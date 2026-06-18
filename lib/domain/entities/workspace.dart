/// Domain entity representing a named workspace that groups together API
/// requests, collections, and environments.
class Workspace {
  /// Unique identifier (UUID v4).
  final String id;

  /// Human-readable workspace name.
  final String name;

  /// Optional free-text description.
  final String? description;

  /// Unix epoch milliseconds when this workspace was created.
  final DateTime createdAt;

  /// Unix epoch milliseconds when this workspace was last modified.
  final DateTime updatedAt;

  const Workspace({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a mutable copy with optional field overrides.
  Workspace copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}