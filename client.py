#!/usr/bin/env python3
# wormcontrol client — окно + управление
import socket, struct, threading, io, sys
import tkinter as tk
from PIL import Image, ImageTk

class Viewer:
    def __init__(self, host, port=50506):
        self.sock = socket.create_connection((host, port))
        self.control = False
        self.root = tk.Tk()
        self.root.title(f"wormcontrol — {host} (просмотр)")
        self.canvas = tk.Label(self.root)
        self.canvas.pack()
        self.root.bind("<KeyPress>", self.on_key_press)
        self.root.bind("<KeyRelease>", self.on_key_release)
        self.root.bind("<ButtonPress>", self.on_button_press)
        self.root.bind("<ButtonRelease>", self.on_button_release)
        self.root.bind("<Motion>", self.on_motion)
        self.root.after(20, self.recv_loop)
        self.root.mainloop()

    def recv_exact(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk: raise ConnectionError
            buf += chunk
        return buf

    def recv_loop(self):
        try:
            ln = struct.unpack("!I", self.recv_exact(4))[0]
            data = self.recv_exact(ln)
            img = Image.open(io.BytesIO(data))
            self.photo = ImageTk.PhotoImage(img)
            self.canvas.config(image=self.photo)
            self.root.after(20, self.recv_loop)
        except Exception:
            self.root.destroy()

    def send(self, payload):
        try: self.sock.sendall(payload)
        except Exception: pass

    def on_motion(self, e):
        if not self.control: return
        self.send(b"M" + struct.pack("!ii", e.x, e.y))

    def on_button_press(self, e):
        if not self.control: return
        btn = 1 if e.num == 1 else 2
        self.send(b"B" + bytes([btn, 1]))

    def on_button_release(self, e):
        if not self.control: return
        btn = 1 if e.num == 1 else 2
        self.send(b"B" + bytes([btn, 0]))

    def on_key_press(self, e):
        # Ctrl+Insert — вкл управление
        if (e.state & 0x4) and e.keysym == "Insert":
            self.control = True
            self.root.title("wormcontrol — УПРАВЛЕНИЕ ВКЛ")
            return
        # Insert+Fn — выкл (Fn на ноуте даёт Insert с keysym Insert, но без Control)
        if e.keysym == "Insert" and not (e.state & 0x4):
            self.control = False
            self.root.title("wormcontrol — УПРАВЛЕНИЕ ВЫКЛ")
            return
        if not self.control: return
        vk = e.keycode & 0xFF
        self.send(b"K" + bytes([vk, 1]))

    def on_key_release(self, e):
        if not self.control: return
        vk = e.keycode & 0xFF
        self.send(b"K" + bytes([vk, 0]))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("использование: python client.py <IP_целевого_ПК>")
        sys.exit(1)
    Viewer(sys.argv[1])
