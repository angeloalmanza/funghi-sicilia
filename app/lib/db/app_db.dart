import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/species.dart';

/// Un'osservazione salvata nel diario.
class DiaryEntry {
  DiaryEntry({
    required this.id,
    required this.createdAt,
    required this.photos,
    this.speciesId,
    this.note,
    this.lat,
    this.lon,
  });
  final int id;
  final DateTime createdAt;
  final List<String> photos;
  final int? speciesId;
  final String? note;
  final double? lat;
  final double? lon;
}

/// Due database locali, 100% offline:
///  * `funghi_species.db`: copia di assets/db/species_db.sqlite (sola lettura), ricopiata quando
///    cambia assets/db/version.txt (generato da pipeline/07_sync_app_assets.py);
///  * `diario.db`: le raccolte dell'utente. È separato, quindi aggiornare le specie non lo cancella.
class AppDb {
  AppDb._(this._species, this._diary, this._ftsOk);
  final Database _species;
  final Database _diary;
  bool _ftsOk;

  static const _speciesAsset = 'assets/db/species_db.sqlite';
  static const _versionAsset = 'assets/db/version.txt';
  static const _speciesFile = 'funghi_species.db';
  static const _versionFile = 'funghi_species.version';

  static Future<AppDb> open() async {
    final dir = await getDatabasesPath();
    await Directory(dir).create(recursive: true);
    final spPath = p.join(dir, _speciesFile);
    final verPath = p.join(dir, _versionFile);

    final assetVersion = (await rootBundle.loadString(_versionAsset)).trim();
    final installed = File(verPath).existsSync()
        ? File(verPath).readAsStringSync().trim()
        : '';
    if (installed != assetVersion || !File(spPath).existsSync()) {
      final data = await rootBundle.load(_speciesAsset);
      final tmp = File('$spPath.tmp');
      await tmp.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      await databaseFactory.deleteDatabase(spPath);
      await tmp.rename(spPath);
      await File(verPath).writeAsString(assetVersion, flush: true);
    }
    final species = await openDatabase(spPath, readOnly: true);

    final diary = await openDatabase(
      p.join(dir, 'diario.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE diary (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at TEXT NOT NULL,
          species_id INTEGER,
          note TEXT,
          photos TEXT,
          lat REAL,
          lon REAL
        )'''),
    );

    var ftsOk = true;
    try {
      await species.rawQuery(
        "SELECT rowid FROM species_fts WHERE species_fts MATCH 'a*' LIMIT 1",
      );
    } catch (_) {
      ftsOk = false; // SQLite di sistema senza FTS5: si usa LIKE
    }
    return AppDb._(species, diary, ftsOk);
  }

  Future<Map<int, List<SpeciesPhoto>>> _photos([List<int>? ids]) async {
    final where = ids == null ? '' : 'WHERE species_key IN (${ids.join(',')})';
    final rows = await _species.rawQuery(
      'SELECT * FROM photos $where ORDER BY id',
    );
    final out = <int, List<SpeciesPhoto>>{};
    for (final r in rows) {
      (out[r['species_key'] as int] ??= []).add(
        SpeciesPhoto(
          asset: 'assets/${r['path']}',
          author: r['author'] as String?,
          license: r['license'] as String?,
          source: r['source'] as String?,
        ),
      );
    }
    return out;
  }

  /// Elenco specie, mortali in cima (ordine_sicurezza), poi alfabetico. [query] cerca in nome
  /// scientifico, italiano, siciliano, nomi della checklist, famiglia e genere (FTS5 con prefisso).
  Future<List<Species>> species({
    String query = '',
    Set<Category>? categories,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    final tokens = query
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isNotEmpty) {
      if (_ftsOk) {
        where.add(
          'key IN (SELECT rowid FROM species_fts WHERE species_fts MATCH ?)',
        );
        args.add(tokens.map((t) => '"$t"*').join(' '));
      } else {
        for (final t in tokens) {
          where.add(
            '(nome_scientifico LIKE ? OR nomi_checklist LIKE ? OR nomi_italiani LIKE ? '
            'OR nomi_siciliani LIKE ? OR famiglia LIKE ? OR genere LIKE ?)',
          );
          args.addAll(List.filled(6, '%$t%'));
        }
      }
    }
    if (categories != null && categories.isNotEmpty) {
      where.add('categoria IN (${categories.map((_) => '?').join(',')})');
      args.addAll(categories.map((c) => c.code));
    }
    List<Map<String, Object?>> rows;
    try {
      rows = await _query(where, args);
    } catch (_) {
      if (!_ftsOk || tokens.isEmpty) rethrow;
      _ftsOk = false; // FTS non utilizzabile a runtime: ripeti con LIKE
      return species(query: query, categories: categories);
    }
    final photos = await _photos(rows.map((r) => r['key'] as int).toList());
    return rows
        .map((r) => Species.fromMap(r, photos[r['key']] ?? const []))
        .toList();
  }

  Future<List<Map<String, Object?>>> _query(
    List<String> where,
    List<Object?> args,
  ) => _species.query(
    'species',
    where: where.isEmpty ? null : where.join(' AND '),
    whereArgs: args,
    orderBy: 'ordine_sicurezza, nome_scientifico COLLATE NOCASE',
  );

  Future<Species?> speciesById(int id) async {
    final rows = await _species.query(
      'species',
      where: 'key = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final photos = await _photos([id]);
    return Species.fromMap(rows.first, photos[id] ?? const []);
  }

  /// Specie di esempio per lo StubClassifier: due dell'elenco legale, un mortale, un tossico, un'altra.
  Future<List<int>> stubCandidateIds() async {
    Future<List<int>> pick(String cat, int n) async => (await _species.rawQuery(
      'SELECT key FROM species WHERE categoria = ? ORDER BY nome_scientifico LIMIT ?',
      [cat, n],
    )).map((r) => r['key'] as int).toList();
    final ok = await pick('commestibile_sicilia', 3);
    return [
      ...ok.take(1),
      ...await pick('mortale', 1),
      ...ok.skip(1),
      ...await pick('tossico', 1),
    ];
  }

  // ---- Diario ----

  /// Salva la raccolta copiando le foto in una cartella stabile (le foto della camera stanno
  /// nella cache e il sistema può cancellarle).
  Future<int> addDiary({
    int? speciesId,
    String? note,
    required List<String> photos,
    double? lat,
    double? lon,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'diario'));
    await dir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final saved = <String>[];
    for (var i = 0; i < photos.length; i++) {
      final dest = p.join(dir.path, '${stamp}_$i${p.extension(photos[i])}');
      await File(photos[i]).copy(dest);
      saved.add(dest);
    }
    return _diary.insert('diary', {
      'created_at': DateTime.now().toIso8601String(),
      'species_id': speciesId,
      'note': note,
      'photos': saved.join('|'),
      'lat': lat,
      'lon': lon,
    });
  }

  Future<List<DiaryEntry>> diary() async {
    final rows = await _diary.query('diary', orderBy: 'created_at DESC');
    return rows
        .map(
          (r) => DiaryEntry(
            id: r['id'] as int,
            createdAt: DateTime.parse(r['created_at'] as String),
            speciesId: r['species_id'] as int?,
            note: r['note'] as String?,
            photos: ((r['photos'] as String?) ?? '')
                .split('|')
                .where((x) => x.isNotEmpty)
                .toList(),
            lat: (r['lat'] as num?)?.toDouble(),
            lon: (r['lon'] as num?)?.toDouble(),
          ),
        )
        .toList();
  }

  Future<void> deleteDiary(DiaryEntry e) async {
    await _diary.delete('diary', where: 'id = ?', whereArgs: [e.id]);
    for (final f in e.photos) {
      try {
        await File(f).delete();
      } catch (_) {}
    }
  }
}
