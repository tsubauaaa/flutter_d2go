import Flutter
import UIKit
import VideoToolbox


/// FlutterD2goPlugin
///
/// This class is a class that infers using the d2go model.
///
public class SwiftFlutterD2goPlugin: NSObject, FlutterPlugin {

    private var registrar: FlutterPluginRegistrar!
    var module: TorchModule?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "tsubauaaa.com/flutter_d2go", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterD2goPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.registrar = registrar
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:Dictionary<String, AnyObject> = call.arguments as! Dictionary<String, AnyObject>;
        if ("loadModel" == call.method) {
            result(loadModel(args: args))
        } else if ("predictImage" == call.method) {
            result(predictImage(args: args))
        } else if ("predictStreamImage" == call.method) {
            result(predictStreamImage(args: args))
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    
    /// Call Objective-C pytorch module to load model and classes.
    ///
    /// - Parameter args: `modelPath` is the path of the D2Go model loaded by the load of pytorch module.
    ///                   `labelPath` is the path of the file where the class is written.
    /// - Returns: If successful, return the string "success" in result.success.
    ///
    private func loadModel(args: Dictionary<String, AnyObject>) -> String {
        let modelPathInFlutterAsset = args["modelPath"] as! String
        let labelPathInFlutterAsset = args["labelPath"] as! String
        let modelKeyForAsset = registrar.lookupKey(forAsset: modelPathInFlutterAsset)
        let modelPathInAppDir = Bundle.main.path(forResource: modelKeyForAsset, ofType: nil)
        let lableKeyForAsset = registrar.lookupKey(forAsset: labelPathInFlutterAsset)
        let labelPathInAppDir = Bundle.main.path(forResource: lableKeyForAsset, ofType: nil)
        if (modelPathInAppDir != nil && labelPathInAppDir != nil) {
            module = TorchModule(loadModel: modelPathInAppDir!, labelPath: labelPathInAppDir!)
            print("Model Loaded")
            return "success"
        }
        return "Copy \(modelPathInFlutterAsset) or \(labelPathInFlutterAsset) failed."
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
        let inputWidth  = args["inputWidth"] as! Int
        let inputHeight = args["inputHeight"] as! Int
        let mean = args["mean"] as! [Float32]
        let std = args["std"] as! [Float32]
        
        // Create a UIImage object from FlutterStandardTypedData and fit the size to the model.
        let image = UIImage(data: data.data)!
        let resizedImage = image.resized(to: CGSize(width: CGFloat(inputWidth), height: CGFloat(inputHeight)))
        guard var pixelBuffer = resizedImage.normalized(mean: mean, std: std) else {
                  return []
        }
        let threshold = args["minScore"] as! Double
        
        // Call Objective-C's pytorch module.
        guard let outputs = self.module?.predictImage(&pixelBuffer, width: Int32(image.size.width), height: Int32(image.size.height), inputWidth: Int32(inputWidth), inputHeight: Int32(inputHeight), threshold: threshold) else {
            return []
        }
        
        return outputs as! [Dictionary<String, AnyObject>]
    }
    
    private func predictStreamImage(args: Dictionary<String, AnyObject>) -> [[String: Any]] {
        guard let imageBytesList = args["imageBytesList"] as? NSArray,
              let imageBytes = imageBytesList[0] as? FlutterStandardTypedData,
              let bytesPerRow = args["imageBytesPerRow"] as? Int else {
            return []
        }
        guard let width = args["width"] as? Int,
              let height = args["height"] as? Int,
              let inputWidth = args["inputWidth"] as? Int,
              let inputHeight = args["inputHeight"] as? Int else {
            return []
        }
        let mean = args["mean"] as! [Float32]
        let std = args["std"] as! [Float32]

        guard let image = createUIImageFromRawData(data: imageBytes.data,
                                                   imageWidth: width,
                                                   imageHeight: height,
                                                   bytes: bytesPerRow) else {
            return []
        }

        let resizedImage = image.resized(to: CGSize(width: CGFloat(inputWidth), height: CGFloat(inputHeight)))
        guard var pixelBuffer = resizedImage.normalized(mean: mean, std: std) else {
                  return []
        }
        let threshold = args["minScore"] as! Double

        // Call Objective-C's pytorch module.
        guard let outputs = self.module?.predictImage(&pixelBuffer, width: Int32(image.size.width),
                                                      height: Int32(image.size.height), inputWidth: Int32(inputWidth),
                                                      inputHeight: Int32(inputHeight), threshold: threshold) else {
            return []
        }

        return outputs as! [Dictionary<String, AnyObject>]
    }


    private func bytesToPixelBuffer(width: Int, height: Int, baseAddress: UnsafeMutableRawPointer, bytesPerRow: Int) -> CVBuffer? {
        var dstPixelBuffer: CVBuffer?
        CVPixelBufferCreateWithBytes(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, baseAddress, bytesPerRow,
                                     nil, nil, nil, &dstPixelBuffer)
        return dstPixelBuffer ?? nil
    }
    
    private func createImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        return cgImage
    }
    
    private func createUIImageFromRawData(data: Data, imageWidth: Int, imageHeight: Int, bytes: Int) -> UIImage? {
        data.withUnsafeBytes { rawBufferPointer in
            let rawPtr = rawBufferPointer.baseAddress!
            let address = UnsafeMutableRawPointer(mutating:rawPtr)
            guard let pxBuffer = bytesToPixelBuffer(width: imageWidth, height: imageHeight, baseAddress: address, bytesPerRow: bytes),
                  let copyImage = pxBuffer.copy(),
                  let cgiImage = createImage(from: copyImage) else {
                return nil
            }

            return UIImage(cgImage: cgiImage)
        }
    }
}
