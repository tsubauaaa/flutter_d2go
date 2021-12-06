import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// A list of Y-byte, Cb-byte, and Cr-byte pixel strides.
const List<int> kBytesPerPixel = [1, 2, 2];

/// Camera stream image width size.
const int kWidth = 720;

/// Camera stream image height size.
const int kHeight = 1280;

/// Width size to resize for inference.
const int kInputWidth = 320;

/// Height size to resize for inference.
const int kInputHeight = 320;

/// mean for normalization.
const List<double> kNormMean = [0.0, 0.0, 0.0];

/// Standard deviation for normalization.
const List<double> kNormStd = [1.0, 1.0, 1.0];

/// Threshold of the inference result
const double kMinScore = 0.5;

/// Tilt according to the orientation of the image to be inferred.
const int kRotation = 0;

/// Infer using d2go in flutter.
///
/// Inference can be done for still images and camera stream images.
/// This class has a static method that performs each inference process.
class FlutterD2go {
  static const MethodChannel _channel =
      MethodChannel('tsubauaaa.com/flutter_d2go');

  /// Receive the d2go relative path [modelPath] and [labelPath] in Flutter's asset.
  /// A method that calls loadModel with invokeMethod and creates pytorch module and labe ArrayList on the Native side.
  /// Returns success string on success and Null on failure.
  static Future<String?> loadModel(
      {required String modelPath, required String labelPath}) async {
    return await _channel.invokeMethod('loadModel', {
      'modelPath': modelPath,
      'labelPath': labelPath,
    });
  }

  /// Using the image file [image] (required) for inference, the image size for inference [inputWidth], [inputHeight],
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

  /// Using the camera stream image [imageBytesList] (required), [imageBytesPerPixel] for inference,
  /// the stream image size [width], [height],
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
    List<int?> imageBytesPerPixel = kBytesPerPixel,
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
