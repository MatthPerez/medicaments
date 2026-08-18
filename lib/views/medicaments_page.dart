import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_meds/constants/colors.dart';
import 'package:my_meds/data/medicaments_repository.dart';

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
    setState(() {
      _medicamentEnEdition = medicament;
    });
    _tabController.animateTo(1);
  }

  void _enregistrerMedicament(Medicament medicament) {
    _repository.ajouterOuMettreAJour(medicament);
    setState(() {
      _medicamentEnEdition = null;
    });
    _tabController.animateTo(0);
  }

  void _supprimerMedicament(String id) {
    _repository.supprimer(id);
  }

  void _importerListe(List<Medicament> importes) {
    _repository.remplacerTout(importes);
  }

  @override
  Widget build(BuildContext context) {
    final medicaments = _repository.medicaments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes médicaments'),
        centerTitle: true,
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
        final double pourcentageRestant = medicament.doseInitiale == 0
            ? 0
            : (medicament.doseActuelle / medicament.doseInitiale) * 100;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            title: Text(
              medicament.nom,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${medicament.classe} · Dose actuelle : '
                '${medicament.doseActuelle} ${medicament.unite}',
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${pourcentageRestant.toStringAsFixed(0)}%'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: pourcentageRestant / 100,
                        color: AppColors.primaryColor,
                        backgroundColor: AppColors.primaryColor.withValues(
                          alpha: 0.15,
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
  }

  @override
  void dispose() {
    _nomController.dispose();
    _classeController.dispose();
    _doseInitialeController.dispose();
    _doseActuelleController.dispose();
    _uniteController.dispose();
    super.dispose();
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;

    final medicament = Medicament(
      id: widget.medicamentInitial?.id,
      nom: _nomController.text.trim(),
      classe: _classeController.text.trim(),
      doseInitiale: double.parse(_doseInitialeController.text.trim()),
      doseActuelle: double.parse(_doseActuelleController.text.trim()),
      unite: _uniteController.text.trim(),
    );

    widget.onEnregistrer(medicament);
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
              decoration: const InputDecoration(
                labelText: 'Nom du médicament',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Champ requis'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _classeController,
              decoration: const InputDecoration(
                labelText: 'Classe (ex : Benzodiazépine, ISRS...)',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Champ requis'
                  : null,
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
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Champ requis'
                  : null,
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
    final jsonStr = jsonEncode(data);
    return base64Encode(utf8.encode(jsonStr));
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
            'Copiez ce code pour sauvegarder ou transférer vos données '
            'vers un autre appareil.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: SelectableText(
              _codeExport,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _copierCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.copy_outlined),
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
            'Collez un code exporté depuis cette application. '
            'Cela remplacera la liste actuelle.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _importController,
            maxLines: 4,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Collez le code ici',
              errorText: _erreurImport,
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
// Widget carte (utilisé par _EnCoursTab)
// ---------------------------------------------------------------------------

class _MedicamentCard extends StatelessWidget {
  final Medicament medicament;

  const _MedicamentCard({required this.medicament});

  @override
  Widget build(BuildContext context) {
    final double pourcentageRestant = medicament.doseInitiale == 0
        ? 0
        : (medicament.doseActuelle / medicament.doseInitiale) * 100;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          medicament.nom,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${medicament.classe} · Dose actuelle : '
            '${medicament.doseActuelle} ${medicament.unite}',
          ),
        ),
        trailing: SizedBox(
          width: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${pourcentageRestant.toStringAsFixed(0)}%'),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: pourcentageRestant / 100,
                color: AppColors.primaryColor,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.15),
              ),
            ],
          ),
        ),
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

  Medicament({
    String? id,
    required this.nom,
    required this.classe,
    required this.doseInitiale,
    required this.doseActuelle,
    required this.unite,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'classe': classe,
    'doseInitiale': doseInitiale,
    'doseActuelle': doseActuelle,
    'unite': unite,
  };

  factory Medicament.fromJson(Map<String, dynamic> json) => Medicament(
    id: json['id'] as String?,
    nom: json['nom'] as String,
    classe: json['classe'] as String,
    doseInitiale: (json['doseInitiale'] as num).toDouble(),
    doseActuelle: (json['doseActuelle'] as num).toDouble(),
    unite: json['unite'] as String,
  );
}
