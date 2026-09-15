extends Node

## Tracks, calculates, and persists player achievements.
##
## Architectural Rule: Achievements are data-driven custom Resources (.tres instances),
## not hardcoded code logic. New achievements can be added by creating resource files
## without modifying manager code. Progress and unlock states are persisted to an
## independent achievements file on disk, separated from game save slots.
