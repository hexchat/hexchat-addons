import requests
import hexchat
import urllib

__module_name__ = "URL Shortener"
__module_version__ = "1.0"
__module_description__ = "Shortens URLs using the TinyURL API"

def shorten_url(url):
    """Shortens a URL using the TinyURL API"""
    encoded_url = urllib.parse.quote(url)
    api_url = "http://tinyurl.com/api-create.php?url=" + encoded_url + "&preview=false"
    response = requests.get(api_url)
    return response.text

def shorten_cb(word, word_eol, userdata):
    """Callback for the 'shorten' command"""
    if len(word) < 2:
        hexchat.prnt("Invalid syntax. Usage: shorten <URL>")
        return hexchat.EAT_ALL
    
    url = word[1]
    short_url = shorten_url(url)
    hexchat.prnt(f"Shortened URL: {short_url}")
    return hexchat.EAT_ALL

hexchat.hook_command("shorten", shorten_cb, help="/SHORTEN <URL> Shortens a URL using the TinyURL API")

hexchat.prnt(__module_name__ + " version " + __module_version__ + " loaded.")
