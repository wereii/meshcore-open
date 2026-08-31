import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/models/contact.dart';
import 'package:meshcore_open/models/message.dart';
import 'package:meshcore_open/services/message_retry_service.dart';

Contact _contact() => Contact(
  publicKey: Uint8List.fromList(List<int>.generate(32, (i) => 0xAA + i)),
  name: 'Test',
  type: 1,
  pathLength: -1,
  path: Uint8List(0),
  lastSeen: DateTime.now(),
);

void main() {
  late MessageRetryService service;
  late Map<String, Message> latest;
  late List<String> sentTexts;
  late bool failSends;

  setUp(() {
    service = MessageRetryService();
    latest = {};
    sentTexts = [];
    failSends = false;
    service.initialize(
      RetryServiceConfig(
        sendMessage: (_, text, _, _) async {
          if (failSends) throw StateError('Not connected');
          sentTexts.add(text);
        },
        addMessage: (_, m) => latest[m.messageId] = m,
        updateMessage: (m) => latest[m.messageId] = m,
      ),
    );
  });

  tearDown(() => service.dispose());

  Message byText(String text) =>
      latest.values.firstWhere((m) => m.text == text);

  test('failed send fails the message and frees the contact slot', () async {
    failSends = true;
    final contact = _contact();
    await service.sendMessageWithRetry(contact: contact, text: 'a');
    await pumpEventQueue();
    expect(byText('a').status, MessageStatus.failed);

    failSends = false;
    await service.sendMessageWithRetry(contact: contact, text: 'b');
    await pumpEventQueue();
    expect(sentTexts, ['b']);
  });

  test('failAllPending fails in-flight and queued messages', () async {
    final contact = _contact();
    await service.sendMessageWithRetry(contact: contact, text: 'a');
    await service.sendMessageWithRetry(contact: contact, text: 'b');
    await pumpEventQueue();
    expect(sentTexts, ['a']);

    service.failAllPending();
    await pumpEventQueue();

    expect(byText('a').status, MessageStatus.failed);
    expect(byText('b').status, MessageStatus.failed);
    expect(service.hasPendingMessages, isFalse);
    expect(sentTexts, ['a']);
  });
}
