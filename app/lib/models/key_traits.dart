import 'species.dart';

/// Un carattere distintivo per riconoscere il fungo a colpo d'occhio.
class KeyTrait {
  const KeyTrait(this.label, this.value, {this.alert = false});
  final String label;
  final String value;

  /// Carattere che nelle specie pericolose conta di più (es. volva alla base del gambo).
  final bool alert;
}

// Traduzioni dei termini inglesi della scheda (Wikipedia en) nel lessico micologico italiano.
// Sono vocabolari chiusi: nessun testo viene inventato, solo tradotto.
const _hymenium = {
  'gills': 'lamelle',
  'pores': 'pori',
  'ridges': 'pieghe',
  'smooth': 'liscio',
  'teeth': 'aculei',
};
const _cap = {
  'convex': 'convesso',
  'offset': 'eccentrico',
  'conical': 'conico',
  'flat': 'piano',
  'depressed': 'depresso',
  'infundibuliform': 'a imbuto',
  'campanulate': 'campanulato',
  'umbonate': 'umbonato',
  'ovate': 'ovoidale',
  'semisferico': 'semisferico',
  'umbonato-acuto': 'umbonato',
  'umbonato-ottuso': 'umbonato',
  'conico-ottuso': 'conico',
  'conico-acuto': 'conico',
  'campanulato-conico': 'campanulato',
  'ovoideo': 'ovoidale',
  'umbellato': 'a ombrello',
};
const _spore = {
  'white': 'bianca',
  'cream': 'crema',
  'pink': 'rosa',
  'brown': 'marrone',
  'yellow': 'gialla',
  'olive': 'oliva',
  'olive-brown': 'bruno-oliva',
  'reddish-brown': 'bruno-rossastra',
  'purple-brown': 'bruno-porpora',
  'blackish-brown': 'bruno-nerastra',
  'tan': 'camoscio',
  'ochre': 'ocra',
  'salmon': 'salmone',
};
const _ecology = {
  'mycorrhizal': 'micorrizico',
  'saprotrophic': 'saprofita',
  'parasitic': 'parassita',
};

// Alberi e ambienti riconoscibili nel testo dell'habitat (cercati come radice della parola).
const _habitats = <(String, String)>[
  ('betull', 'betulla'),
  ('leccio', 'leccio'),
  ('lecci', 'leccio'),
  ('sughera', 'sughera'),
  ('querc', 'quercia'),
  ('roverell', 'roverella'),
  ('cerro', 'cerro'),
  ('castagn', 'castagno'),
  ('fagg', 'faggio'),
  ('abete', 'abete'),
  ('abeti', 'abete'),
  ('pino', 'pino'),
  ('pini', 'pino'),
  ('cedr', 'cedro'),
  ('conifer', 'conifere'),
  ('latifogli', 'latifoglie'),
  ('eucalipt', 'eucalipto'),
  ('pioppo', 'pioppo'),
  ('pioppi', 'pioppo'),
  ('olivo', 'olivo'),
  ('ulivo', 'olivo'),
  ('ferula', 'ferula'),
  ('eringio', 'eringio'),
  ('cisto', 'cisto'),
  ('nocciol', 'nocciolo'),
  ('ontan', 'ontano'),
  ('salice', 'salice'),
  ('salici', 'salice'),
  ('ginepr', 'ginepro'),
  ('cipress', 'cipresso'),
  ('frassin', 'frassino'),
  ('tiglio', 'tiglio'),
  ('platan', 'platano'),
  ('prato', 'prato'),
  ('prati', 'prato'),
  ('pascol', 'pascolo'),
  ('legno', 'legno'),
  ('ceppaie', 'ceppaie'),
  ('dune', 'dune'),
];

extension KeyTraits on Species {
  String? _s(String k) {
    final v = (sheet[k] as String?)?.trim();
    if (v == null || v.isEmpty) return null;
    final l = v.toLowerCase();
    return (l == 'no' || l == 'nd' || l == 'n.d.') ? null : v;
  }

  String? _pick(String key, Map<String, String> en) {
    final it = _s(key);
    if (it != null) return en[it] ?? it;
    final e = _s('${key}_en');
    return e == null ? null : (en[e.toLowerCase()] ?? en[e] ?? e);
  }

  /// Caratteri chiave presi dai dati strutturati della scheda (nessun valore inventato).
  List<KeyTrait> get keyTraits {
    final out = <KeyTrait>[];

    final hym = _pick('imenio', _hymenium);
    if (hym != null) {
      final att = _s('lamelle');
      out.add(
        KeyTrait(
          'Sotto',
          hym == 'lamelle' && att != null ? 'lamelle $att' : hym,
        ),
      );
    }
    final cap = _pick('cappello', _cap);
    if (cap != null) out.add(KeyTrait('Cappello', cap));

    final veil = _s('velo')?.toLowerCase();
    if (veil != null) {
      if (veil == 'nudo') {
        out.add(const KeyTrait('Gambo', 'senza anello né volva'));
      } else {
        out.add(KeyTrait('Gambo', veil, alert: veil.contains('volva')));
      }
    }
    final spore = _pick('sporata', _spore);
    if (spore != null) out.add(KeyTrait('Sporata', spore));

    final flesh = _s('carne')?.toLowerCase();
    if (flesh != null) {
      out.add(
        KeyTrait(
          'Carne',
          flesh == 'virante'
              ? 'vira al taglio'
              : flesh == 'immutabile'
              ? 'immutata'
              : flesh,
        ),
      );
    }
    final eco = _pick('ecologia', _ecology);
    if (eco != null) out.add(KeyTrait('Ecologia', eco));

    final trees = _trees();
    if (trees.isNotEmpty) out.add(KeyTrait('Habitat', trees.join(', ')));
    return out;
  }

  List<String> _trees() {
    final text = (_s('habitat') ?? '').toLowerCase();
    if (text.isEmpty) return const [];
    final found = <String>[];
    for (final (root, name) in _habitats) {
      if (text.contains(root) && !found.contains(name)) found.add(name);
      if (found.length == 3) break;
    }
    return found;
  }

  /// Per le specie senza dati strutturati: la prima frase del riassunto della scheda.
  String? get fallbackBlurb {
    final raw = _s('riassunto') ?? _s('descrizione');
    if (raw == null) return null;
    final t = cleanWiki(raw, maxChars: 400).replaceAll('\n', ' ').trim();
    if (t.isEmpty) return null;
    final m = RegExp(r'^(.{40,170}?[.!?])(\s|$)').firstMatch(t);
    final s =
        m?.group(1) ??
        (t.length > 140 ? '${t.substring(0, 140).trimRight()}…' : t);
    return s;
  }
}
