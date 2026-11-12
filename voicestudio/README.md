# VoiceStudio: TXT → Audio + SRT

Custom integration for VoiceStudio 0.5.8 Windows x64. The existing clone-output
save button saves WAV/MP3 and SRT together. Multi-TXT imports render and export
pairs sequentially after one destination-folder selection.

The workflow builds from upstream tag `v0.5.8`, applies `source.patch`, validates
the official installer SHA256, and replaces only the compiled Electron UI/main
and three backend source files. Existing native Windows helpers are retained
from the verified official installer. No voice models or user data are included.

Outputs are attached to the **draft** release
`voicestudio-txt-srt-0.5.8-20261112`. The repository owner can download them while
signed in; publication is not required. Read the Vietnamese guide before running
`UPDATE.cmd`. This is a custom test build, not an official VoiceStudio release.

The workflow tests file timing, paired exports and updater logic without model
inference. Windows GPU inference and speech quality still need checking on the
actual user's hardware. The separate `SOURCE.zip` provides corresponding source.

Upstream: https://github.com/debpalash/VoiceStudio/tree/v0.5.8 — AGPL-3.0.
Model licenses and voice consent requirements are unchanged.
