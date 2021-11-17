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
            print(args)
            result(predictImage(args: args))
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func loadModel(args: Dictionary<String, AnyObject>) -> String {
        let absModelPath = args["absModelPath"] as! String
        module = TorchModule(loadModel: absModelPath)
        print("Model Loaded")
        return "success"
    }

    private func predictImage(args: Dictionary<String, AnyObject>) -> [[String: Any]] {
        let data:FlutterStandardTypedData = args["image"] as! FlutterStandardTypedData
        let inputWidth = args["width"] as! Int
        let inputHeight:Int = args["height"] as! Int
        let image = UIImage(data: data.data)!
        let resizedImage = image.resized(to: CGSize(width: CGFloat(inputWidth), height: CGFloat(inputHeight)))
        guard var pixelBuffer = resizedImage.normalized() else {
                  return []
        }
        let imageWidthScale = image.size.width/Double(inputWidth)
        let imageHeightScale = image.size.height/Double(inputHeight)
        guard let outputs = self.module?.predictImage(&pixelBuffer, inputWidth: Int32(inputWidth), inputHeight: Int32(inputHeight), widthScale: imageWidthScale, heightScale: imageHeightScale) else {
            return []
        }
//        print(outputs)
        
        return outputs as! [Dictionary]
        
//        return         [
//            [
//              "rect": [
//                "left": 74.65713500976562,
//                "top": 76.94147491455078,
//                "right": 350.64324951171875,
//                "bottom": 323.0279846191406
//              ],
//              "confidenceInClass": 0.985002338886261,
//              "detectedClass": "bicycle"
//            ]
//        ]
    }
}
