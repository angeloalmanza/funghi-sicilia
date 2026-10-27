/// Un candidato restituito dal classificatore.
class Prediction {
  const Prediction(this.speciesId, this.probability);

  /// `key` della specie nel DB, oppure [otherId] per la classe "altro / non riconosciuto".
  final int speciesId;
  final double probability;

  static const otherId = -1;
  bool get isOther => speciesId == otherId;
}

/// Interfaccia del riconoscitore on-device. L'implementazione TFLite
/// arriverà dopo; l'app dipende solo da questa interfaccia.
abstract class Classifier {
  /// Analizza più foto dello stesso fungo e restituisce al massimo [k]
  /// candidati ordinati per probabilità decrescente (risultati delle singole
  /// foto combinati). Può includere [Prediction.otherId].
  Future<List<Prediction>> classify(List<String> imagePaths, {int k = 5});

  /// Sotto questa probabilità del primo candidato l'esito è "non riconosciuto".
  double get minConfidence => 0.5;

  /// Probabilità minima di una specie pericolosa per far scattare l'avviso rosso.
  double get dangerAlertProb => 0.05;
}

/// Stub: restituisce candidati fissi (id specie reali del DB), solo per provare l'interfaccia.
class StubClassifier implements Classifier {
  StubClassifier(this.candidateIds);
  final List<int> candidateIds;

  @override
  double get minConfidence => 0.5;

  @override
  double get dangerAlertProb => 0.05;

  @override
  Future<List<Prediction>> classify(
    List<String> imagePaths, {
    int k = 5,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    const probs = [0.34, 0.22, 0.15, 0.09, 0.05];
    final out = <Prediction>[
      for (var i = 0; i < candidateIds.length && i < probs.length; i++)
        Prediction(candidateIds[i], probs[i]),
      const Prediction(Prediction.otherId, 0.15),
    ]..sort((a, b) => b.probability.compareTo(a.probability));
    return out.take(k).toList();
  }
}
