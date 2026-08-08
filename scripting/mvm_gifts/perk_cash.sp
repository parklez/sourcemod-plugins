ConVar g_cvPerkCashEnabled;
ConVar g_cvPerkCashAmount;

void Perk_Cash_Init()
{
    g_cvPerkCashEnabled = CreateConVar("sm_mvm_gift_cash_enabled", "1", "Enable Cash perk?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvPerkCashAmount = CreateConVar("sm_mvm_gift_cash_amount", "1000", "Amount of cash given.", FCVAR_NOTIFY, true, 1.0);
}

void Perk_Cash_Apply(int client, char[] buffName, int maxLenBuff, char[] expireMsg, int maxLenExpire, float &duration)
{
    duration = 0.0;
    int cash = GetEntProp(client, Prop_Send, "m_nCurrency");
    int amount = g_cvPerkCashAmount.IntValue;
    SetEntProp(client, Prop_Send, "m_nCurrency", cash + amount);
    Format(buffName, maxLenBuff, "$%d Cash", amount);
    strcopy(expireMsg, maxLenExpire, "");
}