#include <sourcemod>
#include <sdkhooks>
#include <tf2items>
#include <morecolors>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2jailredux>

#pragma semicolon 1
#pragma newdecls required

#include "TF2JailRedux/stocks.inc"

#define PLUGIN_VERSION 		"1.0.0"

#define RED 				2
#define BLU 				3

int g_iGlowRef[32] =  { INVALID_ENT_REFERENCE, ... };

Handle g_hWeaponEquip;
Handle g_hGameConfig;

bool g_bHiddenSticky;
bool g_bJumped;

Handle g_hTick;
Handle g_hHiddenHudHp;
Handle g_hHiddenHudClusterBomb;

int g_iHiddenCurrentHp;
int g_iHiddenHpMax;

float g_fHiddenBomb;

char g_sCanisterModel[255] = "models/effects/bday_gib01.mdl";
char g_sBombletModel[255] = "models/weapons/w_models/w_grenade_grenadelauncher.mdl";
char g_sDetonationSound[255] = "ambient/machines/slicer3.wav";
char g_sBlipSound[255] = "buttons/blip1.wav";

float g_fTickInterval;

methodmap JailHidden < JBPlayer
{  // Here we inherit all of the properties and functions that we made as natives
	public JailHidden(const int q)
	{
		return view_as<JailHidden>(q);
	}
	public static JailHidden OfUserId(const int id)
	{
		return view_as<JailHidden>(GetClientOfUserId(id));
	}
	public static JailHidden Of(const JBPlayer player)
	{
		return view_as<JailHidden>(player);
	}
	
	property int iUberTarget
	{  // And then add new ones that we need
		public get() { return this.GetProp("iUberTarget"); }
		public set(const int i) { this.SetProp("iUberTarget", i); }
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
	property int iAirDamage
	{
		public get() { return this.GetProp("iAirDamage"); }
		public set(const int i) { this.SetProp("iAirDamage", i); }
	}
	property int iType
	{
		public get() { return this.GetProp("iType"); }
		public set(const int i) { this.SetProp("iType", i); }
	}
	property int iStabbed
	{
		public get() { return this.GetProp("iStabbed"); }
		public set(const int i) { this.SetProp("iStabbed", i); }
	}
	property int iMarketted
	{
		public get() { return this.GetProp("iMarketted"); }
		public set(const int i) { this.SetProp("iMarketted", i); }
	}
	property int iDamage
	{
		public get() { return this.GetProp("iDamage"); }
		public set(const int i) { this.SetProp("iDamage", i); }
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
		public get() { return this.GetProp("iKills"); }
		public set(const int i) { this.SetProp("iKills", i); }
	}
	property int iClimbs
	{
		public get() { return this.GetProp("iClimbs"); }
		public set(const int i) { this.SetProp("iClimbs", i); }
	}
	
	property bool bIsHidden
	{
		public get() { return this.GetProp("bIsHidden"); }
		public set(const bool i) { this.SetProp("bIsHidden", i); }
	}
	property bool bNeedsToGoBackToBlue
	{
		public get() { return this.GetProp("bNeedsToGoBackToBlue"); }
		public set(const bool i) { this.SetProp("bNeedsToGoBackToBlue", i); }
	}
	
	property float flRAGE
	{
		public get() { return this.GetProp("flRAGE"); }
		public set(const float i) { this.SetProp("flRAGE", i); }
	}
	property float flWeighDown
	{
		public get() { return this.GetProp("flWeighDown"); }
		public set(const float i) { this.SetProp("flWeighDown", i); }
	}
	property float flGlowtime
	{
		public get()
		{
			float i = this.GetProp("flGlowtime");
			if (i < 0.0)i = 0.0;
			return i;
		}
		public set(const float i) { this.SetProp("flGlowtime", i); }
	}
	property float flCharge
	{
		public get() { return this.GetProp("flCharge"); }
		public set(const float i) { this.SetProp("flCharge", i); }
	}
	property float flKillSpree
	{
		public get() { return this.GetProp("flKillSpree"); }
		public set(const float i) { this.SetProp("flKillSpree", i); }
	}
	public void GiveRage(const int damage)
	{  // On player_hurt
		this.flRAGE += (damage / SquareRoot(30000.0) * 4.0);
	}
	public void DoGenericStun(const float rageDist)
	{
		int i;
		float pos[3], pos2[3], distance;
		int client = this.index;
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
		for (i = MaxClients; i; --i) {
			if (!IsValidClient(i) || !IsPlayerAlive(i) || i == client)
				continue;
			else if (GetClientTeam(i) == GetClientTeam(client))
				continue;
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
			distance = GetVectorDistance(pos, pos2);
			if (!TF2_IsPlayerInCondition(i, TFCond_Ubercharged) && distance < rageDist) {
				AttachParticle(i, "yikes_fx", 5.0, 75.0);
				TF2_StunPlayer(i, 5.0, _, TF_STUNFLAGS_GHOSTSCARE | TF_STUNFLAG_NOSOUNDOREFFECT, client);
			}
		}
		i = -1;
		while ((i = FindEntityByClassname(i, "obj_sentrygun")) != -1)
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
			distance = GetVectorDistance(pos, pos2);
			if (distance < rageDist) {
				SetEntProp(i, Prop_Send, "m_bDisabled", 1);
				AttachParticle(i, "yikes_fx", 5.0, 75.0);
				SetVariantInt(1);
				AcceptEntityInput(i, "RemoveHealth");
				//SetPawnTimer(EnableSG, 8.0, EntIndexToEntRef(i)); //CreateTimer(8.0, EnableSG, EntIndexToEntRef(i));
			}
		}
		i = -1;
		while ((i = FindEntityByClassname(i, "obj_dispenser")) != -1)
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
			distance = GetVectorDistance(pos, pos2);
			if (distance < rageDist) {
				SetVariantInt(1);
				AcceptEntityInput(i, "RemoveHealth");
			}
		}
		i = -1;
		while ((i = FindEntityByClassname(i, "obj_teleporter")) != -1)
		{
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
			distance = GetVectorDistance(pos, pos2);
			if (distance < rageDist) {
				SetVariantInt(1);
				AcceptEntityInput(i, "RemoveHealth");
			}
		}
	}
};

