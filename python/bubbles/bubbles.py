# See original source code from:
# http://stackoverflow.com/questions/17262941/multiple-windowsbaloontip-traytip-notifications
# Adapted to HexChat by Assaf Koss, March 2014.

# The Bubble's Icon: http://www.sendspace.com/file/pg1n2n
# Put it in the same folder of the bubbles.py file.

from win32api import *
from win32gui import *
import win32con
import sys, os
import struct
import time
import hexchat

__module_name__ = "Bubbles"
__module_version__ = "1.0"
__module_description__ = "Tray notifications on highlighted events for win32."

print('Bubbles Started!')

def clearBubble(userdata):
    Shell_NotifyIcon(NIM_DELETE, w.nid)

class WindowsBalloonTip:
    def __init__(self, title, msg):
        message_map = {
                win32con.WM_DESTROY: self.OnDestroy,
        }
        # Register the Window class.
        wc = self.wc = WNDCLASS()
        hinst = wc.hInstance = GetModuleHandle(None)
        wc.lpszClassName = "PythonTaskbar"
        wc.lpfnWndProc = message_map # could also specify a wndproc.
        classAtom = self.classAtom = RegisterClass(wc)
        # Create the Window.
        style = win32con.WS_OVERLAPPED | win32con.WS_SYSMENU
        self.hwnd = CreateWindow( classAtom, "Taskbar", style, \
                0, 0, win32con.CW_USEDEFAULT, win32con.CW_USEDEFAULT, \
                0, 0, hinst, None)
        UpdateWindow(self.hwnd)
        iconPathName = hexchat.get_info('configdir') + "\\addons\\bubbles.ico"
        icon_flags = win32con.LR_LOADFROMFILE | win32con.LR_DEFAULTSIZE
        try:
           self.hicon = LoadImage(hinst, iconPathName, \
                    win32con.IMAGE_ICON, 0, 0, icon_flags)
        except:
          self.hicon = LoadIcon(0, win32con.IDI_APPLICATION)
        self.flags = NIF_ICON | NIF_MESSAGE | NIF_TIP
        self.nid = (self.hwnd, 0, self.flags, win32con.WM_USER+20, self.hicon, "Bubbles for HexChat.")
        Shell_NotifyIcon(NIM_ADD, self.nid)
        Shell_NotifyIcon(NIM_MODIFY, \
                         (self.hwnd, 0, NIF_INFO, win32con.WM_USER+20,\
                          self.hicon, "Balloon tooltip", msg, 200, title))
        hexchat.hook_timer(5000, clearBubble)
        # Shell_NotifyIcon(NIM_DELETE, self.nid)
        # DestroyWindow(self.hwnd)
    def OnDestroy(self, hwnd, msg, wparam, lparam):
        print('OnDestroy...')
        PostQuitMessage(0) # Terminate the app.

def Pop(title, msg):
    Shell_NotifyIcon(NIM_ADD, w.nid)
    Shell_NotifyIcon(NIM_MODIFY, \
                     (w.hwnd, 0, NIF_INFO, win32con.WM_USER+20,\
                      w.hicon, "Balloon tooltip", msg, 200, title))
    hexchat.hook_timer(5000, clearBubble)

try:
    w = WindowsBalloonTip("Bubbles...", "Bubbles Activated!")
except Exception as err:
    print('Bubbles Initialization Error:')
    print(err)
    print('Killing Script...')
    PostQuitMessage(0)
    try:
        DestroyWindow(w.hwnd)
        PostQuitMessage(0)
        UnregisterClass(w.classAtom, w.wc.hInstance)
    except Exception as err:
        print('Failed to UnregisterClass():')
        print(err)
    hexchat.command('timer 1 py unload ' + __module_name__)

def process(word, word_eol, userdata):
    # States taken from https://github.com/TingPing/plugins/blob/master/HexChat/growl.py
    # Thanks TingPing!
    try:
        if hexchat.get_prefs('away_omit_alerts') and hexchat.get_info('away'):
            return None
        if hexchat.get_prefs('gui_focus_omitalerts') and hexchat.get_info('win_status') == 'active':
            return None
    except Exception as err:
        pass
    
    try:
        if len(word) >= 3:
            Pop(word[2] + word[0], word[1])
        else:
            Pop(word[0], word[1])
    except Exception as err:
        print('Bubbling Error:')
        print(err)

def unloader(userdata):
    try:
        DestroyWindow(w.hwnd)
        PostQuitMessage(0)
        UnregisterClass(w.classAtom, w.wc.hInstance)
    except Exception as err:
        print('Failed to UnregisterClass():')
        print(err)
    

hexchat.hook_unload(unloader)
hexchat.hook_print("Channel Action Hilight", process)
hexchat.hook_print("Channel Msg Hilight", process)
hexchat.hook_print("Private Message", process)