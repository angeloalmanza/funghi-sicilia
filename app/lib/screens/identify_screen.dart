import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../db/app_db.dart';
import '../ml/classifier.dart';
import '../models/species.dart';
import '../services/location.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'species_detail_screen.dart';

const minPhotos = 2;
const maxPhotos = 5;

const _steps = <(String, String, IconData)>[
  (
    'Sopra',
    'Il cappello visto dall\'alto, intero, con luce naturale.',
    Icons.expand_less,
  ),
  (
    'Sotto',
    'Capovolgi il fungo: lamelle, pori o aculei sotto il cappello.',
    Icons.flip,
  ),
  (
    'Gambo',
    'Estrai il fungo intero senza tagliarlo: serve la base, per la volva.',
    Icons.straighten,
  ),
  (
    'Taglio',
    'Taglia il gambo a metà e fotografa la carne: cambia colore?',
    Icons.content_cut,
  ),
  ('Habitat', 'Il terreno intorno e gli alberi vicini.', Icons.park_outlined),
];

/// Verifica a mano: la foto non vede questi caratteri.
const _checks = [
  'Sotto il cappello: lamelle, pori o aculei? Colore?',
  'Base del gambo: c\'è una volva (sacco)? Estrai il fungo intero, non tagliarlo.',
  'Anello sul gambo? Reticolo o striature?',
  'Taglio della carne: cambia colore? Odore (rapa, anice, farina, inchiostro)?',
  'Su cosa cresce: legno, terra, sotto quali alberi?',
  'Sporata (cappello su carta bianca/nera per qualche ora).',
];

class IdentifyScreen extends StatefulWidget {
  const IdentifyScreen({super.key, required this.db, required this.classifier});
  final AppDb db;
  final Classifier classifier;

  @override
  State<IdentifyScreen> createState() => _IdentifyScreenState();
}

/// Un risultato: specie nota oppure `null` per "altro / non riconosciuto".
typedef _Result = (Species?, double);

class _IdentifyScreenState extends State<IdentifyScreen> {
  final _picker = ImagePicker();
  final _photos = <String>[];
  List<_Result>? _results;
  bool _busy = false;

