/****************************************************************************************************
	BanId Fix
*****************************************************************************************************

*****************************************************************************************************
	CHANGELOG: 
			0.1 - Initial Release.
			0.2 - 
				- Renamed plugin to BanIdFix
				- Internal ban system written to replace the one used by engine.
			0.3 - 
				- Find and kick the player when banid command is issued.
				- Added Updater support.
			0.4 - 
				- Fixed missing parameter causing error spam (Thanks egorka2)
			0.5 - 
				- Fixed crash if no extension is installed.
				
*****************************************************************************************************

*****************************************************************************************************
	INCLUDES.
*****************************************************************************************************/
#undef REQUIRE_EXTENSIONS
#tryinclude <ptah>
#tryinclude <connect>
#tryinclude <connecthook>

#undef REQUIRE_PLUGIN
#tryinclude <updater>

/****************************************************************************************************
	DEFINES
*****************************************************************************************************/
#define PL_VERSION "0.5"
#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsValidClient(%1))
#define UPDATE_URL    "https://bitbucket.org/SM91337/banid-fix/raw/master/addons/sourcemod/update.txt"

/****************************************************************************************************
	ETIQUETTE.
*****************************************************************************************************/
#pragma newdecls required
#pragma semicolon 1

/****************************************************************************************************
	HANDLES.
*****************************************************************************************************/
ArrayList g_alBanList = null;
Database g_dbBans = null;

/****************************************************************************************************
	STRINGS.
*****************************************************************************************************/
char g_szBanTimeout[64];

public Plugin myinfo = 
{
	name = "BanId Fix", 
	author = "SM9();", 
	version = PL_VERSION, 
	url = "www.fragdeluxe.com"
}

