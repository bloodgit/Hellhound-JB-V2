#include <sourcemod>
#include <morecolors>
#include <tf2jailredux>
#include <devzones>

#pragma semicolon 1
#pragma newdecls required
// #include "TF2JailRedux/stocks.inc"

#define PLUGIN_VERSION 		"2.0.0"

public Plugin myinfo = 
{
	name = "TF2Jail LR Module Dodgeball", 
	author = "blood", 
	description = "Add the dodgeball gamemode to Jailbreak", 
	version = PLUGIN_VERSION, 
	url = ""
};

JBGameMode
gamemode
;

LastRequest
g_LR // Me!
;

// Last Request Stuff

// GAMEMODE
#define FPS_LOGIC_RATE			20.0
#define FPS_LOGIC_INTERVAL		1.0 / FPS_LOGIC_RATE

int g_iRocketEntity;
int g_iRocketTarget;
int g_iRocketDeflections;
int g_iRocketCount;
float g_fRocketDirection[3];
float g_fRocketLastDeflectionTime;
Handle g_hLogicTimer; // Logic timer

// CONFIGS
float g_fRocketDamage;
float g_fRocketDamageIncrement;
float g_fRocketSpeed;
float g_fRocketSpeedIncrement;
float g_fRocketTurnRate;
float g_fRocketTurnRateIncrement;
float g_fRocketTargetWeight;
char g_sArenaDevZone[256];

float vecRocketAngle[3];
float vecRocketSpawn[3];
float vecRedSpawn[3];
float vecBlueSpawn[3];

ConVar g_cFlamethrowerBurstAmmo;

// Back to Plugin

#define CHECK() 				if( g_LR == null || g_LR.GetID() != gamemode.iLRType ) return

public void OnPluginStart()
{
	HookEvent("post_inventory_application", OnPlayerInventory, EventHookMode_Post);
	
	g_cFlamethrowerBurstAmmo = FindConVar("tf_flamethrower_burstammo");
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
	
	g_LR = LastRequest.CreateFromConfig("Dodgeball");
	
	if (g_LR == null) // If it's her first time, set the mood
	{
		g_LR = LastRequest.Create("Dodgeball");
		g_LR.SetDescription("Play a crazy round of dodgeball with rockets!");
		g_LR.SetAnnounceMessage("{default}{NAME}{orange} has selected {default}Dodgeball{orange} as their last request.");
		
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
		g_LR.SetParameterNum("RegenerateReds", 0); // Changing this does nothing
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
	{  }
}


public void fwdOnRoundStartPlayer(LastRequest lr, const JBPlayer Player)
{
	CHECK();
	
	g_cFlamethrowerBurstAmmo.IntValue = 0;
	CreateTimer(1.0, RoundStartPlayer); // Do this because JB shit.
}


public Action RoundStartPlayer(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (TF2_GetClientTeam(i) == TFTeam_Red)
			{
				TeleportEntity(i, vecRedSpawn, NULL_VECTOR, NULL_VECTOR); // Teleport to red position.
				PrintToServer("Reds teleported to %f", vecRedSpawn);
			}
			else if (TF2_GetClientTeam(i) == TFTeam_Blue)
			{
				TeleportEntity(i, vecBlueSpawn, NULL_VECTOR, NULL_VECTOR); // Teleport to red position.
				PrintToServer("Blues teleported to %f", vecBlueSpawn);
			}
			
			TF2_SetPlayerClass(i, TFClass_Pyro);
			TF2_RegeneratePlayer(i);
		}
	}
	
	g_hLogicTimer = CreateTimer(FPS_LOGIC_INTERVAL, OnDodgeBallGameFrame, _, TIMER_REPEAT);
	
	// Create rocket to work with gamemode.
	CreateRocket(2); // Create red rocket as default
}

public Action OnDodgeBallGameFrame(Handle hTimer, any Data)
{
	CHECK();
	
	if (g_iRocketCount == 0)
	{
		CreateRocket(2);
		PrintToServer("[DEBUG] OnDodgeballGameFrame() g_iRocketCount is %d", g_iRocketCount);
	}
	
	HomingRocketThink();
}

public void fwdOnRoundStart(LastRequest lr)
{
	CHECK();
	
	BuildLRConfig();
}

public void fwdOnRoundEnd(LastRequest lr, Event event)
{
	CHECK();
	
	if (g_hLogicTimer != INVALID_HANDLE)
	{
		KillTimer(g_hLogicTimer);
		g_hLogicTimer = INVALID_HANDLE;
	}
	
	g_cFlamethrowerBurstAmmo.IntValue = 25;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	if (g_LR.GetID() == gamemode.iLRType)
		iButtons &= ~IN_ATTACK;
	
	return Plugin_Continue;
}

