import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:stripe_desktop/stripe_desktop.dart';

/// S2 — virtual origin check.
///
/// Loads the package's bundled page via `loadData` with an HTTPS `baseUrl`
/// (the virtual origin) and drives the RPC bridge manually:
/// init -> mountCard -> createPaymentMethod. Run it with a `pk_test` key and
/// the test card 4242 4242 4242 4242; for the live check use a `pk_live` key
/// and a real card — `createPaymentMethod` only, never confirm.
class S2OriginSpike extends StatefulWidget {
  const S2OriginSpike({super.key, required this.publishableKey});

  final String Function() publishableKey;

  @override
  State<S2OriginSpike> createState() => _S2OriginSpikeState();
}

class _S2OriginSpikeState extends State<S2OriginSpike>
    with AutomaticKeepAliveClientMixin {
  static final WebUri _virtualOrigin = WebUri(
    'https://pay.gymdogs.app/stripe-desktop',
  );

  final StripeJsBridge _bridge = StripeJsBridge();
  String _result = 'No calls yet.';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _bridge.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<Object?> Function() call) async {
    setState(() => _result = '$label ...');
    try {
      final result = await call();
      setState(() => _result = '$label OK: $result');
    } catch (error) {
      setState(() => _result = '$label FAILED: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Page loaded with baseUrl/historyUrl = $_virtualOrigin'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => _run('init', () {
                  final key = widget.publishableKey();
                  if (!key.startsWith('pk_')) {
                    throw StateError(
                      'use the publishable key (pk_test_/pk_live_), '
                      'never a secret key',
                    );
                  }
                  return _bridge.call('init', {
                    'publishableKey': key,
                    'locale': 'auto',
                  });
                }),
                child: const Text('init'),
              ),
              FilledButton(
                onPressed: () => _run(
                  'mountCard',
                  () => _bridge.call('mountCard', {
                    'style': const <String, dynamic>{},
                    'postalCodeEnabled': false,
                  }),
                ),
                child: const Text('mountCard'),
              ),
              FilledButton(
                onPressed: () => _run(
                  'createPaymentMethod',
                  () => _bridge.call(
                    'createPaymentMethod',
                    const <String, dynamic>{},
                  ),
                ),
                child: const Text('createPaymentMethod'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all()),
              child: InAppWebView(
                initialData: InAppWebViewInitialData(
                  data: stripeDesktopPageHtml,
                  baseUrl: _virtualOrigin,
                  historyUrl: _virtualOrigin,
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  supportZoom: false,
                ),
                onWebViewCreated: _bridge.attach,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(_result),
            ),
          ),
        ],
      ),
    );
  }
}
