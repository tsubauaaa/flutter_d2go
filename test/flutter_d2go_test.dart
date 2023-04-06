import 'dart:io';
import 'dart:typed_data';

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

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      log.add(methodCall);
      if (methodCall.method == 'loadModel') {
        return "success";
      } else if (methodCall.method == 'predictImage') {
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
          },
        ];
      } else {
        return [
          {
            'rect': {
              'left': 36.4365234375,
              'top': 413.9417419433594,
              'right': 442.3828125,
              'bottom': 565.4701538085938
            },
            'confidenceInClass': 0.938831627368927,
            'detectedClass': 'keyboard'
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
        'modelPath': '${current.path}/example/assets/models/d2go.pt',
        'labelPath': '${current.path}/example/assets/models/classes.txt',
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
      },
    ]);
    expect(log, <Matcher>[
      isMethodCall('predictImage', arguments: <String, dynamic>{
        'image': File('${current.path}/example/assets/images/test1.png')
            .readAsBytesSync(),
        'inputWidth': kInputWidth,
        'inputHeight': kInputHeight,
        'mean': kNormMean,
        'std': kNormStd,
        'minScore': kMinScore,
      })
    ]);
  });

  test('getStreamImagePrediction', () async {
    final res = await FlutterD2go.getStreamImagePrediction(
      imageBytesList: [
        Uint8List.fromList([0, 1, 2])
      ],
      imageBytesPerRow: 1,
      imageBytesPerPixel: [1, 2, 2],
    );
    expect(res, [
      {
        'rect': {
          'left': 36.4365234375,
          'top': 413.9417419433594,
          'right': 442.3828125,
          'bottom': 565.4701538085938
        },
        'confidenceInClass': 0.938831627368927,
        'detectedClass': 'keyboard'
      },
    ]);
    expect(log, <Matcher>[
      isMethodCall('predictStreamImage', arguments: <String, dynamic>{
        'imageBytesList': [
          Uint8List.fromList([0, 1, 2])
        ],
        'imageBytesPerRow': 1,
        'imageBytesPerPixel': [1, 2, 2],
        'width': kWidth,
        'height': kHeight,
        'inputWidth': kInputWidth,
        'inputHeight': kInputHeight,
        'mean': kNormMean,
        'std': kNormStd,
        'minScore': kMinScore,
        'rotation': kRotation,
      })
    ]);
  });
}
