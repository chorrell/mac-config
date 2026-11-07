#!/usr/bin/python
"""Ansible module that turns Caps Lock on or off on macOS."""

from __future__ import annotations

import ctypes
import ctypes.util

from ansible.module_utils.basic import AnsibleModule

DOCUMENTATION = r"""
---
module: caps_lock
short_description: Turn Caps Lock on or off on macOS
description:
  - Reads and sets the Caps Lock state through IOKit's IOHIDSystem, the same
    state the Caps Lock key toggles.
  - Run it before disabling the Caps Lock key, which would otherwise leave
    Caps Lock stuck on.
options:
  enabled:
    description: Whether Caps Lock should be on.
    type: bool
    default: false
"""

EXAMPLES = r"""
- name: Turn Caps Lock off
  caps_lock:
    enabled: false
"""

RETURN = r"""
enabled:
  description: Whether Caps Lock is on after the module runs.
  type: bool
  returned: always
"""

IOKIT = "/System/Library/Frameworks/IOKit.framework/IOKit"
K_IO_HID_PARAM_CONNECT_TYPE = 1  # kIOHIDParamConnectType
K_IO_HID_CAPS_LOCK_STATE = 1  # kIOHIDCapsLockState


class HIDSystem:
    """A connection to IOHIDSystem, which holds the Caps Lock state."""

    def __init__(self):
        self.iokit = ctypes.cdll.LoadLibrary(IOKIT)
        libc = ctypes.cdll.LoadLibrary(ctypes.util.find_library("c"))
        iokit = self.iokit
        iokit.IOServiceMatching.restype = ctypes.c_void_p
        iokit.IOServiceMatching.argtypes = [ctypes.c_char_p]
        iokit.IOServiceGetMatchingService.restype = ctypes.c_uint
        iokit.IOServiceGetMatchingService.argtypes = [ctypes.c_uint, ctypes.c_void_p]
        iokit.IOServiceOpen.argtypes = [
            ctypes.c_uint,
            ctypes.c_uint,
            ctypes.c_uint,
            ctypes.POINTER(ctypes.c_uint),
        ]
        iokit.IOServiceClose.argtypes = [ctypes.c_uint]
        iokit.IOObjectRelease.argtypes = [ctypes.c_uint]
        iokit.IOHIDGetModifierLockState.argtypes = [
            ctypes.c_uint,
            ctypes.c_int,
            ctypes.POINTER(ctypes.c_bool),
        ]
        iokit.IOHIDSetModifierLockState.argtypes = [ctypes.c_uint, ctypes.c_int, ctypes.c_bool]

        # kIOMainPortDefault is 0; IOServiceGetMatchingService consumes the dictionary
        service = iokit.IOServiceGetMatchingService(0, iokit.IOServiceMatching(b"IOHIDSystem"))
        if not service:
            raise OSError("IOHIDSystem service not found")
        task = ctypes.c_uint.in_dll(libc, "mach_task_self_").value
        connect = ctypes.c_uint()
        result = iokit.IOServiceOpen(service, task, K_IO_HID_PARAM_CONNECT_TYPE, ctypes.byref(connect))
        iokit.IOObjectRelease(service)
        self._check(result, "IOServiceOpen")
        self.connect = connect.value

    @staticmethod
    def _check(result, call):
        if result != 0:
            raise OSError(f"{call} failed with IOKit error {result & 0xFFFFFFFF:#010x}")

    def caps_lock(self):
        state = ctypes.c_bool()
        result = self.iokit.IOHIDGetModifierLockState(self.connect, K_IO_HID_CAPS_LOCK_STATE, ctypes.byref(state))
        self._check(result, "IOHIDGetModifierLockState")
        return state.value

    def set_caps_lock(self, enabled):
        result = self.iokit.IOHIDSetModifierLockState(self.connect, K_IO_HID_CAPS_LOCK_STATE, enabled)
        self._check(result, "IOHIDSetModifierLockState")

    def close(self):
        self.iokit.IOServiceClose(self.connect)


def main():
    module = AnsibleModule(
        argument_spec={"enabled": {"type": "bool", "default": False}},
        supports_check_mode=True,
    )
    wanted = module.params["enabled"]

    try:
        hid = HIDSystem()
        try:
            changed = hid.caps_lock() != wanted
            if changed and not module.check_mode:
                hid.set_caps_lock(wanted)
                if hid.caps_lock() != wanted:
                    module.fail_json(msg=f"Caps Lock is still {'off' if wanted else 'on'} after setting it")
        finally:
            hid.close()
    except OSError as err:
        module.fail_json(msg=str(err))

    module.exit_json(changed=changed, enabled=wanted)


if __name__ == "__main__":
    main()
