
CFLAGS += -O2 -Wall -fPIC -shared
CFLAGS += $(shell pkg-config --libs --cflags lua)
CFLAGS += $(shell pkg-config --libs --cflags glib-2.0)
OUTFILE := lua.so

all:
	cc lua.c -o $(OUTFILE) $(CFLAGS)
	
clean:
	rm $(OUTFILE)
	
install:
	install -m 644 -D $(OUTFILE) $(HOME)/.config/hexchat/addons/$(OUTFILE)
	
uninstall:
	rm $(HOME)/.config/hexchat/addons/$(OUTFILE)

