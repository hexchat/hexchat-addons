#### SET THIS VALUE TO THE LOCATION OF THE `pci.ids` file ####
PCIIDS = /usr/share/hwdata/pci.ids
#/usr/share/misc/pci.ids # Try this if you have issues with /video

#### UNCOMMENT THIS IF YOU WANT THE BUTTONS ####
#BUTTON = -Dbuttonbar

#### SHOULD NOT NEED TO EDIT BELOW THIS LINE ####
VER_MAJOR = 2
VER_MINOR = 3
VER_PATCH = 0
CC = gcc
CFLAGS += -O2 -Wall -fPIC
CFLAGS += -DVER_MINOR=$(VER_MINOR) -DVER_MAJOR=$(VER_MAJOR) -DVER_PATCH=$(VER_PATCH) \
          -DVER_STRING=\"$(VER_MAJOR).$(VER_MINOR).$(VER_PATCH)\" -DPCIIDS=\"$(PCIIDS)\" $(BUTTON)
LDFLAGS = $(CFLAGS) -shared
LIBRARY = hexsys.so
OBJECTS = xsys.o parse.o pci.o match.o hwmon.o

ALL : $(LIBRARY)

$(LIBRARY) : $(OBJECTS)
	$(CC) $(LDFLAGS) -o $(LIBRARY) $(OBJECTS) -lpci

xsys.o : xsys.c
parse.o : parse.c
pci.o : pci.c
match.o : match.c
hwmon.o : hwmon.c

.PHONY : clean
clean :
	rm -rf *.o *.so *~

.PHONY : install
install : $(LIBRARY)
	rm -f $(HOME)/.config/hexchat/addons/hexsys.so
	cp ./$(LIBRARY) $(HOME)/.config/hexchat/addons/hexsys.so

