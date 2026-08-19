import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactMedical {
  final String id;
  final String nom;
  final String qualite; // ex: "Médecin généraliste", "Psychologue"
  final String? telephone;
  final String? email;
  final String? adressePostale;
  final String note;

  ContactMedical({
    String? id,
    required this.nom,
    required this.qualite,
    this.telephone,
    this.email,
    this.adressePostale,
    this.note = '',
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'qualite': qualite,
        'telephone': telephone,
        'email': email,
        'adressePostale': adressePostale,
        'note': note,
      };

  factory ContactMedical.fromJson(Map<String, dynamic> json) => ContactMedical(
        id: json['id'] as String?,
        nom: json['nom'] as String,
        qualite: json['qualite'] as String,
        telephone: json['telephone'] as String?,
        email: json['email'] as String?,
        adressePostale: json['adressePostale'] as String?,
        note: json['note'] as String? ?? '',
      );
}

class ContactsMedicauxRepository extends ChangeNotifier {
  ContactsMedicauxRepository._();
  static final ContactsMedicauxRepository instance = ContactsMedicauxRepository._();

  static const _cle = 'contacts_medicaux';

  final List<ContactMedical> _contacts = [];
  bool _charge = false;

  List<ContactMedical> get contacts {
    final liste = List<ContactMedical>.from(_contacts);
    liste.sort((a, b) => a.nom.compareTo(b.nom));
    return List.unmodifiable(liste);
  }

  bool get estCharge => _charge;

  Future<void> charger() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cle);
    if (raw != null) {
      try {
        final List<dynamic> data = jsonDecode(raw);
        _contacts
          ..clear()
          ..addAll(data.map((e) => ContactMedical.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // Données corrompues : on repart d'un état vide plutôt que de crasher.
      }
    }
    _charge = true;
    notifyListeners();
  }

  Future<void> _sauvegarder() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _contacts.map((c) => c.toJson()).toList();
    await prefs.setString(_cle, jsonEncode(data));
  }

  Future<void> ajouterOuMettreAJour(ContactMedical contact) async {
    final index = _contacts.indexWhere((c) => c.id == contact.id);
    if (index >= 0) {
      _contacts[index] = contact;
    } else {
      _contacts.add(contact);
    }
    notifyListeners();
    await _sauvegarder();
  }

  Future<void> supprimer(String id) async {
    _contacts.removeWhere((c) => c.id == id);
    notifyListeners();
    await _sauvegarder();
  }
}