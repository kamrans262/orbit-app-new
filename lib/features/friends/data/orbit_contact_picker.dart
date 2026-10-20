import 'package:flutter_contacts/flutter_contacts.dart';

/// A deliberate one-person OS selection, not a bulk contacts sync.
/// Returns only one contact address, and only after read permission.
class OrbitSelectedContact {
  const OrbitSelectedContact({required this.type, required this.value, required this.label});
  final String type;
  final String value;
  final String label;
}

/// Native selection is permission-optional for discovery in general.
/// Calling code also presents a second consent dialog before network matching.
class OrbitContactPicker {
  Future<OrbitSelectedContact?> pick() async {
    final permission = await FlutterContacts.permissions.request(PermissionType.read);
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.limited) {
      return null;
    }
    final chosen = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.phone, ContactProperty.email},
    );
    if (chosen == null) return null;
    final address = chosen.emails
        .map((email) => email.address.trim().toLowerCase())
        .where((email) => email.contains('@') && email.length <= 190)
        .firstOrNull;
    if (address != null) {
      return OrbitSelectedContact(
        type: 'email', value: address,
        label: chosen.displayName ?? 'Selected contact',
      );
    }
    final phone = chosen.phones
        .map((number) => (number.normalizedNumber ?? number.number)
            .replaceAll(RegExp(r'[\s().-]'), ''))
        .where((number) => RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(number))
        .firstOrNull;
    if (phone != null) {
      return OrbitSelectedContact(
        type: 'phone', value: phone,
        label: chosen.displayName ?? 'Selected contact',
      );
    }
    return null;
  }
}
