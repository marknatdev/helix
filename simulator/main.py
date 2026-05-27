import http.server
import socketserver
import webbrowser
import threading
import sys
import os
import time

PORT = 8085
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        # Serve from the directory where this script lives
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def log_message(self, format, *args):
        # Suppress standard request logging to keep console clean
        pass

def run_server():
    socketserver.TCPServer.allow_reuse_address = True
    try:
        with socketserver.TCPServer(("", PORT), Handler) as httpd:
            print(f"[HELIX] Web Simulator server running on http://localhost:{PORT}")
            httpd.serve_forever()
    except Exception as e:
        print(f"[ERR] Failed to start server: {e}")

if __name__ == "__main__":
    print("[HELIX] Starting GPS Web Simulator...")
    # Start the server in a daemon thread so it exits when main exits
    t = threading.Thread(target=run_server, daemon=True)
    t.start()
    
    # Wait a brief moment for the port to bind
    time.sleep(0.5)
    
    # Open default browser
    webbrowser.open(f"http://localhost:{PORT}")
    
    print("[HELIX] Browser opened. Press Ctrl+C in this terminal to exit.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[HELIX] Stopping simulator server...")
        sys.exit(0)
