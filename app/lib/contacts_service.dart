import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// A contact read from the device address book (or the demo fallback).
class DeviceContact {
  final String name;
  final List<String> phones;
  DeviceContact(this.name, this.phones);
}

class ContactsResult {
  final List<DeviceContact> contacts;
  final bool fromDevice; // false = demo fallback (web / denied / unsupported)
  ContactsResult(this.contacts, this.fromDevice);
}

class ContactsService {
  /// Reads device contacts (with permission). Falls back to a small demo set on
  /// web, when unsupported, or when permission is denied — so the matching UI
  /// is always demonstrable.
  Future<ContactsResult> load() async {
    if (kIsWeb) return ContactsResult(_demo(), false);
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) return ContactsResult(_demo(), false);
      final raw = await FlutterContacts.getContacts(withProperties: true);
      final contacts = raw
          .map((c) => DeviceContact(
                c.displayName,
                c.phones.map((p) => p.number).toList(),
              ))
          .where((c) => c.phones.isNotEmpty)
          .toList();
      return ContactsResult(contacts, true);
    } catch (_) {
      return ContactsResult(_demo(), false);
    }
  }

  /// Some of these intentionally match the seeded network peers' phone numbers
  /// (in varied formats) and some don't, to show matched vs. not-on-network.
  List<DeviceContact> _demo() => [
        DeviceContact('Mama', ['+63 917 000 0001']),
        DeviceContact('Kuya Jun', ['+63 917 000 0002']),
        DeviceContact('Tita Beth', ['0917 000 0003']),
        DeviceContact('Migs', ['+639170000004']),
        DeviceContact('Ana', ['+63 917 000 0005']),
        DeviceContact('Lola', ['09170000006']),
        DeviceContact('Sofia', ['+63 917 000 0008']),
        DeviceContact('Grace Tan', ['+639170000009']),
        DeviceContact('Marco', ['0917-000-0010']),
        DeviceContact('Boss Rey', ['+63 999 888 7777']), // not on network
        DeviceContact('Dentist', ['+63 999 111 2222']), // not on network
        DeviceContact('Kuya Driver', ['+63 999 333 4444']), // not on network
      ];
}

/// Normalize to the last 10 significant digits so '+63 917...', '0917...',
/// '+639170000001' all compare equal.
String normalizePhone(String s) {
  final digits = s.replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}
