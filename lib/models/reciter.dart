enum ReciterSource { everyayah, mp3quran }

class Reciter {
  final String id;
  final String name;
  final String folder;
  final String? style;
  final ReciterSource source;
  final String? baseUrl;

  const Reciter({
    required this.id,
    required this.name,
    required this.folder,
    this.style,
    this.source = ReciterSource.everyayah,
    this.baseUrl,
  });

  String get displayName => style != null ? '$name ($style)' : name;

  static const List<Reciter> all = [
    Reciter(id: 'alafasy', name: 'Mishary Rashid Alafasy', folder: 'Alafasy_128kbps'),
    Reciter(id: 'abdulbasit_mujawwad', name: 'AbdulBaset AbdulSamad', folder: 'Abdul_Basit_Mujawwad_128kbps', style: 'Mujawwad'),
    Reciter(id: 'abdulbasit_murattal', name: 'AbdulBaset AbdulSamad', folder: 'Abdul_Basit_Murattal_192kbps', style: 'Murattal'),
    Reciter(id: 'sudais', name: 'Abdur-Rahman As-Sudais', folder: 'Abdurrahmaan_As-Sudais_192kbps'),
    Reciter(id: 'shatri', name: 'Abu Bakr Ash-Shatri', folder: 'Abu_Bakr_Ash-Shaatree_128kbps'),
    Reciter(id: 'ajamy', name: 'Ahmed ibn Ali al-Ajamy', folder: 'ahmed_ibn_ali_al_ajamy_128kbps'),
    Reciter(id: 'alaqimy', name: 'Akram Al-Alaqimy', folder: 'Akram_AlAlaqimy_128kbps'),
    Reciter(id: 'ali_jaber', name: 'Ali Jaber', folder: 'Ali_Jaber_64kbps'),
    Reciter(id: 'ali_hajjaj', name: 'Ali Hajjaj Al-Suesy', folder: 'Ali_Hajjaj_AlSuesy_128kbps'),
    Reciter(id: 'neana', name: 'Ahmed Neana', folder: 'Ahmed_Neana_128kbps'),
    Reciter(id: 'abdullah_basfar', name: 'Abdullah Basfar', folder: 'Abdullah_Basfar_192kbps'),
    Reciter(id: 'abdullah_matroud', name: 'Abdullah Matroud', folder: 'Abdullah_Matroud_128kbps'),
    Reciter(id: 'abdullaah_juhaynee', name: "Abdullaah Al-Juhaynee", folder: 'Abdullaah_3awwaad_Al-Juhaynee_128kbps'),
    Reciter(id: 'ayman_sowaid', name: 'Ayman Sowaid', folder: 'Ayman_Sowaid_64kbps'),
    Reciter(id: 'aziz_alili', name: 'Aziz Alili', folder: 'aziz_alili_128kbps'),
    Reciter(id: 'fares_abbad', name: 'Fares Abbad', folder: 'Fares_Abbad_64kbps'),
    Reciter(id: 'ghamadi', name: 'Saad Al-Ghamadi', folder: 'Ghamadi_40kbps'),
    Reciter(id: 'hani_rifai', name: 'Hani Ar-Rifai', folder: 'Hani_Rifai_192kbps'),
    Reciter(id: 'hudhaify', name: 'Ali Al-Hudhaify', folder: 'Hudhaify_128kbps'),
    Reciter(id: 'husary', name: 'Mahmoud Khalil Al-Husary', folder: 'Husary_128kbps'),
    Reciter(id: 'husary_mujawwad', name: 'Mahmoud Khalil Al-Husary', folder: 'Husary_128kbps_Mujawwad', style: 'Mujawwad'),
    Reciter(id: 'husary_muallim', name: 'Mahmoud Khalil Al-Husary', folder: 'Husary_Muallim_128kbps', style: 'Muallim'),
    Reciter(id: 'ibrahim_akhdar', name: 'Ibrahim Akhdar', folder: 'Ibrahim_Akhdar_64kbps'),
    Reciter(id: 'karim_mansoori', name: 'Karim Mansoori', folder: 'Karim_Mansoori_40kbps'),
    Reciter(id: 'khalid_qahtani', name: 'Khalid Al-Qahtani', folder: 'Khaalid_Abdullaah_al-Qahtaanee_192kbps'),
    Reciter(id: 'khalefa_tunaiji', name: 'Khalefa Al-Tunaiji', folder: 'khalefa_al_tunaiji_64kbps'),
    Reciter(id: 'maher_muaiqly', name: 'Maher Al-Muaiqly', folder: 'MaherAlMuaiqly128kbps'),
    Reciter(id: 'mahmoud_banna', name: 'Mahmoud Ali Al-Banna', folder: 'mahmoud_ali_al_banna_32kbps'),
    Reciter(id: 'minshawy_mujawwad', name: 'Mohamed Siddiq Al-Minshawi', folder: 'Minshawy_Mujawwad_192kbps', style: 'Mujawwad'),
    Reciter(id: 'minshawy_murattal', name: 'Mohamed Siddiq Al-Minshawi', folder: 'Minshawy_Murattal_128kbps', style: 'Murattal'),
    Reciter(id: 'minshawy_teacher', name: 'Mohamed Siddiq Al-Minshawi', folder: 'Minshawy_Teacher_128kbps', style: 'Teacher'),
    Reciter(id: 'tablaway', name: 'Mohammad Al-Tablaway', folder: 'Mohammad_al_Tablaway_128kbps'),
    Reciter(id: 'abdulkareem', name: 'Muhammad AbdulKareem', folder: 'Muhammad_AbdulKareem_128kbps'),
    Reciter(id: 'ayyoub', name: 'Muhammad Ayyoub', folder: 'Muhammad_Ayyoub_128kbps'),
    Reciter(id: 'jibreel', name: 'Muhammad Jibreel', folder: 'Muhammad_Jibreel_128kbps'),
    Reciter(id: 'muhsin_qasim', name: 'Muhsin Al-Qasim', folder: 'Muhsin_Al_Qasim_192kbps'),
    Reciter(id: 'mustafa_ismail', name: 'Mustafa Ismail', folder: 'Mustafa_Ismail_48kbps'),
    Reciter(id: 'nabil_rifai', name: "Nabil Ar-Rifa'i", folder: 'Nabil_Rifa3i_48kbps'),
    Reciter(id: 'nasser_qatami', name: 'Nasser Al-Qatami', folder: 'Nasser_Alqatami_128kbps'),
    Reciter(id: 'sahl_yassin', name: 'Sahl Yassin', folder: 'Sahl_Yassin_128kbps'),
    Reciter(id: 'bukhatir', name: 'Salah AbdulRahman Bukhatir', folder: 'Salaah_AbdulRahman_Bukhatir_128kbps'),
    Reciter(id: 'salah_budair', name: 'Salah Al-Budair', folder: 'Salah_Al_Budair_128kbps'),
    Reciter(id: 'shuraym', name: "Sa'ud Ash-Shuraym", folder: 'Saood_ash-Shuraym_128kbps'),
    Reciter(id: 'yaser_salamah', name: 'Yaser Salamah', folder: 'Yaser_Salamah_128kbps'),
    Reciter(id: 'yasser_dussary', name: 'Yasser Ad-Dussary', folder: 'Yasser_Ad-Dussary_128kbps'),
    Reciter(id: 'warsh', name: 'Warsh (Hafs alternative)', folder: 'warsh'),
    Reciter(
      id: 'badr_turki',
      name: 'Badr Al-Turki',
      folder: 'bader/Rewayat-Hafs-A-n-Assem',
      source: ReciterSource.mp3quran,
      baseUrl: 'https://server10.mp3quran.net',
    ),
  ];

  static Reciter getById(String id) {
    return all.firstWhere((r) => r.id == id, orElse: () => all.first);
  }
}
