import '../models/built_shelter.dart';
import '../models/card_kind.dart';
import '../models/craft_item.dart';
import '../models/game_card.dart';
import '../models/game_phase.dart';
import '../models/madness_card.dart';
import '../models/night_card.dart';
import '../models/player.dart';
import 'game_engine.dart';

class GameCodec {
  GameCodec._();

  static Map<String, dynamic> encodeState(GameState state, {required int idCursor}) {
    return {
      'idCursor': idCursor,
      'totalNights': state.totalNights,
      'phase': state.phase.name,
      'currentPlayerIndex': state.currentPlayerIndex,
      'nightNumber': state.nightNumber,
      'fireLit': state.fireLit,
      'fireFromCraft': state.fireFromCraft,
      'caveShelter': state.caveShelter,
      'pendingNoFireTomorrow': state.pendingNoFireTomorrow,
      'fireBlockedNextNight': state.fireBlockedNextNight,
      'message': state.message,
      'won': state.won,
      'foragedThisRound': state.foragedThisRound.toList(),
      'actionLog': state.actionLog,
      'craftStock': {
        for (final item in CraftItem.values) item.name: state.craftRemaining(item),
      },
      'players': state.players.map(_player).toList(),
      'foragePile': state.foragePile.map(_card).toList(),
      'nightDeck': state.nightDeck.map(_night).toList(),
      'madnessPile': state.madnessPile.map(_madness).toList(),
      'campStash': state.campStash.map(_card).toList(),
      'shelters': [
        for (final shelter in state.shelters)
          {'occupantIds': shelter.occupantIds.toList()},
      ],
      'activeNight':
          state.activeNight == null ? null : _night(state.activeNight!),
    };
  }

  static GameState decodeState(Map<String, dynamic> json) {
    return GameState(
      players: [
        for (final item in json['players'] as List)
          _readPlayer(Map<String, dynamic>.from(item as Map)),
      ],
      foragePile: _cardList(json['foragePile']),
      nightDeck: [
        for (final item in json['nightDeck'] as List)
          _readNight(Map<String, dynamic>.from(item as Map)),
      ],
      madnessPile: [
        for (final item in json['madnessPile'] as List)
          _readMadness(Map<String, dynamic>.from(item as Map)),
      ],
      totalNights: json['totalNights'] as int,
      phase: GamePhase.values.byName(json['phase'] as String),
      currentPlayerIndex: json['currentPlayerIndex'] as int,
      nightNumber: json['nightNumber'] as int,
      fireLit: json['fireLit'] as bool,
      fireFromCraft: json['fireFromCraft'] as bool,
      caveShelter: json['caveShelter'] as bool,
      pendingNoFireTomorrow: json['pendingNoFireTomorrow'] as bool,
      fireBlockedNextNight: json['fireBlockedNextNight'] as bool,
      craftStock: {
        for (final item in CraftItem.values)
          item: (json['craftStock'] as Map)[item.name] as int? ?? 0,
      },
      campStash: _cardList(json['campStash']),
      shelters: [
        for (final item in json['shelters'] as List)
          BuiltShelter(
            occupantIds: {
              for (final id in (item as Map)['occupantIds'] as List)
                id as String,
            },
          ),
      ],
      activeNight: json['activeNight'] == null
          ? null
          : _readNight(Map<String, dynamic>.from(json['activeNight'] as Map)),
      message: json['message'] as String,
      won: json['won'] as bool,
      foragedThisRound: {
        for (final id in json['foragedThisRound'] as List) id as String,
      },
      actionLog: [
        for (final line in json['actionLog'] as List) line as String,
      ],
    );
  }

  static int idCursorOf(Map<String, dynamic> json) => json['idCursor'] as int? ?? 0;

  static Map<String, dynamic> _card(GameCard card) => {
        'id': card.id,
        'name': card.name,
        'kind': card.kind.name,
        'healValue': card.healValue,
        'fullHeal': card.fullHeal,
        'uhOh': card.uhOh?.name,
        'boneIndex': card.boneIndex,
        'wreckage': card.wreckage?.name,
      };

  static List<GameCard> _cardList(dynamic json) => [
        for (final item in json as List)
          _readCard(Map<String, dynamic>.from(item as Map)),
      ];

