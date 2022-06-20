/*
*	Barricades - Doors and Windows
*	Copyright (C) 2022 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.14"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Barricades - Doors and Windows
*	Author	:	SilverShot
*	Descrp	:	Allows Survivors to create Barricades in broken doorways and windows.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=338054
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.14 (20-June-2022)
	- Added a data config to specify positions where there are no doors to allow building barricades in that spot.
	- Added commands "sm_barricade_add" and "sm_barricade_del" to save and delete entries from the data config.
	- L4D2: Plugin now hides the weapon world model when building a barricade.
	- L4D2: Tanks now attack the planks. Thanks to "Lux" for finding the solution.
	- L4D2: Special Infected now attack the planks.

1.13 (16-June-2022)
	- Changed cvar "l4d_barricade_keys" to set accept SHIFT + USE.

1.12 (09-June-2022)
	- Added some door models to prevent building barricades on them.

1.11 (08-June-2022)
	- L4D2: Fixed the building animation not ending when releasing the USE button or after progress bar has finished.

1.10 (07-June-2022)
	- L4D2: Fixed the progress bar not ending correctly.
	- L4D2: Fixed another possible bug of players getting stuck.

1.9 (07-June-2022)
	- L4D2: Fixed the new progress bar creating a solid random model. Thanks to "gongo" for reporting.
	- L4D2: Potentially fixed players getting stuck when the progress bar is destroyed.
	- Changed some cvars to have a minimum value of 0.1, to prevent potential issues with spamming USE.

1.8 (07-June-2022)
	- L4D2: Fixed the double door fix not working from map start.

1.7 (07-June-2022)
	- Added cvar "l4d_barricade_keys" to set the key combination. Requested by "xZk".
	- Fixed building a barricade when reviving someone. Thanks to "gongo" for reporting.
	- L4D2: Progress bar changed to timed button with custom text. Thanks to "xZk" for the method.

1.6 (05-June-2022)
	- Optimized cvar "l4d_barricade_flags" flag checking.

1.5 (04-June-2022)
	- Added cvar "l4d_barricade_flags" to only allow users with specific flags to build barricades. Requested by "Maur0".
	- Added more windows that can be barricaded. Thanks to "Maur0" for reporting.

1.4 (03-June-2022)
	- L4D1: Fixed the planks not showing, however Infected do not attack the barrier. Thanks to "finishlast" for reporting.

1.3 (03-June-2022)
	- Fixed some issues regarding plank health.

1.2 (03-June-2022)
	- Fixed some plank placements being wrong with certain doors and windows.

	- Plugin will now auto link some known individual double doors (currently only L4D2: "c1m1_hotel").
	- This will make the doors open together instead of individually, this is an easier than larger plugin modification to create a workaround.
	- If double doors open individually (which then creates small plank barricades), please report to me the map and location to fix.
	- If admins don't want the doors linked, please request a cvar to block those known doors from being used for barricades.

1.1 (03-June-2022)
	- Common infected now attack the planks!
	- Plugin now supports building barricades in broken Window frames.
	- Plugin renamed to "Barricades - Doors and Windows".
	- All cvars renamed.

1.0 (01-June-2022)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define CONFIG_DATA			"data/l4d_barricade.cfg"
#define MODEL_PLANK1		"models/props_debris/wood_board04a.mdl"
#define MODEL_PLANK2		"models/props_debris/wood_board05a.mdl"
#define SOUND_HAMMER1		"physics/wood/wood_box_impact_bullet1.wav"
#define SOUND_HAMMER2		"physics/wood/wood_box_impact_hard4.wav"
#define SOUND_HAMMER3		"physics/wood/wood_box_impact_hard5.wav"
// #define SOUND_HAMMER1		"weapons/tonfa/tonfa_impact_world1.wav" // L4D2 sound
// #define SOUND_HAMMER2		"weapons/tonfa/tonfa_impact_world2.wav" // L4D2 sound


// Thanks to "Dragokas":
enum // m_eDoorState
{
	DOOR_STATE_CLOSED,
	DOOR_STATE_OPENING_IN_PROGRESS,
	DOOR_STATE_OPENED,
	DOOR_STATE_CLOSING_IN_PROGRESS
}

enum
{
	TYPE_COMMON = 1,
	TYPE_INFECTED,
	TYPE_SURVIVOR,
	TYPE_TANK,
}

enum
{
	TYPE_DOORS = 1,
	TYPE_WINDS,
	TYPE_WINDS_BIG
}

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarDamageC, g_hCvarDamageI, g_hCvarDamageS, g_hCvarDamageT, g_hCvarFlags, g_hCvarHealth, g_hCvarKeys, g_hCvarRange, g_hCvarTime, g_hCvarTimePress, g_hCvarTimeWait, g_hCvarType;
int g_iCvarDamageC, g_iCvarDamageI, g_iCvarDamageS, g_iCvarDamageT, g_iCvarFlags, g_iCvarHealth, g_iCvarKeys, g_iCvarTime, g_iCvarType;
float g_fCvarRange, g_fCvarTimeWait, g_fCvarTimePress;
bool g_bCvarAllow, g_bMapStarted, g_bLeft4Dead2, g_bDoubleDoorFix, g_bDoubleDoorMap, g_bCustomData;
char g_sMod[4];

int g_iBarricade[4096][4];
int g_iRelative[4096];
int g_iRelIndex[4096];
int g_iTypeProp[4096];
int g_iEnties[4096];
float g_vAng[4096][3];
float g_vPos[4096][3];
float g_fPressing[MAXPLAYERS+1];
float g_fTimeout[MAXPLAYERS+1];
float g_fTimePress[MAXPLAYERS+1];
float g_fTimeSound[MAXPLAYERS+1];
bool g_bValidFlags[MAXPLAYERS+1] = { true, ... };
int g_iPressing[MAXPLAYERS+1];
int g_iButtons[MAXPLAYERS+1];


// Block door models
char g_sBlockedModels[5][] =
{
	"models/props_urban/outhouse_door001.mdl",
	"models/props_unique/guncabinet01_ldoor.mdl",
	"models/props_unique/guncabinet01_rdoor.mdl",
	"models/props_waterfront/footlocker01.mdl",
	"models/props_windows/window_urban_sash_32_72_full_gib08.mdl"
};




// ====================================================================================================
//					PLUGIN START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Barricades - Doors and Windows",
	author = "SilverShot",
	description = "Allows Survivors to create Barricades in broken doorways and window frames.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=338054"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if( FindConVar("l4d_door_barricade_version") )
	{
		SetFailState("This plugin makes the \"Door Barricades\" plugin obsolete. Please delete the old one.");
	}
}

public void OnPluginStart()
{
	// Cvars
	g_hCvarAllow =		CreateConVar(	"l4d_barricade_allow",				"1",				"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =		CreateConVar(	"l4d_barricade_modes",				"",					"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =	CreateConVar(	"l4d_barricade_modes_off",			"",					"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =	CreateConVar(	"l4d_barricade_modes_tog",			"0",				"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarDamageC =	CreateConVar(	"l4d_barricade_damage_common",		"250",				"0=Default game damage. Amount of damage to cause to planks when shoved by a Common Infected.", CVAR_FLAGS );
	g_hCvarDamageI =	CreateConVar(	"l4d_barricade_damage_infected",	"250",				"0=Default game damage. Amount of damage to cause to planks when shoved by a Special Infected.", CVAR_FLAGS );
	g_hCvarDamageS =	CreateConVar(	"l4d_barricade_damage_survivor",	"250",				"0=Default game damage. Amount of damage to cause to planks when shoved by a Survivor.", CVAR_FLAGS );
	g_hCvarDamageT =	CreateConVar(	"l4d_barricade_damage_tank",		"0",				"0=Default game damage. Amount of damage to cause to planks when shoved by a Tank.", CVAR_FLAGS );
	g_hCvarFlags =		CreateConVar(	"l4d_barricade_flags",				"",					"Empty string = allow everyone. Otherwise only users with one of these flags can build barricades.", CVAR_FLAGS );
	g_hCvarKeys =		CreateConVar(	"l4d_barricade_keys",				"1",				"1=USE key. 2=CTRL + USE keys. 3=SHIFT + USE keys. Which key combination to build a barricade.", CVAR_FLAGS );
	g_hCvarHealth =		CreateConVar(	"l4d_barricade_health",				"500",				"Health of each plank.", CVAR_FLAGS );
	g_hCvarRange =		CreateConVar(	"l4d_barricade_range",				"100.0",			"Range required by Survivors to an open doorway or window to create planks. Large values may affect other nearby doorways or windows.", CVAR_FLAGS );
	g_hCvarTime =		CreateConVar(	"l4d_barricade_time",				"5",				"How long does it take to build 1 plank. Use whole numbers only, must be 1 or greater.", CVAR_FLAGS, true, 1.0 );
	g_hCvarTimePress =	CreateConVar(	"l4d_barricade_time_press",			"0.3",				"How long must someone be holding +USE before building starts.", CVAR_FLAGS, true, 0.1 );
	g_hCvarTimeWait =	CreateConVar(	"l4d_barricade_time_wait",			"0.5",				"How long after building a plank to make the player wait until they can build again.", CVAR_FLAGS, true, 0.1 );
	g_hCvarType =		CreateConVar(	"l4d_barricade_types",				"3",				"1=Doors. 2=Windows. 3=Both. Where can barricades be built.", CVAR_FLAGS );
	CreateConVar(						"l4d_barricade_version",			PLUGIN_VERSION,		"Barricades - Doors and Windows plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,				"l4d_barricade");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarDamageC.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDamageI.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDamageS.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDamageT.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarHealth.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarKeys.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarFlags.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarRange.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTime.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTimePress.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarTimeWait.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarType.AddChangeHook(ConVarChanged_Cvars);

	// Commands
	if( g_bLeft4Dead2 && CommandExists("sm_doors_glow") == false ) // Shared with "Lock Doors" plugin
	{
		RegAdminCmd("sm_doors_glow", CmdDoorsGlow, ADMFLAG_ROOT, "Debug testing command to show all doors.");
	}

	RegAdminCmd("sm_winds_glow", CmdWindsGlow, ADMFLAG_ROOT, "Debug testing command to show all windows.");

	RegAdminCmd("sm_barricade_add", CmdAdd, ADMFLAG_ROOT, "Adds a place to barricades to the data config. Put your back to one side and face the other, step forward sightly and run the command. Usage: sm_barricade_add [plank type: 1=Small, 2=Large]");
	RegAdminCmd("sm_barricade_del", CmdDel, ADMFLAG_ROOT, "Deletes a data config entry when nearby to the position it's saved. Must be next to the one of the frame sides.");
}



// ====================================================================================================
//					PLUGIN END
// ====================================================================================================
public void OnPluginEnd()
{
	ResetPlugin();
}

void ResetPlugin()
{
	// Reset client arrays, progress bar and movement
	for( int i = 1; i <= MaxClients; i++ )
	{
		RemoveButton(i);

		if( g_iPressing[i] && IsClientInGame(i) )
		{
			if( !g_bLeft4Dead2 )
			{
				SetEntPropString(i, Prop_Send, "m_progressBarText", "");
				SetEntPropFloat(i, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
				SetEntProp(i, Prop_Send, "m_iProgressBarDuration", 0);
			}

			SetEntityMoveType(i, MOVETYPE_WALK);
		}

		g_iPressing[i] = 0;
		g_fPressing[i] = 0.0;
		g_fTimeout[i] = 0.0;
		g_fTimePress[i] = 0.0;
		g_fTimeSound[i] = 0.0;
	}

	// Reset entity arrays, delete planks
	int entity;

	for( int i = 0; i < 4096; i++ )
	{
		g_vAng[i] = view_as<float>({ 0.0, 0.0, 0.0 });
		g_vPos[i] = view_as<float>({ 0.0, 0.0, 0.0 });
		g_iEnties[i] = 0;
		g_iRelative[i] = 0;
		g_iRelIndex[i] = 0;
		g_iTypeProp[i] = 0;

		for( int x = 0; x < 4; x++ )
		{
			entity = g_iBarricade[i][x];
			if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
			{
				RemoveEntity(entity);
			}

			g_iBarricade[i][x] = 0;
		}
	}
}



// ====================================================================================================
//					COMMANDS - GLOW
// ====================================================================================================
bool g_bDoorsGlow;
Action CmdDoorsGlow(int client, int args)
{
	g_bDoorsGlow = !g_bDoorsGlow;

	int entity = -1;
	while( (entity = FindEntityByClassname(entity, "prop_door_rotating")) != INVALID_ENT_REFERENCE )
	{
		SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", 255);
		SetEntProp(entity, Prop_Send, "m_nGlowRange", g_bDoorsGlow ? 0 : 9999);
		SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", 20);
		if( g_bDoorsGlow )
			AcceptEntityInput(entity, "StartGlowing");
		else
			AcceptEntityInput(entity, "StopGlowing");
	}

	return Plugin_Handled;
}

bool g_bWindsGlow;
Action CmdWindsGlow(int client, int args)
{
	g_bWindsGlow = !g_bWindsGlow;

	static char sModel[128];

	int entity = -1;
	while( (entity = FindEntityByClassname(entity, "prop_physics")) != INVALID_ENT_REFERENCE )
	{
		GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

		if(
			strcmp(sModel, "models/props/cs_militia/militiawindow02_breakable.mdl", false) == 0 ||
			strcmp(sModel, "models/props_windows/window_farmhouse_small.mdl", false) == 0 ||
			strcmp(sModel, "models/props_windows/window_industrial.mdl", false) == 0 ||
			strcmp(sModel, "models/props_windows/window_urban_apt.mdl", false) == 0 ||
			strcmp(sModel, "models/props_windows/window_farmhouse_big.mdl", false) == 0
		)
		{
			SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
			SetEntProp(entity, Prop_Send, "m_glowColorOverride", 255);
			SetEntProp(entity, Prop_Send, "m_nGlowRange", g_bWindsGlow ? 0 : 9999);
			SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", 20);
			if( g_bWindsGlow )
				AcceptEntityInput(entity, "StartGlowing");
			else
				AcceptEntityInput(entity, "StopGlowing");
		}
	}

	return Plugin_Handled;
}



// ====================================================================================================
//					COMMANDS - ADD / DELETE
// ====================================================================================================
Action CmdAdd(int client, int args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[SM] Plugin turned off.");
		return Plugin_Handled;
	}

	if( !client )
	{
		ReplyToCommand(client, "[Barricades] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_DATA);
	if( !FileExists(sPath) )
	{
		File hCfg = OpenFile(sPath, "w");
		hCfg.WriteLine("");
		delete hCfg;
		return Plugin_Handled;
	}

	// Load config
	KeyValues hFile = new KeyValues("barricades");
	if( !hFile.ImportFromFile(sPath) )
	{
		PrintToChat(client, "\x04[Barricades] \x01Error: Cannot read the Barricades config, assuming empty file. (\x05%s\x01).", sPath);
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	if( !hFile.JumpToKey(sMap, true) )
	{
		PrintToChat(client, "\x04[Barricades] \x01Error: Failed to add map to the Barricades data config.");
		delete hFile;
		return Plugin_Handled;
	}

	int index = 1;
	while( index )
	{
		IntToString(index, sMap, sizeof(sMap));

		if( KvJumpToKey(hFile, sMap) )
		{
			index++;
			hFile.GoBack();
		} else {
			break;
		}
	}

	index += 2048;
	g_bCustomData = true;

	// Create entry
	KvJumpToKey(hFile, sMap, true);

	// Save data
	float vPos[3];

	// Pos
	GetClientAbsOrigin(client, vPos);
	vPos[2] += 40.0;
	hFile.SetVector("pos", vPos);
	g_vPos[index] = vPos;

	// Ang
	GetClientEyeAngles(client, vPos);
	vPos[0] = 0.0;
	vPos[1] -= 180.0;
	vPos[2] = 0.0;
	hFile.SetFloat("ang", vPos[1]);
	g_vAng[index] = vPos;

	// Type
	int type = 1;

	if( args )
	{
		GetCmdArg(1, sMap, sizeof(sMap));
		type = StringToInt(sMap);
	}

	if( type == 2 )
	{
		g_iTypeProp[index] = TYPE_DOORS;
		g_iRelative[index] = index - 2048;
	}

	hFile.SetNum("type", type);

	// Save cfg
	hFile.Rewind();
	hFile.ExportToFile(sPath);
	delete hFile;

	PrintToChat(client, "\x04[Barricades] \x01Saved new index \x05%d\x01.", index - 2048);

	return Plugin_Handled;
}

Action CmdDel(int client, int args)
{
	if( !g_bCvarAllow )
	{
		ReplyToCommand(client, "[SM] Plugin turned off.");
		return Plugin_Handled;
	}

	if( !client )
	{
		ReplyToCommand(client, "[Barricades] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
		return Plugin_Handled;
	}

	int index;

	float vPos[3];
	GetClientAbsOrigin(client, vPos);


	// Loop props
	for( int i = 2049; i < 4096; i++ )
	{
		// Prop pos
		if( g_vPos[i][0] && g_vPos[i][1] && g_vPos[i][2] )
		{
			if( GetVectorDistance(vPos, g_vPos[i]) <= 100.0 )
			{
				index = i;
				break;
			}
		}
	}

	if( index == 0 )
	{
		PrintToChat(client, "\x04[Barricades] \x01Cannot find a nearby Barricade index. Move closer to the frame or try the other side.", index);
		return Plugin_Handled;
	}

	// Load config
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_DATA);
	if( !FileExists(sPath) )
	{
		PrintToChat(client, "\x04[Barricades] Warning: Cannot find the data config (\x05%s\x01).", CONFIG_DATA);
		return Plugin_Handled;
	}

	KeyValues hFile = new KeyValues("barricades");
	if( !hFile.ImportFromFile(sPath) )
	{
		PrintToChat(client, "\x04[Barricades] Warning: Cannot load the data config (\x05%s\x01).", sPath);
		delete hFile;
		return Plugin_Handled;
	}

	// Check for current map in the config
	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));

	if( !hFile.JumpToKey(sMap) )
	{
		PrintToChat(client, "\x04[Barricades] Warning: Current map not in the data config.");
		delete hFile;
		return Plugin_Handled;
	}

	bool bMove;
	char sTemp[4];
	int i = index - 2048;

	// Move the other entries down
	while( index )
	{
		IntToString(i, sTemp, sizeof(sTemp));

		if( hFile.JumpToKey(sTemp) )
		{
			if( !bMove )
			{
				bMove = true;
				hFile.DeleteThis();

				// Delete barricades
				int entity;

				for( int x = 0; x < 4; x++ )
				{
					entity = g_iBarricade[index][x];
					if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
					{
						RemoveEntity(entity);
					}
				}
			}
			else
			{
				IntToString(i - 1, sTemp, sizeof(sTemp));
				hFile.SetSectionName(sTemp);
				hFile.GoBack();
			}

			i++;
			hFile.Rewind();
			hFile.JumpToKey(sMap);
		}
		else
		{
			break;
		}

		// Move array indexes
		for( int x = 0; x < 4; x++ )
		{
			g_iBarricade[2048 + i - 1][x] = g_iBarricade[2048 + i][x];
		}

		g_vPos[2048 + i - 1] = g_vPos[2048 + i];
		g_vAng[2048 + i - 1] = g_vAng[2048 + i];
		g_iTypeProp[2048 + i - 1] = g_iTypeProp[2048 + i];
		g_iRelative[2048 + i - 1] = g_iRelative[2048 + i];

		g_vPos[2048 + i] = view_as<float>({ 0.0, 0.0, 0.0 });
		g_vAng[2048 + i] = view_as<float>({ 0.0, 0.0, 0.0 });
		g_iTypeProp[2048 + i] = 0;
		g_iRelative[2048 + i] = 0;
	}

	if( bMove )
	{
		// Save to file
		hFile.Rewind();
		hFile.ExportToFile(sPath);

		PrintToChat(client, "\x01\x04[Barricades] \x01Deleted index \x05%d \x01from the data config.", index - 2048);
	}
	else
	{
		PrintToChat(client, "\x01\x04[Barricades] \x01Failed to delete index \x05%d \x01from the data config.", index - 2048);
	}

	return Plugin_Handled;
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnMapStart()
{
	g_bMapStarted = true;

	PrecacheModel(MODEL_PLANK1);
	PrecacheModel(MODEL_PLANK2);
	PrecacheSound(SOUND_HAMMER1);
	PrecacheSound(SOUND_HAMMER2);
	PrecacheSound(SOUND_HAMMER3);

	if( g_bLeft4Dead2 )
	{
		// Find model for func_button_timed so the text displays
		for( int i = 1; i <= 50; i++ )
		{
			FormatEx(g_sMod, sizeof(g_sMod), "*%d", i);
			if( IsModelPrecached(g_sMod) )
			{
				break;
			}

			if( i == 50 )
			{
				g_sMod[0] = 0;
			}
		}
	}



	// =========================
	// Load config
	// =========================
	g_bCustomData = false;

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_DATA);

	if( FileExists(sPath) )
	{
		KeyValues hFile = new KeyValues("barricades");
		if( !hFile.ImportFromFile(sPath) )
		{
			delete hFile;
			return;
		}

		// Check for current map in the config
		char sMap[64];
		GetCurrentMap(sMap, sizeof(sMap));

		if( !hFile.JumpToKey(sMap) )
		{
			delete hFile;
			return;
		}

		g_bCustomData = true;

		int index = 1;
		while( index > 0 )
		{
			IntToString(index, sMap, sizeof(sMap));

			if( KvJumpToKey(hFile, sMap) )
			{
				hFile.GetVector("pos", g_vPos[2048 + index]);
				g_vAng[2048 + index][1] = hFile.GetFloat("ang");

				if( hFile.GetNum("type") == 2 ) // Large model
				{
					g_iTypeProp[2048 + index] = TYPE_DOORS;
					g_iRelative[2048 + index] = index;
				}

				hFile.GoBack();
				index++;
			} else {
				index = 0;
			}
		}

		delete hFile;
	}
}

public void OnMapEnd()
{
	g_bDoubleDoorMap = false;
	g_bDoorsGlow = false;
	g_bWindsGlow = false;
	g_bMapStarted = false;

	ResetPlugin();
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	char sTemp[32];
	g_hCvarFlags.GetString(sTemp, sizeof(sTemp));
	g_iCvarFlags = ReadFlagString(sTemp);
	g_iCvarDamageC = g_hCvarDamageC.IntValue;
	g_iCvarDamageI = g_hCvarDamageI.IntValue;
	g_iCvarDamageS = g_hCvarDamageS.IntValue;
	g_iCvarDamageT = g_hCvarDamageT.IntValue;
	g_iCvarHealth = g_hCvarHealth.IntValue;
	g_iCvarKeys = g_hCvarKeys.IntValue;
	g_fCvarRange = g_hCvarRange.FloatValue;
	g_iCvarTime = RoundToCeil(g_hCvarTime.FloatValue);
	g_fCvarTimePress = g_hCvarTimePress.FloatValue;
	g_fCvarTimeWait = g_hCvarTimeWait.FloatValue;
	g_iCvarType = g_hCvarType.IntValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;

		HookEvent("round_end",			Event_RoundEnd,		EventHookMode_PostNoCopy);

		int entity = -1;
		if( g_iCvarType & TYPE_DOORS )
		{
			while( (entity = FindEntityByClassname(entity, "prop_door_rotating")) != INVALID_ENT_REFERENCE )
			{
				SpawnPostDoors(entity);
			}
		}

		entity = -1;
		if( g_iCvarType & TYPE_WINDS )
		{
			while( (entity = FindEntityByClassname(entity, "prop_physics")) != INVALID_ENT_REFERENCE )
			{
				SpawnPostWinds(entity);
			}
		}
	}
	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;

		UnhookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);

		ResetPlugin();
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		if( g_bMapStarted == false )
			return false;

		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		if( IsValidEntity(entity) )
		{
			DispatchSpawn(entity);
			HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
			HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
			ActivateEntity(entity);
			AcceptEntityInput(entity, "PostSpawnActivate");
			if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
				RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
		}

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void OnClientPutInServer(int client)
{
	g_bValidFlags[client] = true;
}

public void OnClientPostAdminCheck(int client)
{
	if( g_iCvarFlags )
	{
		int flags = GetUserFlagBits(client);

		if( !(flags & ADMFLAG_ROOT) && !(flags & g_iCvarFlags) )
		{
			g_bValidFlags[client] = false;
		}
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bDoorsGlow = false;
	g_bWindsGlow = false;
	ResetPlugin();
}


// ====================================================================================================
//					ENTITY SPAWN
// ====================================================================================================
public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bCvarAllow )
	{
		if( g_iCvarType & TYPE_DOORS && strcmp(classname, "prop_door_rotating") == 0 )
		{
			SDKHook(entity, SDKHook_SpawnPost, SpawnPostDoors);
		}
		else if( g_iCvarType & TYPE_WINDS && strcmp(classname, "prop_physics") == 0 )
		{
			SDKHook(entity, SDKHook_SpawnPost, SpawnPostWinds);
		}
	}
}



// ====================================================================================================
//					DOOR SPAWN
// ====================================================================================================
void SpawnPostDoors(int entity)
{
	// Ignore outhouse doors and gun cabinet doors
	static char sModel[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

	for( int i = 0; i < sizeof(g_sBlockedModels); i++ )
	{
		if(	strcmp(sModel, g_sBlockedModels[i], false) == 0 ) return;
	}

	// Pair together known individual double doors
	if( g_bLeft4Dead2 && !g_bDoubleDoorMap )
	{
		// Individual double doors fix
		g_bDoubleDoorMap = true;
		g_bDoubleDoorFix = false;

		static char sMap[16];

		GetCurrentMap(sMap, sizeof(sMap));
		if( strcmp(sMap, "c1m1_hotel") == 0 )
		{
			g_bDoubleDoorFix = true;
		}
	}

	if( g_bDoubleDoorFix )
	{
		int hammer = GetEntProp(entity, Prop_Data, "m_iHammerID");

		switch( hammer )
		{
			case 705345, 492367:	DispatchKeyValue(entity, "targetname", "silver_barricade_fix_1");
			case 494086, 494081:	DispatchKeyValue(entity, "targetname", "silver_barricade_fix_2");
		}
	}

	// Store ref
	g_iEnties[entity] = EntIndexToEntRef(entity);

	// Save positions
	float vAng[3], vPos[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
	GetEntPropVector(entity, Prop_Data, "m_angRotationClosed", vAng);
	vAng[1] -= 90.0;

	// Change height since L4D1 and L4D2 door models have different ground position (vPos[2])
	if( strncmp(sModel, "models/props_doors", 18, false) == 0 )
	{
		vPos[2] -= 10.0;
	} else {
		vPos[2] += 42.0;
	}

	g_vPos[entity] = vPos;
	g_vAng[entity] = vAng;
	g_iTypeProp[entity] = TYPE_DOORS;

	// Find double doors
	MatchRelatives(entity);
}

void MatchRelatives(int entity)
{
	static char sTemp[128], sTarget[128];
	int target = -1;

	// Match relative doors by "m_SlaveName"
	GetEntPropString(entity, Prop_Data, "m_SlaveName", sTemp, sizeof(sTemp));

	if( sTemp[0] != 0 )
	{
		while( (target = FindEntityByClassname(target, "prop_door_rotating")) != INVALID_ENT_REFERENCE )
		{
			if( target != entity )
			{
				GetEntPropString(target, Prop_Data, "m_iName", sTarget, sizeof(sTarget));
				if( strcmp(sTemp, sTarget) == 0 )
				{
					g_iRelative[target] = EntIndexToEntRef(entity);
					g_iRelative[entity] = EntIndexToEntRef(target);
					g_iRelIndex[target] = entity;
					g_iRelIndex[entity] = target;
					return;
				}
			}
		}
	}

	// Match relative doors by "m_iName"
	GetEntPropString(entity, Prop_Data, "m_iName", sTemp, sizeof(sTemp));

	if( sTemp[0] != 0 )
	{
		target = -1;

		while( (target = FindEntityByClassname(target, "prop_door_rotating")) != INVALID_ENT_REFERENCE )
		{
			if( target != entity )
			{
				GetEntPropString(target, Prop_Data, "m_iName", sTarget, sizeof(sTarget));
				if( strcmp(sTemp, sTarget) == 0 )
				{
					g_iRelative[target] = EntIndexToEntRef(entity);
					g_iRelative[entity] = EntIndexToEntRef(target);
					g_iRelIndex[target] = entity;
					g_iRelIndex[entity] = target;
					return;
				}
			}
		}
	}
}



// ====================================================================================================
//					WINDOW SPAWN
// ====================================================================================================
void SpawnPostWinds(int entity)
{
	// Only allow these windows (please report others to support)
	int type;

	static char sModel[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
	if( strcmp(sModel, "models/props_windows/window_industrial.mdl", false) == 0 )
	{
		type = 1;
	}
	else if( strcmp(sModel, "models/props_windows/window_urban_apt.mdl", false) == 0 || strcmp(sModel, "models/props_windows/window_farmhouse_big.mdl") == 0 || strcmp(sModel, "models/props_windows/window_farmhouse_small.mdl", false) == 0 )
	{
		type = 2;
	}
	else if( strcmp(sModel, "models/props/cs_militia/militiawindow02_breakable.mdl", false) == 0 )
	{
		type = 3;
	}

	if( type )
	{
		// Store ref
		g_iEnties[entity] = EntIndexToEntRef(entity);

		// Save positions
		float vAng[3], vPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
		GetEntPropVector(entity, Prop_Data, "m_angRotation", vAng);
		vAng[1] -= 90.0;

		if( type == 1 ) vPos[2] += 35.0;

		g_vPos[entity] = vPos;
		g_vAng[entity] = vAng;
		g_iTypeProp[entity] = type == 3 ? TYPE_WINDS_BIG : TYPE_WINDS;
	}
}



// ====================================================================================================
//					KEYBINDS
// ====================================================================================================
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if( !g_bCvarAllow ) return Plugin_Continue;

	if( ((g_iCvarKeys == 1 && buttons & IN_USE) || (g_iCvarKeys == 2 && buttons & (IN_USE|IN_DUCK) == IN_USE|IN_DUCK) || (g_iCvarKeys == 3 && buttons & (IN_USE|IN_SPEED) == IN_USE|IN_SPEED)) )
	{
		// Validation checks
		if( !g_bValidFlags[client] || !IsPlayerAlive(client) || GetClientTeam(client) != 2 ) return Plugin_Continue;
		if( IsReviving(client) || IsIncapped(client) || IsClientPinned(client) ) return Plugin_Continue;

		// Time pressing +USE
		if( g_fTimePress[client] == 0.0 )
		{
			g_fTimePress[client] = GetGameTime();
		}
		else if( GetGameTime() > g_fTimePress[client] + g_fCvarTimePress && GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1 )
		{
			if( g_fTimeout[client] < GetGameTime() )
			{
				int index;

				if( !g_iPressing[client] )
				{
					// Player pos, find nearest prop that existed
					float range = g_fCvarRange;
					float dist;
					float vPos[3];
					GetClientAbsOrigin(client, vPos);

					int entries = g_bCustomData ? 4096 : 2048;

					// Loop props
					for( int i = MaxClients + 1; i < entries; i++ )
					{
						// Barricade pos
						if( g_vPos[i][0] && g_vPos[i][1] && g_vPos[i][2] )
						{
							// Custom location or prop is dead
							if( i >= 2048 || (g_iEnties[i] && EntRefToEntIndex(g_iEnties[i]) == INVALID_ENT_REFERENCE && !IsValidEntRef(g_iRelative[i])) )
							{
								dist = GetVectorDistance(vPos, g_vPos[i]);

								if( dist < range )
								{
									range = dist;
									index = i;
								}
							}
						}
					}
				} else {
					index = g_iPressing[client];
				}

				if( index && (!IsValidEntRef(g_iBarricade[index][0]) || !IsValidEntRef(g_iBarricade[index][1]) || !IsValidEntRef(g_iBarricade[index][2]) || !IsValidEntRef(g_iBarricade[index][3])) )
				{
					// Start pressing
					if( !g_iPressing[client] )
					{
						g_fPressing[client] = GetGameTime() + g_iCvarTime;
						g_iPressing[client] = index;
						if( g_bLeft4Dead2 )
						{
							RemoveButton(client);

							// Remove worldmodel weapon
							weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
							if( weapon != -1 )
							{
								SetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", -1);
								SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
							}

							// L4D2 progress bar, with custom text
							static char sTemp[4];
							int button = CreateEntityByName("func_button_timed");
							DispatchKeyValueVector(button, "origin", g_vPos[index]);
							DispatchKeyValue(button, "model", g_sMod); // Required to make text display
							IntToString(g_iCvarTime, sTemp, sizeof(sTemp));
							DispatchKeyValue(button, "spawnflags", "0");
							DispatchKeyValue(button, "solid", "0");
							DispatchKeyValue(button, "auto_disable", "1");
							DispatchKeyValue(button, "use_time", sTemp);
							DispatchKeyValue(button, "use_string", "BARRICADE");
							DispatchKeyValue(button, "use_sub_string", "Building plank...");
							DispatchSpawn(button);

							SetEntProp(button, Prop_Send, "m_nSolidType", 0);
							SetEntityRenderMode(button, RENDER_NONE);

							HookSingleEntityOutput(button, "OnTimeUp", OnButtonEnd);
							HookSingleEntityOutput(button, "OnUnpressed", OnButtonEnd);

							AcceptEntityInput(button, "Use", client);
							g_iButtons[client] = EntIndexToEntRef(button);
						}
						else
						{
							SetEntPropString(client, Prop_Send, "m_progressBarText", "BUILDING BARRICADE...");
							SetEntProp(client, Prop_Send, "m_iProgressBarDuration", g_iCvarTime);
						}

						// Stop player moving
						SetEntityMoveType(client, MOVETYPE_NONE);
						TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, view_as<float>({ 0.0, 0.0, 0.0 }));
					} else {
						PlaySound(client);

						// Finished pressing
						if( g_fPressing[client] < GetGameTime() )
						{
							g_fTimePress[client] = 0.0;
							g_iPressing[client] = 0;
							g_fTimeout[client] = GetGameTime() + g_fCvarTimeWait;

							if( g_bLeft4Dead2 )
							{
								RemoveButton(client);
							}
							else
							{
								SetEntPropString(client, Prop_Send, "m_progressBarText", "");
								SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
							}
							SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
							SetEntityMoveType(client, MOVETYPE_WALK);
							BuildBarricade(index);
						}
					}
				}
			}
		}
	}
	else
	{
		g_fTimePress[client] = 0.0;

		if( g_iPressing[client] )
		{
			g_iPressing[client] = 0;
			g_fPressing[client] = 0.0;

			if( g_bLeft4Dead2 )
			{
				RemoveButton(client);
			}
			else
			{
				SetEntPropString(client, Prop_Send, "m_progressBarText", "");
				SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0);
			}
			SetEntPropFloat(client, Prop_Send, "m_flProgressBarStartTime", GetGameTime());
			SetEntityMoveType(client, MOVETYPE_WALK);
		}
	}

	return Plugin_Continue;
}

Action OnWeaponSwitch(int client, int weapon)
{
	return Plugin_Handled;
}

void OnButtonEnd(const char[] output, int caller, int activator, float delay)
{
	if( activator > 0 && activator <= MaxClients )
	{
		RemoveButton(activator);
	}
}

void RemoveButton(int client)
{
	SDKUnhook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);

	if( IsValidEntRef(g_iButtons[client]) )
	{
		// Remove progress bar
		AcceptEntityInput(g_iButtons[client], "Disable");

		// Delete entity
		RemoveEntity(g_iButtons[client]);
		g_iButtons[client] = 0;

		if( IsClientInGame(client) )
		{
			// Stop animation player
			int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
			if( weapon != -1 )
			{
				RemovePlayerItem(client, weapon);
				EquipPlayerWeapon(client, weapon);
			}

			// Fix healing target making the target unable to be healed again
			int target = GetEntPropEnt(client, Prop_Send, "m_useActionTarget");
			if( target > 0 && target <= MaxClients && IsClientInGame(target) )
			{
				SetEntProp(target, Prop_Send, "m_useActionOwner", 0);
				SetEntProp(target, Prop_Send, "m_useActionTarget", 0);
				SetEntProp(target, Prop_Send, "m_iCurrentUseAction", 0);
			}

			// Fix client unable to move
			SetEntProp(client, Prop_Send, "m_useActionOwner", 0);
			SetEntProp(client, Prop_Send, "m_useActionTarget", 0);
			SetEntProp(client, Prop_Send, "m_iCurrentUseAction", 0);
			SetEntityMoveType(client, MOVETYPE_WALK);
		}
	}
}



// ====================================================================================================
//					SOUND
// ====================================================================================================
void PlaySound(int client)
{
	if( g_fTimeSound[client] < GetGameTime() )
	{
		g_fTimeSound[client] = GetGameTime() + GetRandomFloat(0.35, 0.5);

		SetRandomSeed(RoundFloat(GetTickedTime()));
		switch( GetRandomInt(1, 3) )
		{
			case 1: EmitSoundToAll(SOUND_HAMMER1, client);
			case 2: EmitSoundToAll(SOUND_HAMMER2, client);
			case 3: EmitSoundToAll(SOUND_HAMMER3, client);
		}
	}
}



// ====================================================================================================
//					MAKE BARRICADE
// ====================================================================================================
void BuildBarricade(int index)
{
	int plank;

	if( !IsValidEntRef(g_iBarricade[index][0]) )			plank = 1;
	else if( !IsValidEntRef(g_iBarricade[index][1]) )		plank = 2;
	else if( !IsValidEntRef(g_iBarricade[index][2]) )		plank = 3;
	else if( !IsValidEntRef(g_iBarricade[index][3]) )		plank = 4;

	if( plank )
	{
		int entity = CreateEntityByName(g_bLeft4Dead2 ? "prop_wall_breakable" : "prop_physics");
		if( entity != -1 )
		{
			bool dbl_door;
			bool is_door = g_iTypeProp[index] == TYPE_DOORS;

			if( is_door )
			{
				dbl_door = g_iRelative[index] != 0;
			}

			// If double doors, set relative barricade reference to prevent dupe barricades being created
			g_iBarricade[index][plank - 1] = EntIndexToEntRef(entity);
			if( dbl_door ) g_iBarricade[g_iRelIndex[index]][plank - 1] = EntIndexToEntRef(entity);

			// Big window
			if( g_iTypeProp[index] == TYPE_WINDS_BIG ) dbl_door = true;

			DispatchKeyValue(entity, "solid", "6");
			DispatchKeyValue(entity, "model", dbl_door ? MODEL_PLANK2 : MODEL_PLANK1);
			DispatchSpawn(entity);

			DispatchKeyValue(entity, "classname", "prop_door_rotating"); // SI Attacks
			SetEntityMoveType(entity, MOVETYPE_VPHYSICS); // Tank attacks

			// Health
			SetEntProp(entity, Prop_Data, "m_iHealth", g_iCvarHealth);

			SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);

			// Position
			float vAng[3];
			float vPos[3];

			vAng = g_vAng[index];
			vPos = g_vPos[index];

			// Move into center of prop
			if( is_door )
			{
				if( dbl_door ) // Double door
					MoveSideway(vPos, vAng, vPos, -50.0);
				else
					MoveSideway(vPos, vAng, vPos, -25.0);
			} else {
				MoveSideway(vPos, vAng, vPos, 0.0);
			}

			if( is_door ) // Raise higher so they don't jump over the barrier
				vPos[2] += 10.0;

			switch( plank )
			{
				case 1:
				{
					// Ang up right, very bottom of prop
					vAng[1] -= 90.0;
					vAng[2] += 92.0;
					vPos[2] -= dbl_door ? 28.0 : 20.0;
				}
				case 2:
				{
					// Ang up right, bottom of prop
					vAng[1] -= 90.0;
					vAng[2] += dbl_door ? 89.0 : 96.0;
					vPos[2] -= dbl_door ? 10.0 : 7.0;
				}
				case 3:
				{
					// Ang up left, middle of prop
					vAng[1] -= 90.0;
					vAng[2] += dbl_door ? 87.0 : 85.0;
					vPos[2] += dbl_door ? 12.0 : 8.0;
				}
				case 4:
				{
					// Ang up right, top of prop
					vAng[1] -= 90.0;
					vAng[2] += dbl_door ? 92.0 : 95.0;
					vPos[2] += dbl_door ? 35.0 : 25.0;
				}
			}

			float angleX = vAng[0];
			float angleY = vAng[1];
			float angleZ = vAng[2];
			float vNew[3];
			float vLoc[3];
			NormalizeVector(vPos, vLoc);

			// Thanks to "Don't Fear The Reaper" for the Rotation Matrix:
			vNew[0] = (vLoc[0] * Cosine(angleX) * Cosine(angleY)) - (vLoc[1] * Cosine(angleZ) * Sine(angleY)) + (vLoc[1] * Sine(angleZ) * Sine(angleX) * Cosine(angleY)) + (vLoc[2] * Sine(angleZ) * Sine(angleY)) + (vLoc[2] * Cosine(angleZ) * Sine(angleX) * Cosine(angleY));
			vNew[1] = (vLoc[0] * Cosine(angleX) * Sine(angleY)) + (vLoc[1] * Cosine(angleZ) * Cosine(angleY)) + (vLoc[1] * Sine(angleZ) * Sine(angleX) * Sine(angleY)) - (vLoc[2] * Sine(angleZ) * Cosine(angleY)) + (vLoc[2] * Cosine(angleZ) * Sine(angleX) * Sine(angleY));
			vNew[2] = (-1.0 * vLoc[0] * Sine(angleX)) + (vLoc[1] * Sine(angleZ) * Cosine(angleX)) + (vLoc[2] * Cosine(angleZ) * Cosine(angleX));
			vLoc = vNew;

			AddVectors(vPos, vLoc, vLoc);
			TeleportEntity(entity, vLoc, vAng, NULL_VECTOR);
		}
	}
}

void MoveSideway(const float vPos[3], const float vAng[3], float vReturn[3], float fDistance)
{
	float vDir[3];
	GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
	vReturn = vPos;
	vReturn[0] += vDir[0] * fDistance;
	vReturn[1] += vDir[1] * fDistance;
}



// ====================================================================================================
//					HEALTH
// ====================================================================================================
Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if( damagetype == DMG_CLUB )
	{
		int type;
		if( attacker > MaxClients )
		{
			type = TYPE_COMMON;
		}
		else if( attacker <= MaxClients && inflictor <= MaxClients ) // inflictor can be melee weapon which is also DMG_CLUB
		{
			if( GetClientTeam(attacker) == 3 )
			{
				int class = GetEntProp(attacker, Prop_Send, "m_zombieClass");
				if( (g_bLeft4Dead2 && class == 8) || g_bLeft4Dead2 && class == 5 )
					type = TYPE_TANK;
				else
					type = TYPE_INFECTED;
			}
			else
				type = TYPE_SURVIVOR;
		}

		switch( type )
		{
			case TYPE_COMMON:		if( !g_iCvarDamageC ) type = 0;
			case TYPE_INFECTED:		if( !g_iCvarDamageI ) type = 0;
			case TYPE_SURVIVOR:		if( !g_iCvarDamageS ) type = 0;
			case TYPE_TANK:			if( !g_iCvarDamageT ) type = 0;
		}

		if( type )
		{
			int health = GetEntProp(victim, Prop_Data, "m_iHealth");

			// Must set health on frame, after 1 hit the game sets the planks health to 0
			DataPack dPack = new DataPack();
			dPack.WriteCell(EntIndexToEntRef(victim));
			dPack.WriteCell(health);
			dPack.WriteCell(type);
			RequestFrame(OnFrameHealth, dPack);

			if( health > 0 )
				return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

void OnFrameHealth(DataPack dPack)
{
	dPack.Reset();

	int entity = dPack.ReadCell();
	int health = dPack.ReadCell();
	int type = dPack.ReadCell();
	delete dPack;

	if( EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
	{
		switch( type )
		{
			case TYPE_COMMON:		health = health - g_iCvarDamageC;
			case TYPE_INFECTED:		health = health - g_iCvarDamageI;
			case TYPE_SURVIVOR:		health = health - g_iCvarDamageS;
			case TYPE_TANK:			health = health - g_iCvarDamageT;
		}

		if( health > 0 )
			SetEntProp(entity, Prop_Data, "m_iHealth", health);
		else
			SetEntProp(entity, Prop_Data, "m_iHealth", 0);
	}
}



// ====================================================================================================
//					STOCKS
// ====================================================================================================
bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

bool IsReviving(int client)
{
	if( GetEntPropEnt(client, Prop_Send, "m_reviveTarget") > 0 )
		return true;
	return false;
}

bool IsIncapped(int client)
{
	if( GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) > 0 )
		return true;
	return false;
}

bool IsClientPinned(int client)
{
	if(
		GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0
	) return true;

	if( g_bLeft4Dead2 &&
	(
		GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0
	)) return true;

	return false;
}