import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stripe_desktop/src/bridge/rpc_messages.dart';

void main() {
  group('asStringKeyedMap', () {
    test('passes through a Map<String, dynamic> unchanged', () {
      final map = <String, dynamic>{'a': 1};
      expect(asStringKeyedMap(map), same(map));
    });

    test('converts a Map<dynamic, dynamic> (webview decoder shape)', () {
      final loose = <dynamic, dynamic>{'a': 1, 'b': 'two'};
      final result = asStringKeyedMap(loose);
      expect(result, isA<Map<String, dynamic>>());
      expect(result, {'a': 1, 'b': 'two'});
    });

    test('returns an empty map for null and non-map values', () {
      expect(asStringKeyedMap(null), isEmpty);
      expect(asStringKeyedMap('nope'), isEmpty);
      expect(asStringKeyedMap(42), isEmpty);
    });
  });

  group('RpcRequest', () {
    test('toJson/fromJson round-trip', () {
      const request = RpcRequest(
        id: 7,
        method: 'confirmPayment',
        params: {'clientSecret': 'pi_123_secret_456'},
      );
      final decoded = RpcRequest.fromJson(
        jsonDecode(jsonEncode(request.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.id, 7);
      expect(decoded.method, 'confirmPayment');
      expect(decoded.params, {'clientSecret': 'pi_123_secret_456'});
    });

    test('fromJson casts Map<dynamic, dynamic> params defensively', () {
      final decoded = RpcRequest.fromJson({
        'id': 1,
        'method': 'init',
        'params': <dynamic, dynamic>{'publishableKey': 'pk_test_abc'},
      });
      expect(decoded.params, isA<Map<String, dynamic>>());
      expect(decoded.params['publishableKey'], 'pk_test_abc');
    });

    test('fromJson tolerates a missing params field', () {
      final decoded = RpcRequest.fromJson({'id': 2, 'method': 'unmountCard'});
      expect(decoded.params, isEmpty);
    });

    test('fromJson accepts a double id (JS numbers)', () {
      final decoded = RpcRequest.fromJson({
        'id': 3.0,
        'method': 'createToken',
        'params': <String, dynamic>{},
      });
      expect(decoded.id, 3);
    });
  });

  group('RpcResponse', () {
    test('toJson/fromJson round-trip of a success response', () {
      const response = RpcResponse(
        id: 11,
        ok: true,
        result: {
          'paymentIntent': {'id': 'pi_123', 'status': 'succeeded'},
        },
      );
      final decoded = RpcResponse.fromJson(
        jsonDecode(jsonEncode(response.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.id, 11);
      expect(decoded.ok, isTrue);
      expect(decoded.error, isNull);
      expect(decoded.result?['paymentIntent'], {
        'id': 'pi_123',
        'status': 'succeeded',
      });
    });

    test('toJson/fromJson round-trip of an error response', () {
      const response = RpcResponse(
        id: 12,
        ok: false,
        error: StripeJsError(
          type: 'card_error',
          message: 'Your card was declined.',
          code: 'card_declined',
          declineCode: 'insufficient_funds',
        ),
      );
      final decoded = RpcResponse.fromJson(
        jsonDecode(jsonEncode(response.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.ok, isFalse);
      expect(decoded.result, isNull);
      expect(decoded.error?.type, 'card_error');
      expect(decoded.error?.message, 'Your card was declined.');
      expect(decoded.error?.code, 'card_declined');
      expect(decoded.error?.declineCode, 'insufficient_funds');
    });

    test('fromJson casts a Map<dynamic, dynamic> result defensively', () {
      final decoded = RpcResponse.fromJson({
        'id': 13,
        'ok': true,
        'result': <dynamic, dynamic>{
          'token': <dynamic, dynamic>{'id': 'tok_123'},
        },
      });
      expect(decoded.result, isA<Map<String, dynamic>>());
      expect(decoded.result?['token'], {'id': 'tok_123'});
    });

    test('fromJson tolerates missing result and error fields', () {
      final decoded = RpcResponse.fromJson({'id': 14, 'ok': true});
      expect(decoded.result, isNull);
      expect(decoded.error, isNull);
    });

    test('fromJson treats a non-bool ok as false', () {
      final decoded = RpcResponse.fromJson({'id': 15, 'ok': 'yes'});
      expect(decoded.ok, isFalse);
    });

    test('toJson omits null result and error', () {
      const response = RpcResponse(id: 16, ok: true);
      final json = response.toJson();
      expect(json.containsKey('result'), isFalse);
      expect(json.containsKey('error'), isFalse);
    });
  });

  group('StripeJsError', () {
    test('fromJson falls back to api_error / Unknown error', () {
      final error = StripeJsError.fromJson(const {});
      expect(error.type, 'api_error');
      expect(error.message, 'Unknown error');
      expect(error.code, isNull);
      expect(error.declineCode, isNull);
      expect(error.paymentIntent, isNull);
    });

    test('fromJson keeps the paymentIntent payload, casting defensively', () {
      final error = StripeJsError.fromJson({
        'type': 'card_error',
        'message': 'Your card was declined.',
        'paymentIntent': <dynamic, dynamic>{
          'id': 'pi_123',
          'status': 'requires_payment_method',
        },
      });
      expect(error.paymentIntent, isA<Map<String, dynamic>>());
      expect(error.paymentIntent?['id'], 'pi_123');
    });
  });

  group('PageEvent', () {
    test('fromJson reads the cardChange payload', () {
      final event = PageEvent.fromJson(const {
        'kind': 'event',
        'event': 'cardChange',
        'complete': true,
        'empty': false,
        'brand': 'visa',
        'error': null,
      });
      expect(event.type, PageEvent.kindCardChange);
      expect(event.complete, isTrue);
      expect(event.empty, isFalse);
      expect(event.brand, 'visa');
      expect(event.error, isNull);
    });

    test('toJson/fromJson round-trip', () {
      const event = PageEvent(
        type: PageEvent.kindCardChange,
        complete: false,
        empty: true,
        brand: 'unknown',
        error: 'Your card number is incomplete.',
      );
      final decoded = PageEvent.fromJson(
        jsonDecode(jsonEncode(event.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.type, PageEvent.kindCardChange);
      expect(decoded.complete, isFalse);
      expect(decoded.empty, isTrue);
      expect(decoded.brand, 'unknown');
      expect(decoded.error, 'Your card number is incomplete.');
    });

    test('ready constructor carries no payload', () {
      const event = PageEvent.ready();
      expect(event.type, PageEvent.kindReady);
      expect(event.complete, isNull);
      expect(event.brand, isNull);
    });
  });
}
