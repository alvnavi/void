import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import '../models/app_settings.dart';

class StorageService {
  static const String _settingsKey = 'void_settings';
  static const String _notesKey = 'void_notes';

  // Settings
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  Future<AppSettings> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_settingsKey);
      if (data == null || data.isEmpty) return AppSettings();
      
      final Map<String, dynamic> json = jsonDecode(data);
      return AppSettings.fromJson(json);
    } catch (e) {
      print('Error reading settings (resetting to default): $e');
      return AppSettings();
    }
  }

  // Notes
  Future<void> saveNotes(List<Note> notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = notes.map((n) => n.toJson()).toList();
      await prefs.setString(_notesKey, jsonEncode(data));
    } catch (e) {
      print('Error saving notes: $e');
    }
  }

  Future<List<Note>> getNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_notesKey);
      if (data == null || data.isEmpty) return [];
      
      final dynamic decoded = jsonDecode(data);
      if (decoded is List) {
        return decoded.map((item) => Note.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error reading notes (data corrupted): $e');
      return [];
    }
  }
}
