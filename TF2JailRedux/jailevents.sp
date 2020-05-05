int g_iLastGuard; bool g_bCanLastGuard; bool g_bLastGuardPrompted; bool g_bLastGuardMenuOpen; bool g_bLastGuardEnabled;
int g_iGlowRef[32] =  { INVALID_ENT_REFERENCE, ... };
#define BASE_COLOR 0xCCCCCC
#define GUARD_COLOR 0x0094FF
#define LG_COLOR 0x0026FF
#define LoopAlivePlayers(%1) for (int %1 = 1; %1 <= MaxClients; ++%1) if (IsClientInGame(%1) && IsPlayerAlive(%1))

int GetTeamPlayersAlive(TFTeam iTeam)
{
	int iCount;
	
	LoopAlivePlayers(i)
	{
		if (TF2_GetClientTeam(i) == iTeam)
		{
			iCount++;
		}
	}
	
	return iCount;
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	int client = GetClientOfUserId( event.GetInt("userid") );
	
	if (!IsClientValid(client))
		return Plugin_Continue;

	JailFighter player = JailFighter(client);
	int team = GetClientTeam(client);
	SetVariantString("");
	AcceptEntityInput(client, "SetCustomModel");

//	if (player.bIsFreeday)	// They changed teams, sucks for them
//		player.RemoveFreeday();
	if (player.bIsQueuedFreeday)
	{
		player.GiveFreeday();
		player.TeleportToPosition(FREEDAY);
	}
	
	RemoveGlow(client);
	
	if (GetClientOfUserId(g_iLastGuard) && g_bLastGuardEnabled && TF2_GetClientTeam(client) == TFTeam_Red)
		ApplyGlow(client);

	if (team == BLU)
	{
		if (AlreadyMuted(client) && cvarTF2Jail[DisableBlueMute].BoolValue && gamemode.iRoundState != StateRunning)
		{
			player.ForceTeamChange(RED);
			EmitSoundToClient(client, "vo/heavy_no03.mp3");
			CPrintToChat(client, "%t %t", "Plugin Tag", "Muted Can't Join");
		}
	}

	if (g_bTF2Attribs)
	{
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout:if (cvarTF2Jail[NoDoubleJump].BoolValue) TF2Attrib_SetByDefIndex(client, 49, 1.0);
			case TFClass_Pyro:if (cvarTF2Jail[NoAirblast].BoolValue) TF2Attrib_SetByDefIndex(client, 823, 1.0);
		}
	}

	if (gamemode.bIsWarday)
		player.TeleportToPosition(team);	// Enum value is the same as team value, so we can cheat it

	gamemode.ToggleMuting(player);
	ManageSpawn(player, event);
	SetPawnTimer(PrepPlayer, 0.2, player.userid);

	player.flHealTime = 0.0;

	return Plugin_Continue;
}

public Action OnPlayerDamaged(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	JailFighter victim = JailFighter.OfUserId( event.GetInt("userid") );
	JailFighter attacker = JailFighter.OfUserId( event.GetInt("attacker") );

	if (victim.index == attacker.index || attacker.index <= 0)
		return Plugin_Continue;

	ManageHurtPlayer(attacker, victim, event);

	return Plugin_Continue;
}

void ShowLastGuardMenu(int iClient)
{
	g_bLastGuardMenuOpen = true;
	g_bLastGuardPrompted = true;
	Menu hLGMenu = new Menu(Menu_LastGuardMenu);
	hLGMenu.SetTitle("Would you like to last guard?");
	hLGMenu.AddItem("1", "Yes, I would like to kill all Prisoners!");
	hLGMenu.AddItem("2", "No, I would like to remain peaceful.");
	hLGMenu.Display(iClient, MENU_TIME_FOREVER);
}

