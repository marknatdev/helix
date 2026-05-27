"""
qr_generator.py
────────────────────────────────────────────────────────────────────────────
Builds a LoRa Alliance TR005 "Device Identification QR Code" string and
renders it as a PIL image.

Format (TR005 schema D0):
    LW:D0:<JoinEUI>:<DevEUI>:<ProfileID>[:<OwnerToken>]

ChirpStack v4 (and TTN, Helium, etc.) can scan this to import a device.
The AppKey is NOT included in the QR — it must be entered manually in the
ChirpStack web UI for security reasons.
────────────────────────────────────────────────────────────────────────────
"""
from __future__ import annotations

import qrcode
from PIL import Image


def _hex_clean(s: str, length: int) -> str:
    """Strip separators, uppercase, left-pad with zeros to `length` chars."""
    cleaned = s.replace(":", "").replace("-", "").replace(" ", "").upper()
    return cleaned.zfill(length)[:length]


def build_tr005(
    dev_eui: str,
    join_eui: str = "0000000000000000",
    profile_id: str = "00000000",
    owner_token: str = "",
) -> str:
    """Build a TR005 D0-schema device identification string."""
    dev    = _hex_clean(dev_eui, 16)
    join   = _hex_clean(join_eui, 16)
    profile = _hex_clean(profile_id, 8)
    parts = ["LW", "D0", join, dev, profile]
    if owner_token:
        parts.append(owner_token)
    return ":".join(parts)


def make_qr_image(text: str, size: int = 320) -> Image.Image:
    """Render `text` as a square PIL RGB image of the given pixel size."""
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=10,
        border=2,
    )
    qr.add_data(text)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white").convert("RGB")
    img = img.resize((size, size), Image.NEAREST)
    return img
