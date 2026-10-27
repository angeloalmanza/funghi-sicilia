import 'dart:convert';

import 'package:flutter/material.dart';

/// Categoria di sicurezza (colonna `categoria` del DB, ordinata per `ordine_sicurezza`).
enum Category {
  mortale('mortale', 'Mortale', Color(0xFF111111), true, Icons.dangerous),
  tossicoGrave(
    'tossico_grave',
    'Tossico grave',
    Color(0xFF7F0F0A),
    true,
    Icons.warning_rounded,
  ),
  tossico(
    'tossico',
    'Tossico',
    Color(0xFFB3261E),
    true,
    Icons.warning_amber_rounded,
  ),
  vietato(
    'vietato_per_legge',
    'Vietato per legge',
    Color(0xFF6A1B9A),
    true,
    Icons.block,
  ),
  condizionato(
    'condizionato',
    'Condizionato: non raccogliere',
    Color(0xFFB85C00),
    true,
    Icons.rule,
  ),
  commestibileItalia(
    'commestibile_italia_non_sicilia',
    'Non nell\'elenco siciliano',
    Color(0xFFF2B63D),
    false,
    Icons.help_outline,
  ),
  commestibileSicilia(
    'commestibile_sicilia',
    'Commestibile',
    Color(0xFF2E6B3B),
    false,
    null,
  ),
  sconosciuta(
    'sconosciuta',
    'Sconosciuta',
    Color(0xFF607D8B),
    false,
    Icons.help_outline,
  );

  const Category(this.code, this.label, this.color, this.dangerous, this.icon);
  final String code;
  final String label;
  final Color color;
  final IconData? icon;

  /// Tossica, mortale, vietata o condizionata: l'app non deve mai suggerire la raccolta.
  final bool dangerous;

  static Category parse(String? code) => Category.values.firstWhere(
    (c) => c.code == code,
    orElse: () => Category.sconosciuta,
  );
}

class Lookalike {
  Lookalike({
    required this.with_,
    required this.characters,
    this.warning,
    this.severity,
  });
  final String with_;
  final List<String> characters;
  final String? warning;
  final String? severity;

  factory Lookalike.fromJson(Map<String, dynamic> j) => Lookalike(
    with_: (j['con'] as String?) ?? '',
    characters: _strings(j['caratteri_discriminanti']),
    warning: j['avvertenze'] as String?,
    severity: j['gravita'] as String?,
  );
}

class SourceRef {
  SourceRef({required this.title, this.url, this.note});
  final String title;
  final String? url;
  final String? note;
}

class SpeciesPhoto {
  SpeciesPhoto({required this.asset, this.author, this.license, this.source});

  /// Percorso asset (assets/photos/KEY/FILE.webp).
  final String asset;
  final String? author;
  final String? license;
  final String? source;

  /// Sigla breve della licenza Creative Commons dall'URL (es. "CC BY-NC 4.0").
  String get licenseShort {
    final l = license ?? '';
    final m = RegExp(
      r'creativecommons\.org/(licenses/([a-z\-]+)/([\d.]+)|publicdomain/zero)',
    ).firstMatch(l);
    if (m == null) return l;
    if (m.group(2) == null) return 'CC0';
    return 'CC ${m.group(2)!.toUpperCase()} ${m.group(3)}';
  }
}

/// Nomi da una lista JSON di stringhe oppure di oggetti {"nome": ..., "fonte": ...}.
List<String> _names(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is String && e.isNotEmpty)
            e
          else if (e is Map &&
              e['nome'] is String &&
              (e['nome'] as String).isNotEmpty)
            e['nome'] as String,
      ]
    : const [];

List<String> _strings(Object? v) => v is List
    ? v.whereType<String>().where((s) => s.isNotEmpty).toList()
    : const [];

Object? _json(Object? v) {
  if (v is! String || v.isEmpty) return null;
  try {
    return jsonDecode(v);
  } catch (_) {
    return null;
  }
}

class Species {
  Species({
    required this.id,
    required this.scientificName,
    required this.category,
    required this.label,
    required this.advice,
    required this.safetyOrder,
    required this.edibilityText,
    required this.disclaimer,
    this.checklistNames = const [],
    this.family,
    this.sources = const [],
    this.rules = const [],
    this.syndrome,
    this.latency,
    this.symptoms,
    this.toxNote,
    this.lookalikes = const [],
    this.lookalikeNote,
    this.italianNames = const [],
    this.sicilianNames = const [],
    this.sheet = const {},
    this.photos = const [],
  });