public void OnPluginStart()
{
	#if defined _PTaH_included
	if (LibraryExists("PTaH")) {
		PTaH(PTaH_OnClientConnect, Hook, OnClientConnectPre);
	}
	#endif
	
	if (g_alBanList != null) {
		g_alBanList.Clear();
	} else {
		g_alBanList = new ArrayList(64);
	}
	
	HookEventEx("server_addban", Event_AddBan, EventHookMode_Pre);
	AddCommandListener(Command_RemoveId, "removeid");
	AddCommandListener(Command_ListId, "listid");
	strcopy(g_szBanTimeout, 64, "NULL");
	
	#if defined _updater_included
	if (LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
	#endif
	
	LoadBans();
}

public Action Command_ListId(int iClient, const char[] szCommand, int iArgs)
{
	DBResultSet dbResult = SQL_Query(g_dbBans, "SELECT * FROM bans");
	
	char szBuffer[64];
	int iRowCount = dbResult.RowCount;
	int iFieldNum = -1;
	int iLength = -1;
	
	PrintToServer("ID filter list: %d %s", iRowCount, iRowCount <= 1 ? "entries" : "entry");
	
	for (int i = 0; i <= iRowCount; i++) {
		if (!dbResult.FetchRow()) {
			continue;
		}
		
		if (!dbResult.FieldNameToNum("authid", iFieldNum)) {
			continue;
		}
		
		if (dbResult.IsFieldNull(iFieldNum)) {
			continue;
		}
		
		dbResult.FetchString(iFieldNum, szBuffer, sizeof(szBuffer));
		
		if (!dbResult.FieldNameToNum("length", iFieldNum)) {
			continue;
		}
		
		if (dbResult.IsFieldNull(iFieldNum)) {
			continue;
		}
		
		iLength = dbResult.FetchInt(iFieldNum);
		
		if (iLength > 0) {
			PrintToServer("%s : %d minutes", szBuffer, iLength / 60);
		} else {
			PrintToServer("%s : permanent", szBuffer);
		}
	}
	
	delete dbResult;
	
	return Plugin_Handled;
}

public Action Command_RemoveId(int iClient, const char[] szCommand, int iArgs)
{
	if (iArgs < 1) {
		PrintToServer("Usage:  removeid < uniqueid >");
		return Plugin_Handled;
	}
	
	char szAuthId[64]; GetCmdArgString(szAuthId, sizeof(szAuthId));
	
	TrimString(szAuthId); StripQuotes(szAuthId);
	
	int iSplit = FindCharInString(szAuthId, '\x20');
	
	if (iSplit >= 0) {
		szAuthId[iSplit] = '\0';
	}
	
	if (StrEqual(g_szBanTimeout, szAuthId, false)) {
		strcopy(g_szBanTimeout, 64, "NULL");
		return Plugin_Continue;
	}
	
	if (UnBan(szAuthId)) {
		return Plugin_Handled;
	}
	
	PrintToServer("[BanIdFix] No ban for %s was found", szAuthId);
	return Plugin_Handled;
}

public Action Event_AddBan(Event evEvent, const char[] szEvent, bool bDontBroadcast)
{
	char szAuthId[64]; char szDuration[20];
	
	evEvent.GetString("networkid", szAuthId, sizeof(szAuthId));
	evEvent.GetString("duration", szDuration, sizeof(szDuration));
	
	int iBanTime = -1;
	int iStart = -1;
	int iLen = -1;
	
	if (StrContains(szDuration, "permanently", false) != -1) {
		iBanTime = 0;
	} else if ((iStart = FindCharInString(szDuration, '\x20')) <= 0 || (iLen = FindCharInString(szDuration[++iStart], '\x20')) <= 0) {
		return Plugin_Continue;
	} else {
		szDuration[iStart + iLen] = '\0';
		iBanTime = StringToInt(szDuration[iStart]) * 60;
	}
	
	AddBan(iBanTime, szAuthId, true);
	
	return Plugin_Handled;
}

public Action OnClientPreConnect(const char[] name, const char[] password, const char[] ip, const char[] steamID, char rejectReason[255])
{
	if (g_alBanList.FindString(steamID) != -1) {
		strcopy(rejectReason, 255, "You have been banned from this server.");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action OnClientConnectPre(const char[] sName, char sPassword[128], const char[] sIp, const char[] sSteamID, char rejectReason[512])
{
	if (g_alBanList.FindString(sSteamID) != -1) {
		strcopy(rejectReason, 512, "You have been banned from this server.");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public bool OnClientPreConnectEx(const char[] name, char password[255], const char[] ip, const char[] steamID, char rejectReason[255])
{
	if (g_alBanList.FindString(steamID) != -1) {
		strcopy(rejectReason, 255, "You have been banned from this server.");
		return false;
	}
	
	return true;
}

public void OnClientAuthorized(int iClient, const char[] szAuthId)
{
	if (g_alBanList.FindString(szAuthId) != -1) {
		KickClient(iClient, "You have been banned from this server");
	}
}

public Action Timer_RemoveBan(Handle hTimer, DataPack dPack)
{
	dPack.Reset(); char szAuthId[64]; dPack.ReadString(szAuthId, sizeof(szAuthId)); delete dPack;
	
	UnBan(szAuthId);
	return Plugin_Stop;
}

stock bool AddBan(int iTime, const char[] szAuthId, bool bAddToSQL = true)
{
	if (g_alBanList.FindString(szAuthId) != -1) {
		return false;
	}
	
	if (iTime > 0) {
		DataPack dPack = CreateDataPack(); dPack.WriteString(szAuthId); CreateTimer(float(iTime), Timer_RemoveBan, dPack); dPack.Reset();
	} else if (iTime < 0) {
		return false;
	}
	
	strcopy(g_szBanTimeout, 64, szAuthId);
	g_alBanList.PushString(szAuthId);
	ServerCommand("removeid %s", szAuthId);
	
	int iClient = FindClientByAuthId(szAuthId);
	
	if (IsValidClient(iClient)) {
		KickClient(iClient, "You have been banned from this server");
	}
	
	if (iTime == 0) {
		PrintToServer("[BanIdFix] %s was banned permanently.", szAuthId);
	} else {
		PrintToServer("[BanIdFix] %s was banned for %d minutes.", szAuthId, iTime / 60);
	}
	
	if (!bAddToSQL) {
		return true;
	}
	
	int iUnbanTime = iTime > 0 ? GetTime() + iTime : 0;
	
	char szQuery[200]; Format(szQuery, sizeof(szQuery), "INSERT INTO bans(authid, length, unbantime) VALUES ('%s','%d','%d')", szAuthId, iTime, iUnbanTime);
	
	g_dbBans.Query(Query_CallBackNull, szQuery);
	return true;
}

stock bool UnBan(const char[] szAuthId)
{
	int iBanIndex = g_alBanList.FindString(szAuthId);
	
	if (iBanIndex == -1) {
		return false;
	}
	
	g_alBanList.Erase(iBanIndex);
	
	char szQuery[200]; Format(szQuery, sizeof(szQuery), "DELETE from bans WHERE authid = '%s'", szAuthId);
	g_dbBans.Query(Query_CallBackNull, szQuery);
	
	PrintToServer("[BanIdFix] %s was unbanned.", szAuthId);
	
	return true;
}

stock bool LoadBans()
{
	char szError[200];
	
	KeyValues hKv = CreateKeyValues("bandata", "", "");
	hKv.SetString("driver", "sqlite");
	hKv.SetString("database", "BanIdFix");
	
	g_dbBans = SQL_ConnectCustom(hKv, szError, 200, false); delete hKv;
	
	if (g_dbBans == null) {
		return false;
	}
	
	if (!SQL_FastQuery(g_dbBans, 
			"CREATE TABLE IF NOT EXISTS `bans` ( \
			`id`	INTEGER PRIMARY KEY AUTOINCREMENT, \
			`authid`	BLOB NOT NULL, \
			`length`	INTEGER, \
			`unbantime`	INTEGER \
		);")) {
		return false;
	}
	
	int iCurrentTime = GetTime();
	
	char szBuffer[200]; Format(szBuffer, sizeof(szBuffer), "DELETE FROM bans WHERE unbantime <= %d AND unbantime > 0", iCurrentTime);
	
	if (!SQL_FastQuery(g_dbBans, szBuffer)) {
		return false;
	}
	
	DBResultSet dbResult = SQL_Query(g_dbBans, "SELECT * FROM bans");
	
	int iRowCount = dbResult.RowCount;
	int iFieldNum = -1;
	int iUnbanTime = -1;
	
	for (int i = 0; i <= iRowCount; i++) {
		if (!dbResult.FetchRow()) {
			continue;
		}
		
		if (!dbResult.FieldNameToNum("authid", iFieldNum)) {
			continue;
		}
		
		if (dbResult.IsFieldNull(iFieldNum)) {
			continue;
		}
		
		dbResult.FetchString(iFieldNum, szBuffer, sizeof(szBuffer));
		
		if (!dbResult.FieldNameToNum("unbantime", iFieldNum)) {
			continue;
		}
		
		if (dbResult.IsFieldNull(iFieldNum)) {
			continue;
		}
		
		iUnbanTime = dbResult.FetchInt(iFieldNum);
		
		AddBan(iUnbanTime - iCurrentTime, szBuffer, false);
	}
	
	delete dbResult;
	
	return true;
}

stock int FindClientByAuthId(const char[] szAuthId)
{
	char szTempId[64];
	
	LoopValidClients(iClient) {
		if (!IsClientAuthorized(iClient)) {
			continue;
		}
		
		if (!GetClientAuthId(iClient, AuthId_Engine, szTempId, sizeof(szTempId))) {
			continue;
		}
		
		if (StrEqual(szAuthId, szTempId, false)) {
			return iClient;
		}
	}
	
	return -1;
}

stock bool IsValidClient(int iClient)
{
	if (iClient <= 0 || iClient > MaxClients) {
		return false;
	}
	
	if (!IsClientConnected(iClient)) {
		return false;
	}
	
	return true;
}

public int Query_CallBackNull(Database dbOwner, DBResultSet dbResult, char[] szError, any aData) {  } 