public Action OnPlayerInventory(Handle hEvent, char[] strEventName, bool bDontBroadcast)
{
	CHECK();
	
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (!IsClientInGame(iClient))
		return;
	
	for (int iSlot = 1; iSlot < 5; iSlot++)
	{
		int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (iEntity != -1)
			RemoveEdict(iEntity);
	}
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


// STOCKS

public void CreateRocket(int iTeam)
{
	int iEntity = CreateEntityByName("tf_projectile_rocket");
	if (iEntity && IsValidEntity(iEntity))
	{
		// Fetch spawn point's location and angles.
		float fPosition[3];
		CopyVectors(vecRocketSpawn, fPosition);
		float fAngles[3];
		CopyVectors(vecRocketAngle, fAngles);
		float fDirection[3];
		GetAngleVectors(fAngles, fDirection, NULL_VECTOR, NULL_VECTOR);
		
		// Setup rocket entity.
		SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", 0);
		SetEntProp(iEntity, Prop_Send, "m_bCritical", 1);
		SetEntProp(iEntity, Prop_Send, "m_iTeamNum", iTeam, 1);
		SetEntProp(iEntity, Prop_Send, "m_iDeflected", 1);
		TeleportEntity(iEntity, fPosition, fAngles, view_as<float>( { 0.0, 0.0, 0.0 } ));
		
		float flVelocity[3];
		GetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", flVelocity);
		PrintToServer("[DEBUG] CreateRocket() Rocket velocity: %f, %f, %f", flVelocity[0], flVelocity[1], flVelocity[2]);
		PrintToServer("[DEBUG] g_fRocketSpeed is %f", g_fRocketSpeed);
		
		// Setup rocket structure with the newly created entity.
		int iTargetTeam = GetAnalogueTeam(iTeam);
		int iTarget = SelectTarget(iTargetTeam);
		float fModifier = CalculateModifier(0);
		
		g_iRocketEntity = EntIndexToEntRef(iEntity);
		g_iRocketTarget = EntIndexToEntRef(iTarget);
		
		g_iRocketDeflections = 0;
		g_fRocketLastDeflectionTime = GetGameTime();
		g_fRocketSpeed = CalculateRocketSpeed(fModifier);
		
		g_iRocketCount = 1;
		
		EmitSoundToClient(iTarget, "weapons/sentry_spot.wav");
		CopyVectors(fDirection, g_fRocketDirection);
		SetEntDataFloat(iEntity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, CalculateRocketDamage(fModifier), true);
		DispatchSpawn(iEntity);
		
		// Emit required sounds.
		//EmitRocketSound(RocketSound_Spawn, iClass, iEntity, iTarget, iFlags);
		//EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);
	}
}

int SelectTarget(int iTeam)
{
	int iTarget = -1;
	float fTargetWeight = 0.0;
	float fRocketPosition[3];
	float fRocketDirection[3];
	float fWeight;
	
	int iEntity = EntRefToEntIndex(g_iRocketEntity);
	
	if (iEntity != -1)
	{
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fRocketPosition);
		CopyVectors(g_fRocketDirection, fRocketDirection);
		fWeight = g_fRocketTargetWeight;
		
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			// If the client isn't connected, skip.
			if (!IsClientInGame(iClient) || !IsPlayerAlive(iClient))
				continue;
			
			if (iTeam && GetClientTeam(iClient) != iTeam)continue;
			
			// Determine if this client should be the target.
			float fNewWeight = GetURandomFloatRange(0.0, 100.0);
			
			float fClientPosition[3];
			GetClientEyePosition(iClient, fClientPosition);
			float fDirectionToClient[3];
			MakeVectorFromPoints(fRocketPosition, fClientPosition, fDirectionToClient);
			fNewWeight += GetVectorDotProduct(fRocketDirection, fDirectionToClient) * fWeight;
			
			float flVelocity[3];
			GetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", flVelocity);
			PrintToServer("[DEBUG] SelectTarget() Rocket velocity: %f, %f, %f", flVelocity[0], flVelocity[1], flVelocity[2]);
			
			if ((iTarget == -1) || fNewWeight >= fTargetWeight)
			{
				iTarget = iClient;
				fTargetWeight = fNewWeight;
			}
		}
	}
	
	PrintToServer("[DEBUG] FINAL fDirection is %f %f %f", fRocketDirection[0], fRocketDirection[1], fRocketDirection[2]);
	
	return iTarget;
}

