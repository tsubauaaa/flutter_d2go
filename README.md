# flutter_d2go

Flutter Plugin inferring using [d2go](https://github.com/facebookresearch/d2go), the mobile model of [detectron2](). Currently only supports Android.

## Usage

### Installation

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

### import the library

```dart
import 'package:flutter_d2go/flutter_d2go.dart';
```

### Load model

```dart

```
