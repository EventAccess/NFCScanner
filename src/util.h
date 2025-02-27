#pragma once

#include <Arduino.h>

String getHexRepresentation(const byte* data, const uint32_t numBytes, const char* prefix="0x", const char* separator=" ");
