#include <Arduino.h>
#include "util.h"

String getHexRepresentation(const byte* data, const uint32_t numBytes, const char* prefix, const char* separator) {
    String hexString;

    if (numBytes == 0) {
        hexString = "null";
    }

    for (uint32_t szPos = 0; szPos < numBytes; szPos++) {
        hexString += prefix;
        if (data[szPos] <= 0xF) {
            hexString += "0";
        }
        hexString += String(data[szPos] & 0xFF, HEX);
        if ((numBytes > 1) && (szPos != numBytes - 1)) {
            hexString += separator;
        }
    }
    return hexString;
}
