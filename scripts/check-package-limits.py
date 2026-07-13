#!/usr/bin/env python3
"""Reject npm plugin archives that exceed Codex marketplace limits."""

import json
import sys


MAX_COMPRESSED = 50 * 1024 * 1024
MAX_EXTRACTED = 250 * 1024 * 1024

for filename in sys.argv[1:]:
    payload = json.load(open(filename, encoding="utf-8"))
    record = payload[0] if isinstance(payload, list) else payload
    packed = int(record["size"])
    unpacked = int(record["unpackedSize"])
    if packed > MAX_COMPRESSED or unpacked > MAX_EXTRACTED:
        raise SystemExit(f"{filename}: package too large ({packed} packed, {unpacked} unpacked)")
    print(f"{filename}: {packed} packed, {unpacked} unpacked — within limits")
