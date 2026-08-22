import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:medico/constants/colors.dart';
import 'package:medico/data/contacts_medicaux_repository.dart';

class ContactsMedicauxPage extends StatefulWidget {
  const ContactsMedicauxPage({super.key});

  @override
  State<ContactsMedicauxPage> createState() => _ContactsMedicauxPageState();
}

class _ContactsMedicauxPageState extends State<ContactsMedicauxPage>
    with SingleTickerProviderStateMixin {
  final _repository = ContactsMedicauxRepository.instance;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts médicaux'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Contacts', icon: Icon(Icons.contacts_outlined)),
            Tab(text: 'Import/Export', icon: Icon(Icons.swap_vert)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ListeTab(repository: _repository),
          _ImportExportTab(repository: _repository),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) => _tabController.index == 0
            ? FloatingActionButton.extended(
                onPressed: () => _ouvrirFormulaire(context, null),
                backgroundColor: AppColors.primaryColor,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Ajouter',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _ouvrirFormulaire(
    BuildContext context,
    ContactMedical? contact,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FormulaireContactSheet(
        contactInitial: contact,
        onValider: (c) => _repository.ajouterOuMettreAJour(c),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet 1 : Liste des contacts
// ---------------------------------------------------------------------------

class _ListeTab extends StatelessWidget {
  final ContactsMedicauxRepository repository;

  const _ListeTab({required this.repository});

  @override
  Widget build(BuildContext context) {
    final contacts = repository.contacts;

    return SafeArea(
      child: contacts.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: contacts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _buildLigne(context, contacts[index]),
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
              Icons.contact_phone_outlined,
              size: 64,
              color: AppColors.primaryColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun contact médical enregistré.\n'
              'Utilisez le bouton "Ajouter" pour commencer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  // Tuile de contact (ajouter ville)
  Widget _buildLigne(BuildContext context, ContactMedical contact) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
          child: Icon(Icons.person_outline, color: AppColors.primaryColor),
        ),
        title: Text(
          contact.nom,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(contact.qualite),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _ouvrirFicheContact(context, contact),
      ),
    );
  }

  // Widget _buildLigne(BuildContext context, ContactMedical contact) {
  //   return Card(
  //     margin: EdgeInsets.zero,
  //     child: ListTile(
  //       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //       leading: CircleAvatar(
  //         backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
  //         child: Icon(Icons.person_outline, color: AppColors.primaryColor),
  //       ),
  //       title: Text(
  //         contact.nom,
  //         style: const TextStyle(fontWeight: FontWeight.w600),
  //       ),
  //       subtitle: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(contact.qualite),
  //           Text(
  //             contact.ville,
  //             style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
  //           ),
  //         ],
  //       ),
  //       trailing: const Icon(Icons.chevron_right),
  //       onTap: () => _ouvrirFicheContact(context, contact),
  //     ),
  //   );
  // }

  void _ouvrirFicheContact(BuildContext context, ContactMedical contact) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FicheContactSheet(
        contact: contact,
        onModifier: () {
          Navigator.pop(context);
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (context) => _FormulaireContactSheet(
              contactInitial: contact,
              onValider: (c) => repository.ajouterOuMettreAJour(c),
            ),
          );
        },
        onSupprimer: () async {
          final confirme = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Supprimer ce contact ?'),
              content: const Text('Cette action est irréversible.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Supprimer',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
          if (confirme == true) {
            await repository.supprimer(contact.id);
            if (context.mounted) Navigator.pop(context);
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet 2 : Import / Export au format pipe
// ---------------------------------------------------------------------------

/// Format d'export : une ligne par contact, champs séparés par des `|`.
/// Chaque champ est encodé via Uri.encodeComponent AVANT d'être joint,
/// pour que le caractère `|` (ou un saut de ligne) présent dans une note
/// ou une adresse ne casse jamais le découpage à l'import. Le résultat
/// reste un texte pipe lisible, pas du base64.
///
/// Ordre des champs : id|nom|qualite|telephone|email|adressePostale|note
class _CodecPipeContacts {
  static String exporter(List<ContactMedical> contacts) {
    return contacts
        .map((c) {
          final champs = [
            c.id,
            c.nom,
            c.qualite,
            c.telephone ?? '',
            c.email ?? '',
            c.adressePostale ?? '',
            c.note,
          ];
          return champs.map(Uri.encodeComponent).join('|');
        })
        .join('\n');
  }

  /// Lance une [FormatException] si une ligne est mal formée.
  static List<ContactMedical> importer(String code) {
    final lignes = code
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return lignes.map((ligne) {
      final champs = ligne.split('|');
      if (champs.length != 7) {
        throw const FormatException(
          'Ligne mal formée (nombre de champs incorrect).',
        );
      }
      final decodes = champs.map(Uri.decodeComponent).toList();
      return ContactMedical(
        id: decodes[0].isEmpty ? null : decodes[0],
        nom: decodes[1],
        qualite: decodes[2],
        telephone: decodes[3].isEmpty ? null : decodes[3],
        email: decodes[4].isEmpty ? null : decodes[4],
        adressePostale: decodes[5].isEmpty ? null : decodes[5],
        note: decodes[6],
      );
    }).toList();
  }
}

class _ImportExportTab extends StatefulWidget {
  final ContactsMedicauxRepository repository;

  const _ImportExportTab({required this.repository});

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

  String get _codeExport =>
      _CodecPipeContacts.exporter(widget.repository.contacts);

  void _copierCode() {
    Clipboard.setData(ClipboardData(text: _codeExport));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copié dans le presse-papiers')),
    );
  }

  Future<void> _importerCode() async {
    setState(() => _erreurImport = null);
    try {
      final contacts = _CodecPipeContacts.importer(_importController.text);
      if (contacts.isEmpty) {
        setState(
          () => _erreurImport = 'Aucun contact valide trouvé dans le code.',
        );
        return;
      }

      final confirme = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Importer ces contacts ?'),
          content: Text(
            '${contacts.length} contact(s) seront ajoutés ou mis à jour '
            '(un contact existant avec le même identifiant sera écrasé).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importer'),
            ),
          ],
        ),
      );
      if (confirme != true || !context.mounted) return;

      for (final contact in contacts) {
        await widget.repository.ajouterOuMettreAJour(contact);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${contacts.length} contact(s) importé(s).')),
      );
      _importController.clear();
    } catch (e) {
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
            'Une ligne par contact, champs séparés par des pipes ( | ). '
            'Copiez ce code pour sauvegarder ou transférer vos contacts.',
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
                _codeExport.isEmpty
                    ? '(aucun contact à exporter)'
                    : _codeExport,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: widget.repository.contacts.isEmpty ? null : _copierCode,
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
            'Collez un code exporté depuis cet onglet. Un contact avec le '
            'même identifiant sera mis à jour ; les autres seront ajoutés.',
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
// Formatage d'affichage / de saisie du numéro de téléphone
// ---------------------------------------------------------------------------

/// Regroupe les chiffres d'un numéro par paires, séparées par des
/// espaces (convention française : "06 12 34 56 78"). Ignore tout
/// caractère non numérique déjà présent (espaces, points, tirets).
String formatTelephoneAffichage(String telephone) {
  final chiffres = telephone.replaceAll(RegExp(r'[^0-9+]'), '');
  final buffer = StringBuffer();
  int compteur = 0;
  for (final char in chiffres.split('')) {
    if (char == '+') {
      buffer.write(char);
      continue;
    }
    if (compteur > 0 && compteur % 2 == 0) buffer.write(' ');
    buffer.write(char);
    compteur++;
  }
  return buffer.toString();
}

/// TextInputFormatter qui insère automatiquement un espace tous les
/// 2 chiffres pendant la saisie. Repositionne le curseur en fin de
/// champ à chaque frappe — simplification qui fonctionne bien pour une
/// saisie linéaire (taper au clavier) mais peut déplacer le curseur de
/// façon inattendue si l'utilisateur édite au milieu du numéro déjà
/// saisi (ex: correction d'un chiffre en début de numéro).
class TelephoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formate = formatTelephoneAffichage(newValue.text);
    return TextEditingValue(
      text: formate,
      selection: TextSelection.collapsed(offset: formate.length),
    );
  }
}

// ---------------------------------------------------------------------------
// Fiche détail + actions (appel, email, itinéraire, partage, export)
// ---------------------------------------------------------------------------

class _FicheContactSheet extends StatefulWidget {
  final ContactMedical contact;
  final VoidCallback onModifier;
  final VoidCallback onSupprimer;

  const _FicheContactSheet({
    required this.contact,
    required this.onModifier,
    required this.onSupprimer,
  });

  @override
  State<_FicheContactSheet> createState() => _FicheContactSheetState();
}

class _FicheContactSheetState extends State<_FicheContactSheet> {
  bool _actionEnCours = false;

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    contact.nom,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: widget.onModifier,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: widget.onSupprimer,
                ),
              ],
            ),
            Text(
              contact.qualite,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (contact.telephone != null && contact.telephone!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: Text(formatTelephoneAffichage(contact.telephone!)),
                trailing: const Icon(Icons.call, size: 20),
                onTap: () => _appeler(contact.telephone!),
              ),
            if (contact.email != null && contact.email!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: Text(contact.email!),
                trailing: const Icon(Icons.send, size: 20),
                onTap: () => _envoyerEmail(contact.email!),
              ),
            if (contact.adressePostale != null &&
                contact.adressePostale!.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(contact.adressePostale!),
                trailing: const Icon(Icons.map_outlined, size: 20),
                onTap: () => _ouvrirMaps(contact.adressePostale!),
              ),
            if (contact.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Note',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(contact.note, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Partager cette fiche',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _actionEnCours
                      ? null
                      : () => _partagerTexte(contact),
                  icon: const Icon(Icons.text_snippet_outlined, size: 18),
                  label: const Text('Texte'),
                ),
                OutlinedButton.icon(
                  onPressed: _actionEnCours
                      ? null
                      : () => _partagerImage(context, contact),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Image'),
                ),
                OutlinedButton.icon(
                  onPressed: _actionEnCours
                      ? null
                      : () => _exporterImageGalerie(context, contact),
                  icon: _actionEnCours
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Enregistrer l\'image'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _appeler(String telephone) async {
    final uri = Uri(scheme: 'tel', path: telephone);
    if (!await launchUrl(uri)) {
      _erreur('Impossible de lancer l\'appel.');
    }
  }

  Future<void> _envoyerEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (!await launchUrl(uri)) {
      _erreur('Impossible d\'ouvrir l\'application e-mail.');
    }
  }

  Future<void> _ouvrirMaps(String adresse) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': adresse,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _erreur('Impossible d\'ouvrir la carte.');
    }
  }

  void _erreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _texteFiche(ContactMedical contact) {
    final buffer = StringBuffer()
      ..writeln(contact.nom)
      ..writeln(contact.qualite);
    if (contact.telephone != null && contact.telephone!.isNotEmpty) {
      buffer.writeln('Tél : ${formatTelephoneAffichage(contact.telephone!)}');
    }
    if (contact.email != null && contact.email!.isNotEmpty) {
      buffer.writeln('Email : ${contact.email}');
    }
    if (contact.adressePostale != null && contact.adressePostale!.isNotEmpty) {
      buffer.writeln('Adresse : ${contact.adressePostale}');
    }
    if (contact.note.isNotEmpty) {
      buffer.writeln('Note : ${contact.note}');
    }
    return buffer.toString();
  }

  Future<void> _partagerTexte(ContactMedical contact) async {
    await SharePlus.instance.share(
      ShareParams(
        text: _texteFiche(contact),
        subject: 'Contact médical — ${contact.nom}',
      ),
    );
  }

  Future<Uint8List> _capturerImageFiche(
    BuildContext context,
    ContactMedical contact,
  ) async {
    final boundaryKey = GlobalKey();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,
        top: 0,
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(
            key: boundaryKey,
            child: _ContenuExportContact(contact: contact),
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
      entry.remove();
      throw Exception('Rendu introuvable pour la capture.');
    }

    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    entry.remove();

    if (byteData == null) throw Exception('Échec de conversion en PNG.');
    return byteData.buffer.asUint8List();
  }

  Future<void> _partagerImage(
    BuildContext context,
    ContactMedical contact,
  ) async {
    setState(() => _actionEnCours = true);
    try {
      final bytes = await _capturerImageFiche(context, contact);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'image/png', name: 'contact.png'),
          ],
          fileNameOverrides: ['contact_${contact.nom}.png'],
          subject: 'Contact médical — ${contact.nom}',
        ),
      );
    } catch (e) {
      _erreur('Échec du partage : $e');
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  Future<void> _exporterImageGalerie(
    BuildContext context,
    ContactMedical contact,
  ) async {
    setState(() => _actionEnCours = true);
    try {
      final bytes = await _capturerImageFiche(context, contact);

      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final accorde = await Gal.requestAccess();
        if (!accorde) {
          _erreur('Accès à la galerie refusé.');
          return;
        }
      }

      await Gal.putImageBytes(
        bytes,
        name: 'contact_${contact.nom}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image enregistrée dans la galerie.')),
      );
    } catch (e) {
      _erreur('Échec de l\'export : $e');
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Widget dédié à l'export image de la fiche contact
// ---------------------------------------------------------------------------

class _ContenuExportContact extends StatelessWidget {
  final ContactMedical contact;

  const _ContenuExportContact({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
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
                Icon(
                  Icons.contact_phone_outlined,
                  color: AppColors.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    contact.nom,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            contact.qualite,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (contact.telephone != null && contact.telephone!.isNotEmpty)
            _ligneExport(
              Icons.phone_outlined,
              formatTelephoneAffichage(contact.telephone!),
            ),
          if (contact.email != null && contact.email!.isNotEmpty)
            _ligneExport(Icons.email_outlined, contact.email!),
          if (contact.adressePostale != null &&
              contact.adressePostale!.isNotEmpty)
            _ligneExport(Icons.location_on_outlined, contact.adressePostale!),
          if (contact.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(contact.note, style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Text(
            'Mon suivi médical',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _ligneExport(IconData icone, String texte) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icone, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Formulaire d'ajout / modification
// ---------------------------------------------------------------------------

class _FormulaireContactSheet extends StatefulWidget {
  final ContactMedical? contactInitial;
  final void Function(ContactMedical) onValider;

  const _FormulaireContactSheet({
    required this.contactInitial,
    required this.onValider,
  });

  @override
  State<_FormulaireContactSheet> createState() =>
      _FormulaireContactSheetState();
}

class _FormulaireContactSheetState extends State<_FormulaireContactSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late final TextEditingController _qualiteController;
  late final TextEditingController _telephoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _adresseController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final c = widget.contactInitial;
    _nomController = TextEditingController(text: c?.nom ?? '');
    _qualiteController = TextEditingController(text: c?.qualite ?? '');
    _telephoneController = TextEditingController(
      text: c?.telephone != null ? formatTelephoneAffichage(c!.telephone!) : '',
    );
    _emailController = TextEditingController(text: c?.email ?? '');
    _adresseController = TextEditingController(text: c?.adressePostale ?? '');
    _noteController = TextEditingController(text: c?.note ?? '');
  }

  @override
  void dispose() {
    _nomController.dispose();
    _qualiteController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _adresseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    // Stocke le téléphone sans les espaces d'affichage — la mise en forme
    // est reconstruite à la volée via formatTelephoneAffichage() partout
    // où il est montré, pour rester compatible avec `tel:` (qui tolère
    // les espaces mais autant stocker une forme brute).
    final telephoneBrut = _telephoneController.text.replaceAll(' ', '').trim();

    widget.onValider(
      ContactMedical(
        id: widget.contactInitial?.id,
        nom: _nomController.text.trim(),
        qualite: _qualiteController.text.trim(),
        telephone: telephoneBrut.isEmpty ? null : telephoneBrut,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        adressePostale: _adresseController.text.trim().isEmpty
            ? null
            : _adresseController.text.trim(),
        note: _noteController.text.trim(),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final estModification = widget.contactInitial != null;

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
                estModification ? 'Modifier le contact' : 'Nouveau contact',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qualiteController,
                decoration: const InputDecoration(
                  labelText:
                      'Qualité (ex : médecin généraliste, psychologue...)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telephoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (facultatif)',
                  border: OutlineInputBorder(),
                  hintText: '06 12 34 56 78',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [TelephoneInputFormatter()],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (facultatif)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adresseController,
                decoration: const InputDecoration(
                  labelText: 'Adresse postale (facultatif)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note personnelle (facultatif)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _valider,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(estModification ? 'Mettre à jour' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
