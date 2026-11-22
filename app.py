import os
import redis
from http.server import BaseHTTPRequestHandler, HTTPServer

redis_url = os.getenv("REDIS_URL", "redis://redis:6379/0")
db = redis.Redis.from_url(redis_url, decode_responses=True)

class App(BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path == "/healthz":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
            return

        if self.path == "/readyz":
            try:
                db.ping()
                self.send_response(200)
                message = "Redis is ready"
            except redis.RedisError:
                self.send_response(503)
                message = "Redis is not ready"

            self.end_headers()
            self.wfile.write(message.encode())
            return

        if self.path == "/":
            try:
                count = db.get("count") or "0"
                self.send_response(200)
                self.end_headers()
                self.wfile.write(count.encode())
            except redis.RedisError:
                self.send_response(503)
                self.end_headers()
                self.wfile.write(b"Redis is not available")
            return

        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        if self.path == "/increment":
            try:
                count = db.incr("count")
                self.send_response(200)
                self.end_headers()
                self.wfile.write(str(count).encode())
            except redis.RedisError:
                self.send_response(503)
                self.end_headers()
                self.wfile.write(b"Redis is not available")
            return

        self.send_response(404)
        self.end_headers()

server = HTTPServer(("0.0.0.0", 8000), App)
print("Server started on port 8000", flush=True)
server.serve_forever()