public Plugin myinfo = 
{
	name = "TF2Jail LR Module Hidden", 
	author = "blood", 
	description = "Adds the Hidden mode to Jailbreak", 
	version = PLUGIN_VERSION, 
	url = ""
};

ConVar PickCount;

JBGameMode
gamemode
;

enum
{
	DisableMuting, 
	Version
};

bool g_bTimerDieTick;

ConVar
JBHidden[Version + 1], 
hTeamBansCVar, 
hNoChargeCVar, 
hEngiePDACvar, 
TimeLeft, 
hDroppedWeaponsCVar
;

ConVar HPBase;
ConVar HPIncrease;
ConVar HPIncreaseKill;
ConVar BombDetonationDelay;
ConVar BombCooldown;
ConVar BombletCount;
ConVar BombletMagnitude;
ConVar BombletSpread;
ConVar BombThrowSpeed;
ConVar BombIgnoreHidden;

int
iTeamBansCVar,  // Mid-round detection in case a player is guardbanned
iNoChargeCVar,  // Allow for charging
iDroppedWeaponsCVar,  // Allow dropped weapons
iEngiePDACvar
;

int HealthNumerator;


public void OnPluginStart()
{
	PickCount = CreateConVar("sm_jbhidden_pickcount", "5", "Maximum number of times this LR can be picked in a single map. 0 for no limit", FCVAR_NOTIFY, true, 0.0);
	JBHidden[DisableMuting] = CreateConVar("sm_jbhidden_disable_muting", "0", "Disable plugin muting during this last request?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HPBase = CreateConVar("sm_thehidden_hpbase", "300", "Amount of hp used for calculating the Hidden's starting/max hp.", FCVAR_NONE, true, 1.0, true, 10000.0);
	HPIncrease = CreateConVar("sm_jbhidden_hpincreaseperplayer", "70", "This amount of hp, multiplied by the number of players, plus the base hp, equals The Hidden's hp.", FCVAR_NONE, true, 0.0, true, 1000.0);
	HPIncreaseKill = CreateConVar("sm_jbhidden_hpincreaseperkill", "50", "Amount of hp the Hidden gets back after he kills a player. This value changes based on victim's class.", FCVAR_NONE, true, 0.0, true, 1000.0);
	BombletCount = CreateConVar("sm_jbhidden_bombletcount", "10", "Amount of bomb clusters(bomblets) inside a cluster bomb.", FCVAR_NONE, true, 1.0, true, 30.0);
	BombletMagnitude = CreateConVar("sm_jbhidden_bombletmagnitude", "30.0", "Magnitude of a bomblet.", FCVAR_NONE, true, 1.0, true, 1000.0);
	BombletSpread = CreateConVar("sm_jbhidden_bombletspreadvel", "60.0", "Spread velocity for a randomized direction, bomblets are going to use.", FCVAR_NONE, true, 1.0, true, 500.0);
	BombThrowSpeed = CreateConVar("sm_jbhidden_bombthrowspeed", "2000.0", "Cluster bomb throw speed.", FCVAR_NONE, true, 1.0, true, 10000.0);
	BombDetonationDelay = CreateConVar("sm_jbhidden_bombdetonationdelay", "5.0", "Delay of the cluster bomb detonation.", FCVAR_NONE, true, 0.1, true, 100.0);
	BombIgnoreHidden = CreateConVar("sm_jbhidden_bombignoreuser", "0", "Sets whether the bomb should ignore the Hidden or not.", FCVAR_NONE, true, 0.0, true, 1.0);
	JBHidden[TimeLeft] = CreateConVar("sm_jbhidden_round_time", "600", "Round time during a VSH round IF a time limit is enabled in core plugin.", FCVAR_NOTIFY, true, 0.0);
	BombCooldown = CreateConVar("sm_jbhidden_bombtime", "20.0", "Cluster bomb cooldown.", FCVAR_NONE, true, 1.0, true, 1000.0);
	
	AutoExecConfig(true, "LRModuleHidden");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConfig, SDKConf_Virtual, "WeaponEquip");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hWeaponEquip = EndPrepSDKCall();
	
	if (!g_hWeaponEquip)
	{
		SetFailState("[TF2JailLRModule - Hidden] Failed to prepare the SDKCall forgiving weapons. Try updating gamedata or restarting your server.");
	}
	
	g_fTickInterval = GetTickInterval(); // 0.014999 default
	
	g_hHiddenHudHp = CreateHudSynchronizer();
	g_hHiddenHudClusterBomb = CreateHudSynchronizer();
}

#define CHECK() 				if ( JBGameMode_GetProperty("iLRType") != TF2JailRedux_LRIndex() ) return

public void OnPluginEnd()
{
	TF2JailRedux_UnRegisterPlugin();
}

public void InitSubPlugin()
{
	TF2JailRedux_RegisterPlugin();
	gamemode = new JBGameMode();
	hTeamBansCVar = FindConVar("sm_jbans_ignore_midround");
	hNoChargeCVar = FindConVar("sm_tf2jr_demo_charge");
	hDroppedWeaponsCVar = FindConVar("sm_tf2jr_dropped_weapons");
	hEngiePDACvar = FindConVar("sm_tf2jr_engi_pda");
}

