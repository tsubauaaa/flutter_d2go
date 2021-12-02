import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Camera stream image width size.
const kWidth = 720;

/// Camera stream image height size.
const kHeight = 1280;

/// Width size to resize for inference.
const kInputWidth = 320;

/// Height size to resize for inference.
const kInputHeight = 320;

/// mean for normalization.
const kNormMean = [0.0, 0.0, 0.0];

/// Standard deviation for normalization.
const kNormStd = [1.0, 1.0, 1.0];

/// Threshold of the inference result
const kMinScore = 0.5;

/// Tilt according to the orientation of the image to be inferred.
const kRotation = 0;

/// Infer using d2go in flutter.
///
/// Inference can be done for still images and camera stream images.
/// This class has a static method that performs each inference process.
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
  /// A method that calls loadModel with invokeMethod and creates pytorch module on the Native side.
  /// Returns success string on success and Null on failure.
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

  /// Receive the image file [image] for inference, the image size for inference [inputWidth], [inputHeight],
  /// the mean [mean] and standard deviation [std] for image normalization,
  /// the threshold of the inference result [minScore], and get the inference result.
  /// The format is List of { "rect": { "left": double, "top": double, "right": double, "bottom": double },
  ///                         "mask": Uint8List,
  ///                         "keypoints": [[double, double], [double, double], [double, double], [double, double], ...],
  ///                         "confidenceInClass": double, "detectedClass": String }. "mask" and "keypoints" do not exist on some models.
  static Future<List> getImagePrediction({
    required File image,
    int inputWidth = kInputWidth,
    int inputHeight = kInputHeight,
    List<double> mean = kNormMean,
    List<double> std = kNormStd,
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

  /// Receive the camera stream image [bytesList], [imageBytesList] for inference,
  /// the image size for inference [inputWidth], [inputHeight],
  /// the mean [mean] and standard deviation [std] for image normalization,
  /// the threshold of the inference result [minScore],
  /// the tilt according to the orientation of the image to be inferred [rotation],
  /// and get the inference result.
  /// The format is List of { "rect": { "left": double, "top": double, "right": double, "bottom": double },
  ///                         "mask": Uint8List,
  ///                         "keypoints": [[double, double], [double, double], [double, double], [double, double], ...],
  ///                         "confidenceInClass": double, "detectedClass": String }. "mask" and "keypoints" do not exist on some models.
  static Future<List> getStreamImagePrediction({
    required List<Uint8List> imageBytesList,
    required List<int?> imageBytesPerPixel,
    int width = kWidth,
    int height = kHeight,
    int inputWidth = kInputWidth,
    int inputHeight = kInputHeight,
    List<double> mean = kNormMean,
    List<double> std = kNormStd,
    double minScore = kMinScore,
    int rotation = kRotation,
  }) async {
    final List prediction = await _channel.invokeMethod(
      'predictStreamImage',
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
