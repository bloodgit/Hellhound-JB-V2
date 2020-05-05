#include <sdktools>
#include <sdkhooks>
#include <tf2items>
#include <tf2wearables>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>

#define PLUGIN_VERSION		"0.1"

public Plugin:myinfo = {
	name			= "[TF2] Be The Zombie",
	author			= "Master Xykon",
	description	= "Become a zombie player.",
	version		= PLUGIN_VERSION,
	url				= "http://steamcommunity.com/id/xycon"
};

new ClientWearable[MAXPLAYERS+1] = -1
new bool:enabled[MAXPLAYERS+1] = false

public OnPluginStart()
{
	CreateConVar("sm_zombie_version", PLUGIN_VERSION, "[TF2] Be The Zombie version", FCVAR_NOTIFY | FCVAR_PLUGIN | FCVAR_SPONLY);
	HookEvent("post_inventory_application", Event_Inventory, EventHookMode_Post);
	RegConsoleCmd("sm_zombie", BeZombie)
}

public OnClientDisconnect(client)
{
	enabled[client] = false
}

public Action:Event_Inventory(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new index = GetIndexForClass(client)
	
	if(enabled[client] == true)
	{
		TF2Attrib_SetByName(client, "player skin override", 1.0)
		TF2Attrib_SetByName(client, "zombiezombiezombiezombie", 1.0)
		GiveWearable(client, index)
	}
	else if(enabled[client] == false)
	{
		TF2Attrib_SetByName(client, "player skin override", 0.0)
		TF2Attrib_SetByName(client, "zombiezombiezombiezombie", 0.0)
		GiveWearable(client, 0)
	}
}

public Action:BeZombie(client, args)
{
	decl String:argc[32]
	if(GetCmdArgs() > 0)
	{
		GetCmdArg(1, argc, sizeof(argc))
	}
	else
	{
		argc = "-1"
	}
	
	if(StringToInt(argc) > 0)
	{
		PrintToChat(client, "Zombie Enabled, be a Zombie next time you spawn");
		enabled[client] = true
	}
	else if(StringToInt(argc) == 0)
	{
		PrintToChat(client, "Zombie Disabled, you will stop being a Zombie");
		enabled[client] = false
	}
	else if(StringToInt(argc) == -1)
	{
		if(enabled[client] == true)
		{
			PrintToChat(client, "Zombie Toggled Off");
			enabled[client] = false
		}
		else if(enabled[client] == false)
		{
			PrintToChat(client, "Zombie Toggled On");
			enabled[client] = true
		}
	}
	return Plugin_Handled
}

stock GetIndexForClass(client)
{
	new index
	if(TF2_GetPlayerClass(client) == TFClass_Scout)
	{
		index = 5617
	}
	else if(TF2_GetPlayerClass(client) == TFClass_Soldier)
	{
		index = 5618
	}
	else if(TF2_GetPlayerClass(client) == TFClass_Pyro)
	{
		index = 5624
	}
	else if(TF2_GetPlayerClass(client) == TFClass_DemoMan)
	{
		index = 5620
	}
	else if(TF2_GetPlayerClass(client) == TFClass_Heavy)
	{
		index = 5619
	}
	else if(TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		index = 5621
	}
	else if(TF2_GetPlayerClass(client) == TFClass_Medic)
	{
		index = 5622
	}
	else if(TF2_GetPlayerClass(client) == TFClass_Sniper)
	{
		index = 5625
	}
	else if(TF2_GetPlayerClass(client) == TFClass_Spy)
	{
		index = 5623
	}
	return index
}

stock GiveWearable(client, index)
{
	if(IsValidEntity(ClientWearable[client]))
	{
		if(ClientWearable[client] > 0)
		{
			decl String:classname[64]
			GetEntityClassname(ClientWearable[client], classname, sizeof(classname))
			if(StrEqual(classname, "tf_wearable"))
			{
				if (GetEntPropEnt(ClientWearable[client], Prop_Send, "m_hOwnerEntity") == client)
				{
					TF2_RemovePlayerWearable(client, ClientWearable[client])
					AcceptEntityInput(ClientWearable[client], "Kill")
				}
			}
		}

	}
	
	if(index > 0)
	{
		new Handle:wearable = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
		TF2Items_SetQuality(wearable, 10);
		TF2Items_SetLevel(wearable, 0);
		TF2Items_SetItemIndex(wearable, index);
		TF2Items_SetClassname(wearable, "tf_wearable");
		new ent = TF2Items_GiveNamedItem(client, wearable);
		CloseHandle(wearable);
		if (IsValidEntity(ent))
		{
			TF2Attrib_SetByName(ent, "player skin override", 1.0);
			TF2Attrib_SetByName(ent, "zombiezombiezombiezombie", 1.0);
			TF2_EquipPlayerWearable(client, ent);
			ClientWearable[client] = ent
		}
	}
}