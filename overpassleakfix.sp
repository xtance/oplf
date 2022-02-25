#include <sdktools_entinput>
#include <sdktools_functions>
#include <sdkhooks>

static const float fParticlePos[3] = {-1166.00, -2088.00, 400.00};

bool
    bEnabled = false,
    bHooked = false,
    bFixed = false,
	bMode = true,
    bGive[MAXPLAYERS+1];
int
    iReward = 1000;

public Plugin myinfo =
{
    name        = "Overpass Leak Fix",
    version        = "0.3",
    description    = "Исправляет утечку на Overpass",
    author        = "XTANCE, Grey83",
    url            = "https://t.me/xtance"
}

public void OnPluginStart()
{
	ConVar reward = CreateConVar("sm_leakfix_reward", "1000", "OPLF Reward", _, true, _, true, 16000.0);
	reward.AddChangeHook(CV_Reward);
	iReward = reward.IntValue;
	
	ConVar mode = CreateConVar("sm_leakfix_mode", "1", "0 - enable on de_overpass, 1 - on every map", _, true, 0.0, true, 1.0);
	mode.AddChangeHook(CV_Mode);
	bMode = mode.BoolValue;
	
	RegConsoleCmd("sm_wrench", Cmd_GiveWrench, "Даёт гаечный ключ");
	RegConsoleCmd("sm_spanner", Cmd_GiveWrench, "Даёт гаечный ключ");
}

public void CV_Reward(ConVar cvar, const char[] oldValue, const char[] newValue)
{
    iReward = cvar.IntValue;
}

public void CV_Mode(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	bMode = cvar.BoolValue;
	OnMapStart();
}

public void OnMapStart()
{
    char map[64];
    GetCurrentMap(map, sizeof(map));
    GetMapDisplayName(map, map, sizeof(map));
    bEnabled = bMode || !strcmp(map, "de_overpass", false);
    if(bEnabled && !bHooked)
	{
		bHooked = HookEventEx("weapon_fire", Event_WeaponFire);
		HookEvent("round_start", Event_RoundStart);
	}
    else if (bHooked)
    {
        UnhookEvent("weapon_fire", Event_WeaponFire);
        UnhookEvent("round_start", Event_RoundStart);
        bHooked = false;
    }
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for(int i = 1; i <= MaxClients; i++) bGive[i] = false;
    bFixed = false;
}

public Action Cmd_GiveWrench(int client, int iArgs)
{
    if(!client) return Plugin_Handled;

    static int ent;
    if (!IsPlayerAlive(client)) ReplyToCommand(client, " \x07>>\x01 Надо быть живым, чтобы взять ключ.");
	else if (!bEnabled) ReplyToCommand(client, " \x07>>\x01 Команда работает только на Overpass.");
	else if (bGive[client]) ReplyToCommand(client, " \x07>>\x01 Ты уже брал гаечный ключ в этом раунде.");
	else if ((ent = GivePlayerItem(client, "weapon_spanner")) != -1)
	{
		EquipPlayerWeapon(client, ent);
		SDKHook(ent, SDKHook_StartTouch, OnStartTouch);
		bGive[client] = true;
		ReplyToCommand(client, " \x07>>\x01 Вы получили гаечный ключ.");
	}
    return Plugin_Handled;
}

public Action OnStartTouch(int ent, int client)
{
	AcceptEntityInput(ent, "Kill");
}

public void Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    static int client;
    if(bFixed || !(client = GetClientOfUserId(event.GetInt("userid"))) || IsFakeClient(client) || !IsPlayerAlive(client))
        return;

    char wpn[16];
    event.GetString("weapon", wpn, sizeof(wpn));
    if(strlen(wpn) == 14 && wpn[7] == 's' && wpn[13] == 'r')
    {
        float fPos[3], fDist;
        GetEntPropVector(client, Prop_Send, "m_vecOrigin", fPos);
        PrintToConsole(client, "%.2f, %.2f, %.2f", fPos[0], fPos[1], fPos[2]);
        if((fDist = GetVectorDistance(fParticlePos, fPos, true)) < 5000.0)
        {
            PrintToConsole(client, "Distance: %f", fDist);
            int ent = -1;
            while((ent = FindEntityByClassname(ent, "info_particle_system")) != -1)
            {
                GetEntPropVector(ent, Prop_Send, "m_vecOrigin", fPos);
                if((fDist = GetVectorDistance(fParticlePos, fPos, true)) < 5000.0) AcceptEntityInput(ent, "Kill");
            }

            ent = -1;
            while((ent = FindEntityByClassname(ent, "env_soundscape")) != -1)
            {
                GetEntPropVector(ent, Prop_Send, "m_vecOrigin", fPos);
                if((fDist = GetVectorDistance(fParticlePos, fPos, true)) < 5000.0) AcceptEntityInput(ent, "Kill");
            }

            ClientCommand(client, "play UI/panorama/case_unlock_immediate_01.wav");
            PrintToChatAll(" \x04>>\x01 %N починил трубу.", client);
            bFixed = true;

            int money = GetEntProp(client, Prop_Send, "m_iAccount") + iReward;
            if(money > 16000) money = 16000;
            SetEntProp(client, Prop_Send, "m_iAccount", money);
        }
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if(!bEnabled || IsFakeClient(client) || !IsPlayerAlive(client))
        return Plugin_Continue;

    if (buttons & IN_ATTACK2)
	{
    
        int item = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        if(item == -1) return Plugin_Continue;

        char wpn[16];
        GetEntityClassname(item, wpn, sizeof(wpn));
        if(strlen(wpn) == 14 && wpn[7] == 's' && wpn[13] == 'r')
		{
            buttons &= ~IN_ATTACK2;
            return Plugin_Changed;
        }    
    }
 
    return Plugin_Continue;
}