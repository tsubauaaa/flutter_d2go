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
    // ここに書いていけばよいのでは？
    if ("loadModel" == call.method) {
            print(args)
            result("iOS " + UIDevice.current.systemVersion)
    } else if ("predictImage" == call.method) {
        print(args)
        result("iOS " + UIDevice.current.systemVersion)
    }

    result("iOS " + UIDevice.current.systemVersion)
  }
}
