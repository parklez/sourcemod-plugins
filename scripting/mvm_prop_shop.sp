#include <sourcemod>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION  "1.0.0"

#define COLOR_DEFAULT   "\x01"
#define COLOR_HIGHLIGHT "\x03"
#define COLOR_GREEN     "\x04"
#define COLOR_YELLOW    "\x05"

public Plugin myinfo =
{
    name        = "[TF2 MvM] Cash Prop Store",
    author      = "parklez",
    description = "Allows players to purchase props, explosives, and buildings using MvM cash.",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/parklez/sourcemod-plugins"
};

enum struct PropItem
{
    char name[64];
    char type[32];
    char model[128];
    int  cost;
    int  health;
    int  explodeDamage;
    int  explodeRadius;
}

ArrayList g_hPropList;
int       g_iLastSpawnedProp[MAXPLAYERS + 1] = { -1, ... };
int       g_iLastPropCost[MAXPLAYERS + 1]    = { 0, ... };
bool      g_bWelcomed[MAXPLAYERS + 1]        = { false, ... };

public void OnPluginStart()
{
    g_hPropList = new ArrayList(sizeof(PropItem));

    RegConsoleCmd("sm_props", Command_PropsMenu, "Opens the MvM Prop Store Menu.");
    RegConsoleCmd("sm_refund", Command_Refund, "Refunds the last purchased prop.");

    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
}

public void OnMapStart()
{
    LoadConfig();
}

// ------------------------------------------------------------------
//  Config Loader
// ------------------------------------------------------------------

void LoadConfig()
{
    g_hPropList.Clear();

    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/prop_store.cfg");

    KeyValues hKV = new KeyValues("PropStore");
    if (!hKV.ImportFromFile(sPath))
    {
        delete hKV;
        SetFailState("[!props] Could not locate or parse config file: %s", sPath);
        return;
    }

    if (hKV.GotoFirstSubKey())
    {
        do
        {
            PropItem item;
            hKV.GetSectionName(item.name, sizeof(item.name));
            hKV.GetString("type", item.type, sizeof(item.type), "physics");
            hKV.GetString("model", item.model, sizeof(item.model));
            item.cost          = hKV.GetNum("cost", 0);
            item.health        = hKV.GetNum("health", 0);
            item.explodeDamage = hKV.GetNum("explode_damage", 100);
            item.explodeRadius = hKV.GetNum("explode_radius", 150);

            if (item.model[0] != '\0')
            {
                PrecacheModel(item.model, true);
            }

            g_hPropList.PushArray(item);
        }
        while (hKV.GotoNextKey());
    }

    delete hKV;
}

// ------------------------------------------------------------------
//  Events & Command Listeners
// ------------------------------------------------------------------
public void OnClientConnected(int client)
{
    g_bWelcomed[client] = false;
}

public void OnClientDisconnect(int client)
{
    ResetClientHistory(client);
    g_bWelcomed[client] = false;
}

public Action Event_PlayerSpawn(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    int client = GetClientOfUserId(hEvent.GetInt("userid"));
    if (IsValidClient(client) && IsPlayerAlive(client))
    {
        ResetClientHistory(client);

        if (!g_bWelcomed[client])
        {
            g_bWelcomed[client] = true;
            PrintToChat(client, "%s[!props]%s Type %s!props%s to open the MvM Prop Store or %s!refund%s to return your last prop!",
                        COLOR_GREEN, COLOR_DEFAULT, COLOR_HIGHLIGHT, COLOR_DEFAULT, COLOR_HIGHLIGHT, COLOR_DEFAULT);
        }
    }
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    int client = GetClientOfUserId(hEvent.GetInt("userid"));
    if (client > 0 && client <= MaxClients)
    {
        g_bWelcomed[client] = false;
    }
    return Plugin_Continue;
}

public Action Command_Say(int client, const char[] command, int args)
{
    if (!IsValidClient(client))
        return Plugin_Continue;

    char sArg[32];
    GetCmdArg(1, sArg, sizeof(sArg));

    if (StrEqual(sArg, "!props", false) || StrEqual(sArg, "/props", false))
    {
        OpenPropMenu(client);
        return Plugin_Handled;
    }

    if (StrEqual(sArg, "!refund", false) || StrEqual(sArg, "/refund", false))
    {
        ExecuteRefund(client);
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action Command_PropsMenu(int client, int args)
{
    if (IsValidClient(client)) OpenPropMenu(client);
    return Plugin_Handled;
}

public Action Command_Refund(int client, int args)
{
    if (IsValidClient(client)) ExecuteRefund(client);
    return Plugin_Handled;
}

// ------------------------------------------------------------------
//  Menu Handling
// ------------------------------------------------------------------

void OpenPropMenu(int client, int iStartItem = 0)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client))
        return;

    Menu hMenu = new Menu(MenuHandler_Props);
    hMenu.SetTitle("MvM Prop Store | Cash: $%d", GetClientCash(client));

    int iCash  = GetClientCash(client);
    int iCount = g_hPropList.Length;

    for (int i = 0; i < iCount; i++)
    {
        PropItem item;
        g_hPropList.GetArray(i, item);

        char sIndex[8], sDisplay[128];
        IntToString(i, sIndex, sizeof(sIndex));
        FormatMenuItem(item, sDisplay, sizeof(sDisplay));

        int iFlags = (iCash >= item.cost) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
        hMenu.AddItem(sIndex, sDisplay, iFlags);
    }

    hMenu.ExitButton     = true;
    hMenu.ExitBackButton = true;
    hMenu.Pagination     = 7;
    hMenu.DisplayAt(client, iStartItem, MENU_TIME_FOREVER);
}

