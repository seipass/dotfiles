#!/usr/bin/env python3
"""Use the desktop portal's chooser without changing the shell's Qt theme."""
import ctypes
import sys

import dbus
from dbus.mainloop.glib import DBusGMainLoop

DBusGMainLoop(set_as_default=True)
glib = ctypes.CDLL("libglib-2.0.so.0")
glib.g_main_loop_new.argtypes = [ctypes.c_void_p, ctypes.c_int]
glib.g_main_loop_new.restype = ctypes.c_void_p
glib.g_main_loop_run.argtypes = [ctypes.c_void_p]
glib.g_main_loop_quit.argtypes = [ctypes.c_void_p]
glib.g_main_loop_unref.argtypes = [ctypes.c_void_p]
loop = glib.g_main_loop_new(None, False)
bus = dbus.SessionBus()
request_path = None


def response(code, results, path=None):
    if path != request_path:
        return
    if code == 0 and results.get("uris"):
        print(results["uris"][0], flush=True)
    glib.g_main_loop_quit(loop)


bus.add_signal_receiver(response, signal_name="Response",
                        dbus_interface="org.freedesktop.portal.Request",
                        path_keyword="path")
plugin = len(sys.argv) > 1 and sys.argv[1] == "plugin"
title = "Choose a Display Component" if plugin else "Choose a Wallpaper"
patterns = ["*.qml"] if plugin else ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
filters = dbus.Array(
    [dbus.Struct(("QML" if plugin else "Images",
                  dbus.Array([dbus.Struct((dbus.UInt32(0), pattern), signature="us")
                              for pattern in patterns], signature="(us)")),
                 signature="sa(us)")], signature="(sa(us))",
)
portal = bus.get_object("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop")
request_path = str(dbus.Interface(portal, "org.freedesktop.portal.FileChooser")
                   .OpenFile("", title, {"filters": filters}))
try:
    glib.g_main_loop_run(loop)
finally:
    glib.g_main_loop_unref(loop)
