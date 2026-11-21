#!/usr/bin/env python3
"""Zero-dependency real-time P2PQuake WebSocket listener (emits NDJSON lines)."""
import base64
import json
import os
import re
import socket
import ssl
import struct
import sys
import time
import urllib.request

HOST = "api.p2pquake.net"
WS_PATH = "/v2/ws"
HIST_URL = "https://api.p2pquake.net/v2/history?codes=551&limit=8"


def parse_item(item):
    if not isinstance(item, dict):
        return None
    eq = item.get("earthquake")
    if not isinstance(eq, dict):
        return None
    hypo = eq.get("hypocenter") or {}
    raw_time = eq.get("time") or ""
    hm = re.search(r"(\d{2}:\d{2})", raw_time)
    full = re.search(r"\d{4}/(\d{2}/\d{2} \d{2}:\d{2})", raw_time)
    return {
        "place": hypo.get("name") or "震源地不明",
        "maxScale": int(eq.get("maxScale") if eq.get("maxScale") is not None else -1),
        "magnitude": float(hypo.get("magnitude") if hypo.get("magnitude") is not None else -1),
        "depth": int(hypo.get("depth") if hypo.get("depth") is not None else -1),
        "tsunami": eq.get("domesticTsunami") or "Unknown",
        "rawTime": raw_time,
        "time": hm.group(1) if hm else raw_time,
        "fullTime": full.group(1) if full else raw_time,
    }


def emit(payload):
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def fetch_initial():
    try:
        req = urllib.request.Request(HIST_URL, headers={"User-Agent": "quickshell-earthquake/1.0"})
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read().decode("utf-8", errors="replace"))
        items = [p for x in data if (p := parse_item(x))]
        items.sort(key=lambda x: x["rawTime"], reverse=True)
        emit({"type": "snapshot", "items": items[:8]})
    except Exception:
        pass


def recv_exact(sock, n):
    buf = bytearray()
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("EOF")
        buf.extend(chunk)
    return bytes(buf)


def send_frame(sock, opcode, payload=b""):
    mask = os.urandom(4)
    header = bytearray([0x80 | opcode])
    length = len(payload)
    if length < 126:
        header.append(0x80 | length)
    elif length < 65536:
        header.append(0x80 | 126)
        header.extend(struct.pack("!H", length))
    else:
        header.append(0x80 | 127)
        header.extend(struct.pack("!Q", length))
    header.extend(mask)
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    sock.sendall(bytes(header) + masked)


def run_ws():
    ctx = ssl.create_default_context()
    raw = socket.create_connection((HOST, 443), timeout=15)
    sock = ctx.wrap_socket(raw, server_hostname=HOST)
    try:
        key = base64.b64encode(os.urandom(16)).decode()
        req = (
            f"GET {WS_PATH} HTTP/1.1\r\n"
            f"Host: {HOST}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            "User-Agent: quickshell-earthquake/1.0\r\n\r\n"
        )
        sock.sendall(req.encode())
        resp = b""
        while b"\r\n\r\n" not in resp:
            chunk = sock.recv(1024)
            if not chunk:
                raise ConnectionError("Handshake EOF")
            resp += chunk
        if b" 101 " not in resp.splitlines()[0]:
            raise ConnectionError("WebSocket upgrade failed")
        sock.settimeout(60)
        emit({"type": "connected"})

        while True:
            try:
                head = recv_exact(sock, 2)
            except socket.timeout:
                send_frame(sock, 0x9, b"ping")
                continue
            opcode = head[0] & 0x0F
            masked = (head[1] & 0x80) != 0
            length = head[1] & 0x7F
            if length == 126:
                length = struct.unpack("!H", recv_exact(sock, 2))[0]
            elif length == 127:
                length = struct.unpack("!Q", recv_exact(sock, 8))[0]
            mask_key = recv_exact(sock, 4) if masked else None
            data = recv_exact(sock, length) if length else b""
            if mask_key:
                data = bytes(b ^ mask_key[i % 4] for i, b in enumerate(data))

            if opcode == 0x8:  # Close
                break
            if opcode == 0x9:  # Ping
                send_frame(sock, 0xA, data)
                continue
            if opcode == 0x1:  # Text
                try:
                    msg = json.loads(data.decode("utf-8", errors="replace"))
                except ValueError:
                    continue
                if msg.get("code") == 551:
                    parsed = parse_item(msg)
                    if parsed:
                        emit({"type": "event", "item": parsed})
    finally:
        try:
            sock.close()
        except OSError:
            pass


if __name__ == "__main__":
    backoff = 3
    while True:
        fetch_initial()
        try:
            run_ws()
            backoff = 3
        except Exception:
            time.sleep(backoff)
            backoff = min(30, backoff * 2)
