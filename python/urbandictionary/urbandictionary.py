"""
	Usage: /ud <word>
	Creator: x13machine <https://github.com/x13machine>
	License: WTFPL <http://www.wtfpl.net/>
"""
__module_name__ = "Urban Dictionary"
__module_version__ = "1.0"
__module_description__ = "Gets the Urban Dictionary"
import hexchat
import requests

def ud(word, word_eol, userdata):
	try:
		r = requests.get('http://api.urbandictionary.com/v0/define', params={'term': word_eol[1]})
		data = r.json()['list'][0]
		hexchat.prnt('Urban Dictionary -> ' + data['word'] + ': ' + data['definition'])
	except:
		hexchat.prnt('Urban Dictionary: ENGLISH, MOTHERFUCKER DO YOU SPEAK IT???')	
hexchat.hook_command('ud', ud, help='UD <word>')
