import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medico/constants/colors.dart';
import 'package:medico/data/medicaments_repository.dart';
import 'package:medico/data/paliers_repository.dart';
import 'package:medico/views/medicaments_page.dart' show Medicament;

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Général', icon: Icon(Icons.settings_outlined)),
            Tab(text: 'Import/Export', icon: Icon(Icons.swap_vert)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_GeneralTab(), _ImportExportGlobalTab()],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet 1 : Général
// ---------------------------------------------------------------------------

class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(
          titre: 'Données',
          enfants: [
            ListTile(
              leading: const Icon(
                Icons.delete_sweep_outlined,
                color: Colors.red,
              ),
              title: const Text('Réinitialiser toutes les données'),
              subtitle: const Text(
                'Supprime tous les médicaments et plans de sevrage enregistrés.',
              ),
              onTap: () => _confirmerReinitialisation(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          titre: 'À propos',
          enfants: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: const Text(
                  'Cette application est un outil de suivi personnel. '
                  'Tout plan de réduction de dose doit être établi et '
                  'validé par un médecin ou un pharmacien. Ne modifiez '
                  'jamais un traitement sans avis médical.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Version'),
              subtitle: Text('1.0.1'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({required String titre, required List<Widget> enfants}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            titre,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: enfants),
        ),
      ],
    );
  }

  Future<void> _confirmerReinitialisation(BuildContext context) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tout réinitialiser ?'),
        content: const Text(
          'Cette action supprime définitivement tous vos médicaments et '
          'tous vos plans de sevrage, y compris l\'historique des paliers '
          'déjà atteints. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Réinitialiser',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirme != true || !context.mounted) return;

    final medicamentsRepo = MedicamentsRepository.instance;
    final paliersRepo = PaliersRepository.instance;

    for (final medicament in List.of(medicamentsRepo.medicaments)) {
      await paliersRepo.supprimerPlan(medicament.id);
    }
    await medicamentsRepo.remplacerTout([]);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toutes les données ont été réinitialisées.'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet 2 : Import / Export global (médicaments + paliers)
// ---------------------------------------------------------------------------

class _ImportExportGlobalTab extends StatefulWidget {
  const _ImportExportGlobalTab();

  @override
  State<_ImportExportGlobalTab> createState() => _ImportExportGlobalTabState();
}

class _ImportExportGlobalTabState extends State<_ImportExportGlobalTab> {
  final _importController = TextEditingController();
  String? _erreurImport;

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
    _importController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// Format d'export global : médicaments + paliers, regroupés en un
  /// seul objet JSON encodé en base64. Distinct du code d'export de
  /// l'onglet "Mes médicaments" (qui n'exporte que les médicaments) —
  /// les deux formats ne sont PAS interchangeables.
  String get _codeExport {
    final medicaments = _medicamentsRepo.medicaments;
    final paliersParMedicament = <String, dynamic>{};
    for (final medicament in medicaments) {
      final etapes = _paliersRepo.paliersPour(medicament.id);
      if (etapes.isNotEmpty) {
        paliersParMedicament[medicament.id] = etapes
            .map((e) => e.toJson())
            .toList();
      }
    }

    final data = {
      'version': 1,
      'medicaments': medicaments.map((m) => m.toJson()).toList(),
      'paliers': paliersParMedicament,
    };
    return base64Encode(utf8.encode(jsonEncode(data)));
  }

  void _copierCode() {
    Clipboard.setData(ClipboardData(text: _codeExport));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copié dans le presse-papiers')),
    );
  }

  Future<void> _importerCode() async {
    setState(() => _erreurImport = null);
    try {
      final jsonStr = utf8.decode(base64Decode(_importController.text.trim()));
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      final List<dynamic> medicamentsJson = data['medicaments'] as List? ?? [];
      final medicaments = medicamentsJson
          .map((e) => Medicament.fromJson(e as Map<String, dynamic>))
          .toList();

      final Map<String, dynamic> paliersJson =
          data['paliers'] as Map<String, dynamic>? ?? {};

      final confirme = await _confirmerRemplacement(context);
      if (confirme != true || !context.mounted) return;

      await _medicamentsRepo.remplacerTout(medicaments);

      // Remplace le plan de chaque médicament existant dans l'export.
      // Un médicament du repository actuel absent de l'export garde
      // son plan tel quel — cet import ne vide que ce qu'il connaît.
      for (final medicament in medicaments) {
        await _paliersRepo.supprimerPlan(medicament.id);
        final etapesJson = paliersJson[medicament.id] as List?;
        if (etapesJson != null && etapesJson.isNotEmpty) {
          await _paliersRepo.remplacerPaliers(
            medicament.id,
            etapesJson
                .map((e) => EtapePalier.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${medicaments.length} médicament(s) importé(s).'),
        ),
      );
    } catch (_) {
      setState(() => _erreurImport = 'Code invalide ou mal formaté.');
    }
  }

  Future<bool?> _confirmerRemplacement(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remplacer les données actuelles ?'),
        content: const Text(
          'L\'import va remplacer tous vos médicaments et plans de '
          'sevrage actuels par ceux du code importé. Cette action est '
          'irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remplacer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Exporter toutes les données',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Inclut vos médicaments ET vos plans de sevrage (paliers '
            'passés et futurs). Copiez ce code pour sauvegarder ou '
            'transférer vos données vers un autre appareil.',
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
            'Collez un code exporté depuis cette page. Cela remplacera '
            'tous les médicaments et plans de sevrage actuels.',
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
