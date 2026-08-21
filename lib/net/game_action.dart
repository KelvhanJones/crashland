import '../models/craft_item.dart';
import '../models/wreckage_assignment.dart';
import '../game/game_engine.dart';

class NightPrep {
  NightPrep({
    Set<String>? spearUsers,
    List<WreckageAssignment>? wreckageUses,
    Map<String, bool>? raccoonDiscardFood,
  })  : spearUsers = spearUsers ?? {},
        wreckageUses = wreckageUses ?? [],
        raccoonDiscardFood = raccoonDiscardFood ?? {};

  final Set<String> spearUsers;
  final List<WreckageAssignment> wreckageUses;
  final Map<String, bool> raccoonDiscardFood;

  Map<String, dynamic> toJson() => {
        'spearUsers': spearUsers.toList(),
        'wreckageUses': [
          for (final use in wreckageUses)
            {'cardId': use.cardId, 'targetIds': use.targetIds},
        ],
        'raccoonDiscardFood': raccoonDiscardFood,
      };

  factory NightPrep.fromJson(Map<String, dynamic> json) {
    return NightPrep(
      spearUsers: {
        for (final id in json['spearUsers'] as List? ?? const []) id as String,
      },
      wreckageUses: [
        for (final item in json['wreckageUses'] as List? ?? const [])
          WreckageAssignment(
            cardId: (item as Map)['cardId'] as String,
            targetIds: [
              for (final id in item['targetIds'] as List) id as String,
            ],
          ),
      ],
      raccoonDiscardFood: {
        for (final entry
            in (json['raccoonDiscardFood'] as Map? ?? const {}).entries)
          entry.key as String: entry.value as bool,
      },
    );
  }
}

void applyHostAction(GameEngine engine, Map<String, dynamic> action) {
  final type = action['type'] as String;
  final actorId = action['playerId'] as String?;
  final currentId = engine.state?.currentPlayer.id;
  switch (type) {
    case 'rest':
      if (actorId != null && actorId != currentId) return;
      engine.restCurrentPlayer(useBasket: action['useBasket'] as bool? ?? false);
    case 'forage':
      if (actorId != null && actorId != currentId) return;
      engine.forageCurrentPlayer(action['hearts'] as int);
    case 'contribute':
      engine.contributeToCamp(
        action['playerId'] as String,
        action['cardId'] as String,
      );
    case 'takeCamp':
      engine.takeFromCamp(
        action['playerId'] as String,
        action['cardId'] as String,
      );
    case 'trade':
      engine.tradeCard(
        fromPlayerId: action['fromId'] as String,
        toPlayerId: action['toId'] as String,
        cardId: action['cardId'] as String,
      );
    case 'heal':
      engine.useHealCard(
        ownerId: action['ownerId'] as String,
        cardId: action['cardId'] as String,
        targetId: action['targetId'] as String,
        hearts: action['hearts'] as int?,
      );
    case 'shareHeal':
      engine.shareHealCard(
        ownerId: action['ownerId'] as String,
        cardId: action['cardId'] as String,
        otherId: action['otherId'] as String,
      );
    case 'splitFood':
      engine.splitFood(
        fromPlayerId: action['fromId'] as String,
        toPlayerId: action['toId'] as String,
        cardId: action['cardId'] as String,
      );
    case 'craft':
      engine.craft(
        CraftItem.values.byName(action['item'] as String),
        shelterOccupantIds: {
          for (final id in action['shelterOccupantIds'] as List? ?? const [])
            id as String,
        },
        playerId: action['playerId'] as String?,
      );
    case 'assembleBones':
      engine.assembleBoneCircle();
    case 'beginNight':
      engine.beginNight();
    case 'applyMadness':
      engine.applyMadness();
    default:
      break;
  }
}
