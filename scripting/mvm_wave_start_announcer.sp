#include <sourcemod>
#include <sdktools>
#include <tf2>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.0"

// Hex colors for TF2 chat formatting
#define CHAT_TAG       "\x01[\x04MvM\x01]"
#define COLOR_TEXT     "\x01"       // Normal White/Yellowish
#define COLOR_MAP      "\x0799CCFF" // Soft Cyan/Blue
#define COLOR_DIFF     "\x07FFD700" // Gold/Yellow
#define COLOR_WAVE     "\x0700FF66" // Bright Mint Green

public Plugin myinfo = 
{
    name        = "[TF2 MvM] Wave Start Announcer",
    author      = "parklez",
    description = "Parses map, difficulty, and wave counts, then prints in color on wave start.",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/parklez/sourcemod-plugins"
};

public void OnPluginStart()
{
    // Hooks the MvM wave start event
    HookEvent("mvm_begin_wave", Event_MvMBeginWave, EventHookMode_Post);
}

public void Event_MvMBeginWave(Event event, const char[] name, bool dontBroadcast)
{
    char sPopFile[128];
    if (!GetActivePopFile(sPopFile, sizeof(sPopFile)))
        return;

    char sMapName[64];
    GetCurrentMap(sMapName, sizeof(sMapName));

    char sDifficulty[64];
    ExtractDifficulty(sPopFile, sMapName, sDifficulty, sizeof(sDifficulty));

    int iCurrentWave, iMaxWaves;
    GetMvMWaveInfo(iCurrentWave, iMaxWaves);

    // Print formatted colored message with wave info
    PrintToChatAll("%s Map: \"%s%s%s\" - Difficulty: \"%s%s%s\" - Wave: %s%d/%d%s", 
        CHAT_TAG, 
        COLOR_MAP, sMapName, COLOR_TEXT, 
        COLOR_DIFF, sDifficulty, COLOR_TEXT,
        COLOR_WAVE, iCurrentWave, iMaxWaves, COLOR_TEXT);
}

// =============================================================================
// PARSING & NETPROP HELPERS
// =============================================================================

/**
 * Retrieves the current MvM wave details from tf_objective_resource
 */
bool GetMvMWaveInfo(int &currentWave, int &maxWaves)
{
    int entity = FindEntityByClassname(-1, "tf_objective_resource");
    if (entity != -1)
    {
        currentWave = GetEntProp(entity, Prop_Send, "m_nMannVsMachineWaveCount");
        maxWaves = GetEntProp(entity, Prop_Send, "m_nMannVsMachineMaxWaveCount");
        return true;
    }
    
    currentWave = 0;
    maxWaves = 0;
    return false;
}

/**
 * Extracts difficulty by comparing the popfile to the current map name
 */
void ExtractDifficulty(const char[] sPopFile, const char[] sMapName, char[] buffer, int maxlen)
{
    // Format expected prefix: "mapname_"
    char sMapPrefix[72];
    Format(sMapPrefix, sizeof(sMapPrefix), "%s_", sMapName);

    // If popfile starts with "mapname_" (e.g. "mvm_teien_rc6_advanced_onsen_onslaught")
    if (strncmp(sPopFile, sMapPrefix, strlen(sMapPrefix), false) == 0)
    {
        strcopy(buffer, maxlen, sPopFile[strlen(sMapPrefix)]);
    }
    // If popfile is exactly equal to the map name without extra suffix
    else if (StrEqual(sPopFile, sMapName, false))
    {
        strcopy(buffer, maxlen, "default");
    }
    // Fallback if naming pattern doesn't follow "map_mission" convention
    else
    {
        strcopy(buffer, maxlen, sPopFile);
    }
}

/**
 * Reads and sanitizes the active .pop file name from tf_objective_resource
 */
bool GetActivePopFile(char[] buffer, int maxlen)
{
    int entity = FindEntityByClassname(-1, "tf_objective_resource");
    if (entity != -1 && HasEntProp(entity, Prop_Send, "m_iszMvMPopfileName"))
    {
        GetEntPropString(entity, Prop_Send, "m_iszMvMPopfileName", buffer, maxlen);
        
        SanitizePopfilePath(buffer, maxlen);
        return (buffer[0] != '\0');
    }
    return false;
}

/**
 * Strips path folders and .pop extension cross-platform
 */
void SanitizePopfilePath(char[] buffer, int maxlen)
{
    int lastSlash = -1;
    for (int i = 0; buffer[i] != '\0'; i++)
    {
        if (buffer[i] == '/' || buffer[i] == '\\')
        {
            lastSlash = i;
        }
    }

    if (lastSlash != -1)
    {
        strcopy(buffer, maxlen, buffer[lastSlash + 1]);
    }

    int extIndex = StrContains(buffer, ".pop", false);
    if (extIndex != -1)
    {
        buffer[extIndex] = '\0';
    }
}