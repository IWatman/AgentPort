import 'package:agentport/core/network/system_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemProxy.normalize', () {
    test('accepts host:port values and trims whitespace', () {
      expect(SystemProxy.normalize(' 10.0.2.2:2080 '), '10.0.2.2:2080');
      expect(SystemProxy.normalize('proxy.example:8080'), 'proxy.example:8080');
      expect(SystemProxy.normalize('[::1]:2080'), '[::1]:2080');
    });

    test('rejects malformed values, missing ports, and PAC URLs', () {
      expect(SystemProxy.normalize(null), isNull);
      expect(SystemProxy.normalize(''), isNull);
      expect(SystemProxy.normalize('http://10.0.2.2:2080'), isNull);
      expect(SystemProxy.normalize('10.0.2.2'), isNull);
      expect(SystemProxy.normalize('10.0.2.2:0'), isNull);
      expect(SystemProxy.normalize('10.0.2.2:65536'), isNull);
      expect(SystemProxy.normalize('http://wpad/wpad.dat'), isNull);
    });
  });

  group('SystemProxy.shouldBypass', () {
    test('bypasses loopback, local names, and single-label hosts', () {
      expect(SystemProxy.shouldBypass('localhost'), isTrue);
      expect(SystemProxy.shouldBypass('127.0.0.1'), isTrue);
      expect(SystemProxy.shouldBypass('::1'), isTrue);
      expect(SystemProxy.shouldBypass('printer.local'), isTrue);
      expect(SystemProxy.shouldBypass('opencode'), isTrue);
      expect(SystemProxy.shouldBypass(''), isTrue);
    });

    test('bypasses private and link-local address ranges', () {
      expect(SystemProxy.shouldBypass('10.1.2.3'), isTrue);
      expect(SystemProxy.shouldBypass('172.16.0.1'), isTrue);
      expect(SystemProxy.shouldBypass('172.31.255.255'), isTrue);
      expect(SystemProxy.shouldBypass('192.168.1.10'), isTrue);
      expect(SystemProxy.shouldBypass('169.254.1.1'), isTrue);
      expect(SystemProxy.shouldBypass('fd00::1'), isTrue);
    });

    test('proxies public hosts and public ranges', () {
      expect(SystemProxy.shouldBypass('auth.openai.com'), isFalse);
      expect(SystemProxy.shouldBypass('openrouter.ai'), isFalse);
      expect(SystemProxy.shouldBypass('8.8.8.8'), isFalse);
      expect(SystemProxy.shouldBypass('172.15.0.1'), isFalse);
      expect(SystemProxy.shouldBypass('172.32.0.1'), isFalse);
      expect(SystemProxy.shouldBypass('192.169.1.1'), isFalse);
      expect(SystemProxy.shouldBypass('2001:db8::1'), isFalse);
    });
  });
}
