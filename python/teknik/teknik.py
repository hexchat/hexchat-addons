__module_name__ = "Teknik"
__module_version__ = "1.0.1"
__module_description__ = "Interact with the Teknik Services, including file uploads, pastes, and url shortening."

import_success = True

try:
  import Tkinter as tk
except ImportError:
  import tkinter as tk

try:
  from tkinter.filedialog import askopenfilename
except ImportError:
  from tkFileDialog import askopenfilename

try:
  import hexchat
except ImportError:
  print('This script must be run under Hexchat.')
  print('Get Hexchat now at: https://hexchat.github.io/')
  import_success = False

# Requires Install
try:
  from teknik import uploads as teknik
except ImportError as e:
  print('Missing package(s) for %s: %s' % (__module_name__, e))
  import_success = False

def teknik_prompt():
  # Prompt for a file
  root = tk.Tk()
  root.withdraw()
  file_path = askopenfilename()
  
  if file_path is not None:
    # Upload the selected file
    upload_file(file_path)
        
def upload_file(file):
  if file != '':
    # Get current config values    
    apiUrl = hexchat.get_pluginpref('teknik_url')
    apiUsername = hexchat.get_pluginpref('teknik_username')
    apiToken = hexchat.get_pluginpref('teknik_auth_token')  
    
    # Try to upload the file
    results = teknik.UploadFile(apiUrl, file, apiUsername, apiToken)
    
    # Either print the result to the input box, or write the error message to the window
    if 'error' in results:
      hexchat.prnt('Error: ' + results['error']['message'])
    elif 'result' in results:      
      hexchat.command("settext " + results['result']['url'])
    else:
      hexchat.prnt('Unknown Error')
  else:
    hexchat.prnt('Error: Invalid File')


def teknik_set_url(url):
  hexchat.set_pluginpref('teknik_url', url)
  
def teknik_set_token(token):
  hexchat.set_pluginpref('teknik_auth_token', token)

def teknik_set_username(username):
  hexchat.set_pluginpref('teknik_username', username)
      
def teknik_command(word, word_eol, userdata):
  if len(word) < 2:
    hexchat.prnt("Error: You must specify a command")
  else:
    command = word[1].lower()
    
    if command == 'upload':
      if len(word) < 3:
        teknik_prompt()
      else:
        upload_file(word_eol[2])
    elif command == 'set':
      if len(word) < 3:
        hexchat.prnt("Error: You must specify a config option")
      else:
        option = word[2].lower()
        
        # Set value based on option
        if option == 'username':
          if len(word) < 4:
            hexchat.prnt("Error: You must specify a username")
          else:
            teknik_set_username(word_eol[3])
        elif option == 'token':
          if len(word) < 4:
            hexchat.prnt("Error: You must specify an auth token")
          else:
            teknik_set_token(word_eol[3])
        elif option == 'url':
          if len(word) < 4:
            hexchat.prnt("Error: You must specify an api url")
          else:
            teknik_set_url(word_eol[3])
        else:
          hexchat.prnt("Error: Unrecognized option")
    else:
      hexchat.prnt("Error: Unrecognized command")
  
  return hexchat.EAT_ALL

if __name__ == "__main__" and import_success:
  hexchat.hook_command("TEKNIK", teknik_command, help="""Upload files, paste text, shorten URLs, or change script options.

Usage: TEKNIK upload [<file>]
       TEKNIK set username <username>
       TEKNIK set token <auth_token>
       TEKNIK set url <api_url>""")