void FormatMenuItem(const PropItem item, char[] buffer, int maxlen)
{
    if (item.health > 0)
    {
        Format(buffer, maxlen, "%s [$%d] [HP: %d]", item.name, item.cost, item.health);
    }
    else
    {
        Format(buffer, maxlen, "%s [$%d]", item.name, item.cost);
    }
}

public int MenuHandler_Props(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        int  client = param1;
        char sInfo[8];
        menu.GetItem(param2, sInfo, sizeof(sInfo));

        int propIdx = StringToInt(sInfo);

        if (propIdx >= 0 && propIdx < g_hPropList.Length)
        {
            PropItem item;
            g_hPropList.GetArray(propIdx, item);

            int iCash = GetClientCash(client);
            if (iCash >= item.cost)
            {
                SetClientCash(client, iCash - item.cost);

                int iEnt = SpawnItemAtView(client, item);
                if (IsValidEntity(iEnt))
                {
                    g_iLastSpawnedProp[client] = EntIndexToEntRef(iEnt);
                    g_iLastPropCost[client]    = item.cost;

                    PrintToChat(client, "%s[!props]%s Purchased %s%s%s for %s$%d%s.",
                                COLOR_GREEN, COLOR_DEFAULT, COLOR_HIGHLIGHT, item.name, COLOR_DEFAULT, COLOR_YELLOW, item.cost, COLOR_DEFAULT);
                }
                else
                {
                    SetClientCash(client, iCash);
                    PrintToChat(client, "%s[!props]%s Failed to spawn %s%s%s. Money refunded.",
                                COLOR_GREEN, COLOR_DEFAULT, COLOR_HIGHLIGHT, item.name, COLOR_DEFAULT);
                }
            }
            else
            {
                PrintToChat(client, "%s[!props]%s You do not have enough cash (%s$%d%s required).",
                            COLOR_GREEN, COLOR_DEFAULT, COLOR_YELLOW, item.cost, COLOR_DEFAULT);
            }
        }

        OpenPropMenu(client, GetMenuSelectionPosition());
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

// ------------------------------------------------------------------
//  Refund Logic
// ------------------------------------------------------------------

void ExecuteRefund(int client)
{
    if (g_iLastSpawnedProp[client] == -1)
    {
        PrintToChat(client, "%s[!props]%s You have no recent prop purchases to refund.", COLOR_GREEN, COLOR_DEFAULT);
        return;
    }

    int iEnt = EntRefToEntIndex(g_iLastSpawnedProp[client]);

    if (iEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEnt))
    {
        RemoveEntity(iEnt);
    }

    int iRefundAmount = g_iLastPropCost[client];
    SetClientCash(client, GetClientCash(client) + iRefundAmount);

    PrintToChat(client, "%s[!props]%s Refunded %s$%d%s for your last purchase.",
                COLOR_GREEN, COLOR_DEFAULT, COLOR_YELLOW, iRefundAmount, COLOR_DEFAULT);

    ResetClientHistory(client);
}

// ------------------------------------------------------------------
//  Entity Spawning & Positioning Helpers
// ------------------------------------------------------------------

int SpawnItemAtView(int client, const PropItem item)
{
    float fHitPos[3], fNormal[3];
    if (!TraceLookPosition(client, fHitPos, fNormal))
        return -1;

    float fAngles[3];
    GetClientEyeAngles(client, fAngles);
    fAngles[0] = 0.0;
    fAngles[2] = 0.0;

    float spawnPos[3];
    spawnPos[0] = fHitPos[0];
    spawnPos[1] = fHitPos[1];
    spawnPos[2] = fHitPos[2];

    int iTeam   = GetClientTeam(client);
    if (iTeam <= 1) iTeam = 2;
    char team[2];
    IntToString(iTeam, team, 2);

    int iEnt = -1;

    if (StrEqual(item.type, "sentry", false))
    {
        iEnt = SpawnEngineerBuilding("obj_sentrygun", team, item.health, spawnPos, fAngles);
    }
    else if (StrEqual(item.type, "dispenser", false))
    {
        iEnt = SpawnEngineerBuilding("obj_dispenser", team, item.health, spawnPos, fAngles);
    }
    else
    {
        iEnt = CreatePhysicsEntity(item);
        TeleportToSurface(client, iEnt, fHitPos, fNormal);
    }

    if (iEnt == -1 || !IsValidEntity(iEnt))
        return -1;

    return iEnt;
}

