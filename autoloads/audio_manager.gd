extends Node

## Manages playback of music, ambient tracks, and sound effects.
##
## Architectural Rule: AudioManager reads volume configurations directly from
## SettingsManager or reacts to EventBus settings signals. It does not maintain
## its own divergent copy of volume settings.
