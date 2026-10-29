# Optional voice dependency licences and notices

This directory preserves available licence and notice text from the matching
locally installed packages recorded in `../requirements-lock.txt`, plus clearly
identified upstream notices for separately installed services/models and native
libraries. [inventory.json](inventory.json) records each file's origin.

The dependency software, virtual environment, native binaries and model weights
are not bundled here. The licence files are acknowledgements/reference copies.

In particular, the installed espeakng-loader 0.2.4 wheel did not contain licence
metadata or a licence file. `espeakng-loader/UPSTREAM-LICENSE.txt` records the
upstream project's current MIT notice; it is not an assertion that every
binary in that wheel is MIT-licensed. The eSpeak NG native library has separate
GPL terms, with corresponding source linked from the project credits.

ONNX Runtime and NumPy include additional component notices, which are copied
in full. The SoundFile wheel also contains a libsndfile notice. The Kokoro
model's Apache licence remains in `../LICENSE-Kokoro.txt`.

See [the full project credits](../../CREDITS.md) for package authors, source links,
upstream model/data acknowledgements and academic references.
