import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:medico/constants/colors.dart';
import 'package:medico/data/medicaments_repository.dart';
import 'package:medico/data/symptomes_repository.dart';
import 'package:medico/views/medicaments_page.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final _symptomesRepo = SymptomesRepository.instance;
  final _medicamentsRepo = MedicamentsRepository.instance;
  bool _exportEnCours = false;

  @override
  void initState() {
    super.initState();
    _symptomesRepo.addListener(_onChanged);
    _medicamentsRepo.addListener(_onChanged);
  }

  @override
  void dispose() {
    _symptomesRepo.removeListener(_onChanged);
    _medicamentsRepo.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final symptomes = _symptomesRepo.symptomes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal des symptômes'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _exportEnCours
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.image_outlined),
            tooltip: 'Exporter le journal en image',
            onPressed: (symptomes.isEmpty || _exportEnCours)
                ? null
                : () => _exporterImage(context, symptomes),
          ),
        ],
      ),
      body: SafeArea(
        child: symptomes.isEmpty
            ? _buildEmptyState()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: symptomes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildLigne(symptomes[index]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaireAjout(context),
        backgroundColor: AppColors.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white)),
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
              Icons.edit_note_outlined,
              size: 64,
              color: AppColors.primaryColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun symptôme noté pour le moment.\n'
              'Utilisez le bouton "Ajouter" pour commencer votre journal.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLigne(Symptome symptome) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _couleurIntensite(
                      symptome.intensite,
                    ).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${symptome.intensite}',
                    style: TextStyle(
                      color: _couleurIntensite(symptome.intensite),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    symptome.medicamentNom ?? 'Symptôme général',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(symptome.date),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () => _confirmerSuppression(symptome),
                ),
              ],
            ),
            if (symptome.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 44),
                child: Text(
                  symptome.note,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _couleurIntensite(int intensite) {
    if (intensite <= 2) return Colors.green;
    if (intensite == 3) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _confirmerSuppression(Symptome symptome) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette entrée ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirme == true) {
      await _symptomesRepo.supprimer(symptome.id);
    }
  }

  Future<void> _ouvrirFormulaireAjout(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FormulaireAjoutSheet(
        medicaments: _medicamentsRepo.medicaments,
        onValider: (symptome) => _symptomesRepo.ajouter(symptome),
      ),
    );
  }

  Future<void> _exporterImage(
    BuildContext context,
    List<Symptome> symptomes,
  ) async {
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
              child: _ContenuExportJournal(symptomes: symptomes),
            ),
          ),
        ),
      );

      final overlay = Overlay.of(context);
      overlay.insert(entry);

      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 50));

      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Rendu introuvable pour la capture.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
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
        name: 'journal_symptomes_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image enregistrée dans la galerie.')),
      );
    } catch (e) {
      if (entry.mounted) entry.remove();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec de l\'export : $e')));
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Widget dédié à l'export image du journal complet
// ---------------------------------------------------------------------------

class _ContenuExportJournal extends StatelessWidget {
  final List<Symptome> symptomes;

  const _ContenuExportJournal({required this.symptomes});

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
                Icon(Icons.edit_note_outlined, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Journal des symptômes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${symptomes.length} entrée(s)',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          for (final symptome in symptomes) _buildLigneExport(symptome),
          const SizedBox(height: 12),
          Text(
            'Généré le ${_formatDate(DateTime.now())} — Mon suivi médical',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLigneExport(Symptome symptome) {
    final couleur = symptome.intensite <= 2
        ? Colors.green
        : (symptome.intensite == 3 ? Colors.orange : Colors.red);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${symptome.intensite}',
              style: TextStyle(
                color: couleur,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        symptome.medicamentNom ?? 'Symptôme général',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(symptome.date),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                if (symptome.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      symptome.note,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

// ---------------------------------------------------------------------------
// Formulaire d'ajout
// ---------------------------------------------------------------------------

class _FormulaireAjoutSheet extends StatefulWidget {
  final List<Medicament> medicaments;
  final void Function(Symptome) onValider;

  const _FormulaireAjoutSheet({
    required this.medicaments,
    required this.onValider,
  });

  @override
  State<_FormulaireAjoutSheet> createState() => _FormulaireAjoutSheetState();
}

class _FormulaireAjoutSheetState extends State<_FormulaireAjoutSheet> {
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  int _intensite = 3;
  Medicament? _medicamentSelectionne;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _date = date);
  }

  void _valider() {
    widget.onValider(
      Symptome(
        date: _date,
        medicamentId: _medicamentSelectionne?.id,
        medicamentNom: _medicamentSelectionne?.nom,
        intensite: _intensite,
        note: _noteController.text.trim(),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nouvelle entrée',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Date : ${_date.day.toString().padLeft(2, '0')}/'
                    '${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _choisirDate,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Medicament?>(
                  initialValue: _medicamentSelectionne,
                  decoration: const InputDecoration(
                    labelText: 'Médicament concerné (facultatif)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<Medicament?>(
                      value: null,
                      child: Text('Symptôme général'),
                    ),
                    ...widget.medicaments.map(
                      (m) => DropdownMenuItem<Medicament?>(
                        value: m,
                        child: Text(m.nom),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => _medicamentSelectionne = value),
                ),
                const SizedBox(height: 16),
                Text(
                  'Intensité ressentie : $_intensite / 5',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Slider(
                  value: _intensite.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$_intensite',
                  onChanged: (value) =>
                      setSheetState(() => _intensite = value.round()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Note (facultatif)',
                    border: OutlineInputBorder(),
                    hintText: 'ex : insomnie, irritabilité, nausées...',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _valider,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
