#include "ps_shortcut.h"
#include "config.h"
#include "tusb.h"
#include "class/hid/hid.h"
#include "pico/time.h"

#define PS_KBD_INSTANCE 1

static bool ps_was_pressed       = false;
static uint32_t ps_press_time    = 0;
static bool long_press_fired     = false;
static bool key_release_pending  = false;
static uint32_t key_release_time = 0;
static uint32_t last_high_time   = 0;
static bool is_ps_pressed        = false;
static bool combo_fired          = false;

void ps_shortcut_reset() {
    if (key_release_pending && tud_hid_n_ready(PS_KBD_INSTANCE)) {
        tud_hid_n_keyboard_report(PS_KBD_INSTANCE, 0, 0, NULL);
    }
    ps_was_pressed      = false;
    ps_press_time       = 0;
    long_press_fired    = false;
    key_release_pending = false;
    key_release_time    = 0;
    last_high_time      = 0;
    is_ps_pressed       = false;
    combo_fired         = false;
}

void ps_shortcut_tick(const uint8_t *data, uint16_t len) {
    if (len < 10) return;
    // The HID keyboard interface (PS_KBD_INSTANCE) is only enumerated when wake
    // or the Game Bar shortcut is on (see usb_descriptors.cpp); the display-profile
    // combos below work whenever it is present, PS -> Game Bar stays gated on
    // ps_shortcut_enabled.
    const bool ps_enabled = get_config().ps_shortcut_enabled;
    if (!ps_enabled && !get_config().enable_wake) return;

    uint32_t now = to_ms_since_boot(get_absolute_time());

    if (key_release_pending && now >= key_release_time) {
        if (tud_hid_n_ready(PS_KBD_INSTANCE)) {
            tud_hid_n_keyboard_report(PS_KBD_INSTANCE, 0, 0, NULL);
            key_release_pending = false;
        }
    }

    // Display-profile combos: L1+R1+L2+R2 held + D-pad direction sends a
    // Ctrl+Alt+Shift hotkey (Display Magician profile switch). Edge-triggered:
    // one keystroke per D-pad press; releasing the D-pad (hat back to 8) while
    // keeping the shoulders held re-arms, so profiles can be switched in a row.
    const uint8_t hat = data[7] & 0x0F;          // 0=Up 2=Right 4=Down 6=Left 8=idle
    const bool shoulders_held = (data[8] & 0x0F) == 0x0F; // L1|R1|L2|R2
    if (!shoulders_held || hat == 8) combo_fired = false;
    if (shoulders_held && !combo_fired && !key_release_pending) {
        uint8_t combo_key = 0;
        if (hat == 0)      combo_key = HID_KEY_G; // Up   -> Ctrl+Alt+Shift+G
        else if (hat == 6) combo_key = HID_KEY_D; // Left -> Ctrl+Alt+Shift+D
        else if (hat == 4) combo_key = HID_KEY_S; // Down  -> Ctrl+Alt+Shift+S (host shutdown hotkey)
        else if (hat == 2) combo_key = HID_KEY_A; // Right -> Ctrl+Alt+Shift+A (cancel shutdown)
        if (combo_key && tud_hid_n_ready(PS_KBD_INSTANCE)) {
            uint8_t keys[6] = { combo_key };
            tud_hid_n_keyboard_report(PS_KBD_INSTANCE, 0,
                KEYBOARD_MODIFIER_LEFTCTRL | KEYBOARD_MODIFIER_LEFTALT | KEYBOARD_MODIFIER_LEFTSHIFT,
                keys);
            combo_fired         = true;
            key_release_pending = true;
            key_release_time    = now + 30;
        }
    }

    if (!ps_enabled) return;

    bool raw_ps = (data[9] & 0x01) != 0;

    if (raw_ps) {
        is_ps_pressed = true;
        last_high_time = now;
    } else if (now - last_high_time > 50) {
        is_ps_pressed = false;
    }

    if (is_ps_pressed && !ps_was_pressed) {
        ps_press_time    = now;
        ps_was_pressed   = true;
        long_press_fired = false;
    } else if (is_ps_pressed && ps_was_pressed) {
        if (!long_press_fired && (now - ps_press_time >= 750)) {
            if (tud_hid_n_ready(PS_KBD_INSTANCE)) {
                uint8_t keys[6] = { HID_KEY_TAB };
                tud_hid_n_keyboard_report(PS_KBD_INSTANCE, 0, KEYBOARD_MODIFIER_LEFTGUI, keys);
                long_press_fired    = true;
                key_release_pending = true;
                key_release_time    = now + 30;
            }
        }
    } else if (!is_ps_pressed && ps_was_pressed) {
        if (!long_press_fired) {
            if (tud_hid_n_ready(PS_KBD_INSTANCE)) {
                uint8_t keys[6] = { HID_KEY_G };
                tud_hid_n_keyboard_report(PS_KBD_INSTANCE, 0, KEYBOARD_MODIFIER_LEFTGUI, keys);
                key_release_pending = true;
                key_release_time    = now + 30;
            }
        }
        ps_was_pressed = false;
    }
}
