import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:medico/constants/colors.dart';
import 'package:medico/data/medicaments_repository.dart';
import 'package:medico/data/paliers_repository.dart';
import 'package:medico/views/medicaments_page.dart' show Medicament;

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
                    onGenererPlan: (pourcentage, delai, dateDebut, ratioSubstitution) {
                      if (ratioSubstitution == null) {
                        _paliersRepo.genererPlan(
                          medicamentId: medicament.id,
                          doseInitiale: medicament.doseInitiale,
                          pourcentageReduction: pourcentage,
                          delaiJours: delai,
                          dateDebut: dateDebut,
                        );
                      } else {
                        _paliersRepo.genererPlanSubstitution(
                          medicamentId: medicament.id,
                          doseInitiale: medicament.doseInitiale,
                          pourcentageReduction: pourcentage,
                          delaiJours: delai,
                          dateDebut: dateDebut,
                          ratioEquivalence: ratioSubstitution,
                        );
                      }
                    },
                    onSupprimerPlan: () => _paliersRepo.supprimerPlan(medicament.id),
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
            Icon(Icons.timeline_outlined,
                size: 64, color: AppColors.primaryColor.withValues(alpha: 0.4)),
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

class _PlanCard extends StatefulWidget {
  final Medicament medicament;
  final List<EtapePalier> etapes;
  final void Function(double pourcentage, int delaiJours, DateTime dateDebut,
      double? ratioSubstitution) onGenererPlan;
  final VoidCallback onSupprimerPlan;

  const _PlanCard({
    required this.medicament,
    required this.etapes,
    required this.onGenererPlan,
    required this.onSupprimerPlan,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _deplie = false;
  bool _exportEnCours = false;

  EtapePalier? get _etapeActuelle {
    final maintenant = DateTime.now();
    EtapePalier? actuel;
    for (final e in widget.etapes) {
      if (!e.date.isAfter(maintenant)) actuel = e;
    }
    return actuel;
  }

  bool get _sevrageTermine =>
      widget.etapes.isNotEmpty && widget.etapes.last.date.isBefore(DateTime.now());

  bool get _estSubstitution =>
      widget.etapes.isNotEmpty && widget.etapes.any((e) => e.doseSubstitution != null);

  double get _doseActuellePlan =>
      _etapeActuelle?.dose ?? widget.medicament.doseActuelle;

  double get _pourcentageRestant => widget.medicament.doseInitiale == 0
      ? 0
      : (_doseActuellePlan / widget.medicament.doseInitiale) * 100;

  @override
  Widget build(BuildContext context) {
    final aUnPlan = widget.etapes.isNotEmpty;
    final couleurFond = aUnPlan
        ? (_sevrageTermine
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.white)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: couleurFond,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: aUnPlan ? () => setState(() => _deplie = !_deplie) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.medicament.nom,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (aUnPlan)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _sevrageTermine
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _sevrageTermine ? 'Sevrage terminé' : 'En cours',
                            style: TextStyle(
                              fontSize: 12,
                              color: _sevrageTermine
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      if (aUnPlan)
                        IconButton(
                          icon: _exportEnCours
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.image_outlined),
                          tooltip: 'Exporter en image',
                          onPressed: _exportEnCours ? null : () => _exporterImage(context),
                        ),
                      if (aUnPlan)
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Supprimer ce plan',
                          onPressed: () => _confirmerSuppression(context),
                        ),
                      if (aUnPlan)
                        Icon(_deplie ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.medicament.classe,
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        'Dosage de base : ${widget.medicament.doseInitiale} '
                        '${widget.medicament.unite}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (_estSubstitution &&
                          widget.medicament.moleculeSubstitution != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Bascule en cours vers : '
                            '${widget.medicament.moleculeSubstitution}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.15),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${_pourcentageRestant.clamp(0, 100).toStringAsFixed(0)}%'),
                    ],
                  ),
                  if (_estSubstitution && _etapeActuelle?.doseSubstitution != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${widget.medicament.moleculeSubstitution} actuel : '
                      '${_etapeActuelle!.doseSubstitution} ${widget.medicament.unite}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                  if (!aUnPlan) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _ouvrirFormulaireGeneration(context),
                        icon: const Icon(Icons.auto_graph),
                        label: const Text('Générer un plan'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (aUnPlan)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _deplie ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildTableauPaliers(context),
              ),
              secondChild: const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmerSuppression(BuildContext context) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce plan de sevrage ?'),
        content: const Text(
          'Tous les paliers de ce médicament, y compris ceux déjà '
          'atteints, seront définitivement effacés.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirme == true) {
      widget.onSupprimerPlan();
      setState(() => _deplie = false);
    }
  }

