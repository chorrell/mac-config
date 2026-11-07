"""Unit tests for the keyboard role's caps_lock module.

IOKit is replaced by FakeHIDSystem, so these run anywhere. The Molecule run on
macOS exercises the real IOKit calls through the keyboard role.
"""

import json

import caps_lock
import pytest
from ansible.module_utils.testing import patch_module_args


class FakeHIDSystem:
    """Stands in for caps_lock.HIDSystem and records what the module does."""

    def __init__(self, caps_lock_on, sticks=True):
        self.state = caps_lock_on
        self.sticks = sticks  # False simulates a set that has no effect
        self.set_calls = []
        self.closed = False

    def __call__(self):
        return self

    def caps_lock(self):
        return self.state

    def set_caps_lock(self, enabled):
        self.set_calls.append(enabled)
        if self.sticks:
            self.state = enabled

    def close(self):
        self.closed = True


def run_module(monkeypatch, capsys, hid, **args):
    """Run caps_lock.main() with hid in place of IOKit and return its JSON result."""
    monkeypatch.setattr(caps_lock, "HIDSystem", hid)
    with patch_module_args(args), pytest.raises(SystemExit) as exit_info:
        caps_lock.main()
    result = json.loads(capsys.readouterr().out)
    result["rc"] = exit_info.value.code
    return result


def test_already_off_is_unchanged(monkeypatch, capsys):
    hid = FakeHIDSystem(caps_lock_on=False)
    result = run_module(monkeypatch, capsys, hid)
    assert result["rc"] == 0
    assert result["changed"] is False
    assert result["enabled"] is False
    assert hid.set_calls == []
    assert hid.closed


def test_turns_caps_lock_off(monkeypatch, capsys):
    hid = FakeHIDSystem(caps_lock_on=True)
    result = run_module(monkeypatch, capsys, hid, enabled=False)
    assert result["rc"] == 0
    assert result["changed"] is True
    assert hid.set_calls == [False]
    assert hid.state is False
    assert hid.closed


def test_turns_caps_lock_on(monkeypatch, capsys):
    hid = FakeHIDSystem(caps_lock_on=False)
    result = run_module(monkeypatch, capsys, hid, enabled=True)
    assert result["changed"] is True
    assert result["enabled"] is True
    assert hid.set_calls == [True]


def test_check_mode_reports_change_without_setting(monkeypatch, capsys):
    hid = FakeHIDSystem(caps_lock_on=True)
    result = run_module(monkeypatch, capsys, hid, _ansible_check_mode=True)
    assert result["rc"] == 0
    assert result["changed"] is True
    assert hid.set_calls == []
    assert hid.state is True


def test_fails_when_set_does_not_take_effect(monkeypatch, capsys):
    hid = FakeHIDSystem(caps_lock_on=True, sticks=False)
    result = run_module(monkeypatch, capsys, hid)
    assert result["rc"] == 1
    assert result["failed"] is True
    assert "still on" in result["msg"]
    assert hid.closed


def test_iokit_error_fails_the_module(monkeypatch, capsys):
    def broken_hid_system():
        raise OSError("IOHIDSystem service not found")

    result = run_module(monkeypatch, capsys, broken_hid_system)
    assert result["rc"] == 1
    assert result["msg"] == "IOHIDSystem service not found"


@pytest.mark.parametrize(
    ("code", "expected"),
    [
        (-536870212, "0xe00002bc"),  # kIOReturnError, as a signed kern_return_t
        (0xE00002C2, "0xe00002c2"),  # kIOReturnBadArgument
    ],
)
def test_check_formats_iokit_errors(code, expected):
    with pytest.raises(OSError, match=f"IOServiceOpen failed with IOKit error {expected}"):
        caps_lock.HIDSystem._check(code, "IOServiceOpen")


def test_check_accepts_success():
    caps_lock.HIDSystem._check(0, "IOServiceOpen")
