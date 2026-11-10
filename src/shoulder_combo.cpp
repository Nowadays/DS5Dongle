#include "shoulder_combo.h"

#include "button_shortcut.h"
#include "class/hid/hid.h"
#include "pico/time.h"
#include "utils.h"

static constexpr uint8_t COMBO_MODIFIERS =
        KEYBOARD_MODIFIER_LEFTCTRL | KEYBOARD_MODIFIER_LEFTALT | KEYBOARD_MODIFIER_LEFTSHIFT;
static constexpr uint32_t OVERLAY_HOLD_MS = 300;

static bool combo_fired = false;
static uint32_t shoulders_since = 0;
static bool hold_combo_used = false;
static bool overlay_shown = false;

void shoulder_combo_reset() {
    combo_fired = false;
    shoulders_since = 0;
    hold_combo_used = false;
    overlay_shown = false;
}

void shoulder_combo_tick(const USBGetStateData &state) {
    const uint32_t now = to_ms_since_boot(get_absolute_time());
    const bool shoulders_held =
            state.ButtonL1 && state.ButtonR1 && state.ButtonL2 && state.ButtonR2;
    const bool dpad_idle = state.DPad > NorthWest;

    // Display-profile combos: shoulders held + D-pad direction sends a
    // Ctrl+Alt+Shift hotkey. Edge-triggered: one keystroke per D-pad press;
    // releasing the D-pad while keeping the shoulders held re-arms, so several
    // can be sent in a row.
    if (!shoulders_held || dpad_idle) combo_fired = false;
    if (shoulders_held && !combo_fired) {
        uint8_t key = 0;
        switch (state.DPad) {
            case North: key = HID_KEY_G; break; // gaming display profile
            case West:  key = HID_KEY_D; break; // desktop display profile
            case South: key = HID_KEY_S; break; // host shutdown hotkey
            case East:  key = HID_KEY_A; break; // cancel shutdown
            default: break;
        }
        if (key && button_shortcut_send_pulse(COMBO_MODIFIERS, key)) {
            combo_fired = true;
            hold_combo_used = true;
        }
    }

    // Cheat-sheet overlay: shoulders held alone for 300 ms -> Ctrl+Alt+Shift+O
    // (host shows tools/combo-overlay.ps1); releasing them -> Ctrl+Alt+Shift+H
    // (hide). Skipped when a D-pad combo was already used during this hold.
    // O and H sit at the same place on QWERTY and AZERTY.
    if (shoulders_held) {
        if (shoulders_since == 0) shoulders_since = now ? now : 1;
        if (!overlay_shown && !hold_combo_used && dpad_idle &&
            now - shoulders_since >= OVERLAY_HOLD_MS &&
            button_shortcut_send_pulse(COMBO_MODIFIERS, HID_KEY_O)) {
            overlay_shown = true;
        }
    } else {
        shoulders_since = 0;
        hold_combo_used = false;
        if (overlay_shown && button_shortcut_send_pulse(COMBO_MODIFIERS, HID_KEY_H)) {
            overlay_shown = false;
        }
    }
}
