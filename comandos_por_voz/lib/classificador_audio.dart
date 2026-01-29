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
    if (_isModelLoaded) return;

    try {
      _interpreter = await Interpreter.fromAsset('assets/models/audio.tflite');
      _isModelLoaded = true;

      final inputTensor = _interpreter.getInputTensors()[0];
      final outputTensor = _interpreter.getOutputTensors()[0];

      print("Input shape: ${inputTensor.shape}");
      print("Input type: ${inputTensor.type}");
      print("Output shape: ${outputTensor.shape}");
      print("Tamanho de áudio esperado: ${inputTensor.shape.last} samples");
      print("Modelo carregado com sucesso!");
    } catch (e) {
      print("Erro ao carregar o modelo: $e");
    }
  }

  Future<String> classificarAudio(String audioPath) async {
    if (!_isModelLoaded) {
      await loadModel();
    }

    if (_interpreter == null) {
      return "Erro: modelo não carregado";
    }

    final file = File(audioPath);
    if (!file.existsSync()) {
      return "Erro: arquivo não encontrado";
    }

    final pcmBytes = await file.readAsBytes();
    if (pcmBytes.isEmpty) {
      return "Erro: áudio vazio";
    }

    final byteData = ByteData.sublistView(pcmBytes);
    final numSamples = pcmBytes.length ~/ 2;

    final Float32List floatBuffer = Float32List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      floatBuffer[i] = sample / 32768.0;
    }

    const int tamanhoEsperado = 44032;
    Float32List inputBuffer;

    if (numSamples >= tamanhoEsperado) {
      final inicio = (numSamples - tamanhoEsperado) ~/ 2;
      inputBuffer = Float32List.fromList(
        floatBuffer.sublist(inicio, inicio + tamanhoEsperado),
      );
    } else {
      inputBuffer = Float32List(tamanhoEsperado);
      final offset = (tamanhoEsperado - numSamples) ~/ 2;
      inputBuffer.setRange(offset, offset + numSamples, floatBuffer);
    }

    const double gain = 5.0;
    for (int i = 0; i < inputBuffer.length; i++) {
      inputBuffer[i] *= gain;
      if (inputBuffer[i] > 1.0) inputBuffer[i] = 1.0;
      if (inputBuffer[i] < -1.0) inputBuffer[i] = -1.0;
    }

    double somaAbs = 0.0;
    for (var val in inputBuffer) {
      somaAbs += val.abs();
    }
    double mediaAbs = somaAbs / inputBuffer.length;
    print("Média ABSOLUTA do inputBuffer: $mediaAbs  (ideal: 0.02 ~ 0.2 para fala clara)");

    // Preparar input para o modelo
    var input = inputBuffer.reshape([1, tamanhoEsperado]);

    final outputShape = _interpreter.getOutputTensor(0).shape;
    final outputSize = outputShape.reduce((a, b) => a * b);
    final outputBuffer = List.filled(outputSize, 0.0).reshape(outputShape);

    try {
      _interpreter.run(input, outputBuffer);
    } catch (e) {
      print("Erro durante inferência: $e");
      return "Erro na inferência do modelo";
    }

    final List<double> probabilities = outputBuffer[0];
    print("Probabilidades: $probabilities");

    if (probabilities.any((p) => p.isNaN)) {
      print("NaN detectado nas probabilidades → provável áudio muito baixo ou silêncio");
      return "Background Noise (áudio muito baixo ou inválido)";
    }

    // Encontrar a classe com maior probabilidade
    int maxIndex = 0;
    double maxProb = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }

    String predictedLabel = labels[maxIndex];
    print("Classe prevista: $predictedLabel (confiança: ${(maxProb * 100).toStringAsFixed(1)}%)");

    return predictedLabel;
  }
}