public void Frame_CheckLastGuard(bool bWardenTimer)
{
	int iCount = 0;
	int iBlues = -1;
	for (int i = 1; i <= MaxClients; i++)if (IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
	{
		iCount++;
		iBlues = i;
	}
	
	if (!gamemode.bIsLRInUse)
	{
		if (iCount == 1 && iBlues != -1 && !GetClientOfUserId(g_iLastGuard) && gamemode.iRoundState == StateRunning && g_bCanLastGuard)
		{
			if (!bWardenTimer && !g_bLastGuardPrompted)
			{
				CPrintToChatAll("%t %t", "Plugin Tag", "Last Guard Question");
				PrintCenterTextAll("%t", "Last Guard Question");
				ShowLastGuardMenu(iBlues);
			}
			else
			{
				if (g_bLastGuardMenuOpen)
					CancelClientMenu(iBlues);
				
				g_bLastGuardPrompted = true;
				g_iLastGuard = GetClientUserId(iBlues);
				//RefreshStatus(iBlue);
				
				for (int i = 1; i <= MaxClients; i++)if (IsClientInGame(i))
				{
					JailFighter player = JailFighter(i);
					
					if (TF2_GetClientTeam(i) == TFTeam_Blue && IsPlayerAlive(i))
						player.WardenUnset();
					
					if (TF2_GetClientTeam(i) == TFTeam_Red && IsPlayerAlive(i))
						ApplyGlow(i);
					
					if (player.bIsFreeday)
						player.RemoveFreeday();
				}
			}
		}
	}
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue || gamemode.iRoundState == StateDisabled)
		return Plugin_Continue;

	JailFighter victim = JailFighter.OfUserId( event.GetInt("userid") );	
	JailFighter attacker = JailFighter.OfUserId( event.GetInt("attacker") );
	
	char victimstring[64]; //Riotline had a good idea on this, compared to me atleast. (I just execute it better ;) )
	char attackerstring[64];
	
	if (cvarTF2Jail[KillFeed])
	{
		if (attacker.index <= 0)
			return Plugin_Handled;
		
		if (IsClientInGame(victim.index) && TF2_GetClientTeam(victim.index) == TFTeam_Blue && victim.bIsWarden)
			victimstring = "{blue}(WARDEN) ";
		else if (IsClientInGame(victim.index) && TF2_GetClientTeam(victim.index) == TFTeam_Blue && TF2_GetClientTeam(victim.index) == TFTeam_Blue && !victim.bIsWarden)
			victimstring = "{lightblue}(GUARD) ";
		else if (IsClientInGame(victim.index) && TF2_GetClientTeam(victim.index) == TFTeam_Red && victim.bIsRebel)
			victimstring = "{goldenrod}(REBEL) ";
		else if (IsClientInGame(victim.index) && TF2_GetClientTeam(victim.index) == TFTeam_Red && !victim.bIsRebel)
			victimstring = "{grey}(PRISONER) ";
		else if (IsClientInGame(victim.index) && TF2_GetClientTeam(victim.index) == TFTeam_Red && victim.bIsFreeday)
			victimstring = "{gold}(FREEDAY) ";
		
		if (IsClientInGame(attacker.index) && IsPlayerAlive(attacker.index) && TF2_GetClientTeam(attacker.index) == TFTeam_Blue && attacker.bIsWarden)
			attackerstring = "{blue}(WARDEN) ";
		else if (IsClientInGame(attacker.index) && IsPlayerAlive(attacker.index) && TF2_GetClientTeam(attacker.index) == TFTeam_Blue && !attacker.bIsWarden)
			attackerstring = "{lightblue}(GUARD) ";
		else if (IsClientInGame(attacker.index) && IsPlayerAlive(attacker.index) && TF2_GetClientTeam(attacker.index) == TFTeam_Red && attacker.bIsRebel)
			attackerstring = "{goldenrod}(REBEL) ";
		else if (IsClientInGame(attacker.index) && IsPlayerAlive(attacker.index) && TF2_GetClientTeam(attacker.index) == TFTeam_Red && !attacker.bIsRebel)
			attackerstring = "{grey}(PRISONER) ";
		else if (IsClientInGame(attacker.index) && IsPlayerAlive(attacker.index) && TF2_GetClientTeam(attacker.index) == TFTeam_Red && attacker.bIsFreeday)
			attackerstring = "{gold}(FREEDAY) ";
		
		if (victim.index != attacker.index)
		{
			for (int i = 1; i <= MaxClients; i++) if (IsClientInGame(i))
			{
				if (CheckCommandAccess(i, "", ADMFLAG_GENERIC, true)) 
					CPrintToChat(i, "{orange}Hellhound {white}| %s{limegreen}%N {white}killed %s{limegreen}%N", attackerstring, attacker, victimstring, victim);
				else
					CPrintToChat(i, "{orange}Hellhound {white}| %s{white}killed %s", attackerstring, victimstring);
			}
		}
			
	}

	if (g_bTF2Attribs)
		TF2Attrib_RemoveAll(victim.index);
		
	if (TF2_GetClientTeam(victim.index) == TFTeam_Blue)
		RequestFrame(Frame_CheckLastGuard);

	if (IsClientValid(attacker.index))
		if (!gamemode.bDisableKillSpree)
			FreeKillSystem(attacker);

	SetPawnTimer(CheckLivingPlayers, 0.1);

	if (victim.bIsFreeday)
		victim.RemoveFreeday();
	else if (victim.bIsRebel)
		victim.ClearRebel();

	else if (victim.bIsWarden)
	{
		victim.WardenUnset();

		if (gamemode.iRoundState == StateRunning)
			if (Call_OnWardenKilled(victim, attacker, event) == Plugin_Continue || !gamemode.bSilentWardenKills)
				PrintCenterTextAll("%t", "Warden Killed");
	}

	if (victim.iCustom)
		victim.iCustom = 0;

	ManagePlayerDeath(attacker, victim, event);
	gamemode.ToggleMuting(victim, true);	// IsPlayerAlive more like returns true on player_death >:c

	return Plugin_Continue;
}

