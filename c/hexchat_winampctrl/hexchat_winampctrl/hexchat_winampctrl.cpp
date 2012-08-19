// hexchat_winampctrl.cpp : Defines the entry point for the console application.
//

/*
EasyWinampControl - A Winamp "What's playing" plugin for Xchat
Copyright (C) Yann HAMON & contributors

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#define _CRT_SECURE_NO_WARNINGS

#include <stdio.h>
#include <windows.h>
#include <string>
#include "xchat-plugin.h"
#include "winamp.h"

static xchat_plugin *ph;   /* plugin handle */
static int enable = 1;

std::string to_utf8(const wchar_t* buffer, int len)
{
	int nChars = ::WideCharToMultiByte(
		CP_UTF8,
		0,
		buffer,
		len,
		NULL,
		0,
		NULL,
		NULL);
	if (nChars == 0) return "";

	std::string newbuffer;
	newbuffer.resize(nChars) ;
	::WideCharToMultiByte(
		CP_UTF8,
		0,
		buffer,
		len,
		const_cast< char* >(newbuffer.c_str()),
		nChars,
		NULL,
		NULL); 

	return newbuffer;
}

std::wstring* GetCurrentSongsName(HWND hwndWinamp)
{
	wchar_t wtit[1024];

    GetWindowTextW(hwndWinamp,wtit,1024);
	std::wstring *strTitle = new std::wstring(wtit);
	if ((strTitle->find(L"**") < strTitle->length()-3)&&(strTitle->find(L"**")!=strTitle->npos)) {
		strTitle->assign(strTitle->substr(strTitle->find(L" ", strTitle->find(L"**"))+1));
	}
    strTitle->assign(strTitle->substr(strTitle->find(L" ")+1)); // Deletes the . and the following white space
    strTitle->erase(strTitle->find(L"- Winamp"));// Deletes the trailing "- winamp"		

	return strTitle; 
}

