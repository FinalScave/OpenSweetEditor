package com.qiplat.sweeteditor.core;

import com.qiplat.sweeteditor.core.adornment.TextStyle;
import org.junit.jupiter.api.Test;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ProtocolEncoderBatchTextStylesTest {

    @Test
    void packBatchTextStylesEncodesSortedEntriesInLittleEndianOrder() {
        Map<Integer, TextStyle> textStyles = new LinkedHashMap<>();
        textStyles.put(9, new TextStyle(0xFF556677, 0x11223344, TextStyle.ITALIC));
        textStyles.put(3, new TextStyle(0xFFAABBCC, 0, TextStyle.BOLD));

        byte[] payload = ProtocolEncoder.packBatchTextStyles(textStyles);

        ByteBuffer buffer = ByteBuffer.wrap(payload).order(ByteOrder.LITTLE_ENDIAN);
        assertEquals(2, buffer.getInt());

        assertEquals(3, buffer.getInt());
        assertEquals(0xFFAABBCC, buffer.getInt());
        assertEquals(0, buffer.getInt());
        assertEquals(TextStyle.BOLD, buffer.getInt());

        assertEquals(9, buffer.getInt());
        assertEquals(0xFF556677, buffer.getInt());
        assertEquals(0x11223344, buffer.getInt());
        assertEquals(TextStyle.ITALIC, buffer.getInt());
        assertEquals(0, buffer.remaining());
    }

    @Test
    void packBatchTextStylesRejectsNullStyleId() {
        Map<Integer, TextStyle> textStyles = new HashMap<>();
        textStyles.put(null, new TextStyle(0xFFAABBCC, TextStyle.BOLD));

        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> ProtocolEncoder.packBatchTextStyles(textStyles));

        assertEquals("textStyles contains null styleId", error.getMessage());
    }

    @Test
    void packBatchTextStylesRejectsNullTextStyle() {
        Map<Integer, TextStyle> textStyles = new HashMap<>();
        textStyles.put(4, null);

        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> ProtocolEncoder.packBatchTextStyles(textStyles));

        assertEquals("textStyles contains null TextStyle for styleId=4", error.getMessage());
    }
}