public int Menu_LastGuardMenu(Menu hLGMenu, MenuAction iAction, int iClient, int iParam2)
{
	switch (iAction)
	{
		case MenuAction_Select:
		{
			if (iClient < 1 || iClient > MaxClients || !IsClientInGame(iClient) || !IsPlayerAlive(iClient) || gamemode.iRoundState != StateRunning)
				return;
			
			char sInfo[32]; char sDisplay[MAX_NAME_LENGTH];
			hLGMenu.GetItem(iParam2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));
			
			if (iParam2 == 0)
			{	
				JailFighter player = JailFighter(iClient);
				
				CPrintToChatAll("{orange}Hellbound{white}| {orange}%N{white} has chosen to {orange}Last Guard{white}!", iClient);
				PrintCenterTextAll("%N has chosen to Last Guard!", iClient);
				gamemode.bIsWardenLocked = true;
				g_iLastGuard = GetClientUserId(iClient);
				g_bLastGuardEnabled = true;
				
				if (GetClientOfUserId(player.bIsWarden))
					player.WardenUnset();
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i))
					{
						if (TF2_GetClientTeam(i) == TFTeam_Red && IsPlayerAlive(i))
							ApplyGlow(i);
						
						if (player.bIsFreeday)
							player.RemoveFreeday();
						
						float time = float(gamemode.iTimeLeft);
						
						ClearSyncHud(i, g_hWardenHud);
						SetHudTextParams(-1.0, 0.2, time, 0, 105, 255, 255, 2, 0.0, 0.1, 0.1);
						ShowSyncHudText(i, g_hWardenHud, "Last Guard Active!");
					}
				}
			}
			else if (iParam2 == 1)
			{
				CPrintToChatAll("{orange}Hellhound {white}| {orange}%N{white} has chosen to not activate {orange}Last Guard{white}.", iClient);
				PrintCenterTextAll("%N has chosen to stay peaceful.", iClient);
				g_bCanLastGuard = false;
				g_bLastGuardEnabled = false;
			}
		}
		
		case MenuAction_End:
		{
			g_bLastGuardMenuOpen = false;
			CloseHandle(hLGMenu);
		}
	}
}

public Action OnPreRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
	{
#if defined _SteamWorks_Included
		if (g_bSteam)
			SteamWorks_SetGameDescription("Team Fortress");
#endif
		return Plugin_Continue;
	}

	g_iLastGuard = 0;
	JailFighter player;
	int i;
	if (gamemode.bIsMapCompatible)
	{
		if (strCellOpener[0] != '\0')
		{
			i = FindEntity(strCellOpener, "func_button");
			if (i != -1)
				SetEntProp(i, Prop_Data, "m_bLocked", 1, 1);
			else LogError("***TF2JB ERROR*** Entity name not found for Cell Door Opener! Please verify integrity of the config and the map.");
		}

		if (strFFButton[0] != '\0')
		{
			i = FindEntity(strFFButton, "func_button");
			if (i != -1)
				SetEntProp(i, Prop_Data, "m_bLocked", 1, 1);
		}

		if (strCellNames[0] != '\0')
		{
			int ent;
			char entname[32];
			for (i = 0; i < sizeof(strDoorsList); i++)
			{
				ent = -1;
				while ((ent = FindEntityByClassnameSafe(ent, strDoorsList[i])) != -1)
				{
					GetEntPropString(ent, Prop_Data, "m_iName", entname, sizeof(entname));
					if (StrEqual(entname, strCellNames, false))	// Laziness, hook first cell door opening so open door timer catches and doesn't open on its own
						HookSingleEntityOutput(ent, "OnOpen", OnFirstCellOpening, true);
				}
			}
		}
	}

	for (i = MaxClients; i; --i)
	{
		if (!IsClientInGame(i))
			continue;

		player = JailFighter(i);
//		if (player.bIsQueuedFreeday && IsPlayerAlive(i))
//		{
//			player.GiveFreeday();
//			player.TeleportToPosition(FREEDAY);
//		}

		ResetVariables(player, false);

		if (strBackgroundSong[0] != '\0')
			StopSound(i, SNDCHAN_AUTO, strBackgroundSong);
	}

	// gamemode.iLRType = -1;
	gamemode.DoorHandler(CLOSE);
	gamemode.bDisableCriticals = false;
	gamemode.bMedicDisabled = false;
	gamemode.iRoundState = StateStarting;

	return Plugin_Continue;
}

