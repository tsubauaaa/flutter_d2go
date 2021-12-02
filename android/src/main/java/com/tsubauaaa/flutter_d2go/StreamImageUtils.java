package com.tsubauaaa.flutter_d2go;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Matrix;
import android.renderscript.Allocation;
import android.renderscript.Element;
import android.renderscript.RenderScript;
import android.renderscript.ScriptIntrinsicYuvToRGB;
import android.renderscript.Type;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

import androidx.annotation.NonNull;
import io.flutter.plugin.common.MethodCall;

/**
 * <p>StreamImageUtils</>
 *
 * Utility class to convert bitmaps from camera stream image and metadata.
 */
public class StreamImageUtils {

    private static Context context;
    private static HashMap imageMap;

    /**
     * <p>Constructor to initialize imageMap and context of member variables</>
     *
     * @param call Method call called from Flutter. Contains various arguments.
     * @param context Used in renderscript.
     * The member variable imageMap is a map of camera streaming image and metadata.
     * The elements are
     *           `planes` Map containing bytes (byte[]) and bytesPerPixel (ArrayList<Integer>).
     *           `width` Width size (int) of the image to be inferred.
     *           `height` Height size (int) of the image to be inferred.
     *           `rotation` Tilt (int) according to the orientation of the image to be inferred.
     */
    public StreamImageUtils(@NonNull MethodCall call, @NonNull Context context) {
        this.context = context;
        ArrayList<byte[]> imageBytesList = call.argument("imageBytesList");
        ArrayList<Integer> imageBytesPerPixel = call.argument("imageBytesPerPixel");
        int width = call.argument("width");
        int height = call.argument("height");
        int rotation = call.argument("rotation");
        HashMap imageMap = new HashMap<>();
        ArrayList planes = new ArrayList<Map<String, Object>>(Arrays.asList(new LinkedHashMap<>(), new LinkedHashMap<>(), new LinkedHashMap<>()));
        for (int i = 0; i < planes.size(); i++) {
            Map<String, Object> value = new LinkedHashMap<>();
            value.put("bytes", imageBytesList.get(i));
            value.put("bytesPerPixel", imageBytesPerPixel.get(i));
            planes.set(i, value);
        }

        imageMap.put("planes", planes);
        imageMap.put("width", width);
        imageMap.put("height", height);
        imageMap.put("rotation", rotation);

        this.imageMap = imageMap;
    }

    /**
     * <p>Convert to Bitmap for inferring from camera stream image and metadata (imageMap)</>
     *
     * @param inputWidth Width size for inference image resizing.
     * @param inputHeight Height size for inference image resizing.
     * @return Bitmap for inference converted from camera stream image and metadata (imageMap)
     */
    public static Bitmap getBitmap(int inputWidth, int inputHeight){
        // Resize bitmap for inference
        Bitmap bitmap = Bitmap.createScaledBitmap(streamImageToBitmap(), inputWidth, inputHeight, true);

        // Tilt the bitmap 90 degrees, taking into account the impact of orientation
        Matrix matrix = new Matrix();
        matrix.postRotate((int) imageMap.get("rotation"));
        return Bitmap.createBitmap(bitmap, 0, 0, inputWidth, inputHeight, matrix, true);
    }


    /**
     * <p>Convert stream image and metadata (imageMap) to byte[] in YUV420 NV21 format and then convert to Bitmap</>
     *
     * Use RenderScript to convert YUV420 NV1 to RGBA and then to Bitmap to reduce the calculation load.
     * @return Bitmap converted from stream image and metadata (imageMap).
     */
    private static Bitmap streamImageToBitmap() {

        RenderScript rs = RenderScript.create(context);

        int width = (int) imageMap.get("width");
        int height = (int)imageMap.get("height");

        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        ScriptIntrinsicYuvToRGB yuvToRgbIntrinsic = ScriptIntrinsicYuvToRGB.create(rs, Element.U8_4(rs));

        byte[] data = cameraStreamToBytes();
        Type.Builder yuvType = new Type.Builder(rs, Element.U8(rs)).setX(data.length);
        Allocation in = Allocation.createTyped(rs, yuvType.create(), Allocation.USAGE_SCRIPT);
        in.copyFrom(data);

        Type.Builder rgbaType = new Type.Builder(rs, Element.RGBA_8888(rs)).setX(width).setY(height);
        Allocation out = Allocation.createTyped(rs, rgbaType.create(), Allocation.USAGE_SCRIPT);

        yuvToRgbIntrinsic.setInput(in);
        yuvToRgbIntrinsic.forEach(out);

        out.copyTo(bitmap);
        return bitmap;
    }


    /**
     * <p>Convert camera stream image and metadata (imageMap) to YUV420 NV21 format byte[]</>
     *
     * The Android camera Stream picture format is basically yuv420 nv21, so treat it that way here as well.
     * YUV is a color space expressed using a luminance signal Y and two color difference signals (CbCr).
     * The byte order is divided into Y plane and CbCr plane. For NV21 format, the CbCr plane has the order of Cb bytes and Cr bytes swapped.
     * @see <a href="https://en.wikipedia.org/wiki/YUV#Y%E2%80%B2UV420sp_(NV21)_to_RGB_conversion_(Android)">https://en.wikipedia.org/wiki/YUV#Y%E2%80%B2UV420sp_(NV21)_to_RGB_conversion_(Android)</a>
     * @see <a href="https://visual-foxpro-programmer.com/img/isp/16/rgb-conversion-nv21-storage-format.png">https://visual-foxpro-programmer.com/img/isp/16/rgb-conversion-nv21-storage-format.png</a>
     *
     * @return YUV420 NV21 format byte [] converted from camera stream image and metadata (imageMap).
     */
    private static byte[] cameraStreamToBytes(){
        int width = (int) imageMap.get("width");
        int height = (int)imageMap.get("height");

        ArrayList<Map> planes = (ArrayList) imageMap.get("planes");
        byte[] yBytes = (byte[]) planes.get(0).get("bytes"),
                uBytes= (byte[]) planes.get(1).get("bytes"),
                vBytes= (byte[]) planes.get(2).get("bytes");
        final int color_pixel_stride =(int) planes.get(1).get("bytesPerPixel");

        ByteArrayOutputStream outputBytes = new ByteArrayOutputStream();
        try {
            outputBytes.write(yBytes);
            outputBytes.write(vBytes);
            outputBytes.write(uBytes);
        } catch (IOException e) {
            e.printStackTrace();
        }

        byte[] data = outputBytes.toByteArray();
        final int y_size = yBytes.length;
        final int u_size = uBytes.length;
        final int data_offset = width * height;
        for (int i = 0; i < y_size; i++) {
            data[i] = (byte) (yBytes[i] & 255);
        }
        // swap
        for (int i = 0; i < u_size / color_pixel_stride; i++) {
            data[data_offset + 2 * i] = vBytes[i * color_pixel_stride];
            data[data_offset + 2 * i + 1] = uBytes[i * color_pixel_stride];
        }
        return data;
    }

}
