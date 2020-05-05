#include <sourcemod>
#include <morecolors>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2jailredux>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required
#include "TF2JailRedux/stocks.inc"

#define PLUGIN_VERSION 		"1.0.0"

public Plugin myinfo =
{
	name = "TF2Jail LR Module ZVE",
	author = "blood",
	description = "Add Zombies Vs Engineers to Jailbreak!",
	version = PLUGIN_VERSION,
	url = ""
};

#define RED 				2
#define BLU 				3

Handle hSetWinningTeamPre = INVALID_HANDLE;
Handle hSetupTime = INVALID_HANDLE;

ConVar g_cSetupTime;
Handle g_hRoundTime;
bool g_bBuffed;
bool g_bIsLast3;
bool g_bIsLast1;

bool g_bHasRoundStarted = false;

//// DOUBLE JUMP ////

// Note : Anything labled Double Jump is from paegus's double jump plugin
Handle g_cvJumpBoost = INVALID_HANDLE;
Handle g_cvJumpEnable = INVALID_HANDLE;
Handle g_cvJumpMax = INVALID_HANDLE;
float g_flBoost = 250.0;
bool g_bDoubleJump = true;
int g_fLastButtons[MAXPLAYERS + 1];
int g_fLastFlags[MAXPLAYERS + 1];
int g_iJumps[MAXPLAYERS + 1];
int g_iJumpMax;

JBGameMode
	gamemode
;

LastRequest
	g_LR				// Me!
;

#define CHECK() 				if( g_LR == null || g_LR.GetID() != gamemode.iLRType ) return
#define NOTZVE					( g_LR == null || g_LR.GetID() != gamemode.iLRType ) // To use in IF statements

public void OnLibraryAdded(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false))
	{
		InitSubPlugin();
	}
}

methodmap JailZombie < JBPlayer
{  // Here we inherit all of the properties and functions that we made as natives
	public JailZombie(const int q)
	{
		return view_as<JailZombie>(q);
	}
	public static JailZombie OfUserId(const int id)
	{
		return view_as<JailZombie>(GetClientOfUserId(id));
	}
	public static JailZombie Of(const JBPlayer player)
	{
		return view_as<JailZombie>(player);
	}
	property bool bIsZombie
	{
		public get() { return this.GetProp("bIsZombie"); }
		public set(const bool i) { this.SetProp("bIsZombie", i); }
	}
	property bool bNeedsToGoBackToBlue
	{
		public get() { return this.GetProp("bNeedsToGoBackToBlue"); }
		public set(const bool i) { this.SetProp("bNeedsToGoBackToBlue", i); }
	}
	property bool bNeedsToGoBackToRed
	{
		public get() { return this.GetProp("bNeedsToGoBackToRed"); }
		public set(const bool i) { this.SetProp("bNeedsToGoBackToRed", i); }
	}
}

public void OnPluginStart()
{
	g_cSetupTime = CreateConVar("sm_jbzve_setuptime", "60", "How long before setup time ends?", FCVAR_NOTIFY, true, 0.0, true, 120.0);

	Handle hGameData = LoadGameConfigFile("tf2.setwinningteam");
	if (hGameData == INVALID_HANDLE)
		SetFailState("Gamedata not found for tf2.setwinningteam");

	int offset = GameConfGetOffset(hGameData, "SetWinningTeam");
	hSetWinningTeamPre = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, Hook_SetWinningTeamPre);
	DHookAddParam(hSetWinningTeamPre, HookParamType_Int);
	DHookAddParam(hSetWinningTeamPre, HookParamType_Int);
	DHookAddParam(hSetWinningTeamPre, HookParamType_Bool);
	DHookAddParam(hSetWinningTeamPre, HookParamType_Bool);
	DHookAddParam(hSetWinningTeamPre, HookParamType_Bool);
	DHookAddParam(hSetWinningTeamPre, HookParamType_Bool);

	//// COMMAND LISTENERS ////
	AddCommandListener(CL_Build, "build");
	AddCommandListener(CL_ChangeClass, "joinclass");
	AddCommandListener(CL_ChangeTeam, "jointeam");

	//// DOUBLE JUMP ////
	g_cvJumpEnable = CreateConVar("tf_zve_dj_enabled", "1", "Enable double jumping for blues?", FCVAR_NOTIFY);
	g_cvJumpBoost = CreateConVar("tf_zve_dj_boost", "250.0", "The amount of vertical boost to apply to double jumps.", FCVAR_NOTIFY);
	g_cvJumpMax = CreateConVar("tf_zve_dj_max", "1", "The maximum number of re-jumps allowed while already jumping.", FCVAR_NOTIFY);

	HookConVarChange(g_cvJumpBoost, convar_ChangeBoost);
	HookConVarChange(g_cvJumpEnable, convar_ChangeEnable);
	HookConVarChange(g_cvJumpMax, convar_ChangeMax);

	g_bDoubleJump = GetConVarBool(g_cvJumpEnable);
	g_flBoost = GetConVarFloat(g_cvJumpBoost);
	g_iJumpMax = GetConVarInt(g_cvJumpMax);

	LoadTranslations("tf2jail_redux.phrases");

	AutoExecConfig(true, "LRModuleZVE");
}

