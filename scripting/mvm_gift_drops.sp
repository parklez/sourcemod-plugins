#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.0.0"
#define MODEL_GIFT     "models/items/tf_gift.mdl"
#define SOUND_PICKUP   "items/gunpickup2.wav"

// ------------------------------------------------------------------------
// Color & String Definitions
// ------------------------------------------------------------------------
#define CHAT_TAG       "\x01[\x04Gift\x01]"
#define COLOR_TEXT     "\x01"
#define COLOR_PLAYER   "\x03"
#define COLOR_VALUE    "\x04"

// ------------------------------------------------------------------------
// Helpers
// ------------------------------------------------------------------------
bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

// ------------------------------------------------------------------------
// Enums & Globals
// ------------------------------------------------------------------------
enum struct GiftData
{
    int   entRef;
    float spawnTime;
}

#define NUM_PERKS 6

enum
{
    PERK_CRIT = 0,
    PERK_CASH,
    PERK_UBER,
    PERK_AMMO,
    PERK_SPEED,
    PERK_INSTAKILL
};

ArrayList g_aGifts;
Handle    g_hPerkTimers[MAXPLAYERS + 1][NUM_PERKS];
float     g_flPerkEndTime[MAXPLAYERS + 1][NUM_PERKS];

// General ConVars
ConVar    g_cvDropChance;
ConVar    g_cvGiftLifetime;
ConVar    g_cvGiftFadeSpeed;
ConVar    g_cvStackDuration;

// ------------------------------------------------------------------------
// Perk Modules
// ------------------------------------------------------------------------
#include "mvm_gifts/perk_crit.sp"
#include "mvm_gifts/perk_cash.sp"
#include "mvm_gifts/perk_uber.sp"
#include "mvm_gifts/perk_ammo.sp"
#include "mvm_gifts/perk_speed.sp"
#include "mvm_gifts/perk_instakill.sp"

public Plugin myinfo =
{
    name        = "[TF2 MvM] Gift Drops",
    author      = "parklez",
    description = "Bots drop presents containing random buffs in MvM.",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/parklez/sourcemod-plugins"
};

// ------------------------------------------------------------------------
// Plugin Setup
// ------------------------------------------------------------------------
public void OnPluginStart()
{
    // General Settings
    g_cvDropChance    = CreateConVar("sm_mvm_gift_chance", "5.0", "Percentage chance (0-100) for a bot to drop a gift on death.", FCVAR_NOTIFY, true, 0.0, true, 100.0);
    g_cvGiftLifetime  = CreateConVar("sm_mvm_gift_lifetime", "30.0", "How long (in seconds) before the gift disappears.", FCVAR_NOTIFY, true, 1.0);
    g_cvGiftFadeSpeed = CreateConVar("sm_mvm_gift_fade_speed", "5.0", "How many seconds before expiring should the gift start fading.", FCVAR_NOTIFY, true, 0.1);
    g_cvStackDuration = CreateConVar("sm_mvm_gift_stack_duration", "0", "Stack perk duration on duplicate pickups (1) or reset timer (0).", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    // Initialize Perk ConVars and Hooks
    Perk_Crit_Init();
    Perk_Cash_Init();
    Perk_Uber_Init();
    Perk_Ammo_Init();
    Perk_Speed_Init();
    Perk_InstaKill_Init();

    AutoExecConfig(true, "mvm_gift_drops");

    // Arrays & Events
    g_aGifts = new ArrayList(sizeof(GiftData));
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("mvm_wave_complete", Event_WaveEnd);
    HookEvent("teamplay_round_win", Event_WaveEnd);

    // Setup late-load hooks
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            OnClientPutInServer(i);
        }
    }

    CreateTimer(0.1, Timer_UpdateGifts, _, TIMER_REPEAT);
}

public void OnMapStart()
{
    PrecacheModel(MODEL_GIFT, true);
    PrecacheSound(SOUND_PICKUP, true);
}

public void OnClientPutInServer(int client)
{
    ClearAllBuffs(client);

    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    SDKHook(client, SDKHook_PreThink, SDKHooks_OnPreThink);
}

public void OnClientDisconnect(int client)
{
    ClearAllBuffs(client);
}

public void OnEntityDestroyed(int entity)
{
    if (entity <= MaxClients || entity > 2048) return;

    if (g_aGifts != null)
    {
        int ref   = EntIndexToEntRef(entity);
        int index = g_aGifts.FindValue(ref, 0);
        if (index != -1)
        {
            g_aGifts.Erase(index);
        }
    }
}

