/* Global Hotkeys Plugin
* Copyright (C) 2017 Mark Jansen
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; either version 2 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
*/

#include "hexchat-plugin.h"
#include <vector>
#include <string>
#include <algorithm>

#include <Windows.h>

#define PNAME "Global Hotkeys"
#define PDESC "Register global hotkeys to switch channels"
#define PVERSION "1.1"

static HANDLE g_MessageThread;
static DWORD g_MessageThreadId;
static hexchat_plugin *ph;
static hexchat_hook *g_Timer;
static int g_Channels;
static LONG g_SwitchToChannel = 0;
static LONG g_SwitchRel = 0;

#define EXIT_THREAD_MSG     (WM_USER + 1)


static int open_cb(char *word[], void *userdata)
{
    g_Channels++;
    PostThreadMessage(g_MessageThreadId, WM_NULL, 0, 0);

    return HEXCHAT_EAT_NONE;
}

static int close_cb(char *word[], void *userdata)
{
    --g_Channels;
    PostThreadMessage(g_MessageThreadId, WM_NULL, 0, 0);

    return HEXCHAT_EAT_NONE;
}

static int count_channels()
{
    int count = 0;
    hexchat_list *list = hexchat_list_get(ph, "channels");
    if (!list)
        return 0;
    
    while (hexchat_list_next(ph, list))
    {
        count++;
    }
    hexchat_list_free(ph, list);

    return count;
}

struct TabInfo
{
    int Server;
    int Type;
    std::string CmpName;
    hexchat_context* Ctx;

    TabInfo(hexchat_list *list)
    {
        Server = hexchat_list_int(ph, list, "id");
        Type = hexchat_list_int(ph, list, "type");
        CmpName = hexchat_list_str(ph, list, "channel");
        Ctx = (hexchat_context*)hexchat_list_str(ph, list, "context");
        std::transform(CmpName.begin(), CmpName.end(), CmpName.begin(), tolower);
    }
};

struct
{
    bool operator()(const TabInfo& a, TabInfo& b)
    {
        if (a.Server != b.Server)
            return a.Server < b.Server;
        if (a.Type != b.Type)
            return a.Type < b.Type;

        return a.CmpName < b.CmpName;
    }
} customTab;

static bool channel_list(std::vector<TabInfo>& data)
{
    hexchat_list *list = hexchat_list_get(ph, "channels");

    data.clear();

    if (!list)
    {
        hexchat_printf(ph, PNAME ": Failed to retrieve channel list\n");
        return false;
    }

    while (hexchat_list_next(ph, list))
    {
        data.push_back(TabInfo(list));
    }
    hexchat_list_free(ph, list);

    std::sort(data.begin(), data.end(), customTab);
    return true;
}


static void goto_channel(int num, bool rel)
{
    std::vector<TabInfo> data;

    if (!channel_list(data))
    {
        return;
    }

    if (rel)
    {
        int cur = -1;
        hexchat_context* ctx = hexchat_get_context(ph);
        for (size_t n = 0; n < data.size(); ++n)
        {
            if (data[n].Ctx == ctx)
            {
                cur = (int)n;
                break;
            }
        }
        if (cur < 0)
        {
            hexchat_printf(ph, PNAME ": Could not find active context\n");
        }
        num = cur + num + (int)data.size();
        num %= data.size();
    }

    if (num >= data.size() || num < 0)
    {
        hexchat_printf(ph, PNAME ": Asked to activate a non-existing channel %d\n", num);
        return;
    }

    //hexchat_printf(ph, "Goto channel: %d (%s)\n", num, data[num].CmpName.c_str());
    hexchat_set_context(ph, data[num].Ctx);
    hexchat_command(ph, "GUI FOCUS");
}

static int timeout_cb(void *userdata)
{
    LONG nextChannel = InterlockedExchange(&g_SwitchToChannel, 0);
    if (nextChannel)
    {
        nextChannel = (nextChannel + (8)) % 10;
        goto_channel(nextChannel, false);
    }
    nextChannel = InterlockedExchange(&g_SwitchRel, 0);
    if (nextChannel)
    {
        goto_channel((int)nextChannel, true);
    }
    return 1;
}

static void register_keys(int& numChannels, int newChannels)
{
    if (numChannels != newChannels)
    {
        for (int n = 0; n < min(numChannels, 10); ++n)
        {
            UnregisterHotKey(NULL, n);
        }

        numChannels = newChannels;

        for (int n = 0; n < min(numChannels, 10); ++n)
        {
            RegisterHotKey(NULL, n, MOD_ALT | MOD_CONTROL | MOD_NOREPEAT, '0' + ((n+1)%10));
        }
    }
}

DWORD WINAPI ThreadProc(LPVOID)
{
    MSG msg = { 0 };
    int numChannels = 0;

    register_keys(numChannels, g_Channels);
    RegisterHotKey(NULL, VK_LEFT, MOD_ALT | MOD_CONTROL | MOD_NOREPEAT, VK_LEFT);
    RegisterHotKey(NULL, VK_RIGHT, MOD_ALT | MOD_CONTROL | MOD_NOREPEAT, VK_RIGHT);

    while (GetMessage(&msg, NULL, 0, 0) > 0)
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);

        register_keys(numChannels, g_Channels);

        if (msg.message == WM_HOTKEY)
        {
            int key = HIWORD(msg.lParam);
            if (key >= '0' && key <= '9')
            {
                key -= '0';
                InterlockedExchange(&g_SwitchToChannel, key + 1);
            }
            else if (key == VK_LEFT)
            {
                InterlockedDecrement(&g_SwitchRel);
            }
            else if (key == VK_RIGHT)
            {
                InterlockedIncrement(&g_SwitchRel);
            }
        }
        else if (msg.message == EXIT_THREAD_MSG)
        {
            PostQuitMessage(0);
        }
    }

    register_keys(numChannels, 0);
    UnregisterHotKey(NULL, VK_LEFT);
    UnregisterHotKey(NULL, VK_RIGHT);

    return 0;
}


void hexchat_plugin_get_info(char **name, char **desc, char **version, void **reserved)
{
    *name = PNAME;
    *desc = PDESC;
    *version = PVERSION;
}

int hexchat_plugin_init(hexchat_plugin *plugin_handle, char **plugin_name, char **plugin_desc, char **plugin_version, char *arg)
{
    ph = plugin_handle;

    g_MessageThread = CreateThread(NULL, NULL, ThreadProc, NULL, 0, &g_MessageThreadId);

    if (g_MessageThread)
    {
        *plugin_name = PNAME;
        *plugin_desc = PDESC;
        *plugin_version = PVERSION;

        hexchat_hook_print(ph, "Open Context", HEXCHAT_PRI_NORM, open_cb, 0);
        hexchat_hook_print(ph, "Close Context", HEXCHAT_PRI_NORM, close_cb, 0);
        g_Channels = count_channels();
        g_Timer = hexchat_hook_timer(ph, 1000, timeout_cb, NULL);
        PostThreadMessage(g_MessageThreadId, WM_NULL, 0, 0);
        hexchat_printf(ph, PNAME " " PVERSION " loaded, %d channels\n", g_Channels);

        return 1;
    }
    return 0;
}

int hexchat_plugin_deinit()
{
    if (g_Timer)
    {
        hexchat_unhook(ph, g_Timer);
        g_Timer = NULL;
    }
    PostThreadMessage(g_MessageThreadId, EXIT_THREAD_MSG, 0, 0);
    WaitForSingleObject(g_MessageThread, INFINITE);
    hexchat_print(ph, PNAME " unloading.\n");

    return 1;
}
