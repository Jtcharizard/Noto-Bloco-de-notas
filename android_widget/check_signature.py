"""Confere se o APK foi assinado com a chave fixa do Noto (bloco de assinatura v2/v3)."""
import hashlib
import struct
import sys

EXPECTED = "2438e764896fc729be0f923fd338f5104b8da9507c12092c5800d0ab594c631f"


def signer_hashes(path):
    data = open(path, "rb").read()
    eocd = data.rfind(b"PK\x05\x06")
    cd_offset = struct.unpack("<I", data[eocd + 16:eocd + 20])[0]
    if data[cd_offset - 16:cd_offset] != b"APK Sig Block 42":
        return []
    size = struct.unpack("<Q", data[cd_offset - 24:cd_offset - 16])[0]
    block = data[cd_offset - size:cd_offset - 24]
    found, i = [], 0

    def take(buf, at):
        length = struct.unpack("<I", buf[at:at + 4])[0]
        return buf[at + 4:at + 4 + length], at + 4 + length

    while i < len(block):
        length = struct.unpack("<Q", block[i:i + 8])[0]
        kind = struct.unpack("<I", block[i + 8:i + 12])[0]
        value = block[i + 12:i + 8 + length]
        if kind in (0x7109871A, 0xF05368C0):
            signers, _ = take(value, 0)
            signer, _ = take(signers, 0)
            signed, _ = take(signer, 0)
            _, at = take(signed, 0)
            certificates, _ = take(signed, at)
            cert, _ = take(certificates, 0)
            found.append(hashlib.sha256(cert).hexdigest())
        i += 8 + length
    return found


ok = True
for apk in sys.argv[1:]:
    hashes = signer_hashes(apk)
    good = EXPECTED in hashes
    ok &= good
    print(("OK   " if good else "ERRO ") + apk + " " + ",".join(hashes))
if not ok:
    print("::error::APK não foi assinado com a chave fixa do Noto.")
    sys.exit(1)
