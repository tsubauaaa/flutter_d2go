# flutter_d2go

Flutter Plugin inferring using [d2go](https://github.com/facebookresearch/d2go), the mobile model of [detectron2](https://github.com/facebookresearch/detectron2). Currently only Android works. Also, only object detection can be performed.

## Installation

Add flutter_d2go to your `pubspec.yaml`.

```yaml
dependencies:
  flutter_d2go: ^0.0.1
```

Put the d2go model and class file in the assets directory.

```yaml
assets:
  - assets/models/d2go.pt
  - assets/models/classes.txt
```

Run `flutter pub get`.

```bash
flutter pub get
```

## Import the library

```dart
import 'package:flutter_d2go/flutter_d2go.dart';
```

## Usage

### Load model and classes

```dart
await FlutterD2go.loadModel(
    modelPath: 'assets/models/d2go.pt',     // required
    labelPath: 'assets/models/classes.txt', // required
);
```

### Get predictions

```dart
List<Map<String, dynamic>> predictions = await FlutterD2go.getImagePrediction(
    image: image,           // required File(dart:io) image
    width: 320,             // defaults to 640
    height: 320,            // defaults to 640
    mean: [0.0, 0.0, 0.0],  // defaults to [0.0, 0.0, 0.0]
    std: [1.0, 1.0, 1.0],   // defaults to [1.0, 1.0, 1.0]
    minScore: 0.7,          // defaults to 0.5
);
```

#### Output format

`rect` is the scale of the original image.
`mask` depends on whether the d2go model has masks.
If there are masks, the mask will be a Uint8List of bitmap images.
```dart
[
  {
    rect: {
      left: 74.65713500976562,
      top: 76.94147491455078,
      right: 350.64324951171875,
      bottom: 323.0279846191406
    },
    mask: [66, 77, 122, 0, 0, 0, 0, 0, 0, 0, 122, ...]
    confidenceInClass: 0.985002338886261,
    detectedClass: bicycle
  },
  ...
]
```
