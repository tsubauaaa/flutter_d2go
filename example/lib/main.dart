import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_d2go/flutter_d2go.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error: ${e.code}, Message: ${e.description}');
  }
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<RecognitionModel>? _recognitions;
  File? _selectedImage;
  final List<String> _imageList = ['test1.png', 'test2.jpeg', 'test3.png'];
  int _index = 0;
  int? _imageWidth;
  int? _imageHeight;
  final ImagePicker _picker = ImagePicker();

  CameraController? controller;
  bool _isDetecting = false;
  bool _isLiveModeOn = false;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> live() async {
    controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
    );
    await controller!.initialize().then(
      (_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      },
    );
    await controller!.startImageStream(
      (CameraImage cameraImage) async {
        if (_isDetecting) return;

        _isDetecting = true;

        await FlutterD2go.getStreamImagePrediction(
          imageBytesList:
              cameraImage.planes.map((plane) => plane.bytes).toList(),
          width: cameraImage.width,
          height: cameraImage.height,
          minScore: 0.5,
          rotation: 90,
        ).then(
          (predictions) {
            List<RecognitionModel>? recognitions;
            if (predictions.isNotEmpty) {
              recognitions = predictions.map(
                (e) {
                  return RecognitionModel(
                      Rectangle(
                        e['rect']['left'],
                        e['rect']['top'],
                        e['rect']['right'],
                        e['rect']['bottom'],
                      ),
                      e['mask'],
                      e['keypoints'] != null
                          ? (e['keypoints'] as List)
                          .map((k) => Keypoint(k[0], k[1]))
                          .toList()
                          : null,
                      e['confidenceInClass'],
                      e['detectedClass']);
                },
              ).toList();
            }
            setState(
              () {
                // With android, the inference result of the camera streaming image is tilted 90 degrees,
                // so the vertical and horizontal directions are reversed.
                _imageWidth = cameraImage.height;
                _imageHeight = cameraImage.width;
                _recognitions = recognitions;
              },
            );
          },
        ).whenComplete(
          () => Future.delayed(
            const Duration(
              milliseconds: 100,
            ),
            () {
              setState(() => _isDetecting = false);
            },
          ),
        );
      },
    );
  }

  Future loadModel() async {
    String modelPath = 'assets/models/d2go.ptl';
    String labelPath = 'assets/models/classes.txt';
    try {
      await FlutterD2go.loadModel(
        modelPath: modelPath,
        labelPath: labelPath,
      );
      setState(() {});
    } on PlatformException {
      debugPrint('Load model or label file failed.');
    }
  }

  Future detect() async {
    final image = _selectedImage ??
        await getImageFileFromAssets('assets/images/${_imageList[_index]}');
    final decodedImage = await decodeImageFromList(image.readAsBytesSync());
    final predictions = await FlutterD2go.getImagePrediction(
      image: image,
      minScore: 0.8,
    );
    List<RecognitionModel>? recognitions;
    if (predictions.isNotEmpty) {
      recognitions = predictions.map(
        (e) {
          return RecognitionModel(
              Rectangle(
                e['rect']['left'],
                e['rect']['top'],
                e['rect']['right'],
                e['rect']['bottom'],
              ),
              e['mask'],
              e['keypoints'] != null
                  ? (e['keypoints'] as List)
                      .map((k) => Keypoint(k[0], k[1]))
                      .toList()
                  : null,
              e['confidenceInClass'],
              e['detectedClass']);
        },
      ).toList();
    }

    setState(
      () {
        _imageWidth = decodedImage.width;
        _imageHeight = decodedImage.height;
        _recognitions = recognitions;
      },
    );
  }

  Future<File> getImageFileFromAssets(String path) async {
    final byteData = await rootBundle.load(path);
    final fileName = path.split('/').last;
    final file = File('${(await getTemporaryDirectory()).path}/$fileName');
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

    return file;
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    List<Widget> stackChildren = [];
    stackChildren.add(
      Positioned(
        top: 0.0,
        left: 0.0,
        width: screenWidth,
        child: _selectedImage == null
            ? Image.asset(
                'assets/images/${_imageList[_index]}',
              )
            : Image.file(_selectedImage!),
      ),
    );

    if (_isLiveModeOn) {
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: screenWidth,
          child: CameraPreview(controller!),
        ),
      );
    }

    if (_recognitions != null) {
      final aspectRatio = _imageHeight! / _imageWidth! * screenWidth;
      final widthScale = screenWidth / _imageWidth!;
      final heightScale = aspectRatio / _imageHeight!;

      if (_recognitions!.first.mask != null) {
        stackChildren.addAll(_recognitions!.map(
          (recognition) {
            return RenderSegments(
              imageWidthScale: widthScale,
              imageHeightScale: heightScale,
              recognition: recognition,
            );
          },
        ).toList());
      }

      if (_recognitions!.first.keypoints != null) {
        for (RecognitionModel recognition in _recognitions!) {
          List<Widget> keypointChildren = [];
          for (Keypoint keypoint in recognition.keypoints!) {
            keypointChildren.add(
              RenderKeypoints(
                keypoint: keypoint,
                imageWidthScale: widthScale,
                imageHeightScale: heightScale,
              ),
            );
          }
          stackChildren.addAll(keypointChildren);
        }
      }

      stackChildren.addAll(_recognitions!.map(
        (recognition) {
          return RenderBoxes(
            imageWidthScale: widthScale,
            imageHeightScale: heightScale,
            recognition: recognition,
          );
        },
      ).toList());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter D2Go'),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Expanded(
            child: Stack(
              children: stackChildren,
            ),
          ),
          const SizedBox(height: 48),
          MyButton(
            onPressed: !_isLiveModeOn ? detect : null,
            text: 'Detect',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MyButton(
                    onPressed: () => setState(
                          () {
                            _recognitions = null;
                            if (_selectedImage == null) {
                              _index != 2 ? _index += 1 : _index = 0;
                            } else {
                              _selectedImage = null;
                            }
                          },
                        ),
                    text: 'Test Image\n${_index + 1}/${_imageList.length}'),
                MyButton(
                    onPressed: () async {
                      final XFile? pickedFile =
                          await _picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile == null) return;
                      setState(
                        () {
                          _recognitions = null;
                          _selectedImage = File(pickedFile.path);
                        },
                      );
                    },
                    text: 'Select'),
                MyButton(
                    onPressed: () async {
                      _isLiveModeOn
                          ? await controller!.stopImageStream()
                          : await live();
                      setState(
                        () {
                          _isLiveModeOn = !_isLiveModeOn;
                          _recognitions = null;
                          _selectedImage = null;
                        },
                      );
                    },
                    text: 'Live'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MyButton extends StatelessWidget {
  const MyButton({Key? key, required this.onPressed, required this.text})
      : super(key: key);

  final VoidCallback? onPressed;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 42,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
          ),
        ),
        style: ElevatedButton.styleFrom(
          primary: Colors.grey[300],
          elevation: 0,
        ),
      ),
    );
  }
}

