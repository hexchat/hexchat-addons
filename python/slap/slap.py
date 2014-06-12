__module_name__ = "Hexchat Slap Plugin"
__module_version__ = "0.2"
__module_description__ = "Slap command"
__author__ = "Douglas Brunal (AKA) Frankity"

import hexchat as XC

def slaps(word, word_eol, userdata):
    try:
        XC.command('me ' + 'slaps ' + '\002'+word[1]+'\002' + ' in da face with a large trout')
    except:
        print('error ')

XC.hook_command("slap",slaps)
XC.prnt(__module_name__ + ' version ' + __module_version__ + ' loaded.')
