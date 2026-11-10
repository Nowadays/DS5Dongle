#!/usr/bin/env python3
"""
Print the dongle's internal USB / wake / shortcut state.

Reads HID feature report 0xF9, whose bytes 2+ carry firmware diagnostics
(src/cmd.cpp). Use it when the controller is on but nothing reaches the PC:
it shows which part of the firmware is stuck without needing a serial build.

Requires: pip install hidapi
Run:      python dongle_diag.py [--watch]
"""
import sys
import time

try:
    import hid
except ImportError:
    sys.exit("Missing dependency. Install with:  pip install hidapi")

VID = 0x054C
PIDS = (0x0CE6, 0x0DF2)
WAKE_STATES = ["IDLE", "PENDING_PRESS", "REQUESTED", "KEY_DOWN", "KEY_UP_SENT", "DONE"]


def flags(value, names):
    return ", ".join(n for i, n in enumerate(names) if value & (1 << i)) or "-"


def read_once(dev):
    r = bytes(dev.get_feature_report(0xF9, 64))
    if r and r[0] == 0xF9:
        r = r[1:]
    rssi = r[0] - 256 if r[0] > 127 else r[0]
    if len(r) < 14 or r[2] != 0xD1:
        return f"rssi={rssi}  (firmware has no diagnostics)"
    usb, ready, sc = r[3], r[4], r[5]
    state, host_susp, susp, res, mounts, req, forced, timeouts = r[6:14]
    wake = WAKE_STATES[state] if state < len(WAKE_STATES) else str(state)
    return "\n".join([
        f"rssi={rssi}",
        "usb:       " + flags(usb, ["mounted", "SUSPENDED", "keyboard-only", "RECONFIGURING",
                                    "bt-connected", "show-controller-pending"]),
        "hid ready: " + flags(ready, ["gamepad", "keyboard", "consumer"]),
        "shortcuts: " + flags(sc, ["available", "release-pending", "kbd-clear-pending",
                                   "consumer-clear-pending", "wake-owns-keyboard", "learning",
                                   "host-sleep-pending", "kbd-dirty"]),
        f"wake:      state={wake} host_suspended={host_susp} suspends={susp} resumes={res} "
        f"mounts={mounts} wake_requests={req} forced={forced} stuck_timeouts={timeouts}",
    ])


def main():
    cand = [d for d in hid.enumerate(VID) if d["product_id"] in PIDS
            and d.get("usage_page") == 0x01 and d.get("usage") == 0x05]
    if not cand:
        sys.exit("No ds5dongle gamepad interface found (controller off, or keyboard-only mode).")
    dev = hid.device()
    dev.open_path(cand[0]["path"])
    try:
        while True:
            print(read_once(dev))
            if "--watch" not in sys.argv:
                break
            print("-" * 40)
            time.sleep(1)
    finally:
        dev.close()


if __name__ == "__main__":
    main()
