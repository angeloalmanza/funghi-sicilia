import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'classifier.dart';

/// Soglie calibrate in fase di addestramento (assets/model/thresholds.json).
class Thresholds {
  const Thresholds({required this.unknownBelow, required this.dangerAlertProb});

  /// Sotto questa probabilità del primo candidato l'esito è "non riconosciuto".
  final double unknownBelow;

  /// Se una specie pericolosa ha almeno questa probabilità, avviso rosso.
  final double dangerAlertProb;

  factory Thresholds.fromJson(Map<String, dynamic> j) => Thresholds(
    unknownBelow: (j['unknown_below'] as num).toDouble(),
    dangerAlertProb: (j['danger_alert_prob'] as num).toDouble(),
  );
}

/// Classificatore on-device (TFLite, EfficientNet-B0). Nessuna rete.
/// Preprocessing identico all'addestramento: foto intera ridimensionata a 224x224 (senza ritaglio),
/// RGB 0-255 float32 (la normalizzazione è dentro il modello).
/// Più foto: media delle probabilità.
class TfliteClassifier implements Classifier {
  TfliteClassifier._(this._interp, this._classes, this.thresholds, this._size);

  final Interpreter _interp;

  /// Ordine delle classi del modello: speciesKey come stringa, oppure "altro".
  final List<String> _classes;
  final int _size;
  final Thresholds thresholds;

  static Future<TfliteClassifier> load() async {
    final labels = jsonDecode(
      await rootBundle.loadString('assets/model/labels.json'),
    ) as Map<String, dynamic>;
    final thr = jsonDecode(
      await rootBundle.loadString('assets/model/thresholds.json'),
    ) as Map<String, dynamic>;
    final interp = await Interpreter.fromAsset(
      'assets/model/model.tflite',
      options: InterpreterOptions()..threads = 2,
    );
    return TfliteClassifier._(
      interp,
      (labels['classes'] as List).cast<String>(),
      Thresholds.fromJson(thr),
      (labels['input_size'] as num).toInt(),
    );
  }

  @override
  double get minConfidence => thresholds.unknownBelow;

  @override
  double get dangerAlertProb => thresholds.dangerAlertProb;

  @override
  Future<List<Prediction>> classify(
    List<String> imagePaths, {
    int k = 5,
  }) async {
    if (imagePaths.isEmpty) return const [];
    final size = _size;
    final sum = List<double>.filled(_classes.length, 0);
    var n = 0;
    for (final path in imagePaths) {
      final rgb = await Isolate.run(() => _preprocess(path, size));
      if (rgb == null) continue;
      final input = Float32List(size * size * 3);
      for (var i = 0; i < input.length; i++) {
        input[i] = rgb[i].toDouble();
      }
      final output = List.generate(
        1,
        (_) => List<double>.filled(_classes.length, 0),
      );
      _interp.run(input.reshape([1, size, size, 3]), output);
      final p = output[0];
      for (var i = 0; i < p.length; i++) {
        sum[i] += p[i];
      }
      n++;
    }
    if (n == 0) return const [];
    final order = List<int>.generate(_classes.length, (i) => i)
      ..sort((a, b) => sum[b].compareTo(sum[a]));
    return [
      for (final i in order.take(k))
        Prediction(
          _classes[i] == 'altro' ? Prediction.otherId : int.parse(_classes[i]),
          sum[i] / n,
        ),
    ];
  }
}

/// Decodifica (con orientamento EXIF) e ridimensiona a size x size; null se illeggibile.
Future<Uint8List?> _preprocess(String path, int size) async {
  final raw = await img.decodeImageFile(path);
  if (raw == null) return null;
  final im = img.bakeOrientation(raw);
  final r = img.copyResize(
    im,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
  final out = Uint8List(size * size * 3);
  var o = 0;
  for (final px in r) {
    out[o++] = px.r.toInt().clamp(0, 255);
    out[o++] = px.g.toInt().clamp(0, 255);
    out[o++] = px.b.toInt().clamp(0, 255);
  }
  return out;
}
