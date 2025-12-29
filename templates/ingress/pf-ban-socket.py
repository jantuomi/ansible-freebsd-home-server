#!/usr/bin/env python3
import http.server
import os
import re
import socketserver
import subprocess

SOCK_PATH = "/var/run/pfban/ban.sock"
PF_TABLE = "blocked"

# Simple, conservative filter to avoid junk / injection
IP_RE = re.compile(r"^[0-9A-Fa-f:.]{3,}$")


def ensure_socket_dir(path: str) -> None:
    os.makedirs(os.path.dirname(path), mode=0o755, exist_ok=True)


class BanHandler(http.server.BaseHTTPRequestHandler):
    # Silence default logging
    def log_message(self, format, *args):
        return

    def do_POST(self):
        if self.path != "/ban":
            self.send_response(404)
            self.end_headers()
            return

        ip = self.headers.get("X-IP", "").strip()

        if ip and IP_RE.match(ip):
            subprocess.run(
                ["/sbin/pfctl", "-t", PF_TABLE, "-T", "add", ip],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )

        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        self.send_response(405)
        self.end_headers()


class ThreadingUnixHTTPServer(
    socketserver.ThreadingMixIn,
    socketserver.UnixStreamServer,
):
    daemon_threads = True


def main() -> None:
    ensure_socket_dir(SOCK_PATH)

    # Remove stale socket if present
    try:
        os.unlink(SOCK_PATH)
    except FileNotFoundError:
        pass

    with ThreadingUnixHTTPServer(SOCK_PATH, BanHandler) as httpd:
        # Allow nginx workers (www) to connect
        os.chmod(SOCK_PATH, 0o660)

        httpd.serve_forever()


if __name__ == "__main__":
    main()
