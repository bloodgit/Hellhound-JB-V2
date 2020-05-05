#include <sourcemod>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>
#include <morecolors>
#include <clientprefs>
#include <tf_econ_data>

#pragma newdecls required // Force Transitional Syntax
#pragma semicolon 1 // Force Semicolon, should use in every plugin.

#define PLUGIN_VERSION "1.0.0"

int g_iUnusualID[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "[TF2] Item Modifier", 
	author = "blood", 
	description = "In the spirit of my wearables plugin, it is a rewritten item modifier plugin.", 
	version = PLUGIN_VERSION, 
	url = "https://hellhound-australia.net", 
};

public void OnPluginStart()
{
    CreateConVar("tf_itemmodifier_version", PLUGIN_VERSION, "Item modifier Version (Do not touch).", FCVAR_NOTIFY | FCVAR_REPLICATED);

    RegAdminCmd("sm_items", ItemModifierMenu, ADMFLAG_RESERVATION, "Shows the item modifier menu.");

	HookEvent("post_inventory_application", Event_Inventory);
}

public Action ItemModifierMenu(int client, int args)
{
	Menu menu = new Menu(ItemModifierMenu_Handler, MENU_ACTIONS_ALL);
	
	menu.SetTitle("Hellhound Item Modifier Menu");
	
	menu.AddItem("0", "Edit Weapon Slots");
	menu.AddItem("1", "Unusual Taunts");
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled; // Return Plugin_Handled to prevent "unknown command issues."
}

public int ItemModifierMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{	
		case MenuAction_Select:
		{
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			
			switch (param2)
			{
				case 0: // Edit Weapons Menu, add skins and such
				{
					
				}
				case 1: // Unusual Taunts Menu
				{
					DrawUnusualTauntMenu(param1);
				}
			}
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

void DrawUnusualTauntMenu(int client)
{
	// Make the weapon paints menu.
	Menu menu = new Menu(UnusualTauntMenu_Handler, MENU_ACTIONS_ALL);
	
	menu.SetTitle("Unusual Taunts"); // Self explanatory
	
	// Add the items
	menu.AddItem("0", "None");
	menu.AddItem("3001", "Showstopper (RED)");
	menu.AddItem("3002", "Showstopper (BLU)");
	menu.AddItem("3003", "Holy Grail");
	menu.AddItem("3004", "'72");
	menu.AddItem("3005", "Fountain of Delight");
	menu.AddItem("3006", "Screaming Tiger");
	menu.AddItem("3007", "Skill Gotten Gains");
	menu.AddItem("3008", "Midnight Whirlwind");
	menu.AddItem("3009", "Silver Cyclone");
	menu.AddItem("3010", "Mega Strike");
	menu.AddItem("3011", "Haunted Phantasm");
	menu.AddItem("3012", "Ghastly Ghosts");
	//menu.AddItem("13", "Hellish Inferno");
	//menu.AddItem("14", "Roaring Rockets");
	//menu.AddItem("15", "Acid Bubbles of Envy");
	//menu.AddItem("16", "Flammable Bubbles of Attraction");
    //menu.AddItem("17", "Poisonous Bubbles of Regret");
	
	menu.ExitButton = true; // Self explanatory
	menu.Display(client, MENU_TIME_FOREVER); // Draw the menu to the client.
}

public int UnusualTauntMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{	
		case MenuAction_Select:
		{
            char info[24];
            GetMenuItem(menu, param2, info, sizeof(info));

            int tauntid = StringToInt(info);

            if(tauntid == 0)
                CPrintToChat(param1, "You have reset your unusual taunt effect.");
            else
            {
                CPrintToChat(param1, "You have set your unusual taunt effect ID to %d", tauntid);
                g_iUnusualID[param1] = tauntid;
            }
        }
    }
}

public Action Event_Inventory(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int iItemDefinitionIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

	if(iItemDefinitionIndex == 13)
	{

	}
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int iItemDefinitionIndex, Handle &hItem)
{		
    char sItemSlotName[16];
    TF2Econ_GetItemDefinitionString(iItemDefinitionIndex, "item_slot", sItemSlotName, sizeof(sItemSlotName));
    int iSlot = TF2Econ_TranslateLoadoutSlotNameToIndex(sItemSlotName);

    switch(iSlot)
    {
        case 0, 1, 2, 3, 4: // The Weapon Slots
        {
			hItem = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES);

			if(iItemDefinitionIndex == 13)
			{
				TF2Items_SetQuality(hItem, 5);
           		TF2Items_SetNumAttributes(hItem, 4);
            	TF2Items_SetAttribute(hItem, 0, 134, float(701));
				TF2Items_SetAttribute(hItem, 1, 542, float(1));
				TF2Items_SetAttribute(hItem, 2, 2022, float(1));
				TF2Items_SetAttribute(hItem, 3, 2027, float(1));
            	TF2Items_SetFlags(hItem, OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES);

            	return Plugin_Changed;
			}
        }
        case 5: // Misc slot 1
        {
            
        }
        case 6: // Misc slot 2
        {
            
        }
        case 7: // Misc Slot 3
        {
            
        }
    }

    return Plugin_Continue;
}