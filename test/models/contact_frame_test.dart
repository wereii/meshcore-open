import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/connector/meshcore_protocol.dart';
import 'package:meshcore_open/models/contact.dart';

/// A RESP_CODE_CONTACT frame in the firmware's wire layout:
/// code, pub_key[32], type, flags, path_len, path[64], name[32],
/// last_advert_timestamp, gps_lat, gps_lon, lastmod.
Uint8List contactFrame(Uint8List pubKey, {String name = 'Test'}) {
  final b = BytesBuilder()
    ..addByte(respCodeContact)
    ..add(pubKey)
    ..addByte(1) // type
    ..addByte(0) // flags
    ..addByte(0xFF) // path_len = -1 (flood)
    ..add(Uint8List(maxPathSize));
  final nameBytes = Uint8List(maxNameSize);
  nameBytes.setRange(0, name.length, name.codeUnits);
  b
    ..add(nameBytes)
    ..add(Uint8List(4)) // last_advert_timestamp
    ..add(Uint8List(4)) // gps_lat
    ..add(Uint8List(4)) // gps_lon
    ..add(Uint8List(4)); // lastmod
  return b.toBytes();
}

void main() {
  group('Contact.fromFrame public key guard', () {
    test('rejects an all-zero public key', () {
      expect(Contact.fromFrame(contactFrame(Uint8List(pubKeySize))), isNull);
    });

    test('accepts a short tag zero-padded to 32 bytes', () {
      // Reserved key shape used by meshcomod's synthetic local-command contact:
      // a 6-byte ASCII tag followed by zero padding.
      final key = Uint8List(pubKeySize);
      key.setRange(0, 6, 'MESHCM'.codeUnits);
      final contact = Contact.fromFrame(contactFrame(key, name: 'Meshcomod'));
      expect(contact, isNotNull);
      expect(contact!.name, 'Meshcomod');
    });

    test('accepts an ordinary key', () {
      final key = Uint8List.fromList(List.generate(pubKeySize, (i) => i + 1));
      expect(Contact.fromFrame(contactFrame(key)), isNotNull);
    });
  });
}
