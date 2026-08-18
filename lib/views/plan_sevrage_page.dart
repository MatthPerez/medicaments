import 'package:flutter/material.dart';
import 'package:my_meds/constants/colors.dart';
import 'package:my_meds/data/medicaments_repository.dart';
import 'package:my_meds/data/paliers_repository.dart';
import 'package:my_meds/views/medicaments_page.dart' show Medicament;

class PlanSevragePage extends StatefulWidget {
  const PlanSevragePage({super.key});

  @override
  State<PlanSevragePage> createState() => _PlanSevragePageState();
}

class _PlanSevragePageState extends State<PlanSevragePage> {
  final _medicamentsRepo = MedicamentsRepository.instance;
  final _paliersRepo = PaliersRepository.instance;

  @override
  void initState() {
    super.initState();
    _medicamentsRepo.addListener(_onChanged);
    _paliersRepo.addListener(_onChanged);
  }

  @override
  void dispose() {
    _medicamentsRepo.removeListener(_onChanged);
    _paliersRepo.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final medicaments = _medicamentsRepo.medicaments;

    return Scaffold(
      appBar: AppBar(title: const Text('Plan de sevrage'), centerTitle: true),
      body: SafeArea(
        child: medicaments.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: medicaments.length,
                itemBuilder: (context, index) {
                  final medicament = medicaments[index];
                  final etapes = _paliersRepo.paliersPour(medicament.id);
                  return _PlanCard(
                    medicament: medicament,
                    etapes: etapes,
                    onGenererPlan: (dose, pourcentage, delai, dateDebut) {
                      _paliersRepo.genererPlan(
                        medicamentId: medicament.id,
                        doseDepart: dose,
                        pourcentageReduction: pourcentage,
                        delaiJours: delai,
                        dateDebut: dateDebut,
                      );
                    },
                    onSupprimerEtape: (etape) {
                      _paliersRepo.supprimerPalier(medicament.id, etape);
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 64,
              color: AppColors.primaryColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ajoutez un médicament dans l\'onglet "Mes médicaments" '
              'pour lui définir un plan de sevrage.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carte par médicament
// ---------------------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  final Medicament medicament;
  final List<EtapePalier> etapes;
  final void Function(
    double doseDepart,
    double pourcentage,
    int delaiJours,
    DateTime dateDebut,
  )
  onGenererPlan;
  final void Function(EtapePalier) onSupprimerEtape;

  const _PlanCard({
    required this.medicament,
    required this.etapes,
    required this.onGenererPlan,
    required this.onSupprimerEtape,
  });

  /// Dernier palier dont la date est déjà passée (ou aujourd'hui) —
  /// reflète la dose réellement en cours aujourd'hui, indépendamment
  /// du fait que le tableau affiche aussi les paliers futurs et passés.
  EtapePalier? get _etapeActuelle {
    final maintenant = DateTime.now();
    EtapePalier? actuel;
    for (final e in etapes) {
      if (!e.date.isAfter(maintenant)) {
        actuel = e;
      }
    }
    return actuel;
  }

  double get _doseActuellePlan =>
      _etapeActuelle?.dose ?? medicament.doseActuelle;

  double get _pourcentageRestant => medicament.doseInitiale == 0
      ? 0
      : (_doseActuellePlan / medicament.doseInitiale) * 100;

  bool get _sevrageAtteint =>
      _etapeActuelle != null && _etapeActuelle!.dose <= 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    medicament.nom,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_sevrageAtteint)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Sevrage atteint',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Type de médicament et dosage de base disposés en colonne.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicament.classe,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dosage de base : ${medicament.doseInitiale} ${medicament.unite}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_pourcentageRestant / 100).clamp(0, 1),
                    color: AppColors.primaryColor,
                    backgroundColor: AppColors.primaryColor.withValues(
                      alpha: 0.15,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_pourcentageRestant.clamp(0, 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (etapes.isEmpty)
              const Text(
                'Aucun plan généré.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              )
            else
              _buildTableauPaliers(context),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _ouvrirFormulaireGeneration(context),
                icon: const Icon(Icons.auto_graph),
                label: Text(
                  etapes.isEmpty ? 'Générer un plan' : 'Régénérer le plan',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableauPaliers(BuildContext context) {
    final maintenant = DateTime.now();
    final etapeActuelle = _etapeActuelle;

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FixedColumnWidth(40),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: const [
            _CelluleEntete('Date'),
            _CelluleEntete('Dose'),
            _CelluleEntete('% dose init.'),
            SizedBox(),
          ],
        ),
        for (final etape in etapes)
          TableRow(
            decoration: etape == etapeActuelle
                ? BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.08),
                  )
                : null,
            children: [
              _Cellule(
                _formatDate(etape.date),
                attenue:
                    etape.date.isBefore(maintenant) && etape != etapeActuelle,
              ),
              _Cellule(
                '${etape.dose} ${medicament.unite}',
                attenue:
                    etape.date.isBefore(maintenant) && etape != etapeActuelle,
              ),
              _Cellule(
                medicament.doseInitiale == 0
                    ? '—'
                    : '${((etape.dose / medicament.doseInitiale) * 100).toStringAsFixed(0)}%',
                attenue:
                    etape.date.isBefore(maintenant) && etape != etapeActuelle,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onSupprimerEtape(etape),
              ),
            ],
          ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  Future<void> _ouvrirFormulaireGeneration(BuildContext context) async {
    if (etapes.isNotEmpty) {
      final confirme = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remplacer le plan existant ?'),
          content: const Text(
            'Générer un nouveau plan supprimera tous les paliers '
            'actuellement enregistrés pour ce médicament, y compris '
            'l\'historique des paliers déjà passés.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remplacer'),
            ),
          ],
        ),
      );
      if (confirme != true) return;
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FormulaireGenerationSheet(
        medicament: medicament,
        doseActuelleSuggeree: _doseActuellePlan,
        onValider: onGenererPlan,
      ),
    );
  }
}

class _CelluleEntete extends StatelessWidget {
  final String texte;
  const _CelluleEntete(this.texte);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        texte,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _Cellule extends StatelessWidget {
  final String texte;
  final bool attenue;
  const _Cellule(this.texte, {this.attenue = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        texte,
        style: TextStyle(fontSize: 13, color: attenue ? Colors.grey : null),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Formulaire de génération automatique du plan
// ---------------------------------------------------------------------------

class _FormulaireGenerationSheet extends StatefulWidget {
  final Medicament medicament;
  final double doseActuelleSuggeree;
  final void Function(
    double doseDepart,
    double pourcentage,
    int delaiJours,
    DateTime dateDebut,
  )
  onValider;

  const _FormulaireGenerationSheet({
    required this.medicament,
    required this.doseActuelleSuggeree,
    required this.onValider,
  });

  @override
  State<_FormulaireGenerationSheet> createState() =>
      _FormulaireGenerationSheetState();
}

class _FormulaireGenerationSheetState
    extends State<_FormulaireGenerationSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _doseDepartController;
  final _pourcentageController = TextEditingController(text: '10');
  final _delaiController = TextEditingController(text: '14');
  DateTime _dateDebut = DateTime.now();

  @override
  void initState() {
    super.initState();
    _doseDepartController = TextEditingController(
      text: widget.doseActuelleSuggeree.toString(),
    );
  }

  @override
  void dispose() {
    _doseDepartController.dispose();
    _pourcentageController.dispose();
    _delaiController.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateDebut,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _dateDebut = date);
    }
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;

    widget.onValider(
      double.parse(_doseDepartController.text.trim()),
      double.parse(_pourcentageController.text.trim()),
      int.parse(_delaiController.text.trim()),
      _dateDebut,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Générer le plan — ${widget.medicament.nom}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _doseDepartController,
              decoration: InputDecoration(
                labelText: 'Dose de départ (${widget.medicament.unite})',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validerNombrePositif,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pourcentageController,
              decoration: const InputDecoration(
                labelText: 'Réduction par palier (%)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final erreur = _validerNombrePositif(value);
                if (erreur != null) return erreur;
                final pct = double.parse(value!.trim());
                if (pct >= 100) return 'Doit être < 100';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _delaiController,
              decoration: const InputDecoration(
                labelText: 'Délai entre paliers (jours)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'Champ requis';
                final parsed = int.tryParse(value.trim());
                if (parsed == null || parsed <= 0)
                  return 'Entier positif requis';
                return null;
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Date de départ : ${_dateDebut.day.toString().padLeft(2, '0')}/'
                '${_dateDebut.month.toString().padLeft(2, '0')}/'
                '${_dateDebut.year}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _choisirDate,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _valider,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Générer le plan'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validerNombrePositif(String? value) {
    if (value == null || value.trim().isEmpty) return 'Champ requis';
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Nombre invalide';
    if (parsed <= 0) return 'Doit être positif';
    return null;
  }
}
