import Flutter
import UIKit

public class SwiftFlutterD2goPlugin: NSObject, FlutterPlugin {

    var module: TorchModule?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "tsubauaaa.com/flutter_d2go", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterD2goPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:Dictionary<String, AnyObject> = call.arguments as! Dictionary<String, AnyObject>;
        if ("loadModel" == call.method) {
            print(args)
            result(loadModel(args: args))
        } else if ("predictImage" == call.method) {
            result(predictImage(call: call))
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func loadModel(args: Dictionary<String, AnyObject>) -> String {
        let absModelPath = args["absModelPath"] as! String
        module = TorchModule(fileAtPath: absModelPath)
        print("Model Loaded")
        return "success"
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
