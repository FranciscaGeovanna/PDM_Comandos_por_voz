import 'package:comandos_por_voz/classificador_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Classificação de Áudios',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Classificação de Áudios'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}


class _MyHomePageState extends State<MyHomePage> {
  String start = "Iniciar captura de áudio";
  String stop = "Parar captura de áudio";

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderReady = false;
  bool _isRecording = false;

  String resultadoClassificacao = "Aguardando comando...";
  final ClassificadorAudio _classificadorAudio = ClassificadorAudio();

  @override
  void initState() {
    super.initState();
    initRecorder();
    _classificadorAudio.loadModel();
  }

  Future<void> initRecorder() async {
    await _recorder.openRecorder();
    _isRecorderReady = true;
    setState(() {});
  }

  Future<void> startRecording() async {
    if (!_isRecorderReady) return;
    await _recorder.startRecorder(
      toFile: 'audio_temp.pcm',
      codec: Codec.pcm16,
      sampleRate: 44100,
      numChannels: 1,
    );
    setState(() {
      _isRecording = true;
      resultadoClassificacao = "Ouvindo...";
    });
  }

  Future<void> stopRecording() async {
    if (!_isRecorderReady) return;
    final path = await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
    });

    if (path != null) {
      print("Áudio gravado em: $path");

      String classe = await _classificadorAudio.classificarAudio(path);
      setState(() {
        resultadoClassificacao = "Comando detectado: $classe";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        title: const Text(
          'Classificação de Áudios',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone do microfone
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isRecording ? 120 : 90,
              height: _isRecording ? 120 : 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? Colors.redAccent
                    : colorScheme.primary,
              ),
              child: const Icon(
                Icons.mic,
                size: 50,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 30),

            // Card do resultado
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      _isRecording ? "Ouvindo..." : "Resultado",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      resultadoClassificacao,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Botão principal
            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  if (_isRecording) {
                    await stopRecording();
                  } else {
                    await startRecording();
                  }
                },
                icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
                label: Text(
                  _isRecording ? stop : start,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }
}