import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_meds/constants/colors.dart';

import 'package:my_meds/views/home_page.dart';


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
      title: 'my_meds',
      theme: ThemeData(
        primaryColor: AppColors.primaryColor,
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(),
      ),
      initialRoute: '/',
      navigatorObservers: [routeObserver],
      routes: {
        '/': (BuildContext context) => const HomePage(),
      },
    );
  }
}