public void OnMapStart()
{
	DHookGamerules(hSetWinningTeamPre, false);
}

public MRESReturn Hook_SetWinningTeamPre(Handle hParams)
{
	if(NOTZVE)
		return MRES_Ignored;
	else if (!NOTZVE && GetTeamAliveCount(TFTeam_Red) >> 0)
		return MRES_Supercede;
}

public void InitSubPlugin()
{
	gamemode = new JBGameMode();

	g_LR = LastRequest.CreateFromConfig("Zombies Vs Engineers");

	if (g_LR == null)		// If it's her first time, set the mood
	{
		g_LR = LastRequest.Create("Zombies Vs Engineers");
		g_LR.SetDescription("Play a nice round as Zombies Vs Engineers!");
		g_LR.SetAnnounceMessage("{default}{NAME}{orange} has selected {default}Zombies Vs Engineers{orange} as their last request.");

		g_LR.SetParameterNum("Disabled", 0);
		g_LR.SetParameterNum("OpenCells", 1);
		g_LR.SetParameterNum("TimerStatus", 1);
		g_LR.SetParameterNum("TimerTime", 300);
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

	for (int i = MaxClients; i; --i)
	{
		JailZombie base = JailZombie(i);

		if (IsClientInGame(base.index) && IsPlayerAlive(base.index) && !base.bIsZombie)
		{
			if (TF2_GetClientTeam(base.index) == TFTeam_Blue)
				base.bNeedsToGoBackToBlue = true;
			else if (TF2_GetClientTeam(base.index) == TFTeam_Red)
				base.bNeedsToGoBackToRed = true;

			base.ForceTeamChange(RED);
			TF2_SetPlayerClass(base.index, TFClass_Engineer, false, false);
			TF2_RegeneratePlayer(base.index);
		}
	}

	SetupFirstZombies();

	CPrintToChatAll("%t %t", "Plugin Tag", "ZVE LR Zombie Frozen Time", g_cSetupTime.IntValue);
	hSetupTime = CreateTimer(g_cSetupTime.FloatValue, TIMER_StartRound);
	g_hRoundTime = CreateTimer(view_as<float>(g_LR.GetParameterNum("TimerTime")) / 2, Timer_BuffZombies);

	ServerCommand("tf_zve_dj_boost 250");

	g_bBuffed = false;
}

public Action TIMER_StartRound(Handle timer)
{
	for (int i = MaxClients; i; --i)
	{
		JailZombie base = JailZombie(i);

		if (IsClientInGame(base.index) && IsPlayerAlive(base.index) && base.bIsZombie)
		{
			SetEntProp(base.index, Prop_Data, "m_takedamage", 2, 1);
		}
	}

	g_bHasRoundStarted = true;
	PrintCenterTextAll("The zombies have been released!");
	//g_tHalfRoundTime = CreateTimer(g_hRoundTime.FloatValue/2.0, TIMER_HalfRoundTime);
	ServerCommand("tf_zve_dj_boost 250");
}

public Action Timer_BuffZombies(Handle timer)
{
	ServerCommand("tf_zve_dj_boost 400");
	PrintCenterTextAll("Zombies have been given a damage, speed and jump boost!.");
	g_bBuffed = true;

	JailZombie rand = JailZombie(GetRandomPlayer(BLU, true)); // It's probably best to keep the second param true

	if (rand.bIsZombie)
	{
		int maxhp1 = GetEntProp(rand.index, Prop_Data, "m_iMaxHealth");
		maxhp1 = 500;

		SetEntityHealth(rand.index, maxhp1);

		CPrintToChatAll("%t %t", "Plugin Tag", "ZVE LR Juggernaut", rand.index);
	}

	for (int i = MaxClients; i; --i)
	{
		JailZombie base = JailZombie(i);

		if (IsClientInGame(base.index) && IsPlayerAlive(base.index) && base.bIsZombie)
		{
			TF2_AddCondition(base.index, TFCond_SpeedBuffAlly);
			TF2_AddCondition(base.index, TFCond_CritCola);
		}
	}
}

public void fwdOnRoundEnd(LastRequest lr, Event event)
{
	CHECK();

	g_bHasRoundStarted = false;
	if(hSetupTime == INVALID_HANDLE)
		KillTimer(hSetupTime);

	if(g_hRoundTime == INVALID_HANDLE)
		KillTimer(g_hRoundTime);

	g_bBuffed = false;
}

public void fwdOnPlayerDied(LastRequest lr, const JBPlayer Victim, const JBPlayer Attacker, Event event)
{
	CHECK();

	JailZombie base = JailZombie(Victim);

	if(!Victim.bIsZombie && g_bHasRoundStarted)
		JailZombie(Victim).bIsZombie = true;

	if(JailZombie(Victim).bIsZombie)
	{
		TF2_RespawnPlayer(Victim.index);
		TF2_SetPlayerClass(Victim.index, TFClass_Medic, false, false);
		TF2_RegeneratePlayer(Victim.index);
		TF2_AddCondition(Victim.index, TFCond_RestrictToMelee, -1.0);
		CreateTimer(1.0, MeleeFix);

		TF2Attrib_SetByDefIndex(Victim.index, 26, 50.0);
		TF2Attrib_SetByDefIndex(Victim.index, 448, 1.0);
		TF2Attrib_SetByDefIndex(Victim.index, 450, 1.0);

		SetEntityHealth(Victim.index, 200);

		if (g_bBuffed)
		{
			TF2_AddCondition(Victim.index, TFCond_SpeedBuffAlly);
			TF2_AddCondition(Victim.index, TFCond_CritCola);
		}
	}

	if (GetTeamAliveCount(TFTeam_Red) == 3)
	{
		for (int i = MaxClients; i; --i)
		{
			JailZombie base = JailZombie(i);

			if (IsClientInGame(base.index) && IsPlayerAlive(base.index) && TF2_GetClientTeam(base.index) == TFTeam_Red && !base.bIsZombie)
			{
				g_bIsLast3 = true;

				TF2_AddCondition(base.index, TFCond_SpeedBuffAlly);
				TF2_AddCondition(base.index, TFCond_CritCola);

				TF2Attrib_SetByDefIndex(base.index, 26, 350.0);

				SetEntityHealth(base.index, 250);
			}
		}
	}
	else if (GetTeamAliveCount(TFTeam_Red) == 1)
	{
		for (int i = MaxClients; i; --i)
		{
			JailZombie base = JailZombie(i);

			if (IsClientInGame(base.index) && IsPlayerAlive(base.index) && TF2_GetClientTeam(base.index) == TFTeam_Red && !base.bIsZombie)
			{
				g_bIsLast1 = true;

				TF2_AddCondition(base.index, TFCond_SpeedBuffAlly);
				TF2_AddCondition(base.index, TFCond_Kritzkrieged);

				TF2Attrib_SetByDefIndex(base.index, 26, 250.0);

				SetEntityHealth(base.index, 350);
			}
		}
	}
	else if (GetTeamAliveCount(TFTeam_Red) == 0)
	{
		int iEnt = -1;
		iEnt = FindEntityByClassname(iEnt, "game_round_win");

		if (iEnt < 1)
		{
			iEnt = CreateEntityByName("game_round_win");
			if (IsValidEntity(iEnt))
				DispatchSpawn(iEnt);
		}

		int iWinningTeam = 3;
		SetVariantInt(iWinningTeam);
		AcceptEntityInput(iEnt, "SetTeam");
		AcceptEntityInput(iEnt, "RoundWin");
	}
}

public void OnClientPutInServer(int client)
{
	CHECK();

	if (g_bHasRoundStarted)
	{
		if (IsClientInGame(client))
		{
			JailZombie(client).ForceTeamChange(BLU);
			JailZombie(client).bIsZombie = true;
			TF2_RespawnPlayer(client);
			TF2_SetPlayerClass(client, TFClass_Medic, false, false);
			TF2_RegeneratePlayer(client);
			TF2_AddCondition(client, TFCond_RestrictToMelee, -1.0);
			CreateTimer(1.0, MeleeFix);

			TF2Attrib_SetByDefIndex(client, 26, 50.0);
			TF2Attrib_SetByDefIndex(client, 448, 1.0);
			TF2Attrib_SetByDefIndex(client, 450, 1.0);

			SetEntityHealth(client, 200);

			if (g_bBuffed)
			{
				TF2_AddCondition(client, TFCond_SpeedBuffAlly);
				TF2_AddCondition(client, TFCond_CritCola);
			}
		}
	}
	else
	{
		if (IsClientInGame(client))
		{
			JailZombie(client).ForceTeamChange(RED);
			JailZombie(client).bIsZombie = false;
			TF2_RespawnPlayer(client);
			TF2_SetPlayerClass(client, TFClass_Engineer, false, false);
			TF2_RegeneratePlayer(client);
		}
	}
}

public Action RespawnPlayer(Handle timer)
{
	for (int i = MaxClients; i; --i)
	{
		JailZombie base = JailZombie(i);

		if (IsClientInGame(base.index) && !IsPlayerAlive(base.index) && base.bIsZombie)
		{
			TF2_RespawnPlayer(base.index);
			TF2_SetPlayerClass(base.index, TFClass_Medic, false, false);
			TF2_RegeneratePlayer(base.index);
			TF2_AddCondition(base.index, TFCond_RestrictToMelee, -1.0);
			CreateTimer(1.0, MeleeFix);

			TF2Attrib_SetByDefIndex(base.index, 26, 50.0);
			TF2Attrib_SetByDefIndex(base.index, 448, 1.0);
			TF2Attrib_SetByDefIndex(base.index, 450, 1.0);

			SetEntityHealth(base.index, 200);

			if (g_bBuffed)
			{
				TF2_AddCondition(base.index, TFCond_SpeedBuffAlly);
				TF2_AddCondition(base.index, TFCond_CritCola);
			}
		}
		else if (IsClientInGame(base.index) && !IsPlayerAlive(base.index) && !base.bIsZombie)
		{
			TF2_RespawnPlayer(base.index);
			TF2_SetPlayerClass(base.index, TFClass_Engineer, false, false);
			TF2_RegeneratePlayer(base.index);
		}
	}
}

public Action MeleeFix(Handle timer)
{
	for (int i = MaxClients; i; --i)
	{
		JailZombie base = JailZombie(i);

		if (IsClientInGame(base.index) && IsPlayerAlive(base.index) && base.bIsZombie)
		{
			int weapon = GetPlayerWeaponSlot(base.index, TFWeaponSlot_Melee);
			SetEntPropEnt(base.index, Prop_Send, "m_hActiveWeapon", weapon);
			FakeClientCommand(base.index, "slot3");
		}
	}
}

public void fwdOnPlayerSpawned(LastRequest lr, const JBPlayer Player, Event event)
{
	CHECK();

	JailZombie spawn = JailZombie.Of(Player);

	if(IsClientInGame(spawn.index))
	{
		if(TF2_GetClientTeam(spawn.index) == TFTeam_Blue && spawn.bIsZombie)
		{
			TF2_SetPlayerClass(spawn.index, TFClass_Medic);
		}
	}
}

public void fwdOnVariableReset(LastRequest lr, const JBPlayer Player)
{
	JailZombie base = JailZombie.Of(Player);

	base.bIsZombie = false;

	g_bIsLast1 = false;
	g_bIsLast3 = false;

	for (int i = MaxClients; i; --i)
	{
		if (IsClientInGame(i))
		{
			TF2Attrib_RemoveAll(i);
		}
	}

	if (base.bNeedsToGoBackToBlue && GetClientTeam(base.index) != BLU)
		ChangeClientTeam(base.index, BLU);
	base.bNeedsToGoBackToBlue = false;

	if (base.bNeedsToGoBackToRed && GetClientTeam(base.index) != RED)
		ChangeClientTeam(base.index, RED);

	base.bNeedsToGoBackToRed = false;
}

public void LoadJBHooks()
{
	g_LR.AddHook(OnLRActivate, fwdOnRoundStart);
	g_LR.AddHook(OnLRActivatePlayer, fwdOnRoundStartPlayer);
	g_LR.AddHook(OnRoundEnd, fwdOnRoundEnd);
	//g_LR.AddHook(OnRoundEndPlayer, fwdOnRoundEndPlayer);
	//g_LR.AddHook(OnRedThink, fwdOnRedThink);
	//g_LR.AddHook(OnBlueThink, fwdOnBlueThink);
	g_LR.AddHook(OnPlayerDied, fwdOnPlayerDied);
	g_LR.AddHook(OnPlayerSpawned, fwdOnPlayerSpawned);
	//g_LR.AddHook(OnBuildingDestroyed, fwdOnBuildingDestroyed);
	//g_LR.AddHook(OnObjectDeflected, fwdOnObjectDeflected);
	//g_LR.AddHook(OnPlayerJarated, fwdOnPlayerJarated);
	//g_LR.AddHook(OnUberDeployed, fwdOnUberDeployed);
	//g_LR.AddHook(OnPlayerSpawned, fwdOnPlayerSpawned);
	//g_LR.AddHook(OnTakeDamage, fwdOnTakeDamage);
	//g_LR.AddHook(OnClientInduction, fwdOnClientInduction);
	//g_LR.AddHook(OnPlayMusic, fwdOnMusicPlay);
	g_LR.AddHook(OnVariableReset, fwdOnVariableReset);
	//g_LR.AddHook(OnLastPrisoner, fwdOnLastPrisoner);
	//g_LR.AddHook(OnCheckLivingPlayers, fwdOnCheckLivingPlayers);
	//g_LR.AddHook(OnSoundHook, fwdOnSoundHook);
	//g_LR.AddHook(OnEntCreated, fwdOnEntCreated);
	//g_LR.AddHook(OnSetWardenLock, fwdOnSetWardenLock);

	//JB_Hook(OnDownloads, fwdOnDownloads);
}

///////////////////////////////////////////////// COMMAND LISTENERS /////////////////////////////////////////////////

/*
 * This code is from Tsunami's TF2 build restrictions. It prevents engineers
 * from even placing a sentry.
 * Credit : shewokees
 */

public Action CL_Build(int client, const char[] command, int argc)
{
	if (!NOTZVE)
	{
		//initializing the array that will contain all user collision information
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);

		//Feeding an array because i can only give one custom variable to the timer
		CreateTimer(3.0, Recollide, client);

		if (IsClientInGame(client) && argc)
		{
			char arg1[11];
			GetCmdArg(1, arg1, sizeof(arg1));
			int building = StringToInt(arg1);
			TFTeam team = TF2_GetClientTeam(client);
			if (team == TFTeam_Red && building == view_as<int>(TFObject_Sentry))
				return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action CL_ChangeTeam(int client, const char[] command, int argc)
{
	if (NOTZVE)
		return Plugin_Continue;

	if (TF2_GetClientTeam(client) == TFTeam_Unassigned || TF2_GetClientTeam(client) == TFTeam_Spectator)
	{
		return Plugin_Continue;
	}

	return Plugin_Handled;
}

public Action CL_ChangeClass(int client, const char[] command, int argc)
{
	if (NOTZVE)
		return Plugin_Continue;

	char arg1[256];
	GetCmdArg(1, arg1, sizeof(arg1));

	if (strcmp(arg1, "medic", false) == 0 && TF2_GetClientTeam(client) == TFTeam_Blue)
	{
		return Plugin_Continue;
	}
	else if (TF2_GetClientTeam(client) == TFTeam_Blue)
	{
		ClientCommand(client, "joinclass medic");
	}

	if (strcmp(arg1, "engineer", false) == 0 && TF2_GetClientTeam(client) == TFTeam_Red)
	{
		return Plugin_Continue;
	}
	else if (TF2_GetClientTeam(client) == TFTeam_Red)
	{
		ClientCommand(client, "joinclass engineer");
	}

	return Plugin_Handled;
}

public Action Recollide(Handle timer, any client)
{
	if (IsClientInGame(client))
	{
		if (TF2_GetClientTeam(client) == TFTeam_Red)
		{
			SetEntProp(client, Prop_Data, "m_CollisionGroup", 3);
		}
		else if (TF2_GetClientTeam(client) == TFTeam_Blue)
		{
			SetEntProp(client, Prop_Data, "m_CollisionGroup", 5);
		}
	}
}

public void convar_ChangeBoost(Handle convar, const char[] oldVal, const char[] newVal)
{
	g_flBoost = StringToFloat(newVal);
}

public void convar_ChangeEnable(Handle convar, const char[] oldVal, const char[] newVal)
{
	if (StringToInt(newVal) >= 1)
	{
		g_bDoubleJump = true;
	}
	else
	{
		g_bDoubleJump = false;
	}
}

public void convar_ChangeMax(Handle convar, const char[] oldVal, const char[] newVal)
{
	g_iJumpMax = StringToInt(newVal);
}

public void OnGameFrame()
{
	if (NOTZVE)
		return;

	if (g_bDoubleJump) // double jump active
	{
		for (int i = 1; i <= MaxClients; i++) // cycle through players
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
			{
				FUNCTION_DoubleJump(i); // Check for double jumping
			}
		}
	}
}

int FUNCTION_DoubleJump(const any client)
{
	int fCurFlags = GetEntityFlags(client); // current flags
	int fCurButtons = GetClientButtons(client); // current buttons

	if (g_fLastFlags[client] & FL_ONGROUND) // was grounded last frame
	{
		if (!(fCurFlags & FL_ONGROUND) && !(g_fLastButtons[client] & IN_JUMP) && fCurButtons & IN_JUMP)
		{
			FUNCTION_OriginalJump(client); // process jump from the ground
		}
	}
	else if (fCurFlags & FL_ONGROUND)
	{
		FUNCTION_Landed(client); // process landing on the ground
	}
	else if (!(g_fLastButtons[client] & IN_JUMP) && fCurButtons & IN_JUMP)
	{
		FUNCTION_ReJump(client); // process attempt to double-jump
	}

	g_fLastFlags[client] = fCurFlags; // update flag state for next frame
	g_fLastButtons[client] = fCurButtons; // update button state for next frame
}

int FUNCTION_OriginalJump(const any client)
{
	g_iJumps[client]++; // increment jump count
}

int FUNCTION_Landed(const any client)
{
	g_iJumps[client] = 0; // reset jumps count
}

int FUNCTION_ReJump(const any client)
{
	if (1 <= g_iJumps[client] <= g_iJumpMax)
	{
		g_iJumps[client]++;
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		vVel[2] = g_flBoost;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
}

void SetupFirstZombies()
{
	switch (GetTeamAliveCount(TFTeam_Red))
	{
		case 2:
		OneZombie();
		case 3:
		OneZombie();
		case 4:
		OneZombie();
		case 5:
		TwoZombie();
		case 6:
		TwoZombie();
		case 7:
		TwoZombie();
		case 8:
		TwoZombie();
		case 9:
		TwoZombie();
		case 10:
		TwoZombie();
		case 11:
		ThreeZombie();
		case 12:
		ThreeZombie();
		case 13:
		ThreeZombie();
		case 14:
		ThreeZombie();
		case 15:
		ThreeZombie();
		case 16:
		ThreeZombie();
		case 17:
		FourZombie();
		case 18:
		FourZombie();
		case 19:
		FourZombie();
		case 20:
		FourZombie();
		case 21:
		FourZombie();
		case 22:
		FourZombie();
		case 23:
		FourZombie();
		case 24:
		FourZombie();
	}
}

void OneZombie()
{
	JailZombie rand = JailZombie(GetRandomPlayer(RED, true)); // It's probably best to keep the second param true

	if (rand.index <= 0)
		ForceTeamWin(RED);

	if (GetClientTeam(rand.index) == RED)
		rand.ForceTeamChange(BLU);

	if (!IsPlayerAlive(rand.index))
		TF2_RespawnPlayer(rand.index);

	int weapon = GetPlayerWeaponSlot(rand.index, TFWeaponSlot_Melee);

	TF2Attrib_RemoveAll(rand.index);
	TF2_SetPlayerClass(rand.index, TFClass_Medic, false, true);
	TF2_AddCondition(rand.index, TFCond_RestrictToMelee, -1.0);
	TF2_RegeneratePlayer(rand.index);
	SetEntPropEnt(rand.index, Prop_Send, "m_hActiveWeapon", weapon);
	SetEntProp(rand.index, Prop_Data, "m_takedamage", 0, 1);
	FakeClientCommand(rand.index, "slot3");

	TF2Attrib_SetByDefIndex(rand.index, 448, 1.0);
	TF2Attrib_SetByDefIndex(rand.index, 450, 1.0);

	TF2_StunPlayer(rand.index, g_cSetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
	rand.bIsZombie = true;
	CreateTimer(1.0, MeleeFix);

	TF2Attrib_SetByDefIndex(rand.index, 26, 50.0);

	SetEntityHealth(rand.index, 200);
}

void TwoZombie()
{
	JailZombie rand = JailZombie(GetRandomPlayer(RED, true)); // It's probably best to keep the second param true

	// First Zombie

	if (rand.index <= 0)
		ForceTeamWin(RED);

	if (GetClientTeam(rand.index) == RED)
		rand.ForceTeamChange(BLU);

	if (!IsPlayerAlive(rand.index))
		TF2_RespawnPlayer(rand.index);

	int weapon = GetPlayerWeaponSlot(rand.index, TFWeaponSlot_Melee);

	TF2Attrib_RemoveAll(rand.index);
	TF2_SetPlayerClass(rand.index, TFClass_Medic, false, true);
	TF2_AddCondition(rand.index, TFCond_RestrictToMelee, -1.0);
	TF2_RegeneratePlayer(rand.index);
	SetEntPropEnt(rand.index, Prop_Send, "m_hActiveWeapon", weapon);
	SetEntProp(rand.index, Prop_Data, "m_takedamage", 0, 1);
	FakeClientCommand(rand.index, "slot3");

	TF2Attrib_SetByDefIndex(rand.index, 448, 1.0);
	TF2Attrib_SetByDefIndex(rand.index, 450, 1.0);

	TF2_StunPlayer(rand.index, g_cSetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
	rand.bIsZombie = true;
	CreateTimer(1.0, MeleeFix);

	TF2Attrib_SetByDefIndex(rand.index, 26, 50.0);

	SetEntityHealth(rand.index, 200);

	// Second Zombie

	JailZombie rand2 = JailZombie(GetRandomPlayer(RED, true)); // It's probably best to keep the second param true

	if (rand2.index <= 0)
		ForceTeamWin(RED);

	if (GetClientTeam(rand2.index) == RED)
		rand2.ForceTeamChange(BLU);

	if (!IsPlayerAlive(rand2.index))
		TF2_RespawnPlayer(rand2.index);

	int weapon2 = GetPlayerWeaponSlot(rand2.index, TFWeaponSlot_Melee);

	TF2Attrib_RemoveAll(rand2.index);
	TF2_SetPlayerClass(rand2.index, TFClass_Medic, false, true);
	TF2_AddCondition(rand2.index, TFCond_RestrictToMelee, -1.0);
	TF2_RegeneratePlayer(rand2.index);
	SetEntPropEnt(rand2.index, Prop_Send, "m_hActiveWeapon", weapon2);
	SetEntProp(rand2.index, Prop_Data, "m_takedamage", 0, 1);
	FakeClientCommand(rand2.index, "slot3");

	TF2Attrib_SetByDefIndex(rand2.index, 448, 1.0);
	TF2Attrib_SetByDefIndex(rand2.index, 450, 1.0);

	TF2_StunPlayer(rand2.index, g_cSetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
	rand2.bIsZombie = true;
	CreateTimer(1.0, MeleeFix);

	TF2Attrib_SetByDefIndex(rand2.index, 26, 50.0);

	SetEntityHealth(rand2.index, 200);
}

void ThreeZombie()
{
	JailZombie rand = JailZombie(GetRandomPlayer(RED, true)); // It's probably best to keep the second param true

	// First Zombie

	if (rand.index <= 0)
		ForceTeamWin(RED);

	if (GetClientTeam(rand.index) == RED)
		rand.ForceTeamChange(BLU);

	if (!IsPlayerAlive(rand.index))
		TF2_RespawnPlayer(rand.index);

	int weapon = GetPlayerWeaponSlot(rand.index, TFWeaponSlot_Melee);

	TF2Attrib_RemoveAll(rand.index);
	TF2_SetPlayerClass(rand.index, TFClass_Medic, false, true);
	TF2_AddCondition(rand.index, TFCond_RestrictToMelee, -1.0);
	TF2_RegeneratePlayer(rand.index);
	SetEntPropEnt(rand.index, Prop_Send, "m_hActiveWeapon", weapon);
	SetEntProp(rand.index, Prop_Data, "m_takedamage", 0, 1);
	FakeClientCommand(rand.index, "slot3");

	TF2Attrib_SetByDefIndex(rand.index, 448, 1.0);
	TF2Attrib_SetByDefIndex(rand.index, 450, 1.0);

	TF2_StunPlayer(rand.index, g_cSetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
	rand.bIsZombie = true;
	CreateTimer(1.0, MeleeFix);

	TF2Attrib_SetByDefIndex(rand.index, 26, 50.0);

	SetEntityHealth(rand.index, 200);

	// Second Zombie

	JailZombie rand2 = JailZombie(GetRandomPlayer(RED, true)); // It's probably best to keep the second param true

	if (rand2.index <= 0)
		ForceTeamWin(RED);

	if (GetClientTeam(rand2.index) == RED)
		rand2.ForceTeamChange(BLU);

	if (!IsPlayerAlive(rand2.index))
		TF2_RespawnPlayer(rand2.index);

	int weapon2 = GetPlayerWeaponSlot(rand2.index, TFWeaponSlot_Melee);

	TF2Attrib_RemoveAll(rand2.index);
	TF2_SetPlayerClass(rand2.index, TFClass_Medic, false, true);
	TF2_AddCondition(rand2.index, TFCond_RestrictToMelee, -1.0);
	TF2_RegeneratePlayer(rand2.index);
	SetEntPropEnt(rand2.index, Prop_Send, "m_hActiveWeapon", weapon2);
	SetEntProp(rand2.index, Prop_Data, "m_takedamage", 0, 1);
	FakeClientCommand(rand2.index, "slot3");

	TF2Attrib_SetByDefIndex(rand2.index, 448, 1.0);
	TF2Attrib_SetByDefIndex(rand2.index, 450, 1.0);

	TF2_StunPlayer(rand2.index, g_cSetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
	rand2.bIsZombie = true;
	CreateTimer(1.0, MeleeFix);

	TF2Attrib_SetByDefIndex(rand2.index, 26, 50.0);

	SetEntityHealth(rand2.index, 200);

	// Third Zombie

	JailZombie rand3 = JailZombie(GetRandomPlayer(RED, true)); // It's probably best to keep the second param true

	if (rand3.index <= 0)
		ForceTeamWin(RED);

	if (GetClientTeam(rand3.index) == RED)
		rand3.ForceTeamChange(BLU);

	if (!IsPlayerAlive(rand3.index))
		TF2_RespawnPlayer(rand3.index);

	int weapon3 = GetPlayerWeaponSlot(rand3.index, TFWeaponSlot_Melee);

	TF2Attrib_RemoveAll(rand3.index);
	TF2_SetPlayerClass(rand3.index, TFClass_Medic, false, true);
	TF2_AddCondition(rand3.index, TFCond_RestrictToMelee, -1.0);
	TF2_RegeneratePlayer(rand3.index);
	SetEntPropEnt(rand3.index, Prop_Send, "m_hActiveWeapon", weapon3);
	SetEntProp(rand3.index, Prop_Data, "m_takedamage", 0, 1);
	FakeClientCommand(rand3.index, "slot3");

	TF2Attrib_SetByDefIndex(rand3.index, 448, 1.0);
	TF2Attrib_SetByDefIndex(rand3.index, 450, 1.0);

	TF2_StunPlayer(rand3.index, g_cSetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
	rand3.bIsZombie = true;
	CreateTimer(1.0, MeleeFix);

	TF2Attrib_SetByDefIndex(rand3.index, 26, 50.0);

	SetEntityHealth(rand3.index, 200);
}

void FourZombie()
{
	JailZombie rand = JailZombie(GetRandomPlayer(RED, true)); // It's probably best to keep the second param true

	// First Zombie

	if (rand.index <= 0)
		ForceTeamWin(RED);

	if (GetClientTeam(rand.index) == RED)
		rand.ForceTeamChange(BLU);

	if (!IsPlayerAlive(rand.index))
		TF2_RespawnPlayer(rand.index);

	int weapon = GetPlayerWeaponSlot(rand.index, TFWeaponSlot_Melee);

	TF2Attrib_RemoveAll(rand.index);
	TF2_SetPlayerClass(rand.index, TFClass_Medic, false, true);
	TF2_AddCondition(rand.index, TFCond_RestrictToMelee, -1.0);
	TF2_RegeneratePlayer(rand.index);
	SetEntPropEnt(rand.index, Prop_Send, "m_hActiveWeapon", weapon);
	SetEntProp(rand.index, Prop_Data, "m_takedamage", 0, 1);
	FakeClientCommand(rand.index, "slot3");

	TF2Attrib_SetByDefIndex(rand.index, 448, 1.0);
	TF2Attrib_SetByDefIndex(rand.index, 450, 1.0);

	TF2_StunPlayer(rand.index, g_cSetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
	rand.bIsZombie = true;
	CreateTimer(1.0, MeleeFix);

	TF2Attrib_SetByDefIndex(rand.index, 26, 50.0);

	SetEntityHealth(rand.index, 200);

	// Second Zombie

	JailZombie rand2 = JailZombie(GetRandomPlayer(RED, true)); // It's probably best to keep the second param true

	if (rand2.index <= 0)
		ForceTeamWin(RED);

	if (GetClientTeam(rand2.index) == RED)
		rand2.ForceTeamChange(BLU);

	if (!IsPlayerAlive(rand2.index))
		TF2_RespawnPlayer(rand2.index);

	int weapon2 = GetPlayerWeaponSlot(rand2.index, TFWeaponSlot_Melee);

	TF2Attrib_RemoveAll(rand2.index);
	TF2_SetPlayerClass(rand2.index, TFClass_Medic, false, true);
	TF2_AddCondition(rand2.index, TFCond_RestrictToMelee, -1.0);
	TF2_RegeneratePlayer(rand2.index);
	SetEntPropEnt(rand2.index, Prop_Send, "m_hActiveWeapon", weapon2);
	SetEntProp(rand2.index, Prop_Data, "m_takedamage", 0, 1);
	FakeClientCommand(rand2.index, "slot3");

	TF2Attrib_SetByDefIndex(rand2.index, 448, 1.0);
	TF2Attrib_SetByDefIndex(rand2.index, 450, 1.0);

	TF2_StunPlayer(rand2.index, g_cSetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
	rand2.bIsZombie = true;
	CreateTimer(1.0, MeleeFix);

	TF2Attrib_SetByDefIndex(rand2.index, 26, 50.0);

	SetEntityHealth(rand2.index, 200);

	// Third Zombie

	JailZombie rand3 = JailZombie(GetRandomPlayer(RED, true)); // It's probably best to keep the second param true

	if (rand3.index <= 0)
		ForceTeamWin(RED);

	if (GetClientTeam(rand3.index) == RED)
		rand3.ForceTeamChange(BLU);

	if (!IsPlayerAlive(rand3.index))
		TF2_RespawnPlayer(rand3.index);

	int weapon3 = GetPlayerWeaponSlot(rand3.index, TFWeaponSlot_Melee);

	TF2Attrib_RemoveAll(rand3.index);
	TF2_SetPlayerClass(rand3.index, TFClass_Medic, false, true);
	TF2_AddCondition(rand3.index, TFCond_RestrictToMelee, -1.0);
	TF2_RegeneratePlayer(rand3.index);
	SetEntPropEnt(rand3.index, Prop_Send, "m_hActiveWeapon", weapon3);
	SetEntProp(rand3.index, Prop_Data, "m_takedamage", 0, 1);
	FakeClientCommand(rand3.index, "slot3");

	TF2Attrib_SetByDefIndex(rand3.index, 448, 1.0);
	TF2Attrib_SetByDefIndex(rand3.index, 450, 1.0);

	TF2_StunPlayer(rand3.index, g_cSetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
	rand3.bIsZombie = true;
	CreateTimer(1.0, MeleeFix);

	TF2Attrib_SetByDefIndex(rand3.index, 26, 50.0);

	SetEntityHealth(rand3.index, 200);

	// Fourth Zombie

	JailZombie rand4 = JailZombie(GetRandomPlayer(RED, true)); // It's probably best to keep the second param true

	if (rand4.index <= 0)
		ForceTeamWin(RED);

	if (GetClientTeam(rand4.index) == RED)
		rand4.ForceTeamChange(BLU);

	if (!IsPlayerAlive(rand4.index))
		TF2_RespawnPlayer(rand4.index);

	int weapon4 = GetPlayerWeaponSlot(rand4.index, TFWeaponSlot_Melee);

	TF2Attrib_RemoveAll(rand4.index);
	TF2_SetPlayerClass(rand4.index, TFClass_Medic, false, true);
	TF2_AddCondition(rand4.index, TFCond_RestrictToMelee, -1.0);
	TF2_RegeneratePlayer(rand4.index);
	SetEntPropEnt(rand4.index, Prop_Send, "m_hActiveWeapon", weapon4);
	SetEntProp(rand4.index, Prop_Data, "m_takedamage", 0, 1);
	FakeClientCommand(rand4.index, "slot3");

	TF2Attrib_SetByDefIndex(rand4.index, 448, 1.0);
	TF2Attrib_SetByDefIndex(rand4.index, 450, 1.0);

	TF2_StunPlayer(rand4.index, g_cSetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
	rand4.bIsZombie = true;
	CreateTimer(1.0, MeleeFix);

	TF2Attrib_SetByDefIndex(rand4.index, 26, 50.0);

	SetEntityHealth(rand4.index, 200);
}

int GetTeamAliveCount(TFTeam iTeamNum)
{
	int iCount;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	if (IsClientInGame(iClient) && TF2_GetClientTeam(iClient) == iTeamNum && IsPlayerAlive(iClient))
		iCount++;
	return iCount;
}
