import urllib
import ast
import xchat

__module_name__ = "Define"
__module_author__ = "TingPing"
__module_version__ = "2"
__module_description__ = "Show word definitions"
# based on google dictionary script by Sridarshan Shetty - http://sridarshan.co.cc

def define(word, word_eol, userdata):

	if len(word) >= 2:
		_word = xchat.strip(word[1])
		_number = 1
		if len(word) >= 3:
			_number = int(xchat.strip(word[2]))
	else:
		xchat.prnt('Define Usage: /define word [number]')
		xchat.prnt('	number being alternate definition')
		return xchat.EAT_ALL

	url="http://www.google.com/dictionary/json?callback=s&q=" + _word + "&sl=en&tl=en&restrict=pr,de&client=te"
	obj=urllib.urlopen(url);
	content=obj.read()
	obj.close()
	content=content[2:-10]
	dic=ast.literal_eval(content)
	if dic.has_key("webDefinitions"):
		webdef=dic["webDefinitions"]
		webdef=webdef[0]
		webdef=webdef["entries"]
		index=1

		for i in webdef:
			if index == _number:
				if i["type"]=="meaning":
					ans=i["terms"]
					op=ans[0]['text']
					split=op.split(';')
					xchat.prnt(_word + ': ' + split[0].strip())
			index+=1
		return xchat.EAT_ALL
	else:
		xchat.prnt('Description unavailable for ' + _word)
		return xchat.EAT_ALL

xchat.hook_command("define", define)
xchat.prnt(__module_name__ + ' version ' + __module_version__ + ' loaded.')
