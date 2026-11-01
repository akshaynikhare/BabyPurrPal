extends Node
## Global signal hub. The stage (pets, talk-back) and the UI layer only talk through these.

signal app_paused
signal app_resumed
signal settings_changed(key: StringName, value: Variant)

# Talk-back (emitted by scripts/talkback)
signal talkback_state_changed(state: StringName)
signal mouth_amplitude_changed(value: float)
signal mic_permission_changed(granted: bool)

# Pet stage (emitted by the stage)
signal pet_changed(index: int, pet_name: String)
signal pet_reacted(zone: StringName)
signal zoom_changed(zoomed: bool)
signal time_phase_changed(phase: StringName)
## A toy session runs from started to finished (also on cancel); the toy bar stays locked between.
signal toy_started(toy_id: StringName)
signal toy_finished(toy_id: StringName)

# Requests from the UI to the stage
signal next_pet_requested
signal previous_pet_requested
signal zoom_toggle_requested
signal time_phase_cycle_requested
signal toy_used(toy_id: StringName)
signal test_voice_requested
signal settings_opened
signal settings_closed
