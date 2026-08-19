import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EtapePalier {
  final DateTime date;
  final double dose;

  /// Dose de la molécule de substitution à cette même date, si le plan
  /// est un plan de substitution. Null pour un plan simple.
  final double? doseSubstitution;

  EtapePalier({required this.date, required this.dose, this.doseSubstitution});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'dose': dose,
    'doseSubstitution': doseSubstitution,
  };

  factory EtapePalier.fromJson(Map<String, dynamic> json) => EtapePalier(
    date: DateTime.parse(json['date'] as String),
    dose: (json['dose'] as num).toDouble(),
    doseSubstitution: (json['doseSubstitution'] as num?)?.toDouble(),
  );
}

class RepereAshton {
  final String pourcentageConseille;
  final String delaiConseille;
  final String? dureeGlobaleEstimee;

  const RepereAshton({
    required this.pourcentageConseille,
    required this.delaiConseille,
    this.dureeGlobaleEstimee,
  });

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

  /// Génère un plan simple (dose courante, sans substitution).
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

    const maxEtapes = 200;
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

  /// Génère un plan de SUBSTITUTION : la dose de l'ancien médicament
  /// diminue selon la même logique que [genererPlan], et la dose du
  /// médicament de substitution augmente en parallèle, calculée via
  /// [ratioEquivalence] (mg de molécule de substitution par mg de
  /// molécule d'origine réduite à chaque étape).
  ///
  /// ATTENTION : [ratioEquivalence] doit être fourni par l'utilisateur
  /// à partir d'une source clinique validée (médecin, pharmacien,
  /// table d'équivalence officielle). Ce repository ne connaît AUCUNE
  /// équivalence entre molécules et ne peut pas la déduire — un ratio
  /// incorrect produit un plan de substitution incorrect.
  Future<void> genererPlanSubstitution({
    required String medicamentId,
    required double doseInitiale,
    required double pourcentageReduction,
    required int delaiJours,
    required DateTime dateDebut,
    required double ratioEquivalence,
    double seuilArretPourcentDoseInitiale = 5.0,
  }) async {
    assert(pourcentageReduction > 0 && pourcentageReduction < 100);
    assert(delaiJours > 0);
    assert(ratioEquivalence > 0);

    const maxEtapes = 200;
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

      // Quantité "libérée" de l'ancien médicament à cette étape,
      // convertie en équivalent du médicament de substitution.
      final quantiteReduite = doseInitiale - dose;
      final doseSubstitution = double.parse(
        (quantiteReduite * ratioEquivalence).toStringAsFixed(2),
      );

      etapes.add(
        EtapePalier(
          date: dateDebut.add(Duration(days: delaiJours * (iterations + 1))),
          dose: dose,
          doseSubstitution: doseSubstitution,
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

  Future<void> remplacerPaliers(
    String medicamentId,
    List<EtapePalier> etapes,
  ) async {
    _paliersParMedicament[medicamentId] = etapes;
    notifyListeners();
    await _sauvegarder();
  }
}
