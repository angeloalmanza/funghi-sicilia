import 'package:flutter/material.dart';

import '../models/key_traits.dart';
import '../models/species.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SpeciesDetailScreen extends StatelessWidget {
  const SpeciesDetailScreen({super.key, required this.species});
  final Species species;

  @override
  Widget build(BuildContext context) {
    final s = species;
    final p = Palette.of(context);
    final sheet = s.sheet;
    String? str(String k) => (sheet[k] as String?)?.trim().isEmpty ?? true
        ? null
        : (sheet[k] as String).trim();

    final summary = cleanWiki(str('riassunto') ?? str('descrizione'));
    final englishDesc = summary.isEmpty
        ? cleanWiki(str('descrizione_en'), maxChars: 700)
        : '';
    final habitat = cleanWiki(
      str('habitat') ?? str('habitat_en'),
      maxChars: 600,
    );
    final similar = cleanWiki(
      str('specie_simili') ?? str('specie_simili_en'),
      maxChars: 700,
    );
    final hasDescription =
        summary.isNotEmpty ||
        englishDesc.isNotEmpty ||
        habitat.isNotEmpty ||
        similar.isNotEmpty;
    final hasTox =
        s.syndrome != null ||
        s.latency != null ||
        s.symptoms != null ||
        s.toxNote != null;
    final traits = s.keyTraits;
    final hasCommon = s.italianNames.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: s.photos.isEmpty ? 0 : 340,
            backgroundColor: p.paper,
            foregroundColor: s.photos.isEmpty ? p.ink : Colors.white,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: s.photos.isEmpty
                ? null
                : FlexibleSpaceBar(background: _HeroGallery(species: s)),
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(
                  alpha: s.photos.isEmpty ? 0 : 0.35,
                ),
                child: BackButton(
                  color: s.photos.isEmpty ? p.ink : Colors.white,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            sliver: SliverList.list(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: CategoryBadge(s.category, large: true),
                ),
                const SizedBox(height: 12),
                Text(
                  hasCommon ? s.title : s.scientificName,
                  style: hasCommon
                      ? serif(size: 32, color: p.ink)
                      : serif(size: 30, italic: true, color: p.ink),
                ),
                if (hasCommon)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      s.scientificName,
                      style: serif(
                        size: 20,
                        weight: 400,
                        italic: true,
                        color: p.inkSoft,
                      ),
                    ),
                  ),
                if (s.family != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Famiglia ${s.family}',
                      style: TextStyle(color: p.inkSoft, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 18),
                // Il riquadro compare solo per le specie da NON raccogliere
                if (s.doNotPick) ...[
                  _AdviceBox(species: s),
                  const SizedBox(height: 20),
                ],
                _Section(
                  title: 'Come riconoscerlo',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (traits.isEmpty)
                        Text(
                          'Caratteri non riportati nelle fonti consultate: confronta con le foto e con la scheda descrittiva.',
                          style: TextStyle(color: p.inkSoft, height: 1.4),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final t in traits) TraitChip(t)],
                        ),
                      if (traits.isNotEmpty && traits.any((t) => t.alert))
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'La volva alla base del gambo si vede solo estraendo il fungo intero.',
                            style: TextStyle(
                              color: p.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _Section(
                  title: 'Sosia pericolosi',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (s.lookalikes.isEmpty && s.lookalikeNote == null)
                        Text(
                          'Nessun sosia riportato nelle fonti consultate. Non significa che non esistano.',
                          style: TextStyle(color: p.inkSoft, height: 1.4),
                        ),
                      for (final l in s.lookalikes) _LookalikeCard(l),
                      if (s.lookalikeNote != null)
                        Text(
                          s.lookalikeNote!,
                          style: const TextStyle(height: 1.4),
                        ),
                    ],
                  ),
                ),
                if (hasTox)
                  _Section(
                    title: 'Tossicità',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.dangerBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (s.syndrome != null)
                            _kv(p, 'Sindrome', s.syndrome!),
                          if (s.latency != null) _kv(p, 'Latenza', s.latency!),
                          if (s.symptoms != null)
                            _kv(p, 'Sintomi', s.symptoms!),
                          if (s.toxNote != null)
                            Text(
                              s.toxNote!,
                              style: const TextStyle(height: 1.4),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (s.rules.isNotEmpty)
                  _Section(
                    title: 'Regole di raccolta',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.warnBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final r in s.rules)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '• $r',
                                style: const TextStyle(height: 1.4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (s.italianNames.isNotEmpty ||
                    s.sicilianNames.isNotEmpty ||
                    s.checklistNames.isNotEmpty)
                  _Section(
                    title: 'Nomi',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (s.italianNames.isNotEmpty)
                          _kv(p, 'Italiano', s.italianNames.join(', ')),
                        if (s.sicilianNames.isNotEmpty)
                          _kv(p, 'Siciliano', s.sicilianNames.join(', ')),
                        if (s.checklistNames.isNotEmpty)
                          _kv(
                            p,
                            'Checklist siciliana',
                            s.checklistNames.join('; '),
                          ),
                      ],
                    ),
                  ),
                if (hasDescription)
                  _Collapsible(
                    title: 'Scheda descrittiva',
                    subtitle: 'Da Wikipedia, solo informativa',
                    children: [
                      if (summary.isNotEmpty)
                        Text(summary, style: const TextStyle(height: 1.45)),
                      if (englishDesc.isNotEmpty)
                        Text(
                          '$englishDesc (en)',
                          style: const TextStyle(height: 1.45),
                        ),
                      if (habitat.isNotEmpty) _kv(p, 'Habitat', habitat),
                      if (similar.isNotEmpty) _kv(p, 'Specie simili', similar),
                      Text(
                        'Testo di supporto: non usarlo per decidere la commestibilità.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          color: p.inkSoft,
                        ),
                      ),
                    ],
                  ),
                if (s.sources.isNotEmpty)
                  _Collapsible(
                    title: 'Fonti della classificazione',
                    subtitle: s.edibilityText,
                    children: [
                      for (final src in s.sources)
                        SelectableText(
                          '• ${src.title}${src.url != null ? '\n  ${src.url}' : ''}'
                          '${src.note != null ? '\n  ${src.note}' : ''}',
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                    ],
                  ),
                const SizedBox(height: 18),
                Text(
                  s.disclaimer,
                  style: TextStyle(color: p.inkSoft, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _kv(Palette p, String k, String v) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$k  ',
          style: TextStyle(color: p.inkSoft, fontWeight: FontWeight.w600),
        ),
        TextSpan(text: v),
      ],
    ),
    style: const TextStyle(height: 1.4),
  ),
);

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _Collapsible extends StatelessWidget {
  const _Collapsible({
    required this.title,
    required this.children,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!, style: const TextStyle(fontSize: 12.5)),
          children: [
            for (final c in children)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: c),
          ],
        ),
      ),
    ),
  );
}

