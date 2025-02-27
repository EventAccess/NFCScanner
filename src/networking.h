#pragma once

#include <Arduino.h>
#include <W5500lwIP.h>

#define MAC_EEPROM_ADDR (uint8_t)(0x50)


extern byte ethernet_mac[6];

  // Set the static IP address to use if the DHCP fails to assign
extern IPAddress ip;
extern IPAddress myDns;


extern BearSSL::WiFiClientSecure client;
extern BearSSL::X509List cert;


bool networking_setup();
void networking_loop();

bool verify_tag();
