class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String description;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Task.fromJson(Map<String, dynamic> json) {
    // PostgreSQL BIGSERIAL values can be encoded as JSON strings by node-postgres.
    // Accept both numeric JSON values and numeric strings.
    final rawId = json['id'];
    final parsedId = rawId is num ? rawId.toInt() : int.parse(rawId.toString());

    return Task(
      id: parsedId,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      completed: json['completed'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