public Action OnArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	g_bCanLastGuard = true;
	g_bLastGuardPrompted = false;

	gamemode.bCellsOpened = false;
	gamemode.bWardenExists = false;
	gamemode.bIsWardenLocked = false;
	gamemode.bFirstDoorOpening = false;
	gamemode.iLivingMuteType = cvarTF2Jail[LivingMuteType].IntValue;
	gamemode.iMuteType = cvarTF2Jail[MuteType].IntValue;

	int i;
	JailFighter player;

	CreateTimer(1.0, Timer_Round, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	SetPawnTimer(CheckLivingPlayers, 0.1);

	if (cvarTF2Jail[Balance].BoolValue)
		gamemode.AutobalanceTeams();

	if (gamemode.b1stRoundFreeday)
	{
		gamemode.DoorHandler(OPEN);

		char firstday[32];
		FormatEx(firstday, sizeof(firstday), "%t", "First Day Freeday");
		SetTextNode(hTextNodes[0], firstday, EnumTNPS[0].fCoord_X, EnumTNPS[0].fCoord_Y, EnumTNPS[0].fHoldTime, EnumTNPS[0].iRed, EnumTNPS[0].iGreen, EnumTNPS[0].iBlue, EnumTNPS[0].iAlpha, EnumTNPS[0].iEffect, EnumTNPS[0].fFXTime, EnumTNPS[0].fFadeIn, EnumTNPS[0].fFadeOut);
		PrintCenterTextAll(firstday);
		
		gamemode.iTimeLeft = cvarTF2Jail[RoundTime_Freeday].IntValue;
		gamemode.iLRType = -1;
		return Plugin_Continue;
	}

	bool warday;
	float time;
	int wep;

	gamemode.iTimeLeft = cvarTF2Jail[RoundTime].IntValue;
	gamemode.iLRType = gamemode.iLRPresetType;
	gamemode.iRoundState = StateRunning;
	gamemode.bIsLRRound = gamemode.iLRType > -1;

	ManageRoundStart();	// NOTE THE ORDER OF EXECUTION; *RoundStart BEFORE *RoundStartPlayer
	ManageHUDText();

	warday = gamemode.bIsWarday;

	for (i = MaxClients; i; --i)
	{
		if (!IsClientInGame(i))
			continue;
		if (!IsPlayerAlive(i))
			continue;

		player = JailFighter(i);
		ManageRoundStartPlayer(player);

		if (warday)
		{
			player.TeleportToPosition(GetClientTeam(i));

			wep = GetPlayerWeaponSlot(i, 2);
			if (wep > MaxClients && IsValidEntity(wep) && GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex") == 589 && GetClientTeam(i) == BLU)	// Eureka Effect
			{
				TF2_RemoveWeaponSlot(i, 2);
				player.SpawnWeapon("tf_weapon_wrench", 7, 1, 0, "");
			}

			wep = GetPlayerWeaponSlot(i, 4);
			if (wep > MaxClients && IsValidEntity(wep) && GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex") == 60)	// Cloak and Dagger
			{
				TF2_RemoveWeaponSlot(i, 4);
				player.SpawnWeapon("tf_weapon_invis", 30, 1, 0, "");
			}
		}
		gamemode.ToggleMuting(player);
	}

	gamemode.iLRPresetType = -1;

	if (gamemode.bIsMapCompatible)
	{
		time = cvarTF2Jail[DoorOpenTimer].FloatValue;
		if (time != 0.0)
			SetPawnTimer(Open_Doors, time, gamemode.iRoundCount);
	}

	time = cvarTF2Jail[WardenDelay].FloatValue;
	if (time != 0.0)
	{
		if (time == -1.0)
			gamemode.FindRandomWarden();
		else
		{
			gamemode.bIsWardenLocked = true;
			SetPawnTimer(EnableWarden, time, gamemode.iRoundCount);
			RequestFrame(Frame_CheckLastGuard, true);
		}
	}
	
	if (GetTeamPlayersAlive(TFTeam_Blue) >> 1)
		RequestFrame(Frame_CheckLastGuard);

	gamemode.flMusicTime = GetGameTime() + 1.4;
	return Plugin_Continue;
}

public Action OnRoundEnded(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	g_iLastGuard = 0;
	JailFighter player;
	int i, x;
	bool attrib = g_bTF2Attribs;

	for (i = MaxClients; i; --i)
	{
		if (!IsClientInGame(i))
			continue;

		if (attrib)
			TF2Attrib_RemoveAll(i);

		player = JailFighter(i);

		if (player.bIsFreeday)
			player.RemoveFreeday();
		else if (player.bIsRebel)
			player.ClearRebel();

		for (x = 0; x < sizeof(hTextNodes); x++)
			if (hTextNodes[x] != null)
				ClearSyncHud(i, hTextNodes[x]);

		if (GetClientMenu(i) != MenuSource_None)
			CancelClientMenu(i, true);

		if (strBackgroundSong[0] != '\0')
			StopSound(i, SNDCHAN_AUTO, strBackgroundSong);

		ManageRoundEnd(player, event);
		player.UnmutePlayer();
		g_bLastGuardEnabled = false;
	}
	ManageOnRoundEnd(event); // Making 1 with and without clients so things dont fire once for every client in the loop

	hEngineConVars[0].SetBool(false);
	hEngineConVars[1].SetBool(false);

	gamemode.b1stRoundFreeday = false;
	gamemode.bIsLRInUse = false;
	gamemode.bDisableCriticals = false;
	gamemode.bIsWarday = false;
	gamemode.bOneGuardLeft = false;
	gamemode.bOnePrisonerLeft = false;
	gamemode.bAllowBuilding = false;
	gamemode.bAllowWeapons = false;
	gamemode.bSilentWardenKills = false;
	gamemode.bDisableMuting = false;
	gamemode.bDisableKillSpree = false;
	gamemode.bIgnoreRebels = false;
	gamemode.bIsLRRound = false;
	gamemode.iLRType = -1;
	gamemode.iTimeLeft = 0; // Had to set it to 0 here because it kept glitching out... odd
	gamemode.iRoundState = StateEnding;
	gamemode.iRoundCount++;

	return Plugin_Continue;
}


public Action OnRegeneration(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	JailFighter player = JailFighter.OfUserId( event.GetInt("userid") );

	if (IsClientValid(player.index) 
	&& gamemode.iRoundState != StateEnding 
	&& !player.bSkipPrep
	&& !gamemode.bAllowWeapons)
		SetPawnTimer(PrepPlayer, 0.2, player.userid);

	player.bSkipPrep = false;

	return Plugin_Continue;
}

public Action OnChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	JailFighter player = JailFighter.OfUserId( event.GetInt("userid") );

	if (IsClientValid(player.index))
		SetPawnTimer(PrepPlayer, 0.1, player.userid);

	return Plugin_Continue;
}

public void OnChangeTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return;

	if (event.GetBool("disconnect"))
		return;

	gamemode.ToggleMuting(JailFighter.OfUserId( event.GetInt("userid") ), _, event.GetInt("team"));
}

