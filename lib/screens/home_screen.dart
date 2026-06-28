import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../services/search_service.dart';
import '../widgets/audio_fab.dart';
import '../widgets/editor_view.dart';
import '../widgets/folder_sidebar.dart';
import '../widgets/advanced_settings_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final StorageService _storage = StorageService();
  final AIService _ai = AIService();
  final _uuid = const Uuid();

  List<Note> _notes = [];
  Note? _activeNote;
  AppSettings _settings = AppSettings();

  bool _isRecording = false;
  bool _isProcessing = false;
  DateTime _lastInteractionTime = DateTime.now(); // v13.0: Threshold for auto-creation
  bool _isEditing = false;
  String _currentTranscript = '';
  double _soundLevel = 0.0;
  
  // v11.0 Undo History
  final List<List<Note>> _notesHistory = [];
  
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(() {
      // Update interaction time when user types
      _lastInteractionTime = DateTime.now();
    });
    _loadAllData();
    _initSpeech();
  }

  Future<void> _loadAllData() async {
    final settings = await _storage.getSettings();
    final notes = await _storage.getNotes();
    setState(() {
      _settings = settings;
      _notes = notes;
      _sortNotes(); // v8.2
      if (_notes.isNotEmpty) {
        _activeNote = _notes.first;
        _textController.text = _activeNote!.content;
      } else {
        _createNewNote();
      }
    });
  }

  void _sortNotes() {
    setState(() {
      _notes.sort((a, b) {
        // Prioritize INDEX folder (v8.2)
        if (a.folder == 'INDEX' && b.folder != 'INDEX') return -1;
        if (a.folder != 'INDEX' && b.folder == 'INDEX') return 1;
        // Then sort by date
        return b.modifiedAt.compareTo(a.modifiedAt);
      });
    });
  }

  void _createNewNote() {
    final newNote = Note(
      id: _uuid.v4(),
      title: 'New Note',
      content: '',
      modifiedAt: DateTime.now(),
    );
    setState(() {
      _notes.insert(0, newNote);
      _sortNotes(); // v8.2
      _activeNote = newNote;
      _textController.text = '';
      _isEditing = true;
    });
    _snapshotState();
    _saveNotes();
  }

  void _onDeleteNote(Note note) {
    setState(() {
      // 1. Remove the note itself
      _notes.removeWhere((n) => n.id == note.id);
      
      // 2. Clean up references in INDEX notes (v13.1)
      final wikiLink = '[[' + note.title + ']]';
      for (var n in _notes) {
        if (n.folder == 'INDEX' && n.content.contains(wikiLink)) {
          // Remove the entire line containing the link
          final lines = n.content.split('\n');
          lines.removeWhere((line) => line.contains(wikiLink));
          n.content = lines.join('\n');
          n.modifiedAt = DateTime.now();
        }
      }

      if (_activeNote?.id == note.id) {
        if (_notes.isNotEmpty) {
          _onNoteSelected(_notes.first);
        } else {
          _createNewNote();
        }
      }
    });
    _snapshotState();
    _saveNotes();
  }

  Future<void> _saveNotes() async {
    await _storage.saveNotes(_notes);
  }

  Future<void> _initSpeech() async {
    await Permission.microphone.request();
    await _speech.initialize();
  }

  void _startRecording() async {
    if (_isProcessing) return;
    
    setState(() {
      _isRecording = true;
      _currentTranscript = '';
      _soundLevel = 0.0;
    });

    _speech.listen(
      onResult: (val) => setState(() => _currentTranscript = val.recognizedWords),
      onSoundLevelChange: (level) => setState(() => _soundLevel = level),
      localeId: _settings.targetLanguage == 'English' ? 'en_US' : 'es_ES',
    );
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    _speech.stop();
    setState(() {
      _isRecording = false;
      _soundLevel = 0.0;
      _isProcessing = true;
    });
    
    if (_currentTranscript.isNotEmpty && _settings.activeApiKey.isNotEmpty) {
      // Handle Semantic Voice Intents (v11.2)
      final classification = SearchService.classifyIntent(_currentTranscript);

      switch (classification.intent) {
        case VoiceIntent.undo:
          _handleUndo();
          break;
        case VoiceIntent.save:
          _handleManualSave();
          break;
        case VoiceIntent.open:
          _performAutoOpenSearch(classification.query ?? _currentTranscript);
          break;
        case VoiceIntent.search:
          _performSemanticSearch(classification.query ?? _currentTranscript);
          break;
        case VoiceIntent.remember:
          // v13.0: Force NEW note, skip context
          _processWithAI(forceNew: true, skipContext: true);
          break;
        case VoiceIntent.none:
          // Time threshold logic (v13.0)
          final minutesSinceInteraction = DateTime.now().difference(_lastInteractionTime).inMinutes;
          if (minutesSinceInteraction >= 3) {
            _processWithAI(forceNew: true); // Logic favors new, but model gets context
          } else {
            _processWithAI(forceNew: false); // Logic favors update
          }
          break;
      }
    } else {
      setState(() => _isProcessing = false);
    }
  }

  void _performAutoOpenSearch(String cleanQuery) {
    setState(() => _isProcessing = true);
        
    final results = SearchService.findRelevantNotes(
      query: cleanQuery,
      allNotes: _notes,
      activeNoteId: 'VIRTUAL',
      limit: 10,
    );

    if (results.length == 1) {
      // Direct Navigation
      setState(() {
        _onNoteSelected(results.first);
        _isProcessing = false;
      });
    } else {
      // Fallback to List (same as Search but with "Abre" context)
      String content = '# 🔍 RESULTADOS PARA: $cleanQuery\n\n';
      if (results.isEmpty) {
        content += '_No se encontró ninguna nota para abrir._';
      } else {
        content += '_Se encontraron varias coincidencias. Selecciona una:_\n\n';
        for (var note in results) {
          content += '- [[${note.title}]]\n';
        }
      }

      final searchNote = Note(
        id: 'SEARCH_ID',
        title: 'RESULTADOS BÚSQUEDA',
        content: content,
        modifiedAt: DateTime.now(),
        folder: 'SEARCH',
      );

      setState(() {
        _activeNote = searchNote;
        _textController.text = content;
        _isEditing = false;
        _isProcessing = false;
      });
    }
  }

  void _performSemanticSearch(String cleanQuery) {
    setState(() => _isProcessing = true);
        
    final results = SearchService.findRelevantNotes(
      query: cleanQuery,
      allNotes: _notes,
      activeNoteId: 'VIRTUAL',
      limit: 15,
    );

    String content = '# 🔍 RESULTADOS: $cleanQuery\n\n';
    if (results.isEmpty) {
      content += '_No se encontraron notas relacionadas._';
    } else {
      for (var note in results) {
        content += '- [[${note.title}]]\n';
      }
    }

    final searchNote = Note(
      id: 'SEARCH_ID',
      title: 'RESULTADOS BÚSQUEDA',
      content: content,
      modifiedAt: DateTime.now(),
      folder: 'SEARCH',
    );

    setState(() {
      _activeNote = searchNote;
      _textController.text = content;
      _isEditing = false;
      _isProcessing = false;
    });
  }

  Future<void> _processWithAI({bool? forceNew, bool skipContext = false}) async {
    setState(() => _isProcessing = true);

    List<Note> relevantNotes = [];
    if (_settings.useGlobalContext) {
      relevantNotes = SearchService.findRelevantNotes(
        query: _currentTranscript,
        allNotes: _notes,
        activeNoteId: _activeNote?.id ?? '',
        limit: 5,
      );
    }
    
    // v8.1: If we are on an Index or Search Results, or skipContext is true (v13.0)
    // don't pass the content to the AI to force a New Note creation.
    final String contextContent = (_activeNote?.folder == 'INDEX' || _activeNote?.folder == 'SEARCH' || skipContext) 
        ? '' 
        : (_activeNote?.content ?? '');

    // v13.0: We can override the AI decision by prepending a signal if forceNew is set
    String transcriptToProcess = _currentTranscript;
    if (forceNew == true) {
      transcriptToProcess = "[FORZAR_NUEVA] $transcriptToProcess";
    } else if (forceNew == false && contextContent.isNotEmpty) {
      transcriptToProcess = "[FORZAR_ACTUALIZAR] $transcriptToProcess";
    }

    final response = await _ai.processTranscript(
      transcript: transcriptToProcess,
      currentContent: contextContent,
      settings: _settings,
      relevantNotes: relevantNotes,
      includeCurrentNote: !skipContext,
    );
    
    if (response != null) {
      _handleHybridResult(response);
    }
    
    setState(() => _isProcessing = false);
  }

  void _snapshotState() {
    if (_notesHistory.length > 20) _notesHistory.removeAt(0);
    _notesHistory.add(_notes.map((n) => Note(
      id: n.id,
      title: n.title,
      content: n.content,
      modifiedAt: n.modifiedAt,
      folder: n.folder,
    )).toList());
  }

  void _handleUndo() {
    if (_notesHistory.isNotEmpty) {
      setState(() {
        _notes = _notesHistory.removeLast();
        if (_activeNote != null) {
          final restoredIndex = _notes.indexWhere((n) => n.id == _activeNote!.id);
          if (restoredIndex != -1) {
            _activeNote = _notes[restoredIndex];
          } else if (_notes.isNotEmpty) {
            _activeNote = _notes.first;
          }
          if (_activeNote != null) {
            _textController.text = _activeNote!.content;
          }
        }
      });
      _storage.saveNotes(_notes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acción deshecha'), 
          backgroundColor: Colors.white10,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _handleManualSave() {
    if (_activeNote != null && _isEditing) {
      _snapshotState();
      setState(() {
        final index = _notes.indexWhere((n) => n.id == _activeNote!.id);
        if (index != -1) {
          _notes[index] = Note(
            id: _activeNote!.id,
            title: _activeNote!.title,
            content: _textController.text,
            modifiedAt: DateTime.now(),
            folder: _activeNote!.folder,
          );
          _activeNote = _notes[index];
          _isEditing = false;
        }
      });
      _storage.saveNotes(_notes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nota guardada'), 
          backgroundColor: Colors.white10,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _handleHybridResult(String rawResponse) {
    _snapshotState(); // v11.0: Support undo for AI changes
    // 1. Detect Metadata Block more robustly (v8.9)
    // We look for any mention of METADATA_START to cut the body
    final metadataStart = rawResponse.indexOf('METADATA_START');
    
    // Also check for the "METADATA:" label sometimes added by models
    int cutIndex = metadataStart;
    if (cutIndex == -1) {
       cutIndex = rawResponse.lastIndexOf('METADATA');
    } else if (cutIndex > 0) {
       // Check if there is a "METADATA:" label right before the block
       final potentialLabelIdx = rawResponse.lastIndexOf('METADATA', cutIndex - 1);
       if (potentialLabelIdx != -1 && (cutIndex - potentialLabelIdx) < 20) {
         cutIndex = potentialLabelIdx;
       }
    }

    String cleanBody = cutIndex != -1 
        ? rawResponse.substring(0, cutIndex).trim() 
        : rawResponse.trim();

    // 2. Extract Metadata using specific tags
    final actionMatch = RegExp(r'ACTION: *\[?(NUEVA|ACTUALIZAR)\]?').firstMatch(rawResponse);
    final targetMatch = RegExp(r'TARGET: *(.*)').firstMatch(rawResponse);
    final titleMatch = RegExp(r'TITLE: *(.*)').firstMatch(rawResponse);
    final categoryMatch = RegExp(r'CATEGORY: *(.*)').firstMatch(rawResponse);
    final summaryMatch = RegExp(r'SUMMARY: *(.*)').firstMatch(rawResponse);

    String action = actionMatch?.group(1)?.trim() ?? 'NUEVA';
    String target = targetMatch?.group(1)?.trim() ?? 'NONE';
    String title = titleMatch?.group(1)?.trim() ?? 'Untitled';
    String category = categoryMatch?.group(1)?.trim() ?? 'NONE';
    String summary = summaryMatch?.group(1)?.trim() ?? '';

    // ID Clean-up (v7.8)
    target = target.replaceAll('[', '').replaceAll(']', '').trim();

    // 3. Update or Create Specific Note
    if (category != 'NONE') {
      // Safe H1 Strip (v10.0): Only remove if it exactly matches the title or is just a repeat
      final h1Regex = RegExp(r'^# .*\n?');
      final match = h1Regex.firstMatch(cleanBody);
      if (match != null) {
        final foundTitle = match.group(0)!.replaceFirst('# ', '').trim();
        // If the found H1 is very similar to the metadata TITLE, we strip it
        if (foundTitle.toLowerCase() == title.toLowerCase() || foundTitle.length < 5) {
          cleanBody = cleanBody.replaceFirst(h1Regex, '').trim();
        }
      }
      
      // Better fallbacks: use summary or title directly, avoid "Nota creada" labels
      if (cleanBody.isEmpty) {
        cleanBody = summary.isNotEmpty ? summary : title;
      }
      
      cleanBody = '# $title\n<!-- INDEX: [[$category]] -->\n\n$cleanBody';
    } else {
      if (cleanBody.isEmpty && title != 'Untitled') {
        cleanBody = '# $title';
      }
    }

    Note targetNote;
    int existingIdx = -1;

    // Check by ID first
    if (target != 'NONE' && target != 'ID') {
      existingIdx = _notes.indexWhere((n) => n.id == target);
    } 
    
    // Fallback: Check by Title if Category matches (Deduplication v7.8)
    if (existingIdx == -1 && category != 'NONE') {
      existingIdx = _notes.indexWhere((n) => 
        n.title.toLowerCase() == title.toLowerCase() && 
        n.content.contains('INDEX: [[$category]]'));
    }

    if ((action == 'ACTUALIZAR' || existingIdx != -1) && existingIdx != -1) {
      final String oldTitle = _notes[existingIdx].title;
      final String oldId = _notes[existingIdx].id;
      
      final updatedNote = Note(
        id: oldId,
        title: title,
        content: cleanBody,
        modifiedAt: DateTime.now(),
        folder: _notes[existingIdx].folder,
      );

      setState(() {
        _notes.removeAt(existingIdx);
        _notes.insert(0, updatedNote);
        _activeNote = updatedNote;
        _textController.text = cleanBody;
        _isEditing = false;
      });
      targetNote = updatedNote;
      
      if (category != 'NONE' && category != 'UNKNOWN') {
        _ensureIndexUpdated(category, targetNote, summary, oldTitle: oldTitle);
      }
    } else {
      targetNote = _createAndSetActiveNote(title, cleanBody);
      if (category != 'NONE' && category != 'UNKNOWN') {
        _ensureIndexUpdated(category, targetNote, summary);
      }
    }

    _sortNotes(); // v8.2: Ensure INDEX notes stay at the top
    _saveNotes();
  }

  Note _createAndSetActiveNote(String title, String content) {
    final newNote = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      modifiedAt: DateTime.now(),
    );
    setState(() {
      _notes.insert(0, newNote);
      _activeNote = newNote;
      _textController.text = content;
      _isEditing = false;
      _lastInteractionTime = DateTime.now(); // v13.0
    });
    return newNote;
  }

  void _ensureIndexUpdated(String category, Note childNote, String summary, {String? oldTitle}) {
    final indexTitle = category; 
    final indexNoteIdx = _notes.indexWhere((n) => n.title.toLowerCase() == indexTitle.toLowerCase());
    
    final newEntry = '- [[${childNote.title}]] - ${summary.isEmpty ? "Nueva entrada" : summary}';

    if (indexNoteIdx != -1) {
      String content = _notes[indexNoteIdx].content;
      
      // Patterns to check
      final newLinkPattern = RegExp('- \\[\\[${RegExp.escape(childNote.title)}\\]\\] - .*');
      final oldLinkPattern = oldTitle != null 
          ? RegExp('- \\[\\[${RegExp.escape(oldTitle)}\\]\\] - .*') 
          : null;
      
      setState(() {
        if (content.contains(newLinkPattern)) {
          _notes[indexNoteIdx].content = content.replaceFirst(newLinkPattern, newEntry);
        } else if (oldLinkPattern != null && content.contains(oldLinkPattern)) {
          _notes[indexNoteIdx].content = content.replaceFirst(oldLinkPattern, newEntry);
        } else {
          // v13.1: Insert before KEYWORDS block if it exists to keep metadata at the end
          if (content.contains('<!-- KEYWORDS:')) {
            _notes[indexNoteIdx].content = content.replaceFirst('<!-- KEYWORDS:', '$newEntry\n<!-- KEYWORDS:');
          } else {
            _notes[indexNoteIdx].content += '\n$newEntry';
          }
        }
        _notes[indexNoteIdx].modifiedAt = DateTime.now();
      });
    } else {
      final newIndexNote = Note(
        id: _uuid.v4(),
        title: indexTitle,
        content: '# $indexTitle\n\n$newEntry',
        modifiedAt: DateTime.now(),
        folder: 'INDEX',
      );
      setState(() {
        _notes.add(newIndexNote);
      });
    }
  }

  void _onNoteSelected(Note note) {
    setState(() {
      _activeNote = note;
      _textController.text = note.content;
      _isEditing = false;
      _currentTranscript = '';
      _lastInteractionTime = DateTime.now(); // v13.0
    });
  }

  void _onNoteTitleRequested(String title) {
    final noteIndex = _notes.indexWhere((n) => n.title.toLowerCase() == title.toLowerCase());
    if (noteIndex != -1) {
      _onNoteSelected(_notes[noteIndex]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening: $title'), duration: const Duration(seconds: 1)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note not found: $title'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      drawer: FolderSidebar(
        notes: _notes,
        onNoteSelected: _onNoteSelected,
        onDeleteNote: _onDeleteNote,
        onNewNote: _createNewNote,
      ),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          (_activeNote?.title ?? 'VOID').toUpperCase(),
          style: const TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.visibility : Icons.edit, size: 20),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdvancedSettingsView(
                  settings: _settings,
                  onSave: (s) {
                    setState(() => _settings = s);
                    _storage.saveSettings(s);
                  },
                )),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 150),
            child: EditorView(
              controller: _textController,
              isEditing: _isEditing,
              transientText: (_isRecording || _isProcessing) ? _currentTranscript : '',
              onNoteLinkTapped: _onNoteTitleRequested,
            ),
          ),
          
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: AudioFAB(
                isRecording: _isRecording,
                soundLevel: _soundLevel,
                onHoldStart: _startRecording,
                onHoldEnd: _stopRecording,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
