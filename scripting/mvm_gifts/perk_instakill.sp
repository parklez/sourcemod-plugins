ConVar g_cvPerkInstaKillEnabled;
ConVar g_cvPerkInstaKillDuration;
float  g_flInstaKillEnd[MAXPLAYERS + 1];

void   Perk_InstaKill_Init()
{
    g_cvPerkInstaKillEnabled  = CreateConVar("sm_mvm_gift_instakill_enabled", "1", "Enable Insta-Kill perk?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvPerkInstaKillDuration = CreateConVar("sm_mvm_gift_instakill_duration", "15.0", "Duration of the Insta-Kill buff.", FCVAR_NOTIFY, true, 1.0);
}

void Perk_InstaKill_Clear(int client)
{
    g_flInstaKillEnd[client] = 0.0;
}

bool Perk_InstaKill_OnTakeDamage(int attacker, float &damage)
{
    if (IsValidClient(attacker) && g_flInstaKillEnd[attacker] > GetGameTime())
    {
        damage = 10000.0;
        return true;
    }
    return false;
}

void Perk_InstaKill_Apply(int client, char[] buffName, int maxLenBuff, char[] expireMsg, int maxLenExpire, float &duration, float flRemaining = 0.0)
{
    float baseDuration       = g_cvPerkInstaKillDuration.FloatValue;
    duration                 = baseDuration + flRemaining;
    g_flInstaKillEnd[client] = GetGameTime() + duration;
    Format(buffName, maxLenBuff, "Insta-Kill for %.0f seconds", duration);
    strcopy(expireMsg, maxLenExpire, "Insta-Kill has worn off");
}