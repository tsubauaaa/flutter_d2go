import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_d2go/flutter_d2go.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MaterialApp(home: MyApp()));
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

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future loadModel() async {
    String modelPath = 'assets/models/d2go.pt';
    String labelPath = 'assets/models/classes.txt';
    try {
      FlutterD2go.loadModel(modelPath, labelPath);
      setState(() {});
    } on PlatformException {
      debugPrint('only supported for android so far');
    }
  }

  Future detect() async {
    final image = _selectedImage ??
        await getImageFileFromAssets('assets/images/${_imageList[_index]}');
    final decodedImage = await decodeImageFromList(image.readAsBytesSync());
    _imageWidth = decodedImage.width;
    _imageHeight = decodedImage.height;
    final predictions = await FlutterD2go.getImagePrediction(image: image);
    List<RecognitionModel>? recognitions;
    if (predictions != null && predictions.isNotEmpty) {
      recognitions = predictions
          .map(
            (e) => RecognitionModel(
                Rectangle(
                  e['rect']['left'],
                  e['rect']['top'],
                  e['rect']['right'],
                  e['rect']['bottom'],
                ),
                e['confidenceInClass'],
                e['detectedClass']),
          )
          .toList();
    }
    setState(() => _recognitions = recognitions);
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

    if (_recognitions != null) {
      final aspectRatio = _imageHeight! / _imageWidth! * screenWidth;
      final widthScale = screenWidth / _imageWidth!;
      final heightScale = aspectRatio / _imageHeight!;
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
            onPressed: detect,
            text: 'Detect',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                MyButton(
                    onPressed: () => setState(() {
                          _recognitions = null;
                          if (_selectedImage == null) {
                            _index != 2 ? _index += 1 : _index = 0;
                          } else {
                            _selectedImage = null;
                          }
                        }),
                    text: 'Test Imag\n${_index + 1}/${_imageList.length}'),
                MyButton(
                    onPressed: () async {
                      final XFile? pickedFile =
                          await _picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile == null) return;
                      setState(() {
                        _recognitions = null;
                        _selectedImage = File(pickedFile.path);
                      });
                    },
                    text: 'Select'),
                MyButton(onPressed: () {}, text: 'Live'),
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

  final VoidCallback onPressed;
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
          style: const TextStyle(color: Colors.black),
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

class RecognitionModel {
  RecognitionModel(
    this.rect,
    this.confidenceInClass,
    this.detectedClass,
  );
  Rectangle rect;
  double confidenceInClass;
  String detectedClass;
}

class Rectangle {
  Rectangle(
    this.left,
    this.top,
    this.right,
    this.bottom,
  );
  double left;
  double top;
  double right;
  double bottom;
}