int SpawnEngineerBuilding(const char[] className, const char[] team, int health, const float position[3], const float angle[3])
{
    int building = CreateEntityByName(className);
    if (!IsValidEntity(building))
        return -1;

    DispatchKeyValueVector(building, "origin", position);
    DispatchKeyValueVector(building, "angles", angle);
    DispatchKeyValue(building, "teamnum", team);
    DispatchKeyValue(building, "defaultupgrade", "2");
    DispatchKeyValue(building, "spawnflags", "8");

    DispatchSpawn(building);
    ActivateEntity(building);

    if (health > 0)
    {
        DataPack pack = new DataPack();
        pack.WriteCell(EntIndexToEntRef(building));
        pack.WriteCell(health);
        CreateTimer(0.1, Timer_SetHealthOnMaxLevel, pack, TIMER_REPEAT);
    }

    return building;
}

public Action Timer_SetHealthOnMaxLevel(Handle timer, DataPack pack)
{
    pack.Reset();
    int entityRef = pack.ReadCell();
    int health    = pack.ReadCell();

    int entity    = EntRefToEntIndex(entityRef);
    if (entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity))
    {
        delete pack;
        return Plugin_Stop;
    }

    int upgradeLevel = GetEntProp(entity, Prop_Send, "m_iUpgradeLevel");
    if (upgradeLevel >= 3)
    {
        SetEntProp(entity, Prop_Send, "m_iMaxHealth", health);
        SetEntProp(entity, Prop_Send, "m_iHealth", health);
        SetEntProp(entity, Prop_Data, "m_iMaxHealth", health);
        SetEntProp(entity, Prop_Data, "m_iHealth", health);

        SetVariantInt(health);
        AcceptEntityInput(entity, "SetHealth");

        delete pack;
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

int CreatePhysicsEntity(const PropItem item)
{
    int entity = CreateEntityByName("prop_physics_override");
    if (!IsValidEntity(entity))
        return -1;

    DispatchKeyValue(entity, "model", item.model);

    if (item.health > 0)
    {
        char sHealth[16];
        IntToString(item.health, sHealth, sizeof(sHealth));
        DispatchKeyValue(entity, "health", sHealth);
    }

    if (StrEqual(item.type, "explosive", false))
    {
        char sDmg[16], sRad[16];
        IntToString(item.explodeDamage, sDmg, sizeof(sDmg));
        IntToString(item.explodeRadius, sRad, sizeof(sRad));

        DispatchKeyValue(entity, "ExplodeDamage", sDmg);
        DispatchKeyValue(entity, "ExplodeRadius", sRad);
    }

    DispatchSpawn(entity);
    ActivateEntity(entity);

    return entity;
}

bool TraceLookPosition(int client, float pos[3], float normal[3])
{
    float eyeOrigin[3], eyeAngles[3];
    GetClientEyePosition(client, eyeOrigin);
    GetClientEyeAngles(client, eyeAngles);

    Handle trace = TR_TraceRayFilterEx(eyeOrigin, eyeAngles, MASK_SOLID, RayType_Infinite, FilterPlayer);

    if (!TR_DidHit(trace))
    {
        delete trace;
        return false;
    }

    TR_GetEndPosition(pos, trace);
    TR_GetPlaneNormal(trace, normal);
    delete trace;
    return true;
}

void TeleportToSurface(int client, int entity, const float hitPos[3], const float normal[3])
{
    float mins[3], maxs[3], angles[3], spawnPos[3];
    GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
    GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);

    GetClientAbsAngles(client, angles);
    angles[0]    = 0.0;
    angles[2]    = 0.0;

    float offset = FloatAbs(mins[2]) + 1.0;

    spawnPos[0]  = hitPos[0] + (normal[0] * offset);
    spawnPos[1]  = hitPos[1] + (normal[1] * offset);
    spawnPos[2]  = hitPos[2] + (normal[2] * offset);

    TeleportEntity(entity, spawnPos, angles, NULL_VECTOR);
}

// ------------------------------------------------------------------
//  Helpers & MvM Currency API
// ------------------------------------------------------------------

int GetClientCash(int client)
{
    return GetEntProp(client, Prop_Send, "m_nCurrency");
}

void SetClientCash(int client, int amount)
{
    SetEntProp(client, Prop_Send, "m_nCurrency", amount);
}

void ResetClientHistory(int client)
{
    g_iLastSpawnedProp[client] = -1;
    g_iLastPropCost[client]    = 0;
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

bool FilterPlayer(int entity, int contentsMask)
{
    return (entity > MaxClients);
}