public void OnLibraryAdded(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false))
	{
		TF2JailRedux_RegisterPlugin();
		JB_Hook(OnHudShow, fwdOnHudShow);
		JB_Hook(OnLRPicked, fwdOnLRPicked);
		JB_Hook(OnPanelAdd, fwdOnPanelAdd);
		JB_Hook(OnMenuAdd, fwdOnMenuAdd); // The necessities
		
		//JB_Hook(OnDownloads, 				fwdOnDownloads);
		JB_Hook(OnRoundStart2, fwdOnRoundStart);
		JB_Hook(OnRoundStartPlayer2, fwdOnRoundStartPlayer);
		JB_Hook(OnRoundEnd, fwdOnRoundEnd);
		//JB_Hook(OnRoundEndPlayer, 		fwdOnRoundEndPlayer);
		//JB_Hook(OnPreThink, 				fwdOnPreThink);
		//JB_Hook(OnRedThink, 				fwdOnRedThink);
		//JB_Hook(OnBlueThink, 				fwdOnBlueThink);
		//JB_Hook(OnWardenGet, 				fwdOnWardenGet);
		//JB_Hook(OnClientTouch, 			fwdOnClientTouch);
		//JB_Hook(OnWardenThink, 			fwdOnWardenThink);
		//JB_Hook(OnPlayerSpawned, 			fwdOnPlayerSpawned);
		JB_Hook(OnPlayerDied, fwdOnPlayerDied);
		//JB_Hook(OnWardenKilled, 			fwdOnWardenKilled);
		JB_Hook(OnTimeLeft, fwdOnTimeLeft);
		//JB_Hook(OnPlayerPrepped, 			fwdOnPlayerPrepped);
		//JB_Hook(OnPlayerPreppedPre, 		fwdOnPlayerPreppedPre);
		JB_Hook(OnHurtPlayer, fwdOnHurtPlayer);
		JB_Hook(OnTakeDamage, fwdOnTakeDamage);
		//JB_Hook(OnLastGuard, 				fwdOnLastGuard);
		//JB_Hook(OnLastPrisoner, 			fwdOnLastPrisoner);
		//JB_Hook(OnCheckLivingPlayers, 	fwdOnCheckLivingPlayers);
		//JB_Hook(OnBuildingDestroyed, 		fwdOnBuildingDestroyed);
		//JB_Hook(OnObjectDeflected, 		fwdOnObjectDeflected);
		//JB_Hook(OnPlayerJarated, 			fwdOnPlayerJarated);
		//JB_Hook(OnUberDeployed, 			fwdOnUberDeployed);
		//JB_Hook(OnWMenuAdd, 				fwdOnWMenuAdd);
		//JB_Hook(OnWMenuSelect, 			fwdOnWMenuSelect);
		//JB_Hook(OnClientInduction, 		fwdOnClientInduction);
		JB_Hook(OnVariableReset, fwdOnVariableReset);
		//JB_Hook(OnTimeEnd, 				fwdOnTimeEnd);
		//JB_Hook(OnFreedayGiven, 			fwdOnFreedayGiven);
		//JB_Hook(OnFreedayRemoved, 		fwdOnFreedayRemoved);
		//JB_Hook(OnFFTimer, 				fwdOnFFTimer);
		//JB_Hook(OnDoorsOpen, 				fwdOnDoorsOpen);
		//JB_Hook(OnDoorsClose, 			fwdOnDoorsClose);
		//JB_Hook(OnDoorsLock, 				fwdOnDoorsLock);
		//JB_Hook(OnDoorsUnlock, 			fwdOnDoorsUnlock);
		//JB_Hook(OnPlayMusic, 				fwdOnPlayMusic);
		//JB_Hook(OnSetWardenLock, 			fwdOnSetWardenLock);
		
		InitSubPlugin();
	}
}

public void fwdOnRoundStartPlayer(const JBPlayer Player)
{
	CHECK();
	
	JailHidden base = JailHidden.Of(Player);
	base.iDamage = 0;
	TF2_RemoveAllWeapons(base.index); // Hacky bug patch: Remove weapons to force TF2Items_OnGiveNamedItem to fire for each
	
	if (GetClientTeam(base.index) == BLU && !base.bIsHidden)
	{
		SetEntityMoveType(base.index, MOVETYPE_WALK);
		base.ForceTeamChange(RED);
		base.bNeedsToGoBackToBlue = true;
		return;
	}
	
	if (TF2_GetPlayerClass(base.index) == TFClass_Pyro)
		TF2_SetPlayerClass(base.index, TFClass_Scout);
	
	TF2_RegeneratePlayer(base.index); // Triggers PrepPlayer, which can be overridden. See OnPlayerPreppedPre
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && !JailHidden(i).bIsHidden)
			ApplyGlow(i);
	}
	
	g_hTick = CreateTimer(0.2, Timer_Tick, _, TIMER_REPEAT);
}

public Action Timer_Tick(Handle timer)
{
	if (g_bTimerDieTick == true)
	{
		return Plugin_Stop;
	}
	
	ShowHiddenHP();
	return Plugin_Continue;
}

public void OnMapStart()
{
	PrecacheSound(g_sDetonationSound, true);
	PrecacheModel(g_sCanisterModel, true);
	PrecacheModel(g_sBombletModel, true);
	PrecacheSound(g_sBlipSound, true);
	PrecacheModel("models/props_halloween/ghost.mdl", true);
	PrecacheSound("vo/halloween_boo1.mp3", true);
	PrecacheSound("vo/halloween_boo2.mp3", true);
	PrecacheSound("vo/halloween_boo3.mp3", true);
	PrecacheSound("vo/halloween_boo4.mp3", true);
	PrecacheSound("vo/halloween_boo5.mp3", true);
	PrecacheSound("vo/halloween_boo6.mp3", true);
	PrecacheSound("vo/halloween_boo7.mp3", true);
}

