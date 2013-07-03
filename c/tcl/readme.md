###Building

1. Install the dev tools for your distro
2. Install the tcl dev package for your distro (tcl-devel, tcl-dev, etc)
3. Run *tclConfig.sh* that was included with that (usually /usr/lib/tclConfig.sh)
4. Run this command:

>cc tclplugin.c -O2 -Wall -fPIC -shared -ltcl -o tcl.so

###Installation

Place *tcl.so* in *$HOME/.config/hexchat/addons*
