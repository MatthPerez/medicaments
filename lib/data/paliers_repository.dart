import 'package:flutter/foundation.dart';

/// Un palier planifié : date cible et dose associée.
class EtapePalier {
  final DateTime date;
  final double dose;

  EtapePalier({required this.date, required this.dose});
}

class PaliersRepository extends ChangeNotifier {
  PaliersRepository._();
  static final PaliersRepository instance = PaliersRepository._();

  final Map<String, List<EtapePalier>> _paliersParMedicament = {};

  List<EtapePalier> paliersPour(String medicamentId) =>
      List.unmodifiable(_paliersParMedicament[medicamentId] ?? const []);

  /// Génère un plan de décroissance complet et REMPLACE le plan existant
  /// pour ce médicament.
  ///
  /// Logique retenue (à valider, ce n'est pas neutre) : réduction en
  /// pourcentage de la dose COURANTE à chaque palier (donc compounding,
  /// pas un pourcentage fixe de la dose de départ), appliquée tous les
  /// `delaiJours`, jusqu'à ce que la dose arrondie atteigne 0.
  void genererPlan({
    required String medicamentId,
    required double doseDepart,
    required double pourcentageReduction,
    required int delaiJours,
    required DateTime dateDebut,
  }) {
    assert(pourcentageReduction > 0 && pourcentageReduction < 100);
    assert(delaiJours > 0);

    const epsilon = 0.01;
    const maxEtapes =
        500; // garde-fou contre une boucle infinie / saisie aberrante

    final etapes = <EtapePalier>[];
    double doseCourante = doseDepart;
    DateTime dateCourante = dateDebut;
    int iterations = 0;

    while (doseCourante > epsilon && iterations < maxEtapes) {
      final nouvelleDose = doseCourante * (1 - pourcentageReduction / 100);
      dateCourante = dateCourante.add(Duration(days: delaiJours));
      final doseArrondie = nouvelleDose <= epsilon
          ? 0.0
          : double.parse(nouvelleDose.toStringAsFixed(2));
      etapes.add(EtapePalier(date: dateCourante, dose: doseArrondie));
      doseCourante = doseArrondie;
      iterations++;
    }

    _paliersParMedicament[medicamentId] = etapes;
    notifyListeners();
  }

  void supprimerPalier(String medicamentId, EtapePalier palier) {
    _paliersParMedicament[medicamentId]?.remove(palier);
    notifyListeners();
  }

  void viderPlan(String medicamentId) {
    _paliersParMedicament.remove(medicamentId);
    notifyListeners();
  }
}
