import '../../domain/entities/opencode.dart';

/// One rendered transcript entry.
///
/// OpenCode splits a single assistant reply into many consecutive messages:
/// reasoning, tool calls, and text arrive as separate records. The UI groups
/// them so a turn reads as one answer with a single tool summary.
sealed class OpenCodeTurn {
  const OpenCodeTurn();
}

final class OpenCodeUserTurn extends OpenCodeTurn {
  const OpenCodeUserTurn(this.message);

  final OpenCodeMessage message;
}

final class OpenCodeAssistantTurn extends OpenCodeTurn {
  const OpenCodeAssistantTurn({
    required this.reasoning,
    required this.text,
    required this.tools,
  });

  final String reasoning;
  final String text;
  final List<String> tools;
}

/// Groups consecutive assistant messages into one turn per user message.
///
/// Turns with neither text nor tools are skipped: they carry no visible
/// content, for example a reasoning-only fragment while the model thinks.
List<OpenCodeTurn> groupOpenCodeMessages(List<OpenCodeMessage> messages) {
  final turns = <OpenCodeTurn>[];
  var group = <OpenCodeMessage>[];

  void flush() {
    if (group.isEmpty) {
      return;
    }
    final reasoning = StringBuffer();
    final text = StringBuffer();
    final tools = <String>[];
    for (final message in group) {
      if (message.reasoning.trim().isNotEmpty) {
        if (reasoning.isNotEmpty) {
          reasoning.write('\n\n');
        }
        reasoning.write(message.reasoning);
      }
      if (message.text.trim().isNotEmpty) {
        if (text.isNotEmpty) {
          text.write('\n\n');
        }
        text.write(message.text);
      }
      tools.addAll(message.tools);
    }
    group = [];
    if (text.isEmpty && tools.isEmpty) {
      return;
    }
    turns.add(
      OpenCodeAssistantTurn(
        reasoning: reasoning.toString(),
        text: text.toString(),
        tools: List.unmodifiable(tools),
      ),
    );
  }

  for (final message in messages) {
    if (message.isUser) {
      flush();
      turns.add(OpenCodeUserTurn(message));
    } else {
      group.add(message);
    }
  }
  flush();
  return turns;
}
