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

#define PLUGIN_VERSION 		"2.0.0"

public Plugin myinfo =
{
	name = "TF2Jail LR Module Hidden",
	author = "blood",
	description = "Play the hidden in jailbreak!",
	version = PLUGIN_VERSION,
	url = ""
};

JBGameMode
	gamemode
;

#define RED 				2
#define BLU 				3

LastRequest
	g_LR				// Me!
;

// Last Request Stuff

bool g_bTimerDieTick;
Handle g_hWeaponEquip;
Handle g_hGameConfig;

Handle g_hTick;
Handle g_hHiddenHudHp;
Handle g_hHiddenHudClusterBomb;

int g_iHiddenCurrentHp;
int g_iHiddenHpMax;

bool g_bHiddenSticky;
bool g_bJumped;

char g_sCanisterModel[255] = "models/effects/bday_gib01.mdl";
char g_sBombletModel[255] = "models/weapons/w_models/w_grenade_grenadelauncher.mdl";
char g_sDetonationSound[255] = "ambient/machines/slicer3.wav";
char g_sBlipSound[255] = "buttons/blip1.wav";

float g_fHiddenBomb;

float g_fTickInterval;

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

int g_iGlowRef[32] =  { INVALID_ENT_REFERENCE, ... };

// Back to the plugin

#define CHECK() 				if( g_LR == null || g_LR.GetID() != gamemode.iLRType ) return

public void OnPluginStart()
{
	HPBase = CreateConVar("sm_thehidden_hpbase", "300", "Amount of hp used for calculating the Hidden's starting/max hp.", FCVAR_NONE, true, 1.0, true, 10000.0);
	HPIncrease = CreateConVar("sm_jbhidden_hpincreaseperplayer", "70", "This amount of hp, multiplied by the number of players, plus the base hp, equals The Hidden's hp.", FCVAR_NONE, true, 0.0, true, 1000.0);
	HPIncreaseKill = CreateConVar("sm_jbhidden_hpincreaseperkill", "50", "Amount of hp the Hidden gets back after he kills a player. This value changes based on victim's class.", FCVAR_NONE, true, 0.0, true, 1000.0);
	BombletCount = CreateConVar("sm_jbhidden_bombletcount", "10", "Amount of bomb clusters(bomblets) inside a cluster bomb.", FCVAR_NONE, true, 1.0, true, 30.0);
	BombletMagnitude = CreateConVar("sm_jbhidden_bombletmagnitude", "30.0", "Magnitude of a bomblet.", FCVAR_NONE, true, 1.0, true, 1000.0);
	BombletSpread = CreateConVar("sm_jbhidden_bombletspreadvel", "60.0", "Spread velocity for a randomized direction, bomblets are going to use.", FCVAR_NONE, true, 1.0, true, 500.0);
	BombThrowSpeed = CreateConVar("sm_jbhidden_bombthrowspeed", "2000.0", "Cluster bomb throw speed.", FCVAR_NONE, true, 1.0, true, 10000.0);
	BombDetonationDelay = CreateConVar("sm_jbhidden_bombdetonationdelay", "5.0", "Delay of the cluster bomb detonation.", FCVAR_NONE, true, 0.1, true, 100.0);
	BombIgnoreHidden = CreateConVar("sm_jbhidden_bombignoreuser", "0", "Sets whether the bomb should ignore the Hidden or not.", FCVAR_NONE, true, 0.0, true, 1.0);
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

public void OnLibraryAdded(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false))
	{
		InitSubPlugin();
	}
}

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
};

public void InitSubPlugin()
{
	gamemode = new JBGameMode();

	g_LR = LastRequest.CreateFromConfig("The Hidden");

	if (g_LR == null)		// If it's her first time, set the mood
	{
		g_LR = LastRequest.Create("The Hidden");
		g_LR.SetDescription("Play a spooky round of the hidden!");
		g_LR.SetAnnounceMessage("{default}{NAME}{orange} has selected {default}The Hidden{orange} as their last request.");

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

		g_LR.SetPropertyNum("bOneGuardLeft", 1);

		g_LR.ExportToConfig(.create = true, .createonly = true);
	}

	LoadJBHooks();
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

public void OnLibraryRemoved(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false))
	{}
}


public void fwdOnRoundStartPlayer(LastRequest lr, const JBPlayer Player)
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
		if(g_hTick != INVALID_HANDLE)
			g_hTick = null;
			
		return Plugin_Stop;
	}
	
	ShowHiddenHP();
	return Plugin_Continue;
}

public void fwdOnPlayerDied(LastRequest lr, const JBPlayer Victim, const JBPlayer Attacker, Event event)
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

public void fwdOnRoundStart(LastRequest lr)
{
	CHECK();
	
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
	
	int HealthNumerator = HPIncrease.IntValue * Client_Total();
	
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

public void fwdOnHurtPlayer(LastRequest lr, const JBPlayer Victim, const JBPlayer Attacker, Event event)
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

public void fwdOnVariableReset(LastRequest lr, const JBPlayer Player)
{
	JailHidden base = JailHidden.Of(Player);
	
	base.iHealth = 0;
	base.iMaxHealth = 0;
	base.iDamage = 0;
	// base.bGlow = 0;
	base.bIsHidden = false;
	
	if (base.bNeedsToGoBackToBlue && GetClientTeam(base.index) != BLU)
		ChangeClientTeam(base.index, BLU);
	base.bNeedsToGoBackToBlue = false;
}

public Action fwdOnTakeDamage(LastRequest lr, const JBPlayer Victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
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

public void fwdOnRoundEnd(LastRequest lr, Event event)
{
	CHECK();
	
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

public void LoadJBHooks()
{
	g_LR.AddHook(OnLRActivate, fwdOnRoundStart);
	g_LR.AddHook(OnLRActivatePlayer, fwdOnRoundStartPlayer);
	g_LR.AddHook(OnRoundEnd, fwdOnRoundEnd);
	g_LR.AddHook(OnPlayerDied, fwdOnPlayerDied);
	g_LR.AddHook(OnTakeDamage, fwdOnTakeDamage);
	g_LR.AddHook(OnVariableReset, fwdOnVariableReset);
	g_LR.AddHook(OnPlayerHurt, fwdOnHurtPlayer);
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
