[![pub package](https://img.shields.io/pub/v/flutter_d2go.svg)](https://pub.dartlang.org/packages/flutter_d2go)

# flutter_d2go

Flutter Plugin inferring using [d2go](https://github.com/facebookresearch/d2go), the mobile model of [detectron2](https://github.com/facebookresearch/detectron2). Currently only Android works.

## Features

- Providing class and boundary value box by object detection
- Providing mask data by instance segmentation
- Providing keypoints by keypoint estimation

## Preview

- Object detection and instance segmentation

  ![](images/preview.gif)

- Keypoints estimation

  ![](images/keypoints.png)

## Installation

Add flutter_d2go to your `pubspec.yaml`.

Put the d2go model and class file in the assets directory.

```yaml
assets:
  - assets/models/d2go.pt
  - assets/models/classes.txt
```

## Usage

### 1. Load model and classes

The model is in Pytorch format.  
The format of classes file is [here](example/assets/models/classes.txt).

```dart
await FlutterD2go.loadModel(
    modelPath: 'assets/models/d2go.pt',     // required
    labelPath: 'assets/models/classes.txt', // required
);
```

### 2. Get predictions

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
`mask` and `keypoints` depend on whether the d2go model has mask and keypoints.

`mask` will be a Uint8List of bitmap images.  
`keypoints` will be a list of 17 (x, y).

```dart
[
  {
    "rect": {
      "left": 74.65713500976562,
      "top": 76.94147491455078,
      "right": 350.64324951171875,
      "bottom": 323.0279846191406
    },
    "mask": [66, 77, 122, 0, 0, 0, 0, 0, 0, 0, 122, ...],
    "keypoints": [[117.14504, 77.277405], [122.74037, 73.53044], [105.95437, 73.53044], ...],
    "confidenceInClass": 0.985002338886261,
    "detectedClass": "bicycle"
  }, // For each instance
...
]
```
