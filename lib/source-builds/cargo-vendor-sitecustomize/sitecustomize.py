"""Python startup hook for nixpkgs fetchCargoVendor.

crates.io rejects generic Python requests clients on the crate download API.
fetch-cargo-vendor-util uses requests directly, so set a descriptive default
User-Agent before it creates its HTTP sessions.
"""

from __future__ import annotations

try:
    import requests

    _USER_AGENT = "nix-source-builds/1.0 (https://github.com/BSteffaniak)"
    _original_request = requests.sessions.Session.request

    def _request_with_user_agent(self, method, url, **kwargs):
        headers = dict(kwargs.pop("headers", {}) or {})
        if not any(key.lower() == "user-agent" for key in headers):
            headers["User-Agent"] = _USER_AGENT
        kwargs["headers"] = headers
        return _original_request(self, method, url, **kwargs)

    requests.sessions.Session.request = _request_with_user_agent
except Exception:
    # Never make Python startup fail; without this hook fetchCargoVendor will
    # simply fall back to its default requests behavior.
    pass
