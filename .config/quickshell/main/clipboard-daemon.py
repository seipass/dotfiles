"""Zero-dependency Wayland clipboard daemon (text + images) via ext_data_control_v1."""
import array
import datetime
import hashlib
import json
import os
import select
import socket
import struct
import sys
import threading
import time
from pathlib import Path

CACHE_DIR = Path.home() / ".cache" / "quickshell" / "clipboard"
MAX_TEXT_BYTES = 64 * 1024
MAX_IMAGE_BYTES = 25 * 1024 * 1024

IMAGE_MIMES = [
    ("image/png", ".png"),
    ("image/webp", ".webp"),
    ("image/jpeg", ".jpg"),
    ("image/gif", ".gif"),
    ("image/bmp", ".bmp"),
]
TEXT_MIMES = [
    "text/plain;charset=utf-8",
    "UTF8_STRING",
    "text/plain",
]


def pack_string(s: str) -> bytes:
    raw = s.encode("utf-8") + b"\x00"
    pad = (-len(raw)) & 3
    return struct.pack("<I", len(raw)) + raw + (b"\x00" * pad)


def unpack_string(buf: bytes, offset: int = 0):
    (slen,) = struct.unpack_from("<I", buf, offset)
    end = offset + 4 + slen
    val = buf[offset + 4 : end - 1].decode("utf-8", errors="replace") if slen > 0 else ""
    next_off = offset + 4 + ((slen + 3) & ~3)
    return val, next_off


def parse_image_dimensions(data: bytes, mime: str):
    try:
        if mime == "image/png" and len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n":
            w, h = struct.unpack(">II", data[16:24])
            return w, h
        if mime == "image/gif" and len(data) >= 10 and data[:6] in (b"GIF87a", b"GIF89a"):
            w, h = struct.unpack("<HH", data[6:10])
            return w, h
        if mime == "image/bmp" and len(data) >= 26 and data[:2] == b"BM":
            w, h = struct.unpack("<ii", data[18:26])
            return abs(w), abs(h)
        if mime == "image/webp" and len(data) >= 30 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
            chunk = data[12:16]
            if chunk == b"VP8X" and len(data) >= 30:
                w = 1 + int.from_bytes(data[24:27], "little")
                h = 1 + int.from_bytes(data[27:30], "little")
                return w, h
            if chunk == b"VP8 " and len(data) >= 30:
                w, h = struct.unpack("<HH", data[26:30])
                return w & 0x3FFF, h & 0x3FFF
            if chunk == b"VP8L" and len(data) >= 25:
                bits = struct.unpack("<I", data[21:25])[0]
                return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
        if mime == "image/jpeg" and len(data) > 4 and data[:2] == b"\xff\xd8":
            i = 2
            while i + 4 < len(data):
                while i < len(data) and data[i] != 0xFF:
                    i += 1
                while i < len(data) and data[i] == 0xFF:
                    i += 1
                if i >= len(data):
                    break
                marker = data[i]
                i += 1
                if marker in (0xD8, 0xD9, 0x01) or (0xD0 <= marker <= 0xD7):
                    continue
                if i + 2 > len(data):
                    break
                seg_len = struct.unpack(">H", data[i : i + 2])[0]
                if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB):
                    if i + 7 <= len(data):
                        h, w = struct.unpack(">HH", data[i + 3 : i + 7])
                        return w, h
                    break
                i += seg_len
    except Exception:
        pass
    return 0, 0


