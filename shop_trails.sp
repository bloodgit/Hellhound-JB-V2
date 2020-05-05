#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <shop>
#include <smartdm>

#define PLUGIN_VERSION	"2.2.2"
#define CATEGORY	"trails"

bool toggleEffects = false;
bool hide = false;

Handle hKvTrails;

int iTeam[MAXPLAYERS+1];
int g_SpriteModel[MAXPLAYERS + 1] = {-1, ...};
ItemId selected_id[MAXPLAYERS+1];

#pragma newdecls required

Handle prchArray;

public Plugin myinfo =
{
	name = "[Shop] Trails",
	author = "blood",
	description = "Trails that follows a player",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_death", PlayerDeath);
	HookEvent("player_team", PlayerTeam);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			iTeam[i] = GetClientTeam(i);
		}
	}
	
	prchArray = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	
	RegAdminCmd("sm_trails_reload", Command_TrailsReload, ADMFLAG_ROOT, "Reloads trails config list");
	
	if (Shop_IsStarted()) 
		Shop_Started();
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
	for (int i = 1; i <= MaxClients; i++)
	{
		KillTrail(i);
	}
}

public void OnAllPluginsLoaded()
{
	toggleEffects = LibraryExists("specialfx");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "specialfx"))
	{
		toggleEffects = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "specialfx"))
	{
		toggleEffects = false;
	}
}

public void OnMapStart()
{
	LoadKeyStructure();
	
	char buffer[PLATFORM_MAX_PATH];
	for (int i = 0; i < GetArraySize(prchArray); i++)
	{
		GetArrayString(prchArray, i, buffer, sizeof(buffer));
		Downloader_AddFileToDownloadsTable(buffer);
		PrecacheModel(buffer, true);
	}
}

void LoadKeyStructure()
{
	if (hKvTrails == INVALID_HANDLE)
	{
		hKvTrails = CreateKeyValues("Trails");
		
		char _buffer[PLATFORM_MAX_PATH];
		Shop_GetCfgFile(_buffer, sizeof(_buffer), "trails.txt");
		
		if (!FileToKeyValues(hKvTrails, _buffer)) SetFailState("\"%s\" not found", _buffer);
		
		KvRewind(hKvTrails);
		
		view_as<int>(hide) = KvGetNum(hKvTrails, "hide_opposite_team", 1);
	}
}

public void Shop_Started()
{
	LoadKeyStructure();
	
	char name[64]; char description[64];
	KvGetString(hKvTrails, "name", name, sizeof(name), "Trails");
	KvGetString(hKvTrails, "description", description, sizeof(description));
	
	CategoryId category_id = Shop_RegisterCategory(CATEGORY, name, description);
	
	char item[64]; char item_name[64]; char item_description[64]; char buffer[PLATFORM_MAX_PATH];
	KvRewind(hKvTrails);
	if (KvGotoFirstSubKey(hKvTrails))
	{
		ClearArray(prchArray);
		do
		{
			KvGetString(hKvTrails, "material", buffer, sizeof(buffer));
			if (!File_ExtEqual(buffer, "vmt")) continue;
			
			KvGetSectionName(hKvTrails, item, sizeof(item));
			
			if (Shop_StartItem(category_id, item))
			{
				KvGetString(hKvTrails, "name", item_name, sizeof(item_name), item);
				KvGetString(hKvTrails, "description", item_description, sizeof(item_description));
				Shop_SetInfo(item_name, item_description, KvGetNum(hKvTrails, "price", 500), KvGetNum(hKvTrails, "sell_price", -1), Item_Togglable, KvGetNum(hKvTrails, "duration", 86400));
				Shop_SetCallbacks(OnItemRegistered, OnEquipItem);
				
				if (KvJumpToKey(hKvTrails, "Attributes", false))
				{
					Shop_KvCopySubKeysCustomInfo(hKvTrails);
					KvGoBack(hKvTrails);
				}
				
				Shop_EndItem();
			}
		}
		while (KvGotoNextKey(hKvTrails));
		
		KvRewind(hKvTrails);
	}
}

public void OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	if (KvJumpToKey(hKvTrails, item))
	{
		char buffer[PLATFORM_MAX_PATH];
		KvGetString(hKvTrails, "material", buffer, sizeof(buffer));
		Downloader_AddFileToDownloadsTable(buffer);
		PrecacheModel(buffer, true);
		PushArrayString(prchArray, buffer);
		
		KvSetNum(hKvTrails, "id", view_as<int>(item_id));
		KvRewind(hKvTrails);
	}
}

public Action Command_TrailsReload(int client, int args)
{
	if (hKvTrails != INVALID_HANDLE)
	{
		CloseHandle(hKvTrails);
		hKvTrails = INVALID_HANDLE;
	}
	
	OnPluginEnd();
	Shop_Started();
	
	ReplyToCommand(client, "Trails config list reloaded successfully!");
	
	return Plugin_Handled;
}

public ShopAction OnEquipItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		OnClientDisconnect(client);
		
		selected_id[client] = INVALID_ITEM;
		
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(client, category_id);
	
	selected_id[client] = item_id;
	
	SpriteTrail(client);
	
	return Shop_UseOn;
}

public void OnMapEnd()
{
	for (int client = 1; client <= MAXPLAYERS; client++)
	{
		g_SpriteModel[client] = -1;
	}
}

