#include <sourcemod>
#include <tf2>
#include <morecolors>

// Declarations
int Deaths[MAXPLAYERS] = {0,...};

public Plugin myinfo = 
{
	name = "[TF2] Respawn Players", 
	author = "Astrak, edited by blood.", 
	description = "Allow admins to respawn players", 
	version = "1.0", 
	url = "https://github.com/astrakk/"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_rp", Command_Respawn, ADMFLAG_SLAY, "Respawn a player");
	RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_SLAY, "Respawn a player");
	//RegAdminCmd("sm_rpmenu", Command_RespawnMenu, ADMFLAG_SLAY, "Respawn players killed by another player.");
	
	HookEvent("player_death", OnPlayerDeath);
	
	LoadTranslations("common.phrases");
	LoadTranslations("tf2jail_redux.phrases");
}

public Action OnPlayerDeath(Event event, const char[] name, bool bDontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (victim != attacker || IsClientInGame(attacker))
	{
		Deaths[attacker] = victim;
	}
}

/*public Action Command_RespawnMenu(int client, int args)
{
    Menu menu = new Menu(RespawnKill_MenuHandler, MENU_ACTIONS_ALL);
    menu.SetTitle("Respawn Kill Menu");

    for(int i = 0; i < MaxClients; i++) {
        char display[MAX_NAME_LENGTH * 2 + 20], info[5];
        Format(display, sizeof(display), "%N", Deaths[i]);
        IntToString(i, info, sizeof(info));
        menu.AddItem(info, display);
    }

    menu.ExitButton = true;
    menu.Display(client, 20);
}*/

public Action Command_Respawn(int client, int args)
{
	// Obtaining the client name
	char clientName[MAX_NAME_LENGTH];
	GetClientName(client, clientName, sizeof(clientName));
	
	// Usage information
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_rp <#userid|name>");
		return Plugin_Handled;
	}
	
	// Targetting stuff
	char arg1[MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
				arg1, 
				client, 
				target_list, 
				MAXPLAYERS, 
				COMMAND_FILTER_DEAD, 
				target_name, 
				sizeof(target_name), 
				tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	// Actually respawning the target(s)
	for (int i = 0; i < target_count; i++)
	{
		TF2_RespawnPlayer(target_list[i]);
	}
	
	// Showing different information based on command access (admins vs regular players)
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (CheckCommandAccess(i, "sm_rp", ADMFLAG_SLAY))
			{
				CPrintToChat(i, "%t %t", "Plugin Tag", "Respawn Player Admin", clientName, target_name);
			}
			else
			{
				CPrintToChat(i, "%t %t", "Plugin Tag", "Respawn Player", target_name);
			}
		}
	}
	
	return Plugin_Handled;
} 