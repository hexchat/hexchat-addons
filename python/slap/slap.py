from __future__ import print_function

from random import choice

import hexchat

__module_name__ = 'Slap'
__module_version__ = '2.0'
__module_description__ = 'Slaps specified users'
__author__ = 'Douglas Brunal (AKA) Frankity'

slaps = [
    'slaps {} around a bit with a large trout',
    'gives {} a clout round the head with a fresh copy of WeeChat',
    'slaps {} with a large smelly trout',
    'breaks out the slapping rod and looks sternly at {}',
    'slaps {}\'s bottom and grins cheekily',
    'slaps {} a few times',
    'slaps {} and starts getting carried away',
    'would slap {}, but is not being violent today',
    'gives {} a hearty slap',
    'finds the closest large object and gives {} a slap with it',
    'likes slapping people and randomly picks {} to slap',
    'dusts off a kitchen towel and slaps it at {}'
]


def slap_cb(word, word_eol, userdata):
    if len(word) > 1:
        nick = word[1]
        hexchat.command('me ' + choice(slaps).format(nick))
    else:
        hexchat.command('help slap')
    return hexchat.EAT_ALL


def unload_cb(userdata):
    print(__module_name__, 'version', __module_version__, 'unloaded.')

hexchat.hook_command('slap', slap_cb, help='SLAP <nick>')
hexchat.hook_unload(unload_cb)
print(__module_name__, 'version', __module_version__, 'loaded.')
