#pragma once

struct USBGetStateData;

// Fixed L1+R1+L2+R2 (+ D-pad) host hotkeys. The configurable shortcut slots only
// know two-button chords, so this four-button hold lives next to them and sends
// its keystrokes through button_shortcut_send_pulse(). Called by button_shortcut.cpp.
void shoulder_combo_tick(const USBGetStateData &state);
void shoulder_combo_reset();
