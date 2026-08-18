import 'package:flutter/material.dart';
import 'package:my_meds/constants/colors.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon suivi médical'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: const [
              _MenuTile(
                label: 'Mes médicaments',
                imagePath: 'assets/images/medicaments.png',
                route: '/medicaments',
              ),
              _MenuTile(
                label: 'Plan de sevrage',
                imagePath: 'assets/images/plan.png',
                route: '/plan',
              ),
              _MenuTile(
                label: 'Historique',
                imagePath: 'assets/images/historique.png',
                route: '/historique',
              ),
              _MenuTile(
                label: 'Paramètres',
                imagePath: 'assets/images/parametres.png',
                route: '/parametres',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String label;
  final String imagePath;
  final String route;

  const _MenuTile({
    required this.label,
    required this.imagePath,
    required this.route,
  });

  static const double _tileSize = 140;
  static const double _imageSize = 64;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        // Navigator.pushNamed(context, route);
        // route non encore déclarée dans main.dart — à ajouter dans `routes`
      },
      child: Container(
        width: _tileSize,
        height: _tileSize,
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: _imageSize,
              height: _imageSize,
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.image_not_supported_outlined,
                  size: _imageSize,
                  color: AppColors.primaryColor.withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
