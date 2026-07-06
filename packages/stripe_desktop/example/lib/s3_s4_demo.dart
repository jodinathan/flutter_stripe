import 'package:flutter/material.dart' hide Card;
import 'package:flutter_stripe/flutter_stripe.dart';

/// S3/S4 — the full flutter_stripe flow through the desktop implementation.
///
/// After applying the publishable key, the card field below is created with
/// `StripePlatform.instance.buildCard` (the same entry point the upstream
/// `CardField` widget uses on web) and payments run through
/// `Stripe.instance` — exercising the resident overlay (S4) and the in-page
/// 3DS challenge with the expanded overlay (S3, card 4000 0025 0000 3155).
class S3S4Demo extends StatefulWidget {
  const S3S4Demo({super.key, required this.publishableKey});

  final String Function() publishableKey;

  @override
  State<S3S4Demo> createState() => _S3S4DemoState();
}

class _S3S4DemoState extends State<S3S4Demo>
    with AutomaticKeepAliveClientMixin {
  final CardEditController _cardController = CardEditController();
  final TextEditingController _clientSecretController =
      TextEditingController();
  final List<String> _log = <String>[];
  bool _keyApplied = false;
  CardFieldInputDetails? _details;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _cardController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    setState(() {
      _log.insert(
        0,
        '${DateTime.now().toIso8601String().substring(11, 19)}  $message',
      );
    });
  }

  void _applyKey() {
    final key = widget.publishableKey();
    if (key.isEmpty) {
      _addLog('Publishable key is empty.');
      return;
    }
    if (!key.startsWith('pk_')) {
      _addLog(
        'This looks like a secret key — Stripe.js only takes the '
        'publishable key (pk_test_/pk_live_). Never put sk_ in an app.',
      );
      return;
    }
    Stripe.publishableKey = key;
    setState(() => _keyApplied = true);
    _addLog('Publishable key applied.');
  }

  Future<void> _run(String label, Future<Object?> Function() call) async {
    _addLog('$label ...');
    try {
      final result = await call();
      _addLog('$label OK: $result');
    } catch (error) {
      _addLog('$label FAILED: $error');
    }
  }

  Future<void> _createPaymentMethod() => _run('createPaymentMethod', () async {
    final paymentMethod = await Stripe.instance.createPaymentMethod(
      params: const PaymentMethodParams.card(
        paymentMethodData: PaymentMethodData(),
      ),
    );
    return '${paymentMethod.id} (${paymentMethod.card.brand} '
        '**** ${paymentMethod.card.last4})';
  });

  Future<void> _confirmPayment() => _run('confirmPayment', () async {
    final paymentIntent = await Stripe.instance.confirmPayment(
      paymentIntentClientSecret: _clientSecretController.text.trim(),
      data: const PaymentMethodParams.card(
        paymentMethodData: PaymentMethodData(),
      ),
    );
    return '${paymentIntent.id} -> ${paymentIntent.status}';
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton(
                onPressed: _applyKey,
                child: const Text('Apply key'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _details == null
                      ? 'Card: (no input yet)'
                      : 'Card: complete=${_details!.complete} '
                            'brand=${_details!.brand ?? '-'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_keyApplied)
            StripePlatform.instance.buildCard(
              controller: _cardController,
              height: 48,
              style: CardStyle(
                textColor: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                borderColor: Theme.of(context).colorScheme.outline,
                borderRadius: 8,
              ),
              onCardChanged: (details) => setState(() => _details = details),
            )
          else
            const Text('Apply the publishable key to mount the card field.'),
          const SizedBox(height: 12),
          TextField(
            controller: _clientSecretController,
            decoration: const InputDecoration(
              labelText: 'PaymentIntent client secret (pi_..._secret_...)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: _keyApplied ? _createPaymentMethod : null,
                child: const Text('createPaymentMethod'),
              ),
              FilledButton(
                onPressed: _keyApplied ? _confirmPayment : null,
                child: const Text('confirmPayment'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Log:'),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all()),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _log.length,
                itemBuilder: (context, index) => SelectableText(_log[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
