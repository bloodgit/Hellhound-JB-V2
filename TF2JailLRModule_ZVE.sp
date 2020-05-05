#include <sourcemod>
#include <sdkhooks>
#include <morecolors>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2jailredux>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required
#include "TF2JailRedux/stocks.inc"

#define PLUGIN_VERSION		"1.0.0"

#define RED 				2
#define BLU 				3

#define NOTZVE 				( gamemode.iLRType != TF2JailRedux_LRIndex() )

Handle hSetWinningTeamPre = INVALID_HANDLE;
Handle hSetupTime = INVALID_HANDLE;

enum/*CvarName*/
{
	Timeleft,
	Version
};

ConVar
JBZVE[Version + 1]
;

JBGameMode
gamemode
;

ConVar SetupTime;
ConVar PickCount;
Handle hRoundTime;
bool Buffed;

bool
bDisabled // Handling core late-loading
;

bool g_bHasRoundStarted = false;
//Handle g_tHalfRoundTime;

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

methodmap JailSurvivor < JBPlayer
{
	public JailSurvivor(const int w)
	{
		return view_as<JailSurvivor>(w);
	}
	public static JailSurvivor OfUserId(const int id)
	{
		return view_as<JailSurvivor>(GetClientOfUserId(id));
	}
	public static JailSurvivor Of(const JBPlayer player)
	{
		return view_as<JailSurvivor>(player);
	}
	property int iRolls
	{
		public get() { return this.GetValue("iRolls"); }
		public set(const int i) { this.SetValue("iRolls", i); }
	}
	property int iLastProp
	{
		public get() { return this.GetValue("iLastProp"); }
		public set(const int i) { this.SetValue("iLastProp", i); }
	}
	property int iFlameCount
	{
		public get() { return this.GetValue("iFlameCount"); }
		public set(const int i) { this.SetValue("iFlameCount", i); }
	}

	property bool bTouched
	{
		public get() { return this.GetValue("bTouched"); }
		public set(const bool i) { this.SetValue("bTouched", i); }
	}
	property bool bIsProp
	{
		public get() { return this.GetValue("bIsProp"); }
		public set(const bool i) { this.SetValue("bIsProp", i); }
	}
	property bool bFlaming
	{
		public get() { return this.GetValue("bFlaming"); }
		public set(const bool i) { this.SetValue("bFlaming", i); }
	}
	property bool bLocked
	{
		public get() { return this.GetValue("bLocked"); }
		public set(const bool i) { this.SetValue("bLocked", i); }
	}
	property bool bHoldingLMB
	{
		public get() { return this.GetValue("bHoldingLMB"); }
		public set(const bool i) { this.SetValue("bHoldingLMB", i); }
	}
	property bool bHoldingRMB
	{
		public get() { return this.GetValue("bHoldingRMB"); }
		public set(const bool i) { this.SetValue("bHoldingRMB", i); }
	}
	property bool bFirstPerson
	{
		public get() { return this.GetValue("bFirstPerson"); }
		public set(const bool i) { this.SetValue("bFirstPerson", i); }
	}
	property TFClassType iOldClass
	{
		public get() { return this.GetValue("iOldClass"); }
		public set(const TFClassType i) { this.SetValue("iOldClass", i); }
	}
};

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
		public get() { return this.GetValue("iHealth"); }
		public set(const int i) { this.SetValue("iHealth", i); }
	}
	property int iMaxHealth
	{
		public get() { return this.GetValue("iMaxHealth"); }
		public set(const int i) { this.SetValue("iMaxHealth", i); }
	}
	property int iAirDamage
	{
		public get() { return this.GetValue("iAirDamage"); }
		public set(const int i) { this.SetValue("iAirDamage", i); }
	}
	property int iType
	{
		public get() { return this.GetValue("iType"); }
		public set(const int i) { this.SetValue("iType", i); }
	}
	property int iDamage
	{
		public get() { return this.GetValue("iDamage"); }
		public set(const int i) { this.SetValue("iDamage", i); }
	}
	property int bGlow
	{
		public get() { return GetEntProp(this.index, Prop_Send, "m_bGlowEnabled"); }
		public set(int i)
		{
			Clamp(i, 0, 1);
			SetEntProp(this.index, Prop_Send, "m_bGlowEnabled", i);
		}
	}
	property int iKills
	{
		public get() { return this.GetValue("iKills"); }
		public set(const int i) { this.SetValue("iKills", i); }
	}
	property bool bIsZombie
	{
		public get() { return this.GetValue("bIsZombie"); }
		public set(const bool i) { this.SetValue("bIsZombie", i); }
	}
	property bool bIsLast3
	{
		public get() { return this.GetValue("bIsLast3"); }
		public set(const bool i) { this.SetValue("bIsLast3", i); }
	}
	property bool bIsLast
	{
		public get() { return this.GetValue("bIsLast"); }
		public set(const bool i) { this.SetValue("bIsLast", i); }
	}
	property bool bNeedsToGoBackToBlue
	{
		public get() { return this.GetValue("bNeedsToGoBackToBlue"); }
		public set(const bool i) { this.SetValue("bNeedsToGoBackToBlue", i); }
	}
	property bool bNeedsToGoBackToRed
	{
		public get() { return this.GetValue("bNeedsToGoBackToRed"); }
		public set(const bool i) { this.SetValue("bNeedsToGoBackToRed", i); }
	}
	property float flGlowtime
	{
		public get()
		{
			float i = this.GetValue("flGlowtime");
			if (i < 0.0)i = 0.0;
			return i;
		}
		public set(const float i) { this.SetValue("flGlowtime", i); }
	}
	public void DoGenericThink(bool jump = false, bool sound = false, char[] strSound = "", int random = 0, bool mp3 = true)
	{

	}
};

