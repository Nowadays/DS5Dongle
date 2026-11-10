//
// Created by awalol on 2026/3/4.
//

#ifndef DS5_BRIDGE_USB_H
#define DS5_BRIDGE_USB_H

#include <cstdint>

extern bool usb_keyboard_only;
extern bool usb_reconfiguring;
uint8_t usb_keyboard_instance();
void usb_reconnect(bool keyboard_only);
// A controller just connected: re-plug as the full USB device so the host sets
// it up afresh. Deferred to usb_task() while the host is asleep.
void usb_show_controller();
void usb_task();
bool usb_show_controller_pending();

extern uint8_t mute[2]; // 0: SPEAKER(0x02) 1: MIC(0x05)
extern float volume[2]; // 0: SPEAKER(0x02) 1: MIC(0x05)

#endif //DS5_BRIDGE_USB_H
