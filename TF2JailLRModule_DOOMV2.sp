#include <sourcemod>
#include <morecolors>
#include <tf2jailredux>
#include <tf2items_giveweapon>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required
#include "TF2JailRedux/stocks.inc"

#define PLUGIN_VERSION 		"2.0.0"

public Plugin myinfo =
{
	name = "TF2Jail LR Module DOOM",
	author = "blood",
	description = "RIP AND TEAR!",
	version = PLUGIN_VERSION,
	url = ""
};

#define RED 				2
#define BLU 				3

JBGameMode
	gamemode
;

LastRequest
	g_LR				// Me!
;

// ConVars

ConVar DoomHealth;
ConVar DoomHealthIncrease;
ConVar ImpHealth;
ConVar ImpHealthIncrease;

int
iDoomHealth,
iImpHealth;

bool bMusicPlayed[MAXPLAYERS + 1];

#define CHECK() 				if( g_LR == null || g_LR.GetID() != gamemode.iLRType ) return

methodmap JailDoom < JBPlayer
{  // Here we inherit all of the properties and functions that we made as natives
	public JailDoom(const int q)
	{
		return view_as<JailDoom>(q);
	}
	public static JailDoom OfUserId(const int id)
	{
		return view_as<JailDoom>(GetClientOfUserId(id));
	}
	public static JailDoom Of(const JBPlayer player)
	{
		return view_as<JailDoom>(player);
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
	property bool bIsDoom
	{
		public get() { return this.GetProp("bIsDoom"); }
		public set(const bool i) { this.SetProp("bIsDoom", i); }
	}
	property bool bNeedsToGoBackToBlue
	{
		public get() { return this.GetProp("bNeedsToGoBackToBlue"); }
		public set(const bool i) { this.SetProp("bNeedsToGoBackToBlue", i); }
	}
};

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

	g_LR = LastRequest.CreateFromConfig("DOOM");

	if (g_LR == null)		// If it's her first time, set the mood
	{
		g_LR = LastRequest.Create("DOOM");
		g_LR.SetDescription("RIP AND TEAR");
		g_LR.SetAnnounceMessage("{default}{NAME}{orange} has selected {default}DOOM!{orange} as their last request.");

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

public void OnPluginStart()
{
	DoomHealth = CreateConVar("sm_jbdoom_doomguy_hpbase", "250", "Base HP for Doomguy", FCVAR_NONE, true, 1.0, true, 10000.0);
	DoomHealthIncrease = CreateConVar("sm_jbdoom_doomguy_hpincrease", "10", "Base HP increase per player for Doomguy.", FCVAR_NONE, true, 1.0, true, 10000.0);
	ImpHealth = CreateConVar("sm_jbdoom_imp_hpbase", "350", "Base HP for Imps", FCVAR_NONE, true, 1.0, true, 10000.0);
	ImpHealthIncrease = CreateConVar("sm_jbdoom_imp_hpincrease", "50", "Base HP increase for Imps", FCVAR_NONE, true, 1.0, true, 10000.0);

	AutoExecConfig(true, "LRModuleDOOM");
}

public void OnLibraryRemoved(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false))
	{}
}

public void fwdOnDownloads()
{
	PrepareModel("models/freak_fortress_2/doom/doomv2.mdl");
	AddFileToDownloadsTable("models/freak_fortress_2/doom/doomv2.dx80.vtx");
	AddFileToDownloadsTable("models/freak_fortress_2/doom/doomv2.dx90.vtx");
	AddFileToDownloadsTable("models/freak_fortress_2/doom/doomv2.mdl");
	AddFileToDownloadsTable("models/freak_fortress_2/doom/doomv2.phy");
	AddFileToDownloadsTable("models/freak_fortress_2/doom/doomv2.sw.vtx");
	AddFileToDownloadsTable("models/freak_fortress_2/doom/doomv2.vvd");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doom.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doom_body.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doom_f.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doom_f.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doom_n.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doomguy_happy.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doomguy_happy.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doomguy_invuln.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doomguy_invuln.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doomguy_normal_c.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doomguy_normal_c.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doomguy_normal_l.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doomguy_normal_l.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doomguy_normal_r.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/doomguy_normal_r.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/item_berserk.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/item_berserk.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/item_invuln.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/item_invuln.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/item_rocketlauncher.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/item_rocketlauncher.vtf");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/item_shotgun.vmt");
	AddFileToDownloadsTable("materials/freak_fortress_2/doom/item_shotgun.vtf");
	AddFileToDownloadsTable("sound/doom/theme.mp3");
	PrecacheSound("doom/theme.mp3");
}


public void fwdOnRoundStartPlayer(LastRequest lr, const JBPlayer Player)
{
	CHECK();

	JailDoom base = JailDoom.Of(Player);

	if (!base.bIsDoom)
	{
		base.iDamage = 0;
		TF2_RemoveAllWeapons(base.index); // Hacky bug patch: Remove weapons to force TF2Items_OnGiveNamedItem to fire for each

		if (GetClientTeam(base.index) == BLU)
		{
			SetEntityMoveType(base.index, MOVETYPE_WALK);
			base.ForceTeamChange(RED);
			base.bNeedsToGoBackToBlue = true;
			return;
		}

		CreateTimer(1.0, RoundStartPlayerTimer);

		if (IsClientInGame(base.index))
			TF2_SetPlayerClass(base.index, TFClass_Scout);

		TF2_RegeneratePlayer(base.index); // Triggers PrepPlayer, which can be overridden. See OnPlayerPreppedPre
	}
}

