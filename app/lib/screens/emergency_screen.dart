import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

Future<void> _dial(String number) =>
    launchUrl(Uri(scheme: 'tel', path: number));

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Material(
          color: p.danger,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _dial('118'),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.call, color: Colors.white, size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chiama il 118',
                          style: serif(size: 24, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Emergenza sanitaria (numero unico europeo 112). Tocca per chiamare.',
                          style: TextStyle(color: Colors.white, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Icon(
              Icons.local_hospital_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 30,
            ),
            title: const Text(
              'Centro Antiveleni Niguarda (Milano)',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '02 66101029 · attivo 24 ore su 24, riferimento per le intossicazioni da funghi.\n\n'
                'Numero confermato da più fonti (ISS Epicentro, Università Cattolica, stampa), non dal sito '
                'dell\'ospedale: controllalo con una prova prima di partire. Per un\'emergenza chiama il 118.',
                style: TextStyle(color: p.inkSoft, height: 1.35),
              ),
            ),
            onTap: () => _dial('0266101029'),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'In caso di sospetta intossicazione',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        for (final t in const [
          'Chiama subito il 118 o il Centro Antiveleni, anche se stai bene: i sintomi di alcune specie '
              '(es. Amanita phalloides) compaiono dopo 6-24 ore.',
          'Non indurre il vomito e non dare bevande o rimedi casalinghi senza indicazione medica.',
          'Conserva avanzi, scarti di pulizia e vomito per l\'analisi micologica.',
          'Porta con te al Pronto Soccorso un esemplare crudo dello stesso fungo.',
          'Avvisa chi ha mangiato lo stesso piatto.',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, size: 7, color: p.danger),
                const SizedBox(width: 12),
                Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Icon(
              Icons.fact_check_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 30,
            ),
            title: const Text(
              'Ispettorato Micologico ASP',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Controllo di commestibilità gratuito per i privati. Orari e sedi cambiano ogni stagione: '
                'verifica sul sito della tua ASP.',
                style: TextStyle(color: p.inkSoft, height: 1.35),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
