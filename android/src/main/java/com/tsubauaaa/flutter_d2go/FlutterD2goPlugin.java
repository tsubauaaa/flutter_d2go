package com.tsubauaaa.flutter_d2go;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

import com.facebook.soloader.nativeloader.NativeLoader;
import com.facebook.soloader.nativeloader.SystemDelegate;

import org.pytorch.IValue;
import org.pytorch.Module;
import org.pytorch.Tensor;
import org.pytorch.torchvision.TensorImageUtils;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.nio.FloatBuffer;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import androidx.annotation.NonNull;

import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

/** FlutterD2goPlugin */
public class FlutterD2goPlugin implements FlutterPlugin, MethodCallHandler {

  // Dealing with torchvision options problem
  // Refer to <a href="https://discuss.pytorch.org/t/torchvision-ops-nms-on-android-mobile/81017/6">https://discuss.pytorch.org/t/torchvision-ops-nms-on-android-mobile/81017/6</a>
  static {
    if (!NativeLoader.isInitialized()) {
      NativeLoader.init(new SystemDelegate());
    }
    NativeLoader.loadLibrary("pytorch_jni");
    NativeLoader.loadLibrary("torchvision_ops");
  }

  Module module;
  ArrayList<String> classes = new ArrayList<>();

  private static final String CHANNEL_NAME = "tsubauaaa.com/flutter_d2go";

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    final MethodChannel channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(),
            CHANNEL_NAME);
    channel.setMethodCallHandler(new FlutterD2goPlugin());
  }


  @SuppressWarnings("deprecation")
  public static void registerWith(@NonNull PluginRegistry.Registrar register) {
    final MethodChannel channel = new MethodChannel(register.messenger(), CHANNEL_NAME);
    channel.setMethodCallHandler(new FlutterD2goPlugin());
  }

  @Override
  public void onMethodCall(MethodCall call, final Result result) {
    switch (call.method) {
      case "loadModel":
        loadModel(call, result);
        break;

      case "predictImage":
        predictImage(call, result);
        break;

      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * <p>Load the d2go model and get org.pytorch.Module in [module]. Read the classes file and add classes to [classes]</>
   *
   * @param call absModelPath The path of the D2Go model loaded by the load of org.pytorch.Module
   *             assetModelPath Flutter asset path of D2Go model used to display log when model or classes loading fails
   *             absLabelPath The path of the file where the class is written
   *             assetLabelPath Flutter asset path of classes file used to display log when model or classes loading fails
   * @param result If successful, return the string "success" in result.success
   */
  private void loadModel(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    try {
      classes.clear();
      String absModelPath = call.argument("absModelPath");
      module = Module.load(absModelPath);

      String absLabelPath = call.argument("absLabelPath");
      File labels = new File(absLabelPath);
      BufferedReader br = new BufferedReader(new FileReader(labels));
      String line;
      while ((line = br.readLine()) != null) {
        classes.add(line);
      }
      result.success("success");
    } catch (Exception e) {
      String assetModelPath = call.argument("assetModelPath");
      String assetLabelPath = call.argument("assetLabelPath");
      Log.e("flutter_d2go", assetModelPath + " or " + assetLabelPath + " are not a proper model or label", e);
    }
  }

  /**
   * <p>Infer using the D2Go model, format the result and return it</>
   *
   * @param call [image] List of bytes image to be inferred<Bytes>
   *             [width] width length of image
   *             [height] height length of image
   *             [mean] Average value used in Normalize
   *             [std] Standard deviation used in Normalize
   *             [minScore] threshold
   * @param result If successful, return [outputs] with result.success
   *               The format of [outputs] is List of { "rect": { "left": Float, "top": Float, "right": Float, "bottom": Float },
   *               "confidenceInClass": Float, "detectedClass": String }
   */
  private void predictImage(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    Bitmap bitmap;
    float [] mean;
    float [] std;
    double minScore;
    int inputWidth;
    int inputHeight;
    float imageWidthScale, imageHeightScale;


    byte[] imageBytes = call.argument("image");


    // meanとstdをfloat変換
    ArrayList<Double> _mean = call.argument("mean");
    mean = toFloatPrimitives(_mean.toArray(new Double[0]));
    ArrayList<Double> _std = call.argument("std");
    std = toFloatPrimitives(_std.toArray(new Double[0]));

    minScore = call.argument("minScore");

    inputWidth = call.argument("width");
    inputHeight = call.argument("height");

    // bitmap objectをimageから作成してサイズを復元
    bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.length);
    Bitmap resizedBitmap = Bitmap.createScaledBitmap(bitmap, inputWidth, inputHeight, true);

    imageWidthScale = (float)bitmap.getWidth() / inputWidth;
    imageHeightScale = (float)bitmap.getHeight() / inputHeight;

    final FloatBuffer floatBuffer = Tensor.allocateFloatBuffer(3 * resizedBitmap.getWidth() * resizedBitmap.getHeight());
    TensorImageUtils.bitmapToFloatBuffer(resizedBitmap,0,0, resizedBitmap.getWidth(), resizedBitmap.getHeight(), mean, std, floatBuffer, 0);
    final Tensor inputTensor = Tensor.fromBlob(floatBuffer, new long[] {3, resizedBitmap.getHeight(), resizedBitmap.getWidth()});

    // 推論
    IValue[] outputTuple = module.forward(IValue.listFrom(inputTensor)).toTuple();

    final Map<String, IValue> map = outputTuple[1].toList()[0].toDictStringKey();

    float[] boxesData;
    float[] scoresData;
    long[] labelsData;

    // 推論結果整形
    if (map.containsKey("boxes")) {
      final Tensor boxesTensor = map.get("boxes").toTensor();
      final Tensor scoresTensor = map.get("scores").toTensor();
      final Tensor labelsTensor = map.get("labels").toTensor();
      boxesData = boxesTensor.getDataAsFloatArray();
      scoresData = scoresTensor.getDataAsFloatArray();
      labelsData = labelsTensor.getDataAsLongArray();

      final int totalInstances = scoresData.length;

      // 全インスタンス数 x outputカラム(left, top, right, bottom, score, label)
      List<Map<String, Object>> outputs = new ArrayList<>();
      for (int i = 0; i < totalInstances; i++) {
        if (scoresData[i] < minScore)
          continue;
        Map<String, Object> output = new LinkedHashMap<>();
        Map<String, Float> rect = new LinkedHashMap<>();
        rect.put("left", boxesData[4 * i + 0] * imageWidthScale);
        rect.put("top", boxesData[4 * i + 1] * imageHeightScale);
        rect.put("right", boxesData[4 * i + 2] * imageWidthScale);
        rect.put("bottom", boxesData[4 * i + 3] * imageHeightScale);

        output.put("rect", rect);
        output.put("confidenceInClass", scoresData[i]);
        output.put("detectedClass", classes.get((int)(labelsData[i] - 1)));

        outputs.add(output);
      }
      result.success(outputs);
    }
  }

  /**
   * <p>Convert Normalize parameter to Float</>
   *
   * @param objects Double[] before conversion
   * @return primitives Float[] after conversion
   */
  private static float[] toFloatPrimitives(Double[] objects) {
    float[] primitives = new float[objects.length];
    for (int i = 0; i < objects.length; i++) {
      primitives[i] = objects[i].floatValue();
    }
    return  primitives;
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
  }

}
