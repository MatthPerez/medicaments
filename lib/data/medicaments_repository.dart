import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medico/views/medicaments_page.dart' show Medicament;

class MedicamentsRepository extends ChangeNotifier {
  MedicamentsRepository._();
  static final MedicamentsRepository instance = MedicamentsRepository._();

  static const _cle = 'medicaments';

  final List<Medicament> _medicaments = [];
  bool _charge = false;

  List<Medicament> get medicaments => List.unmodifiable(_medicaments);
  bool get estCharge => _charge;

  Future<void> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cle);
    if (raw != null) {
      try {
        final List<dynamic> data = jsonDecode(raw);
        _medicaments
          ..clear()
          ..addAll(
            data.map((e) => Medicament.fromJson(e as Map<String, dynamic>)),
          );
      } catch (_) {
        // Données corrompues : on repart d'un état vide plutôt que de crasher.
      }
    }
    _charge = true;
    notifyListeners();
  }

  Future<void> _sauvegarder() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _medicaments.map((m) => m.toJson()).toList();
    await prefs.setString(_cle, jsonEncode(data));
  }

  Future<void> ajouterOuMettreAJour(Medicament medicament) async {
    final index = _medicaments.indexWhere((m) => m.id == medicament.id);
    if (index >= 0) {
      _medicaments[index] = medicament;
    } else {
      _medicaments.add(medicament);
    }
    notifyListeners();
    await _sauvegarder();
  }

  Future<void> supprimer(String id) async {
    _medicaments.removeWhere((m) => m.id == id);
    notifyListeners();
    await _sauvegarder();
  }

  Future<void> remplacerTout(List<Medicament> nouvelleListe) async {
    _medicaments
      ..clear()
      ..addAll(nouvelleListe);
    notifyListeners();
    await _sauvegarder();
  }
}