class _AdviceBox extends StatelessWidget {
  const _AdviceBox({required this.species});
  final Species species;

  @override
  Widget build(BuildContext context) {
    final s = species;
    final stop = s.doNotPick;
    final p = Palette.of(context);
    final fg = stop ? p.danger : p.warn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: stop ? p.dangerBg : p.warnBg,
        border: Border.all(color: fg, width: 2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                stop ? Icons.front_hand_rounded : Icons.fact_check_outlined,
                color: fg,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if (!s.label.toUpperCase().contains(s.edibilityText.toUpperCase()) &&
              s.edibilityText != s.category.label) ...[
            const SizedBox(height: 8),
            Text(
              s.edibilityText,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
          ],
          if (!stop) ...[
            const SizedBox(height: 8),
            Text(
              'Anche se è nell\'elenco legale, l\'identificazione da foto non basta: verifica tutti i caratteri.',
              style: TextStyle(color: p.ink, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _LookalikeCard extends StatelessWidget {
  const _LookalikeCard(this.l);
  final Lookalike l;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.dangerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: p.danger, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.with_, style: serif(size: 17, italic: true, color: p.ink)),
          if (l.severity != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Gravità: ${l.severity}',
                style: TextStyle(
                  color: p.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          if (l.characters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Come distinguerli',
              style: TextStyle(
                color: p.inkSoft,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            for (final c in l.characters)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('• $c', style: const TextStyle(height: 1.35)),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Caratteri distintivi non riportati nelle fonti consultate.',
                style: TextStyle(height: 1.35),
              ),
            ),
          if (l.warning != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.warning!, style: const TextStyle(height: 1.35)),
            ),
        ],
      ),
    );
  }
}

class _HeroGallery extends StatefulWidget {
  const _HeroGallery({required this.species});
  final Species species;

  @override
  State<_HeroGallery> createState() => _HeroGalleryState();
}

class _HeroGalleryState extends State<_HeroGallery> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final photos = widget.species.photos;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _PhotoViewer(photo: photos[i])),
            ),
            child: Hero(
              tag: photos[i].asset,
              child: SpeciesPhotoView(
                widget.species,
                index: i,
                cacheWidth: 1100,
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.25, 0.6, 1],
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: IgnorePointer(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    _credit(photos[_i]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    for (var k = 0; k < photos.length; k++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(left: 5),
                        width: k == _i ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: k == _i ? Colors.white : Colors.white54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _credit(SpeciesPhoto p) =>
    '© ${p.author ?? 'autore sconosciuto'} · ${p.licenseShort}';

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo});
  final SpeciesPhoto photo;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    body: Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Hero(tag: photo.asset, child: Image.asset(photo.asset)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            '${_credit(photo)}${photo.source != null ? '\n${photo.source}' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