public void OnHookedEvent(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return;

	JailFighter.OfUserId( event.GetInt("userid") ).bInJump = StrEqual(name, "rocket_jump", false) || StrEqual(name, "sticky_jump", false);
}

/** Events that aren't used in core (but are used in VSH plugin module) :^) **/
public Action ObjectDeflected(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	JailFighter airblaster = JailFighter.OfUserId( event.GetInt("userid") );
	JailFighter airblasted = JailFighter.OfUserId( event.GetInt("ownerid") );
	int weaponid = GetEventInt(event, "weaponid");
	if (weaponid)
		return Plugin_Continue;
	ManageOnAirblast(airblaster, airblasted, event);
	return Plugin_Continue;
}

public Action ObjectDestroyed(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	JailFighter destroyer = JailFighter.OfUserId( event.GetInt("attacker") );
	int building = event.GetInt("index");
	int objecttype = event.GetInt("objecttype");
	ManageBuildingDestroyed(destroyer, building, objecttype, event);
	return Plugin_Continue;
}

public Action PlayerJarated(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;

	JailFighter jarateer = JailFighter.OfUserId( event.GetInt("thrower_entindex") );
	JailFighter jarateed = JailFighter.OfUserId( event.GetInt("victim_entindex") );
	ManageOnPlayerJarated(jarateer, jarateed, event);
	return Plugin_Continue;
}

public Action UberDeployed(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled.BoolValue)
		return Plugin_Continue;
	
	JailFighter medic = JailFighter.OfUserId( event.GetInt("userid") );
	JailFighter patient = JailFighter.OfUserId( event.GetInt("targetid") );
	if (!medic || !patient)
		return Plugin_Continue;

	ManageUberDeployed(patient, medic, event);
	return Plugin_Continue;
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
