import 'package:flutter/material.dart';
import 'app/lab_controller.dart';
import 'app/lab_app.dart';
import 'core/audio/audio_source.dart';
import 'data/repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repository = await LocalRepository.open();
    final controller = LabController(
      audio: AndroidAudioSource(),
      repository: repository,
    );
    await controller.initialize();
    runApp(LabApp(controller: controller));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Spoke Lab could not open local storage. Your saved files have not been replaced.\n\n$e',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
