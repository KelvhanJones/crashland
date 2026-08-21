import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/wreckage_assignment.dart';
import '../game/game_codec.dart';
import '../game/game_engine.dart';
import 'game_action.dart';

const kPlayPort = 7384;

class Seat {
  Seat({required this.id, required this.name, this.connected = false});

  final String id;
  String name;
  bool connected;
}

class TableSession extends ChangeNotifier {
  TableSession.local(this.engine)
      : isHost = true,
        localPlayerId = null,
        networked = false;

  TableSession._network({
    required this.engine,
    required this.isHost,
    required this.localPlayerId,
  }) : networked = true;

  final GameEngine engine;
  final bool isHost;
  final bool networked;
  String? localPlayerId;
  String? hostAddress;
  String status = '';
  bool started = false;
  int seatsWanted = 3;
  int nights = 8;
  final seats = <Seat>[];
  final nightPrepByPlayer = <String, NightPrep>{};

  HttpServer? _server;
  final _clients = <WebSocketChannel>[];
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _clientSub;

  bool get isNetworked => networked;

  bool get isMyForageTurn {
    final state = engine.state;
    if (state == null || localPlayerId == null) return true;
    return state.currentPlayer.id == localPlayerId;
  }

  Future<void> host({
    required String hostName,
    required int playerCount,
    required int totalNights,
  }) async {
    seatsWanted = playerCount.clamp(2, 4);
    nights = totalNights;
    seats
      ..clear()
      ..add(Seat(id: 'p0', name: hostName, connected: true));
    localPlayerId = 'p0';
    hostAddress = await _firstIPv4() ?? '127.0.0.1';
    status = 'Waiting for survivors on $hostAddress:$kPlayPort';

    final handler = webSocketHandler((WebSocketChannel channel, String? _) {
      _clients.add(channel);
      channel.stream.listen(
        (message) => _onHostMessage(channel, message),
        onDone: () {
          _clients.remove(channel);
          _markDisconnected(channel);
        },
        onError: (_) {
          _clients.remove(channel);
        },
      );
      _broadcastLobby();
    });

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, kPlayPort);
    notifyListeners();
  }

  Future<void> join({
    required String address,
    required String name,
  }) async {
    hostAddress = address.trim();
    status = 'Connecting to $hostAddress…';
    notifyListeners();
    final uri = Uri.parse('ws://$hostAddress:$kPlayPort');
    _socket = WebSocketChannel.connect(uri);
    await _socket!.ready;
    _clientSub = _socket!.stream.listen(
      _onClientMessage,
      onError: (Object error) {
        status = 'Connection failed: $error';
        notifyListeners();
      },
      onDone: () {
        status = 'Disconnected from host.';
        notifyListeners();
      },
    );
    _send(_socket!, {
      'type': 'hello',
      'name': name.trim().isEmpty ? 'Survivor' : name.trim(),
    });
  }

  void startHostedGame() {
    if (!isHost || started) return;
    if (seats.length < 2) {
      status = 'Need at least 2 survivors.';
      notifyListeners();
      return;
    }
    engine.startGame(
      playerNames: seats.map((seat) => seat.name).toList(),
      totalNights: nights,
    );
    started = true;
    status = 'Expedition underway.';
    _broadcastSnapshot();
    notifyListeners();
  }

  void dispatch(Map<String, dynamic> action) {
    if (!isHost) {
      _send(_socket, {'type': 'action', 'action': action});
      return;
    }
    applyHostAction(engine, action);
    _broadcastSnapshot();
    notifyListeners();
  }

  void sendNightPrep(NightPrep prep) {
    if (localPlayerId != null) {
      nightPrepByPlayer[localPlayerId!] = prep;
    }
    if (!isHost) {
      _send(_socket, {
        'type': 'nightPrep',
        'playerId': localPlayerId,
        'prep': prep.toJson(),
      });
      return;
    }
    notifyListeners();
  }

  void resolveNightFromHost({
    required Set<String> spearUsers,
    required List<WreckageAssignment> wreckageUses,
    required Map<String, bool> raccoonDiscardFood,
  }) {
    if (!isHost) return;
    final spears = {...spearUsers};
    final wreckage = [...wreckageUses];
    final raccoon = {...raccoonDiscardFood};
    for (final prep in nightPrepByPlayer.values) {
      spears.addAll(prep.spearUsers);
      wreckage.addAll(prep.wreckageUses);
      raccoon.addAll(prep.raccoonDiscardFood);
    }
    engine.resolveNight(
      spearUsers: spears,
      wreckageUses: wreckage,
      raccoonDiscardFood: raccoon,
    );
    nightPrepByPlayer.clear();
    _broadcastSnapshot();
    notifyListeners();
  }

  Future<void> disposeSession() async {
    await _clientSub?.cancel();
    await _socket?.sink.close();
    for (final client in List<WebSocketChannel>.from(_clients)) {
      await client.sink.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
  }

  @override
  void dispose() {
    unawaited(disposeSession());
    super.dispose();
  }

  String _asJsonText(dynamic message) {
    if (message is String) return message;
    if (message is List<int>) return utf8.decode(message);
    return message.toString();
  }

  void _onHostMessage(WebSocketChannel channel, dynamic message) {
    final json = jsonDecode(_asJsonText(message)) as Map<String, dynamic>;
    switch (json['type'] as String) {
      case 'hello':
        if (started) {
          _send(channel, {
            'type': 'error',
            'message': 'The expedition already started.',
          });
          return;
        }
        if (seats.length >= seatsWanted) {
          _send(channel, {
            'type': 'error',
            'message': 'Camp is full.',
          });
          return;
        }
        final index = seats.length;
        final id = 'p$index';
        final rawName = (json['name'] as String?)?.trim();
        seats.add(
          Seat(
            id: id,
            name: (rawName == null || rawName.isEmpty)
                ? 'Survivor ${index + 1}'
                : rawName,
            connected: true,
          ),
        );
        _send(channel, {
          'type': 'welcome',
          'playerId': id,
          'lobby': _lobbyPayload(),
        });
        _broadcastLobby();
      case 'action':
        if (!started) return;
        applyHostAction(
          engine,
          Map<String, dynamic>.from(json['action'] as Map),
        );
        _broadcastSnapshot();
        notifyListeners();
      case 'nightPrep':
        final playerId = json['playerId'] as String? ?? '';
        nightPrepByPlayer[playerId] = NightPrep.fromJson(
          Map<String, dynamic>.from(json['prep'] as Map),
        );
        notifyListeners();
    }
  }

  void _onClientMessage(dynamic message) {
    final json = jsonDecode(_asJsonText(message)) as Map<String, dynamic>;
    switch (json['type'] as String) {
      case 'welcome':
        localPlayerId = json['playerId'] as String;
        _readLobby(json['lobby'] as Map);
        status = 'Joined as $localPlayerId. Waiting for host…';
        notifyListeners();
      case 'lobby':
        _readLobby(json);
        notifyListeners();
      case 'snapshot':
        engine.restore(
          GameCodec.decodeState(
            Map<String, dynamic>.from(json['state'] as Map),
          ),
          idCursor: json['idCursor'] as int?,
        );
        started = true;
        status = 'Synced.';
        notifyListeners();
      case 'error':
        status = json['message'] as String? ?? 'Error';
        notifyListeners();
    }
  }

  void _readLobby(Map lobby) {
    seats
      ..clear()
      ..addAll([
        for (final item in lobby['seats'] as List)
          Seat(
            id: (item as Map)['id'] as String,
            name: item['name'] as String,
            connected: item['connected'] as bool? ?? true,
          ),
      ]);
    seatsWanted = lobby['seatsWanted'] as int? ?? seatsWanted;
    nights = lobby['nights'] as int? ?? nights;
    started = lobby['started'] as bool? ?? started;
  }

  Map<String, dynamic> _lobbyPayload() => {
        'seatsWanted': seatsWanted,
        'nights': nights,
        'started': started,
        'seats': [
          for (final seat in seats)
            {'id': seat.id, 'name': seat.name, 'connected': seat.connected},
        ],
      };

  void _broadcastLobby() {
    final payload = {'type': 'lobby', ..._lobbyPayload()};
    for (final client in _clients) {
      _send(client, payload);
    }
    notifyListeners();
  }

  void _broadcastSnapshot() {
    final state = engine.state;
    if (state == null) return;
    final payload = {
      'type': 'snapshot',
      'idCursor': engine.idCursor,
      'state': GameCodec.encodeState(state, idCursor: engine.idCursor),
    };
    for (final client in _clients) {
      _send(client, payload);
    }
  }

  void _markDisconnected(WebSocketChannel channel) {
    notifyListeners();
  }

  void _send(WebSocketChannel? channel, Map<String, dynamic> payload) {
    if (channel == null) return;
    channel.sink.add(jsonEncode(payload));
  }

  static Future<String?> _firstIPv4() async {
    for (final iface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    )) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return null;
  }
}

TableSession createHostSession() =>
    TableSession._network(engine: GameEngine(), isHost: true, localPlayerId: 'p0');

TableSession createClientSession() =>
    TableSession._network(engine: GameEngine(), isHost: false, localPlayerId: null);
