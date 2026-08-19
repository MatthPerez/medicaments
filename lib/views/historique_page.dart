import 'package:flutter/material.dart';
import 'package:medico/data/paliers_repository.dart';
import 'package:medico/constants/colors.dart';
import 'package:medico/data/medicaments_repository.dart';
// import 'package:medico/data/paliers_repository.dart';
import 'package:medico/views/medicaments_page.dart' show Medicament;

/// Historique en lecture seule : liste tous les paliers déjà atteints
/// (date passée), tous médicaments confondus, du plus récent au plus
/// ancien. Ne modifie rien — les repositories sont la seule source de
/// vérité, cette page se contente de les lire et de les mettre en forme.
class HistoriquePage extends StatefulWidget {
  const HistoriquePage({super.key});

  @override
  State<HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage> {
  final _medicamentsRepo = MedicamentsRepository.instance;
  final _paliersRepo = PaliersRepository.instance;

  @override
  void initState() {
    super.initState();
    _medicamentsRepo.addListener(_onChanged);
    _paliersRepo.addListener(_onChanged);
    if (!_medicamentsRepo.estCharge) {
      _medicamentsRepo.charger();
    }
    if (!_paliersRepo.estCharge) {
      _paliersRepo.charger();
    }
  }

  @override
  void dispose() {
    _medicamentsRepo.removeListener(_onChanged);
    _paliersRepo.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  List<_EntreeHistorique> _construireHistorique() {
    final maintenant = DateTime.now();
    final entrees = <_EntreeHistorique>[];

    for (final medicament in _medicamentsRepo.medicaments) {
      final etapes = _paliersRepo.paliersPour(medicament.id);
      for (final etape in etapes) {
        if (!etape.date.isAfter(maintenant)) {
          entrees.add(_EntreeHistorique(medicament: medicament, etape: etape));
        }
      }
    }

    entrees.sort((a, b) => b.etape.date.compareTo(a.etape.date));
    return entrees;
  }

  @override
  Widget build(BuildContext context) {
    if (!_paliersRepo.estCharge) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final entrees = _construireHistorique();

    return Scaffold(
      appBar: AppBar(title: const Text('Historique'), centerTitle: true),
      body: SafeArea(
        child: entrees.isEmpty
            ? _buildEmptyState()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: entrees.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildLigne(entrees[index]),
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
              Icons.history,
              size: 64,
              color: AppColors.primaryColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun palier atteint pour le moment.\n'
              'L\'historique se remplira au fil de vos plans de sevrage.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLigne(_EntreeHistorique entree) {
    final medicament = entree.medicament;
    final etape = entree.etape;
    final estSevrageComplet = etape.dose <= 0;
    final pourcentageRestant = medicament.doseInitiale == 0
        ? 0.0
        : (etape.dose / medicament.doseInitiale) * 100;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: estSevrageComplet
              ? Colors.green.withValues(alpha: 0.15)
              : AppColors.primaryColor.withValues(alpha: 0.1),
          child: Icon(
            estSevrageComplet
                ? Icons.check_circle_outline
                : Icons.trending_down,
            color: estSevrageComplet ? Colors.green : AppColors.primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          medicament.nom,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          estSevrageComplet
              ? 'Sevrage atteint · ${medicament.classe}'
              : '${medicament.classe} · ${pourcentageRestant.toStringAsFixed(0)}% '
                    'de la dose initiale',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDate(etape.date),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              '${etape.dose} ${medicament.unite}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _EntreeHistorique {
  final Medicament medicament;
  final EtapePalier etape;

  _EntreeHistorique({required this.medicament, required this.etape});
}
