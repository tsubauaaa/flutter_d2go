import 'dart:io';

import 'package:flutter/services.dart';

const kTorchvisionNormMeanRGB = [0.0, 0.0, 0.0];
const kTorchvisionNormStdRGB = [1.0, 1.0, 1.0];
const kInputWidth = 640;
const kInputHeight = 640;
const kMinScore = 0.4;

/// D2Goを使った推論を行うクラス
///
/// List<org.pytorch.Module>のindexがクラスプロパティ
class D2GoModel {
  D2GoModel(this._index);
  static const MethodChannel _channel = MethodChannel('tsubauaaa.com/flutter_d2go');

  final int _index;

  /// D2Goを使った推論結果[prediction]を返却するメソッド
  ///
  /// invokeMethodでd2goを呼び出す
  /// そのパラメータ引数はList<org.pytorch.Module>のindex[index],
  /// 推論対象の画像[image], その縦横長[width]/[height],
  /// Normalizeに使う平均値[mean]、標準偏差[std],
  /// 推論結果から除外するためのしきい値[minScore]となる
  Future<List?> getPredictionD2Go({required File image}) async {
    // Segmentation Label
    final List<String> labels = ['book'];

    // 推論
    final List? prediction = await _channel.invokeMethod(
      'd2go',
      {
        'index': _index,
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
