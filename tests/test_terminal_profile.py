"""Unit tests for the terminal role's terminal_profile module.

`defaults` and `plutil` are replaced by FakeDefaults, so these run anywhere.
The Molecule run on macOS exercises the real commands through the terminal role.
"""

import json
import plistlib

import pytest
import terminal_profile
from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.testing import patch_module_args

DOMAIN = "com.apple.Terminal"
COLOR = b"bplist00 fake NSColor archive"


class FakeDefaults:
    """Stands in for AnsibleModule.run_command, backed by an in-memory domain."""

    def __init__(self, prefs=None, sticks=True):
        self.prefs = prefs if prefs is not None else {}
        self.sticks = sticks  # False simulates a write that has no effect
        self.writes = []

    def __call__(self, args, check_rc=False, data=None, **kwargs):
        if args[:2] == ["defaults", "export"]:
            return 0, plistlib.dumps(self.prefs), b""
        if args[0] == "plutil":
            fmt = {"binary1": plistlib.FMT_BINARY, "xml1": plistlib.FMT_XML}[args[2]]
            try:
                return 0, plistlib.dumps(plistlib.loads(data), fmt=fmt), b""
            except Exception as err:
                return 1, b"", str(err).encode()
        if args[:2] == ["defaults", "write"]:
            _, _, domain, key, flag, name, value = args
            assert (domain, key, flag) == (DOMAIN, "Window Settings", "-dict-add")
            self.writes.append(name)
            if self.sticks:
                self.prefs.setdefault(key, {})[name] = plistlib.loads(value.encode())
            return 0, "", ""
        raise AssertionError(f"unexpected command {args}")


@pytest.fixture
def profile_file(tmp_path):
    path = tmp_path / "Panic Palette.terminal"
    path.write_bytes(
        plistlib.dumps(
            {"name": "Panic Palette", "type": "Window Settings", "BackgroundColor": COLOR, "columnCount": 125}
        )
    )
    return path


def run_module(monkeypatch, capsys, defaults, **args):
    """Run terminal_profile.main() against defaults and return its JSON result."""
    monkeypatch.setattr(AnsibleModule, "run_command", lambda _module, args, **kwargs: defaults(args, **kwargs))
    with patch_module_args(args), pytest.raises(SystemExit) as exit_info:
        terminal_profile.main()
    result = json.loads(capsys.readouterr().out)
    result["rc"] = exit_info.value.code
    return result


def test_imports_into_an_empty_domain(monkeypatch, capsys, profile_file):
    defaults = FakeDefaults()
    result = run_module(monkeypatch, capsys, defaults, name="Panic Palette", src=str(profile_file))
    assert result["rc"] == 0
    assert result["changed"] is True
    assert result["changed_keys"] == ["BackgroundColor", "columnCount", "name", "type"]
    assert defaults.prefs["Window Settings"]["Panic Palette"]["BackgroundColor"] == COLOR


def test_matching_profile_is_unchanged(monkeypatch, capsys, profile_file):
    profile = plistlib.loads(profile_file.read_bytes())
    defaults = FakeDefaults({"Window Settings": {"Panic Palette": profile}})
    result = run_module(monkeypatch, capsys, defaults, name="Panic Palette", src=str(profile_file))
    assert result["rc"] == 0
    assert result["changed"] is False
    assert defaults.writes == []


def test_merges_and_keeps_other_settings_and_profiles(monkeypatch, capsys, profile_file):
    existing = {"name": "Panic Palette", "columnCount": 80, "useOptionAsMetaKey": True}
    defaults = FakeDefaults({"Window Settings": {"Panic Palette": existing, "Basic": {"name": "Basic"}}})
    result = run_module(monkeypatch, capsys, defaults, name="Panic Palette", src=str(profile_file))
    assert result["changed"] is True
    assert result["changed_keys"] == ["BackgroundColor", "columnCount", "type"]
    profile = defaults.prefs["Window Settings"]["Panic Palette"]
    assert profile["columnCount"] == 125
    assert profile["useOptionAsMetaKey"] is True
    assert defaults.prefs["Window Settings"]["Basic"] == {"name": "Basic"}


def test_name_option_renames_the_profile(monkeypatch, capsys, profile_file):
    defaults = FakeDefaults()
    run_module(monkeypatch, capsys, defaults, name="Panic", src=str(profile_file))
    assert defaults.prefs["Window Settings"]["Panic"]["name"] == "Panic"


def test_check_mode_reports_change_with_diff(monkeypatch, capsys, profile_file):
    defaults = FakeDefaults()
    result = run_module(
        monkeypatch,
        capsys,
        defaults,
        name="Panic Palette",
        src=str(profile_file),
        _ansible_check_mode=True,
        _ansible_diff=True,
    )
    assert result["changed"] is True
    assert defaults.writes == []
    assert result["diff"]["before"] == ""
    assert "columnCount: 125" in result["diff"]["after"]
    assert f"BackgroundColor: <data {len(COLOR)} bytes" in result["diff"]["after"]


def test_fails_when_write_does_not_take_effect(monkeypatch, capsys, profile_file):
    defaults = FakeDefaults(sticks=False)
    result = run_module(monkeypatch, capsys, defaults, name="Panic Palette", src=str(profile_file))
    assert result["rc"] == 1
    assert "does not match" in result["msg"]


def test_unreadable_file_fails(monkeypatch, capsys, tmp_path):
    bad = tmp_path / "bad.terminal"
    bad.write_text("not a plist")
    result = run_module(monkeypatch, capsys, FakeDefaults(), name="Panic Palette", src=str(bad))
    assert result["rc"] == 1
    assert "plutil could not read" in result["msg"]


def test_missing_file_fails(monkeypatch, capsys, tmp_path):
    result = run_module(monkeypatch, capsys, FakeDefaults(), name="Panic Palette", src=str(tmp_path / "none"))
    assert result["rc"] == 1
    assert "Could not read" in result["msg"]


def test_describe_summarises_data():
    assert terminal_profile.describe(b"abc").startswith("<data 3 bytes, sha256 ba7816bf8f01")
    assert terminal_profile.describe(125) == "125"
