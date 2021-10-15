import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_d2go/flutter_d2go.dart';
import 'package:image_picker/image_picker.dart';

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
    List<String> imageList = ['test1.png', 'test2.jpeg', 'test3.png'];
    List<Widget> stackChildren = [];
    stackChildren.add(
      Positioned(
        child: Image.asset(
          'assets/images/${imageList[_index]}',
          fit: BoxFit.fill,
        ),
      ),
    );
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter D2Go'),
          backgroundColor: Colors.deepPurpleAccent,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 64, bottom: 32),
              child: Stack(
                children: stackChildren,
              ),
            ),
            MyButton(
              onPressed: runD2Go,
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
                      text: 'Test Imag\n${_index + 1}/${imageList.length}'),
                  MyButton(onPressed: () {}, text: 'Select'),
                  MyButton(onPressed: () {}, text: 'Live'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future runD2Go() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    var recognitionList =
        await FlutterD2go.getPredictionD2Go(image: File(pickedFile.path));
    debugPrint(recognitionList.toString());
    debugPrint(recognitionList!.length.toString());
    setState(() => _recognitions = recognitionList);
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
