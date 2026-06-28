import 'package:flutter/material.dart';
import '../models/note.dart';

class FolderSidebar extends StatelessWidget {
  final List<Note> notes;
  final Function(Note) onNoteSelected;
  final Function(Note) onDeleteNote;
  final VoidCallback onNewNote;

  const FolderSidebar({
    Key? key,
    required this.notes,
    required this.onNoteSelected,
    required this.onDeleteNote,
    required this.onNewNote,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Map<String, List<Note>> folders = {};
    for (var note in notes) {
      folders.putIfAbsent(note.folder, () => []).add(note);
    }

    return Drawer(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      child: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'V',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Image.asset(
                          'assets/logo.png',
                          height: 24,
                          width: 24,
                        ),
                      ),
                      const Text(
                        'ID',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.pop(context);
                      onNewNote();
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: folders.keys.map((folderName) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 20, bottom: 8),
                      child: Text(
                        folderName.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    ...folders[folderName]!.map((note) {
                      final bool urgent = note.content.toLowerCase().contains(RegExp(r'urgencia[:* ]+alta'));
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: Colors.white.withValues(alpha: 0.05),
                          title: Text(
                            note.title.isEmpty ? 'Untitled' : note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14, 
                              color: urgent ? Colors.redAccent : Colors.white,
                              fontWeight: urgent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            note.modifiedAt.toString().split(' ')[0],
                            style: TextStyle(fontSize: 11, color: Colors.white24),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
                            onPressed: () => _confirmDelete(context, note),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            onNoteSelected(note);
                          },
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('DELETE NOTE', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${note.title}"?', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white24)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDeleteNote(note);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
