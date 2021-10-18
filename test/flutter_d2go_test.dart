import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_d2go/flutter_d2go.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('tsubauaaa.com/flutter_d2go');

  final List<MethodCall> log = <MethodCall>[];

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

  // TODO: test loadModel method
  // test('loadModel', () async {
  //   await FlutterD2go.loadModel(
  //     './example/assets/models/d2go.pt',
  //     './example/assets/models/classes.txt',
  //   );
  //   expect(log, <Matcher>[
  //     isMethodCall('loadModel', arguments: <String, dynamic>{
  //       'modelPath': './example/assets/models/d2go.pt',
  //       'labelPath': './example/assets/models/classes.txt',
  //     })
  //   ]);
  // });

  test('getImagePrediction', () async {
    await FlutterD2go.getImagePrediction(
      image: File('./example/assets/images/test1.png'),
    );
    expect(log, <Matcher>[
      isMethodCall('predictImage', arguments: <String, dynamic>{
        'image': File('./example/assets/images/test1.png').readAsBytesSync(),
        'width': kInputWidth,
        'height': kInputHeight,
        'mean': kTorchvisionNormMeanRGB,
        'std': kTorchvisionNormStdRGB,
        'minScore': kMinScore,
      })
    ]);
  });
}