public Plugin myinfo =
{
	name = "TF2Jail ZVE LR Module",
	author = "blood, original gamemode by also by blood",
	description = "Zombies Vs Engineers embedded as an LR for TF2Jail Redux",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	JBZVE[Version] = CreateConVar("jbzve_version", PLUGIN_VERSION, "Zombies Vs Engineers (Do not touch)", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	JBZVE[Timeleft] = CreateConVar("sm_jbzve_round_time", "300", "Round time during a VSH round IF a time limit is enabled in core plugin.", FCVAR_NOTIFY, true, 0.0);
	PickCount = CreateConVar("sm_jbzve_lr_max", "5", "What is the maximum number of times this LR can be picked in a single map? 0 for no limit.", FCVAR_NOTIFY, true, 0.0);
	SetupTime = CreateConVar("sm_jbzve_setuptime", "60", "How long before setup time ends?", FCVAR_NOTIFY, true, 0.0, true, 120.0);

	HookEvent("player_death", PlayerDeath);

	AutoExecConfig(true, "LRModuleZVE");

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
}

public void OnMapStart()
{
	DHookGamerules(hSetWinningTeamPre, false);
}

//CTFGameRules::SetWinningTeam(int,int,bool,bool,bool,bool)
public MRESReturn Hook_SetWinningTeamPre(Handle hParams)
{
	if (NOTZVE)
		return MRES_Ignored;
	else if (!NOTZVE && GetTeamAliveCount(TFTeam_Red) >> 0)
		return MRES_Supercede;
}

public void OnAllPluginsLoaded()
{
	TF2JailRedux_RegisterPlugin();
	gamemode = new JBGameMode();
	LoadJBHooks();
}

public void OnPluginEnd()
{
	if (LibraryExists("TF2Jail_Redux")) // If TF2JailRedux is still loaded
		TF2JailRedux_UnRegisterPlugin(); // Unregister
}

public void OnLibraryRemoved(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false))
	{  // If enabled, disable
		bDisabled = true; // The global isn't required
	}
}