// ------------------------------------------------------------------------
// Cleanup Logic
// ------------------------------------------------------------------------
void ClearAllBuffs(int client)
{
    bool hadBuffs = false;
    for (int perk = 0; perk < NUM_PERKS; perk++)
    {
        if (g_hPerkTimers[client][perk] != null)
        {
            KillTimer(g_hPerkTimers[client][perk]);
            g_hPerkTimers[client][perk] = null;
            hadBuffs = true;
        }
        g_flPerkEndTime[client][perk] = 0.0;
    }

    Perk_Crit_Clear(client);
    Perk_Uber_Clear(client);
    Perk_Ammo_Clear(client);
    Perk_Speed_Clear(client);
    Perk_InstaKill_Clear(client);

    if (hadBuffs && IsClientInGame(client))
    {
        PrintToChat(client, "%s Your effects expired!", CHAT_TAG, COLOR_TEXT);
    }
}

void ClearPerkEffect(int client, int perkId)
{
    switch (perkId)
    {
        case PERK_CRIT: Perk_Crit_Clear(client);
        case PERK_UBER: Perk_Uber_Clear(client);
        case PERK_AMMO: Perk_Ammo_Clear(client);
        case PERK_SPEED: Perk_Speed_Clear(client);
        case PERK_INSTAKILL: Perk_InstaKill_Clear(client);
    }
}

// ------------------------------------------------------------------------
// Damage Hook
// ------------------------------------------------------------------------
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
    if (Perk_InstaKill_OnTakeDamage(attacker, damage))
    {
        return Plugin_Changed;
    }
    return Plugin_Continue;
}

// ------------------------------------------------------------------------
// Drop Logic & Events
// ------------------------------------------------------------------------
bool ClientHasBuffs(int client)
{
    for (int perk = 0; perk < NUM_PERKS; perk++)
    {
        if (g_hPerkTimers[client][perk] != null || g_flPerkEndTime[client][perk] > GetGameTime())
        {
            return true;
        }
    }
    return false;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidClient(victim))
        return Plugin_Continue;

    if (!IsFakeClient(victim) && ClientHasBuffs(victim))
    {
        ClearAllBuffs(victim);
        return Plugin_Continue;
    }

    if (GetRandomFloat(0.0, 100.0) <= g_cvDropChance.FloatValue)
    {
        SpawnGift(victim);
    }

    return Plugin_Continue;
}

public Action Event_WaveEnd(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && !IsFakeClient(i) && ClientHasBuffs(i))
        {
            ClearAllBuffs(i);
        }
    }
    return Plugin_Continue;
}

