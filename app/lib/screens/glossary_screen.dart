import 'dart:async';

import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../models/species.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'species_detail_screen.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key, required this.db});
  final AppDb db;

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _query = '';
  Category? _filter;
  Timer? _debounce;
  late Future<List<Species>> _future = _load();

  static final _filters = Category.values
      .where((c) => c != Category.sconosciuta)
      .toList();

  Future<List<Species>> _load() => widget.db.species(
    query: _query,
    categories: _filter == null ? null : {_filter!},
  );

  void _refresh() => setState(() => _future = _load());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cerca nome italiano, scientifico o siciliano',
            ),
            onChanged: (v) {
              _query = v;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), _refresh);
            },
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterPill(
                label: 'Tutte',
                selected: _filter == null,
                onTap: () {
                  _filter = null;
                  _refresh();
                },
              ),
              for (final c in _filters)
                _FilterPill(
                  label: c.label,
                  dot: c.color,
                  selected: _filter == c,
                  onTap: () {
                    _filter = _filter == c ? null : c;
                    _refresh();
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Species>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Errore database: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data!;
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Nessuna specie trovata. Prova con il nome scientifico o con una parte del nome.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.inkSoft),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: list.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Text(
                      '${list.length} specie · pericolose in cima',
                      style: TextStyle(
                        color: p.inkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }
                  return SpeciesCard(species: list[i - 1]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? cs.primary : p.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? cs.primary : p.outline),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                if (dot != null) ...[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? cs.onPrimary : p.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SpeciesCard extends StatelessWidget {
  const SpeciesCard({super.key, required this.species});
  final Species species;

  @override
  Widget build(BuildContext context) {
    final s = species;
    final p = Palette.of(context);
    final theme = Theme.of(context);
    final hasCommon = s.italianNames.isNotEmpty;
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SpeciesDetailScreen(species: s)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(aspectRatio: 16 / 10, child: SpeciesPhotoView(s)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 64,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  right: 12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CategoryBadge(s.category),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasCommon ? s.title : s.scientificName,
                    style: hasCommon
                        ? theme.textTheme.titleLarge
                        : serif(size: 22, italic: true, color: p.ink),
                  ),
                  if (hasCommon)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        s.scientificName,
                        style: serif(
                          size: 15,
                          weight: 400,
                          italic: true,
                          color: p.inkSoft,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TraitChips(s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
