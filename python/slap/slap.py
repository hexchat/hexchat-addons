from __future__ import print_function
import hexchat

__module_name__ = 'Slap'
__module_version__ = '1.0'
__module_description__ = 'Slaps specified users'
__author__ = 'Douglas Brunal (AKA) Frankity'

def slap_cb(word, word_eol, userdata):
  if len(word) > 1:
    hexchat.command('me slaps {} in da face with a large trout'.format(word[1]))
  else:
    hexchat.command('help slap')

  return hexchat.EAT_ALL

def unload_cb(userdata):
  print(__module_name__, 'version', __module_version__, 'unloaded.')

hexchat.hook_command('slap', slap_cb, help='SLAP <nick>')
hexchat.hook_unload(unload_cb)
print(__module_name__, 'version', __module_version__, 'loaded.')
