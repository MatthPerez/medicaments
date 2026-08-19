import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EtapePalier {
  final DateTime date;
  final double dose;

  EtapePalier({required this.date, required this.dose});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'dose': dose,
  };

  factory EtapePalier.fromJson(Map<String, dynamic> json) => EtapePalier(
    date: DateTime.parse(json['date'] as String),
    dose: (json['dose'] as num).toDouble(),
  );
}

/// Repères informatifs tirés du manuel Ashton (résumé public), fournis
/// à titre indicatif uniquement — l'utilisateur reste libre de saisir
/// d'autres valeurs. Aucune de ces bornes n'est appliquée automatiquement.
class RepereAshton {
  final String pourcentageConseille; // ex: "5 à 10 %"
  final String delaiConseille; // ex: "1 à 3 semaines"
  final String? dureeGlobaleEstimee; // ex: "3 à 9 mois", selon ancienneté

  const RepereAshton({
    required this.pourcentageConseille,
    required this.delaiConseille,
    this.dureeGlobaleEstimee,
  });

  /// [ancienneteMois] : ancienneté du traitement en mois, si connue.
  static RepereAshton pour(int? ancienneteMois) {
    String? duree;
    if (ancienneteMois != null) {
      if (ancienneteMois < 12) {
        duree = '4 à 12 semaines';
      } else if (ancienneteMois <= 60) {
        duree = '3 à 9 mois';
      } else {
        duree = '6 à 18 mois';
      }
    }
    return RepereAshton(
      pourcentageConseille: '5 à 10 %',
      delaiConseille: '1 à 3 semaines (7 à 21 jours)',
      dureeGlobaleEstimee: duree,
    );
  }
}

/// Source unique de vérité pour les plans de sevrage, indexés par id
/// de médicament. Persisté via shared_preferences.
class PaliersRepository extends ChangeNotifier {
  PaliersRepository._();
  static final PaliersRepository instance = PaliersRepository._();

  static const _cle = 'paliers_par_medicament';

  final Map<String, List<EtapePalier>> _paliersParMedicament = {};
  bool _charge = false;

  List<EtapePalier> paliersPour(String medicamentId) =>
      List.unmodifiable(_paliersParMedicament[medicamentId] ?? const []);

  bool get estCharge => _charge;

  Future<void> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cle);
    if (raw != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(raw);
        _paliersParMedicament.clear();
        data.forEach((medicamentId, liste) {
          _paliersParMedicament[medicamentId] = (liste as List)
              .map((e) => EtapePalier.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      } catch (_) {
        // Données corrompues : on repart d'un état vide plutôt que de crasher.
      }
    }
    _charge = true;
    notifyListeners();
  }

  Future<void> _sauvegarder() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _paliersParMedicament.map(
      (id, etapes) => MapEntry(id, etapes.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(_cle, jsonEncode(data));
  }

  /// Génère un plan de décroissance en pourcentage de la DOSE COURANTE
  /// (logique Ashton), avec un seuil d'arrêt qui force le dernier
  /// palier à 0 pour garantir une fin — sans ce seuil, une réduction
  /// en pourcentage de la dose courante ne mathématiquement jamais 0.
  ///
  /// [seuilArretPourcentDoseInitiale] : en dessous de ce pourcentage
  /// de la dose INITIALE, le palier suivant est fixé à 0 au lieu de
  /// continuer à réduire proportionnellement. Valeur par défaut : 5 %.
  /// Ce seuil est un choix technique arbitraire — pas une valeur du
  /// manuel Ashton, qui ne fixe pas de règle mathématique de fin.
  Future<void> genererPlan({
    required String medicamentId,
    required double doseInitiale,
    required double pourcentageReduction,
    required int delaiJours,
    required DateTime dateDebut,
    double seuilArretPourcentDoseInitiale = 5.0,
  }) async {
    assert(pourcentageReduction > 0 && pourcentageReduction < 100);
    assert(delaiJours > 0);

    const maxEtapes = 200; // garde-fou contre une saisie aberrante

    final seuilArret = doseInitiale * (seuilArretPourcentDoseInitiale / 100);
    final etapes = <EtapePalier>[];
    double doseCourante = doseInitiale;
    int iterations = 0;

    while (doseCourante > 0 && iterations < maxEtapes) {
      final nouvelleDoseBrute = doseCourante * (1 - pourcentageReduction / 100);
      final estDerniereEtape = nouvelleDoseBrute <= seuilArret;
      final dose = estDerniereEtape
          ? 0.0
          : double.parse(nouvelleDoseBrute.toStringAsFixed(2));

      etapes.add(
        EtapePalier(
          date: dateDebut.add(Duration(days: delaiJours * (iterations + 1))),
          dose: dose,
        ),
      );

      doseCourante = dose;
      iterations++;
      if (estDerniereEtape) break;
    }

    _paliersParMedicament[medicamentId] = etapes;
    notifyListeners();
    await _sauvegarder();
  }

  Future<void> remplacerPaliers(
    String medicamentId,
    List<EtapePalier> etapes,
  ) async {
    _paliersParMedicament[medicamentId] = etapes;
    notifyListeners();
    await _sauvegarder();
  }

  Future<void> supprimerPlan(String medicamentId) async {
    _paliersParMedicament.remove(medicamentId);
    notifyListeners();
    await _sauvegarder();
  }

  Future<void> supprimerPalier(String medicamentId, EtapePalier palier) async {
    _paliersParMedicament[medicamentId]?.remove(palier);
    notifyListeners();
    await _sauvegarder();
  }
}
