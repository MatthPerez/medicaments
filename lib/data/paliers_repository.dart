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

/// Source unique de vérité pour les plans de sevrage, indexés par id
/// de médicament. Persisté via shared_preferences (JSON), chargé une
/// fois au démarrage via `charger()`.
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

  /// Génère un plan de décroissance à DATE DE FIN GARANTIE : chaque
  /// pourcentage est appliqué à la dose INITIALE (pas à la dose
  /// courante), donc la suite est arithmétique et non asymptotique.
  /// Le dernier palier est toujours exactement 0.
  Future<void> genererPlan({
    required String medicamentId,
    required double doseInitiale,
    required double pourcentageReduction,
    required int delaiJours,
    required DateTime dateDebut,
  }) async {
    assert(pourcentageReduction > 0 && pourcentageReduction <= 100);
    assert(delaiJours > 0);

    final pasDose = doseInitiale * (pourcentageReduction / 100);
    final nombrePaliers = (doseInitiale / pasDose).ceil();

    final etapes = <EtapePalier>[];
    for (int i = 1; i <= nombrePaliers; i++) {
      final doseBrute = doseInitiale - (pasDose * i);
      final dose = i == nombrePaliers
          ? 0.0
          : double.parse(doseBrute.clamp(0, doseInitiale).toStringAsFixed(2));
      etapes.add(
        EtapePalier(
          date: dateDebut.add(Duration(days: delaiJours * i)),
          dose: dose,
        ),
      );
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
}
