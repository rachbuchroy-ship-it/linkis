import requests
import html as htmllib

# ---------------- Whatsapp ----------------

def scan_after_two_needles(
    text: str,
    first_needle: str,
    second_needle: str,
    *,
    end_char: str = '"',
    start_pos: int = 0,
) -> str | None:
    """
    1) Finds first_needle in text (starting at start_pos).
    2) From there, scans char-by-char to find second_needle.
    3) Captures chars until end_char.
    Returns captured string (not unescaped) or None.
    """
    start = text.find(first_needle, start_pos)
    if start == -1:
        return None

    i = start
    j = 0  # match index for second_needle

    # scan for second_needle char-by-char
    while i < len(text):
        ch = text[i]
        if ch == second_needle[j]:
            j += 1
            if j == len(second_needle):
                i += 1  # move to the first char after second_needle
                break
        else:
            # overlap-friendly reset
            j = 1 if ch == second_needle[0] else 0
        i += 1

    if j != len(second_needle):
        return None

    # capture until end_char
    captured = []
    while i < len(text) and text[i] != end_char:
        captured.append(text[i])
        i += 1

    if i >= len(text) or text[i] != end_char:
        return None

    return "".join(captured).strip()


def extract_link_image(page_url: str) -> str | None:
    """
    Downloads HTML from page_url and extracts og:image content URL
    using the generic scanner.
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

    raw_url = scan_after_two_needles(
        page_html,
        first_needle='og:image"',
        second_needle='content="',
        end_char='"',
    )


    if raw_url is None:
        return None

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
    url = extract_link_image(initial_url)
    if not url:
        return None

    return url

# ---------------- Telegram ----------------
def get_telegram_image_url(initial_url: str) -> bytes:
    pass