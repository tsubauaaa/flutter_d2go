import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

const kTorchvisionNormMeanRGB = [0.0, 0.0, 0.0];
const kTorchvisionNormStdRGB = [1.0, 1.0, 1.0];
const kInputWidth = 640;
const kInputHeight = 640;
const kMinScore = 0.5;

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

  /// Receive the relative path [modelPath] of the D2Go model file in Flutter's asset and
  /// get the path [absPath] to read on the Native side.
  /// A method that calls loadModel with invokeMethod and creates org.pytorch.Module on the Native side
  static Future loadModel(
      {required String modelPath, required String labelPath}) async {
    String absModelPath = await _getAbsolutePath(modelPath);
    String absLabelPath = await _getAbsolutePath(labelPath);
    await _channel.invokeMethod('loadModel', {
      'absModelPath': absModelPath,
      'absLabelPath': absLabelPath,
      'assetModelPath': modelPath,
      'assetLabelPath': labelPath,
    });
    return;
  }

  /// A method that calls predictImage with invokeMethod to predict
  static Future<List?> getImagePrediction({required File image}) async {
    final List? prediction = await _channel.invokeMethod(
      'predictImage',
      {
        'image': image.readAsBytesSync(),
        'width': kInputWidth,
        'height': kInputHeight,
        'mean': kTorchvisionNormMeanRGB,
        'std': kTorchvisionNormStdRGB,
        'minScore': kMinScore,
      },
    );

    return prediction;
  }
}
