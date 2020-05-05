#include <tf2_stocks>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo =
{
	name = "[TF2] !givemeall plugin",
	author = "blood",
	description = "Provides !givemeall and !giveitems commands that rewards clients with achievements.",
	version = "1.0",
	url = "http://sourcemod.net"
};

public OnPluginStart() 
{
	RegConsoleCmd("sm_givemeall", Command_GiveMeAll, "Unlocks all achievements for you.");
	RegConsoleCmd("sm_giveitems", Command_GiveItems, "Unlocks item achievements for you.");
}

public Action:Command_GiveItems(client, args)
{
	UnlockNamed(client, 1036, "scout1");// Scout
	UnlockNamed(client, 1037, "scout2");
	UnlockNamed(client, 1038, "scout3");
	 
	UnlockNamed(client, 1136, "Sniper Milestone 1");
	UnlockNamed(client, 1137, "Sniper Milestone 2");
	UnlockNamed(client, 1138, "Sniper Milestone 3");
	 
	UnlockNamed(client, 1236, "Soldier Milestone 1");
	UnlockNamed(client, 1237, "Soldier Milestone 2");
	UnlockNamed(client, 1238, "Soldier Milestone 3");
	 
	UnlockNamed(client, 1336, "Demoman Milestone 1");
	UnlockNamed(client, 1337, "Demoman Milestone 2");
	UnlockNamed(client, 1338, "Demoman Milestone 3");
	 
	UnlockNamed(client, 1437, "Milestone 1");
	UnlockNamed(client, 1438, "Milestone 2");
	UnlockNamed(client, 1439, "Milestone 3");
	 
	UnlockNamed(client, 1537, "Milestone 1"); // Heavy
	UnlockNamed(client, 1538, "Milestone 2");
	UnlockNamed(client, 1539, "Milestone 3");
	 
	UnlockNamed(client, 1637, "Milestone 1"); // Pyro
	UnlockNamed(client, 1638, "Milestone 2");
	UnlockNamed(client, 1639, "Milestone 3");
	 
	UnlockNamed(client, 1735, "Spy Milestone 1"); // Spy
	UnlockNamed(client, 1736, "Spy Milestone 2");
	UnlockNamed(client, 1737, "Spy Milestone 3");
	 
	UnlockNamed(client, 1801, "Engineer Milestone 1"); // Engy
	UnlockNamed(client, 1802, "Engineer Milestone 2");
	UnlockNamed(client, 1803, "Engineer Milestone 3");
	 
	UnlockNamed(client, 2004, "Star of My Own Show");
	UnlockNamed(client, 2006, "Local Cinema Star");
	 
	UnlockNamed(client, 2212, "Foundry Milestone");
	
	UnlockNamed(client, 2412, "Doomsday Milestone");
	
	UnlockNamed(client, 156, "Fresh Pair Of Eyes");
	 
	return Plugin_Handled;
}

public Action:Command_GiveMeAll(client, args)
{	
	if(!IsPlayerAlive(client))
	{
		PrintToChat(client, "[SM] You must be alive to use !givemeall command");
		return Plugin_Handled;
	}
	
	TF2_RespawnPlayer(client);
	
	// General
	for(int iGeneral = 127, iGeneral <= 156, iGeneral++)
		Unlock(client, iGeneral);

	for(int iScout = 1001, iScout <= 1038, iScout++)
		Unlock(client, iScout);

	for(int iSoldier = 1201, iSoldier <= 1238, iSoldier++)
		Unlock(client, iSoldier);

	for(int iSniper = 1101, iSniper <= 1138, iSniper++)
		Unlock(client, iSniper);

	for(int iDemo = 1301, iDemo<= 1338, iDemo++)
		Unlock(client, iDemo);

	for(int iMedic = 1401, iMedic <= 1439, iMedic++)
		Unlock(client, iMedic);

	for(int iHeavy = 1501, iHeavy <= 1539, iHeavy++)
		Unlock(client, iHeavy);

	for(int iPyro = 1601, iPyro <= 1639, iPyro++)
		Unlock(client, iPyro);

	for(int iSpy = 1701, iSpy <= 1737, iSpy++)
		Unlock(client, iSpy);

	for(int iEngineer = 1801, iEngineer <= 1838, iEngineer++)
		Unlock(client, iEngineer);
	
	for(int iHalloween = 1901, iHalloween <= 1921, iHalloween++)
		Unlock(client, iHalloween);

	for(int iReplay = 2001, iReplay <= 2008, iReplay++)
		Unlock(client, iReplay);

	for(int iChristmas = 2101, iChristmas <= 2101, iChristmas++)
		Unlock(client, iChristmas);
	
	for(int iFoundry = 2201, iFoundry <= 2212, iFoundry++)
		Unlock(client, iFoundry);

	for(int iMvM = 2301, iMvM <= 2335, iMvM++)
		Unlock(client, iMvM);

	for(int iDoomsday = 2401, iDoomsday <= 2412, Doomsday++)
		Unlock(client, iDoomsday);

	return Plugin_Handled;
}

UnlockNamed(client, id, String:achname[]) {
	new Handle:bf = StartMessageOne("AchievementEvent", client, USERMSG_RELIABLE);
	BfWriteShort(bf, id);
	EndMessage();
}

Unlock(client, id) {
	new Handle:bf = StartMessageOne("AchievementEvent", client, USERMSG_RELIABLE);
	BfWriteShort(bf, id);
	EndMessage();
}