public void OnLibraryAdded(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false) && bDisabled) // Rinse and repeat
		OnAllPluginsLoaded();
}


/********************************************************************
						[F*O*R*W*A*R*D*S]
********************************************************************/
// Obviously, here we place what would normally go under the proper, called function in the core plugin
public void fwdOnDownloads()
{

}
public void fwdOnRoundStartPlayer(const JBPlayer Player, Event event)
{
	if (NOTZVE)
		return;
}

public void fwdOnRoundStart()
{
	if (NOTZVE)
		return;

	gamemode.bIsWardenLocked = true;
	gamemode.bCellsOpened = true;
	gamemode.bOneGuardLeft = true;
	gamemode.bDisableCriticals = true;
	gamemode.bIsWarday = true;
	gamemode.bAllowBuilding = true;
	gamemode.bDisableKillSpree = true;
	gamemode.bIgnoreRebels = true;
	gamemode.DoorHandler(OPEN);

	g_bHasRoundStarted = false;

	gamemode.iTimeLeft = JBZVE[Timeleft].IntValue;

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

	CPrintToChatAll("%t %t", "Plugin Tag", "ZVE LR Zombie Frozen Time", SetupTime.IntValue);
	hSetupTime = CreateTimer(SetupTime.FloatValue, TIMER_StartRound);
	hRoundTime = CreateTimer(JBZVE[Timeleft].FloatValue / 2, Timer_BuffZombies);

	ServerCommand("tf_zve_dj_boost 250");

	Buffed = false;
}

public void fwdOnRoundEnd(Event event)
{
	if (NOTZVE)
		return;

	g_bHasRoundStarted = false;
	if(hSetupTime == INVALID_HANDLE)
		KillTimer(hSetupTime);

	if(hRoundTime == INVALID_HANDLE)
		KillTimer(hRoundTime);

	Buffed = false;
}
public void fwdOnRedThink(const JBPlayer Player)
{

}
public void fwdOnBlueThink(const JBPlayer Player)
{
	if (NOTZVE)
		return;

}
public void fwdOnHudShow(char strHud[128])
{
	if (NOTZVE)
		return;

	strcopy(strHud, 128, "Zombies Vs Engineers");
}

public Action fwdOnLRPicked(const JBPlayer Player, const int selection, ArrayList arrLRS)
{
	if (selection == TF2JailRedux_LRIndex())
		CPrintToChatAll("%t %t", "Plugin Tag", "ZVE LR Chosen LR", Player.index);

	return Plugin_Continue; // Returning anything but Plugin_Continue will reject the LR selection
}

