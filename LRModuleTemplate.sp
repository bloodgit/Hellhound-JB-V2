#include <sourcemod>
#include <morecolors>
#include <tf2jailredux>

#pragma semicolon 1
#pragma newdecls required
// #include "TF2JailRedux/stocks.inc"

#define PLUGIN_VERSION 		"1.0.0"

public Plugin myinfo =
{
	name = "TF2Jail LR Module Template",
	author = "",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

JBGameMode
	gamemode
;

LastRequest
	g_LR				// Me!
;

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

	g_LR = LastRequest.CreateFromConfig("LRModule Template");

	if (g_LR == null)		// If it's her first time, set the mood
	{
		g_LR = LastRequest.Create("LRModule Template");
		g_LR.SetDescription("----");
		g_LR.SetAnnounceMessage("{default}{NAME}{burlywood} has selected {default}---{burlywood} as their last request.");

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
}

public void fwdOnRoundEnd(LastRequest lr, Event event)
{
	CHECK();
}

public void LoadJBHooks()
{
	g_LR.AddHook(OnLRActivate, fwdOnRoundStart);
	g_LR.AddHook(OnLRActivatePlayer, fwdOnRoundStartPlayer);
	g_LR.AddHook(OnRoundEnd, fwdOnRoundEnd);
	//g_LR.AddHook(OnRoundEndPlayer, fwdOnRoundEndPlayer);
	//g_LR.AddHook(OnRedThink, fwdOnRedThink);
	//g_LR.AddHook(OnBlueThink, fwdOnBlueThink);
	//g_LR.AddHook(OnPlayerDied, fwdOnPlayerDied);
	//g_LR.AddHook(OnBuildingDestroyed, fwdOnBuildingDestroyed);
	//g_LR.AddHook(OnObjectDeflected, fwdOnObjectDeflected);
	//g_LR.AddHook(OnPlayerJarated, fwdOnPlayerJarated);
	//g_LR.AddHook(OnUberDeployed, fwdOnUberDeployed);
	//g_LR.AddHook(OnPlayerSpawned, fwdOnPlayerSpawned);
	//g_LR.AddHook(OnTakeDamage, fwdOnTakeDamage);
	//g_LR.AddHook(OnClientInduction, fwdOnClientInduction);
	//g_LR.AddHook(OnPlayMusic, fwdOnMusicPlay);
	//g_LR.AddHook(OnVariableReset, fwdOnVariableReset);
	//g_LR.AddHook(OnLastPrisoner, fwdOnLastPrisoner);
	//g_LR.AddHook(OnCheckLivingPlayers, fwdOnCheckLivingPlayers);
	//g_LR.AddHook(OnSoundHook, fwdOnSoundHook);
	//g_LR.AddHook(OnEntCreated, fwdOnEntCreated);
	//g_LR.AddHook(OnSetWardenLock, fwdOnSetWardenLock);

	//JB_Hook(OnDownloads, fwdOnDownloads);
}