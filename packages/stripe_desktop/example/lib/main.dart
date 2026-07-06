import 'package:flutter/material.dart';
import 'package:stripe_desktop/stripe_desktop.dart';

import 's1_typing_spike.dart';
import 's2_origin_spike.dart';
import 's3_s4_demo.dart';

/// Publishable key default, injectable at build time with
/// `flutter run --dart-define=STRIPE_PK=pk_test_...`. Never hardcode a key.
const String kDefaultPublishableKey = String.fromEnvironment('STRIPE_PK');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Manual registration (idempotent): does not depend on the tooling's
  // dart plugin registrant. Must run before any `Stripe` usage.
  StripeDesktopPlugin.registerWith();
  runApp(const StripeDesktopExampleApp());
}

class StripeDesktopExampleApp extends StatelessWidget {
  const StripeDesktopExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'stripe_desktop example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _publishableKeyController =
      TextEditingController(text: kDefaultPublishableKey);

  @override
  void dispose() {
    _publishableKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('stripe_desktop spikes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'S1 typing'),
              Tab(text: 'S2 origin'),
              Tab(text: 'S3/S4 demo'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _publishableKeyController,
                decoration: const InputDecoration(
                  labelText: 'Publishable key (pk_test_...)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const S1TypingSpike(),
                  S2OriginSpike(
                    publishableKey: () => _publishableKeyController.text.trim(),
                  ),
                  S3S4Demo(
                    publishableKey: () => _publishableKeyController.text.trim(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
