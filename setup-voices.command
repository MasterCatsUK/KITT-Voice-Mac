#!/bin/zsh
set -eu
cd "$(dirname "$0")"
voice_python=""
for candidate in /opt/homebrew/bin/python3.13 /usr/local/bin/python3.13 /opt/homebrew/bin/python3.12 /usr/local/bin/python3.12; do
  if [ -x "$candidate" ]; then voice_python="$candidate"; break; fi
done
if [ -z "$voice_python" ]; then
  echo 'Install Python 3.12 or 3.13, then run this script again. Built-in Mac voices work without it.'
  exit 1
fi
"$voice_python" -m venv VoiceEngine/.venv
VoiceEngine/.venv/bin/python -m pip install -r VoiceEngine/requirements-lock.txt
mkdir -p VoiceEngine/models
if [ ! -s VoiceEngine/models/kokoro-v1.0.onnx ]; then
  curl -fL --retry 2 https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1/kokoro-v1.0.onnx -o VoiceEngine/models/kokoro-v1.0.onnx
fi
if [ ! -s VoiceEngine/models/voices-v1.0.bin ]; then
  curl -fL --retry 2 https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1/voices-v1.0.bin -o VoiceEngine/models/voices-v1.0.bin
fi
echo 'Local voices are ready. Open KITT Voice.app.'