public void fwdOnPlayerDied(const JBPlayer Victim, const JBPlayer Attacker, Event event)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (JailHidden(attacker).bIsHidden)
	{
		int hpperkill = HPIncreaseKill.IntValue;
		
		TFClassType classv = TF2_GetPlayerClass(victim);
		
		switch (classv)
		{
			case TFClass_Scout, TFClass_Sniper, TFClass_Engineer:
			{
				g_iHiddenCurrentHp += hpperkill;
				
				if (g_iHiddenCurrentHp > g_iHiddenHpMax)
				{
					g_iHiddenCurrentHp = g_iHiddenHpMax;
				}
			}
			case TFClass_Heavy, TFClass_Soldier:
			{
				g_iHiddenCurrentHp += hpperkill + 20;
				
				if (g_iHiddenCurrentHp > g_iHiddenHpMax)
				{
					g_iHiddenCurrentHp = g_iHiddenHpMax;
				}
			}
			default:
			{
				g_iHiddenCurrentHp += hpperkill + 10;
				
				if (g_iHiddenCurrentHp > g_iHiddenHpMax)
				{
					g_iHiddenCurrentHp = g_iHiddenHpMax;
				}
			}
		}
	}
}

public void fwdOnRoundStart()
{
	CHECK();
	
	gamemode.bIsWardenLocked = true;
	gamemode.bCellsOpened = true;
	gamemode.bOneGuardLeft = true;
	gamemode.bDisableCriticals = true;
	gamemode.bIsWarday = true;
	gamemode.bAllowAmmo = true;
	gamemode.bDisableKillSpree = true;
	gamemode.bIgnoreRebels = true;
	if (JBHidden[DisableMuting].BoolValue)
		gamemode.bDisableMuting = true;
	gamemode.DoorHandler(OPEN);
	
	RequestFrame(AllowBuildings);
	
	if (hTeamBansCVar && !hTeamBansCVar.BoolValue)
	{
		hTeamBansCVar.SetBool(true);
		iTeamBansCVar = 1;
	}
	
	if (hTeamBansCVar && !hTeamBansCVar.BoolValue)
	{
		hTeamBansCVar.SetBool(true);
		iTeamBansCVar = 1;
	}
	
	if (hNoChargeCVar)
	{
		iNoChargeCVar = hNoChargeCVar.IntValue;
		hNoChargeCVar.SetInt(0);
	}
	
	if (hDroppedWeaponsCVar)
	{
		iDroppedWeaponsCVar = hDroppedWeaponsCVar.IntValue;
		hDroppedWeaponsCVar.SetInt(1);
	}
	
	if (hEngiePDACvar)
	{
		iEngiePDACvar = hEngiePDACvar.IntValue;
		hEngiePDACvar.SetInt(1);
	}
	
	if (hNoChargeCVar)
		hNoChargeCVar.SetInt(0);
	
	JailHidden rand = JailHidden(GetRandomClient(true)); // It's probably best to keep the second param true
	if (rand.index <= 0)
		ForceTeamWin(RED);
	
	int client = rand.index;
	
	if (GetClientTeam(client) == RED)
		rand.ForceTeamChange(BLU);
	
	if (!IsPlayerAlive(client))
		TF2_RespawnPlayer(client);
	
	if (TF2_GetPlayerClass(client) != TFClass_Spy)
		TF2_SetPlayerClass(client, TFClass_Spy);
	
	rand.bIsHidden = true;
	
	TF2_RemoveWeaponSlot(client, 0); // Revolver
	TF2_RemoveWeaponSlot(client, 2); // Knife
	
	if (!IsFakeClient(client))
	{
		Client_SetHideHud(client, (1 << 3));
		TF2_RemoveWeaponSlot(client, 3); // Disguise Kit
	}
	
	TF2_RemoveWeaponSlot(client, 4); // Invisibility Watch
	CreateNamedItem(client, 4, "tf_weapon_knife", 1, 0);
	
	TF2_AddCondition(client, TFCond_RestrictToMelee, -1.0);
	CreateTimer(1.0, MeleeFix);
	
	GiveHiddenVision(client);
	
	int count;
	for (int i = MaxClients; i; --i)
	{
		if (IsClientInGame(i))
			count++;
	}
	
	HealthNumerator = HPIncrease.IntValue * Client_Total();
	
	g_iHiddenHpMax = GetConVarInt(HPBase) + HealthNumerator;
	
	g_iHiddenCurrentHp = g_iHiddenHpMax;
	
	g_bTimerDieTick = false;
	
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "item_healthkit_*")) != -1)
		SetEntProp(ent, Prop_Send, "m_iTeamNum", 2, 4);
}

public Action MeleeFix(Handle timer)
{
	for (int i = MaxClients; i; --i)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && JailHidden(i).bIsHidden)
		{
			int weapon = GetPlayerWeaponSlot(i, TFWeaponSlot_Melee);
			SetEntPropEnt(i, Prop_Send, "m_hActiveWeapon", weapon);
		}
	}
}

public void AllowBuildings()
{
	gamemode.bAllowBuilding = true;
}

public void fwdOnHurtPlayer(const JBPlayer Victim, const JBPlayer Attacker, Event event)
{
	if (JailHidden(Victim.index).bIsHidden)
	{
		int damage = GetEventInt(event, "damageamount");
		g_iHiddenCurrentHp -= damage;
		
		if (g_iHiddenCurrentHp < 0)
		{
			g_iHiddenCurrentHp = 0;
		}
	}
}

