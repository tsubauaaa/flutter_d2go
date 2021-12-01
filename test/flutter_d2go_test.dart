import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_d2go/flutter_d2go.dart';
import 'package:flutter_test/flutter_test.dart';

/// Run as root in the flutter_d2go project
/// "flutter test" to run
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('tsubauaaa.com/flutter_d2go');

  final List<MethodCall> log = <MethodCall>[];

  final Directory current = Directory.current;

  setUpAll(() {
    // expose path_provider
    const MethodChannel pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    pathProviderChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      return ".";
    });
  });

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      log.add(methodCall);
      if (methodCall.method == 'loadModel') {
        return "success";
      } else {
        return [
          {
            'rect': {
              'left': 74.65713500976562,
              'top': 76.94147491455078,
              'right': 350.64324951171875,
              'bottom': 323.0279846191406
            },
            'confidenceInClass': 0.985002338886261,
            'detectedClass': "bicycle",
            'mask': [0, 255, 255, 0],
          },
        ];
      }
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
    log.clear();
  });

  test('loadModel', () async {
    final res = await FlutterD2go.loadModel(
      modelPath: '${current.path}/example/assets/models/d2go.pt',
      labelPath: '${current.path}/example/assets/models/classes.txt',
    );
    expect(res, "success");
    expect(log, <Matcher>[
      isMethodCall('loadModel', arguments: <String, dynamic>{
        'absModelPath': '${current.path}/example/assets/models/d2go.pt',
        'absLabelPath': '${current.path}/example/assets/models/classes.txt',
        'assetModelPath': '${current.path}/example/assets/models/d2go.pt',
        'assetLabelPath': '${current.path}/example/assets/models/classes.txt',
      })
    ]);
  });

  test('getImagePrediction', () async {
    final res = await FlutterD2go.getImagePrediction(
      image: File('${current.path}/example/assets/images/test1.png'),
    );
    expect(res, [
      {
        'rect': {
          'left': 74.65713500976562,
          'top': 76.94147491455078,
          'right': 350.64324951171875,
          'bottom': 323.0279846191406
        },
        'confidenceInClass': 0.985002338886261,
        'detectedClass': "bicycle",
        'mask': [0, 255, 255, 0],
      },
    ]);
    expect(log, <Matcher>[
      isMethodCall('predictImage', arguments: <String, dynamic>{
        'image': File('${current.path}/example/assets/images/test1.png')
            .readAsBytesSync(),
        'width': kInputWidth,
        'height': kInputHeight,
        'mean': kNormMean,
        'std': kNormStd,
        'minScore': kMinScore,
      })
    ]);
  });
}
