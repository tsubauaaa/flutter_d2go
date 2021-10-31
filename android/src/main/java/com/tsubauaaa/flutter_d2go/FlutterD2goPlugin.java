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
import java.util.Arrays;
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

  final int rawMaskWidth = 28;

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


  private byte[] addBMPImageHeader(int size)
  {
    byte[]buffer = new byte[14];
    // BM as file type
    buffer[0] = 0x42;
    buffer[1] = 0x4D;

    // Header size
    buffer[2] = (byte) (122 & 0xff);
    buffer[3] = 0x00;
    buffer[4] = 0x00;
    buffer[5] = 0x00;

    // Hot spot
    buffer[6] = 0x00;
    buffer[7] = 0x00;
    buffer[8] = 0x00;
    buffer[9] = 0x00;

    // Offset 122
    buffer[10] = (byte) (122 & 0xff);
    buffer[11] = 0x00;
    buffer[12] = 0x00;
    buffer[13] = 0x00;
    return buffer;
  }

  private byte[] addBMPImageInfoHeader(int w, int h) {
    byte[] buffer = new byte[108];

    // Header size
    buffer[0] = (byte) (108 & 0xff);
    buffer[1] = 0x00;
    buffer[2] = 0x00;
    buffer[3] = 0x00;

    // Width of bitmap
    buffer[4] = (byte) (w & 0xff);
    buffer[5] = 0x00;
    buffer[6] = 0x00;
    buffer[7] = 0x00;

    // Height of bitmap
    buffer[8] = (byte) (h & 0xff);
    buffer[9] = 0x00;
    buffer[10] = 0x00;
    buffer[11] = 0x00;

    // 1 as plane number
    buffer[12] = 0x01;
    buffer[13] = 0x00;

    // Bit per pixel
    buffer[14] = (byte) (32 & 0xff);
    buffer[15] = 0x00;

    // Compressed format
    buffer[16] = (byte) (3 & 0xff);
    buffer[17] = 0x00;
    buffer[18] = 0x00;
    buffer[19] = 0x00;

    // Image data size
    buffer[20] = (byte) (64 & 0xff);
    buffer[21] = (byte) (12 & 0xff);
    buffer[22] = 0x00;
    buffer[23] = 0x00;

    // Horizontal resolution
    buffer[24] = 0x00;
    buffer[25] = 0x00;
    buffer[26] = 0x00;
    buffer[27] = 0x00;

    // Vertical resolution
    buffer[28] = 0x00;
    buffer[29] = 0x00;
    buffer[30] = 0x00;
    buffer[31] = 0x00;

    // Number of colors to use
    buffer[32] = 0x00;
    buffer[33] = 0x00;
    buffer[34] = 0x00;
    buffer[35] = 0x00;

    // Important number of colors
    buffer[36] = 0x00;
    buffer[37] = 0x00;
    buffer[38] = 0x00;
    buffer[39] = 0x00;

    // Red component color mask
    buffer[40] = (byte) (255 & 0xff);
    buffer[41] = 0x00;
    buffer[42] = 0x00;
    buffer[43] = 0x00;

    // Green component color mask
    buffer[44] = 0x00;
    buffer[45] = (byte) (255 & 0xff);
    buffer[46] = 0x00;
    buffer[47] = 0x00;

    // Blue component color mask
    buffer[48] = 0x00;
    buffer[49] = 0x00;
    buffer[50] = (byte) (255 & 0xff);
    buffer[51] = 0x00;

    // Alpha component color mask
    buffer[52] = 0x00;
    buffer[53] = 0x00;
    buffer[54] = 0x00;
    buffer[55] = (byte) (255 & 0xff);

    // CIEXYZTRIPLE structure
    buffer[56] = 0x00;
    buffer[57] = 0x00;
    buffer[58] = 0x00;
    buffer[59] = 0x00;
    buffer[60] = 0x00;
    buffer[61] = 0x00;
    buffer[62] = 0x00;
    buffer[63] = 0x00;
    buffer[64] = 0x00;
    buffer[65] = 0x00;
    buffer[66] = 0x00;
    buffer[67] = 0x00;
    buffer[68] = 0x00;
    buffer[69] = 0x00;
    buffer[70] = 0x00;
    buffer[71] = 0x00;
    buffer[72] = 0x00;
    buffer[73] = 0x00;
    buffer[74] = 0x00;
    buffer[75] = 0x00;
    buffer[76] = 0x00;
    buffer[77] = 0x00;
    buffer[78] = 0x00;
    buffer[79] = 0x00;
    buffer[80] = 0x00;
    buffer[81] = 0x00;
    buffer[82] = 0x00;
    buffer[83] = 0x00;
    buffer[84] = 0x00;
    buffer[85] = 0x00;
    buffer[86] = 0x00;
    buffer[87] = 0x00;
    buffer[88] = 0x00;
    buffer[89] = 0x00;
    buffer[90] = 0x00;
    buffer[91] = 0x00;

    // Gamma value of red component
    buffer[92] = 0x00;
    buffer[93] = 0x00;
    buffer[94] = 0x00;
    buffer[95] = 0x00;

    // Gamma value of green component
    buffer[96] = 0x00;
    buffer[97] = 0x00;
    buffer[98] = 0x00;
    buffer[99] = 0x00;

    // Gamma value of blue component
    buffer[100] = 0x00;
    buffer[101] = 0x00;
    buffer[102] = 0x00;
    buffer[103] = 0x00;

    // Gamma value of alpha component
    buffer[104] = 0x00;
    buffer[105] = 0x00;
    buffer[106] = 0x00;
    buffer[107] = 0x00;
    return buffer;
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


    // Convert [mean] and [std] to float
    ArrayList<Double> _mean = call.argument("mean");
    mean = toFloatPrimitives(_mean.toArray(new Double[0]));
    ArrayList<Double> _std = call.argument("std");
    std = toFloatPrimitives(_std.toArray(new Double[0]));

    minScore = call.argument("minScore");

    inputWidth = call.argument("width");
    inputHeight = call.argument("height");

    // Create a bitmap object from image and fit the size to the model
    bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.length);
    Bitmap resizedBitmap = Bitmap.createScaledBitmap(bitmap, inputWidth, inputHeight, true);

    // Get the increase / decrease ratio between the bitmap and the original image
    imageWidthScale = (float)bitmap.getWidth() / inputWidth;
    imageHeightScale = (float)bitmap.getHeight() / inputHeight;


    // Create a dtype torch.float32 tensor to input to the model with [inputWidth], [inputHeight] size and bitmap data
    final FloatBuffer floatBuffer = Tensor.allocateFloatBuffer(3 * resizedBitmap.getWidth() * resizedBitmap.getHeight());
    TensorImageUtils.bitmapToFloatBuffer(resizedBitmap,0,0, resizedBitmap.getWidth(), resizedBitmap.getHeight(), mean, std, floatBuffer, 0);
    final Tensor inputTensor = Tensor.fromBlob(floatBuffer, new long[] {3, resizedBitmap.getHeight(), resizedBitmap.getWidth()});

    // inference
    IValue[] outputTuple = module.forward(IValue.listFrom(inputTensor)).toTuple();

    final Map<String, IValue> map = outputTuple[1].toList()[0].toDictStringKey();

    // Formatting inference results
    if (map.containsKey("boxes")) {
      final Tensor boxesTensor = map.get("boxes").toTensor();
      final Tensor scoresTensor = map.get("scores").toTensor();
      final Tensor labelsTensor = map.get("labels").toTensor();
      final Tensor rawMasksTensor = map.containsKey("masks") ? map.get("masks").toTensor() : null;

      // [boxesData] has 4 sets of left, top, right and bottom per instance
      // boxesData = [left1, top1, right1, bottom1, left2, top2, right2, bottom2, left3, top3, ..., bottomN]
      final float[] boxesData = boxesTensor.getDataAsFloatArray();
      final float[] scoresData = scoresTensor.getDataAsFloatArray();
      final long[] labelsData = labelsTensor.getDataAsLongArray();
      final float[] rawMasksData = rawMasksTensor != null ?  rawMasksTensor.getDataAsFloatArray() : null;

      // Inferred number of all instances
      final int totalInstances = scoresData.length;

      List<Map<String, Object>> outputs = new ArrayList<>();
      for (int i = 0; i < totalInstances; i++) {
        if (scoresData[i] < minScore)
          continue;
        Map<String, Object> output = new LinkedHashMap<>();
        Map<String, Float> rect = new LinkedHashMap<>();

        // Set rect to a value that matches the original image
        rect.put("left", boxesData[4 * i + 0] * imageWidthScale);
        rect.put("top", boxesData[4 * i + 1] * imageHeightScale);
        rect.put("right", boxesData[4 * i + 2] * imageWidthScale);
        rect.put("bottom", boxesData[4 * i + 3] * imageHeightScale);

        output.put("rect", rect);

        if (rawMasksData != null) {
          output.put("mask", getMaskBytes(rawMasksData, i));
        }

        output.put("confidenceInClass", scoresData[i]);
        output.put("detectedClass", classes.get((int)(labelsData[i] - 1)));

        outputs.add(output);
      }
      result.success(outputs);
    }
  }

  private byte[] getMaskBytes(float[] rawMasksData, int instanceIndex) {
    final float[] rawMask = Arrays.copyOfRange(rawMasksData, instanceIndex * rawMaskWidth * rawMaskWidth, (instanceIndex + 1) * rawMaskWidth * rawMaskWidth);
    final int ch = 4;
    final byte[] pixels = new byte[rawMaskWidth * rawMaskWidth * ch];
    
    int offset = 0;
    for (int j = rawMask.length; j >= rawMaskWidth; j -= rawMaskWidth) {
      int end = j - 1, start = j - rawMaskWidth;
      for (int k = start; k <= end; k++) {
        int r;
        int g;
        int b;
        int a;
        if (rawMask[k] < 0.5) {
          r = 0;
          g = 0;
          b = 0;
          a = 0;
        } else {
          r = 255;
          g = 0;
          b = 0;
          a = 128;
        }
        pixels[ch * offset + 0] = (byte) (r & 0xff);
        pixels[ch * offset + 1] = (byte) (g & 0xff);
        pixels[ch * offset + 2] = (byte) (b & 0xff);
        pixels[ch * offset + 3] = (byte) (a & 0xff);
        offset += 1;
      }
    }
    final byte[] bmpHeader = addBMPImageHeader(pixels.length);
    final byte[] bmpInfo = addBMPImageInfoHeader(rawMaskWidth, rawMaskWidth);
    byte[] maskBytes = new byte[bmpHeader.length + bmpInfo.length + pixels.length];

    System.arraycopy(bmpHeader, 0, maskBytes, 0, bmpHeader.length);
    System.arraycopy(bmpInfo, 0, maskBytes, bmpHeader.length, bmpInfo.length);
    System.arraycopy(pixels, 0, maskBytes, bmpHeader.length + bmpInfo.length, pixels.length);

    return maskBytes;
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