class WaylandClipboardDaemon:
    def __init__(self):
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        runtime_dir = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        display = os.environ.get("WAYLAND_DISPLAY", "wayland-1")
        self.sock_path = os.path.join(runtime_dir, display)
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(self.sock_path)
        self.sock_lock = threading.Lock()

        self.next_id = 2
        self.recv_buf = b""
        self.recv_fds = []

        self.seat_global = None
        self.mgr_global = None
        self.mgr_iface = None
        self.seat_id = None
        self.mgr_id = None
        self.device_id = None

        self.offers = {}  # offer_id -> list[str]
        self.current_selection_offer = None
        self.active_sources = {}  # source_id -> {"data": bytes, "mimes": list[str]}
        self.own_selection_hash = None
        self.own_selection_ts = 0.0
        self.running = True

    def alloc_id(self) -> int:
        oid = self.next_id
        self.next_id += 1
        if self.next_id >= 0xFE000000:
            self.next_id = 100
        return oid

    def send_msg(self, oid: int, op: int, payload: bytes = b"", fds=None):
        header = struct.pack("<IHH", oid, op, 8 + len(payload))
        data = header + payload
        with self.sock_lock:
            if fds:
                ancdata = [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", fds))]
                self.sock.sendmsg([data], ancdata)
            else:
                self.sock.sendall(data)

    def recv_once(self) -> bool:
        try:
            data, ancdata, _, _ = self.sock.recvmsg(65536, socket.CMSG_SPACE(64 * 4))
        except OSError:
            return False
        if not data:
            return False
        self.recv_buf += data
        for cmsg_level, cmsg_type, cmsg_data in ancdata:
            if cmsg_level == socket.SOL_SOCKET and cmsg_type == socket.SCM_RIGHTS:
                arr = array.array("i")
                arr.frombytes(cmsg_data[: len(cmsg_data) - (len(cmsg_data) % arr.itemsize)])
                self.recv_fds.extend(arr)
        return True

    def pop_fd(self):
        return self.recv_fds.pop(0) if self.recv_fds else -1

    def bootstrap(self):
        reg_id = self.alloc_id()
        sync_id = self.alloc_id()
        self.send_msg(1, 1, struct.pack("<I", reg_id))
        self.send_msg(1, 0, struct.pack("<I", sync_id))

        synced = False
        while not synced:
            if not self.recv_once():
                raise RuntimeError("Wayland connection closed during bootstrap")
            while len(self.recv_buf) >= 8:
                oid, op, size = struct.unpack_from("<IHH", self.recv_buf, 0)
                if len(self.recv_buf) < size:
                    break
                body = self.recv_buf[8:size]
                self.recv_buf = self.recv_buf[size:]
                if oid == reg_id and op == 0:
                    name = struct.unpack_from("<I", body, 0)[0]
                    iface, off = unpack_string(body, 4)
                    ver = struct.unpack_from("<I", body, off)[0]
                    if iface == "wl_seat" and self.seat_global is None:
                        self.seat_global = (name, iface, min(ver, 7))
                    elif iface == "ext_data_control_manager_v1":
                        self.mgr_global = (name, iface, 1)
                        self.mgr_iface = iface
                    elif iface == "zwlr_data_control_manager_v1" and self.mgr_global is None:
                        self.mgr_global = (name, iface, min(ver, 2))
                        self.mgr_iface = iface
                elif oid == sync_id and op == 0:
                    synced = True

        if not self.seat_global or not self.mgr_global:
            raise RuntimeError("Compositor does not expose wl_seat or data_control_manager")

        self.seat_id = self.alloc_id()
        self.mgr_id = self.alloc_id()
        self.device_id = self.alloc_id()

        # wl_registry.bind(name, iface, ver, new_id)
        sname, siface, sver = self.seat_global
        self.send_msg(reg_id, 0, struct.pack("<I", sname) + pack_string(siface) + struct.pack("<II", sver, self.seat_id))
        mname, miface, mver = self.mgr_global
        self.send_msg(reg_id, 0, struct.pack("<I", mname) + pack_string(miface) + struct.pack("<II", mver, self.mgr_id))
        # manager.get_data_device(new_id, seat)
        self.send_msg(self.mgr_id, 1, struct.pack("<II", self.device_id, self.seat_id))

    def emit(self, payload: dict):
        sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
        sys.stdout.flush()

    def destroy_offer(self, offer_id: int):
        if offer_id and offer_id in self.offers:
            self.offers.pop(offer_id, None)
            try:
                self.send_msg(offer_id, 1)  # offer.destroy()
            except OSError:
                pass

    def handle_selection(self, offer_id: int):
        prev = self.current_selection_offer
        self.current_selection_offer = offer_id if offer_id != 0 else None
        if prev and prev != offer_id:
            self.destroy_offer(prev)

        if offer_id == 0:
            return
        mimes = self.offers.get(offer_id, [])
        if not mimes:
            return

        # Ignore our own freshly set selection echo
        if self.own_selection_hash and (time.monotonic() - self.own_selection_ts) < 1.2:
            self.own_selection_hash = None
            return

        # Prefer image if offered
        chosen_image = None
        for mime, ext in IMAGE_MIMES:
            if mime in mimes:
                chosen_image = (mime, ext)
                break

        if chosen_image:
            mime, ext = chosen_image
            self.request_receive(offer_id, mime, is_image=True, ext=ext)
            return

        for mime in TEXT_MIMES:
            if mime in mimes:
                self.request_receive(offer_id, mime, is_image=False, ext="")
                return

    def request_receive(self, offer_id: int, mime: str, is_image: bool, ext: str):
        r_fd, w_fd = os.pipe()
        try:
            self.send_msg(offer_id, 0, pack_string(mime), fds=[w_fd])
        except OSError:
            os.close(r_fd)
            os.close(w_fd)
            return
        os.close(w_fd)
        threading.Thread(
            target=self._read_offer_pipe,
            args=(r_fd, mime, is_image, ext),
            daemon=True,
        ).start()

    def _read_offer_pipe(self, r_fd: int, mime: str, is_image: bool, ext: str):
        limit = MAX_IMAGE_BYTES if is_image else MAX_TEXT_BYTES
        chunks = []
        total = 0
        deadline = time.monotonic() + 3.0
        try:
            os.set_blocking(r_fd, False)
            while time.monotonic() < deadline:
                ready, _, _ = select.select([r_fd], [], [], 0.25)
                if not ready:
                    continue
                try:
                    chunk = os.read(r_fd, 65536)
                except BlockingIOError:
                    continue
                if not chunk:
                    break
                total += len(chunk)
                if total > limit:
                    return
                chunks.append(chunk)
        except OSError:
            return
        finally:
            try:
                os.close(r_fd)
            except OSError:
                pass

        data = b"".join(chunks)
        if not data:
            return

        now_str = datetime.datetime.now().strftime("%H:%M")
        digest = hashlib.sha256(data).hexdigest()[:16]

        if is_image:
            out_path = CACHE_DIR / f"{digest}{ext}"
            if not out_path.exists():
                tmp_path = CACHE_DIR / f".{digest}{ext}.tmp"
                try:
                    tmp_path.write_bytes(data)
                    tmp_path.replace(out_path)
                except OSError:
                    return
            w, h = parse_image_dimensions(data, mime)
            self.emit({
                "type": "image",
                "id": digest,
                "path": str(out_path),
                "mime": mime,
                "width": w,
                "height": h,
                "size": len(data),
                "time": now_str,
            })
        else:
            text = data.decode("utf-8", errors="replace")
            if not text:
                return
            self.emit({
                "type": "text",
                "id": digest,
                "text": text,
                "time": now_str,
            })

    def set_selection_data(self, data: bytes, mimes: list):
        source_id = self.alloc_id()
        self.active_sources[source_id] = {"data": data, "mimes": mimes}
        self.own_selection_hash = hashlib.sha256(data).hexdigest()[:16]
        self.own_selection_ts = time.monotonic()

        # manager.create_data_source(new_id)
        self.send_msg(self.mgr_id, 0, struct.pack("<I", source_id))
        for m in mimes:
            # source.offer(mime_type)
            self.send_msg(source_id, 0, pack_string(m))
        # device.set_selection(source)
        self.send_msg(self.device_id, 0, struct.pack("<I", source_id))

    def _serve_fd(self, fd: int, data: bytes):
        try:
            view = memoryview(data)
            written = 0
            while written < len(view):
                n = os.write(fd, view[written : written + 65536])
                if n <= 0:
                    break
                written += n
        except OSError:
            pass
        finally:
            try:
                os.close(fd)
            except OSError:
                pass

    def handle_command(self, line: str):
        line = line.strip()
        if not line:
            return
        try:
            cmd = json.loads(line)
        except ValueError:
            return
        action = cmd.get("cmd")
        if action == "copy_image":
            path = Path(cmd.get("path", ""))
            mime = cmd.get("mime") or "image/png"
            if path.is_file():
                try:
                    data = path.read_bytes()
                    self.set_selection_data(data, [mime])
                except OSError:
                    pass
        elif action == "copy_text":
            text = cmd.get("text", "")
            if isinstance(text, str) and text:
                self.set_selection_data(
                    text.encode("utf-8"),
                    ["text/plain;charset=utf-8", "text/plain", "UTF8_STRING"],
                )
        elif action == "clear":
            for entry in CACHE_DIR.glob("*"):
                if entry.is_file():
                    try:
                        entry.unlink()
                    except OSError:
                        pass

    def dispatch_wayland(self):
        while len(self.recv_buf) >= 8:
            oid, op, size = struct.unpack_from("<IHH", self.recv_buf, 0)
            if len(self.recv_buf) < size:
                break
            body = self.recv_buf[8:size]
            self.recv_buf = self.recv_buf[size:]

            if oid == 1 and op == 0:
                # wl_display.error
                continue
            elif oid == self.device_id:
                if op == 0:  # data_offer(new_id)
                    (offer_id,) = struct.unpack_from("<I", body, 0)
                    self.offers[offer_id] = []
                elif op == 1:  # selection(object_id)
                    (offer_id,) = struct.unpack_from("<I", body, 0)
                    self.handle_selection(offer_id)
                elif op == 2:  # finished
                    self.running = False
                elif op == 3:  # primary_selection(object_id)
                    (offer_id,) = struct.unpack_from("<I", body, 0)
                    if offer_id and offer_id != self.current_selection_offer:
                        self.destroy_offer(offer_id)
            elif oid in self.offers and op == 0:
                # offer.offer(mime_type)
                mime, _ = unpack_string(body, 0)
                if mime:
                    self.offers[oid].append(mime)
            elif oid in self.active_sources:
                if op == 0:  # source.send(mime_type, fd)
                    fd = self.pop_fd()
                    src = self.active_sources.get(oid)
                    if fd >= 0 and src:
                        threading.Thread(
                            target=self._serve_fd,
                            args=(fd, src["data"]),
                            daemon=True,
                        ).start()
                    elif fd >= 0:
                        os.close(fd)
                elif op == 1:  # source.cancelled()
                    self.active_sources.pop(oid, None)
                    try:
                        self.send_msg(oid, 1)  # source.destroy()
                    except OSError:
                        pass

    def run(self):
        self.bootstrap()
        stdin_fd = sys.stdin.fileno()
        stdin_buf = b""
        os.set_blocking(stdin_fd, False)

        while self.running:
            rlist = [self.sock, stdin_fd]
            try:
                ready, _, _ = select.select(rlist, [], [], 1.0)
            except (OSError, ValueError):
                break
            if self.sock in ready:
                if not self.recv_once():
                    break
                self.dispatch_wayland()
            if stdin_fd in ready:
                try:
                    chunk = os.read(stdin_fd, 65536)
                except BlockingIOError:
                    chunk = b""
                except OSError:
                    break
                if not chunk:
                    break
                stdin_buf += chunk
                while b"\n" in stdin_buf:
                    line, stdin_buf = stdin_buf.split(b"\n", 1)
                    self.handle_command(line.decode("utf-8", errors="replace"))


if __name__ == "__main__":
    daemon = WaylandClipboardDaemon()
    daemon.run()
