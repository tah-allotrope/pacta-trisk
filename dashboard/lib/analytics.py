from __future__ import annotations

import os
import threading
import urllib.parse
import urllib.request


def _endpoint() -> str | None:
    return os.environ.get("PILOT_ANALYTICS_ENDPOINT") or None


def is_analytics_enabled() -> bool:
    return _endpoint() is not None


def _send(url: str, page_slug: str) -> None:
    try:
        query = urllib.parse.urlencode({"p": f"/{page_slug}"})
        req = urllib.request.Request(f"{url}?{query}", headers={"User-Agent": "pacta-trisk-pilot"})
        urllib.request.urlopen(req, timeout=2)
    except Exception:
        pass


def track_page_view(page_slug: str) -> None:
    """Fire an anonymous, PII-free page-view ping if analytics is configured.

    No-op unless PILOT_ANALYTICS_ENDPOINT is set. Payload is only the page
    slug — no user identity, IP is handled by the counter service, not us.
    Runs in a background thread so it never blocks page render.
    """
    url = _endpoint()
    if url is None:
        return
    threading.Thread(target=_send, args=(url, page_slug), daemon=True).start()
