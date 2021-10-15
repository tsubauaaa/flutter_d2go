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
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('recognitions: ${_recognitions.toString()}\n'),
        ),
        floatingActionButton: FloatingActionButton(
          child: const Text('Inf'),
          onPressed: runD2Go,
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
