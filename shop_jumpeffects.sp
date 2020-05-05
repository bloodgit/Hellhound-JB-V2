#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "blood"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <shop>
#include <tf2_stocks>
#include <jumptracker>
#include <tf2items>

#pragma newdecls required

Handle g_hKv;
bool g_bEnabled[MAXPLAYERS + 1];
int g_iColor[MAXPLAYERS + 1][4];
int iLaserBeam;
char sParticleString[256][MAXPLAYERS+1];

ItemId selected_id[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "[Shop] Jump Effects", 
	author = PLUGIN_AUTHOR, 
	description = "Jump effects for my store plugin", 
	version = PLUGIN_VERSION, 
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_checkjumpeffect", Cmd_CheckJumpEffect);
	
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
	
	g_hKv = CreateKeyValues("Jump Effects");
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "jumpeffects.txt");
	
	if (!FileToKeyValues(g_hKv, buffer))
		SetFailState("Couldn't parse file %s", buffer);
	
	iLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
}

public void Shop_Started()
{
	if (g_hKv == INVALID_HANDLE)
		OnMapStart();
	
	KvRewind(g_hKv);
	char sName[64]; char sDescription[64];
	KvGetString(g_hKv, "name", sName, sizeof(sName), "Jump Effects");
	KvGetString(g_hKv, "description", sDescription, sizeof(sDescription));
	
	CategoryId category_id = Shop_RegisterCategory("jump_effects", sName, sDescription);
	
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
				Shop_SetCallbacks(_, OnJumpEffectsUsed);
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

public ShopAction OnJumpEffectsUsed(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
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
		Shop_ToggleClientCategoryOff(iClient, category_id);
		
		selected_id[iClient] = item_id;
		
		g_bEnabled[iClient] = true;
		
		KvGetString(g_hKv, "particle", sParticleString[iClient], sizeof(sParticleString), "");
		KvGetColor(g_hKv, "color", g_iColor[iClient][0], g_iColor[iClient][1], g_iColor[iClient][2], g_iColor[iClient][3]);
		return Shop_UseOn;
	}
	KvRewind(g_hKv);
	
	return Shop_Raw;
}

public void JT_OnClientJumped(int client)
{
	if (g_bEnabled[client] && !TF2_IsPlayerInCondition(client, TFCond_Cloaked)) 
	{
		float origin[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", origin);
		
		if(StrEqual(sParticleString[client], ""))
		{
			TE_SetupBeamRingPoint(origin, 0.0, 50.0, iLaserBeam, 0, 0, 0, 1.0, 2.0, 0.0, g_iColor[client], 150, FBEAM_NOTILE);
			TE_SendToAll();
		}
		else
		{
			CreateTempParticle(sParticleString[client], client);
		}
	}
}

public Action Cmd_CheckJumpEffect(int client, int args)
{
	if (g_bEnabled[client])
		ReplyToCommand(client, "[DEBUG] You have a jump effect enabled.");
} 

void CreateTempParticle(char[] particle, int entity = -1, float origin[3] = NULL_VECTOR, float angles[3] = {0.0, 0.0, 0.0}, bool resetparticles = false)
{
	int tblidx = FindStringTable("ParticleEffectNames");

	char tmp[256];
	int stridx = INVALID_STRING_INDEX;

	for (int i = 0; i < GetStringTableNumStrings(tblidx); i++)
	{
		ReadStringTable(tblidx, i, tmp, sizeof(tmp));
		if(StrEqual(tmp, particle, false))
		{
			stridx = i;
			break;
		}
	}

	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", origin[0]);
	TE_WriteFloat("m_vecOrigin[1]", origin[1]);
	TE_WriteFloat("m_vecOrigin[2]", origin[2]);
	TE_WriteVector("m_vecAngles", angles);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	TE_WriteNum("entindex", entity);
	TE_WriteNum("m_iAttachType", 1);
	TE_WriteNum("m_bResetParticles", resetparticles);
	TE_SendToAll();
}

stock void ClearTempParticles(int client)
{
	float empty[3];
	CreateTempParticle("sandwich_fx", client, empty, empty, true);
}