  /// `key` GBIF della specie (anche id dell'etichetta del classificatore).
  final int id;
  final String scientificName;
  final Category category;
  final String label; // etichetta breve, es. "NON RACCOGLIERE (MORTALE)"
  final String advice; // NON RACCOGLIERE | RACCOGLIBILE SOLO CON CONTROLLO ISPETTORATO MICOLOGICO
  final int safetyOrder;
  final String edibilityText;
  final String disclaimer;
  final List<String> checklistNames;
  final String? family;
  final List<SourceRef> sources;
  final List<String> rules;
  final String? syndrome;
  final String? latency;
  final String? symptoms;
  final String? toxNote;
  final List<Lookalike> lookalikes;
  final String? lookalikeNote;
  final List<String> italianNames;
  final List<String> sicilianNames;
  final Map<String, dynamic> sheet;
  final List<SpeciesPhoto> photos;

  String get title =>
      italianNames.isNotEmpty ? italianNames.first : scientificName;
  bool get doNotPick =>
      advice.trim().toUpperCase().startsWith('NON RACCOGLIERE');

  factory Species.fromMap(Map<String, Object?> m, List<SpeciesPhoto> photos) {
    List<String> list(String k) => _strings(_json(m[k] as String?));
    final srcs = <SourceRef>[];
    final rawSrc = _json(m['fonti_commestibilita'] as String?);
    if (rawSrc is List) {
      for (final s in rawSrc.whereType<Map>()) {
        srcs.add(
          SourceRef(
            title: (s['titolo'] as String?) ?? (s['fonte'] as String?) ?? '',
            url: s['url'] as String?,
            note: s['nota'] as String?,
          ),
        );
      }
    }
    final look = <Lookalike>[];
    final rawLook = _json(m['sosia'] as String?);
    if (rawLook is List) {
      for (final l in rawLook.whereType<Map>()) {
        look.add(Lookalike.fromJson(l.cast<String, dynamic>()));
      }
    }
    final sheetRaw = _json(m['scheda'] as String?);
    String? s(String k) => (m[k] as String?)?.trim().isEmpty ?? true
        ? null
        : (m[k] as String).trim();
    return Species(
      id: m['key'] as int,
      scientificName: m['nome_scientifico'] as String,
      category: Category.parse(m['categoria'] as String?),
      label: (m['etichetta'] as String?) ?? 'NON RACCOGLIERE',
      // Dato mancante => prudenza.
      advice: (m['consiglio'] as String?) ?? 'NON RACCOGLIERE',
      safetyOrder: (m['ordine_sicurezza'] as int?) ?? 99,
      edibilityText: (m['commestibilita'] as String?) ?? 'Sconosciuta',
      disclaimer: (m['disclaimer'] as String?) ?? 'Supporto informativo, non sostituisce il controllo dell\'Ispettorato Micologico ASP.',
      checklistNames: list('nomi_checklist'),
      family: s('famiglia'),
      sources: srcs,
      rules: list('regole_raccolta'),
      syndrome: s('sindrome'),
      latency: s('latenza'),
      symptoms: s('sintomi'),
      toxNote: s('note_tossicita'),
      lookalikes: look,
      lookalikeNote: s('sosia_nota'),
      italianNames: _names(_json(m['nomi_italiani'] as String?)),
      sicilianNames: _names(_json(m['nomi_siciliani'] as String?)),
      sheet: sheetRaw is Map ? sheetRaw.cast<String, dynamic>() : const {},
      photos: photos,
    );
  }
}

/// Ripulisce il markup Wikipedia residuo (link, immagini, template) per mostrarlo come testo semplice.
String cleanWiki(String? raw, {int maxChars = 900}) {
  if (raw == null) return '';
  var t = raw
      .split('\n')
      .where((l) {
        final x = l.trimLeft().toLowerCase();
        return !(x.startsWith('image:') ||
            x.startsWith('file:') ||
            x.startsWith('immagine:') ||
            x.startsWith('|'));
      })
      .join('\n');
  t = t.replaceAll(
    RegExp(r'\[\[(?:File|Image|Immagine):[^\]]*\]\]', caseSensitive: false),
    '',
  );
  t = t.replaceAllMapped(
    RegExp(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]'),
    (m) => m.group(1) ?? '',
  );
  t = t
      .replaceAll(RegExp(r'\{\{[^}]*\}\}'), '')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  t = t
      .replaceAll(RegExp(r"'{2,}"), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (t.length <= maxChars) return t;
  final cut = t.substring(0, maxChars);
  final end = cut.lastIndexOf(RegExp(r'[.!?]\s'));
  return '${end > maxChars ~/ 2 ? cut.substring(0, end + 1) : cut}…';
}
