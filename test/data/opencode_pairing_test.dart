import 'dart:convert';

import 'package:agentport/data/opencode/opencode_pairing.dart';
import 'package:agentport/domain/entities/opencode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = OpenCodePairingParser();

  group('OpenCodePairingParser JSON payloads', () {
    test('parses a JSON payload and normalizes trailing slashes', () {
      final pairing = parser.parse(
        jsonEncode({
          'code': 'abc123',
          'urls': [
            'http://192.168.1.10:4096/',
            'https://opencode.example.com/tunnel/',
          ],
        }),
      );

      expect(pairing.code, 'abc123');
      expect(pairing.urls, [
        'http://192.168.1.10:4096',
        'https://opencode.example.com/tunnel',
      ]);
      expect(pairing.primaryUrl, 'http://192.168.1.10:4096');
    });

    test('accepts surrounding whitespace and preserves path prefixes', () {
      final pairing = parser.parse(
        '  {"code":"  xyz-1  ","urls":["https://host/opencode"]}  ',
      );

      expect(pairing.code, 'xyz-1');
      expect(pairing.urls, ['https://host/opencode']);
    });

    test('skips malformed URLs while keeping usable ones', () {
      final pairing = parser.parse(
        jsonEncode({
          'code': 'abc',
          'urls': ['ftp://host', 'not a url', 'https://host:4096'],
        }),
      );

      expect(pairing.urls, ['https://host:4096']);
    });

    test('deduplicates repeated URLs', () {
      final pairing = parser.parse(
        jsonEncode({
          'code': 'abc',
          'urls': ['https://host', 'https://host/'],
        }),
      );

      expect(pairing.urls, ['https://host']);
    });

    test('rejects malformed JSON', () {
      expect(
        () => parser.parse('{"code":'),
        throwsA(
          isA<OpenCodeFailure>().having(
            (failure) => failure.kind,
            'kind',
            OpenCodeFailureKind.invalidPayload,
          ),
        ),
      );
    });

    test('rejects a payload without a code', () {
      expect(
        () => parser.parse('{"urls":["https://host"]}'),
        throwsA(isA<OpenCodeFailure>()),
      );
    });

    test('rejects a payload without usable URLs', () {
      expect(
        () => parser.parse('{"code":"abc","urls":["ftp://host"]}'),
        throwsA(
          isA<OpenCodeFailure>().having(
            (failure) => failure.kind,
            'kind',
            OpenCodeFailureKind.invalidPayload,
          ),
        ),
      );
    });
  });

  group('OpenCodePairingParser links', () {
    test('parses a connect link', () {
      final pairing = parser.parse(
        'http://192.168.1.10:4096/auth/connect/abc123',
      );

      expect(pairing.code, 'abc123');
      expect(pairing.urls, ['http://192.168.1.10:4096']);
    });

    test('parses a connect link with a base path', () {
      final pairing = parser.parse(
        'https://example.com/opencode/auth/connect/abc123/',
      );

      expect(pairing.code, 'abc123');
      expect(pairing.urls, ['https://example.com/opencode']);
    });

    test('decodes percent-encoded codes', () {
      final pairing = parser.parse(
        'https://example.com/auth/connect/abc%2D123',
      );

      expect(pairing.code, 'abc-123');
    });

    test('rejects a non-connect link', () {
      expect(
        () => parser.parse('https://example.com/auth/login/abc'),
        throwsA(isA<OpenCodeFailure>()),
      );
    });

    test('rejects a non-http link', () {
      expect(
        () => parser.parse('ftp://example.com/auth/connect/abc'),
        throwsA(isA<OpenCodeFailure>()),
      );
    });

    test('rejects an empty payload', () {
      expect(() => parser.parse('   '), throwsA(isA<OpenCodeFailure>()));
    });
  });
}
