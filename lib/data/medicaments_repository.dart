// lib/data/medicaments_repository.dart
import 'package:flutter/foundation.dart';
import 'package:medico/views/medicaments_page.dart' show Medicament;

/// Source unique de vérité pour la liste des médicaments.
/// Singleton simple — évite de faire remonter le paramètre `medicaments`
/// à travers les routes. Ce n'est pas une vraie architecture d'état
/// partagé (pas de persistance, pas de séparation UI/logique) : c'est
/// un pansement pour débloquer le routage sans paramètre.
class MedicamentsRepository extends ChangeNotifier {
  MedicamentsRepository._();
  static final MedicamentsRepository instance = MedicamentsRepository._();

  final List<Medicament> _medicaments = [];

  List<Medicament> get medicaments => List.unmodifiable(_medicaments);

  void ajouterOuMettreAJour(Medicament medicament) {
    final index = _medicaments.indexWhere((m) => m.id == medicament.id);
    if (index >= 0) {
      _medicaments[index] = medicament;
    } else {
      _medicaments.add(medicament);
    }
    notifyListeners();
  }

  void supprimer(String id) {
    _medicaments.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  void remplacerTout(List<Medicament> nouvelleListe) {
    _medicaments
      ..clear()
      ..addAll(nouvelleListe);
    notifyListeners();
  }
}
