import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medico/constants/colors.dart';
import 'package:medico/data/medicaments_repository.dart';
import 'package:medico/data/paliers_repository.dart';
import 'package:medico/data/symptomes_repository.dart';
import 'package:medico/views/journal_page.dart';

import 'package:medico/views/home_page.dart';
import 'package:medico/views/medicaments_page.dart';
import 'package:medico/views/plan_sevrage_page.dart';
import 'package:medico/views/historique_page.dart';
import 'package:medico/views/contacts_medicaux_page.dart';
import 'package:medico/views/parametres_page.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MedicamentsRepository.instance.charger();
  await PaliersRepository.instance.charger();
  await SymptomesRepository.instance.charger();
  runApp(const DailyApp());
}

class DailyApp extends StatelessWidget {
  const DailyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mon suivi médical',
      theme: ThemeData(
        primaryColor: AppColors.primaryColor,
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(),
      ),
      initialRoute: '/',
      navigatorObservers: [routeObserver],
      routes: {
        '/': (context) => const HomePage(),
        '/medicaments': (context) => const MedicamentsPage(),
        '/plan': (context) => const PlanSevragePage(),
        '/historique': (context) => const HistoriquePage(),
        '/journal': (context) => const JournalPage(),
        '/contacts': (context) => const ContactsMedicauxPage(),
        '/parametres': (context) => const ParametresPage(),
      },
    );
  }
}
