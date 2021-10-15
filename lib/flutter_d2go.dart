import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'd2go_model.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class FlutterD2go {
  static const MethodChannel _channel =
      MethodChannel('tsubauaaa.com/flutter_d2go');

  /// D2Goモデル(d2go.pt)の相対パス[modelPath]を受けて、org.pytorch.Moduleのloadメソッド
  /// が読み込むためのパス形式の[absPath]を作成する
  /// invokeMethodでloadModelを呼び出し、D2GoModelクラスインスタンス[D2GoModel(index)]
  /// を取得、それを返却するメソッド
  static Future<D2GoModel> loadModel(String modelPath, String labelPath) async {
    String absModelPath = await _getAbsolutePath(modelPath);
    String absLabelPath = await _getAbsolutePath(labelPath);
    int index = await _channel.invokeMethod('loadModel', {
      'absModelPath': absModelPath,
      'absLabelPath': absLabelPath,
      'assetModelPath': modelPath,
      'assetLabelPath': labelPath,
    });
    return D2GoModel(index);
  }

  /// Flutter内のassetにあるD2Goモデル(d2go.pt)[path]をNativeが触れるパス[dirPath]にコピー
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
