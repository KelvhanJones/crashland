import 'resource_type.dart';

class GameCard {
  const GameCard({required this.id, required this.resource});

  final String id;
  final ResourceType resource;

  GameCard copyWith({String? id, ResourceType? resource}) {
    return GameCard(
      id: id ?? this.id,
      resource: resource ?? this.resource,
    );
  }
}
