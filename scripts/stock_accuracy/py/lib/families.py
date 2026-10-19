"""Item 'family' key: same brand + sub-category + pet type + name stripped of size/colour/pack tokens."""
import re
SIZE = re.compile(r"\b(\d+(\.\d+)?\s*(kg|g|gm|gr|ml|l|lt|ltr|lb|lbs|oz|cm|mm|m|inch|in|pcs|pc|x\d+|pack|pk)|xs|s|m|l|xl|xxl|xxxl|small|medium|large|mini|maxi|jumbo|giant|x-large|xlarge|x-small)\b", re.I)
COLOR = re.compile(r"\b(black|white|red|blue|green|yellow|pink|purple|orange|grey|gray|brown|beige|lilac|turquoise|turquise|navy|gold|silver|teal|coral|cream|violet|multi|assorted|mixed)\b", re.I)
NUM = re.compile(r"\d+([.,]\d+)?")
PUNCT = re.compile(r"[^a-z0-9\s]")
STOP = {"with", "for", "and", "the", "of", "in", "a", "&", "-", "/", "x"}

def family_key(brand, p3, p4, name: str) -> str:
    n = (name or "").lower()
    n = PUNCT.sub(" ", n)
    n = SIZE.sub(" ", n); n = COLOR.sub(" ", n); n = NUM.sub(" ", n)
    toks = [t for t in n.split() if t not in STOP and len(t) > 1]
    stem = " ".join(toks[:4])
    return f"{brand}|{p3 or ''}|{p4 or ''}|{stem}"
