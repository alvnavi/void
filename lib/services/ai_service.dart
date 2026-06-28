import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/note.dart';

class AIService {
  static const String _openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _cerebrasUrl = 'https://api.cerebras.ai/v1/chat/completions';

  Future<String?> processTranscript({
    required String transcript,
    required String currentContent,
    required AppSettings settings,
    List<Note> relevantNotes = const [],
    bool includeCurrentNote = true,
  }) async {
    if (transcript.trim().isEmpty) return null;

    final bool isCerebras = settings.activeProvider == AIProvider.cerebras;
    final String url = isCerebras ? _cerebrasUrl : _openRouterUrl;
    final String apiKey = settings.activeApiKey;
    final String model = isCerebras ? 'gpt-oss-120b' : 'deepseek/deepseek-r1-0528:free';

    if (apiKey.isEmpty) return null;

    String globalContext = "";
    if (relevantNotes.isNotEmpty) {
      globalContext = "\n\nCONTEXTO PARA REFERENCIA:\n";
      for (var note in relevantNotes) {
        globalContext += "--- [ID: ${note.id}] TITULO: ${note.title} ---\n${note.content}\n\n";
      }
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          if (!isCerebras) 'HTTP-Referer': 'https://void-notes.app',
          if (!isCerebras) 'X-Title': 'Void Notes',
        },
        body: jsonEncode({
          "model": model,
          "messages": [
            {
              "role": "system",
              "content": "${settings.systemInstructions}\n\nIdioma: ${settings.targetLanguage}.$globalContext"
            },
            {
              "role": "user",
              "content": "${includeCurrentNote ? "NOTA ABIERTA AHORA:\n$currentContent\n\n" : ""}TRANSCRIPCIÓN:\n$transcript"
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('Process failed: ${response.statusCode}');
      }
    } catch (e) {
      print('AI Error ($model): $e');
      return null;
    }
  }
}
