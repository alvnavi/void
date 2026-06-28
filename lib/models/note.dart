class Note {
  final String id;
  String title;
  String content;
  String folder;
  DateTime modifiedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.folder = 'Default',
    required this.modifiedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'folder': folder,
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] ?? '',
    title: json['title'] ?? 'Untitled',
    content: json['content'] ?? '',
    folder: json['folder'] ?? 'Default',
    modifiedAt: DateTime.tryParse(json['modifiedAt'] ?? '') ?? DateTime.now(),
  );
}