void HomingRocketThink()
{
	// Retrieve the rocket's attributes.
	int iEntity = EntRefToEntIndex(g_iRocketEntity);
	
	if (iEntity == -1)
		return;
	int iTarget = EntRefToEntIndex(g_iRocketTarget);
	int iTeam = GetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1);
	int iTargetTeam = GetAnalogueTeam(iTeam);
	int iDeflectionCount = GetEntProp(iEntity, Prop_Send, "m_iDeflected") - 1;
	float fModifier = CalculateModifier(iDeflectionCount);
	
	// Check if the target is available
	if (!IsClientInGame(iTarget) || !IsPlayerAlive(iTarget))
	{
		iTarget = SelectTarget(iTargetTeam);
		
		if (!IsClientInGame(iTarget) || IsClientInGame(iTarget) && !IsPlayerAlive(iTarget))
			return;
		
		g_iRocketTarget = EntIndexToEntRef(iTarget);
	}
	// Has the rocket been deflected recently? If so, set new target.
	else if ((iDeflectionCount > g_iRocketDeflections))
	{
		// Calculate new direction from the player's forward
		int iClient = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
		if (IsClientInGame(iClient) && !IsPlayerAlive(iClient))
		{
			float fViewAngles[3];
			float fDirection[3];
			GetClientEyeAngles(iClient, fViewAngles);
			GetAngleVectors(fViewAngles, fDirection, NULL_VECTOR, NULL_VECTOR);
			CopyVectors(fDirection, g_fRocketDirection);
		}
		
		// Set new target & deflection count
		iTarget = SelectTarget(iTargetTeam);
		g_iRocketTarget = EntIndexToEntRef(iTarget);
		g_iRocketDeflections = iDeflectionCount;
		g_fRocketLastDeflectionTime = GetGameTime();
		g_fRocketSpeed = CalculateRocketSpeed(fModifier);
		//g_iRocketSpeed = RoundFloat(g_fRocketSpeed[ * 0.042614);
		
		SetEntDataFloat(iEntity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4, CalculateRocketDamage(fModifier), true);
		
		EmitSoundToClient(iTarget, "weapons/sentry_spot.wav");
		
		//EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);
		//Send out temp entity to target
		//SendTempEnt(iTarget, "superrare_greenenergy", iEntity, _, _, true);
	}
	else
	{
		// If the delay time since the last reflection has been elapsed, rotate towards the client.
		if ((GetGameTime() - g_fRocketLastDeflectionTime))
		{
			// Calculate turn rate and retrieve directions.
			float fTurnRate = CalculateRocketTurnRate(fModifier);
			float fDirectionToTarget[3]; CalculateDirectionToClient(iEntity, iTarget, fDirectionToTarget);
			float fFinalDirection[3];
			CopyVectors(g_fRocketDirection, fFinalDirection);
			
			// Smoothly change the orientation to the new one.
			LerpVectors(fFinalDirection, fDirectionToTarget, fFinalDirection, fTurnRate);
			CopyVectors(fFinalDirection, g_fRocketDirection);
		}
	}
	
	// Done
	ApplyRocketParameters();
}

void BuildLRConfig()
{
	//Thanks Scags for TF2Jail
	
	char cfg[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, cfg, sizeof(cfg), "configs/tf2jail/lastrequests/dodgeball.cfg");
	
	KeyValues kv = new KeyValues("TF2Jail_Dodgeball");
	char map[128];
	GetCurrentMap(map, sizeof(map));
	if (!kv.ImportFromFile(cfg))
	{
		LogError("[TF2Jail] Dodgeball config does not exist!, not enabling.");
		
		delete kv;
		return;
	}
	if (!kv.JumpToKey(map))
	{
		LogError("[TF2Jail] Map is not configured for Dodgeball LR, not enabling.");
		
		delete kv;
		return;
	}
	kv.GoBack();
	
	if (kv.JumpToKey("rocket_info"))
	{
		g_fRocketDamage = kv.GetFloat("damage");
		g_fRocketDamageIncrement = kv.GetFloat("damage_increment");
		g_fRocketSpeed = kv.GetFloat("speed");
		g_fRocketSpeedIncrement = kv.GetFloat("speed_increment");
		g_fRocketTurnRate = kv.GetFloat("turn_rate");
		g_fRocketTurnRateIncrement = kv.GetFloat("turn_rate_increment");
		g_fRocketTargetWeight = kv.GetFloat("target_weight");
	}
	kv.GoBack();
	
	if (kv.JumpToKey(map))
	{
		if (kv.JumpToKey("rocketspawn"))
		{
			vecRocketSpawn[0] = kv.GetFloat("Coordinate_X");
			vecRocketSpawn[1] = kv.GetFloat("Coordinate_Y");
			vecRocketSpawn[2] = kv.GetFloat("Coordinate_Z");
			vecRocketAngle[0] = kv.GetFloat("Angle_X");
			vecRocketAngle[1] = kv.GetFloat("Angle_Y");
			vecRocketAngle[2] = kv.GetFloat("Angle_Z");
		}
		kv.GoBack();
		
		if (kv.JumpToKey("red_spawn"))
		{
			vecRedSpawn[0] = kv.GetFloat("Coordinate_X");
			vecRedSpawn[1] = kv.GetFloat("Coordinate_Y");
			vecRedSpawn[2] = kv.GetFloat("Coordinate_Z");
		}
		kv.GoBack();
		
		if (kv.JumpToKey("blue_spawn"))
		{
			vecBlueSpawn[0] = kv.GetFloat("Coordinate_X");
			vecBlueSpawn[1] = kv.GetFloat("Coordinate_Y");
			vecBlueSpawn[2] = kv.GetFloat("Coordinate_Z");
		}
		kv.GoBack();
		
		kv.GetString("devzone_name", g_sArenaDevZone, sizeof(g_sArenaDevZone));
	}
	
	PrintToServer("[DEBUG] BuildLRConfig() g_fRocketSpeed is %f", g_fRocketSpeed);
	
	delete kv;
}

