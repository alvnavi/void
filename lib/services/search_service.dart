import '../models/note.dart';

enum VoiceIntent { undo, save, search, open, remember, none }

class VoiceIntentResult {
  final VoiceIntent intent;
  final String? query;
  VoiceIntentResult(this.intent, {this.query});
}

class SearchService {
  /// Classifies the user's vocal intent based on semantic templates (v11.2)
  static VoiceIntentResult classifyIntent(String transcript) {
    final transcriptLower = transcript.toLowerCase().trim();
    if (transcriptLower.isEmpty) return VoiceIntentResult(VoiceIntent.none);

    final tokens = _tokenize(transcript);

    // 1. UNDO Intent
    const undoTriggers = {
      'vuelve', 'regresa', 'atrás', 'atras', 'undo', 'equivocado', 'borra', 
      'quita', 'puse', 'mal', 'deshacer', 'error', 'fallo'
    };
    if (tokens.any((t) => undoTriggers.contains(t))) return VoiceIntentResult(VoiceIntent.undo);

    // 2. SAVE Intent
    const saveTriggers = {
      'guardar', 'save', 'listo', 'finalizar', 'termina', 'terminar', 
      'fijar', 'confirmar', 'ok', 'vale', 'guarda'
    };
    if (tokens.any((t) => saveTriggers.contains(t))) return VoiceIntentResult(VoiceIntent.save);

    // 3. REMEMBER Intent (v13.0)
    const rememberTriggers = {
      'recuerda', 'recordatorio', 'apunta', 'anota', 'nuevo', 'nueva', 'recordar'
    };
    if (tokens.any((t) => rememberTriggers.contains(t))) return VoiceIntentResult(VoiceIntent.remember);

    // 4. OPEN Intent (High Priority Prefix)
    final openMatch = RegExp(r'^(abre|abrir|open|ve\s+a|ir\s+a)\s+(.+)', caseSensitive: false).firstMatch(transcriptLower);
    if (openMatch != null) {
      return VoiceIntentResult(VoiceIntent.open, query: openMatch.group(2)?.trim());
    }

    // 5. SEARCH Intent
    final searchMatch = RegExp(r'^(busca|buscar|find|search|donde|dónde|búscame|buscame)\s+(.+)', caseSensitive: false).firstMatch(transcriptLower);
    if (searchMatch != null) {
      return VoiceIntentResult(VoiceIntent.search, query: searchMatch.group(2)?.trim());
    }

    return VoiceIntentResult(VoiceIntent.none);
  }

  /// Simple keyword-based similarity search (lite TF-IDF/Jaccard hybrid)
  /// Now with Relational Graph Boosting (v12.1) and Single Note Fallback (v13.0)
  static List<Note> findRelevantNotes({
    required String query,
    required List<Note> allNotes,
    required String activeNoteId,
    int limit = 3,
  }) {
    if (query.trim().length < 2) return [];

    final queryWords = _tokenize(query);
    // If no words but search requested, perhaps it's a very short term
    final List<String> effectiveQueryWords = queryWords.isEmpty 
        ? query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 1).toList()
        : queryWords.toList();

    if (effectiveQueryWords.isEmpty) return [];

    // 1. Identify "Relevant Indices" (v12.1) - Softened (v12.2) + Taxonomy Bridge (v13.1)
    final relevantIndices = allNotes
        .where((n) => n.folder == 'INDEX')
        .where((n) {
          final titleLower = n.title.toLowerCase();
          final contentLower = n.content.toLowerCase();
          
          // Match title
          if (effectiveQueryWords.any((q) => titleLower.contains(q))) return true;
          
          // Taxonomy Bridge: Match hidden keywords block (v13.1)
          // Format: <!-- KEYWORDS: word1, word2 -->
          final keywordRegex = RegExp(r'<!-- KEYWORDS: (.*?) -->');
          final match = keywordRegex.firstMatch(contentLower);
          if (match != null) {
            final keywords = match.group(1) ?? '';
            if (effectiveQueryWords.any((q) => keywords.contains(q))) return true;
          }
          
          return false;
        }).toList();

    // 2. Extract "Related Titles" from those indices (v12.1)
    final Set<String> relatedTitles = {};
    for (var indexNote in relevantIndices) {
      final wikiLinkRegex = RegExp(r'\[\[(.*?)\]\]');
      final matches = wikiLinkRegex.allMatches(indexNote.content);
      for (var m in matches) {
        if (m.group(1) != null) {
          relatedTitles.add(m.group(1)!.toLowerCase());
        }
      }
    }

    final scoredNotes = allNotes
        .where((n) => n.id != activeNoteId) 
        .where((n) => n.folder != 'INDEX' && n.folder != 'SEARCH')
        .map((note) {
      final noteContentLower = note.content.toLowerCase();
      final noteTitleLower = note.title.toLowerCase();
      
      // Extraction of Category Tag (v12.2)
      final categoryRegex = RegExp(r'<!-- INDEX: \[\[(.*?)\]\] -->');
      final categoryMatch = categoryRegex.firstMatch(note.content);
      final String? noteCategory = categoryMatch?.group(1)?.toLowerCase();

      double score = 0;

      for (var word in effectiveQueryWords) {
        // A. Fuzzy Content Match (v12.2)
        if (noteContentLower.contains(word)) {
          score += 1.0;
        }

        // B. Fuzzy Title Match (v12.2)
        if (noteTitleLower.contains(word)) {
          score += 3.0; // Base title weight
          
          // Exact sub-token bonus (v12.0)
          if (noteTitleLower == word) {
            score += 5.0;
          }
        }

        // C. Category Tag Boost (v12.2)
        if (noteCategory != null && noteCategory.contains(word)) {
          score += 6.0; // Higher than standard title, lower than relational
        }
      }

      // 3. Relational Boost (v12.1)
      if (relatedTitles.contains(noteTitleLower)) {
        score += 8.0;
      }

      // Whole query match bonus (v12.0)
      if (noteTitleLower.contains(query.toLowerCase())) {
        score += 10.0;
      }

      // Normalize by length slightly
      final wordCount = note.content.split(RegExp(r'\s+')).length;
      score = score / (1 + (wordCount * 0.01));

      return _ScoredNote(note, score);
    }).where((sn) => sn.score > 0).toList();

    if (scoredNotes.isEmpty) {
      // 4. Single Note Fallback (v13.0): If there's only one content note, return it
      final contentNotes = allNotes.where((n) => 
        n.folder != 'INDEX' && 
        n.folder != 'SEARCH' && 
        n.id != activeNoteId
      ).toList();
      
      if (contentNotes.length == 1) {
        return [contentNotes.first];
      }
      return [];
    }

    scoredNotes.sort((a, b) => b.score.compareTo(a.score));

    return scoredNotes.take(limit).map((sn) => sn.note).toList();
  }

  static Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toSet();
  }

  static final Set<String> _stopWords = {
    'que', 'con', 'para', 'una', 'los', 'del', 'las', 'por', 'los', 'tan', 'como', 'sus', 'sus',
    'the', 'and', 'for', 'with', 'this', 'that', 'from', 'have', 'been', 'were', 'was',
    'una', 'uno', 'unos', 'unas', 'este', 'esta', 'estos', 'estas', 'pero', 'mas', 'muy'
  };
}

class _ScoredNote {
  final Note note;
  final double score;
  _ScoredNote(this.note, this.score);
}
