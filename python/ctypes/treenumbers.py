from ctypes import *
import xchat

__module_name__        = "treenumbers"
__module_version__     = "1.0"
__module_description__ = "Enumerate all tabs for use with ALT-#"

# from gtype.h
class GTypeClass(Structure):
    _fields_ = [("g_type", c_uint)]
class GTypeInstance(Structure):
    _fields_ = [("g_class", POINTER(GTypeClass))]

class GtkTreeIter(Structure):
    _fields_ = [("stamp",      c_int)
               ,("user_data",  c_void_p)
               ,("user_data2", c_void_p)
               ,("user_data3", c_void_p)
               ]

# from gparamspecs.h
class GParamSpec(Structure):
    _fields_ = [("g_type_instance", GTypeInstance)
               ,("name", c_char_p)
               ,("flags", c_uint)
               ,("value_type", c_ulong)
               ,("owner_type", c_ulong)
               ]

# since 2.9.6b1, gtkwin_ptr is properly set as the address in a hex string
gtkwin = int(xchat.get_info("gtkwin_ptr"), 16)

# TODO detect platform and appropriately load the DLL or SO
gtk     = cdll.LoadLibrary("gtk-win32-2.0.dll")
gobject = cdll.LoadLibrary("gobject-2.0.dll")

gobject.g_type_check_instance_is_a.restype = c_bool
gobject.g_object_class_list_properties.argtypes = [c_void_p, POINTER(c_int)]
gobject.g_object_class_list_properties.restype = POINTER(POINTER(GParamSpec))
gobject.g_type_name.restype = c_char_p
gtk.gtk_tree_model_iter_next.restype = c_bool
gtk.gtk_tree_path_to_string.restype = c_char_p

GTKCALLBACK = CFUNCTYPE(None, c_void_p, c_void_p)

def show_prop_list(ptr, count, indent=""):
    for p in range(0,count.value):
        prop = ptr[p].contents
        xchat.prnt("%s%2d: %-20s %x %s" % (indent, p,
            gobject.g_type_name(prop.owner_type),
            prop.value_type,
            prop.name
            ))

# some samples of printing out property keys of a gobject
#winobj = cast(gtkwin, POINTER(GTypeInstance))
#nprops = c_int()
#props = gobject.g_object_class_list_properties(
#        winobj.contents.g_class, nprops)
#show_prop_list(props, nprops)

# class needed is to keep noneCount mutable for callback
# can't mutate global data from the callback
class F:
    noneCount = 0

    def cb(self, a, data):
        gobj = cast(a, POINTER(GTypeInstance))

        if gobject.g_type_check_instance_is_a(gobj,
                gtk.gtk_tree_view_get_type()):
            number = 1
            gtk.gtk_tree_view_set_show_expanders(gobj, 0)
            gtk.gtk_tree_view_set_enable_tree_lines(gobj, 0)
            gtk.gtk_tree_view_set_level_indentation(gobj, 0)
            store = gtk.gtk_tree_view_get_model(gobj)

            if gobject.g_type_check_instance_is_a(
                    cast(store, POINTER(GTypeInstance)),
                    gtk.gtk_list_store_get_type()): return

            iter = GtkTreeIter()
            has_first = gtk.gtk_tree_model_get_iter_first(
                    store, byref(iter))

            has_next = True

            # TODO refactor this
            while has_next:
                child = GtkTreeIter()
                has_children = gtk.gtk_tree_model_iter_has_child(
                        store, byref(iter))
                hasc2 = gtk.gtk_tree_model_iter_children(
                        store, byref(child), byref(iter))
                hn2 = True

                v = c_char_p()
                gtk.gtk_tree_model_get(
                        store, byref(iter), 0, byref(v), -1)

                newname = update_name(v.value, number)
                gtk.gtk_tree_store_set(
                        store, byref(iter), 0, c_char_p(newname), -1)
                # want to emit gtk_tree_model_row_changed but it fails?
                #gtk.gtk_tree_model_row_changed(
                #        store, gtk.gtk_tree_model_get_path(iter), iter)
                number = number + 1

                while hn2 and hasc2 == 1:
                    gtk.gtk_tree_model_get(
                            store, byref(child), 0, byref(v), -1)
                    newname = update_name(v.value, number)
                    gtk.gtk_tree_store_set(store,
                            byref(child), 0, c_char_p(newname), -1)
                    hn2 = gtk.gtk_tree_model_iter_next(store, child)
                    number = number + 1

                has_next = gtk.gtk_tree_model_iter_next(store, iter)

        gtk.gtk_container_foreach(a, GTKCALLBACK(self.cb), None)

    prev_channels = []

    timerhook = None
    scheduled = False

    def enumerate_cb(self, data):
        enumerate_tabs()
        if self.timerhook is not None:
            xchat.unhook(self.timerhook)
        self.timerhook = None

    def update_cb(self, word=None, word_eol=None, data=None):
        channels = map(lambda c: c.channel, xchat.get_list("channels"))
        if self.prev_channels != channels and self.timerhook is None:
            self.timerhook = xchat.hook_timer(250, self.enumerate_cb)
            self.prev_channels = channels
        return 1

def update_name(name, number):
    if name.startswith("("):
        idx = name.index(" ")
        name = name[idx:]
    return "(%d) %s" % (number, name.strip())

def enumerate_tabs():
    try:
        gtk.gtk_container_foreach(gtkwin, GTKCALLBACK(F().cb), None)
    except:
        pass # squelch errors

# no reliable way of hooking UI changes, poll every 1/4s instead  :-/
timerhook = xchat.hook_timer(250, F().update_cb)

def unload_cb(arg):
    xchat.unhook(timerhook)
    xchat.unhook(unloadhook)

unloadhook = xchat.hook_unload(unload_cb)
enumerate_tabs()
