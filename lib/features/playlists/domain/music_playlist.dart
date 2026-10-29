class MusicPlaylist {
  MusicPlaylist({
    required this.id,
    required this.name,
    required List<String> songIds,
  }) : songIds = List.unmodifiable(songIds);
  final String id;
  final String name;
  final List<String> songIds;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'songIds': songIds};
  factory MusicPlaylist.fromJson(Map<String, dynamic> json) => MusicPlaylist(
    id: json['id'] as String,
    name: json['name'] as String,
    songIds: (json['songIds'] as List).cast<String>(),
  );
}
