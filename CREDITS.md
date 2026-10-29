# Credits — KITT Voice for Mac

This page records the software, integrations, documentation and creative
resources evidenced in this project's source and development records. A listed
integration is not necessarily bundled in the repository. Existing copyright
and licence notices remain in force; this acknowledgement does not relicense
third-party work or imply endorsement.

## Native app and tools

- **Apple**: [SwiftUI](https://developer.apple.com/xcode/swiftui/), AppKit,
  AVFoundation, Speech, Combine, Foundation, Security/Keychain and
  [SF Symbols](https://developer.apple.com/sf-symbols/) supply the native UI,
  audio, on-device recognition and system icons. These are macOS/SDK components,
  not separately bundled third-party frameworks.
- **The Swift project, Apple and Swift contributors**: [Swift](https://www.swift.org/)
  and the Xcode command-line toolchain compile the app.
- **Python Software Foundation and contributors**: [Python](https://www.python.org/),
  [licensing](https://docs.python.org/3/license.html), provides the separately
  installed optional voice-worker runtime. **pip/PyPA contributors** provide
  its package installer. **Homebrew maintainers** provide the optional Python
  installation paths recognised by the setup script.
- **curl contributors**: the setup script uses [curl](https://curl.se/) for
  model downloads. This repository does not include the curl executable.

## AI chat and speech

| Project / creator | Contribution | Source and terms |
|---|---|---|
| Ollama and contributors | Local chat-model server, installed separately | [Ollama](https://github.com/ollama/ollama), [MIT notice](VoiceEngine/licenses/ollama/LICENSE.txt). |
| Meta / Llama contributors | The recommended `llama3.2:3b` chat model, downloaded separately through Ollama | **Built with Llama.** [Model card](https://github.com/meta-llama/llama-models/blob/main/models/llama3_2/MODEL_CARD.md), [Llama 3.2 Community License](VoiceEngine/licenses/llama-3.2/LICENSE.txt). |
| hexgrad / Kokoro contributors | Kokoro-82M local speech model and voices | [Kokoro model card](https://huggingface.co/hexgrad/Kokoro-82M), Apache-2.0; [licence copy](VoiceEngine/LICENSE-Kokoro.txt). |
| thewh1teagle / kokoro-onnx contributors | Python ONNX wrapper and distribution of the downloaded ONNX model/voice pack | [kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx), [model-files-v1.1 release](https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.1), MIT wrapper notice in `VoiceEngine/licenses/kokoro-onnx/`. The model has its own licence. |
| Fish Audio | Optional online text-to-speech API | [Fish Audio API documentation](https://docs.fish.audio/). Service and model terms apply separately; no Fish model weights are bundled. |
| Polybius223 | The linked community KITT voice model, identified by this creator name in the original project setup | [KITT voice model](https://fish.audio/m/eaa8a416bfcd4a38b3e3fa94ad934225/), model ID `eaa8a416bfcd4a38b3e3fa94ad934225`. This credits the model uploader without claiming ownership of the original character/actor's voice. |

The Llama attribution is retained verbatim in [NOTICE](NOTICE). Model weights,
Ollama, Python environments and native speech libraries are downloaded or
installed separately; they are not part of the GitHub app archive.

### Kokoro's upstream acknowledgements

The [Kokoro model card](https://huggingface.co/hexgrad/Kokoro-82M#acknowledgements)
credits **Li et al. / yl4579** for StyleTTS 2, **iSTFTNet** for architectural
work, and **rzvzn** for model training. Its training-data attribution section
lists **Koniwa (`tnc`, CC BY 3.0)** and **SIWIS (CC BY 4.0)**. These are upstream
model credits, not a claim that this app's maintainers trained the model or
redistribute those datasets. See also the [voice descriptions](https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md).

## Optional Python voice environment

These versions are recorded in [requirements-lock.txt](VoiceEngine/requirements-lock.txt).
The table was checked against the matching locally installed package metadata;
available licence and third-party notice files are preserved under
[VoiceEngine/licenses](VoiceEngine/licenses/README.md). Those notices do not
apply a single licence to all dependencies or to the native app.

| Package | Recorded version | Creator / contributors | Licence and notices |
|---|---|---|---|
| [attrs](https://github.com/python-attrs/attrs) | 26.1.0 | attrs contributors | MIT; [notice files](VoiceEngine/licenses/attrs/). |
| [cffi](https://github.com/python-cffi/cffi) | 2.1.1 | CFFI contributors | MIT-0, as declared by the installed 2.1.1 distribution; [notice files](VoiceEngine/licenses/cffi/). |
| [cloudpickle](https://github.com/cloudpipe/cloudpickle) | 3.1.2 | cloudpickle contributors | BSD-3-Clause; [notice files](VoiceEngine/licenses/cloudpickle/). |
| [dlinfo](https://github.com/fphammerle/python-dlinfo) | 2.0.0 | Fabian Peter Hammerle and contributors | MIT; [notice files](VoiceEngine/licenses/dlinfo/). |
| [espeakng-loader](https://github.com/thewh1teagle/espeakng-loader) | 0.2.4 | thewh1teagle and contributors | See upstream MIT notice; the installed 0.2.4 wheel did not include licence metadata. Native eSpeak NG has separate GPL terms.; [notice files](VoiceEngine/licenses/espeakng-loader/). |
| [flatbuffers](https://github.com/google/flatbuffers) | 25.12.19 | Google and FlatBuffers contributors | Apache-2.0; [notice files](VoiceEngine/licenses/flatbuffers/). |
| [joblib](https://github.com/joblib/joblib) | 1.6.0 | joblib contributors | BSD-3-Clause; [notice files](VoiceEngine/licenses/joblib/). |
| [kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx) | 0.6.1 | thewh1teagle and contributors | MIT; [notice files](VoiceEngine/licenses/kokoro-onnx/). |
| [numpy](https://numpy.org/) | 2.5.4 | NumPy developers and contributors | BSD-3-Clause plus bundled component notices; see copied licence files; [notice files](VoiceEngine/licenses/numpy/). |
| [onnxruntime](https://onnxruntime.ai/) | 1.31.0 | Microsoft and ONNX Runtime contributors | MIT plus third-party notices; [notice files](VoiceEngine/licenses/onnxruntime/). |
| [packaging](https://github.com/pypa/packaging) | 26.3 | Python Packaging Authority and contributors | Apache-2.0 OR BSD-2-Clause; [notice files](VoiceEngine/licenses/packaging/). |
| [phonemizer](https://github.com/bootphon/phonemizer) | 3.4.0 | Mathieu Bernard, Hadrien Titeux and contributors | GPL-3.0-or-later; [notice files](VoiceEngine/licenses/phonemizer/). |
| [protobuf](https://github.com/protocolbuffers/protobuf) | 7.36.2 | Google and Protocol Buffers contributors | BSD-3-Clause; [notice files](VoiceEngine/licenses/protobuf/). |
| [pycparser](https://github.com/eliben/pycparser) | 3.12 | Eli Bendersky and contributors | BSD-3-Clause; [notice files](VoiceEngine/licenses/pycparser/). |
| [soundfile](https://github.com/bastibe/python-soundfile) | 0.13.1 | Bastian Bechtold and SoundFile contributors | BSD-3-Clause; libsndfile has separate LGPL terms; [notice files](VoiceEngine/licenses/soundfile/). |
| [typing_extensions](https://github.com/python/typing_extensions) | 4.16.0 | Python typing contributors / Python Software Foundation | PSF-2.0; [notice files](VoiceEngine/licenses/typing_extensions/). |

Additional native components:

- **eSpeak NG contributors**: [eSpeak NG](https://github.com/espeak-ng/espeak-ng)
  supplies phoneme conversion through the optional environment;
  [GPL notice](VoiceEngine/licenses/espeak-ng/LICENSE.txt), with corresponding
  source at that upstream repository. Its licence is separate from the Python
  loader's licence.
- **Erik de Castro Lopo and libsndfile contributors**:
  [libsndfile](https://github.com/libsndfile/libsndfile), used by SoundFile;
  [LGPL notice](VoiceEngine/licenses/libsndfile/LICENSE.txt). The installed
  SoundFile wheel's own additional notices are retained as well.
- ONNX Runtime and NumPy bundle additional upstream components in their
  installed distributions. Their full supplied third-party notice files are
  retained rather than attributing all of those components to the wrapper.

Phonemizer's requested academic citation: **Mathieu Bernard and Hadrien Titeux
(2021), “Phonemizer: Text to Phones Transcription for Multiple Languages in
Python”, Journal of Open Source Software 6(68), 3958**,
[doi:10.21105/joss.03958](https://doi.org/10.21105/joss.03958).

## Character, visual inspiration and phrase references

**Knight Rider and KITT** are credited as the original television/character
inspiration, with rights retained by their respective owners. This is an
unofficial fan project. The compact dashboard was guided by a user-supplied
reference. The app's icon and native LED interface were drawn programmatically
for the project; the repository's screenshots show this app, not television
stills.

Short saying references were checked against the **Knight Rider Archives**
script collection and **Springfield! Springfield!** transcripts:

- [A Knight in Shining Armor](https://www.knightriderarchives.com/knight_rider/season_two/a_knight_in_shining_armor/scripts/1/)
- [Trust Doesn't Rust](https://knightriderarchives.com/knight_rider/season_one/trust_doesnt_rust/scripts/9/)
- [Goliath Returns](https://www.knightriderarchives.com/knight_rider/season_two/goliath_returns/scripts/1/)
- [Mouth of the Snake transcript](https://www.springfieldspringfield.co.uk/view_episode_scripts.php?episode=s02e21&tv-show=knight-rider-1982)

Audio is generated by the selected speech engine. No television dialogue
recordings, soundtrack or complete scripts are bundled.

## Development assistance

- Maintained and published by [MasterCatsUK](https://github.com/MasterCatsUK).
- [OpenAI Codex](https://openai.com/codex/) was used for AI-assisted implementation,
  troubleshooting, documentation and release preparation. This records tool
  provenance; it does not replace the credits or licences of upstream projects.

Attribution inventory reviewed: 29 October 2026.
