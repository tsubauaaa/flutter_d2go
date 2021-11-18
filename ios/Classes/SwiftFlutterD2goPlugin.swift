import Flutter
import UIKit


/// FlutterD2goPlugin
///
/// This class is a class that infers using the d2go model.
///
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
            result(loadModel(args: args))
        } else if ("predictImage" == call.method) {
            result(predictImage(args: args))
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    
    /// Call Objective-C pytorch module to load model and classes.
    ///
    /// - Parameter args: `absModelPath` is the path of the D2Go model loaded by the load of pytorch module.
    ///                   `absLabelPath` is the path of the file where the class is written.
    /// - Returns: If successful, return the string "success" in result.success.
    ///
    private func loadModel(args: Dictionary<String, AnyObject>) -> String {
        let absModelPath = args["absModelPath"] as! String
        let absLabelPath = args["absLabelPath"] as! String
        module = TorchModule(loadModel: absModelPath, absLabelPath: absLabelPath)
        print("Model Loaded")
        return "success"
    }

    
    /// Call Objective-C's pytorch module to receive the result.
    ///
    /// - Parameter args: `image` is a list of bytes image to be inferred.
    ///                   `width` is a  width of image when inferring to d2go model.
    ///                   `height` is a height of image when inferring to d2go model.
    ///                   `mean` is a average value used in normalize.
    ///                   `std` is a standard deviation used in normalize.
    ///                   `minScore` is a threshold.
    /// - Returns: The result of inference by the pytorch module of Objective-C.
    ///
    private func predictImage(args: Dictionary<String, AnyObject>) -> [[String: Any]] {
        let data:FlutterStandardTypedData = args["image"] as! FlutterStandardTypedData
        let inputWidth  = args["width"] as! Int
        let inputHeight = args["height"] as! Int
        let mean = args["mean"] as! [Float32]
        let std = args["std"] as! [Float32]
        let image = UIImage(data: data.data)!
        let resizedImage = image.resized(to: CGSize(width: CGFloat(inputWidth), height: CGFloat(inputHeight)))
        guard var pixelBuffer = resizedImage.normalized(mean: mean, std: std) else {
                  return []
        }
        let imageWidthScale = image.size.width/Double(inputWidth)
        let imageHeightScale = image.size.height/Double(inputHeight)
        let threshold = args["minScore"] as! Double
        guard let outputs = self.module?.predictImage(&pixelBuffer, inputWidth: Int32(inputWidth), inputHeight: Int32(inputHeight), widthScale: imageWidthScale, heightScale: imageHeightScale, threshold: threshold) else {
            return []
        }
        
        return outputs as! [Dictionary<String, AnyObject>]
    }
}
