package com.tsubauaaa.flutter_d2go;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodChannel;

/**
 * <p>FlutterD2goPlugin</>
 *
 * A class that sets MethodCallHandler that performs D2Go inference processing in flutter plugin MethodChannel.
 */
public class FlutterD2goPlugin implements FlutterPlugin {

  private MethodChannel channel;
  private FlutterD2goHandler handler;
  private static final String CHANNEL_NAME = "tsubauaaa.com/flutter_d2go";

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    final MethodChannel channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(),
            CHANNEL_NAME);
    handler = new FlutterD2goHandler(flutterPluginBinding.getApplicationContext());
    channel.setMethodCallHandler(handler);
  }


  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    channel = null;
    handler = null;
  }
}