void SpawnGift(int client)
{
    int gift = CreateEntityByName("prop_dynamic_override");
    if (gift == -1) return;

    float pos[3];
    GetClientAbsOrigin(client, pos);
    pos[2] += 20.0;

    DispatchKeyValue(gift, "model", MODEL_GIFT);
    DispatchSpawn(gift);

    TeleportEntity(gift, pos, NULL_VECTOR, NULL_VECTOR);
    SetEntProp(gift, Prop_Send, "m_nSolidType", 2);
    SetEntProp(gift, Prop_Send, "m_usSolidFlags", 12);
    SetEntProp(gift, Prop_Send, "m_CollisionGroup", 11);

    SetEntityRenderMode(gift, RENDER_TRANSCOLOR);
    SetEntityRenderColor(gift, 255, 255, 255, 255);

    GiftData data;
    data.entRef    = EntIndexToEntRef(gift);
    data.spawnTime = GetGameTime();
    g_aGifts.PushArray(data);

    SDKHook(gift, SDKHook_StartTouch, OnGiftTouch);
    CreateTimer(g_cvGiftLifetime.FloatValue, Timer_RemoveGift, EntIndexToEntRef(gift), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_RemoveGift(Handle timer, int entRef)
{
    int entity = EntRefToEntIndex(entRef);
    if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
    {
        AcceptEntityInput(entity, "Kill");
    }
    return Plugin_Stop;
}

public Action Timer_UpdateGifts(Handle timer)
{
    if (g_aGifts.Length == 0) return Plugin_Continue;

    float currentTime = GetGameTime();
    float lifetime    = g_cvGiftLifetime.FloatValue;
    float fadeSpeed   = g_cvGiftFadeSpeed.FloatValue;

    for (int i = 0; i < g_aGifts.Length; i++)
    {
        GiftData data;
        g_aGifts.GetArray(i, data);

        int gift = EntRefToEntIndex(data.entRef);
        if (gift != INVALID_ENT_REFERENCE && IsValidEntity(gift))
        {
            // Rotation logic
            float angles[3];
            GetEntPropVector(gift, Prop_Data, "m_angRotation", angles);
            angles[1] += 10.0;
            if (angles[1] >= 360.0) angles[1] -= 360.0;
            TeleportEntity(gift, NULL_VECTOR, angles, NULL_VECTOR);

            // Fade Out logic
            float timeAlive     = currentTime - data.spawnTime;
            float timeRemaining = lifetime - timeAlive;

            if (timeRemaining <= fadeSpeed && timeRemaining > 0.0)
            {
                int alpha = RoundToFloor((timeRemaining / fadeSpeed) * 255.0);
                if (alpha < 0) alpha = 0;

                SetEntityRenderColor(gift, 255, 255, 255, alpha);
            }
        }
    }
    return Plugin_Continue;
}

// ------------------------------------------------------------------------
// Touch & Buff Logic
// ------------------------------------------------------------------------
public Action OnGiftTouch(int entity, int other)
{
    if (!IsValidClient(other) || !IsPlayerAlive(other) || IsFakeClient(other))
        return Plugin_Continue;

    SDKUnhook(entity, SDKHook_StartTouch, OnGiftTouch);

    EmitSoundToAll(SOUND_PICKUP, other, SNDCHAN_ITEM, SNDLEVEL_NORMAL);

    AcceptEntityInput(entity, "Kill");
    GiveRandomBuff(other);

    return Plugin_Continue;
}

void GiveRandomBuff(int client)
{
    ArrayList aActivePerks = new ArrayList();

    if (g_cvPerkCritEnabled.BoolValue) aActivePerks.Push(PERK_CRIT);
    if (g_cvPerkCashEnabled.BoolValue) aActivePerks.Push(PERK_CASH);
    if (g_cvPerkUberEnabled.BoolValue) aActivePerks.Push(PERK_UBER);
    if (g_cvPerkAmmoEnabled.BoolValue) aActivePerks.Push(PERK_AMMO);
    if (g_cvPerkSpeedEnabled.BoolValue) aActivePerks.Push(PERK_SPEED);
    if (g_cvPerkInstaKillEnabled.BoolValue) aActivePerks.Push(PERK_INSTAKILL);

    if (aActivePerks.Length == 0)
    {
        delete aActivePerks;
        return;
    }

    int perkId = aActivePerks.Get(GetRandomInt(0, aActivePerks.Length - 1));
    delete aActivePerks;

    char  buffName[64];
    char  expireMsg[64];
    float duration    = 0.0;

    float flRemaining = 0.0;
    if (g_cvStackDuration.BoolValue)
    {
        flRemaining = g_flPerkEndTime[client][perkId] - GetGameTime();
        if (flRemaining < 0.0)
        {
            flRemaining = 0.0;
        }
    }

    if (g_hPerkTimers[client][perkId] != null)
    {
        KillTimer(g_hPerkTimers[client][perkId]);
        g_hPerkTimers[client][perkId] = null;
    }

    switch (perkId)
    {
        case PERK_CRIT: Perk_Crit_Apply(client, buffName, sizeof(buffName), expireMsg, sizeof(expireMsg), duration, flRemaining);
        case PERK_CASH: Perk_Cash_Apply(client, buffName, sizeof(buffName), expireMsg, sizeof(expireMsg), duration);
        case PERK_UBER: Perk_Uber_Apply(client, buffName, sizeof(buffName), expireMsg, sizeof(expireMsg), duration, flRemaining);
        case PERK_AMMO: Perk_Ammo_Apply(client, buffName, sizeof(buffName), expireMsg, sizeof(expireMsg), duration, flRemaining);
        case PERK_SPEED: Perk_Speed_Apply(client, buffName, sizeof(buffName), expireMsg, sizeof(expireMsg), duration, flRemaining);
        case PERK_INSTAKILL: Perk_InstaKill_Apply(client, buffName, sizeof(buffName), expireMsg, sizeof(expireMsg), duration, flRemaining);
    }

    PrintToChatAll("%s %s%N%s picked up a gift and got: %s%s%s!",
                   CHAT_TAG, COLOR_PLAYER, client, COLOR_TEXT, COLOR_VALUE, buffName, COLOR_TEXT);

    if (duration > 0.0)
    {
        g_flPerkEndTime[client][perkId] = GetGameTime() + duration;

        DataPack pack;
        g_hPerkTimers[client][perkId] = CreateDataTimer(duration, Timer_BuffExpire, pack, TIMER_FLAG_NO_MAPCHANGE);
        pack.WriteCell(GetClientUserId(client));
        pack.WriteCell(perkId);
        pack.WriteString(expireMsg);
    }
}

// ------------------------------------------------------------------------
// Expiration Announcer
// ------------------------------------------------------------------------
public Action Timer_BuffExpire(Handle timer, DataPack pack)
{
    pack.Reset();
    int  userid = pack.ReadCell();
    int  perkId = pack.ReadCell();
    char expireMsg[64];
    pack.ReadString(expireMsg, sizeof(expireMsg));

    int client = GetClientOfUserId(userid);

    if (IsValidClient(client))
    {
        g_hPerkTimers[client][perkId]   = null;
        g_flPerkEndTime[client][perkId] = 0.0;

        ClearPerkEffect(client, perkId);

        if (IsPlayerAlive(client) && expireMsg[0] != '\0')
        {
            PrintToChat(client, "%s %sYour %s%s%s.",
                        CHAT_TAG, COLOR_TEXT, COLOR_VALUE, expireMsg, COLOR_TEXT);
        }
    }

    return Plugin_Stop;
}