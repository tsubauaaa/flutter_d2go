import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_d2go/flutter_d2go.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List? _recognitions;
  File? _selectedImage;
  final List<String> _imageList = ['test1.png', 'test2.jpeg', 'test3.png'];
  int _index = 0;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future loadModel() async {
    String modelPath = 'assets/models/d2go.pt';
    String labelPath = 'assets/models/classes.txt';
    try {
      FlutterD2go.loadModel(modelPath, labelPath);
      setState(() {});
    } on PlatformException {
      debugPrint('only supported for android and ios so far');
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    stackChildren.add(
      Positioned(
        child: _selectedImage == null
            ? Image.asset(
                'assets/images/${_imageList[_index]}',
                fit: BoxFit.fill,
              )
            : Image.file(_selectedImage!),
      ),
    );
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter D2Go'),
          backgroundColor: Colors.deepPurpleAccent,
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: stackChildren,
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
                            _index != 2 ? _index += 1 : _index = 0;
                          }),
                      text: 'Test Imag\n${_index + 1}/${_imageList.length}'),
                  MyButton(
                      onPressed: () async {
                        final XFile? pickedFile = await _picker.pickImage(
                            source: ImageSource.gallery);
                        if (pickedFile == null) return;
                        setState(() => _selectedImage = File(pickedFile.path));
                      },
                      text: 'Select'),
                  MyButton(onPressed: () {}, text: 'Live'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future detect() async {
    final image = _selectedImage ??
        await getImageFileFromAssets('assets/images/${_imageList[_index]}');
    var recognitionList = await FlutterD2go.getPredictionD2Go(image: image);
    debugPrint(recognitionList.toString());
    debugPrint(recognitionList!.length.toString());
    setState(() => _recognitions = recognitionList);
  }

  Future<File> getImageFileFromAssets(String path) async {
    final byteData = await rootBundle.load(path);
    final fileName = path.split('/').last;
    final file = File('${(await getTemporaryDirectory()).path}/$fileName');
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

    return file;
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
