import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// S1 — typing in an AppKitView-hosted webview.
///
/// A raw [InAppWebView] loading inline HTML with two text inputs, to manually
/// validate: focus by click, continuous typing (30+ chars, accents),
/// Tab/Shift-Tab between inputs, Cmd+V paste, Cmd+A select-all, focus
/// hand-off between Flutter widgets and the webview.
class S1TypingSpike extends StatefulWidget {
  const S1TypingSpike({super.key});

  @override
  State<S1TypingSpike> createState() => _S1TypingSpikeState();
}

class _S1TypingSpikeState extends State<S1TypingSpike>
    with AutomaticKeepAliveClientMixin {
  static const _html = '''
<!doctype html><html><head><meta charset="utf-8"><style>
  body { font-family: -apple-system, sans-serif; margin: 16px; }
  input { display: block; width: 90%; margin: 12px 0; padding: 8px; font-size: 16px; }
</style></head><body>
  <label>Input 1 <input type="text" placeholder="Type here, use Tab / paste"></label>
  <label>Input 2 <input type="text" placeholder="Shift-Tab back to input 1"></label>
</body></html>
''';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Click an input, type 30+ characters with accents, Tab between '
            'the inputs, paste with Cmd+V, then click the Flutter field below '
            'and back.',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all()),
              child: InAppWebView(
                initialData: InAppWebViewInitialData(data: _html),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  supportZoom: false,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Flutter TextField (focus hand-off check)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