public void fwdOnVariableReset(const JBPlayer Player)
{
	JailHidden base = JailHidden.Of(Player);
	
	base.iUberTarget = 0;
	base.iHealth = 0;
	base.iMaxHealth = 0;
	base.iAirDamage = 0;
	base.iType = -1;
	base.iStabbed = 0;
	base.iDamage = 0;
	base.iMarketted = 0;
	// base.bGlow = 0;
	base.iClimbs = 0;
	base.bIsHidden = false;
	base.flRAGE = 0.0;
	base.flWeighDown = 0.0;
	base.flGlowtime = 0.0;
	base.flCharge = 0.0;
	base.flKillSpree = 0.0;
	
	if (base.bNeedsToGoBackToBlue && GetClientTeam(base.index) != BLU)
		ChangeClientTeam(base.index, BLU);
	base.bNeedsToGoBackToBlue = false;
}

public Action fwdOnTakeDamage(const JBPlayer Victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (IsClientInGame(Victim.index) && IsPlayerAlive(Victim.index) && JailHidden(Victim.index).bIsHidden)
	{
		if (damagetype & DMG_FALL)
			return Plugin_Handled;
		
		if (TF2_GetPlayerClass(attacker) == TFClass_Spy)
			if (damage > 100.0)
			damage = 80.0;
	}
	
	return Plugin_Continue;
}

//shoot the bomb if ready
bool HiddenBombTrigger()
{
	if (g_fHiddenBomb > 0.0)
	{
		return false;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && JailHidden(i).bIsHidden)
		{
			Command_ClusterBomb(i);
			TF2_RemoveCondition(i, TFCond_Cloaked);
		}
	}
	
	return true;
}

