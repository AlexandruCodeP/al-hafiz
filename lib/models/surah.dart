class Ayah {
  final int id;
  final String text;
  final String? translation;
  final String? phonetic;
  final int? pageNumber;

  const Ayah({
    required this.id,
    required this.text,
    this.translation,
    this.phonetic,
    this.pageNumber,
  });

  factory Ayah.fromJson(Map<String, dynamic> json) {
    return Ayah(
      id: json['id'] as int,
      text: json['text'] as String,
      translation: json['translation'] as String?,
      phonetic: json['phonetic'] as String?,
    );
  }
}

class Surah {
  final int id;
  final String name;
  final String transliteration;
  final String type;
  final int totalVerses;
  final List<Ayah> verses;

  const Surah({
    required this.id,
    required this.name,
    required this.transliteration,
    required this.type,
    required this.totalVerses,
    required this.verses,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      id: json['id'] as int,
      name: json['name'] as String,
      transliteration: json['transliteration'] as String,
      type: json['type'] as String,
      totalVerses: json['total_verses'] as int,
      verses: (json['verses'] as List)
          .map((v) => Ayah.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isMeccan => type == 'meccan';
}
