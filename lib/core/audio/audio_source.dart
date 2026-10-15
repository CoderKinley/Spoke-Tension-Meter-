import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class AudioPacket {
  const AudioPacket(this.samples, this.sampleRate, this.sequence);
  final List<double> samples;
  final int sampleRate, sequence;
  factory AudioPacket.fromEvent(Map<dynamic, dynamic> event) {
    final bytes = event['pcm'] as Uint8List;
    if (bytes.length.isOdd) {
      throw const FormatException('Truncated PCM buffer');
    }
    final view = ByteData.sublistView(bytes);
    return AudioPacket(
      List.generate(
        bytes.length ~/ 2,
        (i) => view.getInt16(i * 2, Endian.little) / 32768.0,
      ),
      event['sampleRate'] as int,
      event['sequence'] as int,
    );
  }
}

abstract class AudioSource {
  Stream<AudioPacket> get packets;
  Future<String> start();
  Future<void> stop();
}

class AndroidAudioSource implements AudioSource {
  static const methods = MethodChannel('org.spokelab/audio');
  static const events = EventChannel('org.spokelab/pcm');
  @override
  Stream<AudioPacket> get packets => events.receiveBroadcastStream().map(
    (event) => AudioPacket.fromEvent(event as Map),
  );
  @override
  Future<String> start() async {
    final result = await methods.invokeMapMethod<String, dynamic>('start');
    if (result == null) {
      throw StateError('Audio capture did not start');
    }
    return '${result['device']} • ${result['source']} • ${result['sampleRate']} Hz';
  }

  @override
  Future<void> stop() => methods.invokeMethod<void>('stop');
}
