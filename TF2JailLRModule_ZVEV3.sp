#include <sourcemod>
#include <morecolors>
#include <tf2jailredux>
#include <tf2attributes>
#include <morecolors>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required
#include "TF2JailRedux/stocks.inc"

#define RED 2
#define BLU 3

#define PLUGIN_VERSION 		"1.0.0"

public Plugin myinfo =
{
	name = "TF2Jail LR Module ZVE",
	author = "blood",
	description = "Add Zombies Vs Engineers to Jailbreak!",
	version = PLUGIN_VERSION,
	url = ""
};

JBGameMode
	gamemode
;

LastRequest
	g_LR				// Me!
;

// LR Specific

Handle hSetWinningTeamPre = INVALID_HANDLE;
Handle g_hMeleeFix[MAXPLAYERS+1];
float g_fZombieHealth;
float g_fHumanHealth;
bool g_bHasRoundStarted;
bool g_bZombieBuff;
bool g_bSetupRound;

ConVar g_cSetupTime;
ConVar g_cHumanHPBase;
ConVar g_cHumanHPIncrease;
ConVar g_cZombieHPBase;
ConVar g_cZombieHPIncrease;


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


#define CHECK() 				if( g_LR == null || g_LR.GetID() != gamemode.iLRType ) return

public void OnPluginStart()
{
	g_cSetupTime = CreateConVar("sm_jbzve_setuptime", "60", "How long before setup time ends?", FCVAR_NOTIFY, true, 0.0, true, 120.0);
	g_cHumanHPBase = CreateConVar("sm_jbzve_humanhp_base", "150", "Human HP Base", FCVAR_NOTIFY, true, 0.0, true, 120.0);
	g_cHumanHPIncrease = CreateConVar("sm_jbzve_humanhp_increase", "20", "Amount of health humans get per player", FCVAR_NOTIFY, true, 0.0, true, 120.0);
	g_cZombieHPBase = CreateConVar("sm_jbzve_zombiehp_base", "200", "Zombie HP Base", FCVAR_NOTIFY, true, 0.0, true, 120.0);
	g_cZombieHPIncrease = CreateConVar("sm_jbzve_zombiehp_increase", "40", "Amount of health zombies get per player.", FCVAR_NOTIFY, true, 0.0, true, 120.0);

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

	AutoExecConfig(true, "LRModuleZVE");
}

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

	g_LR = LastRequest.CreateFromConfig("Zombies Vs Engineers");

	if (g_LR == null)		// If it's her first time, set the mood
	{
		g_LR = LastRequest.Create("Zombies Vs Engineers");
		g_LR.SetDescription("Play a scary round of zombies vs engineers!");
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

	property int iHealth
	{
		public get() { return this.GetProp("iHealth"); }
		public set(const int i) { this.SetProp("iHealth", i); }
	}
	property int iMaxHealth
	{
		public get() { return this.GetProp("iMaxHealth"); }
		public set(const int i) { this.SetProp("iMaxHealth", i); }
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
};

public void OnMapStart()
{
	DHookGamerules(hSetWinningTeamPre, false);
}

public MRESReturn Hook_SetWinningTeamPre(Handle hParams)
{
	if(g_LR.GetID() == gamemode.iLRType)
	{
		if(GetTeamAliveCount(TFTeam_Red) == 0)
			return MRES_Ignored;
		else if(GetTeamAliveCount(TFTeam_Red >= 1))
			return MRES_Supercede;
	}

	return MRES_Ignored;
}

public void OnLibraryRemoved(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false))
	{}
}


public void fwdOnRoundStartPlayer(LastRequest lr, const JBPlayer Player)
{
	CHECK();

	if(IsClientInGame(Player.index))
		RequestFrame(MakeHuman, GetClientOfUserId(Player.index);
}

public void fwdOnRoundStart(LastRequest lr)
{
	CHECK();

	CreateTimer(1.0, SetupRound);
}

public Action SetupRound(Handle timer)
{
	JailZombie zombie1 = JailZombie(GetRandomPlayer(RED));
	JailZombie zombie2 = JailZombie(GetRandomPlayer(RED));
	JailZombie zombie3 = JailZombie(GetRandomPlayer(RED));
	JailZombie zombie4 = JailZombie(GetRandomPlayer(RED));

}

public void fwdOnPlayerDied(LastRequest lr, const JBPlayer Victim, const JBPlayer Attacker, Event event)
{
	CHECK();

}

void MakeZombie(int userid)
{
	int client = GetClientOfUserId(userid);

	if(IsClientInGame(client))
	{
		JailZombie(client).bIsZombie = true;
		TF2_ChangeClientTeam(client, TFTeam_Blue);
		TF2_SetPlayerClass(client, TFClass_Medic);
		TF2_RegeneratePlayer(client);
		g_hMeleeFix[client] = CreateTimer(1.0, MeleeFix, client);

		if(g_bZombieBuff)
		{
			TF2_AddCondition(client, TFCond_Buffed, -1.0);
			TF2_AddCondition(client, TFCond_SpeedBuffAlly, -1.0);
		}
	}
}

void MakeHuman(int userid)
{
	int client = GetClientOfUserId(userid);

	if(IsClientInGame(client))
	{
		TF2_ChangeClientTeam(client, TFTeam_Red);
		TF2_SetPlayerClass(client, TFClass_Engineer);
		TF2_RegeneratePlayer(client);
	}
}

public Action MeleeFix(Handle timer, int client)
{
	if(IsClientInGame(client) && IsPlayerAlive(client) && JailZombie(client).bIsZombie) // Double check
	{
		TF2_AddCondition(client, TFCond_RestrictToMelee, -1.0);
		int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		FakeClientCommand(client, "slot3");
	}
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
	g_LR.AddHook(OnPlayerDied, fwdOnPlayerDied);
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

int GetTeamAliveCount(TFTeam iTeamNum)
{
	int iCount;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	if (IsClientInGame(iClient) && TF2_GetClientTeam(iClient) == iTeamNum && IsPlayerAlive(iClient))
		iCount++;
	return iCount;
}

public void OnGameFrame()
{
	CHECK();

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

// DOUBLE JUMP

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

///////////////////////////////////////////////// COMMAND LISTENERS /////////////////////////////////////////////////

/*
 * This code is from Tsunami's TF2 build restrictions. It prevents engineers
 * from even placing a sentry.
 * Credit : shewokees
 */

public Action CL_Build(int client, const char[] command, int argc)
{
	if (g_LR.GetID() == gamemode.iLRType)
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
	CHECK() Plugin_Continue;

	if (TF2_GetClientTeam(client) == TFTeam_Unassigned || TF2_GetClientTeam(client) == TFTeam_Spectator)
	{
		return Plugin_Continue;
	}

	return Plugin_Handled;
}

public Action CL_ChangeClass(int client, const char[] command, int argc)
{
	CHECK() Plugin_Continue;

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

int Client_Total()
{
	int numClients = 0;

	for (int client = 1; client <= MaxClients; client++) {

		if (!IsClientConnected(client) || !IsClientInGame(client) || IsClientReplay(client) || IsClientSourceTV(client) || GetClientTeam(client) <= 1)
		{
			continue;
		}

		numClients++;
	}

	return numClients;
}
