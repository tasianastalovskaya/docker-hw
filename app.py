import os
from http.server import BaseHTTPRequestHandler, HTTPServer

COUNT_FILE = "/data/count.txt"

def read_count():
    try:
        with open(COUNT_FILE, "r") as f:
            return int(f.read())
    except (FileNotFoundError, ValueError):
        return 0

def save_count(count):
    with open(COUNT_FILE, "w") as f:
        f.write(str(count))

class App(BaseHTTPRequestHandler):
    def do_GET(self):
        count = read_count() + 1
        save_count(count)

        if self.path == "/":
            text = os.getenv("GREETING", "Привет!")
        else:
            text = str(count)

        self.send_response(200)
        self.end_headers()
        self.wfile.write(text.encode("utf-8"))

server = HTTPServer(("0.0.0.0", 8000), App)
print("Server started on port 8000", flush=True)
server.serve_forever()
