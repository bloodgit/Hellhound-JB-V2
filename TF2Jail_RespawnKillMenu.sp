#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <morecolors>

#pragma newdecls required

int g_iAttacker[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[TF2] Respawn Kill", 
	author = PLUGIN_AUTHOR, 
	description = "Respawn victims of attackers.", 
	version = PLUGIN_VERSION, 
	url = ""
};

public void OnPluginStart()
{
	HookEvent("player_death", PlayerDeath);
	
	RegAdminCmd("sm_rpmenu", Respawn_Menu, ADMFLAG_ROOT, "Respawns all victims selected by players in a menu.");
	
	HookEvent("teamplay_round_win", RoundWin);
}

public Action RoundWin(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			g_iAttacker[i] = 0;
		}
	}
}

public Action Respawn_Menu(int client, int args)
{
	Menu menu = new Menu(RespawnKill_MenuHandler, MENU_ACTIONS_ALL);
	menu.SetTitle("Respawn Kill Menu");
	
	char sName[MAX_NAME_LENGTH];
	char sUserId[10];
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && CountVictims(i) > 0)
		{
			GetClientName(i, sName, sizeof(sName));
			IntToString(GetClientUserId(i), sUserId, sizeof(sUserId));
			
			menu.AddItem(sUserId, sName);
		}
	}
	
	menu.ExitButton = true;
	menu.Display(client, 20);
}

public int RespawnKill_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Start:
		{
			PrintToServer("Displaying menu"); // Log it
		}
		
		case MenuAction_Display:
		{
			PrintToServer("Client %d was sent menu with panel %x", param1, param2);
		}
		
		case MenuAction_Select:
		{
			char info[32];
			int userid, target;
			
			menu.GetItem(param2, info, sizeof(info));
			
			userid = StringToInt(info);
			
			if ((target = GetClientOfUserId(userid)) != 0)
			{
				Respawn(param1, target);
			}
		}
		
		case MenuAction_Cancel:
		{
			PrintToServer("Client %d's menu was cancelled for reason %d", param1, param2);
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
		
		case MenuAction_DrawItem:
		{
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);
		}
		
		case MenuAction_DisplayItem:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
		}
	}
	
	return 0;
}

public void PlayerDeath(Handle hEvent, const char[] sName, bool bDontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	if (IsClientInGame(victim) && IsClientInGame(attacker))
		g_iAttacker[victim] = attacker;
}

int Respawn(int client, int attacker)
{
	for (int i = 0; i < sizeof(g_iAttacker); i++)
	{
		if (g_iAttacker[i] != attacker)
			continue;
		
		TF2_RespawnPlayer(i);
		g_iAttacker[i] = 0;
	}
	
	CPrintToChatAll("{orange}Hellhound {white}| {orange}%N {white}respawned all victims killed by {orange}%N", client, attacker);
}

int CountVictims(int attacker)
{
	int count = 0;
	for (int i = 0; i < sizeof(g_iAttacker); i++)
	{
		if (g_iAttacker[i] == attacker)
		{
			count++;
		}
	}
	
	return count;
} 