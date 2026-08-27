import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/main.dart';

void main() {
  testWidgets('renders login and signup navigation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('College Grievance Management'), findsOneWidget);
    expect(find.text('Login to continue'), findsOneWidget);
    expect(find.text('College email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Student / Register Number'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('Confirm Password'), findsOneWidget);
  });

  testWidgets('renders grievance submission form', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RaiseGrievance())),
    );
    expect(find.text('Tell us what happened'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('Submit grievance'), findsOneWidget);
  });

  testWidgets('renders dashboard metrics and grievance details', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MetricCard(label: 'Total', value: '3'),
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    await tester.pumpWidget(
      const MaterialApp(
        home: GrievanceDetails(
          data: {
            'grievanceId': 'G-1',
            'subject': 'Library access',
            'category': 'Library',
            'priority': 'Medium',
            'description': 'Access issue',
            'status': 'Submitted',
            'adminResponse': '',
          },
        ),
      ),
    );
    expect(find.text('Library access'), findsOneWidget);
    expect(find.text('Status timeline'), findsOneWidget);
  });
}
