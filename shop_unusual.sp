#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "blood"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <tf2items>
#include <shop>
#include <tf_econ_data>

#pragma newdecls required

Handle g_hKv;
bool g_bEnabled[MAXPLAYERS + 1];
int g_iUnusualID[MAXPLAYERS + 1];

ItemId selected_id[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "[Shop] TF2 Unusuals", 
	author = PLUGIN_AUTHOR, 
	description = "Add Team Fortress 2 unusuals to the store.", 
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
	
	g_hKv = CreateKeyValues("Unusual Effects");
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "unusual_effects.txt");
	
	if (!FileToKeyValues(g_hKv, buffer))
		SetFailState("Couldn't parse file %s", buffer);
}

public void Shop_Started()
{
	if (g_hKv == INVALID_HANDLE)
		OnMapStart();
	
	KvRewind(g_hKv);
	char sName[64]; char sDescription[64];
	KvGetString(g_hKv, "name", sName, sizeof(sName), "Unusual Effects");
	KvGetString(g_hKv, "description", sDescription, sizeof(sDescription));
	
	CategoryId category_id = Shop_RegisterCategory("unusual_effects", sName, sDescription);
	
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
				Shop_SetCallbacks(_, OnUnusualEffectsUsed);
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

public ShopAction OnUnusualEffectsUsed(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
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
		g_iUnusualID[iClient] = KvGetNum(g_hKv, "unusual_id");
		PrintToChat(iClient, "\x04[Shop] \x01You've selected a unusual effect!, please goto spectators and back to activate the effect.");
		
		selected_id[iClient] = item_id;
		
		Shop_ToggleClientCategoryOff(iClient, category_id);
		
		return Shop_UseOn;
	}
	KvRewind(g_hKv);
	
	return Shop_Raw;
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int iItemDefinitionIndex, Handle &hItem)
{
	hItem = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES | PRESERVE_ATTRIBUTES);
	
	TF2Items_SetNumAttributes(hItem, 1); // 1 Attribute is unusual.
	
	if (g_bEnabled[client])
	{
		char sItemSlotName[16];
		TF2Econ_GetItemDefinitionString(iItemDefinitionIndex, "item_slot", sItemSlotName, sizeof(sItemSlotName));
		
		if(StrEqual(sItemSlotName, "head", false))
		{
			TF2Items_SetQuality(hItem, 5);
			TF2Items_SetAttribute(hItem, 0, 134, float(g_iUnusualID[client]));
		}
	}
	
	return Plugin_Changed;
} 