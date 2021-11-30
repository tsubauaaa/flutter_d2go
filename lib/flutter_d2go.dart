import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

const kTorchvisionNormMeanRGB = [0.0, 0.0, 0.0];
const kTorchvisionNormStdRGB = [1.0, 1.0, 1.0];
const kWidth = 720;
const kHeight = 1280;
const kInputWidth = 320;
const kInputHeight = 320;
const kMinScore = 0.5;
const kRotation = 0;

class FlutterD2go {
  static const MethodChannel _channel =
      MethodChannel('tsubauaaa.com/flutter_d2go');

  /// A method to copy the D2Go model [path] in Flutter's asset to
  /// the path [dirPath] that native code can touch.
  static Future<String> _getAbsolutePath(String path) async {
    // The path of the directory where native code can place data [dir]
    Directory dir = await getApplicationDocumentsDirectory();

    // A string [dirPath] that joins [dir] with the relative path of the D2Go model file
    // in Flutter's asset [dirPath]
    // ex: /data/user/0/com.tsubauaaa.d2go.app/app_flutter/assets/models/d2go.pt
    String dirPath = join(dir.path, path);

    ByteData data = await rootBundle.load(path);
    List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    List split = path.split('/');
    String nextDir = '';

    // Create a directory for [dirPath] (like mkdir -p)
    for (int i = 0; i < split.length; i++) {
      if (i != split.length - 1) {
        nextDir += split[i];
        await Directory(join(dir.path, nextDir)).create();
        nextDir += '/';
      }
    }
    // Copy the D2Go model file to [dirPath]
    await File(dirPath).writeAsBytes(bytes);

    return dirPath;
  }

  /// Receive the d2go relative path [modelPath] and [labelPath] in Flutter's asset and
  /// get the path [absModelPath] and [absLabelPath] to read on the Native side.
  /// A method that calls loadModel with invokeMethod and creates org.pytorch.Module on the Native side.
  /// Returns success on success and Null on failure.
  static Future<String?> loadModel(
      {required String modelPath, required String labelPath}) async {
    String absModelPath = await _getAbsolutePath(modelPath);
    String absLabelPath = await _getAbsolutePath(labelPath);
    return await _channel.invokeMethod('loadModel', {
      'absModelPath': absModelPath,
      'absLabelPath': absLabelPath,
      'assetModelPath': modelPath,
      'assetLabelPath': labelPath,
    });
  }

  /// A method that calls predictImage with invokeMethod to predict
  static Future<List> getImagePrediction({
    required File image,
    int inputWidth = kInputWidth,
    int inputHeight = kInputHeight,
    List<double> mean = kTorchvisionNormMeanRGB,
    List<double> std = kTorchvisionNormStdRGB,
    double minScore = kMinScore,
  }) async {
    final List prediction = await _channel.invokeMethod(
      'predictImage',
      {
        'image': image.readAsBytesSync(),
        'inputWidth': inputWidth,
        'inputHeight': inputHeight,
        'mean': mean,
        'std': std,
        'minScore': minScore,
      },
    );

    return prediction;
  }

  static Future<List> getImageStreamPrediction({
    required List<Uint8List> imageBytesList,
    required List<int?> imageBytesPerPixel,
    int width = kWidth,
    int height = kHeight,
    int inputWidth = kInputWidth,
    int inputHeight = kInputHeight,
    List<double> mean = kTorchvisionNormMeanRGB,
    List<double> std = kTorchvisionNormStdRGB,
    double minScore = kMinScore,
    int rotation = kRotation,
  }) async {
    final List prediction = await _channel.invokeMethod(
      'predictImageStream',
      {
        'imageBytesList': imageBytesList,
        'imageBytesPerPixel': imageBytesPerPixel,
        'width': width,
        'height': height,
        'inputWidth': inputWidth,
        'inputHeight': inputHeight,
        'mean': mean,
        'std': std,
        'minScore': minScore,
        'rotation': rotation,
      },
    );

    return prediction;
  }
}
