import 'package:agentport/domain/entities/opencode.dart';
import 'package:agentport/features/opencode/opencode_transcript.dart';
import 'package:flutter_test/flutter_test.dart';

OpenCodeMessage _user(String id, String text) {
  return OpenCodeMessage(id: id, role: 'user', text: text);
}

OpenCodeMessage _assistant(
  String id, {
  String text = '',
  String reasoning = '',
  List<String> tools = const [],
}) {
  return OpenCodeMessage(
    id: id,
    role: 'assistant',
    text: text,
    reasoning: reasoning,
    tools: tools,
  );
}

void main() {
  group('groupOpenCodeMessages', () {
    test('merges consecutive assistant messages into one turn', () {
      final turns = groupOpenCodeMessages([
        _user('u1', 'Do the work'),
        _assistant(
          'a1',
          reasoning: 'First I inspect the files.',
          tools: const ['shell'],
        ),
        _assistant('a2', reasoning: 'Then I edit them.', tools: const ['edit']),
        _assistant('a3', text: 'Done.'),
        _user('u2', 'Thanks'),
        _assistant('a4', text: 'Welcome.'),
      ]);

      expect(turns, hasLength(4));
      expect(turns[0], isA<OpenCodeUserTurn>());
      final first = turns[1] as OpenCodeAssistantTurn;
      expect(first.text, 'Done.');
      expect(first.tools, ['shell', 'edit']);
      expect(first.reasoning, contains('inspect the files'));
      expect(first.reasoning, contains('Then I edit them'));
      expect(first.reasoning, contains('\n\n'));
      expect(turns[2], isA<OpenCodeUserTurn>());
      final second = turns[3] as OpenCodeAssistantTurn;
      expect(second.text, 'Welcome.');
      expect(second.tools, isEmpty);
    });

    test('skips assistant fragments without text or tools', () {
      final turns = groupOpenCodeMessages([
        _user('u1', 'Question'),
        _assistant('a1', reasoning: 'Only thinking.'),
        _assistant('a2', text: 'Answer.'),
      ]);

      expect(turns, hasLength(2));
      final turn = turns[1] as OpenCodeAssistantTurn;
      expect(turn.text, 'Answer.');
      expect(turn.reasoning, 'Only thinking.');
    });

    test('keeps turns ordered when the session starts with an assistant', () {
      final turns = groupOpenCodeMessages([
        _assistant('a1', text: 'Intro.'),
        _user('u1', 'Question'),
      ]);

      expect(turns, hasLength(2));
      expect(turns[0], isA<OpenCodeAssistantTurn>());
      expect(turns[1], isA<OpenCodeUserTurn>());
    });

    test('returns no turns for an empty transcript', () {
      expect(groupOpenCodeMessages(const []), isEmpty);
    });
  });
}