void CopyVectors(float fFrom[3], float fTo[3])
{
	fTo[0] = fFrom[0];
	fTo[1] = fFrom[1];
	fTo[2] = fFrom[2];
}

float CalculateModifier(int iDeflections)
{
	return view_as<float>(iDeflections);
}

float CalculateRocketDamage(float fModifier)
{
	return g_fRocketDamage + g_fRocketDamageIncrement * fModifier;
}

float CalculateRocketSpeed(float fModifier)
{
	return g_fRocketSpeed + g_fRocketSpeedIncrement * fModifier;
}

float CalculateRocketTurnRate(float fModifier)
{
	return g_fRocketTurnRate + g_fRocketTurnRateIncrement * fModifier;
}

void CalculateDirectionToClient(int iEntity, int iClient, float fOut[3])
{
	float fRocketPosition[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fRocketPosition);
	GetClientEyePosition(iClient, fOut);
	MakeVectorFromPoints(fRocketPosition, fOut, fOut);
	NormalizeVector(fOut, fOut);
}

void ApplyRocketParameters()
{
	int iEntity = EntRefToEntIndex(g_iRocketEntity);
	
	if (iEntity != -1)
	{
		float fAngles[3];
		GetVectorAngles(g_fRocketDirection, fAngles);
		float fVelocity[3];
		CopyVectors(g_fRocketDirection, fVelocity);
		ScaleVector(fVelocity, g_fRocketSpeed);
		SetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", fVelocity);
		SetEntPropVector(iEntity, Prop_Send, "m_angRotation", fAngles);
	}
}

float GetURandomFloatRange(float fMin, float fMax)
{
	return fMin + (GetURandomFloat() * (fMax - fMin));
}

int GetAnalogueTeam(int iTeam)
{
	if (iTeam == view_as<int>(TFTeam_Red))return view_as<int>(TFTeam_Blue);
	return view_as<int>(TFTeam_Red);
}

void LerpVectors(float fA[3], float fB[3], float fC[3], float t)
{
	if (t < 0.0)
	{
		t = 0.0;
	}
	if (t > 1.0)
	{
		t = 1.0;
	}
	
	fC[0] = fA[0] + (fB[0] - fA[0]) * t;
	fC[1] = fA[1] + (fB[1] - fA[1]) * t;
	fC[2] = fA[2] + (fB[2] - fA[2]) * t;
}

public void OnEntityDestroyed(int entity)
{
	CHECK();
	
	if (entity == EntRefToEntIndex(g_iRocketEntity))
	{
		g_iRocketCount = 0;
		PrintToServer("[DEBUG] OnEntityDestroyed() g_iRocketCount is %d", g_iRocketCount);
	}
}

public void Zone_OnClientLeave(int client, const char[] zone)
{
	CHECK();
	
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
		return;
	
	if (StrEqual(zone, g_sArenaDevZone))
	{
		float flEyeAngles[3];
        GetClientEyeAngles(client, flEyeAngles);
        float flStartPos[3];
        GetClientEyePosition(client, flStartPos);
        float flDirection[3];
        
        GetAngleVectors(flEyeAngles, flDirection, NULL_VECTOR, NULL_VECTOR);
        
        float flEndPos[3];
        
        SubtractVectors(flStartPos, flDirection, flEndPos);
        
        TeleportEntity(client, flEndPos, NULL_VECTOR, NULL_VECTOR);
	}
}