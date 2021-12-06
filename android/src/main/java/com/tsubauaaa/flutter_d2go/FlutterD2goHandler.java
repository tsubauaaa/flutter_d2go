package com.tsubauaaa.flutter_d2go;

import android.content.Context;
import android.content.res.AssetManager;
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
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.FloatBuffer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

import androidx.annotation.NonNull;
import io.flutter.FlutterInjector;
import io.flutter.Log;
import io.flutter.embedding.engine.loader.FlutterLoader;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static java.util.Objects.requireNonNull;

/**
 * <p>FlutterD2goHandler</>
 *
 * Handler class that performs D2Go inference processing.
 */
public class FlutterD2goHandler implements MethodChannel.MethodCallHandler {
    private final Context context;

    // Dealing with torchvision options problem
    // @see <a href="https://discuss.pytorch.org/t/torchvision-ops-nms-on-android-mobile/81017/6">https://discuss.pytorch.org/t/torchvision-ops-nms-on-android-mobile/81017/6</a>
    static {
        if (!NativeLoader.isInitialized()) {
            NativeLoader.init(new SystemDelegate());
        }
        NativeLoader.loadLibrary("pytorch_jni");
        NativeLoader.loadLibrary("torchvision_ops");
    }

    private Module module;
    private final ArrayList<String> classes = new ArrayList<>();

