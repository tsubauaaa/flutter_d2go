import Flutter
import UIKit

public class SwiftFlutterD2goPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "tsubauaaa.com/flutter_d2go", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterD2goPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args:Dictionary<String, AnyObject> = call.arguments as! Dictionary<String, AnyObject>;
    if ("loadModel" == call.method) {
            print(args)
            result("iOS " + UIDevice.current.systemVersion)
    } else if ("predictImage" == call.method) {
        result(predictImage(call:call))
    }

    result("iOS " + UIDevice.current.systemVersion)
  }

    private func loadModel(call: FlutterMethodCall) {
//         lazy var module:  = {
//             if let filePath = Bundle.main.path(forResource: "d2go_optimized", ofType: "ptl"),
//                 let module = InferenceModule(fileAtPath: filePath) {
//                 return module
//             } else {
//                 fatalError("Failed to load model!")
//             }
//         }()
    }

    private func predictImage(call: FlutterMethodCall) -> [[String: Any]] {
        return         [
            [
              "rect": [
                "left": 74.65713500976562,
                "top": 76.94147491455078,
                "right": 350.64324951171875,
                "bottom": 323.0279846191406
              ],
              "confidenceInClass": 0.985002338886261,
              "detectedClass": "bicycle"
            ]
        ]

    }
}
