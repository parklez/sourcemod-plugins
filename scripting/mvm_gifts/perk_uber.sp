ConVar g_cvPerkUberEnabled;
ConVar g_cvPerkUberDuration;

void Perk_Uber_Init()
{
    g_cvPerkUberEnabled = CreateConVar("sm_mvm_gift_uber_enabled", "1", "Enable Uber buff perk?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvPerkUberDuration = CreateConVar("sm_mvm_gift_uber_duration", "30.0", "Duration of the Uber buff.", FCVAR_NOTIFY, true, 1.0);
}

void Perk_Uber_Clear(int client)
{
    if (IsValidClient(client))
    {
        TF2_RemoveCondition(client, TFCond_Ubercharged);
    }
}

void Perk_Uber_Apply(int client, char[] buffName, int maxLenBuff, char[] expireMsg, int maxLenExpire, float &duration)
{
    duration = g_cvPerkUberDuration.FloatValue;
    TF2_AddCondition(client, TFCond_Ubercharged, duration);
    Format(buffName, maxLenBuff, "Invincibility for %.0f seconds", duration);
    strcopy(expireMsg, maxLenExpire, "Invincibility has worn off");
}