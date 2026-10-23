#!/bin/sh
set -eu
: "${GODOT:?Set GODOT to the reviewed Godot 4.7.2 executable}"
python scripts/build_save_adapter.py
python scripts/test_native.py "$GODOT"
"$GODOT" --headless --path native --quit-after 3