  Widget _buildTableauPaliers(BuildContext context) {
    final maintenant = DateTime.now();
    final etapeActuelle = _etapeActuelle;

    return Table(
      columnWidths: _estSubstitution
          ? const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
            }
          : const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
            },
      border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade300)),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            const _CelluleEntete('Date'),
            const _CelluleEntete('Dose'),
            const _CelluleEntete('% dose init.'),
            if (_estSubstitution) const _CelluleEntete('Dose subst.'),
          ],
        ),
        for (final etape in widget.etapes)
          TableRow(
            decoration: etape == etapeActuelle
                ? BoxDecoration(color: AppColors.primaryColor.withValues(alpha: 0.1))
                : null,
            children: [
              _Cellule(_formatDate(etape.date),
                  attenue: etape.date.isBefore(maintenant) && etape != etapeActuelle),
              _Cellule('${etape.dose} ${widget.medicament.unite}',
                  attenue: etape.date.isBefore(maintenant) && etape != etapeActuelle),
              _Cellule(
                widget.medicament.doseInitiale == 0
                    ? '—'
                    : '${((etape.dose / widget.medicament.doseInitiale) * 100).toStringAsFixed(0)}%',
                attenue: etape.date.isBefore(maintenant) && etape != etapeActuelle,
              ),
              if (_estSubstitution)
                _Cellule(
                  etape.doseSubstitution != null
                      ? '${etape.doseSubstitution} ${widget.medicament.unite}'
                      : '—',
                  attenue: etape.date.isBefore(maintenant) && etape != etapeActuelle,
                ),
            ],
          ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _ouvrirFormulaireGeneration(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FormulaireGenerationSheet(
        medicament: widget.medicament,
        onValider: widget.onGenererPlan,
      ),
    );
  }

  /// Capture le plan sous une forme stylisée et l'enregistre dans la
  /// galerie via `gal`. Le widget capturé n'est PAS la carte affichée
  /// à l'écran : c'est un widget dédié (_ContenuExportImage), monté
  /// hors-écran via un OverlayEntry, pour garantir une mise en page
  /// propre indépendamment de l'état replié/déplié de la carte.
  Future<void> _exporterImage(BuildContext context) async {
    setState(() => _exportEnCours = true);
    final boundaryKey = GlobalKey();
    late OverlayEntry entry;

    try {
      entry = OverlayEntry(
        builder: (context) => Positioned(
          left: -10000,
          top: 0,
          child: Material(
            type: MaterialType.transparency,
            child: RepaintBoundary(
              key: boundaryKey,
              child: _ContenuExportImage(
                medicament: widget.medicament,
                etapes: widget.etapes,
                sevrageTermine: _sevrageTermine,
                estSubstitution: _estSubstitution,
              ),
            ),
          ),
        ),
      );

      final overlay = Overlay.of(context);
      overlay.insert(entry);

      // Laisse le temps à Flutter de layout + peindre le widget hors-écran
      // avant de tenter la capture.
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 50));

      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Rendu introuvable pour la capture.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      entry.remove();

      if (byteData == null) throw Exception('Échec de conversion en PNG.');
      final Uint8List bytes = byteData.buffer.asUint8List();

      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final accorde = await Gal.requestAccess();
        if (!accorde) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Accès à la galerie refusé.')),
          );
          return;
        }
      }

      await Gal.putImageBytes(
        bytes,
        name: 'plan_sevrage_${widget.medicament.nom}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image enregistrée dans la galerie.')),
      );
    } catch (e) {
      if (entry.mounted) entry.remove();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'export : $e')),
      );
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }
}

