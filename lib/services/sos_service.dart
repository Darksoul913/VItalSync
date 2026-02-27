import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/patient.dart';
import 'tts_service.dart';

/// Centralized SOS orchestrator — handles phone calls, SMS, and alert dispatch.
class SosService {
  final TtsService _ttsService;
  bool _permissionsGranted = false;

  SosService({TtsService? ttsService})
    : _ttsService = ttsService ?? TtsService();

  /// Normalize phone number: add +91 if no country code
  String _normalizePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!cleaned.startsWith('+')) {
      cleaned = '+91$cleaned';
    }
    return cleaned;
  }

  /// Request CALL_PHONE and SEND_SMS permissions at runtime
  Future<bool> requestSosPermissions() async {
    if (_permissionsGranted) return true;

    final statuses = await [Permission.phone, Permission.sms].request();

    _permissionsGranted =
        statuses[Permission.phone]!.isGranted &&
        statuses[Permission.sms]!.isGranted;

    debugPrint(
      'SOS Permissions: phone=${statuses[Permission.phone]}, sms=${statuses[Permission.sms]}',
    );
    return _permissionsGranted;
  }

  /// Full SOS sequence: permissions → haptic → voice → call → SMS
  Future<void> triggerSos({
    required EmergencyContact contact,
    String? customMessage,
  }) async {
    // 0. Ensure permissions
    await requestSosPermissions();

    // 1. Haptic feedback
    await HapticFeedback.heavyImpact();

    // 2. Voice alert
    await _ttsService.speakAlert('ALERT_SOS');

    // 3. Call emergency contact
    await callContact(contact.phone);

    // 4. Send SMS with emergency message
    final smsBody =
        customMessage ??
        'SOS Alert from VitalSync! I need immediate help. Please check on me.';
    await sendSms(contact.phone, smsBody);
  }

  /// Launch phone dialer with the given number
  Future<bool> callContact(String phone) async {
    final normalized = _normalizePhone(phone);
    final uri = Uri(scheme: 'tel', path: normalized);
    debugPrint('SOS: Calling $normalized');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('SOS: Call failed: $e');
      return false;
    }
  }

  /// Place a direct phone call via Android ACTION_CALL (no dialer UI)
  Future<bool> callContactDirect(String phone) async {
    // Ensure CALL_PHONE permission
    if (!await Permission.phone.isGranted) {
      final status = await Permission.phone.request();
      if (!status.isGranted) {
        debugPrint('SOS: CALL_PHONE permission denied, falling back to dialer');
        return callContact(phone);
      }
    }

    final normalized = _normalizePhone(phone);
    debugPrint('SOS: Direct call to $normalized');
    try {
      const channel = MethodChannel('com.vitalsync/call');
      final result = await channel.invokeMethod('makeCall', {
        'phone': normalized,
      });
      debugPrint('SOS: Direct call initiated: $result');
      return result == true;
    } catch (e) {
      debugPrint('SOS: Direct call failed: $e, falling back to dialer');
      return callContact(phone);
    }
  }

  /// Open SMS app with pre-filled message
  Future<bool> sendSms(String phone, String message) async {
    final normalized = _normalizePhone(phone);
    final uri = Uri(
      scheme: 'sms',
      path: normalized,
      queryParameters: {'body': message},
    );
    debugPrint('SOS: Opening SMS to $normalized');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('SOS: SMS failed: $e');
      return false;
    }
  }

  /// Send SMS directly in background via Android SmsManager (no user interaction)
  Future<bool> sendDirectSms(String phone, String message) async {
    // Ensure SMS permission
    if (!await Permission.sms.isGranted) {
      final status = await Permission.sms.request();
      if (!status.isGranted) {
        debugPrint('SOS: SMS permission denied, falling back to SMS app');
        return sendSms(phone, message);
      }
    }

    final normalized = _normalizePhone(phone);
    debugPrint('SOS: Direct SMS to $normalized');
    try {
      const channel = MethodChannel('com.vitalsync/sms');
      final result = await channel.invokeMethod('sendSms', {
        'phone': normalized,
        'message': message,
      });
      debugPrint('SOS: Direct SMS sent: $result');
      return result == true;
    } catch (e) {
      debugPrint('SOS: Direct SMS failed: $e, falling back to SMS app');
      return sendSms(phone, message);
    }
  }

  /// Auto-send alert SMS with contextual vital info
  Future<void> autoAlertSms({
    required String phone,
    required String alertCode,
    required String alertMessage,
    required double vitalValue,
  }) async {
    String smsBody;
    switch (alertCode) {
      case 'ALERT_HR_CRITICAL':
        smsBody =
            'VitalSync ALERT: Heart rate critically high at ${vitalValue.toInt()} BPM. '
            'Immediate attention required. Please check on the patient.';
        break;
      case 'ALERT_SPO2_LOW':
        smsBody =
            'VitalSync ALERT: Blood oxygen (SpO2) critically low at ${vitalValue.toInt()}%. '
            'Immediate medical attention required.';
        break;
      case 'ALERT_TEMP_HIGH':
        smsBody =
            'VitalSync ALERT: Body temperature critically high at ${vitalValue.toStringAsFixed(1)}°C. '
            'Please check on the patient immediately.';
        break;
      case 'ALERT_FALL':
        smsBody =
            'VitalSync ALERT: A fall has been detected! '
            'The patient may need immediate help. Please check on them.';
        break;
      case 'ALERT_BP_HIGH':
        smsBody =
            'VitalSync ALERT: Blood pressure is critically elevated. '
            'Immediate medical attention recommended.';
        break;
      default:
        smsBody =
            'VitalSync ALERT: $alertMessage. Please check on the patient.';
    }

    await sendDirectSms(phone, smsBody);
  }

  // ─── Auto-Emergency: Call + SMS all contacts ────────────────

  /// Trigger automatic emergency alert to ALL contacts.
  /// Sends direct SMS to every contact, then places a direct call to the first contact.
  Future<void> triggerAutoEmergency({
    required List<EmergencyContact> contacts,
    required String emergencySummary,
  }) async {
    if (contacts.isEmpty) {
      debugPrint('SOS: No emergency contacts configured for auto-emergency');
      return;
    }

    // 0. Ensure permissions
    await requestSosPermissions();

    // 1. Haptic feedback
    await HapticFeedback.heavyImpact();

    // 2. Voice alert
    await _ttsService.speakAlert('ALERT_SOS');

    // 3. Send direct SMS to ALL contacts
    for (final contact in contacts) {
      if (contact.phone.isNotEmpty) {
        debugPrint('SOS: Auto-SMS to ${contact.name} (${contact.phone})');
        await sendDirectSms(contact.phone, emergencySummary);
      }
    }

    // 4. Place direct call to the FIRST contact
    final primaryContact = contacts.first;
    if (primaryContact.phone.isNotEmpty) {
      debugPrint(
        'SOS: Auto-CALL to ${primaryContact.name} (${primaryContact.phone})',
      );
      await callContactDirect(primaryContact.phone);
    }
  }
}