  static GameCard _readCard(Map<String, dynamic> json) {
    return GameCard(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: CardKind.values.byName(json['kind'] as String),
      healValue: json['healValue'] as int? ?? 0,
      fullHeal: json['fullHeal'] as bool? ?? false,
      uhOh: json['uhOh'] == null
          ? null
          : UhOhEffect.values.byName(json['uhOh'] as String),
      boneIndex: json['boneIndex'] as int?,
      wreckage: json['wreckage'] == null
          ? null
          : WreckageAbility.values.byName(json['wreckage'] as String),
    );
  }

  static Map<String, dynamic> _player(Player player) => {
        'id': player.id,
        'name': player.name,
        'hearts': player.hearts,
        'maxHearts': player.maxHearts,
        'dead': player.dead,
        'hand': player.hand.map(_card).toList(),
        'hasBasket': player.hasBasket,
        'spearCount': player.spearCount,
        'cannotTrade': player.cannotTrade,
        'forcedForage': player.forcedForage,
        'forcedRest': player.forcedRest,
        'drewMadnessThisNight': player.drewMadnessThisNight,
        'pendingMadness': player.pendingMadness == null
            ? null
            : _madness(player.pendingMadness!),
      };

  static Player _readPlayer(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      hearts: json['hearts'] as int,
      maxHearts: json['maxHearts'] as int? ?? 6,
      dead: json['dead'] as bool,
      hand: _cardList(json['hand']),
      hasBasket: json['hasBasket'] as bool,
      spearCount: json['spearCount'] as int,
      cannotTrade: json['cannotTrade'] as bool,
      forcedForage: json['forcedForage'] as int?,
      forcedRest: json['forcedRest'] as bool,
      drewMadnessThisNight: json['drewMadnessThisNight'] as bool? ?? false,
      pendingMadness: json['pendingMadness'] == null
          ? null
          : _readMadness(
              Map<String, dynamic>.from(json['pendingMadness'] as Map),
            ),
    );
  }

  static Map<String, dynamic> _night(NightCard card) => {
        'id': card.id,
        'title': card.title,
        'description': card.description,
        'eventType': card.eventType.name,
        'allHearts': card.allHearts,
        'unshelteredHearts': card.unshelteredHearts,
        'fireCancels': card.fireCancels,
        'fireReducesAbsDamageTo': card.fireReducesAbsDamageTo,
        'fireBonusHeal': card.fireBonusHeal,
        'destroyShelter': card.destroyShelter,
        'noFireTomorrow': card.noFireTomorrow,
        'discardOneForage': card.discardOneForage,
        'loseAllFiber': card.loseAllFiber,
        'loseAllForage': card.loseAllForage,
        'permanentCave': card.permanentCave,
        'damageIfHasForage': card.damageIfHasForage,
        'raccoonChoice': card.raccoonChoice,
      };

  static NightCard _readNight(Map<String, dynamic> json) {
    return NightCard(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      eventType: NightEventType.values.byName(json['eventType'] as String),
      allHearts: json['allHearts'] as int? ?? 0,
      unshelteredHearts: json['unshelteredHearts'] as int? ?? 0,
      fireCancels: json['fireCancels'] as bool? ?? false,
      fireReducesAbsDamageTo: json['fireReducesAbsDamageTo'] as int?,
      fireBonusHeal: json['fireBonusHeal'] as int? ?? 0,
      destroyShelter: json['destroyShelter'] as bool? ?? false,
      noFireTomorrow: json['noFireTomorrow'] as bool? ?? false,
      discardOneForage: json['discardOneForage'] as bool? ?? false,
      loseAllFiber: json['loseAllFiber'] as bool? ?? false,
      loseAllForage: json['loseAllForage'] as bool? ?? false,
      permanentCave: json['permanentCave'] as bool? ?? false,
      damageIfHasForage: json['damageIfHasForage'] as bool? ?? false,
      raccoonChoice: json['raccoonChoice'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _madness(MadnessCard card) => {
        'id': card.id,
        'kind': card.kind.name,
        'title': card.title,
        'description': card.description,
      };

  static MadnessCard _readMadness(Map<String, dynamic> json) {
    return MadnessCard(
      id: json['id'] as String,
      kind: MadnessKind.values.byName(json['kind'] as String),
      title: json['title'] as String,
      description: json['description'] as String,
    );
  }
}
