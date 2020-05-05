#if defined _jumptracker_included
	#endinput
#endif
#define _jumptracker_included

/**
 * Called as soon as a client jumps.
 *
 * @param client        Client index.
 */
forward void JT_OnClientJumped(int client);

/**
 * Called as soon as a client lands from a jump.
 *
 * @param client        Client index.
 */
forward void JT_OnClientLanded(int client);

public SharedPlugin __pl_jumptracker = 
{
	name = "jumptracker",
	file = "jumptracker.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};