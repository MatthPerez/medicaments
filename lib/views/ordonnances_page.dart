import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:medico/constants/colors.dart';
import 'package:medico/data/ordonnances_repository.dart';

class OrdonnancesPage extends StatefulWidget {
  const OrdonnancesPage({super.key});

  @override
  State<OrdonnancesPage> createState() => _OrdonnancesPageState();
}

class _OrdonnancesPageState extends State<OrdonnancesPage>
    with SingleTickerProviderStateMixin {
  final _repository = OrdonnancesRepository.instance;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repository.addListener(_onChanged);
  }

  @override
  void dispose() {
    _repository.removeListener(_onChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!_repository.estCharge) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordonnances'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Documents', icon: Icon(Icons.description_outlined)),
            Tab(text: 'Import/Export', icon: Icon(Icons.folder_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DocumentsTab(repository: _repository),
          _ImportExportTab(repository: _repository),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet 1 : Affichage et CRUD des documents
// ---------------------------------------------------------------------------

class _DocumentsTab extends StatefulWidget {
  final OrdonnancesRepository repository;

  const _DocumentsTab({required this.repository});

  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  bool _ajoutEnCours = false;

  @override
  Widget build(BuildContext context) {
    final documents = widget.repository.documents;

    return Scaffold(
      body: documents.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: documents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _buildLigne(documents[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajoutEnCours ? null : _ajouterDocument,
        backgroundColor: AppColors.primaryColor,
        icon: _ajoutEnCours
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Ajouter un PDF',
          style: TextStyle(color: Colors.white),
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
              Icons.picture_as_pdf_outlined,
              size: 64,
              color: AppColors.primaryColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune ordonnance enregistrée.\n'
              'Utilisez le bouton "Ajouter un PDF" pour commencer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLigne(DocumentOrdonnance doc) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
          child: Icon(
            Icons.picture_as_pdf_outlined,
            color: AppColors.primaryColor,
          ),
        ),
        title: Text(
          doc.nomAffichage,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('Ajouté le ${_formatDate(doc.dateAjout)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Partager',
              onPressed: () => _partager(doc),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Supprimer',
              onPressed: () => _confirmerSuppression(doc),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _ajouterDocument() async {
    setState(() => _ajoutEnCours = true);
    try {
      final fichiers = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (fichiers.isEmpty) return; // annulé par l'utilisateur

      final fichier = fichiers.first;
      if (fichier.path == null) {
        _erreur('Chemin de fichier indisponible sur cette plateforme.');
        return;
      }

      final nomAffichage = await _demanderNomAffichage(context, fichier.name);
      if (nomAffichage == null) return; // annulé dans la boîte de dialogue

      await widget.repository.ajouterDepuisFichier(
        cheminSource: fichier.path!,
        nomAffichage: nomAffichage,
      );
    } catch (e) {
      _erreur('Échec de l\'ajout : $e');
    } finally {
      if (mounted) setState(() => _ajoutEnCours = false);
    }
  }

  Future<String?> _demanderNomAffichage(
    BuildContext context,
    String nomParDefaut,
  ) {
    final controller = TextEditingController(text: nomParDefaut);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nom du document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.trim().isEmpty
                  ? nomParDefaut
                  : controller.text.trim(),
            ),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmerSuppression(DocumentOrdonnance doc) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce document ?'),
        content: Text('« ${doc.nomAffichage} » sera définitivement supprimé.'),
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
      await widget.repository.supprimer(doc.id);
    }
  }

  Future<void> _partager(DocumentOrdonnance doc) async {
    final chemin = widget.repository.cheminComplet(doc);
    if (!await File(chemin).exists()) {
      _erreur('Fichier introuvable sur le disque.');
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(chemin, name: doc.nomAffichage)]),
    );
  }

  void _erreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

// ---------------------------------------------------------------------------
// Onglet 2 : Import / Export via le gestionnaire de documents du système
// ---------------------------------------------------------------------------

class _ImportExportTab extends StatefulWidget {
  final OrdonnancesRepository repository;

  const _ImportExportTab({required this.repository});

  @override
  State<_ImportExportTab> createState() => _ImportExportTabState();
}

class _ImportExportTabState extends State<_ImportExportTab> {
  bool _actionEnCours = false;

  @override
  Widget build(BuildContext context) {
    final documents = widget.repository.documents;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Importer',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sélectionnez un ou plusieurs PDF depuis votre gestionnaire de '
            'fichiers (stockage local, Drive, iCloud...). Chaque document '
            'sera copié dans l\'application avec son nom d\'origine.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _actionEnCours ? null : _importerDepuisGestionnaire,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.file_open_outlined, color: Colors.white),
            label: const Text('Importer des documents'),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Exporter',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            documents.isEmpty
                ? 'Aucun document à exporter.'
                : 'Copie les ${documents.length} document(s) enregistré(s) '
                      'vers un dossier de votre choix.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: (_actionEnCours || documents.isEmpty)
                ? null
                : _exporterVersDossier,
            icon: _actionEnCours
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open_outlined),
            label: const Text('Exporter vers un dossier'),
          ),
        ],
      ),
    );
  }

  Future<void> _importerDepuisGestionnaire() async {
    setState(() => _actionEnCours = true);
    try {
      final fichiers = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      if (fichiers.isEmpty) return;

      int importes = 0;
      for (final fichier in fichiers) {
        if (fichier.path == null) continue;
        await widget.repository.ajouterDepuisFichier(
          cheminSource: fichier.path!,
          nomAffichage: fichier.name,
        );
        importes++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$importes document(s) importé(s).')),
      );
    } catch (e) {
      _erreur('Échec de l\'import : $e');
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  Future<void> _exporterVersDossier() async {
    setState(() => _actionEnCours = true);
    try {
      final dossierCible = await FilePicker.getDirectoryPath();
      if (dossierCible == null) return; // annulé

      int exportes = 0;
      for (final doc in widget.repository.documents) {
        final source = File(widget.repository.cheminComplet(doc));
        if (!await source.exists()) continue;
        final nomFichierExporte = '${doc.nomAffichage}.pdf'.replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_',
        ); // caractères interdits par les OS
        await source.copy('$dossierCible/$nomFichierExporte');
        exportes++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$exportes document(s) exporté(s).')),
      );
    } catch (e) {
      _erreur('Échec de l\'export : $e');
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  void _erreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
