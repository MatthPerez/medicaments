import 'package:flutter/material.dart';
import 'package:my_meds/constants/colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _tiles = [
    _TileData(
      label: 'Mes médicaments',
      imagePath: 'lib/assets/images/medicaments.png',
      route: '/medicaments',
    ),
    _TileData(
      label: 'Plan de sevrage',
      imagePath: 'lib/assets/images/plan.png',
      route: '/plan',
    ),
    _TileData(
      label: 'Historique',
      imagePath: 'lib/assets/images/historique.png',
      route: '/historique',
    ),
    _TileData(
      label: 'Paramètres',
      imagePath: 'lib/assets/images/parametres.png',
      route: '/parametres',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            children: List.generate(_tiles.length, (index) {
              final start = index * 0.15;
              final end = (start + 0.6).clamp(0.0, 1.0);
              final animation = CurvedAnimation(
                parent: _controller,
                curve: Interval(start, end, curve: Curves.easeOutBack),
              );

              return _MenuTile(data: _tiles[index], animation: animation);
            }),
          ),
        ),
      ),
    );
  }
}

class _TileData {
  final String label;
  final String imagePath;
  final String route;

  const _TileData({
    required this.label,
    required this.imagePath,
    required this.route,
  });
}

class _MenuTile extends StatelessWidget {
  final _TileData data;
  final Animation<double> animation;

  const _MenuTile({required this.data, required this.animation});

  static const double _tileSize = 140;
  static const double _imageSize = 64;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: animation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, data.route),
        child: Container(
          width: _tileSize,
          height: _tileSize,
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: _imageSize,
                height: _imageSize,
                child: Image.asset(
                  data.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.image_not_supported_outlined,
                    size: _imageSize,
                    color: AppColors.primaryColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
