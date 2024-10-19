#!/bin/bash

arduino-cli compile --output-dir artifacts/ -b rp2040:rp2040:challenger_2040_nfc poc/TagDetect

arduino-cli compile --output-dir artifacts/ -b rp2040:rp2040:challenger_2040_nfc poc/WebClientRepeating

arduino-cli compile --output-dir artifacts/ -b rp2040:rp2040:challenger_2040_nfc poc/ElectronicCats-DetectTags



arduino-cli compile --output-dir artifacts/ -b rp2040:rp2040:challenger_2040_nfc src