//cbomb and bomblets
public Action Command_ClusterBomb(int client)
{
	if (IsPlayerHere(client) && IsPlayerAlive(client))
	{
		if (GetMaxEntities() - GetEntityCount() < 200)
		{
			g_fHiddenBomb = 1.0;
			return Plugin_Handled;
		}
		
		float pos[3];
		float ePos[3];
		float angs[3];
		float vecs[3];
		GetClientEyePosition(client, pos);
		GetClientEyeAngles(client, angs);
		GetAngleVectors(angs, vecs, NULL_VECTOR, NULL_VECTOR);
		Handle trace = TR_TraceRayFilterEx(pos, angs, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
		
		if (TR_DidHit(trace))
		{
			TR_GetEndPosition(ePos, trace);
			if (GetVectorDistance(ePos, pos, false) < 45.0)
			{
				g_fHiddenBomb = 1.0;
				return Plugin_Handled;
			}
		}
		
		CloseHandle(trace);
		pos[0] += vecs[0] * 32.0;
		pos[1] += vecs[1] * 32.0;
		ScaleVector(vecs, GetConVarFloat(BombThrowSpeed));
		int ent = CreateEntityByName("prop_physics_override");
		
		if (IsValidEntity(ent))
		{
			DispatchKeyValue(ent, "model", g_sCanisterModel);
			SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
			SetEntProp(ent, Prop_Send, "m_CollisionGroup", 1);
			DispatchKeyValue(ent, "nodamageforces", "1");
			DispatchKeyValue(ent, "spawnflags", "512");
			SetEntProp(ent, Prop_Send, "m_iTeamNum", 3);
			SetEntProp(ent, Prop_Send, "m_nSkin", 1);
			DispatchSpawn(ent);
			TeleportEntity(ent, pos, NULL_VECTOR, vecs);
			g_fHiddenBomb = GetConVarFloat(BombCooldown);
			CreateTimer(GetConVarFloat(BombDetonationDelay), SpawnClusters, ent, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	return Plugin_Handled;
}

public void fwdOnTimeLeft()
{
	CHECK();
	
	gamemode.iTimeLeft = JBHidden[TimeLeft].IntValue;
}

public Action SpawnClusters(Handle timer, any ent)
{
	if (IsValidEntity(ent))
	{
		float pos[3];
		GetEntPropVector(ent, Prop_Data, "m_vecOrigin", pos);
		EmitAmbientSound(g_sDetonationSound, pos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, 0.0);
		int client = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
		AcceptEntityInput(ent, "Kill");
		float ang[3];
		
		for (int i = 0; i < GetConVarInt(BombletCount); i++)
		{
			float fsv = GetConVarFloat(BombletSpread);
			ang[0] = ((GetURandomFloat() + 0.1) * fsv) * ((GetURandomFloat() + 0.1) * 0.8);
			ang[1] = ((GetURandomFloat() + 0.1) * fsv) * ((GetURandomFloat() + 0.1) * 0.8);
			ang[2] = ((GetURandomFloat() + 0.1) * fsv) * ((GetURandomFloat() + 0.1) * 0.8);
			
			int ent2 = CreateEntityByName("prop_physics_override");
			
			if (IsValidEntity(ent2))
			{
				DispatchKeyValue(ent2, "model", g_sBombletModel);
				SetEntPropEnt(ent2, Prop_Send, "m_hOwnerEntity", client);
				DispatchKeyValue(ent2, "nodamageforces", "1");
				DispatchKeyValue(ent2, "spawnflags", "512");
				SetEntProp(ent2, Prop_Send, "m_nSkin", 1);
				SetEntProp(ent2, Prop_Send, "m_iTeamNum", 3);
				DispatchSpawn(ent2);
				TeleportEntity(ent2, pos, NULL_VECTOR, ang);
				
				CreateTimer((GetURandomFloat() + 0.1) / 2.0 + 0.5, ExplodeBomblet, ent2, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}
public Action ExplodeBomblet(Handle timer, any ent)
{
	if (IsValidEntity(ent))
	{
		float pos[3];
		GetEntPropVector(ent, Prop_Data, "m_vecOrigin", pos);
		pos[2] += 4.0;
		int client = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
		int team = GetEntProp(client, Prop_Send, "m_iTeamNum");
		AcceptEntityInput(ent, "Kill");
		int explosion = CreateEntityByName("env_explosion");
		
		if (IsValidEntity(explosion))
		{
			int physexplosion = CreateEntityByName("point_push");
			int tMag = GetConVarInt(BombletMagnitude);
			
			if (IsValidEntity(physexplosion))
			{
				SetEntPropFloat(physexplosion, Prop_Data, "m_flMagnitude", tMag * 24.0);
				SetEntPropFloat(physexplosion, Prop_Data, "m_flRadius", tMag * 12.0);
				SetEntProp(physexplosion, Prop_Data, "m_bEnabled", 0);
				DispatchKeyValue(physexplosion, "spawnflags", "24");
				SetEntProp(physexplosion, Prop_Send, "m_iTeamNum", team);
				SetEntPropEnt(physexplosion, Prop_Send, "m_hOwnerEntity", explosion);
				DispatchSpawn(physexplosion);
				ActivateEntity(physexplosion);
				
				TeleportEntity(physexplosion, pos, NULL_VECTOR, NULL_VECTOR);
			}
			
			SetEntProp(explosion, Prop_Data, "m_iMagnitude", tMag);
			SetEntProp(explosion, Prop_Send, "m_iTeamNum", team);
			SetEntPropEnt(explosion, Prop_Send, "m_hOwnerEntity", client);
			if (GetConVarBool(BombIgnoreHidden))
			{
				SetEntPropEnt(explosion, Prop_Data, "m_hEntityIgnore", client);
			}
			
			DispatchSpawn(explosion);
			ActivateEntity(explosion);
			
			TeleportEntity(explosion, pos, NULL_VECTOR, NULL_VECTOR);
			AcceptEntityInput(explosion, "Explode");
			AcceptEntityInput(physexplosion, "Enable");
			AcceptEntityInput(explosion, "Kill");
			
			CreateTimer(0.4, StopPush, physexplosion, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public void OnGameFrame()
{
	CHECK();
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && JailHidden(i).bIsHidden)
		{
			if (!TF2_IsPlayerInCondition(i, TFCond_Cloaked) && !TF2_IsPlayerInCondition(i, TFCond_Taunting))
			{
				TF2_AddCondition(i, TFCond_Cloaked, -1.0);
			}
			
			SetEntityHealth(i, g_iHiddenCurrentHp);
			
			SetEntPropFloat(i, Prop_Send, "m_flCloakMeter", 100.0);
		}
	}
	
	if (g_fHiddenBomb > 0.0)
	{
		g_fHiddenBomb -= g_fTickInterval;
		
		if (g_fHiddenBomb < 0.0)
		{
			g_fHiddenBomb = 0.0;
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (JailHidden(client).bIsHidden && buttons &IN_ATTACK)
	{
		if (IsClientInGame(client) && JailHidden(client).bIsHidden)
			TF2_RemoveCondition(client, TFCond_Cloaked);
		
		return Plugin_Changed;
	}
	
	if (JailHidden(client).bIsHidden && buttons &IN_ATTACK2 && !IsFakeClient(client))
	{
		buttons &= ~IN_ATTACK2;
		HiddenSuperJump();
		return Plugin_Changed;
	}
	
	if (JailHidden(client).bIsHidden && buttons &IN_RELOAD)
	{
		HiddenBombTrigger();
	}
	
	if (JailHidden(client).bIsHidden && g_bHiddenSticky && (buttons &IN_JUMP > 0))
	{
		HiddenUnstick();
	}
	else if (JailHidden(client).bIsHidden && !g_bHiddenSticky && (buttons &IN_JUMP > 0))
		HiddenStick();
	
	return Plugin_Continue;
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

public void fwdOnRoundEnd(Event event)
{
	CHECK();
	
	gamemode.DoorHandler(OPEN);
	
	if (hTeamBansCVar && iTeamBansCVar)
	{
		hTeamBansCVar.SetBool(false);
		iTeamBansCVar = 0;
	}
	
	if (hNoChargeCVar)
		hNoChargeCVar.SetInt(iNoChargeCVar);
	
	if (hEngiePDACvar)
	{
		hEngiePDACvar.SetInt(iEngiePDACvar);
	}
	
	if (hDroppedWeaponsCVar)
		hDroppedWeaponsCVar.SetInt(iDroppedWeaponsCVar);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			RemoveHiddenVision(i);
			RemoveGlow(i);
			
			if (IsPlayerAlive(i))
				TF2_RemoveCondition(i, TFCond_Cloaked);
		}
	}
	
	g_bTimerDieTick = true;
	
	gamemode.bAllowAmmo = false;
	
	//g_hTick = null;
}

public void OnLibraryRemoved(const char[] name)
{
	if (!strcmp(name, "TF2JailRedux_TeamBans", false))
		hTeamBansCVar = null;
}

public void fwdOnHudShow(char strHud[128])
{
	CHECK();
	
	strcopy(strHud, 128, "The Hidden");
}
public Action fwdOnLRPicked(const JBPlayer Player, const int selection, ArrayList arrLRS)
{
	if (selection == TF2JailRedux_LRIndex())
		CPrintToChatAll("{orange}Hellhound {white}| {orange}%N {white}has chosen The Hidden as their last request.", Player.index);
	return Plugin_Continue;
}

public void fwdOnPanelAdd(const int index, char name[64])
{
	if (index != TF2JailRedux_LRIndex())
		return;
	
	strcopy(name, sizeof(name), "The Hidden");
}

public void fwdOnMenuAdd(const int index, int &max, char strName[64])
{
	if (index != TF2JailRedux_LRIndex())
		return;
	
	max = PickCount.IntValue;
	strcopy(strName, sizeof(strName), "The Hidden");
}


stock void SpawnRandomAmmo()
{
	int iEnt = MaxClients + 1;
	float vPos[3], vAng[3];
	int spawned;
	int limit = JBHidden[Ammo].IntValue;
	if (!limit)
		return;
	
	while ((iEnt = FindEntityByClassname(iEnt, "info_player_teamspawn")) != -1) {
		if (spawned >= limit)
			break;
		// Technically you'll never find a map without a spawn point.
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);
		GetEntPropVector(iEnt, Prop_Send, "m_angRotation", vAng);
		int ammo = CreateEntityByName("item_ammopack_small");
		TeleportEntity(ammo, vPos, vAng, NULL_VECTOR);
		DispatchSpawn(ammo);
		SetEntProp(ammo, Prop_Send, "m_iTeamNum", 2, 4);
		++spawned;
	}
}
stock void SpawnRandomHealth()
{
	int iEnt = MaxClients + 1;
	float vPos[3], vAng[3];
	int spawned;
	int limit = JBHidden[Health].IntValue;
	if (!limit)
		return;
	
	while ((iEnt = FindEntityByClassname(iEnt, "info_player_teamspawn")) != -1) {
		if (spawned >= limit)
			break;
		// Technically you'll never find a map without a spawn point.
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);
		GetEntPropVector(iEnt, Prop_Send, "m_angRotation", vAng);
		int healthkit = CreateEntityByName("item_healthkit_small");
		TeleportEntity(healthkit, vPos, vAng, NULL_VECTOR);
		DispatchSpawn(healthkit);
		SetEntProp(healthkit, Prop_Send, "m_iTeamNum", 2, 4);
		++spawned;
	}
}

stock bool OnlyScoutsLeft(const int team)
{
	for (int i = MaxClients; i; --i) {
		if (!IsValidClient(i) || !IsPlayerAlive(i))
			continue;
		if (GetClientTeam(i) == team && TF2_GetPlayerClass(i) != TFClass_Scout)
			return false;
	}
	return true;
}

void ShowHiddenHP()
{
	int perc = RoundToCeil(float(g_iHiddenCurrentHp) / float(g_iHiddenHpMax) * 100.0);
	int cbomb = RoundToCeil(100.0 - g_fHiddenBomb / GetConVarFloat(BombCooldown) * 100.0);
	
	if (perc <= 0.0)
	{
		return;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) > 0)
		{
			if (JailHidden(i).bIsHidden)
			{
				if (perc > 25.0)
				{
					SetHudTextParams(-1.0, 0.1, 0.23, 50, 255, 50, 255, 1, 0.0, 0.0, 0.0);
				}
				else
				{
					SetHudTextParams(-1.0, 0.1, 0.23, 255, 50, 50, 255, 1, 0.0, 0.0, 0.0);
				}
				
				ShowSyncHudText(i, g_hHiddenHudHp, "The Hidden's Health: %.0i%%", perc);
				
				SetHudTextParams(-1.0, 0.200, 0.23, 70, 70, 255, 255, 1, 0.0, 0.0, 0.0);
				ShowSyncHudText(i, g_hHiddenHudClusterBomb, "Cluster Bomb: %.0i%%", cbomb);
			}
			else
			{
				if (perc > 25.0)
				{
					SetHudTextParams(-1.0, 0.1, 0.23, 50, 255, 50, 255, 1, 0.0, 0.0, 0.0);
				}
				else
				{
					SetHudTextParams(-1.0, 0.1, 0.23, 255, 50, 50, 255, 1, 0.0, 0.0, 0.0);
				}
				
				ShowSyncHudText(i, g_hHiddenHudHp, "The Hidden's Health: %.0i%%", perc);
			}
		}
	}
}

int HiddenStick()
{
	float pos[3];
	float ang[3];
	
	for (int i = MaxClients; i; --i)
	{
		if (IsClientInGame(i) && JailHidden(i).bIsHidden)
		{
			GetClientEyeAngles(i, ang);
			GetClientEyePosition(i, pos);
		}
	}
	
	Handle ray = TR_TraceRayFilterEx(pos, ang, MASK_ALL, RayType_Infinite, TraceRay_HitWorld);
	
	if (TR_DidHit(ray))
	{
		float pos2[3];
		TR_GetEndPosition(pos2, ray);
		
		if (GetVectorDistance(pos, pos2) < 64.0)
		{
			if (g_bHiddenSticky)
			{
				CloseHandle(ray);
				return 0;
			}
			
			g_bHiddenSticky = true;
			
			for (int i = MaxClients; i; --i)
			{
				if (IsClientInGame(i) && JailHidden(i).bIsHidden)
				{
					if (GetEntityMoveType(i) != MOVETYPE_NONE)
					{
						SetEntityMoveType(i, MOVETYPE_NONE);
					}
				}
			}
			
			CloseHandle(ray);
			return 1;
		}
		else
		{
			CloseHandle(ray);
			return -1;
		}
	}
	else
	{
		CloseHandle(ray);
		return -1;
	}
}

void HiddenUnstick()
{
	g_bHiddenSticky = false;
	
	for (int i = MaxClients; i; --i)
	{
		if (IsClientInGame(i) && JailHidden(i).bIsHidden)
		{
			if (GetEntityMoveType(i) == MOVETYPE_NONE)
			{
				SetEntityMoveType(i, MOVETYPE_WALK);
				float vel[3] = 0.0;
				TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vel);
			}
		}
	}
}

void Client_SetHideHud(int client, int flags)
{
	SetEntProp(client, Prop_Send, "m_iHideHUD", flags);
}

bool CreateNamedItem(int client, int itemindex, char[] classname, int level, int quality)
{
	int weapon = CreateEntityByName(classname);
	
	if (!IsValidEntity(weapon))
	{
		return false;
	}
	
	char entclass[64];
	GetEntityNetClass(weapon, entclass, sizeof(entclass));
	SetEntData(weapon, FindSendPropInfo(entclass, "m_iItemDefinitionIndex"), itemindex);
	SetEntData(weapon, FindSendPropInfo(entclass, "m_bInitialized"), 1);
	SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityLevel"), level);
	SetEntData(weapon, FindSendPropInfo(entclass, "m_iEntityQuality"), quality);
	
	if (StrEqual(classname, "tf_weapon_builder", true) || StrEqual(classname, "tf_weapon_sapper", true))
	{
		SetEntProp(weapon, Prop_Send, "m_iObjectType", 3);
	}
	
	DispatchSpawn(weapon);
	SDKCall(g_hWeaponEquip, client, weapon);
	return true;
}

bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	if (contentsMask == -15)
	{
		LogToGame("WutFace");
	}
	
	return entity > MaxClients || !entity;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (IsClientInGame(client) && JailHidden(client).bIsHidden)
	{
		switch (condition)
		{
			case TFCond_OnFire:
			{
				TF2_RemoveCondition(client, condition);
				GiveHiddenVision(client);
			}
			case TFCond_Ubercharged:
			{
				TF2_RemoveCondition(client, condition);
				GiveHiddenVision(client);
			}
			case TFCond_Jarated:
			{
				TF2_RemoveCondition(client, condition);
				GiveHiddenVision(client);
			}
			case TFCond_Milked, TFCond_Bonked:
			{
				TF2_RemoveCondition(client, condition);
			}
			case TFCond_Bleeding:
			{
				TF2_RemoveCondition(client, condition);
				GiveHiddenVision(client);
			}
			case TFCond_DeadRingered, TFCond_Kritzkrieged, TFCond_MarkedForDeath, TFCond_CritOnFirstBlood:
			{
				TF2_RemoveCondition(client, condition);
			}
			case TFCond_Disguising, TFCond_Disguised:
			{
				if (!IsFakeClient(client))
				{
					TF2_RemoveCondition(client, condition);
				}
			}
		}
	}
}

void GiveHiddenVision(int i)
{
	OverlayCommand(i, "effects/combine_binocoverlay");
}

void RemoveHiddenVision(int i)
{
	OverlayCommand(i, "\"\"");
}

void OverlayCommand(int client, char[] overlay)
{
	if (IsPlayerHere(client))
	{
		SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT));
		ClientCommand(client, "r_screenoverlay %s", overlay);
	}
}

bool IsPlayerHere(int client)
{
	return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client));
}

bool TraceRay_HitWorld(int entity, int contentsMask)
{
	if (contentsMask == -15)
	{
		LogToGame("WutFace");
	}
	
	return entity == 0;
}

bool HiddenSuperJump()
{
	if (HiddenStick() != -1 || g_bJumped)
	{
		return;
	}
	
	HiddenUnstick();
	
	float ang[3];
	float vel[3];
	
	for (int i = MaxClients; i; --i)
	{
		if (IsClientInGame(i) && JailHidden(i).bIsHidden)
		{
			GetClientEyeAngles(i, ang);
			GetEntPropVector(i, Prop_Data, "m_vecAbsVelocity", vel);
			
			float tmp[3];
			
			GetAngleVectors(ang, tmp, NULL_VECTOR, NULL_VECTOR);
			
			vel[0] += tmp[0] * 700.0;
			vel[1] += tmp[1] * 700.0;
			vel[2] += tmp[2] * 1320.0;
			
			TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vel);
			
			TF2_RemoveCondition(i, TFCond_Cloaked);
		}
	}
	
	g_bJumped = true;
	CreateTimer(1.4, Timer_Jumped, _, TIMER_FLAG_NO_MAPCHANGE);
	return;
}