public Action RoundStartPlayerTimer(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !JailDoom(i).bIsDoom)
		{
			if (TF2_GetPlayerClass(i) != TFClass_Scout)
				TF2_SetPlayerClass(i, TFClass_Scout); // FIX

			TF2_RegeneratePlayer(i);

			SetEntityRenderColor(i, 255, 0, 0, 255);

			TF2_AddCondition(i, TFCond_RestrictToMelee, -1.0);
			CreateTimer(1.0, MeleeFix); // Melee shit doesn't work otherwise, idk why.

			TF2Attrib_SetByName(i, "max health additive bonus", float(iImpHealth) - 125.0);
			SetEntData(i, FindDataMapInfo(i, "m_iHealth"), iImpHealth, 4, true);

			TF2Items_GiveWeapon(i, 939);

			if (!bMusicPlayed[i])
			{
				EmitSoundToClient(i, "doom/theme.mp3");
				bMusicPlayed[i] = true;
			}
		}
	}
}

public Action MeleeFix(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && !JailDoom(i).bIsDoom)
		{
			int weapon = GetPlayerWeaponSlot(i, TFWeaponSlot_Melee);
			SetEntPropEnt(i, Prop_Send, "m_hActiveWeapon", weapon);
		}
	}
}

public void fwdOnRoundStart(LastRequest lr)
{
	CHECK();

	JailDoom rand = JailDoom(GetRandomClient(true)); // It's probably best to keep the second param true
	if (rand.index <= 0)
		ForceTeamWin(RED);

	int client = rand.index;
	if (GetClientTeam(client) == RED)
		rand.ForceTeamChange(BLU);

	rand.bIsDoom = true;

	if (rand.bIsDoom)
	{
		if (!IsPlayerAlive(rand.index))
			TF2_RespawnPlayer(rand.index);

		if (IsClientInGame(rand.index) && JailDoom(rand.index).bIsDoom)
			TF2_SetPlayerClass(rand.index, TFClass_Soldier);

		rand.iHealth = rand.iMaxHealth;
		SetEntityHealth(rand.index, rand.iHealth);

		TF2_RegeneratePlayer(rand.index); // IMPORTANT

		int HealthNumerator = Client_Total() * GetConVarInt(DoomHealthIncrease);

		iDoomHealth = DoomHealth.IntValue + HealthNumerator;

		int Multiplier = Client_Total() * GetConVarInt(ImpHealthIncrease);

		iImpHealth = ImpHealth.IntValue + Multiplier;

		SetVariantString("models/freak_fortress_2/doom/doomv2.mdl");
		AcceptEntityInput(rand.index, "SetCustomModel");
		SetEntProp(client, Prop_Send, "m_bCustomModelRotates", true);
		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", true);

		TF2_RemoveAllWearables(rand.index);

		TF2Items_GiveWeapon(rand.index, 513);

		SetClip(rand.index, TFWeaponSlot_Primary, 2000);

		TF2_AddCondition(rand.index, TFCond_CritCola);

		EmitSoundToClient(rand.index, "doom/theme.mp3");

		int ent = -1;
		while ((ent = FindEntityByClassname(ent, "item_healthkit_*")) != -1)
			SetEntProp(ent, Prop_Send, "m_iTeamNum", 2, 4);
	}
}

public void fwdOnRoundEnd(LastRequest lr, Event event)
{
	CHECK();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			bMusicPlayed[i] = false;
			StopSound(i, SNDCHAN_AUTO, "doom/theme.mp3");
			TF2Attrib_RemoveAll(i);
		}
	}
}

public void OnGameFrame()
{
	CHECK();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			if (JailDoom(i).bIsDoom)
				SetEntityHealth(i, iDoomHealth);
		}
	}
}

public void fwdOnHurtPlayer(LastRequest lr, const JBPlayer Victim, const JBPlayer Attacker, Event event)
{
	if (JailDoom(Victim.index).bIsDoom)
	{
		int damage = GetEventInt(event, "damageamount");
		iDoomHealth -= damage;

		if (iDoomHealth < 0)
		{
			iDoomHealth = 0;
		}
	}
}

public void fwdOnVariableReset(LastRequest lr, const JBPlayer Player)
{
	JailDoom base = JailDoom.Of(Player);

	base.iHealth = 0;
	base.iMaxHealth = 0;
	base.iDamage = 0;
	base.bIsDoom = false;

	if (base.bNeedsToGoBackToBlue && GetClientTeam(base.index) != BLU)
		ChangeClientTeam(base.index, BLU);
	base.bNeedsToGoBackToBlue = false;
}

public void LoadJBHooks()
{
	g_LR.AddHook(OnLRActivate, fwdOnRoundStart);
	g_LR.AddHook(OnLRActivatePlayer, fwdOnRoundStartPlayer);
	g_LR.AddHook(OnRoundEnd, fwdOnRoundEnd);
	g_LR.AddHook(OnPlayerHurt, fwdOnHurtPlayer);
	g_LR.AddHook(OnVariableReset, fwdOnVariableReset);

	JB_Hook(OnDownloads, fwdOnDownloads);
}

void TF2_RemoveAllWearables(int client)
{
	int i = -1;
	while ((i = FindEntityByClassname(i, "tf_wearable*")) != -1)
	{
		if (client != GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))continue;
		AcceptEntityInput(i, "Kill");
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

void SetClip(int client, int wepslot, int newAmmo)
{
	int weapon = GetPlayerWeaponSlot(client, wepslot);
	if (IsValidEntity(weapon))
	{
		int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
		SetEntData(weapon, iAmmoTable, newAmmo, 4, true);
	}
}
