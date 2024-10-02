#!/bin/bash
apt update
apt install python3

pushd /tmp
    rm -f arduino-cli_*.tar.gz
    wget https://github.com/arduino/arduino-cli/releases/download/v1.0.4/arduino-cli_1.0.4_Linux_64bit.tar.gz
    tar xfzv arduino-cli_*.tar.gz
    mkdir -p ~/.local/bin
    mv arduino-cli ~/.local/bin/
    rm arduino-cli_*.tar.gz
popd

arduino-cli config set library.enable_unsafe_install true

arduino-cli lib install --git-url https://github.com/adamgreg/arduino-nfc.git#88d07446367bb75a5e3bf5fad5ab409e754640d9

arduino-cli config add board_manager.additional_urls https://github.com/earlephilhower/arduino-pico/releases/download/global/package_rp2040_index.json
arduino-cli core install rp2040:rp2040@4.0.2

# TODO: Implement renovate auto-update
#        * arduino-cli download
#        * arduino libraries
#        * arduino board manager
