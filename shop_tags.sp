#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "blood"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <chat-processor>
#include <shop>

Handle g_hKv;
bool g_bEnabled[MAXPLAYERS + 1];
char g_sTagString[256][MAXPLAYERS+1];

ItemId selected_id[MAXPLAYERS+1];

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[Shop] Chat Tags",
	author = PLUGIN_AUTHOR,
	description = "Chat tags stuff for FD-Shop",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	if (Shop_IsStarted())
		Shop_Started();
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnMapStart()
{
	if (g_hKv != INVALID_HANDLE)
		CloseHandle(g_hKv);
	
	char buffer[PLATFORM_MAX_PATH];
	
	g_hKv = CreateKeyValues("Chat Tags");
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "chat_tags.txt");
	
	if (!FileToKeyValues(g_hKv, buffer))
		SetFailState("Couldn't parse file %s", buffer);
}

public void Shop_Started()
{
	if (g_hKv == INVALID_HANDLE)
		OnMapStart();
	
	KvRewind(g_hKv);
	char sName[64]; char sDescription[64];
	KvGetString(g_hKv, "name", sName, sizeof(sName), "Chat Tags");
	KvGetString(g_hKv, "description", sDescription, sizeof(sDescription));
	
	CategoryId category_id = Shop_RegisterCategory("chat_tags", sName, sDescription);
	
	KvRewind(g_hKv);
	
	if (KvGotoFirstSubKey(g_hKv))
	{
		do
		{
			if (KvGetSectionName(g_hKv, sName, sizeof(sName)) && Shop_StartItem(category_id, sName))
			{
				KvGetString(g_hKv, "name", sDescription, sizeof(sDescription), sName);
				Shop_SetInfo(sDescription, "", KvGetNum(g_hKv, "price", 1000), KvGetNum(g_hKv, "sellprice", -1), Item_Togglable, KvGetNum(g_hKv, "duration", 604800));
				Shop_SetCustomInfo("level", KvGetNum(g_hKv, "level", 0));
				Shop_SetCallbacks(_, OnChatTagsUsed);
				Shop_EndItem();
			}
		} while (KvGotoNextKey(g_hKv));
	}
	
	KvRewind(g_hKv);
}

public void OnClientPostAdminCheck(int client)
{
	if(g_bEnabled[client])
		g_bEnabled[client] = false;
}

public ShopAction OnChatTagsUsed(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_bEnabled[iClient] = false;
		
		selected_id[iClient] = INVALID_ITEM;
		
		return Shop_UseOff;
	}
	
	KvRewind(g_hKv);
	if (KvJumpToKey(g_hKv, item, false))
	{
		g_bEnabled[iClient] = true;
		
		Shop_ToggleClientCategoryOff(iClient, category_id);

		KvGetString(g_hKv, "tag", g_sTagString[iClient], sizeof(g_sTagString));
		
		selected_id[iClient] = item_id;
		
		return Shop_UseOn;
	}
	KvRewind(g_hKv);
	
	return Shop_Raw;
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	if(g_bEnabled[author])
	{
		Format(name, MAXLENGTH_NAME, "%s{default}%s", g_sTagString[author], name);
	}
		
	return Plugin_Changed;
}