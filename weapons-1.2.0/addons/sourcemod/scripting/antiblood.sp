#include <sdktools>
#pragma semicolon 1
#pragma newdecls required

ConVar g_cEnableNoBlood;
static int table;
public Plugin myinfo = 
{
	name = "Anit blood",
	author = "Bara, IT-KiLLER",
	description = "Hide blood",
	version = "1.0",
	url = "https://github.com/IT-KiLLER"
};

public void OnPluginStart()
{
	g_cEnableNoBlood = CreateConVar("sm_blood_disable", "1", "Enable / Disable No Blood", _, true, 0.0, true, 1.0);
	//AddTempEntHook("Blood Sprite", TE_OnWorldDecal);
	AddTempEntHook("Entity Decal", TE_OnWorldDecal);
	AddTempEntHook("World Decal", TE_OnWorldDecal);
	AddTempEntHook("Impact", TE_OnWorldDecal);
}
public void OnMapStart()
{
	table = FindStringTable("decalprecache");
}

public Action TE_OnWorldDecal(const char[] te_name, const Players[], int numClients, float delay)
{
	if (!g_cEnableNoBlood.BoolValue) return Plugin_Continue;

	float vecOrigin[3];
	int nIndex = TE_ReadNum("m_nIndex");
	char sDecalName[64];

	TE_ReadVector("m_vecOrigin", vecOrigin);
	GetDecalName(nIndex, sDecalName, sizeof(sDecalName));

	if (StrContains(sDecalName, "decals/blood") == 0 && StrContains(sDecalName, "_subrect") != -1)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

stock int GetDecalName(int index, char[] sDecalName, int maxlen)
{
	
	return ReadStringTable(table, index, sDecalName, maxlen);
}