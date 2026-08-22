import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medico/constants/colors.dart';
import 'package:medico/data/medicaments_repository.dart';
import 'package:medico/data/medicaments_reference.dart';
import 'package:medico/views/ordonnances_page.dart';

/// Convertit une date de prescription en nombre de mois écoulés,
/// arrondi à l'entier inférieur. Retourne null si aucune date n'est
/// renseignée.
int? moisDepuisPrescription(DateTime? datePrescription) {
  if (datePrescription == null) return null;
  final jours = DateTime.now().difference(datePrescription).inDays;
  if (jours < 0)
    return 0; // date future saisie par erreur : traité comme "aujourd'hui"
  return (jours / 30).floor();
}

class MedicamentsPage extends StatefulWidget {
  const MedicamentsPage({super.key});

  @override
  State<MedicamentsPage> createState() => _MedicamentsPageState();
}

class _MedicamentsPageState extends State<MedicamentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repository = MedicamentsRepository.instance;

  Medicament? _medicamentEnEdition;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() => setState(() {});

  void _ouvrirEdition(Medicament? medicament) {
    setState(() => _medicamentEnEdition = medicament);
    _tabController.animateTo(1);
  }

  void _enregistrerMedicament(Medicament medicament) {
    _repository.ajouterOuMettreAJour(medicament);
    setState(() => _medicamentEnEdition = null);
    // Retour automatique sur l'onglet "En cours" après soumission.
    _tabController.animateTo(0);
  }

  void _supprimerMedicament(String id) => _repository.supprimer(id);

  void _importerListe(List<Medicament> importes) =>
      _repository.remplacerTout(importes);

  @override
  Widget build(BuildContext context) {
    final medicaments = _repository.medicaments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes médicaments'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Ordonnances',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OrdonnancesPage()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'En cours', icon: Icon(Icons.list_alt)),
            Tab(text: 'Saisie', icon: Icon(Icons.edit_note)),
            Tab(text: 'Import/Export', icon: Icon(Icons.swap_vert)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _EnCoursTab(
            medicaments: medicaments,
            onModifier: _ouvrirEdition,
            onSupprimer: _supprimerMedicament,
          ),
          _SaisieTab(
            key: ValueKey(_medicamentEnEdition?.id ?? 'nouveau'),
            medicamentInitial: _medicamentEnEdition,
            onEnregistrer: _enregistrerMedicament,
          ),
          _ImportExportTab(
            medicaments: medicaments,
            onImporter: _importerListe,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet 1 : Traitements en cours
// ---------------------------------------------------------------------------

class _EnCoursTab extends StatelessWidget {
  final List<Medicament> medicaments;
  final void Function(Medicament) onModifier;
  final void Function(String id) onSupprimer;

  const _EnCoursTab({
    required this.medicaments,
    required this.onModifier,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    if (medicaments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.medication_outlined,
                size: 64,
                color: AppColors.primaryColor.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun médicament suivi pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: medicaments.length,
      itemBuilder: (context, index) {
        final medicament = medicaments[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicament.nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medicament.classe,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        medicament.datePrescription != null
                            ? 'Prescrit le ${_formatDate(medicament.datePrescription!)}'
                            : 'Date de prescription non renseignée',
                        style: TextStyle(
                          fontSize: 12,
                          color: medicament.datePrescription != null
                              ? Colors.grey
                              : Colors.grey.shade400,
                          fontStyle: medicament.datePrescription != null
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (medicament.moleculeSubstitution != null &&
                                medicament.moleculeSubstitution!.isNotEmpty)
                            ? 'Substitution envisagée : ${medicament.moleculeSubstitution}'
                            : 'Aucune substitution envisagée',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              (medicament.moleculeSubstitution != null &&
                                  medicament.moleculeSubstitution!.isNotEmpty)
                              ? null
                              : Colors.grey.shade400,
                          fontStyle:
                              (medicament.moleculeSubstitution != null &&
                                  medicament.moleculeSubstitution!.isNotEmpty)
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Modifier',
                  onPressed: () => onModifier(medicament),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Supprimer',
                  onPressed: () => onSupprimer(medicament.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

// ---------------------------------------------------------------------------
// Onglet 2 : Saisie / modification
// ---------------------------------------------------------------------------

class _SaisieTab extends StatefulWidget {
  final Medicament? medicamentInitial;
  final void Function(Medicament) onEnregistrer;

  const _SaisieTab({
    super.key,
    required this.medicamentInitial,
    required this.onEnregistrer,
  });

  @override
  State<_SaisieTab> createState() => _SaisieTabState();
}

class _SaisieTabState extends State<_SaisieTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late final TextEditingController _classeController;
  late final TextEditingController _doseInitialeController;
  late final TextEditingController _doseActuelleController;
  late final TextEditingController _uniteController;
  late final TextEditingController _substitutionController;
  late DateTime _datePrescription;

  @override
  void initState() {
    super.initState();
    final m = widget.medicamentInitial;
    _nomController = TextEditingController(text: m?.nom ?? '');
    _classeController = TextEditingController(text: m?.classe ?? '');
    _doseInitialeController = TextEditingController(
      text: m?.doseInitiale.toString() ?? '',
    );
    _doseActuelleController = TextEditingController(
      text: m?.doseActuelle.toString() ?? '',
    );
    _uniteController = TextEditingController(text: m?.unite ?? 'mg');
    _substitutionController = TextEditingController(
      text: m?.moleculeSubstitution ?? '',
    );
    // Aujourd'hui par défaut si aucune date n'était déjà renseignée.
    _datePrescription = m?.datePrescription ?? DateTime.now();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _classeController.dispose();
    _doseInitialeController.dispose();
    _doseActuelleController.dispose();
    _uniteController.dispose();
    _substitutionController.dispose();
    super.dispose();
  }

  Future<void> _choisirDatePrescription() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _datePrescription,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _datePrescription = date);
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;

    final substitution = _substitutionController.text.trim();

    final medicament = Medicament(
      id: widget.medicamentInitial?.id,
      nom: _nomController.text.trim(),
      classe: _classeController.text.trim(),
      doseInitiale: double.parse(_doseInitialeController.text.trim()),
      doseActuelle: double.parse(_doseActuelleController.text.trim()),
      unite: _uniteController.text.trim(),
      datePrescription: _datePrescription,
      moleculeSubstitution: substitution.isEmpty ? null : substitution,
    );

    widget.onEnregistrer(medicament);
  }

  Future<void> _ouvrirSelecteur(BuildContext context) async {
    final resultat = await showModalBottomSheet<_SelectionMedicament>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _SelecteurMedicamentSheet(),
    );
    if (resultat != null) {
      setState(() {
        _nomController.text = resultat.nom;
        _classeController.text = resultat.classe;
      });
    }
  }

  Future<void> _ouvrirSelecteurSubstitution(BuildContext context) async {
    final resultat = await showModalBottomSheet<_SelectionMedicament>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _SelecteurMedicamentSheet(),
    );
    if (resultat != null) {
      setState(() => _substitutionController.text = resultat.nom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estModification = widget.medicamentInitial != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              estModification ? 'Modifier un traitement' : 'Nouveau traitement',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nomController,
              decoration: InputDecoration(
                labelText: 'Nom du médicament',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Choisir dans la liste',
                  onPressed: () => _ouvrirSelecteur(context),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _classeController,
              decoration: const InputDecoration(
                labelText: 'Classe (ex : Benzodiazépine, ISRS...)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _doseInitialeController,
                    decoration: const InputDecoration(
                      labelText: 'Dose de départ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _validerNombre,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _doseActuelleController,
                    decoration: const InputDecoration(
                      labelText: 'Dose actuelle',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _validerNombre,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _uniteController,
              decoration: const InputDecoration(
                labelText: 'Unité (mg, ml, gouttes...)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              tileColor: Colors.transparent,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Date de prescription'),
              subtitle: Text(_formatDate(_datePrescription)),
              onTap: _choisirDatePrescription,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Informations complémentaires (facultatif)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _substitutionController,
              decoration: InputDecoration(
                labelText: 'Molécule de substitution envisagée',
                border: const OutlineInputBorder(),
                hintText: 'ex : diazépam',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Choisir dans la liste',
                  onPressed: () => _ouvrirSelecteurSubstitution(context),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _valider,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save_outlined),
              label: Text(estModification ? 'Mettre à jour' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validerNombre(String? value) {
    if (value == null || value.trim().isEmpty) return 'Champ requis';
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Nombre invalide';
    if (parsed < 0) return 'Doit être positif';
    return null;
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

// ---------------------------------------------------------------------------
// Sélecteur de médicament (nom + classe, ou substitution)
// ---------------------------------------------------------------------------

class _SelectionMedicament {
  final String nom;
  final String classe;
  const _SelectionMedicament({required this.nom, required this.classe});
}

class _SelecteurMedicamentSheet extends StatefulWidget {
  const _SelecteurMedicamentSheet();

  @override
  State<_SelecteurMedicamentSheet> createState() =>
      _SelecteurMedicamentSheetState();
}

class _SelecteurMedicamentSheetState extends State<_SelecteurMedicamentSheet> {
  final _rechercheController = TextEditingController();
  String _filtre = '';

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtreMinuscule = _filtre.trim().toLowerCase();

    final classesFiltrees = <String, List<String>>{};
    for (final entry in MedicamentsReference.parClasse.entries) {
      final medicamentsFiltres = filtreMinuscule.isEmpty
          ? entry.value
          : entry.value
                .where((m) => m.toLowerCase().contains(filtreMinuscule))
                .toList();
      if (medicamentsFiltres.isNotEmpty) {
        classesFiltrees[entry.key] = medicamentsFiltres;
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choisir un médicament',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Liste indicative et non exhaustive. Si votre médicament '
                'n\'y figure pas, saisissez-le manuellement.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rechercheController,
                decoration: const InputDecoration(
                  labelText: 'Rechercher',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _filtre = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: classesFiltrees.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun résultat. Saisissez le nom manuellement.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        children: [
                          for (final entry in classesFiltrees.entries)
                            _buildGroupeClasse(entry.key, entry.value),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupeClasse(String classe, List<String> medicaments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            classe,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        for (final nom in medicaments)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(nom),
            onTap: () => Navigator.pop(
              context,
              _SelectionMedicament(nom: nom, classe: classe),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet 3 : Import / Export
// ---------------------------------------------------------------------------

class _ImportExportTab extends StatefulWidget {
  final List<Medicament> medicaments;
  final void Function(List<Medicament>) onImporter;

  const _ImportExportTab({required this.medicaments, required this.onImporter});

  @override
  State<_ImportExportTab> createState() => _ImportExportTabState();
}

class _ImportExportTabState extends State<_ImportExportTab> {
  final _importController = TextEditingController();
  String? _erreurImport;

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  String get _codeExport {
    final data = widget.medicaments.map((m) => m.toJson()).toList();
    return base64Encode(utf8.encode(jsonEncode(data)));
  }

  void _copierCode() {
    Clipboard.setData(ClipboardData(text: _codeExport));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copié dans le presse-papiers')),
    );
  }

  void _importerCode() {
    setState(() => _erreurImport = null);
    try {
      final jsonStr = utf8.decode(base64Decode(_importController.text.trim()));
      final List<dynamic> data = jsonDecode(jsonStr);
      final medicaments = data
          .map((e) => Medicament.fromJson(e as Map<String, dynamic>))
          .toList();
      widget.onImporter(medicaments);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${medicaments.length} médicament(s) importé(s)'),
        ),
      );
    } catch (_) {
      setState(() => _erreurImport = 'Code invalide ou mal formaté.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Exporter',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Copiez ce code pour sauvegarder ou transférer vos données vers un autre appareil.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            height: 150,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _codeExport,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _copierCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.copy_outlined, color: Colors.white),
            label: const Text('Copier le code'),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Importer',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Collez un code exporté depuis cette application. Cela remplacera la liste actuelle.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: TextField(
              controller: _importController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Collez le code ici',
                errorText: _erreurImport,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _importerCode,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Importer'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modèle
// ---------------------------------------------------------------------------

class Medicament {
  final String id;
  final String nom;
  final String classe;
  final double doseInitiale;
  final double doseActuelle;
  final String unite;
  final DateTime? datePrescription;
  final String? moleculeSubstitution;

  Medicament({
    String? id,
    required this.nom,
    required this.classe,
    required this.doseInitiale,
    required this.doseActuelle,
    required this.unite,
    this.datePrescription,
    this.moleculeSubstitution,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'classe': classe,
    'doseInitiale': doseInitiale,
    'doseActuelle': doseActuelle,
    'unite': unite,
    'datePrescription': datePrescription?.toIso8601String(),
    'moleculeSubstitution': moleculeSubstitution,
  };

  factory Medicament.fromJson(Map<String, dynamic> json) => Medicament(
    id: json['id'] as String?,
    nom: json['nom'] as String,
    classe: json['classe'] as String,
    doseInitiale: (json['doseInitiale'] as num).toDouble(),
    doseActuelle: (json['doseActuelle'] as num).toDouble(),
    unite: json['unite'] as String,
    datePrescription: json['datePrescription'] != null
        ? DateTime.parse(json['datePrescription'] as String)
        : null,
    moleculeSubstitution: json['moleculeSubstitution'] as String?,
  );
}
