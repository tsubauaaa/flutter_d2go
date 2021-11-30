package com.tsubauaaa.flutter_d2go;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.renderscript.Allocation;
import android.renderscript.Element;
import android.renderscript.RenderScript;
import android.renderscript.ScriptIntrinsicYuvToRGB;
import android.renderscript.Type;

import com.facebook.soloader.nativeloader.NativeLoader;
import com.facebook.soloader.nativeloader.SystemDelegate;

import org.pytorch.IValue;
import org.pytorch.Module;
import org.pytorch.Tensor;
import org.pytorch.torchvision.TensorImageUtils;

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.nio.FloatBuffer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

import androidx.annotation.NonNull;
import io.flutter.Log;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static java.util.Objects.requireNonNull;

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
            case "predictImageOnFrame":
                predictImageOnFrame(call, result);
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
            File labels = new File(requireNonNull(absLabelPath));
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
     * <p>Create an input image from static image for inference and return the inference result to Flutter</>
     *
     * @param call Method call called from Flutter. Contains various arguments.
     * @param result If successful, return a formatted the inference result with result.success
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

        // Get formatted inference results
        List<Map<String, Object>> outputs = createOutputsFromPredictions(resizedBitmap, meanDouble, stdDouble, minScore, imageWidthScale, imageHeightScale);

        result.success(outputs);
    }


    /**
     * <p>Create an input image from camera streaming image for inference and return the inference result to Flutter</>
     *
     * @param call Method call called from Flutter. Contains various arguments.
     * @param result If successful, return a formatted the inference result with result.success
     */
    private void predictImageOnFrame(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        HashMap image = call.argument("image");
        ArrayList<Double> meanDouble = call.argument("mean");
        ArrayList<Double> stdDouble = call.argument("std");
        double minScore = call.argument("minScore");
        int width = call.argument("width");
        int height = call.argument("height");
        int inputWidth = call.argument("inputWidth");
        int inputHeight = call.argument("inputHeight");

        // Create a bitmap object from the image and add orientation by 90 degrees
        Bitmap orientedBitmap = getBitmap(image, width, height, inputWidth, inputHeight);

        // Get the increase / decrease ratio between the bitmap and the original image
        // the camera streaming image is tilted 90 degrees, so the vertical and horizontal directions are reversed
        float imageWidthScale = (float) height / inputWidth;
        float imageHeightScale = (float) width / inputHeight;

        // Get formatted inference results
        List<Map<String, Object>> outputs = createOutputsFromPredictions(orientedBitmap, meanDouble, stdDouble, minScore, imageWidthScale, imageHeightScale);

        result.success(outputs);
    }


    public Bitmap getBitmap(HashMap image, int width, int height, int inputWidth, int inputHeight){
        Bitmap bitmap = Bitmap.createScaledBitmap(yuv420toBitMap(image, width, height), inputWidth, inputHeight, true);
        Matrix matrix = new Matrix();
        matrix.postRotate((Integer)image.get("rotation"));
        return Bitmap.createBitmap(bitmap, 0, 0, inputWidth, inputHeight, matrix, true);
    }


    public Bitmap yuv420toBitMap(final HashMap image, int w, int h) {
        ArrayList<Map> planes = (ArrayList) image.get("planes");

        byte[] data = yuv420toNV21(w, h, planes);

        RenderScript rs = RenderScript.create(context);

        Bitmap bitmap = Bitmap.createBitmap(w, h,   Bitmap.Config.ARGB_8888);
        ScriptIntrinsicYuvToRGB yuvToRgbIntrinsic = ScriptIntrinsicYuvToRGB.create(rs, Element.U8_4(rs));

        Type.Builder yuvType = new Type.Builder(rs, Element.U8(rs)).setX(data.length);
        Allocation in = Allocation.createTyped(rs, yuvType.create(), Allocation.USAGE_SCRIPT);
        in.copyFrom(data);

        Type.Builder rgbaType = new Type.Builder(rs, Element.RGBA_8888(rs)).setX(w).setY(h);
        Allocation out = Allocation.createTyped(rs, rgbaType.create(), Allocation.USAGE_SCRIPT);

        yuvToRgbIntrinsic.setInput(in);
        yuvToRgbIntrinsic.forEach(out);

        out.copyTo(bitmap);
        return bitmap;
    }


    public byte[] yuv420toNV21(int width,int height, ArrayList<Map> planes){
        byte[] yBytes = (byte[]) planes.get(0).get("bytes"),
                uBytes= (byte[]) planes.get(1).get("bytes"),
                vBytes= (byte[]) planes.get(2).get("bytes");
        final int color_pixel_stride =(int) planes.get(1).get("bytesPerPixel");

        ByteArrayOutputStream outputbytes = new ByteArrayOutputStream();
        try {
            outputbytes.write(yBytes);
            outputbytes.write(vBytes);
            outputbytes.write(uBytes);
        } catch (IOException e) {
            e.printStackTrace();
        }

        byte[] data = outputbytes.toByteArray();
        final int y_size = yBytes.length;
        final int u_size = uBytes.length;
        final int data_offset = width * height;
        for (int i = 0; i < y_size; i++) {
            data[i] = (byte) (yBytes[i] & 255);
        }
        for (int i = 0; i < u_size / color_pixel_stride; i++) {
            data[data_offset + 2 * i] = vBytes[i * color_pixel_stride];
            data[data_offset + 2 * i + 1] = uBytes[i * color_pixel_stride];
        }
        return data;
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
        return primitives;
    }

}
