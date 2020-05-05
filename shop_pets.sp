#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "blood"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <shop>

Handle g_hKv;
bool g_bEnabled[MAXPLAYERS + 1];

// PETS




#pragma newdecls required

public Plugin myinfo = 
{
	name = "[Shop] TF2 Pets",
	author = PLUGIN_AUTHOR,
	description = "Adds pet functionality to the shop.",
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
	
	g_hKv = CreateKeyValues("Pets");
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "pets.txt");
	
	if (!FileToKeyValues(g_hKv, buffer))
		SetFailState("Couldn't parse file %s", buffer);
}

public void Shop_Started()
{
	if (g_hKv == INVALID_HANDLE)
		OnMapStart();
	
	KvRewind(g_hKv);
	char sName[64]; char sDescription[64];
	KvGetString(g_hKv, "name", sName, sizeof(sName), "Pets");
	KvGetString(g_hKv, "description", sDescription, sizeof(sDescription));
	
	CategoryId category_id = Shop_RegisterCategory("shop_pets", sName, sDescription);
	
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
				Shop_SetCallbacks(_, OnPetsUsed);
				Shop_EndItem();
			}
		} while (KvGotoNextKey(g_hKv));
	}
	
	KvRewind(g_hKv);
}

public void OnClientPostAdminCheck(int client)
{
	if (g_bEnabled[client])
		g_bEnabled[client] = false;
}

public ShopAction OnPetsUsed(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_bEnabled[iClient] = false;
		return Shop_UseOff;
	}
	
	KvRewind(g_hKv);
	if (KvJumpToKey(g_hKv, item, false))
	{
		g_bEnabled[iClient] = true;
		
		return Shop_UseOn;
	}
	KvRewind(g_hKv);
	
	return Shop_Raw;
}