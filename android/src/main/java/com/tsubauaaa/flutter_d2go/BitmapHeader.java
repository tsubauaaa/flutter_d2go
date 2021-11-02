package com.tsubauaaa.flutter_d2go;

/**
 * <p>BitmapHeader</>
 * This class is a class that infers using the d2go model
 */
public class BitmapHeader {

    // Bitfile file header size and info header size
    //  @see <a href="https://en.wikipedia.org/wiki/BMP_file_format#Bitmap_file_header">https://en.wikipedia.org/wiki/BMP_file_format#Bitmap_file_header</a>
    final private static int fileHeaderSize = 14;
    final private static int infoHeaderSize = 108;


    /**
     * Create a bitmap file header and return it with byte []
     * @return bitmap file header byte array
     */
    public static byte[] getBMPFileHeader()
    {
        byte[]buffer = new byte[14];
        // file type
        buffer[0] = 0x42;
        buffer[1] = 0x4D;

        // Header size
        buffer[2] = (byte) (fileHeaderSize + infoHeaderSize & 0xff);
        buffer[3] = 0x00;
        buffer[4] = 0x00;
        buffer[5] = 0x00;

        // Hot spot
        buffer[6] = 0x00;
        buffer[7] = 0x00;
        buffer[8] = 0x00;
        buffer[9] = 0x00;

        // Offset
        buffer[10] = (byte) (fileHeaderSize + infoHeaderSize & 0xff);
        buffer[11] = 0x00;
        buffer[12] = 0x00;
        buffer[13] = 0x00;

        return buffer;
    }

    /**
     * Create a bitmap info header (BITMAPV4HEADER) and return it with byte []
     * @return bitmap file header byte array
     */
    public static byte[] getBMPInfoHeader(int w, int h) {
        byte[] buffer = new byte[infoHeaderSize];

        // Header size
        buffer[0] = (byte) (infoHeaderSize & 0xff);
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

        // plane number
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
}
