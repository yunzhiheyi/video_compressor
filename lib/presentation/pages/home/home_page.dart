import 'dart:io';
import 'package:flutter/material.dart';
import 'mobile/home_mobile_page.dart';
import 'desktop/home_desktop_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) {
      return const HomeDesktopPage();
    }
    return const HomeMobilePage();
  }
}
