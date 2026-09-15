extends Node

## Single source of truth for persistent user preferences.
##
## Architectural Rule: Never create a second source of truth for state that an
## autoload owns (e.g. do not cache volume levels or input bindings in UI scripts).
## UI controls display current SettingsManager values and forward user changes back to it.
## Settings data is persisted to its own dedicated configuration file, strictly separated
## from gameplay save files.
