import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Une entrée de journal : un symptôme ressenti à une date donnée,
/// éventuellement rattaché à un médicament (utile pour croiser un
/// ressenti avec un palier de sevrage en cours), avec une intensité
/// et une note libre.
class Symptome {
  final String id;
  final DateTime date;
  final String? medicamentId;
  final String? medicamentNom; // dupliqué au moment de la saisie, pour
  // survivre à la suppression du médicament (voir avertissement historique)
  final int intensite; // 1 (léger) à 5 (sévère)
  final String note;

  Symptome({
    String? id,
    required this.date,
    this.medicamentId,
    this.medicamentNom,
    required this.intensite,
    required this.note,
  })  : assert(intensite >= 1 && intensite <= 5),
        id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'medicamentId': medicamentId,
        'medicamentNom': medicamentNom,
        'intensite': intensite,
        'note': note,
      };

  factory Symptome.fromJson(Map<String, dynamic> json) => Symptome(
        id: json['id'] as String?,
        date: DateTime.parse(json['date'] as String),
        medicamentId: json['medicamentId'] as String?,
        medicamentNom: json['medicamentNom'] as String?,
        intensite: json['intensite'] as int,
        note: json['note'] as String,
      );
}

class SymptomesRepository extends ChangeNotifier {
  SymptomesRepository._();
  static final SymptomesRepository instance = SymptomesRepository._();

  static const _cle = 'symptomes';

  final List<Symptome> _symptomes = [];
  bool _charge = false;

  /// Triés du plus récent au plus ancien.
  List<Symptome> get symptomes {
    final liste = List<Symptome>.from(_symptomes);
    liste.sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(liste);
  }

  List<Symptome> pourMedicament(String medicamentId) =>
      symptomes.where((s) => s.medicamentId == medicamentId).toList();

  bool get estCharge => _charge;

  Future<void> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cle);
    if (raw != null) {
      try {
        final List<dynamic> data = jsonDecode(raw);
        _symptomes
          ..clear()
          ..addAll(data.map((e) => Symptome.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // Données corrompues : on repart d'un état vide plutôt que de crasher.
      }
    }
    _charge = true;
    notifyListeners();
  }

  Future<void> _sauvegarder() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _symptomes.map((s) => s.toJson()).toList();
    await prefs.setString(_cle, jsonEncode(data));
  }

  Future<void> ajouter(Symptome symptome) async {
    _symptomes.add(symptome);
    notifyListeners();
    await _sauvegarder();
  }

  Future<void> supprimer(String id) async {
    _symptomes.removeWhere((s) => s.id == id);
    notifyListeners();
    await _sauvegarder();
  }
}