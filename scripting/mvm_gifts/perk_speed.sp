ConVar g_cvPerkSpeedEnabled;
ConVar g_cvPerkSpeedDuration;

void Perk_Speed_Init()
{
    g_cvPerkSpeedEnabled = CreateConVar("sm_mvm_gift_speed_enabled", "1", "Enable Speed & Regen buff perk?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvPerkSpeedDuration = CreateConVar("sm_mvm_gift_speed_duration", "60.0", "Duration of the Speed & Regen buff.", FCVAR_NOTIFY, true, 1.0);
}

void Perk_Speed_Clear(int client)
{
    if (IsValidClient(client))
    {
        TF2_RemoveCondition(client, TFCond_SpeedBuffAlly); 
        TF2_RemoveCondition(client, TFCond_HalloweenQuickHeal); 
    }
}

void Perk_Speed_Apply(int client, char[] buffName, int maxLenBuff, char[] expireMsg, int maxLenExpire, float &duration)
{
    duration = g_cvPerkSpeedDuration.FloatValue;
    TF2_AddCondition(client, TFCond_SpeedBuffAlly, duration); 
    TF2_AddCondition(client, TFCond_HalloweenQuickHeal, duration); 

    Format(buffName, maxLenBuff, "Super Speed & Regen for %.0f seconds", duration);
    strcopy(expireMsg, maxLenExpire, "Super Speed & Regen has worn off");
}