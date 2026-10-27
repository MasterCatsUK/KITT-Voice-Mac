"""Offline Kokoro speech worker. Reads JSON on stdin; writes a WAV file.

No HTTP client, API key, telemetry, or runtime model downloads are used.
"""
import json
import os
import sys
from pathlib import Path

os.environ.setdefault("OMP_NUM_THREADS", "4")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "4")

import numpy as np
import onnxruntime as ort
ort.disable_telemetry_events()
import soundfile as sf
from kokoro_onnx import Kokoro


def main():
    request = json.load(sys.stdin)
    root = Path(__file__).resolve().parent
    allowed = {"am_michael", "am_fenrir", "am_puck", "am_onyx", "bm_george", "af_heart"}
    voice = request.get("voice", "am_michael")
    if voice not in allowed:
        raise ValueError("Unsupported local voice")
    text = str(request["text"]).strip().replace("K.I.T.T.", "Kitt").replace("KITT", "Kitt")
    if not text or len(text) > 12000:
        raise ValueError("Speech text is empty or too long")
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(root / "models/kokoro-v1.0.onnx"),
        sess_options=options, providers=["CPUExecutionProvider"])
    engine = Kokoro.from_session(session, str(root / "models/voices-v1.0.bin"))
    samples, sample_rate = engine.create(text, voice=voice,
        speed=max(0.65, min(1.45, float(request.get("speed", 1.0)))),
        lang="en-gb" if voice.startswith("b") else "en-us")
    if not len(samples) or not np.isfinite(samples).all():
        raise ValueError("No valid audio was generated")
    sf.write(request["output"], samples, sample_rate, subtype="PCM_16")
    print(json.dumps({"seconds": len(samples) / sample_rate, "voice": voice}))


if __name__ == "__main__":
    main()
