#!/usr/bin/python
"""Ansible module that imports a Terminal.app profile from a .terminal file."""

import hashlib
import plistlib

from ansible.module_utils.basic import AnsibleModule

DOCUMENTATION = r"""
---
module: terminal_profile
short_description: Import a Terminal.app profile from a .terminal file
description:
  - Merges the settings in a C(.terminal) file (a profile exported from
    Terminal.app) into the named profile under C(Window Settings) in the
    Terminal preferences. Settings the file does not list are left alone.
  - Reads and writes through C(defaults), so cfprefsd sees the change.
    C(community.general.osx_defaults) can't do this, because a profile holds
    nested data values (colours and the font).
  - Terminal keeps its profiles in memory, so quit and reopen it to see a
    change made while it is running.
options:
  name:
    description: Name of the profile in Terminal.
    type: str
    required: true
  src:
    description: Path to the C(.terminal) file to import.
    type: path
    required: true
  domain:
    description: Preferences domain to write to.
    type: str
    default: com.apple.Terminal
"""

EXAMPLES = r"""
- name: Import the Panic Palette profile
  terminal_profile:
    name: Panic Palette
    src: "{{ role_path }}/files/Panic Palette.terminal"
"""

RETURN = r"""
changed_keys:
  description: Profile settings that were added or changed.
  type: list
  elements: str
  returned: always
"""


def plutil_convert(module, data, fmt, what):
    """Convert plist bytes to fmt (binary1 or xml1) with plutil."""
    rc, out, err = module.run_command(
        ["plutil", "-convert", fmt, "-o", "-", "-"], data=data, binary_data=True, encoding=None
    )
    if rc != 0:
        module.fail_json(msg=f"plutil could not read {what}: {err}")
    return out


def load_plist(module, data, what):
    """Parse plist bytes in any format.

    XML from Terminal can hold raw control characters (key bindings do), which
    plistlib rejects and plutil accepts, so go through binary.
    """
    try:
        return plistlib.loads(plutil_convert(module, data, "binary1", what))
    except plistlib.InvalidFileException as err:
        module.fail_json(msg=f"Could not read {what}: {err}")


def read_domain(module, domain):
    """Return the preferences in domain as a dict ({} if it does not exist)."""
    rc, out, err = module.run_command(["defaults", "export", domain, "-"], binary_data=True, encoding=None)
    if rc != 0:
        module.fail_json(msg=f"defaults export {domain} failed: {err}")
    return load_plist(module, out, f"the {domain} preferences")


def describe(value):
    """Short, diff-friendly text for a plist value."""
    if isinstance(value, bytes):
        return f"<data {len(value)} bytes, sha256 {hashlib.sha256(value).hexdigest()[:12]}>"
    return repr(value)


def as_text(profile, keys):
    return "".join(f"{key}: {describe(profile[key])}\n" for key in keys if key in profile)


def main():
    module = AnsibleModule(
        argument_spec={
            "name": {"type": "str", "required": True},
            "src": {"type": "path", "required": True},
            "domain": {"type": "str", "default": "com.apple.Terminal"},
        },
        supports_check_mode=True,
    )
    name = module.params["name"]
    domain = module.params["domain"]

    try:
        with open(module.params["src"], "rb") as src:
            data = src.read()
    except OSError as err:
        module.fail_json(msg=f"Could not read {module.params['src']}: {err}")
    settings = load_plist(module, data, module.params["src"])
    if not isinstance(settings, dict):
        module.fail_json(msg=f"{module.params['src']} does not hold a profile")
    settings["name"] = name

    current = read_domain(module, domain).get("Window Settings", {}).get(name, {})
    wanted = {**current, **settings}
    changed_keys = sorted(key for key, value in settings.items() if current.get(key) != value)
    changed = bool(changed_keys)

    result = {"changed": changed, "changed_keys": changed_keys}
    if module._diff:
        result["diff"] = {
            "before_header": f"{domain} Window Settings: {name}",
            "after_header": f"{domain} Window Settings: {name}",
            "before": as_text(current, changed_keys),
            "after": as_text(wanted, changed_keys),
        }

    if changed and not module.check_mode:
        # plistlib can't write control characters as XML, so let plutil do it
        binary = plistlib.dumps(wanted, fmt=plistlib.FMT_BINARY)
        value = plutil_convert(module, binary, "xml1", "the new profile").decode()
        module.run_command(["defaults", "write", domain, "Window Settings", "-dict-add", name, value], check_rc=True)
        if read_domain(module, domain).get("Window Settings", {}).get(name) != wanted:
            module.fail_json(msg=f"The {name} profile does not match {module.params['src']} after writing it")

    module.exit_json(**result)


if __name__ == "__main__":
    main()
