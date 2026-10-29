# Local speech dependencies

- [Kokoro-82M by hexgrad](https://huggingface.co/hexgrad/Kokoro-82M): Apache License 2.0.
- [kokoro-onnx by thewh1teagle](https://github.com/thewh1teagle/kokoro-onnx): MIT license. The optional ONNX model and voice pack are downloaded from its [model-files-v1.1 release](https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1).
- The optional Python environment installed by setup-voices.command includes the distribution license files for its dependencies. Exact installed package versions are listed in `requirements-lock.txt`.

The `speak.py` worker reads text from its local standard input and writes a local WAV file. It uses CPU inference, disables ONNX Runtime telemetry, and does not call online inference services. No voice cloning or training is performed by the local engine.

SHA-256 of the downloaded assets:

- `kokoro-v1.0.onnx`: `beb0d1848dee9a49da392cc3df26958d46cfa35d321edf434f52949153f0df3a`
- `voices-v1.0.bin`: `bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d`

## Complete acknowledgements

See [CREDITS.md](../CREDITS.md), the project's [NOTICE](../NOTICE) and
[licence inventory](licenses/README.md) for the expanded software, native
library, model, data-source and creator credits. Each dependency retains its
own licence; the Apache licence above describes the Kokoro model, not the
entire optional environment.
