/*
  Spotify Now Playing plugin
  Original X-Chat source by S3NSA: http://forum.cheatengine.org/viewtopic.php?t=405073&sid=83516683cf425324e4596a993fcec09b
  Rewritten for HexChat by Freek
*/

#include <windows.h>
#include <stdlib.h>
#include <string.h>
#include "hexchat-plugin.h"


static hexchat_plugin *ph;   /* plugin handle */
static char name[] = "Spotify Now Playing";
static char desc[] = "Sends currently playing song in Spotify to the current channel.";
static char version[] = "0.1";
static const char helpmsg[] = "Sends currently playing song in Spotify to the current channel. USAGE: /spotify";
static const LPCTSTR SPOTIFY_CLASS_NAME = TEXT("SpotifyMainWindow");

static int spotify_cb(char *word[], char *word_eol[], void *userdata)
{
	HWND hWnd = FindWindow(SPOTIFY_CLASS_NAME, NULL);
	if(hWnd != NULL)
	{
		int title_length = GetWindowTextLength(hWnd);
		if(title_length != 0)
		{
			char* title;
			title = (char*)malloc((++title_length) * sizeof *title );
			if(title != NULL)
			{
				GetWindowText(hWnd, title, title_length);
				if(strcmp(title, "Spotify") != 0)
				{
					hexchat_commandf(ph, "me is now listening to: %s", title + (10 * sizeof *title));
				}
				else
				{
					hexchat_print(ph, "Spotify is not playing anything right now.");
				}
			}
			else
			{
				hexchat_print(ph, "Unable to allocate memory for title");
			}
			free(title);
		}
		else
		{
			hexchat_print(ph, "Unable to get Spotify window title.");
		}
	}
	else
	{
		hexchat_print(ph, "Unable to find Spotify window.");
	}
	return HEXCHAT_EAT_ALL;
}

int hexchat_plugin_init(hexchat_plugin *plugin_handle,
                      char **plugin_name,
                      char **plugin_desc,
                      char **plugin_version,
                      char *arg)
{
	/* we need to save this for use with any hexchat_* functions */
	ph = plugin_handle;

	/* tell HexChat our info */
	*plugin_name = name;
	*plugin_desc = desc;
	*plugin_version = version;

	hexchat_hook_command (ph, "SPOTIFY", HEXCHAT_PRI_NORM, spotify_cb, helpmsg, 0);

	hexchat_printf (ph, "%s plugin loaded\n", name);

	return 1;	/* return 1 for success */
}

int hexchat_plugin_deinit(hexchat_plugin *plugin_handle)
{
	hexchat_printf (plugin_handle, "%s plugin unloaded\n", name);
	return 1;
}