class _CelluleEntete extends StatelessWidget {
  final String texte;
  const _CelluleEntete(this.texte);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(texte, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
      child: Text(texte, style: TextStyle(fontSize: 13, color: attenue ? Colors.grey : null)),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget dédié à l'export image — stylisé, mis en page indépendamment
// de l'écran (fond blanc opaque obligatoire pour un PNG lisible).
// ---------------------------------------------------------------------------

class _ContenuExportImage extends StatelessWidget {
  final Medicament medicament;
  final List<EtapePalier> etapes;
  final bool sevrageTermine;
  final bool estSubstitution;

  const _ContenuExportImage({
    required this.medicament,
    required this.etapes,
    required this.sevrageTermine,
    required this.estSubstitution,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.medication_outlined, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    medicament.nom,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sevrageTermine ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sevrageTermine ? 'Sevrage terminé' : 'En cours',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sevrageTermine ? Colors.green.shade800 : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(medicament.classe, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            'Dose de départ : ${medicament.doseInitiale} ${medicament.unite}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (estSubstitution && medicament.moleculeSubstitution != null) ...[
            const SizedBox(height: 4),
            Text(
              'Substitution vers : ${medicament.moleculeSubstitution}',
              style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 20),
          Table(
            columnWidths: estSubstitution
                ? const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2)}
                : const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2)},
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey.shade300),
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: [
                  const _CelluleExportEntete('Date'),
                  _CelluleExportEntete('Dose ${medicament.unite}'),
                  if (estSubstitution)
                    _CelluleExportEntete('${medicament.moleculeSubstitution ?? "Subst."}'),
                ],
              ),
              for (final etape in etapes)
                TableRow(
                  children: [
                    _CelluleExport(_formatDate(etape.date)),
                    _CelluleExport('${etape.dose}'),
                    if (estSubstitution)
                      _CelluleExport(
                          etape.doseSubstitution != null ? '${etape.doseSubstitution}' : '—'),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Généré le ${_formatDate(DateTime.now())} — Mon suivi médical',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          const Text(
            'À valider avec un médecin ou pharmacien.',
            style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _CelluleExportEntete extends StatelessWidget {
  final String texte;
  const _CelluleExportEntete(this.texte);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(texte, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _CelluleExport extends StatelessWidget {
  final String texte;
  const _CelluleExport(this.texte);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(texte, style: const TextStyle(fontSize: 12)),
    );
  }
}

// ---------------------------------------------------------------------------
// Formulaire de génération — plan simple ou plan de substitution
// ---------------------------------------------------------------------------

class _FormulaireGenerationSheet extends StatefulWidget {
  final Medicament medicament;
  final void Function(double pourcentage, int delaiJours, DateTime dateDebut,
      double? ratioSubstitution) onValider;

  const _FormulaireGenerationSheet({
    required this.medicament,
    required this.onValider,
  });

  @override
  State<_FormulaireGenerationSheet> createState() => _FormulaireGenerationSheetState();
}

class _FormulaireGenerationSheetState extends State<_FormulaireGenerationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _pourcentageController = TextEditingController(text: '10');
  final _delaiController = TextEditingController(text: '14');
  final _ratioController = TextEditingController();
  DateTime _dateDebut = DateTime.now();
  bool _modeSubstitution = false;

  bool get _substitutionDisponible =>
      widget.medicament.moleculeSubstitution != null &&
      widget.medicament.moleculeSubstitution!.isNotEmpty;

  @override
  void dispose() {
    _pourcentageController.dispose();
    _delaiController.dispose();
    _ratioController.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateDebut,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _dateDebut = date);
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    widget.onValider(
      double.parse(_pourcentageController.text.trim()),
      int.parse(_delaiController.text.trim()),
      _dateDebut,
      _modeSubstitution ? double.parse(_ratioController.text.trim()) : null,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repere = RepereAshton.pour(widget.medicament.ancienneteTraitementMois);

    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Générer le plan — ${widget.medicament.nom}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dose de départ : ${widget.medicament.doseInitiale} '
                    '${widget.medicament.unite} · réduction calculée sur la dose courante',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Repères informatifs (manuel Ashton, résumé public)',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 6),
                        Text('• Réduction habituelle : ${repere.pourcentageConseille}',
                            style: const TextStyle(fontSize: 12)),
                        Text('• Délai habituel entre paliers : ${repere.delaiConseille}',
                            style: const TextStyle(fontSize: 12)),
                        if (repere.dureeGlobaleEstimee != null)
                          Text(
                            '• Durée totale habituelle pour cette ancienneté de traitement : '
                            '${repere.dureeGlobaleEstimee}',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pourcentageController,
                    decoration: const InputDecoration(
                      labelText: 'Réduction par palier (% de la dose courante)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setSheetState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Champ requis';
                      final pct = double.tryParse(value.trim());
                      if (pct == null) return 'Nombre invalide';
                      if (pct <= 0 || pct >= 100) return 'Doit être entre 0 et 100';
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
                    onChanged: (_) => setSheetState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Champ requis';
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed <= 0) return 'Entier positif requis';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Date de départ : ${_dateDebut.day.toString().padLeft(2, '0')}/'
                      '${_dateDebut.month.toString().padLeft(2, '0')}/${_dateDebut.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: _choisirDate,
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Basculer vers un médicament de substitution'),
                    subtitle: Text(
                      _substitutionDisponible
                          ? 'Vers : ${widget.medicament.moleculeSubstitution}'
                          : 'Renseignez d\'abord une molécule de substitution dans la fiche médicament.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _substitutionDisponible ? Colors.grey : Colors.red,
                      ),
                    ),
                    value: _modeSubstitution,
                    onChanged: _substitutionDisponible
                        ? (value) => setSheetState(() => _modeSubstitution = value)
                        : null,
                  ),
                  if (_modeSubstitution) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade700),
                      ),
                      child: const Text(
                        'Le ratio d\'équivalence entre les deux molécules doit être '
                        'validé par un médecin ou pharmacien. Une valeur incorrecte '
                        'produit un plan de substitution incorrect.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ratioController,
                      decoration: InputDecoration(
                        labelText: 'Ratio d\'équivalence (mg de '
                            '${widget.medicament.moleculeSubstitution} par mg de '
                            '${widget.medicament.nom})',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (!_modeSubstitution) return null;
                        if (value == null || value.trim().isEmpty) return 'Champ requis';
                        final ratio = double.tryParse(value.trim());
                        if (ratio == null || ratio <= 0) return 'Nombre positif requis';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Le dernier palier passe automatiquement à 0 dès que la dose '
                    'restante atteint environ 5 % de la dose de départ, pour '
                    'garantir une fin de plan.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
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
          ),
        );
      },
    );
  }
}