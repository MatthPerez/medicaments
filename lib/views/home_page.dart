import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medico/constants/colors.dart';
import 'package:medico/main.dart' show routeObserver;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, RouteAware {
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
    label: 'Journal',
    imagePath: 'lib/assets/images/journal.png',
    route: '/journal',
  ),
  _TileData(
    label: 'Historique',
    imagePath: 'lib/assets/images/historique.png',
    route: '/historique',
  ),
  _TileData(
    label: 'Contacts médicaux',
    imagePath: 'lib/assets/images/contacts.png',
    route: '/contacts',
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Zone haute : titre + tuiles. Occupe tout l'espace restant
            // UNE FOIS que l'image du bas (non-flexible) a déterminé sa
            // propre hauteur — donc toujours au-dessus, jamais chevauchée.
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'MON SUIVI MÉDICAL',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.robotoMono(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 32),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1,
                        children: List.generate(_tiles.length, (index) {
                          final start = index * 0.1;
                          final end = (start + 0.6).clamp(0.0, 1.0);
                          final animation = CurvedAnimation(
                            parent: _controller,
                            curve: Interval(
                              start,
                              end,
                              curve: Curves.easeOutBack,
                            ),
                          );

                          return _MenuTile(
                            data: _tiles[index],
                            animation: animation,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Image de fond : dernier enfant du Column, donc toujours
            // après (visuellement en dessous de) la zone des tuiles.
            // Largeur pleine écran, hauteur calculée automatiquement
            // pour conserver le ratio d'origine — aucun recadrage.
            Image.asset(
              'lib/assets/images/medicaments_bg.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ],
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

  static const double _imageSize = 56;

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
              const SizedBox(height: 10),
              Text(
                data.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
