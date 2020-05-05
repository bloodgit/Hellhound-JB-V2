#include <sourcemod>
#include <morecolors>
#include <tf2jailredux>
#include <tf2items_giveweapon>

#pragma semicolon 1
#pragma newdecls required
// #include "TF2JailRedux/stocks.inc"

#define PLUGIN_VERSION 		"2.0.0"

public Plugin myinfo =
{
	name = "TF2Jail LR Module RRD",
	author = "blood",
	description = "Adds rapid rockets day to jailbreak as an LR.",
	version = PLUGIN_VERSION,
	url = ""
};

JBGameMode
	gamemode
;

LastRequest
	g_LR				// Me!
;

Handle g_hGracePeriodTimer;

// LR Specific

#define CHECK() 				if( g_LR == null || g_LR.GetID() != gamemode.iLRType ) return

public void OnLibraryAdded(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false))
	{
		InitSubPlugin();
	}
}

public void InitSubPlugin()
{
	gamemode = new JBGameMode();

	g_LR = LastRequest.CreateFromConfig("Rapid Rockets Day");

	if (g_LR == null)		// If it's her first time, set the mood
	{
		g_LR = LastRequest.Create("Rapid Rockets Day");
		g_LR.SetDescription("Enjoy a nice round of hectic rapid rockets!");
		g_LR.SetAnnounceMessage("{default}{NAME}{orange} has selected {default}Rapid Rockets Day{orange} as their last request.");

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

		g_LR.ExportToConfig(.create = true, .createonly = true);
	}

	LoadJBHooks();
}

public void OnLibraryRemoved(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false))
	{}
}


public void fwdOnRoundStartPlayer(LastRequest lr, const JBPlayer Player)
{
	CHECK();
	
	
}

public void fwdOnRoundStart(LastRequest lr)
{
	CHECK();
	
	g_LR.SetParameterNum("FriendlyFire", 0);
	
	PrintCenterTextAll("A grace period has been activated for 30 seconds!");
	
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

public void fwdOnRoundEnd(LastRequest lr, Event event)
{
	CHECK();
	
	g_LR.SetParameterNum("FriendlyFire", 0);
	
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
	g_LR.SetParameterNum("FriendlyFire", 1);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			SetEntProp(i, Prop_Data, "m_takedamage", 2, 1);
		}
	}
}

public void LoadJBHooks()
{
	g_LR.AddHook(OnLRActivate, fwdOnRoundStart);
	g_LR.AddHook(OnLRActivatePlayer, fwdOnRoundStartPlayer);
	g_LR.AddHook(OnRoundEnd, fwdOnRoundEnd);
}