public void OnClientDisconnect(int client)
{
	KillTrail(client);
}

public void OnClientDisconnect_Post(int client)
{
	iTeam[client] = 0;
	selected_id[client] = INVALID_ITEM;
	g_SpriteModel[client] = -1;
}

public Action PlayerSpawn(Handle event,const char[] name, bool dontBroadcast)
{
	CreateTimer(1.0, GiveTrail, GetEventInt(event, "userid"));
}

public Action PlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	iTeam[client] = GetEventInt(event, "team");
}

public Action PlayerDeath(Handle event,const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	KillTrail(client);
}

public Action GiveTrail(Handle timer, any userid)
{
	SpriteTrail(GetClientOfUserId(userid));
}


bool SpriteTrail(int client)
{
	if (!client)
	{
		return false;
	}

	KillTrail(client);
	
	if (selected_id[client] == INVALID_ITEM || iTeam[client] == 0 || IsFakeClient(client))
	{
		return false;
	}
	if (!IsPlayerAlive(client) || !(1 < iTeam[client] < 4))
	{
		return true;
	}
	
	char item[SHOP_MAX_STRING_LENGTH];
	item[0] = '\0';
	Shop_GetItemById(selected_id[client], item, sizeof(item));
	
	if (!item[0] || !KvJumpToKey(hKvTrails, item))
	{
		PrintToServer("Item %s is not exists");
		return false;
	}
	
	g_SpriteModel[client] = CreateEntityByName("env_spritetrail");
	if (g_SpriteModel[client] != -1) 
	{
		char buffer[PLATFORM_MAX_PATH]; float dest_vector[3];
		
		DispatchKeyValueFloat(g_SpriteModel[client], "lifetime", KvGetFloat(hKvTrails, "lifetime", 1.0));
		
		KvGetString(hKvTrails, "startwidth", buffer, sizeof(buffer), "10");
		DispatchKeyValue(g_SpriteModel[client], "startwidth", buffer);
		
		KvGetString(hKvTrails, "endwidth", buffer, sizeof(buffer), "6");
		DispatchKeyValue(g_SpriteModel[client], "endwidth", buffer);
		
		KvGetString(hKvTrails, "material", buffer, sizeof(buffer));
		DispatchKeyValue(g_SpriteModel[client], "spritename", buffer);
		DispatchKeyValue(g_SpriteModel[client], "renderamt", "255");
		
		KvGetString(hKvTrails, "color", buffer, sizeof(buffer));
		DispatchKeyValue(g_SpriteModel[client], "rendercolor", buffer);
		
		IntToString(KvGetNum(hKvTrails, "rendermode", 1), buffer, sizeof(buffer));
		DispatchKeyValue(g_SpriteModel[client], "rendermode", buffer);
		
		DispatchSpawn(g_SpriteModel[client]);
		
		KvGetVector(hKvTrails, "position", dest_vector);
		
		float or[3]; float ang[3];
		float fForward[3];
		float fRight[3];
		float fUp[3];
		
		GetClientAbsOrigin(client, or);
		GetClientAbsAngles(client, ang);
		
		GetAngleVectors(ang, fForward, fRight, fUp);

		or[0] += fRight[0]*dest_vector[0] + fForward[0]*dest_vector[1] + fUp[0]*dest_vector[2];
		or[1] += fRight[1]*dest_vector[0] + fForward[1]*dest_vector[1] + fUp[1]*dest_vector[2];
		or[2] += fRight[2]*dest_vector[0] + fForward[2]*dest_vector[1] + fUp[2]*dest_vector[2];
		
		TeleportEntity(g_SpriteModel[client], or, NULL_VECTOR, NULL_VECTOR);
		
		SetVariantString("!activator");
		AcceptEntityInput(g_SpriteModel[client], "SetParent", client); 
		SetEntPropFloat(g_SpriteModel[client], Prop_Send, "m_flTextureRes", 0.05);
		SetEntPropEnt(g_SpriteModel[client], Prop_Send, "m_hOwnerEntity", client);
		
		if (hide)
		{
			SDKHook(g_SpriteModel[client], SDKHook_SetTransmit, Hook_TrailShouldHide);
		}
	}
	KvRewind(hKvTrails);
	
	return true;
}

public Action Hook_TrailShouldHide(int entity, int client)
{
	if (toggleEffects)
	{
		return Plugin_Handled;
	}
	
	if (g_SpriteModel[client] == entity || iTeam[client] < 2)
	{
		return Plugin_Continue;
	}
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner != -1 && iTeam[owner] != iTeam[client])
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void KillTrail(int client)
{
	if (g_SpriteModel[client] > MaxClients && IsValidEdict(g_SpriteModel[client]))
	{
		AcceptEntityInput(g_SpriteModel[client], "kill");
	}
	
	g_SpriteModel[client] = -1;
}

void File_GetExtension(const char[] path, char[] buffer, int size)
{
	int extpos = FindCharInString(path, '.', true);
	
	if (extpos == -1)
	{
		buffer[0] = '\0';
		return;
	}

	strcopy(buffer, size, path[++extpos]);
}

bool File_ExtEqual(const char[] path, const char[] ext, bool caseSensetive = false)
{
	char buf[4];
	File_GetExtension(path, buf, sizeof(buf));
	return StrEqual(buf, ext, caseSensetive);
}