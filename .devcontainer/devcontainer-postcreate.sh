#!/bin/bash

pip install -r .tools/requirements.txt

python .tools/install_tools.py
python .tools/install_arduino_deps.py
