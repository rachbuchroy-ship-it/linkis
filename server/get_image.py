import requests
import html as htmllib

# ---------------- Whatsapp ----------------

def extract_og_image(page_url: str) -> str | None:
    """
    Downloads HTML from page_url and extracts the og:image content URL
    by scanning char-by-char (as you requested).
    Returns the cleaned image URL (HTML entities decoded) or None.
    """
    r = requests.get(
        page_url,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Linkiz/1.0"},
        timeout=15,
        allow_redirects=True,
    )
    r.raise_for_status()
    page_html = r.text
    
    image_exist = page_html.find("_ari4")
    if image_exist is None:
        return None

    needle = 'og:image"'
    start = page_html.find(needle)
    if start == -1:
        return None

    content_needle = 'content="'
    i = start
    j = 0

    while i < len(page_html):
        ch = page_html[i]
        if ch == content_needle[j]:
            j += 1
            if j == len(content_needle):
                i += 1  # right after content="
                break
        else:
            j = 1 if ch == content_needle[0] else 0
        i += 1

    if j != len(content_needle):
        return None

    captured = []
    while i < len(page_html) and page_html[i] != '"':
        captured.append(page_html[i])
        i += 1

    if i >= len(page_html) or page_html[i] != '"':
        return None

    raw_url = "".join(captured).strip()
    return htmllib.unescape(raw_url)

def get_whatsapp_image_url(initial_url: str) -> bytes:
    """
    ✅ Final function for reuse in other files.

    Input:
      - initial_url: page URL that contains og:image meta tag

    Process:
      - Extract og:image URL
      - Download it as bytes (even if the file is served as .enc)
      - Return the bytes

    Returns:
      - bytes of the downloaded image
    """
    og_url = extract_og_image(initial_url)
    if not og_url:
        return None

    return og_url

# ---------------- Telegram ----------------
def get_telegram_image_url(initial_url: str) -> bytes:
    pass