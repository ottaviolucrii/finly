import 'dart:convert';

import 'package:equatable/equatable.dart';

/// A copy of an answer of the server, kept on the phone.
class CachedResponse extends Equatable {
  final int statusCode;

  /// The few headers a read needs again: the type of the content and, for a page
  /// of rows, the range.
  final Map<String, String> headers;

  /// The answer, as text (the server answers JSON).
  final String body;

  /// When the copy was made.
  final DateTime savedAt;

  const CachedResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.savedAt,
  });

  String toJson() {
    return jsonEncode({
      'status': statusCode,
      'headers': headers,
      'body': body,
      'saved_at': savedAt.toUtc().toIso8601String(),
    });
  }

  /// Throws when the text is not a copy written by [toJson].
  factory CachedResponse.fromJson(String text) {
    final map = jsonDecode(text) as Map<String, dynamic>;

    return CachedResponse(
      statusCode: map['status'] as int,
      headers: Map<String, String>.from(map['headers'] as Map),
      body: map['body'] as String,
      savedAt: DateTime.parse(map['saved_at'] as String).toLocal(),
    );
  }

  @override
  List<Object?> get props => [statusCode, headers, body, savedAt];
}
