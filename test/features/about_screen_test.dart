import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:teleprompter/features/about/about_screen.dart';

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'Teleprompter',
      packageName: 'in.sundarprakash.teleprompter',
      version: '1.0.1',
      buildNumber: '2',
      buildSignature: '',
    );
  });

  testWidgets('shows version, promises and developer links', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Version 1.0.1 (2)'), findsOneWidget);
    expect(find.text('Free forever'), findsOneWidget);
    expect(find.text('No ads'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Portfolio'), 200);
    expect(find.text('Sundar Prakash P'), findsOneWidget);
    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Open-source licences'), 200);
    expect(find.text('Privacy policy'), findsOneWidget);
  });
}
