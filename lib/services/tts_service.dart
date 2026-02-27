import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../config/constants.dart';

/// Vernacular Voice Engine — converts alert codes to spoken messages
/// in the user's preferred language using Sarvam AI.
/// Falls back to local Android TTS if Sarvam is unavailable.
class TtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  String _currentLanguage = 'en';
  bool _isSpeaking = false;

  // ─── Alert → Speech Mappings ────────────────────────────
  static const Map<String, Map<String, String>> _alertMessages = {
    'ALERT_HR_HIGH': {
      'en': 'Your heart rate is high. Please sit down and take rest.',
      'hi': 'Aapki dhadkan tez hai. Kripya baith jaiye aur aaram karein.',
      'mr':
          'Tumchya hrudayache thokke jaast aahet. Krupaya basa aani vishraanti ghya.',
    },
    'ALERT_HR_CRITICAL': {
      'en':
          'Warning! Heart rate is critically high. Seek immediate medical attention.',
      'hi': 'Chetavni! Dhadkan bahut tez hai. Turant doctor se sampark karein.',
      'mr':
          'Chetavni! Hrudayache thokke atishay jaast aahet. Lagech doctor la bhetaa.',
    },
    'ALERT_SPO2_LOW': {
      'en': 'Your oxygen level is low. Take deep breaths slowly.',
      'hi': 'Oxygen ka star kam hai. Dheere dheere gehri saans lein.',
      'mr': 'Tumchya oxygen chi paatali kami aahe. Haluhalu deep shwaas ghya.',
    },
    'ALERT_TEMP_HIGH': {
      'en': 'Your body temperature is high. Stay hydrated and rest.',
      'hi': 'Sharir ka taapman zyada hai. Paani pijiye aur aaram karein.',
      'mr':
          'Tumchya shariraache taapamaan jaast aahe. Paani pya aani vishraanti ghya.',
    },
    'ALERT_FALL': {
      'en':
          'Fall detected! Are you okay? Emergency contacts are being notified.',
      'hi':
          'Girne ka pata chala! Kya aap theek hain? Emergency contact ko suchit kiya ja raha hai.',
      'mr':
          'Padlyache aadhale! Tumhi theek aahat ka? Emergency contacts la kalvle jaat aahe.',
    },
    'ALERT_BP_HIGH': {
      'en': 'Blood pressure is elevated. Avoid salt and take rest.',
      'hi': 'Blood pressure badha hua hai. Namak kam khaiye aur aaram karein.',
      'mr': 'Blood pressure vadhla aahe. Meeth kami kha aani vishraanti ghya.',
    },
    'ALERT_SOS': {
      'en': 'SOS activated! Calling your emergency contact now.',
      'hi': 'SOS chalu! Aapke emergency contact ko call kiya ja raha hai.',
      'mr': 'SOS chalu! Tumchya emergency contact la call kela jaat aahe.',
    },
  };

  // ─── General health messages for TTS ────────────────────
  static const Map<String, Map<String, String>> _generalMessages = {
    'GREETING': {
      'en': 'Welcome to VitalSync. Your health companion.',
      'hi': 'VitalSync mein aapka swagat hai. Aapka swasthya saathi.',
      'mr': 'VitalSync madhe tumche swaagat aahe. Tumcha aarogya saathi.',
    },
    'ALL_NORMAL': {
      'en': 'All your vitals are within normal range. Keep it up!',
      'hi': 'Aapke saare vital signs normal hain. Aise hi rakhen!',
      'mr': 'Tumche sarv vital signs samanya aahet. Ase rahude!',
    },
    'CHECKUP_START': {
      'en': 'Starting health checkup. Please remain still.',
      'hi': 'Swasthya jaanch shuru ho rahi hai. Kripya sthir rahein.',
      'mr': 'Aarogya tapasani suru hot aahe. Krupaya sthir rahaa.',
    },
    'MEASUREMENT_COMPLETE': {
      'en': 'Measurement complete. Results are ready.',
      'hi': 'Maapan pura hua. Parinaam taiyar hain.',
      'mr': 'Maapan purn zaale. Parinaam tayar aahet.',
    },
    'TEST_ORTHOSTATIC': {
      'en': 'Starting orthostatic test. Please lie down and remain still.',
      'hi':
          'Orthostatic test shuru ho raha hai. Kripya lait jaiye aur sthir rahein.',
      'mr': 'Orthostatic test suru hot aahe. Krupaya zopa aani sthir rahaa.',
    },
    'TEST_BREATHING': {
      'en': 'Starting breathing test. Take slow, deep breaths.',
      'hi': 'Saans ka test shuru ho raha hai. Dheere dheere gehri saans lein.',
      'mr': 'Shwaas test suru hot aahe. Haluhalu deep shwaas ghya.',
    },
    'TEST_STRESS': {
      'en': 'Starting stress test. Walk briskly for two minutes.',
      'hi': 'Stress test shuru ho raha hai. Do minute tez chalen.',
      'mr': 'Stress test suru hot aahe. Don minute jhelat chala.',
    },
    'TEST_ECG': {
      'en': 'Starting ECG recording. Please sit still.',
      'hi': 'ECG recording shuru ho raha hai. Kripya baith kar sthir rahein.',
      'mr': 'ECG recording suru hot aahe. Krupaya basun sthir rahaa.',
    },
    'TEST_SLEEP': {
      'en': 'Analyzing your overnight vitals data.',
      'hi': 'Aapke raat ke vitals data ka vishleshan ho raha hai.',
      'mr': 'Tumchya raatrichya vitals data che vishleshan hot aahe.',
    },
    'TEST_COMPLETE': {
      'en': 'Test complete. Your results are ready.',
      'hi': 'Test pura hua. Aapke parinaam taiyar hain.',
      'mr': 'Test purn zaala. Tumche parinaam tayar aahet.',
    },
  };

  TtsService() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        _isSpeaking = false;
      }
    });

    // Initialize local TTS engine
    _flutterTts.setLanguage('en-IN');
    _flutterTts.setSpeechRate(0.45);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() => _isSpeaking = false);
  }

  // ─── Language Control ───────────────────────────────────
  Future<void> setLanguage(String langCode) async {
    _currentLanguage = langCode;
    // Update local TTS language too
    final ttsLang = _getSarvamLangCode(langCode);
    await _flutterTts.setLanguage(ttsLang);
  }

  String get currentLanguage => _currentLanguage;
  bool get isSpeaking => _isSpeaking;

  /// Map internal lang codes to Sarvam API target_language-code
  String _getSarvamLangCode(String lang) {
    switch (lang) {
      case 'hi':
        return 'hi-IN';
      case 'mr':
        return 'mr-IN';
      case 'ta':
        return 'ta-IN';
      case 'te':
        return 'te-IN';
      case 'kn':
        return 'kn-IN';
      case 'bn':
        return 'bn-IN';
      case 'gu':
        return 'gu-IN';
      case 'ml':
        return 'ml-IN';
      case 'or':
        return 'or-IN';
      case 'pa':
        return 'pa-IN';
      case 'en':
      default:
        return 'en-IN';
    }
  }

  /// Get the ideal speaker for the language
  String _getSpeaker(String langCode) {
    return 'neha';
  }

  // ─── Call Sarvam API ────────────────────────────────────
  /// Returns true if Sarvam TTS succeeds, false otherwise
  Future<bool> _callSarvamTts(String text) async {
    if (AppConstants.sarvamApiKey.isEmpty ||
        AppConstants.sarvamApiKey.contains('PASTE')) {
      debugPrint('TTS: Sarvam API key not set, using local TTS');
      return false;
    }

    final targetLang = _getSarvamLangCode(_currentLanguage);
    final speaker = _getSpeaker(targetLang);

    try {
      final response = await http.post(
        Uri.parse('https://api.sarvam.ai/text-to-speech'),
        headers: {
          'Content-Type': 'application/json',
          'api-subscription-key': AppConstants.sarvamApiKey,
        },
        body: jsonEncode({
          'inputs': [text],
          'target_language_code': targetLang,
          'speaker': speaker,
          'pitch': 0,
          'pace': 1.05,
          'loudness': 1.5,
          'speech_sample_rate': 8000,
          'enable_preprocessing': true,
          'model': 'bulbul:v1',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final base64Audio = data['audios']?[0];

        if (base64Audio != null) {
          final audioBytes = base64Decode(base64Audio);
          await _audioPlayer.play(BytesSource(audioBytes));
          _isSpeaking = true;
          return true;
        }
      } else {
        debugPrint(
          'TTS: Sarvam API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('TTS: Sarvam API Failed: $e');
    }
    return false;
  }

  // ─── Local TTS Fallback ─────────────────────────────────
  Future<void> _speakLocal(String text) async {
    debugPrint('TTS: Using local Android TTS: "$text"');
    _isSpeaking = true;
    await _flutterTts.speak(text);
  }

  // ─── Speech Methods ─────────────────────────────────────

  /// Speak an alert based on its code
  Future<void> speakAlert(String alertCode) async {
    final messages = _alertMessages[alertCode];
    if (messages == null) return;
    final text = messages[_currentLanguage] ?? messages['en']!;
    await _speak(text);
  }

  /// Speak a general message by key
  Future<void> speakMessage(String messageKey) async {
    final messages = _generalMessages[messageKey];
    if (messages == null) return;
    final text = messages[_currentLanguage] ?? messages['en']!;
    await _speak(text);
  }

  /// Speak any free-form text
  Future<void> speak(String text) async {
    await _speak(text);
  }

  /// Stop speaking
  Future<void> stop() async {
    await _audioPlayer.stop();
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) await stop();
    debugPrint('TTS: Speaking: "$text"');

    // Try Sarvam AI first, fall back to local TTS
    final success = await _callSarvamTts(text);
    if (!success) {
      await _speakLocal(text);
    }
  }

  /// Get the localized alert message text without speaking it
  String getAlertMessage(String alertCode) {
    final messages = _alertMessages[alertCode];
    if (messages == null) return alertCode;
    return messages[_currentLanguage] ?? messages['en']!;
  }

  /// Get the localized general message text without speaking it
  String getMessage(String messageKey) {
    final messages = _generalMessages[messageKey];
    if (messages == null) return messageKey;
    return messages[_currentLanguage] ?? messages['en']!;
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
