// Copyright 2023 FluffyChat.
// This file is part of FluffyChat

// Licensed under the AGPL;
//
// https://gitlab.com/famedly/fluffychat
//

import 'dart:async';
import 'dart:io';
import 'package:asyou_app/infra/pages/channel/content/audio_player.dart';
import 'package:asyou_app/domain/utils/functions.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:asyou_app/router.dart';
import 'package:asyou_app/application/store/theme.dart';
import 'package:asyou_app/domain/utils/platform_infos.dart';
import 'package:asyou_app/domain/utils/screen/screen.dart';

class RecordingDialog extends StatefulWidget {
  static const String recordingFileType = 'm4a';
  const RecordingDialog({
    Key? key,
  }) : super(key: key);

  @override
  RecordingDialogState createState() => RecordingDialogState();
}

class RecordingDialogState extends State<RecordingDialog> {
  Timer? _recorderSubscription;
  Duration _duration = Duration.zero;

  bool error = false;
  String? _recordedPath;
  final _audioRecorder = Record();
  final List<double> amplitudeTimeline = [];

  static const int bitRate = 64000;
  static const int samplingRate = 22050;

  Future<void> startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _recordedPath =
          '${tempDir.path}/recording${DateTime.now().microsecondsSinceEpoch}.${RecordingDialog.recordingFileType}';
      // mac特别处理
      if (PlatformInfos.isMacOS) {
        _recordedPath = "file://$_recordedPath";
      }

      // 判断权限
      final result = await _audioRecorder.hasPermission();
      if (result != true) {
        setState(() => error = true);
        return;
      }

      // 开始录音
      final isSupported = await _audioRecorder.isEncoderSupported(
        AudioEncoder.aacLc,
      );
      printDebug('${AudioEncoder.aacLc.name} supported: $isSupported');
      await _audioRecorder.start(path: _recordedPath);

      setState(() => _duration = Duration.zero);

      _recorderSubscription?.cancel();
      _recorderSubscription = Timer.periodic(const Duration(milliseconds: 100), (_) async {
        final amplitude = await _audioRecorder.getAmplitude();
        var value = 100 + amplitude.current * 2;
        value = value < 1 ? 1 : value;
        amplitudeTimeline.add(value);
        setState(() {
          _duration += const Duration(milliseconds: 100);
        });
      });
    } catch (_) {
      setState(() => error = true);
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    startRecording();
  }

  @override
  void dispose() {
    _recorderSubscription?.cancel();
    _audioRecorder.stop();
    super.dispose();
  }

  void _stopAndSend() async {
    _recorderSubscription?.cancel();
    var path = await _audioRecorder.stop();
    if (path == null) {
      BotToast.showText(
        text: 'Recording failed',
        duration: const Duration(seconds: 2),
      );
      Navigator.of(globalCtx(), rootNavigator: false).pop();
      return;
    }
    print(path);
    // mac特别处理
    if (PlatformInfos.isMacOS) {
      path = path.replaceAll("file://", "");
    }

    final audioFile = File(path);
    if (!(await audioFile.exists())) {
      BotToast.showText(
        text: 'Recording failed file not exist',
        duration: const Duration(seconds: 2),
      );
      Navigator.of(globalCtx(), rootNavigator: false).pop();
      return;
    }
    const waveCount = AudioPlayerWidget.wavesCount;
    final step = amplitudeTimeline.length < waveCount ? 1 : (amplitudeTimeline.length / waveCount).round();
    final waveform = <int>[];
    for (var i = 0; i < amplitudeTimeline.length; i += step) {
      waveform.add((amplitudeTimeline[i] / 100 * 1024).round());
    }

    Navigator.of(globalCtx(), rootNavigator: false).pop<RecordingResult>(
      RecordingResult(
        path: path,
        duration: _duration.inMilliseconds,
        waveform: waveform,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final constTheme = Theme.of(context).extension<ExtColors>()!;
    const maxDecibalWidth = 54.0;
    final time =
        '${_duration.inMinutes.toString().padLeft(2, '0')}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}';
    final content = error
        ? Text(L10n.of(context)!.oopsSomethingWentWrong)
        : Padding(
            padding: EdgeInsets.only(top: 22.w),
            child: Row(
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  size: 20.w,
                  color: constTheme.buttonBg,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: amplitudeTimeline.reversed
                        .take(26)
                        .toList()
                        .reversed
                        .map(
                          (amplitude) => Container(
                            margin: const EdgeInsets.only(left: 2),
                            width: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            height: maxDecibalWidth * (amplitude / 100),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: Text(time),
                ),
              ],
            ),
          );
    return AlertDialog(
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: false).pop(),
          child: Text(
            L10n.of(context)!.cancel.toUpperCase(),
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(150),
            ),
          ),
        ),
        if (error != true)
          TextButton(
            onPressed: _stopAndSend,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(L10n.of(context)!.send.toUpperCase()),
                const SizedBox(width: 4),
                const Icon(Icons.send_outlined, size: 15),
              ],
            ),
          ),
      ],
    );
  }
}

class RecordingResult {
  final String path;
  final int duration;
  final List<int> waveform;

  const RecordingResult({
    required this.path,
    required this.duration,
    required this.waveform,
  });

  factory RecordingResult.fromJson(Map<String, dynamic> json) => RecordingResult(
        path: json['path'],
        duration: json['duration'],
        waveform: List<int>.from(json['waveform']),
      );

  Map<String, dynamic> toJson() => {
        'path': path,
        'duration': duration,
        'waveform': waveform,
      };
}
