import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

const kTorchvisionNormMeanRGB = [0.0, 0.0, 0.0];
const kTorchvisionNormStdRGB = [1.0, 1.0, 1.0];
const kInputWidth = 640;
const kInputHeight = 640;
const kMinScore = 0.4;

class FlutterD2go {
  static const MethodChannel _channel =
      MethodChannel('tsubauaaa.com/flutter_d2go');

  /// D2Goモデル(d2go.pt)の相対パス[modelPath]を受けて、org.pytorch.Moduleのloadメソッド
  /// が読み込むためのパス形式の[absPath]を作成する
  /// invokeMethodでloadModelを呼び出し、Native側のorg.pytorch.Moduleを生成するメソッド
  static Future loadModel(String modelPath, String labelPath) async {
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

  static Future<List?> getPredictionD2Go({required File image}) async {
    // 推論
    final List? prediction = await _channel.invokeMethod(
      'd2go',
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

  /// Flutter内のassetにあるD2Goモデル[path]をNativeが触れるパス[dirPath]にコピー
  /// するメソッド
  static Future<String> _getAbsolutePath(String path) async {
    // アプリがデータを配置可能なディレクトリのパス[dir]
    Directory dir = await getApplicationDocumentsDirectory();

    // [dir]とD2Goモデル(d2go.pt)の相対パスとをjoinした文字列[dirPath]
    // ex: /data/user/0/com.tsubauaaa.d2go.app/app_flutter/assets/models/d2go.pt
    String dirPath = join(dir.path, path);

    ByteData data = await rootBundle.load(path);
    List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    List split = path.split('/');
    String nextDir = '';

    // [dirPath]のディレクトリを作成する(mkdir -p的に)
    for (int i = 0; i < split.length; i++) {
      if (i != split.length - 1) {
        nextDir += split[i];
        await Directory(join(dir.path, nextDir)).create();
        nextDir += '/';
      }
    }
    // [dirPath]にD2Goモデル(d2go.pt)をコピーする
    await File(dirPath).writeAsBytes(bytes);

    return dirPath;
  }
}
