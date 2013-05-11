from ctypes import *
import xchat

__module_name__        = "tabxhider"
__module_version__     = "1.0"
__module_description__ = "Hide the X button in the tabbed channel switcher"

# from gtype.h
class GTypeInstance(Structure):
    _fields_ = [("g_class", c_void_p)]

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
        #data = cast(data, py_object).value
        #indent = data['indent']
        gobj = cast(a, POINTER(GTypeInstance))

        #data = { "indent": data["indent"] + "  ",
        #         "show":   data["show"]
        #         }

        if gobject.g_type_check_instance_is_a(gobj,
                gtk.gtk_button_get_type()):
            #data['show'] = True
            #nprops = c_int()
            #props = gobject.g_object_class_list_properties(
            #        gobj.contents.g_class, nprops)
            l = c_char_p()
            gobject.g_object_get(gobj, "label", byref(l))
            #xchat.prnt("%s0x%016x -- %s" % (indent, a, l.value))

            # third button with a NULL label is the X button, hide it
            if l.value is None:
                self.noneCount = self.noneCount + 1
                if self.noneCount == 3:
                    gtk.gtk_widget_hide_all(gobj)

            glib.g_free(l)
            #show_prop_list(props, nprops, data['indent'] + " ")

        gtk.gtk_container_foreach(a, GTKCALLBACK(self.cb), py_object(data))

# userdata passed to callback, used to print out introspection info
data = { "indent": "", "show": False }
gtk.gtk_container_foreach(gtkwin, GTKCALLBACK(F().cb), py_object(data))
