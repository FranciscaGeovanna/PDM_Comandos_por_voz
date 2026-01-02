import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class ClassificadorAudio {
  late Interpreter _interpreter;
  bool _isModelLoaded = false;

  final List<String> labels = [
    'Background Noise',
    'ligado',
    'desligado',
    'cima',
    'baixo',
    'direita',
    'esquerda',
  ];

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/audio.tflite');
      _isModelLoaded = true;
      print("Modelo carregado com sucesso");
    } catch (e) {
      print("Erro ao carregar o modelo: $e");
    }
  }

  Future<String> classificarAudio(String audioPath) async {
    if (!_isModelLoaded) {
      await loadModel();
    }

    final file = File(audioPath);
    if (!file.existsSync()) {
      return "Erro: arquivo não encontrado";
    }

    final pcmBytes = await file.readAsBytes();
    final byteData = ByteData.sublistView(pcmBytes);
    final numSamples = pcmBytes.length ~/ 2;

    final Float32List floatBuffer = Float32List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      floatBuffer[i] = sample / 32768.0;
    }

    const int tamanhoEsperado = 44032;
    Float32List inputBuffer = Float32List(tamanhoEsperado);
    for (int i = 0; i < tamanhoEsperado; i++) {
      inputBuffer[i] = i < numSamples ? floatBuffer[i] : 0.0;
    }

    var input = inputBuffer.reshape([1, tamanhoEsperado]);
    var output = List.filled(labels.length, 0.0).reshape([1, labels.length]);

    _interpreter.run(input, output);

    List<double> probabilities = output[0];
    print("Probabilidades: $probabilities");

    // Encontra o índice da maior probabilidade
    int maxIndex = 0;
    double maxProb = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }

    String predictedLabel = labels[maxIndex];
    print("Classe prevista: $predictedLabel (prob: ${maxProb.toStringAsFixed(3)})");

    return predictedLabel;
  }
}