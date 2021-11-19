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
import java.util.Random;

import androidx.annotation.NonNull;

import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;


/**
 * <p>FlutterD2goPlugin</>
 *
 * This class is a class that infers using the d2go model
 */
public class FlutterD2goPlugin implements FlutterPlugin, MethodCallHandler {

  // Dealing with torchvision options problem
  // @see <a href="https://discuss.pytorch.org/t/torchvision-ops-nms-on-android-mobile/81017/6">https://discuss.pytorch.org/t/torchvision-ops-nms-on-android-mobile/81017/6</a>
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
  public void onMethodCall(MethodCall call, @NonNull final Result result) {
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
   * @param call [image] List of bytes image to be inferred
   *             [width] width of image when inferring to d2go model
   *             [height] height of image when inferring to d2go model
   *             [mean] Average value used in Normalize
   *             [std] Standard deviation used in Normalize
   *             [minScore] threshold
   * @param result If successful, return [outputs] with result.success
   *               The format of [outputs] is List of { "rect": { "left": Float, "top": Float, "right": Float, "bottom": Float },
   *               "mask": [byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte ...],
   *               "keypoints": [[Float, Float], [Float, Float], [Float, Float], [Float, Float], ...],
   *               "confidenceInClass": Float, "detectedClass": String }. "mask" and "keypoints" do not exist on some models.
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
      final boolean hasMasks = map.containsKey("masks");
      final boolean hasKeypoints = map.containsKey("keypoints");

      final Tensor boxesTensor = map.get("boxes").toTensor();
      final Tensor scoresTensor = map.get("scores").toTensor();
      final Tensor labelsTensor = map.get("labels").toTensor();

      // [boxesData] has 4 sets of left, top, right and bottom per instance
      // boxesData = [left1, top1, right1, bottom1, left2, top2, right2, bottom2, left3, top3, ..., bottomN]
      final float[] boxesData = boxesTensor.getDataAsFloatArray();
      final float[] scoresData = scoresTensor.getDataAsFloatArray();
      final long[] labelsData = labelsTensor.getDataAsLongArray();

      // Inferred number of all instances
      final int totalInstances = scoresData.length;

      List<Map<String, Object>> outputs = new ArrayList<>();
      for (int i = 0; i < totalInstances; i++) {
        if (scoresData[i] < minScore)
          continue;
        Map<String, Object> output = new LinkedHashMap<>();
        Map<String, Float> rect = new LinkedHashMap<>();

        // Set rect to a value that matches the original image
        rect.put("left", boxesData[4 * i] * imageWidthScale);
        rect.put("top", boxesData[4 * i + 1] * imageHeightScale);
        rect.put("right", boxesData[4 * i + 2] * imageWidthScale);
        rect.put("bottom", boxesData[4 * i + 3] * imageHeightScale);

        output.put("rect", rect);

        if (hasMasks) {
          // [rawMaskData] is the instance mask data in the bounding box and has a size of 28 * 28
          // @see <a href="https://github.com/facebookresearch/detectron2/discussions/3393">https://github.com/facebookresearch/detectron2/discussions/3393</a>
          final Tensor rawMasksTensor = map.get("masks").toTensor();
          final float[] rawMasksData = rawMasksTensor.getDataAsFloatArray();
          output.put("mask", getMaskBytes(rawMasksData, i));
        }

        if (hasKeypoints) {
          // keypointsData is in a format with 17 * (x, y, score) for each instance. (coco estimates have 17 keypoints)
          final Tensor keypointsTensor = map.get("keypoints").toTensor();
          final float[] keypointsData = keypointsTensor.getDataAsFloatArray();
          output.put("keypoints", getKeypointsList(keypointsData, i, bitmap.getWidth(), bitmap.getHeight()));
        }

        output.put("confidenceInClass", scoresData[i]);
        output.put("detectedClass", classes.get((int)(labelsData[i] - 1)));

        outputs.add(output);
      }

      result.success(outputs);
    }
  }


  /**
   * <p>Converts mask data to byte array of bitmap image and returns</>
   *
   * @param rawMasksData Mask data included in the inference result.
   * @param instanceIndex Inferred instance number
   * @return bitmap image byte array
   */
  private byte[] getMaskBytes(float[] rawMasksData, int instanceIndex) {
    // rawMasksData contains 28 * 28 mask data for the number of instances
    final float[] rawMask = Arrays.copyOfRange(rawMasksData, instanceIndex * rawMaskWidth * rawMaskWidth, (instanceIndex + 1) * rawMaskWidth * rawMaskWidth);

    // color channel (RGBA)
    final int ch = 4;

    final byte[] pixels = new byte[rawMaskWidth * rawMaskWidth * ch];

    // Change the color of the mask image for each instance
    Random rand = new Random();
    final int r = rand.nextInt(255);
    final int g = rand.nextInt(255);
    final int b = rand.nextInt(255);


    // The pixel of the bitmap image to be used is saved from bottom to top in the vertical direction.
    // @see <a href="https://en.wikipedia.org/wiki/BMP_file_format#Pixel_array_(bitmap_data)">https://en.wikipedia.org/wiki/BMP_file_format#Pixel_array_(bitmap_data)</a>
    int offset = 0;
    for (int i = rawMask.length; i >= rawMaskWidth; i -= rawMaskWidth) {
      int end = i - 1, start = i - rawMaskWidth;
      for (int j = start; j <= end; j++) {
        // Since the masks output of the d2go model assumes 28 * 28 raw data, the mask range is 0.5 or more.
        // @see <a href="https://detectron2.readthedocs.io/en/latest/tutorials/deployment.html#use-the-model-in-c-python">https://detectron2.readthedocs.io/en/latest/tutorials/deployment.html#use-the-model-in-c-python</a>
        final int a = rawMask[j] < 0.5 ? 0 : 128;
        pixels[ch * offset] = (byte) (r & 0xff);
        pixels[ch * offset + 1] = (byte) (g & 0xff);
        pixels[ch * offset + 2] = (byte) (b & 0xff);
        pixels[ch * offset + 3] = (byte) (a & 0xff);
        offset += 1;
      }
    }

    // Concatenate pixels and bitmap headers
    final byte[] bmpFileHeader = BitmapHeader.getBMPFileHeader();
    final byte[] bmpInfoHeader = BitmapHeader.getBMPInfoHeader(rawMaskWidth, rawMaskWidth);
    byte[] maskBytes = new byte[bmpFileHeader.length + bmpInfoHeader.length + pixels.length];

    System.arraycopy(bmpFileHeader, 0, maskBytes, 0, bmpFileHeader.length);
    System.arraycopy(bmpInfoHeader, 0, maskBytes, bmpFileHeader.length, bmpInfoHeader.length);
    System.arraycopy(pixels, 0, maskBytes, bmpFileHeader.length + bmpInfoHeader.length, pixels.length);

    return maskBytes;
  }


  /**
   * <p>Return 17 keypoints (x, y) for each instance as a list</>
   * 
   * @param keypointsData is in a format with 17 * (x, y, score) for each instance
   * @param instanceIndex Inferred instance number
   * @param imageWidth Image width size to infer
   * @param imageHeight Image height size to infer
   * @return Returns a list of 17 keypoints (x, y)
   */
  @NonNull
  private List<float[]> getKeypointsList(float[] keypointsData, int instanceIndex, int imageWidth, int imageHeight) {
    // coco estimates have 17 keypoints
    final int numOfKeypoints = 17;
    final float[] keypoints = Arrays.copyOfRange(keypointsData, instanceIndex * 3 * numOfKeypoints, (instanceIndex + 1) * 3 * numOfKeypoints);
    List<float[]> keypointsList = new ArrayList<>();
    for (int i = 0; i < keypoints.length; i = 3 + i) {
      // Since the d2go model output assumes that the input image size is 320 * 320, match the scale with the image to be inferred
      final float x = keypoints[i] * imageWidth / 320;
      final float y = keypoints[i+1] * imageHeight / 320;
      final float[] keypoint = {x, y};
      keypointsList.add(keypoint);
    }
    return keypointsList;
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