class RenderBoxes extends StatelessWidget {
  const RenderBoxes({
    Key? key,
    required this.recognition,
    required this.imageWidthScale,
    required this.imageHeightScale,
  }) : super(key: key);

  final RecognitionModel recognition;
  final double imageWidthScale;
  final double imageHeightScale;

  @override
  Widget build(BuildContext context) {
    final left = recognition.rect.left * imageWidthScale;
    final top = recognition.rect.top * imageHeightScale;
    final right = recognition.rect.right * imageWidthScale;
    final bottom = recognition.rect.bottom * imageHeightScale;
    return Positioned(
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(8.0)),
          border: Border.all(
            color: Colors.yellow,
            width: 2,
          ),
        ),
        child: Text(
          "${recognition.detectedClass} ${(recognition.confidenceInClass * 100).toStringAsFixed(0)}%",
          style: TextStyle(
            background: Paint()..color = Colors.yellow,
            color: Colors.black,
            fontSize: 15.0,
          ),
        ),
      ),
    );
  }
}

class RenderSegments extends StatelessWidget {
  const RenderSegments({
    Key? key,
    required this.recognition,
    required this.imageWidthScale,
    required this.imageHeightScale,
  }) : super(key: key);

  final RecognitionModel recognition;
  final double imageWidthScale;
  final double imageHeightScale;

  @override
  Widget build(BuildContext context) {
    final left = recognition.rect.left * imageWidthScale;
    final top = recognition.rect.top * imageHeightScale;
    final right = recognition.rect.right * imageWidthScale;
    final bottom = recognition.rect.bottom * imageHeightScale;
    final mask = recognition.mask!;
    return Positioned(
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
      child: Image.memory(
        mask,
        fit: BoxFit.fill,
      ),
    );
  }
}

class RenderKeypoints extends StatelessWidget {
  const RenderKeypoints({
    Key? key,
    required this.keypoint,
    required this.imageWidthScale,
    required this.imageHeightScale,
  }) : super(key: key);

  final Keypoint keypoint;
  final double imageWidthScale;
  final double imageHeightScale;

  @override
  Widget build(BuildContext context) {
    final x = keypoint.x * imageWidthScale;
    final y = keypoint.y * imageHeightScale;
    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class RecognitionModel {
  RecognitionModel(
    this.rect,
    this.mask,
    this.keypoints,
    this.confidenceInClass,
    this.detectedClass,
  );
  Rectangle rect;
  Uint8List? mask;
  List<Keypoint>? keypoints;
  double confidenceInClass;
  String detectedClass;
}

class Rectangle {
  Rectangle(this.left, this.top, this.right, this.bottom);
  double left;
  double top;
  double right;
  double bottom;
}

class Keypoint {
  Keypoint(this.x, this.y);
  double x;
  double y;
}
