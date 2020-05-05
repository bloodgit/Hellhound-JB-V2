#include <sourcemod>
#include <morecolors>
#include <tf2jailredux>
#include <tf2attributes>
#include <tf2items_giveweapon>

#pragma semicolon 1
#pragma newdecls required
#include "TF2JailRedux/stocks.inc"

#define PLUGIN_VERSION 		"1.0.0"

int g_iGlowRef[32] =  { INVALID_ENT_REFERENCE, ... };

public Plugin myinfo = 
{
	name = "TF2Jail LR Module DOOM", 
	author = "blood", 
	description = "DOOM LR for TF2Jailbreak", 
	version = PLUGIN_VERSION, 
	url = ""
};

#define RED 				2
#define BLU 				3

#define NOTDOOM 				( gamemode.iLRType != TF2JailRedux_LRIndex() )

ConVar PickCount;

enum
{
	DisableMuting, 
	Version
};

ConVar hTeamBansCVar;
ConVar DoomHealth;
ConVar DoomHealthIncrease;
ConVar ImpHealth;
ConVar ImpHealthIncrease;

int
iTeamBansCVar, 
iDoomHealth, 
iImpHealth;

bool bMusicPlayed[MAXPLAYERS + 1];

JBGameMode
gamemode
;

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

public void OnPluginStart()
{
	PickCount = CreateConVar("sm_jbdoom_pickcount", "5", "Maximum number of times this LR can be picked in a single map. 0 for no limit", FCVAR_NOTIFY, true, 0.0);
	
	DoomHealth = CreateConVar("sm_jbdoom_doomguy_hpbase", "250", "Base HP for Doomguy", FCVAR_NONE, true, 1.0, true, 10000.0);
	DoomHealthIncrease = CreateConVar("sm_jbdoom_doomguy_hpincrease", "10", "Base HP increase per player for Doomguy.", FCVAR_NONE, true, 1.0, true, 10000.0);
	ImpHealth = CreateConVar("sm_jbdoom_imp_hpbase", "350", "Base HP for Imps", FCVAR_NONE, true, 1.0, true, 10000.0);
	ImpHealthIncrease = CreateConVar("sm_jbdoom_imp_hpincrease", "50", "Base HP increase for Imps", FCVAR_NONE, true, 1.0, true, 10000.0);
	
	PrintToServer("OnPluginStart()");
	PrintToServer("IMP HP BASE %d", ImpHealth.IntValue);
	PrintToServer("DOOM HP BASE %d", DoomHealth.IntValue);
	
	AutoExecConfig(true, "LRModuleDOOM");
}

public void OnPluginEnd()
{
	TF2JailRedux_UnRegisterPlugin();
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
		
		JB_Hook(OnDownloads, fwdOnDownloads);
		JB_Hook(OnRoundStart, fwdOnRoundStart);
		JB_Hook(OnRoundStartPlayer, fwdOnRoundStartPlayer);
		JB_Hook(OnRoundEnd, fwdOnRoundEnd);
		//JB_Hook(OnRoundEndPlayer, 		fwdOnRoundEndPlayer);
		//JB_Hook(OnPreThink, 				fwdOnPreThink);
		//JB_Hook(OnRedThink, 				fwdOnRedThink);
		//JB_Hook(OnBlueThink, 				fwdOnBlueThink);
		//JB_Hook(OnWardenGet, 				fwdOnWardenGet);
		//JB_Hook(OnClientTouch, 			fwdOnClientTouch);
		//JB_Hook(OnWardenThink, 			fwdOnWardenThink);
		//JB_Hook(OnPlayerSpawned, 			fwdOnPlayerSpawned);
		//JB_Hook(OnPlayerDied, 			fwdOnPlayerDied);
		//JB_Hook(OnWardenKilled, 			fwdOnWardenKilled);
		//JB_Hook(OnTimeLeft, 				fwdOnTimeLeft);
		//JB_Hook(OnPlayerPrepped, 			fwdOnPlayerPrepped);
		//JB_Hook(OnPlayerPreppedPre, 		fwdOnPlayerPreppedPre);
		JB_Hook(OnHurtPlayer, fwdOnHurtPlayer);
		//JB_Hook(OnTakeDamage, 			fwdOnTakeDamage);
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
		
		PrintToServer("OnLibraryAdded()");
		PrintToServer("IMP HP BASE %d", ImpHealth.IntValue);
		PrintToServer("DOOM HP BASE %d", DoomHealth.IntValue);
	}
}

public void InitSubPlugin()
{
	TF2JailRedux_RegisterPlugin();
	gamemode = new JBGameMode();
}

public void OnLibraryRemoved(const char[] name)
{
	if (!strcmp(name, "TF2Jail_Redux", false))
	{  }
}

// FORWARDS

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

public void fwdOnRoundStartPlayer(const JBPlayer Player)
{
	if (NOTDOOM)
		return;
	
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

public void fwdOnHurtPlayer(const JBPlayer Victim, const JBPlayer Attacker, Event event)
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

public void OnGameFrame()
{
	if (NOTDOOM)
		return;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			if (JailDoom(i).bIsDoom)
				SetEntityHealth(i, iDoomHealth);
		}
	}
}

public void fwdOnRoundStart()
{
	if (NOTDOOM)
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
	
	if (hTeamBansCVar && !hTeamBansCVar.BoolValue)
	{
		hTeamBansCVar.SetBool(true);
		iTeamBansCVar = 1;
	}
	
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

public void fwdOnRoundEnd(Event event)
{
	if (NOTDOOM)
		return;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			bMusicPlayed[i] = false;
			StopSound(i, SNDCHAN_AUTO, "doom/theme.mp3");
			TF2Attrib_RemoveAll(i);
		}
	}
	
	if (hTeamBansCVar && iTeamBansCVar)
	{
		hTeamBansCVar.SetBool(false);
		iTeamBansCVar = 0;
	}
	
	gamemode.DoorHandler(OPEN);
}

public void fwdOnVariableReset(const JBPlayer Player)
{
	JailDoom base = JailDoom.Of(Player);
	
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
	base.bIsDoom = false;
	base.flRAGE = 0.0;
	base.flWeighDown = 0.0;
	base.flGlowtime = 0.0;
	base.flCharge = 0.0;
	base.flKillSpree = 0.0;
	
	if (base.bNeedsToGoBackToBlue && GetClientTeam(base.index) != BLU)
		ChangeClientTeam(base.index, BLU);
	base.bNeedsToGoBackToBlue = false;
}

public void fwdOnHudShow(char strHud[128])
{
	if (NOTDOOM)
		return;
	
	strcopy(strHud, 128, "DOOM");
}
public Action fwdOnLRPicked(const JBPlayer Player, const int selection, ArrayList arrLRS)
{
	if (selection == TF2JailRedux_LRIndex())
		CPrintToChatAll("{orange}Hellhound {white}| %N has chosen {orange}DOOM {white}as their last request.", Player.index);
	return Plugin_Continue;
}

public void fwdOnPanelAdd(const int index, char name[64])
{
	if (index != TF2JailRedux_LRIndex())
		return;
	
	strcopy(name, sizeof(name), "DOOM");
}

public void fwdOnMenuAdd(const int index, int &max, char strName[64])
{
	if (index != TF2JailRedux_LRIndex())
		return;
	
	max = PickCount.IntValue;
	strcopy(strName, sizeof(strName), "DOOM");
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