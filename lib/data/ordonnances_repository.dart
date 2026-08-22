import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DocumentOrdonnance {
  final String id;
  final String nomAffichage;
  final String nomFichier; // nom du fichier stocké localement (id + extension)
  final DateTime dateAjout;

  DocumentOrdonnance({
    required this.id,
    required this.nomAffichage,
    required this.nomFichier,
    required this.dateAjout,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nomAffichage': nomAffichage,
        'nomFichier': nomFichier,
        'dateAjout': dateAjout.toIso8601String(),
      };

  factory DocumentOrdonnance.fromJson(Map<String, dynamic> json) => DocumentOrdonnance(
        id: json['id'] as String,
        nomAffichage: json['nomAffichage'] as String,
        nomFichier: json['nomFichier'] as String,
        dateAjout: DateTime.parse(json['dateAjout'] as String),
      );
}

/// Les fichiers PDF eux-mêmes vivent sur le disque, dans un sous-dossier
/// du répertoire documents de l'app (PAS dans SharedPreferences, qui ne
/// convient pas à du contenu binaire). SharedPreferences ne stocke que
/// les métadonnées (nom affiché, date, nom de fichier).
class OrdonnancesRepository extends ChangeNotifier {
  OrdonnancesRepository._();
  static final OrdonnancesRepository instance = OrdonnancesRepository._();

  static const _cleMeta = 'ordonnances_meta';

  final List<DocumentOrdonnance> _documents = [];
  bool _charge = false;
  Directory? _dossier;

  List<DocumentOrdonnance> get documents {
    final liste = List<DocumentOrdonnance>.from(_documents);
    liste.sort((a, b) => b.dateAjout.compareTo(a.dateAjout));
    return List.unmodifiable(liste);
  }

  bool get estCharge => _charge;

  Future<void> charger() async {
    final docsDir = await getApplicationDocumentsDirectory();
    _dossier = Directory(p.join(docsDir.path, 'ordonnances'));
    if (!await _dossier!.exists()) {
      await _dossier!.create(recursive: true);
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cleMeta);
    if (raw != null) {
      try {
        final List<dynamic> data = jsonDecode(raw);
        _documents
          ..clear()
          ..addAll(data.map((e) => DocumentOrdonnance.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // Métadonnées corrompues : on repart d'un état vide plutôt que de crasher.
      }
    }
    _charge = true;
    notifyListeners();
  }

  Future<void> _sauvegarderMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _documents.map((d) => d.toJson()).toList();
    await prefs.setString(_cleMeta, jsonEncode(data));
  }

  String cheminComplet(DocumentOrdonnance doc) {
    if (_dossier == null) throw StateError('Repository non chargé.');
    return p.join(_dossier!.path, doc.nomFichier);
  }

  /// Copie un fichier externe (choisi via le sélecteur système) dans le
  /// stockage local de l'app. [cheminSource] doit être un chemin absolu
  /// valide (fourni par file_picker) — null sur certaines plateformes
  /// (web) où l'accès direct au chemin n'est pas disponible.
  Future<DocumentOrdonnance> ajouterDepuisFichier({
    required String cheminSource,
    required String nomAffichage,
  }) async {
    if (_dossier == null) throw StateError('Repository non chargé.');

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final extension = p.extension(cheminSource);
    final nomFichier = '$id$extension';
    final destination = File(p.join(_dossier!.path, nomFichier));

    await File(cheminSource).copy(destination.path);

    final doc = DocumentOrdonnance(
      id: id,
      nomAffichage: nomAffichage,
      nomFichier: nomFichier,
      dateAjout: DateTime.now(),
    );
    _documents.add(doc);
    notifyListeners();
    await _sauvegarderMeta();
    return doc;
  }

  Future<void> supprimer(String id) async {
    final index = _documents.indexWhere((d) => d.id == id);
    if (index == -1) return;
    final doc = _documents[index];
    final fichier = File(cheminComplet(doc));
    if (await fichier.exists()) {
      await fichier.delete();
    }
    _documents.removeAt(index);
    notifyListeners();
    await _sauvegarderMeta();
  }
}