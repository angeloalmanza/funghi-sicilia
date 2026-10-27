import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/app_db.dart';
import '../theme.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.db});
  final AppDb db;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late Future<List<(DiaryEntry, String?)>> _future = _load();

  Future<List<(DiaryEntry, String?)>> _load() async {
    final entries = await widget.db.diary();
    return [
      for (final e in entries)
        (
          e,
          e.speciesId == null
              ? null
              : (await widget.db.speciesById(e.speciesId!))?.title,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return FutureBuilder<List<(DiaryEntry, String?)>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data!;
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmarks_outlined, size: 48, color: p.inkSoft),
                  const SizedBox(height: 12),
                  Text(
                    'Nessuna raccolta salvata',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dopo un\'analisi, tocca "Salva nel diario" per ricordare foto, nota e posizione.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.inkSoft, height: 1.35),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final (e, name) = rows[i];
            final when = e.createdAt.toString().substring(0, 16);
            final coords = e.lat == null
                ? null
                : '${e.lat!.toStringAsFixed(5)}, ${e.lon!.toStringAsFixed(5)}';
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: e.photos.isEmpty
                        ? Icon(Icons.eco_outlined, color: p.inkSoft)
                        : Image.file(
                            File(e.photos.first),
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            errorBuilder: (_, _, _) =>
                                Icon(Icons.eco_outlined, color: p.inkSoft),
                          ),
                  ),
                ),
                title: Text(
                  name ?? 'Non identificato',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    when,
                    '${e.photos.length} foto',
                    if (e.note != null) e.note!,
                    if (coords != null) 'GPS $coords (tocca per copiare)',
                  ].join('\n'),
                  style: TextStyle(color: p.inkSoft, height: 1.35),
                ),
                isThreeLine: true,
                onTap: coords == null
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: coords));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coordinate copiate')),
                        );
                      },
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await widget.db.deleteDiary(e);
                    setState(() => _future = _load());
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
