#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.0.1"

ConVar g_cvEnable;

public Plugin myinfo =
{
    name        = "[TF2 MvM] Auto Cash Pick Up",
    author      = "parklez",
    description = "Automatically teleports cash to a player.",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/parklez/sourcemod-plugins"
};

public void OnPluginStart()
{
    g_cvEnable = CreateConVar("sm_mvm_cash_pickup_enable", "1", "Enable auto cash pickup", FCVAR_NONE, true, 0.0, true, 1.0);
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (strncmp(classname, "item_currencypack_", 18) == 0)
        SDKHook(entity, SDKHook_SpawnPost, MoneyCreated);
}

public void MoneyCreated(int entity)
{
    if (!g_cvEnable.BoolValue)
        return;

    if (!TryTeleportMoney(entity))
        CreateTimer(0.1, Timer_TeleportMoney, EntIndexToEntRef(entity), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_TeleportMoney(Handle timer, int entityRef)
{
    if (!g_cvEnable.BoolValue || TryTeleportMoney(EntRefToEntIndex(entityRef)))
        return Plugin_Stop;

    return Plugin_Continue;
}

bool TryTeleportMoney(int entity)
{
    if (entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity))
        return true;

    static int s_iCurrentPlayer = 0;
    int        targetPlayer     = -1;

    for (int i = 0; i < MaxClients; i++)
    {
        s_iCurrentPlayer = (s_iCurrentPlayer % MaxClients) + 1;

        if (IsClientInGame(s_iCurrentPlayer) && !IsFakeClient(s_iCurrentPlayer) && IsPlayerAlive(s_iCurrentPlayer) && view_as<TFTeam>(GetClientTeam(s_iCurrentPlayer)) == TFTeam_Red)
        {
            targetPlayer = s_iCurrentPlayer;
            break;
        }
    }

    if (targetPlayer != -1)
    {
        float origin[3];
        GetClientAbsOrigin(targetPlayer, origin);
        origin[2] += 10.0;
        TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);
    }

    return false;
}