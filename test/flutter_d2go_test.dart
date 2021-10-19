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
    const MethodChannel path_provider_channel =
        MethodChannel('plugins.flutter.io/path_provider');
    path_provider_channel
        .setMockMethodCallHandler((MethodCall methodCall) async {
      return ".";
    });
  });

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      log.add(methodCall);
      return null;
    });
    log.clear();
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('loadModel', () async {
    await FlutterD2go.loadModel(
      modelPath: '${current.path}/example/assets/models/d2go.pt',
      labelPath: '${current.path}/example/assets/models/classes.txt',
    );
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
    await FlutterD2go.getImagePrediction(
      image: File('${current.path}/example/assets/images/test1.png'),
    );
    expect(log, <Matcher>[
      isMethodCall('predictImage', arguments: <String, dynamic>{
        'image': File('${current.path}/example/assets/images/test1.png')
            .readAsBytesSync(),
        'width': kInputWidth,
        'height': kInputHeight,
        'mean': kTorchvisionNormMeanRGB,
        'std': kTorchvisionNormStdRGB,
        'minScore': kMinScore,
      })
    ]);
  });
}
