#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#include <tf2attributes>

#pragma newdecls required

#define ATTRIB_FIRE_RATE    6
#define ATTRIB_RELOAD_SPEED 97

ConVar g_cvPerkAmmoEnabled;
ConVar g_cvPerkAmmoDuration;
ConVar g_cvPerkAmmoFireRateMult;
float  g_flInfiniteAmmoEnd[MAXPLAYERS + 1];

#define MAX_ENTITIES 2048

float g_flWeaponBaseFireRate[MAX_ENTITIES];
float g_flWeaponBaseReloadSpeed[MAX_ENTITIES];
int   g_iWeaponBoostRef[MAX_ENTITIES];

void   Perk_Ammo_Init()
{
    g_cvPerkAmmoEnabled      = CreateConVar("sm_mvm_gift_ammo_enabled", "1", "Enable Infinite Ammo perk?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvPerkAmmoDuration     = CreateConVar("sm_mvm_gift_ammo_duration", "30.0", "Duration of the Infinite Ammo buff.", FCVAR_NOTIFY, true, 1.0);
    g_cvPerkAmmoFireRateMult = CreateConVar("sm_mvm_gift_ammo_firerate", "2.0", "Fire rate multiplier during Infinite Ammo buff (e.g. 2.0 = 2x faster).", FCVAR_NOTIFY, true, 1.0);

    // Apply PreThink hooks for players already on the server if the plugin is late-loaded
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            OnClientPutInServer(i);
        }
    }
}

void Perk_Ammo_Clear(int client)
{
    g_flInfiniteAmmoEnd[client] = 0.0;
    Perk_Ammo_RemoveFireRate(client);
}

void Perk_Ammo_Apply(int client, char[] buffName, int maxLenBuff, char[] expireMsg, int maxLenExpire, float &duration, float flRemaining = 0.0)
{
    float baseDuration          = g_cvPerkAmmoDuration.FloatValue;
    duration                    = baseDuration + flRemaining;

    // Set the expiration time to be evaluated inside OnPreThink
    g_flInfiniteAmmoEnd[client] = GetGameTime() + duration;

    Perk_Ammo_ApplyFireRate(client);

    Format(buffName, maxLenBuff, "Infinite Ammo for %.0f seconds", duration);
    strcopy(expireMsg, maxLenExpire, "Infinite Ammo has worn off");
}

public void SDKHooks_OnPreThink(int client)
{
    // Evaluate if the client is alive and their buff is still active
    if (IsPlayerAlive(client) && GetGameTime() <= g_flInfiniteAmmoEnd[client])
    {
        // Loop through Primary, Secondary, and Melee slots
        for (int slot = 0; slot <= 2; slot++)
        {
            int weapon = GetPlayerWeaponSlot(client, slot);
            if (weapon != -1)
            {
                GiveInfiniteAmmo(client, weapon);
            }
        }
        Perk_Ammo_ApplyFireRate(client);
    }
}

void Perk_Ammo_ApplyFireRate(int client)
{
    float mult = g_cvPerkAmmoFireRateMult.FloatValue;
    if (mult <= 0.0) return;

    for (int i = 0; i <= 2; i++)
    {
        int weapon = GetPlayerWeaponSlot(client, i);
        if (weapon > MaxClients && weapon < MAX_ENTITIES && IsValidEntity(weapon))
        {
            int ref = EntIndexToEntRef(weapon);
            if (g_iWeaponBoostRef[weapon] != ref)
            {
                Address pAttrFire = TF2Attrib_GetByDefIndex(weapon, ATTRIB_FIRE_RATE);
                g_flWeaponBaseFireRate[weapon] = (pAttrFire != Address_Null) ? TF2Attrib_GetValue(pAttrFire) : 1.0;
                
                Address pAttrReload = TF2Attrib_GetByDefIndex(weapon, ATTRIB_RELOAD_SPEED);
                g_flWeaponBaseReloadSpeed[weapon] = (pAttrReload != Address_Null) ? TF2Attrib_GetValue(pAttrReload) : 1.0;
                
                g_iWeaponBoostRef[weapon] = ref;
            }
            
            TF2Attrib_SetByDefIndex(weapon, ATTRIB_FIRE_RATE, g_flWeaponBaseFireRate[weapon] / mult);
            TF2Attrib_SetByDefIndex(weapon, ATTRIB_RELOAD_SPEED, g_flWeaponBaseReloadSpeed[weapon] / mult);
        }
    }
}

void Perk_Ammo_RemoveFireRate(int client)
{
    if (IsValidClient(client))
    {
        for (int i = 0; i <= 2; i++)
        {
            int weapon = GetPlayerWeaponSlot(client, i);
            if (weapon > MaxClients && weapon < MAX_ENTITIES && IsValidEntity(weapon))
            {
                int ref = EntIndexToEntRef(weapon);
                if (g_iWeaponBoostRef[weapon] == ref)
                {
                    if (g_flWeaponBaseFireRate[weapon] == 1.0)
                        TF2Attrib_RemoveByDefIndex(weapon, ATTRIB_FIRE_RATE);
                    else
                        TF2Attrib_SetByDefIndex(weapon, ATTRIB_FIRE_RATE, g_flWeaponBaseFireRate[weapon]);

                    if (g_flWeaponBaseReloadSpeed[weapon] == 1.0)
                        TF2Attrib_RemoveByDefIndex(weapon, ATTRIB_RELOAD_SPEED);
                    else
                        TF2Attrib_SetByDefIndex(weapon, ATTRIB_RELOAD_SPEED, g_flWeaponBaseReloadSpeed[weapon]);

                    g_iWeaponBoostRef[weapon] = 0;
                }
            }
        }
    }
}

void GiveInfiniteAmmo(int client, int weapon)
{
    if (!IsValidEntity(weapon))
    {
        return;
    }

    // 1. Reserve Ammo Logic (Fixes Snipers and Miniguns)
    // Uses Prop_Send for m_iPrimaryAmmoType and Prop_Data for m_iAmmo as done in the reference plugin
    int iAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    if (iAmmoType != -1)
    {
        SetEntProp(client, Prop_Data, "m_iAmmo", 666, _, iAmmoType);
    }

    // 2. Clip Logic
    // Uses Prop_Data for m_iClip1 as done in the reference plugin
    if (HasEntProp(weapon, Prop_Data, "m_iClip1"))
    {
        // Only attempt to set the clip if the weapon actually uses clips (not -1)
        if (GetEntProp(weapon, Prop_Data, "m_iClip1") != -1)
        {
            SetEntProp(weapon, Prop_Data, "m_iClip1", 99);
        }
    }

    // 3. Energy Weapon Logic (Cow Mangler, Righteous Bison, Pomson)
    // Uses Prop_Send for m_flEnergy as done in the reference plugin
    if (HasEntProp(weapon, Prop_Send, "m_flEnergy"))
    {
        SetEntPropFloat(weapon, Prop_Send, "m_flEnergy", 100.0);
    }
}