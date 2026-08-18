import 'package:flutter/material.dart';
import 'package:medico/constants/colors.dart';
import 'package:medico/data/medicaments_repository.dart';
import 'package:medico/data/paliers_repository.dart';

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres'), centerTitle: true),
      body: SafeArea(
        child: ListView(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                  subtitle: Text('1.0.0'),
                ),
              ],
            ),
          ],
        ),
      ),
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
    medicamentsRepo.remplacerTout([]);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toutes les données ont été réinitialisées.'),
      ),
    );
  }
}
