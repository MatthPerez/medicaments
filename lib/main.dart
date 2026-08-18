import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medico/constants/colors.dart';

import 'package:medico/views/home_page.dart';
import 'package:medico/views/medicaments_page.dart';
import 'package:medico/views/plan_sevrage_page.dart';
import 'package:medico/views/historique_page.dart';
import 'package:medico/views/parametres_page.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() {
  runApp(const MyMedsApp());
}

class MyMedsApp extends StatelessWidget {
  const MyMedsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'medico',
      theme: ThemeData(
        primaryColor: AppColors.primaryColor,
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(),
      ),
      initialRoute: '/',
      navigatorObservers: [routeObserver],
      routes: {
        '/': (BuildContext context) => const HomePage(),
        '/medicaments': (BuildContext context) => const MedicamentsPage(),
        '/plan': (BuildContext context) => const PlanSevragePage(),
        '/historique': (BuildContext context) => const HistoriquePage(),
        '/parametres': (BuildContext context) => const ParametresPage(),
      },
    );
  }
}
