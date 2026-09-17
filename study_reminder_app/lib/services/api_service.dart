import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/group_models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Talks to the group task-assignment backend. Every call that needs a
/// signed-in member takes [token] explicitly — the caller (GroupService)
/// owns loading/storing it, this class is a thin, stateless HTTP wrapper.
class ApiService {
  static const baseUrl = 'https://api-production-10e2.up.railway.app';

  Map<String, String> _headers([String? token]) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    final body =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    throw ApiException((body as Map<String, dynamic>)['error'] as String? ??
        'Error del servidor (${response.statusCode})');
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    required String displayName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groups'),
      headers: _headers(),
      body: jsonEncode({'name': name, 'displayName': displayName}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> joinGroup({
    required String joinCode,
    required String displayName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groups/join'),
      headers: _headers(),
      body: jsonEncode({'joinCode': joinCode, 'displayName': displayName}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> fetchGroup(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/groups/mine'),
      headers: _headers(token),
    );
    return _decode(response);
  }

  Future<List<GroupTask>> fetchMyTasks(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tasks/mine'),
      headers: _headers(token),
    );
    final json = await _decode(response);
    return (json['tasks'] as List)
        .map((t) => GroupTask.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<GroupTask> createTask({
    required String token,
    required int assigneeMemberId,
    required String title,
    required String frequency,
    required int morningHour,
    required int morningMinute,
    String? confirmationCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tasks'),
      headers: _headers(token),
      body: jsonEncode({
        'assigneeMemberId': assigneeMemberId,
        'title': title,
        'frequency': frequency,
        'morningHour': morningHour,
        'morningMinute': morningMinute,
        if (confirmationCode != null && confirmationCode.isNotEmpty)
          'confirmationCode': confirmationCode,
      }),
    );
    final json = await _decode(response);
    return GroupTask.fromJson(json['task'] as Map<String, dynamic>);
  }

  /// Throws [ApiException] with the server's message on an incorrect code
  /// (403) so the caller can show it next to the input, same as the local
  /// confirmation-code flow.
  Future<void> completeTask({
    required String token,
    required int taskId,
    String? code,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/complete'),
      headers: _headers(token),
      body: jsonEncode({if (code != null) 'code': code}),
    );
    await _decode(response);
  }

  Future<void> deleteTask({required String token, required int taskId}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: _headers(token),
    );
    if (response.statusCode != 204) {
      await _decode(response);
    }
  }
}
