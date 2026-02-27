import 'dart:developer';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service to handle on-device ML Inference for the Arrhythmia TFLite model.
/// Input shape: [1, 375, 1] (Float32)
/// Output shape: [1, 4] (Float32)
class ArrhythmiaService {
  Interpreter? _interpreter;
  bool _isInit = false;

  final List<String> classLabels = [
    'Normal',
    'Supraventricular',
    'Ventricular',
    'Fusion',
  ];

  Future<void> init() async {
    try {
      // The path must match what is in pubspec.yaml exactly
      _interpreter = await Interpreter.fromAsset(
        'assets/models/arrhythmia.tflite',
      );
      _isInit = true;
      log('✅ Arrhythmia Model Loaded successfully');
    } catch (e) {
      log('❌ Failed to load model: $e');
    }
  }

  bool get isReady => _isInit && _interpreter != null;

  /// Runs inference on a 1D array of ECG data.
  /// Automatically pads or truncates to exactly 375 samples.
  Map<String, dynamic>? predict(List<double> ecgData) {
    if (!isReady) return null;

    // 1. Prepare exactly 375 sliding window samples
    List<double> inputWindow = List.from(ecgData);
    if (inputWindow.length > 375) {
      inputWindow = inputWindow.sublist(inputWindow.length - 375);
    } else if (inputWindow.length < 375) {
      inputWindow = [
        ...List.filled(375 - inputWindow.length, 0.0),
        ...inputWindow,
      ];
    }

    // 2. Reshape to [1, 375, 1] as required by the model
    var input = [
      inputWindow.map((e) => [e]).toList(),
    ];

    // 3. Prepare output buffer for [1, 4] shape
    var output = List<List<double>>.filled(1, List<double>.filled(4, 0.0));

    try {
      // 4. Run inference
      _interpreter!.run(input, output);

      final probabilities = output[0];

      // Find the argmax
      int topIndex = 0;
      double topProb = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > topProb) {
          topProb = probabilities[i];
          topIndex = i;
        }
      }

      return {
        'classIndex': topIndex,
        'label': topIndex < classLabels.length
            ? classLabels[topIndex]
            : 'Unknown',
        'confidence': topProb,
        'probabilities': probabilities,
      };
    } catch (e) {
      log('Prediction error: $e');
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}
