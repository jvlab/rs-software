# docs/hook_site_config.py
from urllib.parse import urlparse

SITE_PREFIX: str = ""

def update_site_prefix(config):
    global SITE_PREFIX
    site_url = config.get("site_url", "")
    SITE_PREFIX = urlparse(site_url).path.rstrip("/")
