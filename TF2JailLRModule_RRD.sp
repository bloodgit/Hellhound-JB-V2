#include <sourcemod>
#include <morecolors>
#include <tf2jailredux>
#include <tf2items_giveweapon>

#pragma semicolon 1
#pragma newdecls required
// #include "TF2JailRedux/stocks.inc"

#define PLUGIN_VERSION 		"1.0.0"

JBGameMode
gamemode
;

ConVar g_bFriendlyFire;

Handle g_hGracePeriodTimer;

public Plugin myinfo = 
{
	name = "TF2Jail Rapid Rockets LR Module", 
	author = "blood", 
	description = "Adds the infamous incorporation of Rapid Rockets Day into an LR", 
	version = PLUGIN_VERSION, 
	url = ""
};

ConVar PickCount;

public void OnPluginStart()
{
	PickCount = CreateConVar("sm_jbrrd_pickcount", "5", "Maximum number of times this LR can be picked in a single map. 0 for no limit", FCVAR_NOTIFY, true, 0.0);
	
	g_bFriendlyFire = FindConVar("mp_friendlyfire");
	
	AutoExecConfig(true, "LRModuleRRD");
	
	LoadTranslations("tf2jail_redux.phrases");
}

#define CHECK() 				if ( JBGameMode_GetProperty("iLRType") != TF2JailRedux_LRIndex() ) return

public void OnLibraryRemoved(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false))
	{
		
	}
}

public void OnLibraryAdded(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false))
	{	
		InitSubPlugin();
		JB_Hook(OnHudShow, fwdOnHudShow);
		JB_Hook(OnLRPicked, fwdOnLRPicked);
		JB_Hook(OnPanelAdd, fwdOnPanelAdd);
		JB_Hook(OnMenuAdd, fwdOnMenuAdd); // The necessities
		JB_Hook(OnRoundStart, fwdOnRoundStart);
		JB_Hook(OnRoundEnd, fwdOnRoundEnd);
		JB_Hook(OnVariableReset, fwdOnVariableReset);
	}
}

public void InitSubPlugin()
{
	gamemode = new JBGameMode();

	g_LR = LastRequest.CreateFromConfig("Rapid Rockets Day");
	
	if (g_LR == null) // If it's her first time, set the mood
	{
		g_LR = LastRequest.Create("Rapid Rockets Day");
		g_LR.SetDescription("Play a nice round of VSH");
		g_LR.SetAnnounceMessage("{default}{NAME}{burlywood} has selected {default}Versus Saxton Hale{burlywood} as their last request.");

		g_LR.SetParameterNum("Disabled", 0);
		g_LR.SetParameterNum("OpenCells", 1);
		g_LR.SetParameterNum("TimerStatus", 1);
		g_LR.SetParameterNum("TimerTime", 600);
		g_LR.SetParameterNum("LockWarden", 1);
		g_LR.SetParameterNum("UsesPerMap", 3);
		g_LR.SetParameterNum("IsWarday", 1);
		g_LR.SetParameterNum("NoMuting", 1);
		g_LR.SetParameterNum("DisableMedic", 1);
		g_LR.SetParameterNum("AllowBuilding", 1);
		g_LR.SetParameterNum("RegenerateReds", 0);	// Changing this does nothing
		g_LR.SetParameterNum("EnableCriticals", 0);
		g_LR.SetParameterNum("IgnoreRebels", 1);
		g_LR.SetParameterNum("VoidFreekills", 1);
		g_LR.SetParameterNum("AllowWeapons", 1);

		g_LR.SetPropertyNum("bOneGuardLeft", 1);

		g_LR.ExportToConfig(.create = true, .createonly = true);
	}

	LoadJBHooks();
}

public void fwdOnHudShow(char strHud[128])
{
	CHECK();
	
	strcopy(strHud, 128, "Rapid Rockets Day");
}

public void fwdOnRoundStart(Event event)
{
	CHECK();
	
	gamemode.bIsWardenLocked = true;
	gamemode.bCellsOpened = true;
	gamemode.bDisableCriticals = true;
	gamemode.bIsWarday = true;
	gamemode.bDisableKillSpree = true;
	gamemode.bIgnoreRebels = true;
	
	gamemode.DoorHandler(OPEN);
	
	g_bFriendlyFire.BoolValue = false;
	
	PrintCenterTextAll("A grace period of 30 seconds is now underway.");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			TF2Items_GiveWeapon(i, 8018);
			
			SetEntProp(i, Prop_Data, "m_takedamage", 1, 1);
		}
	}
	
	g_hGracePeriodTimer = CreateTimer(30.0, Timer_GracePeriod);
}

public void fwdOnRoundEnd(Event event)
{
	CHECK();
	
	g_bFriendlyFire.BoolValue = false;
	
	KillTimer(g_hGracePeriodTimer);
	
	if (g_hGracePeriodTimer != INVALID_HANDLE)
	{
		KillTimer(g_hGracePeriodTimer);
		g_hGracePeriodTimer = INVALID_HANDLE;
	}
}

public Action Timer_GracePeriod(Handle timer)
{
	PrintCenterTextAll("The grace period is now over!.");
	g_bFriendlyFire.BoolValue = true;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			SetEntProp(i, Prop_Data, "m_takedamage", 2, 1);
		}
	}
}

public Action fwdOnLRPicked(const JBPlayer Player, const int selection, ArrayList arrLRS)
{	
	if (selection == TF2JailRedux_LRIndex())
		CPrintToChatAll("%t %t", "Plugin Tag", "LR RRD Chosen", Player.index);
	
	return Plugin_Continue;
}

public void fwdOnPanelAdd(const int index, char name[64])
{
	if (index != TF2JailRedux_LRIndex())
		return;
	
	strcopy(name, sizeof(name), "Rapid Rockets Day");
}

public void fwdOnMenuAdd(const int index, int &max, char strName[64])
{
	if (index != TF2JailRedux_LRIndex())
		return;
	
	max = PickCount.IntValue;
	strcopy(strName, sizeof(strName), "Rapid Rockets Day");
}

public void fwdOnVariableReset(const JBPlayer Player)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			SetEntProp(i, Prop_Data, "m_takedamage", 2, 1);
		}
	}
	
	if (g_hGracePeriodTimer != INVALID_HANDLE)
	{
		KillTimer(g_hGracePeriodTimer);
	}
	
	g_bFriendlyFire.BoolValue = false;
}
