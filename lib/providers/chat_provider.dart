import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/vitals_history_service.dart';

/// Chat message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Provider for AI Health Chatbot using Gemini API
class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  String _patientContext = '';
  String _vitalsHistory = '';
  String _dailySummary = '';
  final VitalsHistoryService _historyService = VitalsHistoryService();

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;

  // ─── Configuration ──────────────────────────────────────
  void setApiKey(String key) {
    // Kept to avoid modifying main.dart, but we're hardcoded to Nvidia Qwen now
  }

  /// Update the patient vitals context for personalized responses
  void updatePatientContext({
    required double heartRate,
    required double spo2,
    required double temperature,
    required double systolic,
    required double diastolic,
    String? aiDiagnosis,
    List<Map<String, dynamic>>? recentAlerts,
  }) {
    _patientContext =
        '''
Current Patient Vitals (LIVE):
- Heart Rate: ${heartRate.toStringAsFixed(0)} BPM
- SpO2: ${spo2.toStringAsFixed(0)}%
- Temperature: ${temperature.toStringAsFixed(1)}°C
- Blood Pressure: ${systolic.toStringAsFixed(0)}/${diastolic.toStringAsFixed(0)} mmHg
- ECG Diagnosis: ${aiDiagnosis ?? 'Normal Sinus Rhythm'}
''';

    if (recentAlerts != null && recentAlerts.isNotEmpty) {
      _vitalsHistory = '\nRecent Alerts:\n';
      for (final alert in recentAlerts.take(5)) {
        _vitalsHistory += '- ${alert['message']} (${alert['severity']})\n';
      }
    }
  }

  /// Load today's daily summary from Firestore for AI context
  Future<void> loadDailySummary(String uid) async {
    _dailySummary = await _historyService.getSummaryForAI(uid);
  }

  // ─── Messaging ──────────────────────────────────────────
  void addWelcomeMessage() {
    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          text:
              'Hello! I\'m your VitalSync Health Assistant 🩺\n\nI can help you understand your vitals, answer health questions, and provide wellness guidance. What would you like to know?',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    _messages.add(
      ChatMessage(text: text.trim(), isUser: true, timestamp: DateTime.now()),
    );
    _isTyping = true;
    notifyListeners();

    try {
      String response = await _callNvidiaApi(text.trim());

      _messages.add(
        ChatMessage(text: response, isUser: false, timestamp: DateTime.now()),
      );
    } catch (e) {
      _messages.add(
        ChatMessage(
          text:
              'I\'m having trouble connecting right now. Let me answer based on general knowledge.\n\n${_generateMockResponse(text.trim())}',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  // ─── Nvidia API Integration (Qwen) ─────────────────────────────
  Future<String> _callNvidiaApi(String userMessage) async {
    final url = Uri.parse(
      'https://integrate.api.nvidia.com/v1/chat/completions',
    );

    final systemPrompt =
        '''
You are VitalSync Health Assistant, a caring and knowledgeable AI health companion built into a remote health monitoring app.

Your role:
- Help users understand their vital signs (heart rate, SpO2, temperature, blood pressure, ECG)
- Answer health questions in simple, easy-to-understand language
- Provide wellness tips and lifestyle advice
- Flag concerning vital patterns and recommend when to see a doctor
- Be empathetic, supportive, and encouraging
- When asked for a health summary or report, provide a comprehensive but concise summary of ALL current vitals with status indicators (Normal/Elevated/Low/Critical), trends, and personalized recommendations

Important rules:
- Never provide medical diagnoses — always recommend consulting a doctor for serious concerns
- Use simple language, avoid complex medical jargon
- Keep responses concise (2-4 sentences for simple questions, more for summaries)
- Reference the patient's current vitals when relevant
- Use emojis sparingly to make the conversation warm and friendly
- When generating a health summary, format it clearly with sections for each vital and an overall health score

$_patientContext
$_vitalsHistory
$_dailySummary
''';

    final body = jsonEncode({
      "model": "meta/llama-3.1-8b-instruct",
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": userMessage},
      ],
      "max_tokens": 1024,
      "temperature": 0.60,
      "top_p": 0.95,
      "stream": false,
    });

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization':
                  'Bearer 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',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 45)); // Increased from 20s to 45s for slow model inference

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String text = data['choices']?[0]?['message']?['content'] ?? '';

        // Remove <think>...</think> tags if the model returned them
        text = text
            .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
            .trim();

        if (text.isEmpty) {
          return 'I couldn\'t generate a response. Please try again.';
        }
        return text;
      } else {
        // Output the actual Nvidia error for easier debugging
        final errorData = jsonDecode(response.body);
        final errorMsg =
            errorData['detail'] ??
            errorData['error']?['message'] ??
            'Unknown error';
        debugPrint('Nvidia API Error (${response.statusCode}): $errorMsg');
        return 'API Error: $errorMsg';
      }
    } catch (e) {
      debugPrint('Nvidia HTTP Exception: $e');
      throw Exception('Failed to connect to AI service');
    }
  }

  // ─── Mock Responses (Offline / No API Key) ──────────────
  String _generateMockResponse(String query) {
    final q = query.toLowerCase();

    // Vitals-related
    if (q.contains('heart rate') || q.contains('pulse') || q.contains('hr')) {
      return 'Your current heart rate is reflected in the dashboard readings. A normal resting heart rate for adults is between 60-100 BPM. \n\nIf your heart rate is consistently above 100 BPM at rest, consider reducing caffeine, managing stress, and consulting your doctor. 💚';
    }
    if (q.contains('spo2') ||
        q.contains('oxygen') ||
        q.contains('saturation')) {
      return 'SpO2 measures the oxygen saturation in your blood. Normal levels are 95-100%. \n\nIf your SpO2 drops below 94%, practice deep breathing exercises. Below 90% requires immediate medical attention. Stay active and avoid smoking for better oxygen levels. 🫁';
    }
    if (q.contains('temperature') ||
        q.contains('fever') ||
        q.contains('temp')) {
      return 'Normal body temperature is approximately 36.1°C to 37.2°C (97°F to 99°F). \n\nA temperature above 38°C (100.4°F) is considered a fever. Stay hydrated, rest, and take fever-reducing medication if needed. See a doctor if fever persists for more than 3 days. 🌡️';
    }
    if (q.contains('blood pressure') || q.contains('bp')) {
      return 'Normal blood pressure is around 120/80 mmHg. \n\n• **Stage 1 Hypertension**: 130-139/80-89\n• **Stage 2 Hypertension**: 140+/90+\n\nReduce salt, exercise regularly, manage stress, and limit alcohol to maintain healthy BP. 💪';
    }
    if (q.contains('ecg') ||
        q.contains('electrocardiogram') ||
        q.contains('heart rhythm')) {
      return 'Your ECG shows the electrical activity of your heart. "Normal Sinus Rhythm" means your heart is beating regularly with a normal pattern. \n\nIf the ECG shows irregular patterns, it may indicate arrhythmia. Always consult a cardiologist for ECG interpretation. 📊';
    }

    // Wellness
    if (q.contains('sleep') || q.contains('insomnia')) {
      return 'Good sleep is vital for heart health! Here are tips:\n\n• Aim for 7-9 hours of sleep\n• Keep a consistent schedule\n• Avoid screens 1 hour before bed\n• Keep your room cool and dark\n• Avoid caffeine after 2 PM\n\nPoor sleep can raise blood pressure and heart rate. 😴';
    }
    if (q.contains('exercise') ||
        q.contains('workout') ||
        q.contains('active')) {
      return 'Regular exercise benefits your cardiovascular health! Recommendations:\n\n• 150 minutes of moderate activity per week\n• Or 75 minutes of vigorous activity\n• Include strength training 2x per week\n• Start slow if you\'re new to exercise\n\nMonitor your heart rate during exercise — stay in your target zone. 🏃';
    }
    if (q.contains('stress') || q.contains('anxiety') || q.contains('relax')) {
      return 'Stress directly affects your vitals — raising heart rate and blood pressure. Try these:\n\n• Deep breathing: 4-7-8 technique\n• Progressive muscle relaxation\n• Short walks in nature\n• Meditation (even 5 minutes helps)\n• Talking to someone you trust\n\nYour VitalSync app tracks stress indicators through HRV! 🧘';
    }
    if (q.contains('diet') ||
        q.contains('food') ||
        q.contains('nutrition') ||
        q.contains('eat')) {
      return 'Heart-healthy eating tips:\n\n• Eat more fruits, vegetables, and whole grains\n• Choose lean proteins (fish, chicken, legumes)\n• Limit sodium to under 2,300mg/day\n• Reduce processed foods and sugar\n• Stay hydrated — aim for 8 glasses of water daily\n\nThe DASH diet is specifically designed for better blood pressure! 🥗';
    }

    // General
    if (q.contains('hello') || q.contains('hi') || q.contains('hey')) {
      return 'Hello! 👋 I\'m here to help you stay on top of your health. You can ask me about:\n\n• Your vital signs and what they mean\n• Health tips and wellness advice\n• Sleep, exercise, and nutrition\n• When to see a doctor\n\nWhat would you like to know?';
    }
    if (q.contains('thank')) {
      return 'You\'re welcome! 💚 Remember, taking an active interest in your health is the first step to a healthier life. I\'m always here if you have more questions!';
    }

    // Default
    return 'That\'s a great question! While I don\'t have a specific answer for that right now, I recommend consulting with your healthcare provider for personalized medical advice.\n\nIn the meantime, keep monitoring your vitals with VitalSync — early detection is key to good health! 🩺';
  }

  // ─── Quick Suggestions ──────────────────────────────────
  List<String> get quickSuggestions => [
    'Summarize my health',
    'How is my heart rate?',
    'Tips for better sleep',
    'What does my SpO2 mean?',
    'Blood pressure advice',
    'Stress relief techniques',
  ];

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }
}
