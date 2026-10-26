import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/task.dart';

class TaskService {
  TaskService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  Uri _uri(String path) => Uri.parse('$_configuredBaseUrl$path');

  Future<List<Task>> getTasks() async {
    final response = await _client.get(_uri('/api/tasks'));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Task.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Task> createTask({required String title, required String description}) async {
    final response = await _client.post(
      _uri('/api/tasks'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title, 'description': description}),
    );
    _ensureSuccess(response);
    return Task.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Task> updateTask(
    int id, {
    String? title,
    String? description,
    bool? completed,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (completed != null) payload['completed'] = completed;
    final response = await _client.patch(
      _uri('/api/tasks/$id'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    _ensureSuccess(response);
    return Task.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteTask(int id) async {
    final response = await _client.delete(_uri('/api/tasks/$id'));
    _ensureSuccess(response);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['error'] is String) {
        throw TaskApiException(body['error'] as String);
      }
    } on FormatException {
      // Use a generic message for non-JSON server errors.
    }
    throw TaskApiException('Request failed (${response.statusCode}). Please try again.');
  }
}

class TaskApiException implements Exception {
  const TaskApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