// Displays current song and controls Winamp
static int wp_cb(char *word[], char *word_eol[], void *userdata)
{
    HWND hwndWinamp = NULL;
    long int bitrate, length, elapsed, minutes, seconds, eminutes, eseconds, samplerate, nbchannels;
	size_t convertedChars = 0;
    char elapsedtime[7];
    char totaltime[7];
	std::wstring *strTitle;
	std::string this_title;
	LPCWSTR winName=L"Winamp v1.x";

    if ((hwndWinamp = FindWindow(winName,NULL)) == NULL)
        xchat_print(ph, "Winamp window not found. Is Winamp running?\n");
    else // Winamp's running
    {
        // Seems buggy when Winamp2's agent is running, and Winamp not (or Winamp3) -> crashes XChat.
        SendMessage(hwndWinamp, WM_USER, (WPARAM)0, (LPARAM)IPC_GETLISTPOS);
        strTitle=GetCurrentSongsName(hwndWinamp);
		this_title=to_utf8(strTitle->c_str(),strTitle->length());
		//xchat_printf(ph, "Title: %s\n", this_title);
        // Get samplerate
        if ((samplerate = SendMessage(hwndWinamp, WM_USER, (WPARAM)0, (LPARAM)IPC_GETINFO)) == 0)
        {
            xchat_print(ph, "Could not get current song's samplerate... !?\n");
            return XCHAT_EAT_ALL;
        }
        // Get bitrate
        if ((bitrate = SendMessage(hwndWinamp, WM_USER, (WPARAM)1, (LPARAM)IPC_GETINFO)) == 0)
        {
            xchat_print(ph, "Could not get current song's bitrate... !?\n");
            return XCHAT_EAT_ALL;
        }
        // Get number of audio channels
        if ((nbchannels = SendMessage(hwndWinamp, WM_USER, (WPARAM)2, (LPARAM)IPC_GETINFO)) == 0)
        {
            xchat_print(ph, "Could not get the number of channels... !?\n");
            return XCHAT_EAT_ALL;
        }
        // Get current track's length (in seconds).
        if ((length = SendMessage(hwndWinamp, WM_USER, (WPARAM)1, (LPARAM)IPC_GETOUTPUTTIME)) == 0)
        {
            // Could be buggy when streaming audio or video, returned length is unexpected;
            // How to detect is Winamp is streaming, and display ??:?? in that case?
            xchat_print(ph, "Could not get current song's length... !?\n");
            return XCHAT_EAT_ALL;
        }
        else
        {
            minutes = length/60;
            seconds = length%60;

            if (seconds>9)
                sprintf(totaltime, "%d:%d", minutes, seconds);
            else
                sprintf(totaltime, "%d:0%d", minutes, seconds);
        }
        // Get position of current track (in milliseconds).
        // This tends to not work when the command to play the next track is spammed.
        // Never mind. It works if it's ignored.
        //if ((elapsed = SendMessage(hwndWinamp, WM_USER, 0, IPC_GETOUTPUTTIME)) == 0)
        //{
        elapsed = SendMessage(hwndWinamp, WM_USER, 0, IPC_GETOUTPUTTIME);
        // Ignore it. It works anyway.
        //    xchat_print(ph, "Could not get current song's elapsed time... !?\n");
        //    return XCHAT_EAT_ALL;
        //}
        //else
        //{
        eminutes = (elapsed / 1000) / 60;   /* kinda stupid sounding, but e is for elapsed */
        eseconds = (elapsed / 1000) % 60;
        //xchat_printf(ph, "elapsed: %d\neminutes: %d\neseconds: %d\n", elapsed, eminutes, eseconds);
        // I'm not sure whether or not I should leave debug prints in the code...

        if (eseconds > 9)
            sprintf(elapsedtime, "%d:%d", eminutes, eseconds);
        else
            sprintf(elapsedtime, "%d:0%d", eminutes, eseconds);
        //}

        // Control of Winamp

        // Everything's here : http://winamp.com/nsdn/winamp2x/dev/sdk/api.php
        // The previous url seems dead, see http://forums.winamp.com/showthread.php?threadid=180297

        // Display track details
        if (strcmp(word[2], "") == 0)
            xchat_commandf(ph, "dispcurrsong %d %d %d %s %s %s",
                           samplerate, bitrate, nbchannels, elapsedtime, totaltime, this_title.c_str());
        // Play previous track
        else if (strcmp(word[2], "b") == 0)
        {
            SendMessage (hwndWinamp, WM_COMMAND, WINAMP_BUTTON1, 0);
			strTitle=GetCurrentSongsName(hwndWinamp);
			this_title=to_utf8(strTitle->c_str(),strTitle->length());
            xchat_printf(ph, "Now playing: %s\n", this_title.c_str());
        }
        // Play (or restart current track)
        else if (strcmp(word[2], "p") == 0)
        {
            SendMessage (hwndWinamp, WM_COMMAND, WINAMP_BUTTON2, 0);
			strTitle=GetCurrentSongsName(hwndWinamp);
			this_title=to_utf8(strTitle->c_str(),strTitle->length());
            xchat_printf(ph, "Playing: %s\n", this_title.c_str());
        }
        /*
        // I'd use just 'p' for play/pause, but it looks like foo_winamp_spam isn't working correctly:
        // Playing is 1; paused should be 3 but is always 1, and stopped is 0.
        else if (strcmp(word[2], "test") == 0)
        {
            // Put int playState; at the beginning of this function
            playState = SendMessage(hwndWinamp,WM_WA_IPC,1,IPC_ISPLAYING);
            xchat_printf(ph, "%d", playState);
        */
        // Pause (or play, if paused)
        else if (strcmp(word[2], "q") == 0)
        {
            SendMessage (hwndWinamp, WM_COMMAND, WINAMP_BUTTON3, 0);
        }
        else if (strcmp(word[2], "s") == 0)
        {
            SendMessage (hwndWinamp, WM_COMMAND, WINAMP_BUTTON4, 0);
        }
        else if (strcmp(word[2], "n") == 0)
        {
            SendMessage (hwndWinamp, WM_COMMAND, WINAMP_BUTTON5, 0);
            // Because of overhead between telling it to play a new track and
            // getting the new track's information
            Sleep(200);
			strTitle=GetCurrentSongsName(hwndWinamp);
			this_title=to_utf8(strTitle->c_str(),strTitle->length());
            xchat_printf(ph, "Now playing: %s\n", this_title.c_str());
        }
        else if (strcmp(word[2], "c") == 0)
        {
            xchat_printf(ph, "Current track: %s[%0d:%d/%0d:%d]\n",
                         this_title, eminutes, eseconds, minutes, seconds);
        }
    }
    return XCHAT_EAT_ALL;   /* eat this command so xchat and other plugins can't process it */
}

extern "C" {
	int xchat_plugin_init(xchat_plugin *plugin_handle,
						  char **plugin_name,
						  char **plugin_desc,
						  char **plugin_version,
						  char *arg)
	{
		/* we need to save this for use with any xchat_* functions */
		ph = plugin_handle;

		*plugin_name = "EasyWinampControl";
		*plugin_desc = "Plugin for remotely controlling Winamp";
		*plugin_version = "1.3.6";

		xchat_hook_command(ph, "wp", XCHAT_PRI_NORM, wp_cb,
						   "Usage: wp [ n  |  b  |  p  |  s  |  q   ]\n"\
						   "           next  prev  play  stop  pause\n", 0);

		xchat_printf(ph, "%s %s plugin loaded successfully!\n", *plugin_name, *plugin_version);

		return 1;       /* Return 1 for success */
	}
}