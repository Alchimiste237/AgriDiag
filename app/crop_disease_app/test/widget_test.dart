import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crop_disease_app/app.dart';
import 'package:crop_disease_app/core/widgets/agro_chrome.dart';
import 'package:crop_disease_app/features/home/home_screen.dart';
import 'package:crop_disease_app/features/main_shell.dart';
import 'package:crop_disease_app/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('App bootstrap smoke test', (WidgetTester tester) async {
    // The app performs async init (storage, settings, voice, crop classifier
    // preload). Just make sure it mounts without throwing and shows the
    // loading state while initializing. (No pumpAndSettle: the loading
    // spinner animates forever, so it would never settle.)
    await tester.pumpWidget(const CropDiseaseApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Onboarding hero shows artwork background and Get Started',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    // The logo, wordmark and tagline are baked into the background artwork.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('Onboarding form opens from hero and validates', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Village'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('Home screen shows scan card and history', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('SCAN NEW LEAF'), findsOneWidget);
    expect(find.text('AgroDiag'), findsOneWidget);
    expect(find.text('MY HISTORY'), findsOneWidget);
  });

  test('Tab-to-index mapping skips the scanner value', () {
    // Regression: AgroTab has 5 values but the shell's IndexedStack hosts
    // only 4 children. Indices must stay in range and Advice/Profile must
    // not be shifted by one (Advice used to show the Profile screen and
    // Profile threw "index out of range").
    expect(agroTabIndex(AgroTab.home), 0);
    expect(agroTabIndex(AgroTab.history), 1);
    expect(agroTabIndex(AgroTab.advice), 2);
    expect(agroTabIndex(AgroTab.profile), 3);
    expect(agroTabIndex(AgroTab.scanner), lessThan(4));
  });

  testWidgets('Bottom navigation exposes the five destinations', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AgroBottomNavBar(
        currentTab: AgroTab.home,
        onTabSelected: _noop,
      ))),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Scanner'), findsOneWidget);
    expect(find.text('Advice'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}

void _noop(AgroTab tab) {}
