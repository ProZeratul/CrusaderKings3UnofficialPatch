#!/usr/bin/env python3
# Send a synthetic motion + left click to an X window at window-relative x, y (no pointer move, no focus change).
import ctypes, sys, time

wid, x, y = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
X = ctypes.cdll.LoadLibrary("libX11.so.6")
X.XOpenDisplay.restype = ctypes.c_void_p
X.XDefaultRootWindow.restype = ctypes.c_ulong
X.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
X.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_long, ctypes.c_void_p]
X.XFlush.argtypes = [ctypes.c_void_p]

class XButtonEvent(ctypes.Structure):  # also matches XMotionEvent layout up to same_screen
    _fields_ = [("type", ctypes.c_int), ("serial", ctypes.c_ulong), ("send_event", ctypes.c_int),
                ("display", ctypes.c_void_p), ("window", ctypes.c_ulong), ("root", ctypes.c_ulong),
                ("subwindow", ctypes.c_ulong), ("time", ctypes.c_ulong), ("x", ctypes.c_int), ("y", ctypes.c_int),
                ("x_root", ctypes.c_int), ("y_root", ctypes.c_int), ("state", ctypes.c_uint),
                ("button", ctypes.c_uint), ("same_screen", ctypes.c_int)]

class XEvent(ctypes.Union):
    _fields_ = [("xbutton", XButtonEvent), ("pad", ctypes.c_long * 24)]

MotionNotify, ButtonPress, ButtonRelease = 6, 4, 5
masks = {MotionNotify: 1 << 6, ButtonPress: 1 << 2, ButtonRelease: 1 << 3}
d = X.XOpenDisplay(None)
root = X.XDefaultRootWindow(d)

def send(etype, button=0, state=0):
    e = XEvent()
    b = e.xbutton
    b.type, b.display, b.window, b.root = etype, d, wid, root
    b.x, b.y, b.x_root, b.y_root = x, y, x, y
    b.button, b.state, b.same_screen = button, state, 1
    X.XSendEvent(d, wid, 1, masks[etype], ctypes.byref(e))
    X.XFlush(d)

send(MotionNotify); time.sleep(0.1)
send(ButtonPress, 1); time.sleep(0.05)
send(ButtonRelease, 1, 1 << 8)