  Future<void> _shoot() async {
    if (_photos.length >= maxPhotos) return;
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() {
      _photos.add(x.path);
      _results = null;
    });
  }

  Future<void> _analyze() async {
    setState(() => _busy = true);
    final preds = await widget.classifier.classify(List.of(_photos));
    final out = <_Result>[];
    for (final p in preds) {
      if (p.isOther) {
        out.add((null, p.probability));
      } else {
        final s = await widget.db.speciesById(p.speciesId);
        if (s != null) out.add((s, p.probability));
      }
    }
    if (!mounted) return;
    setState(() {
      _results = out;
      _busy = false;
    });
  }

  Future<void> _save() async {
    final noteCtl = TextEditingController();
    var withGps = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Salva nel diario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noteCtl,
                decoration: const InputDecoration(
                  labelText: 'Nota (facoltativa)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Salva posizione GPS'),
                subtitle: const Text('Funziona anche senza rete'),
                value: withGps,
                onChanged: (v) => setD(() => withGps = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    ({double lat, double lon})? pos;
    if (withGps) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Cerco la posizione GPS…')),
      );
      pos = await currentPosition();
    }
    final first = _results?.firstOrNull?.$1;
    await widget.db.addDiary(
      photos: _photos,
      speciesId: first?.id,
      note: noteCtl.text.trim().isEmpty ? null : noteCtl.text.trim(),
      lat: pos?.lat,
      lon: pos?.lon,
    );
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          withGps && pos == null
              ? 'Salvato senza posizione (GPS non disponibile)'
              : 'Salvato nel diario',
        ),
      ),
    );
  }

  void _reset() => setState(() {
    _photos.clear();
    _results = null;
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final cs = Theme.of(context).colorScheme;
    final step = _photos.length < _steps.length ? _steps[_photos.length] : null;
    final ready = _photos.length >= minPhotos;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          'Fotografa lo stesso fungo',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Da $minPhotos a $maxPhotos foto, il fungo intero e non pulito. Più lati, più il risultato è affidabile.',
          style: TextStyle(color: p.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 84,
          child: Row(
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                Expanded(
                  child: _StepTile(
                    index: i,
                    photo: i < _photos.length ? _photos[i] : null,
                    isNext: i == _photos.length,
                  ),
                ),
                if (i < _steps.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: step == null
              ? Text(
                  'Hai scattato il massimo di $maxPhotos foto.',
                  key: const ValueKey('done'),
                  style: TextStyle(color: p.inkSoft),
                )
              : Container(
                  key: ValueKey(step.$1),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(step.$3, color: cs.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prossimo scatto: ${step.$1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              step.$2,
                              style: TextStyle(
                                color: p.inkSoft,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _photos.length < maxPhotos ? _shoot : null,
          icon: const Icon(Icons.photo_camera),
          label: Text(
            step == null ? 'Massimo $maxPhotos foto' : 'Scatta: ${step.$1}',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: ready && !_busy ? _analyze : null,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(
                        ready
                            ? 'Analizza ${_photos.length} foto'
                            : 'Analizza (${_photos.length}/$minPhotos foto)',
                      ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 60,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: _photos.isEmpty ? null : _reset,
                child: const Icon(Icons.restart_alt),
              ),
            ),
          ],
        ),
        if (_results != null) ..._resultWidgets(context, _results!),
      ],
    );
  }

  List<Widget> _resultWidgets(BuildContext context, List<_Result> results) {
    final p = Palette.of(context);
    final top = results.firstOrNull;
    final unrecognized =
        top == null ||
        top.$1 == null ||
        top.$2 < widget.classifier.minConfidence;
    final dangerous = results.any(
      (r) =>
          r.$1 != null &&
          r.$1!.category.dangerous &&
          r.$2 >= widget.classifier.dangerAlertProb,
    );
    final topDoNotPick = top?.$1?.doNotPick ?? false;

    // Mai un esito "commestibile": al massimo candidati da verificare.
    final Widget banner;
    if (unrecognized) {
      banner = const AlertCard(
        title: 'Non riconosciuto o poco sicuro',
        text:
            'NON RACCOGLIERE. Il fungo potrebbe non essere tra quelli dell\'app.',
      );
    } else if (dangerous || topDoNotPick) {
      banner = const AlertCard(
        title: 'Attenzione',
        text:
            'Tra i candidati c\'è una specie tossica, mortale, vietata o non raccoglibile. '
            'NON raccogliere né mangiare.',
      );
    } else {
      banner = const AlertCard(
        kind: AlertKind.caution,
        title: 'Solo candidati, non un verdetto',
        text:
            'Verifica i caratteri qui sotto e controlla i sosia nella scheda prima di decidere.',
      );
    }

    return [
      const SizedBox(height: 24),
      Text('Candidati', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      banner,
      const SizedBox(height: 12),
      for (final (s, prob) in results)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: s == null
              ? _OtherCard(prob: prob)
              : _CandidateCard(species: s, prob: prob),
        ),
      Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(
              Icons.fact_check_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text(
              'Verifica guidata: controlla a mano',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'La foto non vede questi caratteri',
              style: TextStyle(color: p.inkSoft, fontSize: 12.5),
            ),
            initiallyExpanded: !unrecognized,
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in _checks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_box_outline_blank,
                        size: 20,
                        color: p.inkSoft,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(c, style: const TextStyle(height: 1.35)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('Salva nel diario'),
      ),
    ];
  }
}

/// Un passo della guida agli scatti: foto scattata, prossimo da fare, oppure da fare dopo.
class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.photo,
    required this.isNext,
  });
  final int index;
  final String? photo;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final cs = Theme.of(context).colorScheme;
    final (title, _, icon) = _steps[index];
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: photo == null ? p.surface : null,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isNext ? cs.primary : p.outline,
                width: isNext ? 2.5 : 1.2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: photo != null
                ? Image.file(File(photo!), fit: BoxFit.cover, cacheWidth: 240)
                : Icon(
                    isNext ? Icons.photo_camera : icon,
                    color: isNext
                        ? cs.primary
                        : p.inkSoft.withValues(alpha: 0.6),
                    size: 24,
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          maxLines: 1,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isNext || photo != null
                ? FontWeight.w700
                : FontWeight.w500,
            color: isNext ? cs.primary : p.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.species, required this.prob});
  final Species species;
  final double prob;

  @override
  Widget build(BuildContext context) {
    final s = species;
    final p = Palette.of(context);
    final hasCommon = s.italianNames.isNotEmpty;
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SpeciesDetailScreen(species: s)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SpeciesThumb(s, size: 72),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasCommon ? s.title : s.scientificName,
                          style: hasCommon
                              ? serif(size: 18, color: p.ink)
                              : serif(size: 17, italic: true, color: p.ink),
                        ),
                        if (hasCommon)
                          Text(
                            s.scientificName,
                            style: serif(
                              size: 14,
                              weight: 400,
                              italic: true,
                              color: p.inkSoft,
                            ),
                          ),
                        const SizedBox(height: 6),
                        CategoryBadge(s.category),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(prob * 100).round()}%',
                    style: serif(size: 22, color: p.ink),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: prob.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: p.surfaceAlt,
                  color: s.category.dangerous
                      ? p.danger
                      : Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 10),
              TraitChips(s, max: 4, showBlurb: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtherCard extends StatelessWidget {
  const _OtherCard({required this.prob});
  final double prob;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(Icons.help_outline, size: 36, color: p.inkSoft),
        title: const Text(
          'Altro / non riconosciuto',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'NON RACCOGLIERE',
          style: TextStyle(color: p.danger, fontWeight: FontWeight.w700),
        ),
        trailing: Text(
          '${(prob * 100).round()}%',
          style: serif(size: 22, color: p.ink),
        ),
      ),
    );
  }
}
