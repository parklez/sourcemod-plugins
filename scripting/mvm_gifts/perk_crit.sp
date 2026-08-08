ConVar g_cvPerkCritEnabled;
ConVar g_cvPerkCritDuration;

void Perk_Crit_Init()
{
    g_cvPerkCritEnabled = CreateConVar("sm_mvm_gift_crit_enabled", "1", "Enable Crit buff perk?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvPerkCritDuration = CreateConVar("sm_mvm_gift_crit_duration", "60.0", "Duration of the Crit buff.", FCVAR_NOTIFY, true, 1.0);
}

void Perk_Crit_Clear(int client)
{
    if (IsValidClient(client))
    {
        TF2_RemoveCondition(client, TFCond_Kritzkrieged);
    }
}

void Perk_Crit_Apply(int client, char[] buffName, int maxLenBuff, char[] expireMsg, int maxLenExpire, float &duration)
{
    duration = g_cvPerkCritDuration.FloatValue;
    TF2_AddCondition(client, TFCond_Kritzkrieged, duration);
    Format(buffName, maxLenBuff, "Critically Boosted for %.0f seconds", duration);
    strcopy(expireMsg, maxLenExpire, "Crit Boost has worn off");
}