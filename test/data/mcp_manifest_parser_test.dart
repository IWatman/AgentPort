import 'package:agentport/data/marketplace/mcp_manifest_parser.dart';
import 'package:agentport/domain/entities/marketplace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = McpManifestParser();

  group('McpManifestParser', () {
    test('parses the mcpServers wrapper', () {
      final metadata = parser.parse('''
{
  "mcpServers": {
    "linear": {
      "type": "http",
      "url": "https://mcp.linear.app/mcp"
    }
  }
}
''');

      expect(metadata.status, PluginMcpStatus.remote);
      expect(metadata.servers, hasLength(1));
      expect(metadata.unsupportedServers, isEmpty);

      final server = metadata.servers.single;
      expect(server.name, 'linear');
      expect(server.transport, McpTransport.http);
      expect(server.url, 'https://mcp.linear.app/mcp');
      expect(server.authType, McpAuthType.unknown);
      expect(server.headerNames, isEmpty);
      expect(server.isRemote, isTrue);
    });

    test('parses a bare server map like the Linear manifest', () {
      final metadata = parser.parse('''
{
  "linear": {
    "transport": "http",
    "url": "https://mcp.linear.app/mcp"
  }
}
''');

      expect(metadata.status, PluginMcpStatus.remote);
      expect(metadata.servers.single.name, 'linear');
      expect(metadata.servers.single.transport, McpTransport.http);
    });

    test('parses remote HTTP and SSE servers', () {
      final metadata = parser.parse('''
{
  "mcpServers": {
    "http-server": {
      "type": "streamable-http",
      "url": "https://mcp.example.com/http"
    },
    "sse-server": {
      "type": "sse",
      "url": "https://mcp.example.com/sse"
    }
  }
}
''');

      expect(metadata.status, PluginMcpStatus.remote);
      expect(metadata.servers, hasLength(2));

      final httpServer = metadata.servers.firstWhere(
        (server) => server.name == 'http-server',
      );
      final sseServer = metadata.servers.firstWhere(
        (server) => server.name == 'sse-server',
      );

      expect(httpServer.transport, McpTransport.http);
      expect(sseServer.transport, McpTransport.sse);
    });

    test('excludes command and stdio servers', () {
      final metadata = parser.parse('''
{
  "mcpServers": {
    "local-command": {
      "command": "npx",
      "args": ["-y", "@example/mcp-server"]
    },
    "local-stdio": {
      "type": "stdio",
      "url": "https://mcp.example.com/stdio"
    }
  }
}
''');

      expect(metadata.servers, isEmpty);
      expect(metadata.status, PluginMcpStatus.stdio);
      expect(
        metadata.unsupportedServers,
        unorderedEquals(['local-command', 'local-stdio']),
      );
    });

    test('keeps remote servers and reports unsupported ones as mixed', () {
      final metadata = parser.parse('''
{
  "mcpServers": {
    "remote": {
      "type": "http",
      "url": "https://mcp.example.com/remote"
    },
    "local": {
      "command": "node",
      "args": ["server.js"]
    }
  }
}
''');

      expect(metadata.status, PluginMcpStatus.mixed);
      expect(metadata.servers.single.name, 'remote');
      expect(metadata.unsupportedServers, ['local']);
    });

    test('excludes non-HTTPS URLs', () {
      final metadata = parser.parse('''
{
  "mcpServers": {
    "insecure": {
      "type": "http",
      "url": "http://mcp.example.com/mcp"
    }
  }
}
''');

      expect(metadata.servers, isEmpty);
      expect(metadata.unsupportedServers, ['insecure']);
    });

    test('sorts header names and detects API-key authentication', () {
      final metadata = parser.parse('''
{
  "mcpServers": {
    "headers": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "headers": {
        "X-API-Key": "\${API_KEY}",
        "Authorization": "Bearer \${TOKEN}"
      }
    }
  }
}
''');

      final server = metadata.servers.single;
      expect(server.headerNames, ['Authorization', 'X-API-Key']);
      expect(server.authType, McpAuthType.apiKey);
      expect(server.rawJson['headers'], isA<Map>());
    });

    test('uses unknown auth when no headers are declared', () {
      final metadata = parser.parse('''
{
  "mcpServers": {
    "no-headers": {
      "type": "http",
      "url": "https://mcp.example.com/mcp"
    }
  }
}
''');

      expect(metadata.servers.single.headerNames, isEmpty);
      expect(metadata.servers.single.authType, McpAuthType.unknown);
    });

    test('returns none for an empty or unrecognized manifest', () {
      expect(parser.parse('{"mcpServers": {}}').status, PluginMcpStatus.none);
      expect(parser.parse('{}').status, PluginMcpStatus.none);
      expect(parser.parse('{"unrelated": true}').status, PluginMcpStatus.none);
    });

    test('configHash is stable across reordered input', () {
      const first = '''
{
  "mcpServers": {
    "alpha": {"type": "http", "url": "https://mcp.example.com/alpha"},
    "beta": {"type": "sse", "url": "https://mcp.example.com/beta"}
  }
}
''';
      const reordered = '''
{
  "mcpServers": {
    "beta": {"type": "sse", "url": "https://mcp.example.com/beta"},
    "alpha": {"type": "http", "url": "https://mcp.example.com/alpha"}
  }
}
''';

      final firstHash = parser.configHash(parser.parse(first).servers);
      final reorderedHash = parser.configHash(parser.parse(reordered).servers);

      expect(firstHash, reorderedHash);
      expect(firstHash, isNotEmpty);
    });

    test('configHash changes when a server URL changes', () {
      const original = '''
{
  "mcpServers": {
    "alpha": {"type": "http", "url": "https://mcp.example.com/alpha"}
  }
}
''';
      const changed = '''
{
  "mcpServers": {
    "alpha": {"type": "http", "url": "https://mcp.example.com/moved"}
  }
}
''';

      final originalHash = parser.configHash(parser.parse(original).servers);
      final changedHash = parser.configHash(parser.parse(changed).servers);

      expect(originalHash, isNot(changedHash));
    });

    test('returns an error status for malformed JSON', () {
      final metadata = parser.parse('{"mcpServers": {');

      expect(metadata.status, PluginMcpStatus.error);
      expect(metadata.error, isNotNull);
      expect(metadata.servers, isEmpty);
    });

    test('returns an error status for a non-object root', () {
      final metadata = parser.parse('[]');

      expect(metadata.status, PluginMcpStatus.error);
      expect(metadata.error, isNotNull);
    });

    test('keeps header templates but drops literal header values', () {
      final metadata = parser.parse('''
{
  "mcpServers": {
    "headers": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "headers": {
        "Authorization": "Bearer \${TOKEN}",
        "X-Literal": "do-not-store-me"
      }
    }
  }
}
''');

      final server = metadata.servers.single;
      expect(server.headerTemplates, {'Authorization': r'${TOKEN}'});
      expect(server.toJson()['headerTemplates'], {
        'Authorization': r'${TOKEN}',
      });
      expect(server.toJson().toString(), isNot(contains('do-not-store-me')));
    });

    test('configHash changes when a header template changes', () {
      const first = '''
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.example.com/mcp",
      "headers": {"Authorization": "Bearer \${TOKEN_A}"}
    }
  }
}
''';
      const second = '''
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.example.com/mcp",
      "headers": {"Authorization": "Bearer \${TOKEN_B}"}
    }
  }
}
''';

      final firstHash = parser.configHash(parser.parse(first).servers);
      final secondHash = parser.configHash(parser.parse(second).servers);

      expect(firstHash, isNot(secondHash));
    });

    test('rejects URLs with credentials or secret query parameters', () {
      final metadata = parser.parse('''
{
  "mcpServers": {
    "userinfo": {
      "type": "http",
      "url": "https://user:pass@mcp.example.com/mcp"
    },
    "query-token": {
      "type": "http",
      "url": "https://mcp.example.com/mcp?token=secret"
    }
  }
}
''');

      expect(metadata.servers, isEmpty);
      expect(
        metadata.unsupportedServers,
        unorderedEquals(['userinfo', 'query-token']),
      );
    });
  });
}