public Action Timer_Jumped(Handle timer, any data)
{
	g_bJumped = false;
}

public Action StopPush(Handle timer, any ent)
{
	if (IsValidEntity(ent))
	{
		AcceptEntityInput(ent, "Kill");
	}
}

void ApplyGlow(int iClient)
{
	RemoveGlow(iClient);
	int iGlow = CreateGlow(iClient);
	g_iGlowRef[iClient - 1] = EntIndexToEntRef(iGlow);
}

int CreateGlow(int iEnt)
{
	char oldEntName[64];
	GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));
	
	char strName[126], strClass[64];
	GetEntityClassname(iEnt, strClass, sizeof(strClass));
	Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
	DispatchKeyValue(iEnt, "targetname", strName);
	
	int ent = CreateEntityByName("tf_glow");
	DispatchKeyValue(ent, "targetname", "WallHax");
	DispatchKeyValue(ent, "target", strName);
	DispatchKeyValue(ent, "Mode", "0");
	DispatchSpawn(ent);
	int color[] =  { 0, 255, 255, 255 };
	SetVariantColor(color);
	AcceptEntityInput(ent, "SetGlowColor");
	AcceptEntityInput(ent, "Enable");
	
	SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);
	
	return ent;
}

void RemoveGlow(int iClient)
{
	int iGlow = EntRefToEntIndex(g_iGlowRef[iClient - 1]);
	if (IsValidEntity(iGlow))
		AcceptEntityInput(iGlow, "Kill");
	
	g_iGlowRef[iClient - 1] = INVALID_ENT_REFERENCE;
}
