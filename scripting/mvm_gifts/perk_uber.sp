ConVar g_cvPerkUberEnabled;
ConVar g_cvPerkUberDuration;

void   Perk_Uber_Init()
{
    g_cvPerkUberEnabled  = CreateConVar("sm_mvm_gift_uber_enabled", "1", "Enable Uber buff perk?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvPerkUberDuration = CreateConVar("sm_mvm_gift_uber_duration", "30.0", "Duration of the Uber buff.", FCVAR_NOTIFY, true, 1.0);
}

void Perk_Uber_Clear(int client)
{
    if (IsValidClient(client))
    {
        TF2_RemoveCondition(client, TFCond_UberchargedCanteen);
    }
}

void Perk_Uber_Apply(int client, char[] buffName, int maxLenBuff, char[] expireMsg, int maxLenExpire, float &duration, float flRemaining = 0.0)
{
    float baseDuration = g_cvPerkUberDuration.FloatValue;
    duration           = baseDuration + flRemaining;
    TF2_AddCondition(client, TFCond_Ubercharged, duration);
    Format(buffName, maxLenBuff, "Ubercharge for %.0f seconds", duration);
    strcopy(expireMsg, maxLenExpire, "Ubercharge has worn off");
}