    public FlutterD2goHandler(Context context) {
        this.context = context;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "loadModel":
                loadModel(call, result);
                break;
            case "predictImage":
                predictImage(call, result);
                break;
            case "predictStreamImage":
                predictStreamImage(call, result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }


    /**
     * <p>Load the d2go model and get org.pytorch.Module in [module]. Read the classes file and add classes to [classes]</>
     *
     * @param call modelPath The path of the D2Go model loaded by the load of org.pytorch.Module.
     *             labelPath The path of the file where the class is written.
     * @param result If successful, return the string "success" in result.success.
     */
    private void loadModel(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        classes.clear();
        String modelPathInFlutterAsset = call.argument("modelPath");
        String modelPathInAppDir = getFilePathInAppDir(modelPathInFlutterAsset);
        String labelPathInFlutterAsset = call.argument("labelPath");
        String labelPathInAppDir = getFilePathInAppDir(labelPathInFlutterAsset);
        File labels = new File(requireNonNull(labelPathInAppDir));
        try {
            module = Module.load(modelPathInAppDir);

            BufferedReader bufferedReader = new BufferedReader(new FileReader(labels));
            String line;
            while ((line = bufferedReader.readLine()) != null) {
                classes.add(line);
            }
            result.success("success");
        } catch (Exception e) {
            Log.e("flutter_d2go", modelPathInFlutterAsset + " or " + labelPathInFlutterAsset + " are not a proper model or label", e);
        }
    }

    /**
     * <p>Copy the files in flutter asset to Android application directory</>
     *
     * @param flutterAssetPath File path in a Flutter asset.
     * @return Path under Application directory where files in Flutter assets are copied.
     */
    private String getFilePathInAppDir(String flutterAssetPath) {
        FlutterLoader loader = FlutterInjector.instance().flutterLoader();
        String flutterAssetFilePath = loader.getLookupKeyForAsset(flutterAssetPath);

        // Path under Application Directory
        String filePathInAppDir = context.getApplicationContext().getApplicationInfo().dataDir + "/" + flutterAssetFilePath;

        AssetManager assetManager = context.getAssets();
        InputStream inputStream = null;
        OutputStream outputStreams = null;

        try {
            // Read a file in a Flutter asset
            inputStream = assetManager.open(flutterAssetFilePath);
            byte[] buffer = new byte[inputStream.available()];
            inputStream.read(buffer);

            // Delete the copy destination file if it already exists
            File fileInAppDir = new File(filePathInAppDir);
            if (fileInAppDir.exists()) {
                fileInAppDir.delete();
            }

            // Create the copy destination sub directory if it already doesn't exists
            String dirPathInAppSubDir = filePathInAppDir.substring(0, filePathInAppDir.lastIndexOf("/"));
            File dirInAppDir = new File(dirPathInAppSubDir);
            if (!dirInAppDir.exists()) {
                dirInAppDir.mkdirs();
            }

            // Create the copy destination directory
            fileInAppDir.createNewFile();

            // Copy the files in the Flutter asset under the Application Directory
            OutputStream os = new FileOutputStream(fileInAppDir);
            os.write(buffer);

        }catch (Exception e) {
            Log.e("flutter_d2go", String.format("Copy %s failed", flutterAssetPath), e);
        } finally {
            try {
                if (inputStream != null) {
                    inputStream.close();
                }
                if (outputStreams != null) {
                    outputStreams.close();
                }
            } catch (IOException e) {
                Log.e("flutter_d2go", "Close stream failed", e);
            }
        }
        return filePathInAppDir;
    }

    /**
     * <p>Create an input image from static image for inference and return the inference result to Flutter</>
     *
     * @param call Method call called from Flutter. Contains various arguments.
     * @param result If successful, return a formatted the inference result with result.success.
     */
    private void predictImage(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {

        byte[] imageBytes = call.argument("image");
        ArrayList<Double> meanDouble = call.argument("mean");
        ArrayList<Double> stdDouble = call.argument("std");
        double minScore = call.argument("minScore");
        int inputWidth = call.argument("inputWidth");
        int inputHeight = call.argument("inputHeight");

        // Create a bitmap object from image and fit the size to the model
        Bitmap bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, requireNonNull(imageBytes).length);
        Bitmap resizedBitmap = Bitmap.createScaledBitmap(bitmap, inputWidth, inputHeight, true);

        // Get the increase / decrease ratio between the bitmap and the original image
        float imageWidthScale = (float)bitmap.getWidth() / inputWidth;
        float imageHeightScale = (float)bitmap.getHeight() / inputHeight;

        // Get formatted inference results and register in result.success
        result.success(createOutputsFromPredictions(resizedBitmap, meanDouble, stdDouble, minScore, imageWidthScale, imageHeightScale));
    }


    /**
     * <p>Create an input image from camera streaming image for inference and return the inference result to Flutter</>
     *
     * @param call Method call called from Flutter. Contains various arguments.
     * @param result If successful, return a formatted the inference result with result.success.
     */
    private void predictStreamImage(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        int width = call.argument("width");
        int height = call.argument("height");
        int inputWidth = call.argument("inputWidth");
        int inputHeight = call.argument("inputHeight");
        ArrayList<Double> meanDouble = call.argument("mean");
        ArrayList<Double> stdDouble = call.argument("std");
        double minScore = call.argument("minScore");

        StreamImageUtils streamImageUtils = new StreamImageUtils(call, context);

        // Create a bitmap object from the imageMap and add fit the size to the model and orientation by 90 degrees
        Bitmap resizedBitmap = streamImageUtils.getBitmap(inputWidth, inputHeight);

        // Get the increase / decrease ratio between the bitmap and the original imageMap
        // the camera streaming imageMap is tilted 90 degrees, so the vertical and horizontal directions are reversed
        float imageWidthScale = height / inputWidth;
        float imageHeightScale = width / inputHeight;

        // Get formatted inference results and register in result.success
        result.success(createOutputsFromPredictions(resizedBitmap, meanDouble, stdDouble, minScore, imageWidthScale, imageHeightScale));
    }

    /**
     * <p>Infer using the D2Go model, format the result and return it</>
     *
     * @param bitmap Bitmap formatted for inference
     * @param meanDouble Average value used in Normalize
     * @param stdDouble Standard deviation used in Normalize
     * @param minScore If this threshold is not met, it will not be included in the results
     * @param imageWidthScale the increase / decrease ratio of width between the formatted bitmap and the original image
     * @param imageHeightScale the increase / decrease ratio of height between the formatted bitmap and the original image
     * @return A formatted version of the inference result
     *         The format is List of { "rect": { "left": Float, "top": Float, "right": Float, "bottom": Float },
     *                                 "mask": [byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte ...],
     *                                 "keypoints": [[Float, Float], [Float, Float], [Float, Float], [Float, Float], ...],
     *                                 "confidenceInClass": Float, "detectedClass": String }. "mask" and "keypoints" do not exist on some models.
     */
    private List<Map<String, Object>> createOutputsFromPredictions(Bitmap bitmap, ArrayList<Double> meanDouble, ArrayList<Double> stdDouble, double minScore, float imageWidthScale, float imageHeightScale ) {

        // Convert [mean] and [std] to float
        float[] mean = toFloatPrimitives(requireNonNull(meanDouble).toArray(new Double[0]));
        float[] std = toFloatPrimitives(requireNonNull(stdDouble).toArray(new Double[0]));

        // Create a dtype torch.float32 tensor to input to the model with [inputWidth], [inputHeight] size and bitmap data
        final FloatBuffer floatBuffer = Tensor.allocateFloatBuffer(3 * bitmap.getWidth() * bitmap.getHeight());
        TensorImageUtils.bitmapToFloatBuffer(bitmap,0,0, bitmap.getWidth(), bitmap.getHeight(), mean, std, floatBuffer, 0);
        final Tensor inputTensor = Tensor.fromBlob(floatBuffer, new long[] {3, bitmap.getHeight(), bitmap.getWidth()});

        // inference
        IValue[] outputTuple = module.forward(IValue.listFrom(inputTensor)).toTuple();

        final Map<String, IValue> map = outputTuple[1].toList()[0].toDictStringKey();

        List<Map<String, Object>> outputs = new ArrayList<>();

        // Formatting inference results
        if (map.containsKey("boxes")) {
            final boolean hasMasks = map.containsKey("masks");
            final boolean hasKeypoints = map.containsKey("keypoints");

            final Tensor boxesTensor = requireNonNull(map.get("boxes")).toTensor();
            final Tensor scoresTensor = requireNonNull(map.get("scores")).toTensor();
            final Tensor labelsTensor = requireNonNull(map.get("labels")).toTensor();

            // [boxesData] has 4 sets of left, top, right and bottom per instance
            // boxesData = [left1, top1, right1, bottom1, left2, top2, right2, bottom2, left3, top3, ..., bottomN]
            final float[] boxesData = boxesTensor.getDataAsFloatArray();
            final float[] scoresData = scoresTensor.getDataAsFloatArray();
            final long[] labelsData = labelsTensor.getDataAsLongArray();

            // Inferred number of all instances
            final int totalInstances = scoresData.length;

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
                    final Tensor rawMasksTensor = requireNonNull(map.get("masks")).toTensor();
                    final float[] rawMasksData = rawMasksTensor.getDataAsFloatArray();
                    output.put("mask", getMaskBytes(rawMasksData, i));
                }

                if (hasKeypoints) {
                    // keypointsData is in a format with 17 * (x, y, score) for each instance. (coco estimates have 17 keypoints)
                    final Tensor keypointsTensor = requireNonNull(map.get("keypoints")).toTensor();
                    final float[] keypointsData = keypointsTensor.getDataAsFloatArray();
                    output.put("keypoints", getKeypointsList(keypointsData, i, bitmap.getWidth(), bitmap.getHeight()));
                }

                output.put("confidenceInClass", scoresData[i]);
                output.put("detectedClass", classes.get((int)(labelsData[i] - 1)));

                outputs.add(output);
            }
        }
        return outputs;
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
        int rawMaskWidth = 28;
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
        final byte[] bmpFileHeader = MaskBitmapHeader.getBMPFileHeader();
        final byte[] bmpInfoHeader = MaskBitmapHeader.getBMPInfoHeader(rawMaskWidth, rawMaskWidth);
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
        return primitives;
    }

}
