#include "networking.h"
#include "ca_cert.h"
#include "util.h"
#include "ca_cert.h"

#include <Arduino.h>

#include <time.h>
//#include <WiFiClientSecure.h>
#include <W5500lwIP.h>

#include <Wire.h>
#include <SPI.h>

// D10 challenger NFC marking == GPIO5, matches with FeatherWing Ethernet
Wiznet5500lwIP eth(D10 /* chipselect */, SPI, -1 /* interrupt*/);

void read_mac() {
  // Read MAC address from EEPROM
  Wire.begin();

  Wire.beginTransmission(MAC_EEPROM_ADDR);
  Wire.write(0xFA); // EUI-48 address location
  Wire.endTransmission(false);

  Wire.requestFrom(MAC_EEPROM_ADDR, 6);
  size_t mac_bytes_read = 0;
  if (Wire.available() > 0) {
    mac_bytes_read = Wire.readBytes(ethernet_mac, 6);
  }

  Serial.print("MAC: ");
  Serial.println(getHexRepresentation(ethernet_mac, 6));
}


byte ethernet_mac[6] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

IPAddress ip = IPAddress(192, 168, 42, 177);
IPAddress myDns = IPAddress(192, 168, 42, 1);

BearSSL::WiFiClientSecure client;
BearSSL::X509List cert(ROOT_CERT);

bool networking_setup() {
    Serial.println("Starting Ethernet port");

    // Start the Ethernet port
    if (!eth.begin()) {
      Serial.println("No wired Ethernet hardware detected. Check pinouts, wiring.");
      while (1) {
        delay(1000);
      }
    }

    while (!eth.connected()) {
      Serial.print(".");
      delay(500);
    }

    Serial.println("");
    Serial.println("Ethernet connected");
    Serial.println("IP address: ");
    Serial.println(eth.localIP());


    client.setTrustAnchors(&cert);
    //Serial.printf("Try validating without setting the time (should fail)\n");
    //fetchURL(&client, ssl_host, ssl_port, path);

    NTP.begin("ntp.uio.no", "no.pool.ntp.org");

    Serial.print("Waiting for NTP time sync: ");
    NTP.waitSet([]() {
      Serial.print(".");
    });
    Serial.println();
    time_t now = time(nullptr);
    struct tm timeinfo;
    gmtime_r(&now, &timeinfo);
    Serial.print("Current time: ");
    Serial.print(asctime(&timeinfo));
    //Serial.printf("Try again after setting NTP time (should pass)\n");
    //fetchURL(&client, ssl_host, ssl_port, path);
    return false;
}


void networking_loop() {

}

bool verify_tag() {
    return false;
}
