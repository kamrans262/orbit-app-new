import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../circles/presentation/widgets/orbit_circle_sheet.dart';
import '../../../core/widgets/app_primary_button.dart';

class OrbitChatVoiceCapture {
  const OrbitChatVoiceCapture(this.file,this.durationMs);
  final File file;
  final int durationMs;
}

/// Existing Orbit full-width white bottom sheet, primary button and palette.
/// Recording is never sent until encrypted upload and M13 ACK succeed.
abstract final class OrbitChatVoiceRecorder {
  /// Delete only an app-created temporary voice recording, never a user's
  /// gallery media. Uploaded ciphertext and queued messages are unaffected.
  static Future<void> discardTemporaryCapture(File file) async {
    final temp=await getTemporaryDirectory();
    final name=file.uri.pathSegments.last;
    const prefix='orbit_m13_voice_';
    if(file.parent.absolute.path!=temp.absolute.path ||
        !name.startsWith(prefix) || !name.endsWith('.m4a') ||
        name.length!=prefix.length+36+5){
      return;
    }
    try{
      if(await file.exists())await file.delete();
    }catch(_){
      // The OS may have already removed this app-private temporary file.
    }
  }

  static Future<OrbitChatVoiceCapture?> open(BuildContext context) async {
    final recorder=AudioRecorder();
    File? output;
    var recording=false;
    OrbitChatVoiceCapture? completed;
    var elapsed=Duration.zero;
    Timer? ticker;
    final clock=Stopwatch();
    try{
      final result=await showOrbitCircleSheet<OrbitChatVoiceCapture>(
        context:context,title:'Voice Message',
        builder:(sheet)=>StatefulBuilder(
          builder:(ctx,update){
            Future<void> toggle() async {
              try{
                if(!recording){
                  if(!await recorder.hasPermission()){
                    throw StateError('Microphone permission was not granted.');
                  }
                  final dir=await getTemporaryDirectory();
                  output=File(dir.path+Platform.pathSeparator+
                    'orbit_m13_voice_'+const Uuid().v4()+'.m4a');
                  await recorder.start(const RecordConfig(
                    encoder:AudioEncoder.aacLc,
                    bitRate:96000,sampleRate:44100),
                    path:output!.path);
                  recording=true;
                  clock.start();
                  ticker=Timer.periodic(const Duration(milliseconds:250),(_){
                    if(ctx.mounted)update(()=>elapsed=clock.elapsed);
                  });
                  if(ctx.mounted)update((){});
                  return;
                }
                ticker?.cancel();
                clock.stop();
                final saved=await recorder.stop();
                recording=false;
                if(saved==null||output==null||!await output!.exists()||
                   clock.elapsedMilliseconds<500){
                  throw StateError('Recording is too short.');
                }
                if(ctx.mounted)Navigator.of(ctx).pop(
                  OrbitChatVoiceCapture(output!,clock.elapsedMilliseconds));
              }catch(_){
                if(ctx.mounted){
                  ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                    const SnackBar(content:Text(
                      'Microphone recording could not be completed.')));
                }
              }
            }
            final mm=elapsed.inMinutes.toString().padLeft(2,'0');
            final ss=elapsed.inSeconds.remainder(60).toString().padLeft(2,'0');
            return Column(
              mainAxisSize:MainAxisSize.min,
              crossAxisAlignment:CrossAxisAlignment.stretch,
              children:[
                const Text(
                  'Your voice message stays on your device until '
                  'an encrypted upload and recipient authorization succeed.',
                  style:TextStyle(fontFamily:AppTypography.fontFamily,
                    fontSize:13,color:AppColors.textMuted)),
                const SizedBox(height:18),
                Center(child:Icon(recording
                  ?Icons.mic_rounded:Icons.mic_none_rounded,
                  size:38,color:AppColors.primaryEnd)),
                const SizedBox(height:8),
                Center(child:Text(mm+':'+ss,
                  style:const TextStyle(fontFamily:AppTypography.fontFamily,
                    fontSize:24,fontWeight:FontWeight.w600,
                    color:AppColors.primaryEnd))),
                const SizedBox(height:20),
                AppPrimaryButton(label:recording
                  ?'Finish Recording':'Start Recording',
                  onPressed:()=>unawaited(toggle())),
                const SizedBox(height:10),
                TextButton(onPressed:()=>Navigator.of(ctx).pop(),
                  child:const Text('Cancel')),
              ],
            );
          },
        ),
      );
      completed=result;
      return result;
    }finally{
      ticker?.cancel();
      clock.stop();
      if(recording){
        try{await recorder.stop();}catch(_){}
      }
      await recorder.dispose();
      if(completed==null && output!=null && await output!.exists()){
        try{await output!.delete();}catch(_){}
      }
    }
  }
}