public Action PlayerDeath(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	JailZombie victim = JailZombie(client);

	if (!NOTZVE)
	{
		if (victim.bIsLast3 || victim.bIsLast)
		{
			victim.bIsLast3 = false;
			victim.bIsLast = false;
		}

		if (GetTeamAliveCount(TFTeam_Red) == 3)
		{
			for (int i = MaxClients; i; --i)
			{
				JailZombie base = JailZombie(i);

				if (IsClientInGame(base.index) && IsPlayerAlive(base.index) && TF2_GetClientTeam(base.index) == TFTeam_Red && !base.bIsZombie && !base.bIsLast)
				{
					base.bIsLast3 = true;

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

				if (IsClientInGame(base.index) && IsPlayerAlive(base.index) && TF2_GetClientTeam(base.index) == TFTeam_Red && !base.bIsZombie && !base.bIsLast)
				{
					base.bIsLast = true;

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

		if (g_bHasRoundStarted)
		{
			if (IsClientInGame(victim.index))
			{
				victim.ForceTeamChange(BLU);
				victim.bIsZombie = true;
				CreateTimer(1.0, RespawnPlayer);
			}
		}
		else
		{
			if (IsClientInGame(victim.index))
			{
				victim.ForceTeamChange(RED);
				victim.bIsZombie = false;
				CreateTimer(1.0, RespawnPlayer);
			}
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

			if (Buffed)
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

public void fwdOnBuildingDestroyed(const JBPlayer Attacker, const int building, Event event)
{

}
public void fwdOnObjectDeflected(const JBPlayer Victim, const JBPlayer Attacker, Event event)
{

}
public void fwdOnPlayerJarated(const JBPlayer Attacker, const JBPlayer Victim)
{

}
public void fwdOnUberDeployed(const JBPlayer Medic, const JBPlayer Patient)
{

}
public void fwdOnPlayerSpawned(const JBPlayer Player, Event event)
{
	if (NOTZVE)
		return;

	JailZombie spawn = JailZombie.Of(Player);

	if (GetClientTeam(spawn.index) == BLU)
	{
		if (spawn.bIsZombie)
			TF2_SetPlayerClass(spawn.index, TFClass_Medic);
	}
}
public void fwdOnMenuAdd(const int index, int &max, char strName[32])
{
	if (index != TF2JailRedux_LRIndex())
		return;

	max = PickCount.IntValue; // Everything else is managed in core, even if max is 0
	strcopy(strName, sizeof(strName), "Zombies Vs Engineers");
}
public void fwdOnPanelAdd(const int index, char name[64])
{
	if (index != TF2JailRedux_LRIndex())
		return;

	strcopy(name, sizeof(name), "Zombies Vs Engineers");
}
public void fwdOnTimeLeft()
{
	if (NOTZVE)
		return;



	gamemode.iTimeLeft = JBZVE[Timeleft].IntValue;
}
public void fwdOnHurtPlayer(const JBPlayer Victim, const JBPlayer Attacker, Event event)
{

}
public Action fwdOnTakeDamage(const JBPlayer Victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{

}

public void fwdOnClientInduction(const JBPlayer Player)
{
	JailZombie base = JailZombie.Of(Player);

	base.bNeedsToGoBackToBlue = false;
	base.bNeedsToGoBackToRed = false;
}

public Action fwdOnMusicPlay(char song[PLATFORM_MAX_PATH], float &time)
{

}
public void fwdOnVariableReset(const JBPlayer Player)
{
	JailZombie base = JailZombie.Of(Player);

	base.bIsZombie = false;

	if (base.bIsLast3 || base.bIsLast)
	{
		base.bIsLast3 = false;
		base.bIsLast = false;
	}

	for (int i = MaxClients; i; --i)
	{
		JailZombie loop = JailZombie(i);

		if (IsClientInGame(loop.index))
		{
			TF2Attrib_SetByDefIndex(loop.index, 448, 0.0);
			TF2Attrib_SetByDefIndex(loop.index, 450, 0.0);
		}
	}

	if (base.bNeedsToGoBackToBlue && GetClientTeam(base.index) != BLU)
		ChangeClientTeam(base.index, BLU);
	base.bNeedsToGoBackToBlue = false;

	if (base.bNeedsToGoBackToRed && GetClientTeam(base.index) != RED)
		ChangeClientTeam(base.index, RED);

	base.bNeedsToGoBackToRed = false;
}
public void fwdOnLastPrisoner()
{

}
public void fwdOnCheckLivingPlayers()
{

}

public Action fwdOnPlayerPreppedPre(const JBPlayer player)
{
	if (NOTZVE)
		return;
}

public void fwdOnRoundEndPlayer(const JBPlayer player, Event event)
{

}

public Action fwdOnSoundHook(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], JBPlayer player, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{

}

public Action fwdOnCalcAttack(JBPlayer player, int weapon, char[] weaponname, bool &result)
{

}

public Action fwdOnEntCreated(int entity, const char[] classname)
{

}

public void OnPostAdminCheck(int client)
{
	if (NOTZVE)
		return;

	JailZombie victim = JailZombie(client);

	if (IsClientInGame(victim.index))
	{
		victim.ForceTeamChange(BLU);
		victim.bIsZombie = true;
		CreateTimer(1.0, RespawnPlayer);
	}
}

public Action Timer_BuffZombies(Handle timer)
{
	ServerCommand("tf_zve_dj_boost 400");
	PrintCenterTextAll("Zombies have been given a damage, speed and jump boost!.");
	Buffed = true;

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

	TF2_StunPlayer(rand.index, SetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
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

	TF2_StunPlayer(rand.index, SetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
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

	TF2_StunPlayer(rand2.index, SetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
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

	TF2_StunPlayer(rand.index, SetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
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

	TF2_StunPlayer(rand2.index, SetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
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

	TF2_StunPlayer(rand3.index, SetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
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

	TF2_StunPlayer(rand.index, SetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
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

	TF2_StunPlayer(rand2.index, SetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
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

	TF2_StunPlayer(rand3.index, SetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
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

	TF2_StunPlayer(rand4.index, SetupTime.FloatValue, 1.00, TF_STUNFLAG_SLOWDOWN);
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

public void LoadJBHooks()
{
	if (!JB_HookEx(OnDownloads, fwdOnDownloads))
		LogError("Failed to load OnDownloads forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnRoundStartPlayer, fwdOnRoundStartPlayer))
		LogError("Failed to load OnRoundStartPlayer forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnRoundStart, fwdOnRoundStart))
		LogError("Failed to load OnRoundStart forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnRoundEnd, fwdOnRoundEnd))
		LogError("Failed to load OnRoundEnd forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnRoundEndPlayer, fwdOnRoundEndPlayer))
		LogError("Failed to load OnRoundEndPlayer forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnRedThink, fwdOnRedThink))
		LogError("Failed to load OnRedThink forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnBlueThink, fwdOnBlueThink))
		LogError("Failed to load OnBlueThink forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnHudShow, fwdOnHudShow))
		LogError("Failed to load OnHudShow forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnLRPicked, fwdOnLRPicked))
		LogError("Failed to load OnLRPicked forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnBuildingDestroyed, fwdOnBuildingDestroyed))
		LogError("Failed to load OnBuildingDestroyed forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnObjectDeflected, fwdOnObjectDeflected))
		LogError("Failed to load OnObjectDeflected forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnPlayerJarated, fwdOnPlayerJarated))
		LogError("Failed to load OnPlayerJarated forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnUberDeployed, fwdOnUberDeployed))
		LogError("Failed to load OnUberDeployed forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnPlayerSpawned, fwdOnPlayerSpawned))
		LogError("Failed to load OnPlayerSpawned forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnMenuAdd, fwdOnMenuAdd))
		LogError("Failed to load OnMenuAdd forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnPanelAdd, fwdOnPanelAdd))
		LogError("Failed to load OnPanelAdd forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnTimeLeft, fwdOnTimeLeft))
		LogError("Failed to load OnTimeLeft forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnHurtPlayer, fwdOnHurtPlayer))
		LogError("Failed to load OnHurtPlayer forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnTakeDamage, fwdOnTakeDamage))
		LogError("Failed to load OnTakeDamage forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnClientInduction, fwdOnClientInduction))
		LogError("Failed to load OnClientInduction forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnPlayMusic, fwdOnMusicPlay))
		LogError("Failed to load OnMusicPlay forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnVariableReset, fwdOnVariableReset))
		LogError("Failed to load OnVariableReset forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnLastPrisoner, fwdOnLastPrisoner))
		LogError("Failed to load OnLastPrisoner forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnCheckLivingPlayers, fwdOnCheckLivingPlayers))
		LogError("Failed to load OnCheckLivingPlayers forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnPlayerPreppedPre, fwdOnPlayerPreppedPre))
		LogError("Failed to load OnPlayerPreppedPre forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnSoundHook, fwdOnSoundHook))
		LogError("Failed to load OnSoundHook forwards for JB ZVE Sub-Plugin!");
	if (!JB_HookEx(OnEntCreated, fwdOnEntCreated))
		LogError("Failed to load OnEntCreated forwards for JB ZVE Sub-Plugin!");
}
