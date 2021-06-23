----------------------------------------------------------------  
-- Staging Room Screen
----------------------------------------------------------------  
include( "InstanceManager" );	--InstanceManager
include( "PlayerSetupLogic" );
include( "NetworkUtilities" );
include( "ButtonUtilities" );
include( "PlayerTargetLogic" );
include( "ChatLogic" );
include( "NetConnectionIconLogic" );
include( "PopupDialog" );
include( "Civ6Common" );
include( "TeamSupport" );

local g_version = "13X"
print("Staging Room For MPH ",g_version)					
----------------------------------------------------------------  
-- Constants
---------------------------------------------------------------- 
local CountdownTypes = {
	None				= "None",
	Launch				= "Launch",						-- Standard Launch Countdown
	Launch_Instant		= "Launch_Instant",				-- Instant Launch
	WaitForPlayers		= "WaitForPlayers",				-- Used by Matchmaking games after the Ready countdown to try to fill up the game with human players before starting.
	Ready_PlayByCloud	= "Ready_PlayByCloud",
	Ready_MatchMaking	= "Ready_MatchMaking",
	Draft_MapBan 		= "Draft_MapBan",
	Draft_LeaderBan 	= "Draft_LeaderBan",
	Draft_LeaderPick 	= "Draft_LeaderPick",
	Draft_ReadyStart 	= "Draft_ReadyStart",
};

local TimerTypes = {
	Script 				= "Script",						-- Timer is internally tracked in this script.
	NetworkManager 		= "NetworkManager",				-- Timer is handled by the NetworkManager.  This is synchronized across all the clients in a matchmaking game.
};


----------------------------------------------------------------  
-- Globals
----------------------------------------------------------------  
local g_PlayerEntries = {};					-- All the current player entries, indexed by playerID.
local g_PlayerRootToPlayerID = {};  -- maps the string name of a player entry's Root control to a playerID.
local g_PlayerReady = {};			-- cached player ready status, indexed by playerID.
local g_PlayerModStatus = {};		-- cached player localized mod status strings.
local g_cachedTeams = {};				-- A cached mapping of PlayerID->TeamID.
local g_refreshing = "Refreshing"
-- MPH Variables
local m_LeaderBan:table = {} 
local g_banned_leader = nil
local g_slot_draft = 0				-- 0: RANDOM 1: Slot	2: CWC		3: NEW CWC
local g_banned_map = nil
local g_error = false
local m_nickname = ""

-- Connection / Refresh / Timer
local g_last_tick_time = nil
local g_timer = 0
local g_tick_size = 5 -- Time between refresh in second
local b_tick = false
local g_player_status = {} 


-- Visibility / Disabled controls
local g_disabled_slot_settings = false
local g_hide_player = 0				-- 0: SHOW   1: Hide    2: Partial 
local g_hide_map = true
local g_disabled_civ = false
local g_hide_vote_map = true
-- Voting Draft Constants
local g_map_script = nil
local g_map_temp = nil
local g_map_age = nil
local g_player_name = nil


local b_teamer = false
local g_phase = -1

local PHASE_DEFAULT = -1
local PHASE_INIT = 0
local PHASE_MAPBAN = 7
local PHASE_LEADERBAN = 1
local PHASE_LEADERPICK = 2
local PHASE_READY = 3
local PHASE_VOTE_BAN_MAP = 11
local PHASE_VOTE_BAN_LEADER = 12

local b_debug = true
local g_debug = false
local b_has_voted = true
local isCivPlayerName = false
local g_next_ID = nil
local g_test = nil
local g_last_team = -1
local g_ban_count = 0
local g_valid_count = 0
local g_total_players = 0
local g_all_players = 0
local b_check = false
local b_launch = false
local b_clean = true
--------------------------------------------
-- Mod Flags
--------------------------------------------
local b_mph_game = false;
local b_spec_game = false;
local b_bbg_game = false;
local b_bbs_game = false;
local s_bbs_id = "";
local s_bbg_id = "";
local b_mods_ok = false


local g_cached_playerIDs = {}
local g_map_pool = {}
local g_version_map = {}	
					   
-- end						
local m_playerTarget = { targetType = ChatTargetTypes.CHATTARGET_ALL, targetID = GetNoPlayerTargetID() };
local m_playerTargetEntries = {};
local m_ChatInstances		= {};
local m_infoTabsIM:table = InstanceManager:new("ShellTab", "TopControl", Controls.InfoTabs);
local m_shellTabIM:table = InstanceManager:new("ShellTab", "TopControl", Controls.ShellTabs);
local m_friendsIM = InstanceManager:new( "FriendInstance", "RootContainer", Controls.FriendsStack );
local m_playersIM = InstanceManager:new( "PlayerListEntry", "Root", Controls.PlayerListStack );
local g_GridLinesIM = InstanceManager:new( "HorizontalGridLine", "Control", Controls.GridContainer );
local m_gameSetupParameterIM = InstanceManager:new( "GameSetupParameter", "Root", nil );
local m_kPopupDialog:table;
local m_shownPBCReadyPopup = false;			-- Remote clients in a new PlayByCloud game get a ready-to-go popup when
											-- This variable indicates this popup has already been shown in this instance
											-- of the staging room.
local m_savePBCReadyChoice :boolean = false;	-- Should we save the user's PlayByCloud ready choice when they have decided?
local m_exitReadyWait :boolean = false;		-- Are we waiting on a local player ready change to propagate prior to exiting the match?
local m_numPlayers:number;
local m_teamColors = {};
local m_sessionID :number = FireWireTypes.FIREWIRE_INVALID_ID;

-- Additional Content 
local m_modsIM = InstanceManager:new("AdditionalContentInstance", "Root", Controls.AdditionalContentStack);

-- Reusable tooltip control
local m_CivTooltip:table = {};
ContextPtr:BuildInstanceForControl("CivToolTip", m_CivTooltip, Controls.TooltipContainer);
m_CivTooltip.UniqueIconIM = InstanceManager:new("IconInfoInstance",	"Top", m_CivTooltip.InfoStack);
m_CivTooltip.HeaderIconIM = InstanceManager:new("IconInstance", "Top", m_CivTooltip.InfoStack);
m_CivTooltip.CivHeaderIconIM = InstanceManager:new("CivIconInstance", "Top", m_CivTooltip.InfoStack);
m_CivTooltip.HeaderIM = InstanceManager:new("HeaderInstance", "Top", m_CivTooltip.InfoStack);

-- Game launch blockers
local m_bTeamsValid = true;						-- Are the teams valid for game start?
local g_everyoneConnected = true;				-- Is everyone network connected to the game?
local g_badPlayerForMapSize = false;			-- Are there too many active civs for this map?
local g_notEnoughPlayers = false;				-- Is there at least two players in the game?
local g_everyoneReady = false;					-- Is everyone ready to play?
local g_everyoneModReady = true;				-- Does everyone have the mods for this game?
local g_humanRequiredFilled = true;				-- Are all the human required slots filled by humans?
local g_duplicateLeaders = false;				-- Are there duplicate leaders blocking launch?
												-- Note:  This only applies if No Duplicate Leaders parameter is set.
local g_pbcNewGameCheck = true;					-- In a PlayByCloud game, only the game host can launch a new game.	
local g_pbcMinHumanCheck = true;				-- PlayByCloud matches need at least two human players. 
												-- The game and backend can not handle solo games. 
												-- NOTE: The backend will automatically end started PBC matches that end up 
												-- with a solo human due to quits/kicks. 
local g_matchMakeFullGameCheck = true;			-- In a Matchmaking game, we only game launch during the ready countdown if the game is full of human players.				
local g_viewingGameSummary = true;
local g_hotseatNumHumanPlayers = 0;
local g_hotseatNumAIPlayers = 0;
local g_isBuildingPlayerList = false;

local m_iFirstClosedSlot = -1;					-- Closed slot to show Add player line

local NO_COUNTDOWN = -1;

local m_countdownType :string				= CountdownTypes.None;	-- Which countdown type is active?
local g_fCountdownTimer :number 			= NO_COUNTDOWN;			-- Start game countdown timer.  Set to -1 when not in use.
local g_fCountdownInitialTime :number 		= NO_COUNTDOWN;			-- Initial time for the current countdown.
local g_fCountdownTickSoundTime	:number 	= NO_COUNTDOWN;			-- When was the last time we make a countdown tick sound?
local g_fCountdownReadyButtonTime :number	= NO_COUNTDOWN;			-- When was the last time we updated the ready button countdown time?

-- Defines for the different Countdown Types.
-- CountdownTime - How long does the ready up countdown last in seconds?
-- TickStartTime - How long before the end of the ready countdown time does the ticking start?
local g_CountdownData = {
	[CountdownTypes.Launch]				= { CountdownTime = 10,		TimerType = TimerTypes.Script,				TickStartTime = 10},
	[CountdownTypes.Launch_Instant]		= { CountdownTime = 5,		TimerType = TimerTypes.Script,				TickStartTime = 0},
	[CountdownTypes.WaitForPlayers]		= { CountdownTime = 180,	TimerType = TimerTypes.NetworkManager,		TickStartTime = 10},
	[CountdownTypes.Ready_PlayByCloud]	= { CountdownTime = 600,	TimerType = TimerTypes.Script,				TickStartTime = 10},
	[CountdownTypes.Ready_MatchMaking]	= { CountdownTime = 60,		TimerType = TimerTypes.Script,				TickStartTime = 10},
	[CountdownTypes.Draft_MapBan]		= { CountdownTime = 32,		TimerType = TimerTypes.Script,				TickStartTime = 12},
	[CountdownTypes.Draft_LeaderBan]	= { CountdownTime = 62,		TimerType = TimerTypes.Script,				TickStartTime = 12},
	[CountdownTypes.Draft_LeaderPick]	= { CountdownTime = 62,		TimerType = TimerTypes.Script,				TickStartTime = 12},
	[CountdownTypes.Draft_ReadyStart]	= { CountdownTime = 300,	TimerType = TimerTypes.Script,				TickStartTime = 10},
};

-- hotseatOnly - Only available in hotseat mode.
-- hotseatInProgress = Available for active civs (AI/HUMAN) when loading a hotseat game
-- hotseatAllowed - Allowed in hotseat mode.
--StagingRoom: OnSlotType : SlotStatus.SS_CLOSED	2
--StagingRoom: OnSlotType : SlotStatus.SS_TAKEN	3
--StagingRoom: OnSlotType : SlotStatus.SS_COMPUTER	1
--StagingRoom: OnSlotType : SlotStatus.SS_OPEN	0
-- { name ="LOC_SLOTTYPE_CS",		tooltip = "LOC_SLOTTYPE_CS_TT",	hotseatOnly=false,	slotStatus=4,						hotseatInProgress = true,		hotseatAllowed=true },
local g_slotTypeData = 
{
	{ name ="LOC_SLOTTYPE_OPEN",		tooltip = "LOC_SLOTTYPE_OPEN_TT",		hotseatOnly=false,	slotStatus=SlotStatus.SS_OPEN,		hotseatInProgress = false,		hotseatAllowed=false},
	{ name ="LOC_SLOTTYPE_AI",			tooltip = "LOC_SLOTTYPE_AI_TT",			hotseatOnly=false,	slotStatus=SlotStatus.SS_COMPUTER,	hotseatInProgress = true,		hotseatAllowed=true },
	{ name ="LOC_SLOTTYPE_CLOSED",		tooltip = "LOC_SLOTTYPE_CLOSED_TT",		hotseatOnly=false,	slotStatus=SlotStatus.SS_CLOSED,	hotseatInProgress = false,		hotseatAllowed=true },		
	{ name ="LOC_SLOTTYPE_HUMAN",		tooltip = "LOC_SLOTTYPE_HUMAN_TT",		hotseatOnly=true,	slotStatus=SlotStatus.SS_TAKEN,		hotseatInProgress = true,		hotseatAllowed=true },
	{ name ="LOC_SLOTTYPE_OBSERVER",		tooltip = "LOC_SLOTTYPE_HUMAN_TT",		hotseatOnly=true,	slotStatus=SlotStatus.SS_OBSERVER,		hotseatInProgress = false,		hotseatAllowed=false },	
	{ name ="LOC_MP_SWAP_PLAYER",		tooltip = "TXT_KEY_MP_SWAP_BUTTON_TT",	hotseatOnly=false,	slotStatus=-1,						hotseatInProgress = true,		hotseatAllowed=true },		
};

local MAX_EVER_PLAYERS : number = 60; -- hardwired max possible players in multiplayer, determined by how many players 
local MIN_EVER_PLAYERS : number = 2;  -- hardwired min possible players in multiplayer, the game does bad things if there aren't at least two players on different teams.
local MAX_SUPPORTED_PLAYERS : number = 50; -- Max number of officially supported players in multiplayer.  You can play with more than this number, but QA hasn't vetted it.
local g_currentMaxPlayers : number = MAX_EVER_PLAYERS;
local g_currentMinPlayers : number = MIN_EVER_PLAYERS;
	
local PlayerConnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_CHAT" );
local PlayerDisconnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_DISCONNECTED_CHAT" );
local PlayerHostMigratedChatStr = Locale.Lookup( "LOC_MP_PLAYER_HOST_MIGRATED_CHAT" );
local PlayerKickedChatStr = Locale.Lookup( "LOC_MP_PLAYER_KICKED_CHAT" );
local BytesStr = Locale.Lookup( "LOC_BYTES" );
local KilobytesStr = Locale.Lookup( "LOC_KILOBYTES" );
local MegabytesStr = Locale.Lookup( "LOC_MEGABYTES" );
local DefaultHotseatPlayerName = Locale.Lookup( "LOC_HOTSEAT_DEFAULT_PLAYER_NAME" );
local NotReadyStatusStr = Locale.Lookup("LOC_NOT_READY");
local ReadyStatusStr = Locale.Lookup("LOC_READY_LABEL");
local BadMapSizeSlotStatusStr = Locale.Lookup("LOC_INVALID_SLOT_MAP_SIZE");
local BadMapSizeSlotStatusStrTT = Locale.Lookup("LOC_INVALID_SLOT_MAP_SIZE_TT");
local EmptyHumanRequiredSlotStatusStr :string = Locale.Lookup("LOC_INVALID_SLOT_HUMAN_REQUIRED");
local EmptyHumanRequiredSlotStatusStrTT :string = Locale.Lookup("LOC_INVALID_SLOT_HUMAN_REQUIRED_TT");
local UnsupportedText = Locale.Lookup("LOC_READY_UNSUPPORTED");
local UnsupportedTextTT = Locale.Lookup("LOC_READY_UNSUPPORTED_TT");
local downloadPendingStr = Locale.Lookup("LOC_MODS_SUBSCRIPTION_DOWNLOAD_PENDING");
local loadingSaveGameStr = Locale.Lookup("LOC_STAGING_ROOM_LOADING_SAVE");
local gameInProgressGameStr = Locale.Lookup("LOC_STAGING_ROOM_GAME_IN_PROGRESS");

local onlineIconStr = "[ICON_OnlinePip]";
local offlineIconStr = "[ICON_OfflinePip]";

local COLOR_GREEN				:number = UI.GetColorValueFromHexLiteral(0xFF00FF00);
local COLOR_RED					:number = UI.GetColorValueFromHexLiteral(0xFF0000FF);
local ColorString_ModGreen		:string = "[color:ModStatusGreen]";
local PLAYER_LIST_SIZE_DEFAULT	:number = 325;
local PLAYER_LIST_SIZE_HOTSEAT	:number = 535;
local GRID_LINE_WIDTH			:number = 1020;
local GRID_LINE_HEIGHT			:number = 51;
local NUM_COLUMNS				:number = 5;

local TEAM_ICON_SIZE			:number = 38;
local TEAM_ICON_PREFIX			:string = "ICON_TEAM_ICON_";


-------------------------------------------------
-- Localized Constants
-------------------------------------------------
local LOC_FRIENDS:string = Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_FRIENDS"));
local LOC_GAME_SETUP:string = Locale.Lookup("LOC_MULTIPLAYER_GAME_SETUP");
local LOC_GAME_SUMMARY:string = Locale.Lookup("LOC_MULTIPLAYER_GAME_SUMMARY");
local LOC_STAGING_ROOM:string = Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_STAGING_ROOM"));


-- ===========================================================================
function Close()	
    if m_kPopupDialog:IsOpen() then
		m_kPopupDialog:Close();
	end
	LuaEvents.Multiplayer_ExitShell();
end

-- ===========================================================================
--	Input Handler
-- ===========================================================================
function KeyUpHandler( key:number )
	if key == Keys.VK_ESCAPE then
		Close();
		return true;
	end
    return false;
end
function OnInputHandler( pInputStruct:table )
	local uiMsg :number = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then return KeyUpHandler( pInputStruct:GetKey() ); end	
	return false;
end


----------------------------------------------------------------  
-- Helper Functions
---------------------------------------------------------------- 
function SetCurrentMaxPlayers( newMaxPlayers : number )
	g_currentMaxPlayers = math.min(newMaxPlayers, MAX_EVER_PLAYERS);
end

function SetCurrentMinPlayers( newMinPlayers : number )
	g_currentMinPlayers = math.max(newMinPlayers, MIN_EVER_PLAYERS);
end

-- Could this player slot be displayed on the staging room?  The staging room ignores a lot of possible slots (city states; barbs; player slots exceeding the map size)
function IsDisplayableSlot(playerID :number)
	local pPlayerConfig = PlayerConfigurations[playerID];
	if(pPlayerConfig == nil) then
		return false;
	end

	if(playerID < g_currentMaxPlayers	-- Any slot under the current max player limit is displayable.
		-- Full Civ participants are displayable.
		or (pPlayerConfig:IsParticipant() 
			and pPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV) ) then
			return true;
	end

	return false;
end

-- Is the cloud match in progress?
function IsCloudInProgress()
	if(not GameConfiguration.IsPlayByCloud()) then
		return false;
	end

	if(GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_LAUNCHED -- Saved game state is launched.
		-- Has the cloud match blocked player joins?  The game host sets this prior to launching the match.
		-- We check for this becaus the game state will only be set to GAMESTATE_LAUNCHED once the first turn is committed.
		-- We need to count as being inprogress from when the host started to launch the match thru them committing their first turn.
		or Network.IsCloudJoinsBlocked()) then
		return true;
	end

	return false;
end

-- Are we in a launched PlayByCloud match where it is not our turn?
function IsCloudInProgressAndNotTurn()
	if(not IsCloudInProgress()) then
		return false;
	end

	if(Network.IsCloudTurnPlayer()) then
		return false;
	end

	-- If the local player is dead, count as false.  This should result in the CheckForGameStart immediately autolaunching the game so the player can see the endgamemenu.
	local localPlayerID = Network.GetLocalPlayerID();
	if( localPlayerID ~= NetPlayerTypes.INVALID_PLAYERID) then
		local localPlayerConfig = PlayerConfigurations[localPlayerID];
		if(not localPlayerConfig:IsAlive()) then
			return false;
		end
	end

	-- TTP 44083 - It is always the host's turn if the match is "in progress" but the match has not been started.  
	-- This can happen if the game host disconnected from the match right as the launch countdown hit zero.
	if(Network.IsGameHost() and not Network.IsCloudMatchStarted()) then
		return false;
	end

	return true;
end

function IsLaunchCountdownActive()
	if(m_countdownType == CountdownTypes.Launch or m_countdownType == CountdownTypes.Launch_Instant) then
		return true;
	end

	return false;
end

function IsDraftCountdownActive()
	if(m_countdownType == CountdownTypes.Draft_MapBan
		or m_countdownType == CountdownTypes.Draft_LeaderPick
		or m_countdownType == CountdownTypes.Draft_ReadyStart
		or m_countdownType == CountdownTypes.Draft_LeaderBan) then
		return true;
	end

	return false;
end

function IsReadyCountdownActive()
	if(m_countdownType == CountdownTypes.Ready_MatchMaking 
		or m_countdownType == CountdownTypes.Ready_PlayByCloud) then
		return true;
	end

	return false;
end

function IsWaitForPlayersCountdownActive()
	if(m_countdownType == CountdownTypes.WaitForPlayers) then
		return true;
	end

	return false;
end

function IsUseReadyCountdown()
	local type = GetReadyCountdownType();
	if(type ~= CountdownTypes.None) then
		return true;
	end

	return false;
end

function GetReadyCountdownType()
	if(GameConfiguration.IsPlayByCloud()) then
		return CountdownTypes.Ready_PlayByCloud;
	elseif(GameConfiguration.IsMatchMaking()) then
		return CountdownTypes.Ready_MatchMaking;
	end
	return CountdownTypes.None;
end	

function IsUseWaitingForPlayersCountdown()
	return GameConfiguration.IsMatchMaking();
end

function GetCountdownTimeRemaining()
	local countdownData :table = g_CountdownData[m_countdownType];
	if(countdownData == nil) then
		return 0;
	end

	if(countdownData.TimerType == TimerTypes.NetworkManager) then
		local sessionTime :number = Network.GetElapsedSessionTime();
		return countdownData.CountdownTime - sessionTime;
	else
		return g_fCountdownTimer;
	end
end


----------------------------------------------------------------  
-- Event Handlers
---------------------------------------------------------------- 
function OnMapMaxMajorPlayersChanged(newMaxPlayers : number)
	if(g_currentMaxPlayers ~= newMaxPlayers) then
		SetCurrentMaxPlayers(newMaxPlayers);
		if(ContextPtr:IsHidden() == false) then
			CheckGameAutoStart();	-- game start can change based on the new max players.
			BuildPlayerList();	-- rebuild player list because several player slots will have changed.
		end
	end
end

function OnMapMinMajorPlayersChanged(newMinPlayers : number)
	if(g_currentMinPlayers ~= newMinPlayers) then
		SetCurrentMinPlayers(newMinPlayers);
		if(ContextPtr:IsHidden() == false) then
			CheckGameAutoStart();	-- game start can change based on the new min players.
		end
	end
end

-------------------------------------------------
-- OnGameConfigChanged
-------------------------------------------------
function OnGameConfigChanged()
	Refresh()	  
	if(ContextPtr:IsHidden() == false) then
		RealizeGameSetup(); -- Rebuild the game settings UI.
		RebuildTeamPulldowns();	-- NoTeams setting might have changed.

		-- PLAYBYCLOUDTODO - Remove PBC special case once ready state changes have been moved to cloud player meta data.
		-- PlayByCloud uses GameConfigChanged to communicate player ready state changes, don't reset ready in that mode.
		if(not GameConfiguration.IsPlayByCloud() and not Automation.IsActive()) then
			SetLocalReady(false);  -- unready so player can acknowledge the new settings.
		end

		-- [TTP 42798] PlayByCloud Only - Ensure local player is ready if match is inprogress.  
		-- Previously players could get stuck unready if they unreadied between the host starting the launch countdown but before the game launch.
		if(IsCloudInProgress()) then
			SetLocalReady(true);
		end

		CheckGameAutoStart();  -- Toggling "No Duplicate Leaders" can affect the autostart.
	end
	OnMapMaxMajorPlayersChanged(MapConfiguration.GetMaxMajorPlayers());	
	OnMapMinMajorPlayersChanged(MapConfiguration.GetMinMajorPlayers());
end

-------------------------------------------------
-------------------------------------------------
--  Tournament Baby!
-------------------------------------------------
function OnTick()
	QuickRefresh()
	if g_last_tick_time == nil then
		g_last_tick_time = os.clock()
		return
	end
	if os.clock() > g_last_tick_time + g_tick_size or os.clock() == g_last_tick_time + g_tick_size then
		g_last_tick_time = os.clock()
		if b_tick == true then
			b_tick = false
		end
		Refresh()
		RefreshStatus()
		ShowHideEditButton()
		return
	end
	-- Define Settings
	g_slot_draft = 0
	if GameConfiguration.GetValue("DRAFT_SLOT_ORDER") ~= nil then
		g_slot_draft = GameConfiguration.GetValue("DRAFT_SLOT_ORDER")
	end
	g_timer = 1
	if GameConfiguration.GetValue("DRAFT_TIMER") ~= nil then
		if GameConfiguration.GetValue("DRAFT_TIMER") == true then
			g_timer = 1 
			else
			g_timer = 0
		end
	end	
end

function CheckStatusID(playerID)
	if GameConfiguration.GetGameState() ~= -901772834 then
		return
	end
	local name = PlayerConfigurations[playerID]:GetPlayerName()
	local ID = nil
	local status = nil
	local version = nil
	if g_player_status ~= nil then
		for i, player in ipairs(g_player_status) do 
			if player.Name == name then
				ID = player.ID
				version = player.Version
				status = player.Status
			end
		end
		for i, player in ipairs(g_player_status) do 
			if player.ID == ID then
				player.ID = playerID
				player.Name = name
				player.Version = version
				player.Status = status
			end
		end
	end
end

function GetLocalModVersion(id)
	if id == nil then
		return nil
	end
	
	local mods = Modding.GetInstalledMods();
	if(mods == nil or #mods == 0) then
		print("No mods locally installed!")
		return nil
	end
	
	local handle = -1
	for i,mod in ipairs(mods) do
		if mod.Id == id then
			handle = mod.Handle
			break
		end
	end
	if handle ~= -1 then
		local version = Modding.GetModProperty(handle, "Version");
		return version
		else
		return nil
	end
	
	
end

function RefreshStatusID(playerID,version,bbs_version,bbg_version)
	print("RefreshStatusID",playerID,version,bbg_version,bbs_version)
	if GameConfiguration.GetGameState() ~= -901772834 or m_countdownType =="Launch" then
		return
	end
	local fresh_id = true
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local versionBBS = GetLocalModVersion(s_bbs_id)
	local versionBBG = GetLocalModVersion(s_bbg_id)
	
	if g_player_status ~= nil then
		if version == nil then
			for i, player in ipairs(g_player_status) do 
				if player.ID == playerID then
					if Network.IsPlayerConnected(playerID) then
						player.Status = 0
						player.Version = 0
						if b_bbg_game == true then
							player.bbg_id = s_bbg_id
							player.bbg_v = 0
						end
						if b_bbs_game == true then
							player.bbs_id = s_bbs_id
							player.bbs_v = 0
						end
						player.Name = PlayerConfigurations[playerID]:GetPlayerName()
						fresh_id = false
						if player.ID == hostID then
							player.Status = 99
							player.Version = tostring(g_version)
							if b_bbg_game == true then
								player.bbg_id = s_bbg_id
								player.bbg_v = versionBBG
							end
							if b_bbs_game == true then
								player.bbs_id = s_bbs_id
								player.bbs_v = versionBBS
							end
							fresh_id = false					
						end
						else
						player.Status = -1
						player.Version = 0
						player.Name = "AI"
						if b_bbg_game == true then
							player.bbg_id = s_bbg_id
							player.bbg_v = 0
						end
						if b_bbs_game == true then
							player.bbs_id = s_bbs_id
							player.bbs_v = 0
						end
						fresh_id = false					
					end
				end
			end
			
			if fresh_id == true then
				if Network.IsPlayerConnected(playerID) then
					if PlayerConfigurations[playerID] ~= nil then
						if playerID == hostID then
							local tmp = { ID = playerID, Status = 99, Version = g_version, Name = PlayerConfigurations[playerID]:GetPlayerName()}
							if b_bbg_game == true then
								tmp.bbg_id = s_bbg_id
								tmp.bbg_v = versionBBG
							end
							if b_bbs_game == true then
								tmp.bbs_id = s_bbs_id
								tmp.bbs_v = versionBBS
							end
							table.insert(g_player_status, tmp)
							else
							local tmp = { ID = playerID, Status = 0, Version = 0, Name = PlayerConfigurations[playerID]:GetPlayerName()}
							if b_bbg_game == true then
								tmp.bbg_id = s_bbg_id
								tmp.bbg_v = 0
							end
							if b_bbs_game == true then
								tmp.bbs_id = s_bbs_id
								tmp.bbs_v = 0
							end
							table.insert(g_player_status, tmp)
						end
						else
						print("Error:",playerID,"has no valid PlayerConfigurations[playerID]",Network.IsPlayerConnected(playerID))
					end
					else
					local tmp = { ID = playerID, Status = -1, Version = 0, Name = "AI"}
					if b_bbg_game == true then
						tmp.bbg_id = s_bbg_id
						tmp.bbg_v = 0
					end
					if b_bbs_game == true then
						tmp.bbs_id = s_bbs_id
						tmp.bbs_v = 0
					end
					table.insert(g_player_status, tmp)
				end
			end
			
			else -- we are receiving a version number
			
			for i, player in ipairs(g_player_status) do 
				if player.ID == playerID then
					if Network.IsPlayerConnected(playerID) then
						player.Status = 2
						player.Version = tostring(version)	
						player.bbg_v = tostring(bbg_version)	
						player.bbs_v = tostring(bbs_version)	
						player.Name = PlayerConfigurations[playerID]:GetPlayerName()
					end
				end
			end				
		end
	end
end

function ResetStatus()
	print("ResetStatus()")
	if GameConfiguration.GetGameState() ~= -901772834 or m_countdownType =="Launch" then
		return
	end
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local versionBBS = GetLocalModVersion(s_bbs_id)
	local versionBBG = GetLocalModVersion(s_bbg_id)
	g_player_status = {}
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do
		if Network.IsPlayerConnected(iPlayer) then
			if iPlayer ~= hostID then
				local tmp = { ID = iPlayer, Status = 0, Version = 0, Name = PlayerConfigurations[iPlayer]:GetPlayerName()}
				if b_bbg_game == true then
					tmp.bbg_id = s_bbg_id
					tmp.bbg_v = 0
				end
				if b_bbs_game == true then
					tmp.bbs_id = s_bbs_id
					tmp.bbs_v = 0
				end
				table.insert(g_player_status, tmp)
				else
				local tmp = { ID = iPlayer, Status = 99, Version = g_version, Name = PlayerConfigurations[iPlayer]:GetPlayerName()}
				if b_bbg_game == true then
					tmp.bbg_id = s_bbg_id
					tmp.bbg_v = versionBBG
				end
				if b_bbs_game == true then
					tmp.bbs_id = s_bbs_id
					tmp.bbs_v = versionBBS
				end
				table.insert(g_player_status, tmp)					
			end
			else
			local tmp = { ID = iPlayer, Status = -1, Version = g_version, Name = "AI"}
				if b_bbg_game == true then
					tmp.bbg_id = s_bbg_id
					tmp.bbg_v = versionBBG
				end
				if b_bbs_game == true then
					tmp.bbs_id = s_bbs_id
					tmp.bbs_v = versionBBS
				end
			table.insert(g_player_status, tmp)				
		end
		
	end
end

function ResetStatus_SpecificID(playerID)
	if GameConfiguration.GetGameState() ~= -901772834 then
		return
	end
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()

	if g_player_status ~= nil and g_player_status ~= {} then
		for i, player in pairs(g_player_status) do
			if player.ID == playerID then
				player.Status = 0
				player.Version = 0
				if b_bbg_game == true then
					player.bbg_id = s_bbg_id
					player.bbg_v = 0
				end
				if b_bbs_game == true then
					player.bbs_id = s_bbs_id
					player.bbs_v = 0
				end
			end
		end
	end
end

function GetStatus_SpecificID(playerID)
	if GameConfiguration.GetGameState() ~= -901772834 then
		return "Wrong State"
	end
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local status = "no player ID"
	if g_player_status ~= nil and g_player_status ~= {} then
		for i, player in pairs(g_player_status) do
			if player.ID == playerID then
				status = player.Status
				return status
			end
		end
	end
end

function RefreshStatus()
	print("RefreshStatus()",os.date("%c"),b_tick)
	if GameConfiguration.GetGameState() ~= -901772834 or b_mph_game == false or m_countdownType =="Launch" or b_tick == true then
		return
	end
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	b_tick = true
	b_mods_ok = true
	if hostID == localID and b_mph_game == true then
		if g_player_status ~= nil and g_player_status ~= {} then
			for i, player in pairs(g_player_status) do
				if Network.IsPlayerConnected(player.ID) == false and player.Status ~= -1 then
					player.Status = -1
				end
				if player.Status == 1 then
					-- We haven't received an answer most likely hasn't a fully loaded MPH
						Network.SendChat("[COLOR_Civ6Red]Error:"..player.Name.." - MPH not preloaded. Cannot check Mod Version.",-2,player.ID)
						Network.SendChat("[COLOR_Civ6Red]You do not have a fully loaded version of MPH! [NEWLINE]Please subscribe to the mod on Steam. [NEWLINE]Be sure you to have MPH selected in additional content [NEWLINE]Be sure to restart the game before joining this game.[ENDCOLOR]",-2,player.ID)

					player.Status = 66
					b_mods_ok = false
				end
				if player.Status == 2 then
					-- We haven't received an answer most likely hasn't a fully loaded MPH
						if tostring(player.Version) ~= tostring(g_version) then
							Network.SendChat("[COLOR_Civ6Red]MPH Host version: "..tostring(g_version).." Your version: "..tostring(player.Version),-2,player.ID)
							player.Status = 66
						end
						if b_bbs_game == true and tostring(player.bbs_v) ~= tostring(GetLocalModVersion(s_bbs_id)) then
							Network.SendChat("[COLOR_Civ6Red]BBS Host version: "..tostring(GetLocalModVersion(s_bbs_id)).." Your version: "..tostring(player.bbs_v),-2,player.ID)
							player.Status = 66
						end
						if b_bbg_game == true and tostring(player.bbg_v) ~= tostring(GetLocalModVersion(s_bbg_id)) then
							Network.SendChat("[COLOR_Civ6Red]BBG Host version: "..tostring(GetLocalModVersion(s_bbg_id)).." Your version: "..tostring(player.bbg_v),-2,player.ID)
							player.Status = 66
						end
						if player.Status == 66 then
							Network.SendChat("[COLOR_Civ6Red]Error:"..player.Name.." - Version Mismatch.",-2,player.ID)
							b_mods_ok = false
							else
							player.Status = 3
							Network.SendChat("[COLOR_Civ6Green]"..player.Name.." - Mod Versions - OK.",-2,player.ID)
						end
				end				
				if player.Status == 0 then
					print("RefreshStatus() - Host Querrying - ID:",player.ID)
					local name = PlayerConfigurations[player.ID]:GetPlayerName()
					if name == nil then
						name = "Player "..player.ID
					end
					name = tostring(name)
					-- Request Clients
					Network.SendChat("[COLOR_Civ6Green]# Greetings! "..name.." has joined a MP game using Multiplayer Helper (v "..g_version.."). [ENDCOLOR]",-2,player.ID)
					player.Status = 1
				end
				if Network.IsPlayerConnected(player.ID) and (g_phase == PHASE_DEFAULT or g_phase == PHASE_INIT) then
					UpdatePlayerEntry(player.ID)
				end
			end	
			else
			ResetStatus()
			b_mods_ok = false
			return
		end
	end
end

function OnModCheck()
	print("OnModCheck()",os.date("%c"))
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	b_mods_ok = false
	g_player_status = {}
	ResetStatus()
end

function SendVersion()
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	if localID ~= hostID and b_mph_game == true then
		local bbs_version = GetLocalModVersion(s_bbs_id)
		local bbg_version = GetLocalModVersion(s_bbg_id)
		Network.SendChat(".mph_ui_modversion_"..tostring(g_version).."_BBS_"..tostring(bbs_version).."_BBG_"..tostring(bbg_version),-2,hostID)
	end
end

function PlayerEntryVisibility()
	-- Hide/Disable Player Entry Area
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	if g_hide_player == 1 then
		-- Hide playerEntry
		Controls.SortbyCiv:SetHide(true) 
		Controls.SortbyDifficulty:SetHide(true) 
		Controls.SortbyReady:SetHide(true) 
		Controls.SortbyKickPlayer:SetHide(true) 
		Controls.PrimaryStackGrid:SetSizeX(300)
		Controls.GridLine_1:SetHide(true) 
		Controls.GridLine_2:SetHide(true) 
		Controls.GridLine_3:SetHide(true)
		Controls.GridLine_4:SetHide(true) 
		Controls.GridLine_5:SetHide(true)
		g_GridLinesIM:ResetInstances()
		for i, iPlayer in ipairs(player_ids) do	
			local playerEntry = g_PlayerEntries[iPlayer]
			if playerEntry ~= nil then
			local button = playerEntry.SlotTypePulldown:GetButton()
			button:SetHide(true)
			playerEntry.TeamPullDown:SetDisabled(true)
			playerEntry.ColorPullDown:SetHide(true)
			playerEntry.PlayerPullDown:SetHide(true)
			playerEntry.HandicapPullDown:SetHide(true)
			playerEntry.StatusLabel:SetHide(true)
			playerEntry.ReadyImage:SetHide(true)
			playerEntry.AddPlayerButton:SetSizeX(285)
			playerEntry.KickButton:SetHide(true)

			if localID == iPlayer then
				playerEntry.YouIndicatorLine:SetHide(true) 
			end
			end
		end
		elseif g_hide_player == 0 then  -- Show
		Controls.SortbyCiv:SetHide(false) 
		Controls.SortbyDifficulty:SetHide(false) 
		Controls.SortbyReady:SetHide(false) 
		Controls.SortbyKickPlayer:SetHide(false) 
		Controls.PrimaryStackGrid:SetSizeX(1020)
		Controls.GridLine_1:SetHide(false) 
		Controls.GridLine_2:SetHide(false) 
		Controls.GridLine_3:SetHide(false)
		Controls.GridLine_4:SetHide(false) 
		Controls.GridLine_5:SetHide(false)	
		g_GridLinesIM:ResetInstances()
		for i, iPlayer in ipairs(player_ids) do	
			local playerEntry = g_PlayerEntries[iPlayer]
			if playerEntry ~= nil then
			local button = playerEntry.SlotTypePulldown:GetButton()
			button:SetHide(false)
			playerEntry.AddPlayerButton:SetSizeX(1000)
			playerEntry.SlotTypePulldown:SetDisabled(false)
			playerEntry.TeamPullDown:SetDisabled(false)
			playerEntry.ColorPullDown:SetHide(false)
			playerEntry.PlayerPullDown:SetHide(false)
			if g_disabled_civ == true then
				playerEntry.ColorPullDown:SetDisabled(true)
				playerEntry.PlayerPullDown:SetDisabled(true)
				else
				playerEntry.ColorPullDown:SetDisabled(false)
				playerEntry.PlayerPullDown:SetDisabled(false)			
			end
			playerEntry.HandicapPullDown:SetHide(false)
			playerEntry.StatusLabel:SetHide(false)
			playerEntry.ReadyImage:SetHide(false)
			if localID == iPlayer then
				playerEntry.YouIndicatorLine:SetHide(false) 
				playerEntry.YouIndicatorLine:SetSizeX(1000) 
				else
				playerEntry.KickButton:SetHide(false)
			end
			end
		end	
		elseif g_hide_player == 2 then  -- Show Partial
		Controls.SortbyCiv:SetHide(false) 
		Controls.SortbyDifficulty:SetHide(true) 
		Controls.SortbyReady:SetHide(true) 
		Controls.SortbyKickPlayer:SetHide(true) 
		Controls.PrimaryStackGrid:SetSizeX(628)
		g_GridLinesIM:ResetInstances()
		for i, iPlayer in ipairs(player_ids) do	
			local playerEntry = g_PlayerEntries[iPlayer]
			if playerEntry ~= nil then
			local button = playerEntry.SlotTypePulldown:GetButton()
			button:SetHide(false)
			playerEntry.AddPlayerButton:SetSizeX(612)
			playerEntry.TeamPullDown:SetDisabled(true)
			local IsVisible = false
			for j, player in ipairs(g_cached_playerIDs) do	
				if player.ID == iPlayer then
					if player.IsVisible == true then
							IsVisible = true
					end
				end
			end
			if IsVisible == true then
				playerEntry.ColorPullDown:SetHide(false)
				playerEntry.PlayerPullDown:SetHide(false)
				else
				playerEntry.ColorPullDown:SetHide(true)
				playerEntry.PlayerPullDown:SetHide(true)			
			end
			if g_disabled_civ == true then
				playerEntry.ColorPullDown:SetDisabled(true)
				playerEntry.PlayerPullDown:SetDisabled(true)
				else
				playerEntry.ColorPullDown:SetDisabled(false)
				playerEntry.PlayerPullDown:SetDisabled(false)			
			end
			if localID == iPlayer then
				playerEntry.YouIndicatorLine:SetSizeX(628) 
				playerEntry.YouIndicatorLine:SetHide(true) 
			end
			playerEntry.HandicapPullDown:SetHide(true)
			playerEntry.StatusLabel:SetHide(true)
			playerEntry.ReadyImage:SetHide(true)
			end
		end			
	end
end

function MapBanVisibility()
	-- Hide Map Pool Display
	if g_hide_map == true then
		for i = 1, 16 do
			local maplabel = Controls["MapPool_"..i.."Label"]
			maplabel:SetHide(true)
		end
		else -- unhide
		for i = 1, 16 do
			local maplabel = Controls["MapPool_"..i.."Label"]
			maplabel:SetHide(false)
		end	
	end
	
	-- Hide Vote Map Display
	if g_hide_vote_map == true then
		Controls.VoteMapScriptLabel:SetHide(true)
		Controls.VoteMapScriptPullDown:SetHide(true)
		Controls.VoteMapAgeLabel:SetHide(true)
		Controls.VoteMapAgePullDown:SetHide(true)
		Controls.VoteMapTempLabel:SetHide(true)
		Controls.VoteMapTempPullDown:SetHide(true)
		else
		Controls.VoteMapScriptLabel:SetHide(false)
		Controls.VoteMapScriptPullDown:SetHide(false)
		Controls.VoteMapAgeLabel:SetHide(false)
		Controls.VoteMapAgePullDown:SetHide(false)
		Controls.VoteMapTempLabel:SetHide(false)
		Controls.VoteMapTempPullDown:SetHide(false)
	end
end

function PhaseVisibility()
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	-- Phase 
	-- -1: no phase
	-- 0: tournament / voting init
	-- 7: tournament map ban
	-- 1: tournament leader ban
	-- 2: tournament pick
	-- 3: tournament / voting end
	
	if g_phase == PHASE_INIT then
		g_disabled_civ = false
		b_has_voted = false
		Controls.ModCheckButton:SetHide(true)
		Controls.VoteMapScriptPullDown:SetHide(true)
		Controls.VoteMapAgePullDown:SetHide(true)
		Controls.VoteMapTempPullDown:SetHide(true)
		Controls.VoteMapScriptLabel:SetHide(true)
		Controls.VoteMapAgeLabel:SetHide(true)
		Controls.VoteMapTempLabel:SetHide(true)
		Controls.MPH_ConfirmButton:SetHide(true)
		Controls.MPH_VoteButton:SetHide(true)
		Controls.MPH_VoteButton:ClearCallback(Mouse.eLClick)	
		Controls.StartButton:SetHide(true)
		Controls.MPH_Leader_ConfirmButton:SetHide(true)
		Controls.ReadyCheck:SetDisabled(true)
		Controls.ReadyButton:SetDisabled(true)
		Controls.BanLabel:SetHide(true) 
		Controls.BanPullDown:SetHide(true)
		Controls.PickedMapLabel:SetHide(true) 
		Controls.PickedMap2Label:SetHide(true) 
		Controls.PhaseLabel:SetHide(false)
		Controls.PhaseLabel_hint:SetHide(false)
		Controls.BanMapLabel:SetHide(true)
		Controls.BanMapPullDown:SetHide(true)	
		for i =1, 16 do
			local maplabel = Controls["MapPool_"..i.."Label"]
			maplabel:SetHide(true)
		end
		Controls.MapPoolLabel:SetHide(true)
		if GameConfiguration.GetValue("CPL_BAN_FORMAT") == 3 then
			Controls.PhaseLabel:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_0_TEXT"))
			if localID ~= hostID then
				Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_HOST_TEXT"))
				Controls.PhaseLabel_hint:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_0_HINT_TEXT"))
				Controls.PhaseButton:SetHide(true)
				Controls.ResetButton:SetHide(true)
				else
				Controls.PhaseButton:SetHide(false)
				local b_unable_to_launch = false
				for i, player in pairs(g_player_status) do
					if player.Status ~= 3 and player.Status ~= -1 and player.Status ~= 99 then
						b_unable_to_launch  = true
						Controls.PhaseButton:SetText("WAIT")
						if player.Status == 66 then
							Controls.PhaseButton:SetText("ERROR")
						end
					end
				end
				Controls.PhaseButton:SetDisabled(b_unable_to_launch)
				if b_unable_to_launch == true then
					Controls.PhaseButton:SetToolTipString(Locale.Lookup("LOC_MPH_PHASE_BUTTON_TOOLTIP_ERROR"))
					else
					Controls.PhaseButton:SetToolTipString(Locale.Lookup("LOC_MPH_PHASE_BUTTON_TOOLTIP"))
					Controls.PhaseButton:SetText("LAUNCH")
				end
				Controls.ResetButton:SetHide(false)
				Controls.PhaseButton:RegisterCallback(Mouse.eLClick,OnHostLaunch)
				Controls.PhaseButton:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_0_PHASE_BUTTON_TEXT"))
				Controls.ResetButton:RegisterCallback(Mouse.eLClick,OnHostReset)
				Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_LAUNCH_HOST_TEXT"))
				Controls.PhaseLabel_hint:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_0_HOST_HINT_TEXT"))
			end	
			elseif GameConfiguration.GetValue("CPL_BAN_FORMAT") == 4 then
			Controls.PhaseLabel:SetText(Locale.Lookup("LOC_MPH_VOTING_PHASE_0_TEXT"))
			if localID ~= hostID then
				Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_HOST_TEXT"))
				Controls.PhaseLabel_hint:SetText(Locale.Lookup("LOC_MPH_VOTING_PHASE_0_HINT_TEXT"))
				Controls.PhaseButton:SetHide(true)
				Controls.ResetButton:SetHide(true)
				else
				Controls.PhaseButton:SetHide(false)
				local b_unable_to_launch = false
				for i, player in pairs(g_player_status) do
					if player.Status ~= 3 and player.Status ~= -1 and player.Status ~= 99 then
						b_unable_to_launch  = true
						Controls.PhaseButton:SetText("WAIT")
						if player.Status == 66 then
							Controls.PhaseButton:SetText("ERROR")
						end
					end
				end
				Controls.PhaseButton:SetDisabled(b_unable_to_launch)
				if b_unable_to_launch == true then
					Controls.PhaseButton:SetToolTipString(Locale.Lookup("LOC_MPH_PHASE_BUTTON_TOOLTIP_ERROR"));
					Controls.PhaseButton:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_0_PHASE_BUTTON_NOT_READY_TEXT"));
					Controls.RefreshLabel:SetHide(false)
					Controls.RefreshLabel:SetText(g_refreshing)
					else
					Controls.RefreshLabel:SetHide(true)
					Controls.PhaseButton:SetToolTipString(Locale.Lookup("LOC_MPH_PHASE_BUTTON_TOOLTIP"));
					Controls.PhaseButton:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_0_PHASE_BUTTON_TEXT"));
				end
				Controls.ResetButton:SetHide(false)
				Controls.PhaseButton:RegisterCallback(Mouse.eLClick,OnHostLaunch)
				Controls.PhaseButton:SetText(Locale.Lookup("LOC_MPH_VOTING_PHASE_0_PHASE_BUTTON_TEXT"))
				Controls.ResetButton:RegisterCallback(Mouse.eLClick,OnHostReset)
				Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_LAUNCH_HOST_TEXT"))
				Controls.PhaseLabel_hint:SetText(Locale.Lookup("LOC_MPH_VOTING_PHASE_0_HOST_HINT_TEXT"))
			end		
		end
		return
	end
	
	if g_phase == PHASE_MAPBAN then
		Controls.ModCheckButton:SetHide(true)
		Controls.MPH_Leader_ConfirmButton:SetHide(true)
		g_disabled_civ = true
		g_hide_map = false
		g_hide_vote_map = true
		MapBanVisibility()
		g_disabled_slot_settings = true
		g_hide_player = 1
		PlayerEntryVisibility()
		Controls.PhaseLabel:SetHide(false)
		if localID == hostID then
			Controls.PhaseButton:SetHide(false)
			Controls.ResetButton:SetHide(false)
			Controls.PhaseButton:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_1_PHASE_BUTTON_TEXT"))
		end
		Controls.ResetButton:RegisterCallback(Mouse.eLClick,OnHostReset)
		Controls.PhaseButton:RegisterCallback(Mouse.eLClick,OnHostSkip)
		Controls.BanPullDown:SetHide(true)
		Controls.BanLabel:SetHide(true)
		Controls.BanMadeLabel:SetHide(true) 
		Controls.BanMade_1:SetHide(true)
		Controls.BanMade_2:SetHide(true)
		Controls.BanMade_3:SetHide(true) 
		Controls.BanMade_4:SetHide(true) 
		Controls.BanMade_5:SetHide(true) 
		Controls.BanMade_6:SetHide(true)
		Controls.BanMade_7:SetHide(true) 
		Controls.BanMade_8:SetHide(true) 
		Controls.BanMade_9:SetHide(true) 
		Controls.BanMade_10:SetHide(true)	
		Controls.PickMadeLabel:SetHide(true) 
		Controls.PickMade_1:SetHide(true)
		Controls.PickMade_2:SetHide(true)
		Controls.PickMade_3:SetHide(true) 
		Controls.PickMade_4:SetHide(true)
		Controls.PickMade_1Label:SetHide(true)
		Controls.PickMade_2Label:SetHide(true)
		Controls.PickMade_3Label:SetHide(true)
		Controls.PickMade_4Label:SetHide(true)			
		if b_teamer == true then
			Controls.PhaseLabel:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_7_TEAM_TEXT"))
			if g_slot_draft == 0 then
				Controls.PhaseLabel_hint:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_7_TEAM_RAND_HINT_TEXT"))
				Controls.PhaseLabel_hint:SetHide(false)
				elseif g_slot_draft == 1 or g_slot_draft == 2 then
				Controls.PhaseLabel_hint:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_7_TEAM_SLOT_HINT_TEXT"))
				Controls.PhaseLabel_hint:SetHide(false)
			end
			else
			Controls.PhaseLabel:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_7_FFA_TEXT"))
			if g_slot_draft == 0 then
				Controls.PhaseLabel_hint:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_7_FFA_RAND_HINT_TEXT"))
				Controls.PhaseLabel_hint:SetHide(false)
				elseif g_slot_draft == 1 or g_slot_draft == 2 then
				Controls.PhaseLabel_hint:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_7_FFA_RAND_HINT_TEXT"))
				Controls.PhaseLabel_hint:SetHide(false)
			end
		end
		return
	end
	
	if g_phase == PHASE_VOTE_BAN_MAP then
		Controls.ModCheckButton:SetHide(true)
		if localID == hostID then
			Controls.PhaseButton:SetHide(false)
			Controls.ResetButton:SetHide(false)
			Controls.PhaseButton:SetText(Locale.Lookup("LOC_MPH_VOTING_PHASE_1_PHASE_BUTTON_TEXT"))
			else
			Controls.PhaseButton:SetHide(true)
			Controls.ResetButton:SetHide(true)
		end
		Controls.PickMadeLabel:SetHide(true) 
		Controls.PickMade_1:SetHide(true)
		Controls.PickMade_2:SetHide(true)
		Controls.PickMade_3:SetHide(true) 
		Controls.PickMade_4:SetHide(true)
		Controls.PickMade_1Label:SetHide(true)
		Controls.PickMade_2Label:SetHide(true)
		Controls.PickMade_3Label:SetHide(true)
		Controls.PickMade_4Label:SetHide(true)	
		Controls.ResetButton:RegisterCallback(Mouse.eLClick,OnHostReset)
		Controls.PhaseButton:RegisterCallback(Mouse.eLClick,OnHostSkip)
		Controls.PhaseLabel:SetHide(false)
		Controls.PhaseLabel_hint:SetHide(false)
		Controls.MPH_ConfirmButton:SetHide(true)
		Controls.PhaseLabel:SetText(Locale.Lookup("LOC_MPH_VOTING_PHASE_11_TEXT"))
		Controls.PhaseLabel_hint:SetText(Locale.Lookup("LOC_MPH_VOTING_PHASE_11_HINT_TEXT"))
		Controls.MapPoolLabel:SetHide(true)
		-- Show Map Control
		g_hide_vote_map = false
		g_disabled_civ = true
		g_hide_map = true
		MapBanVisibility()
		g_disabled_slot_settings = true
		g_hide_player = 1
		PlayerEntryVisibility()
		return
	end

	if g_phase == PHASE_VOTE_BAN_LEADER then
		Controls.ModCheckButton:SetHide(true)
		Controls.BanMadeLabel:SetHide(false) 
		Controls.BanMade_1:SetHide(false)
		Controls.BanMade_2:SetHide(false)
		Controls.BanMade_3:SetHide(false) 
		Controls.BanMade_4:SetHide(false) 
		Controls.BanMade_5:SetHide(false) 
		Controls.BanMade_6:SetHide(false)
		if g_slot_draft == 3 then
			Controls.BanMade_7:SetHide(false) 
			Controls.BanMade_8:SetHide(false) 
			Controls.BanMade_9:SetHide(false) 
			Controls.BanMade_10:SetHide(false)
		end
		Controls.PickMadeLabel:SetHide(true) 
		Controls.PickMade_1:SetHide(true)
		Controls.PickMade_2:SetHide(true)
		Controls.PickMade_3:SetHide(true) 
		Controls.PickMade_4:SetHide(true)
		Controls.PickMade_1Label:SetHide(true)
		Controls.PickMade_2Label:SetHide(true)
		Controls.PickMade_3Label:SetHide(true)
		Controls.PickMade_4Label:SetHide(true)	
		Controls.PhaseLabel:SetHide(false)
		Controls.PhaseLabel_hint:SetHide(false)
		Controls.MPH_ConfirmButton:SetHide(true)
		Controls.PhaseLabel:SetText(Locale.Lookup("LOC_MPH_VOTING_PHASE_12_TEXT"))
		Controls.PhaseLabel_hint:SetText(Locale.Lookup("LOC_MPH_VOTING_PHASE_12_HINT_TEXT"))
		Controls.MapPoolLabel:SetHide(true)
		-- Show Map Control
		g_hide_vote_map = true
		g_disabled_civ = true
		g_hide_map = true
		MapBanVisibility()
		g_disabled_slot_settings = true
		g_hide_player = 1
		PlayerEntryVisibility()
		return
	end	
	
	
	if g_phase == PHASE_LEADERBAN then
		Controls.ModCheckButton:SetHide(true)
		g_disabled_slot_settings = true
		Controls.MPH_Leader_ConfirmButton:SetHide(true)
		g_disabled_civ = true
		g_player_disabled = true
		g_hide_player = 1
		PlayerEntryVisibility()
		g_hide_map = true
		g_hide_vote_map = true
		MapBanVisibility()
		Controls.BanMapLabel:SetHide(true)
		Controls.BanMapPullDown:SetHide(true)
		Controls.MapPoolLabel:SetHide(true)

		Controls.PhaseLabel:SetHide(false)
		if localID == hostID then
			Controls.PhaseButton:SetHide(false)
			Controls.ResetButton:SetHide(false)
			Controls.PhaseButton:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_1_PHASE_BUTTON_TEXT"))
		end
		Controls.PhaseButton:RegisterCallback(Mouse.eLClick,OnHostSkip)
		Controls.ResetButton:RegisterCallback(Mouse.eLClick,OnHostReset)
		Controls.BanMadeLabel:SetHide(false) 
		Controls.BanMade_1:SetHide(false)
		Controls.BanMade_2:SetHide(false)
		Controls.BanMade_3:SetHide(false) 
		Controls.BanMade_4:SetHide(false) 
		Controls.BanMade_5:SetHide(false) 
		Controls.BanMade_6:SetHide(false)
		if g_slot_draft == 3 then
			Controls.BanMade_7:SetHide(false) 
			Controls.BanMade_8:SetHide(false) 
			Controls.BanMade_9:SetHide(false) 
			Controls.BanMade_10:SetHide(false)
			Controls.PickMadeLabel:SetHide(false) 
			Controls.PickMade_1:SetHide(false)
			Controls.PickMade_2:SetHide(false)
			Controls.PickMade_3:SetHide(false) 
			Controls.PickMade_4:SetHide(false) 
		end
		if b_teamer == true then
			Controls.PhaseLabel:SetText("Teamer Phase 1: "..g_ban_count.."/ 6 Leader Bans")
			if g_slot_draft == 0 then
				Controls.PhaseLabel_hint:SetText("")
				Controls.PhaseLabel_hint:SetHide(false)
				elseif g_slot_draft == 3 then
				Controls.PhaseLabel:SetText("Teamer Phase 1: "..g_ban_count.."/ 10 Leader Bans")
				if g_ban_count < 3 then
					Controls.PhaseLabel_hint:SetText("Once only the 4th Leader is banned, we will move to picking in order starting back from the first slot")
					Controls.PhaseLabel_hint:SetHide(false)			
					else
					Controls.PhaseLabel:SetText("Teamer Phase 3: "..g_ban_count.."/ 10 Leader Bans")
					Controls.PhaseLabel_hint:SetText("Once only the last Leader is banned, we will return to picking in order")
					Controls.PhaseLabel_hint:SetHide(false)						
				end
				else
				Controls.PhaseLabel_hint:SetText("Once only the 6th Leader is banned, we will move to picking in order starting back from the first slot")
				Controls.PhaseLabel_hint:SetHide(false)
			end

			else
			Controls.PhaseLabel:SetText("FFA Phase 1: "..g_ban_count.."/ 6 Leader Bans")
			if g_slot_draft == 0 then
				Controls.PhaseLabel_hint:SetText("The first to pick in FFA would also been random")
				Controls.PhaseLabel_hint:SetHide(false)
				elseif g_slot_draft == 3 then
				Controls.PhaseLabel:SetText("There should not be a FFA in CWC?")
				else
				Controls.PhaseLabel_hint:SetText("We will restart to the first slots for picking")
				Controls.PhaseLabel_hint:SetHide(false)
			end
		end
		return
	end
	
	if g_phase == PHASE_LEADERPICK then
		Controls.ModCheckButton:SetHide(true)
		g_disabled_slot_settings = true
		Controls.MPH_Leader_ConfirmButton:SetHide(false)
		Controls.MPH_VoteButton:SetHide(true)
		Controls.MPH_ConfirmButton:SetHide(true)
		Controls.PhaseLabel:SetHide(false)
		Controls.BanMapLabel:SetHide(true)
		Controls.BanMapPullDown:SetHide(true)
		Controls.BanLabel:SetHide(true)
		Controls.BanPullDown:SetHide(true)
		Controls.MapPoolLabel:SetHide(true)
		Controls.PickMadeLabel:SetHide(true) 
		Controls.PickMade_1:SetHide(true)
		Controls.PickMade_2:SetHide(true)
		Controls.PickMade_3:SetHide(true) 
		Controls.PickMade_4:SetHide(true)
		Controls.PickMade_1Label:SetHide(true)
		Controls.PickMade_2Label:SetHide(true)
		Controls.PickMade_3Label:SetHide(true)
		Controls.PickMade_4Label:SetHide(true)	
		g_player_disabled = true
		g_hide_player = 2
		g_hide_vote_map = true
		PlayerEntryVisibility()
		g_hide_map = true
		MapBanVisibility()
		if localID == hostID then
			Controls.PhaseButton:SetHide(false)
			Controls.ResetButton:SetHide(false)
			Controls.PhaseButton:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_2_PHASE_BUTTON_TEXT"))
		end
		Controls.PhaseButton:RegisterCallback(Mouse.eLClick,OnHostSkip)
		Controls.ResetButton:RegisterCallback(Mouse.eLClick,OnHostReset)
		if b_teamer == true then
			Controls.PhaseLabel:SetText("Teamer Phase 2: Leader Selection")
			Controls.PhaseLabel_hint:SetText("Remember you can change your pick with one of your teammate at the end")
			Controls.PhaseLabel_hint:SetHide(false)
			elseif g_slot_draft ~= 3 then
			Controls.PhaseLabel:SetText("FFA Phase 2: "..g_valid_count.."/ "..g_total_players.." Players")
			Controls.PhaseLabel_hint:SetText("")
			Controls.PhaseLabel_hint:SetHide(false)
			elseif g_slot_draft == 3 and g_valid_count < 4 then
			Controls.PhaseLabel:SetText("FFA Phase 2: "..g_valid_count.."/ "..g_total_players.." Players")
			Controls.PhaseLabel_hint:SetText("")
			Controls.PhaseLabel_hint:SetHide(false)
			elseif g_slot_draft == 3 and g_valid_count > 4 then
			Controls.PhaseLabel:SetText("FFA Phase 4: "..g_valid_count.."/ "..g_total_players.." Players")
			Controls.PhaseLabel_hint:SetText("")
			Controls.PhaseLabel_hint:SetHide(false)
		end
		return
	end
	
	if g_phase == PHASE_READY then
		Controls.ModCheckButton:SetHide(true)
		Controls.MPH_Leader_ConfirmButton:SetHide(true)
		Controls.MPH_ConfirmButton:SetHide(true)
				Controls.PickMadeLabel:SetHide(true) 
		Controls.PickMade_1:SetHide(true)
		Controls.PickMade_2:SetHide(true)
		Controls.PickMade_3:SetHide(true) 
		Controls.PickMade_4:SetHide(true)
		Controls.PickMade_1Label:SetHide(true)
		Controls.PickMade_2Label:SetHide(true)
		Controls.PickMade_3Label:SetHide(true)
		Controls.PickMade_4Label:SetHide(true)	
		g_hide_vote_map = true
		if localID == hostID then
			Controls.PhaseButton:SetHide(false)
			Controls.StartButton:SetHide(false)
			Controls.PhaseButton:SetText(Locale.Lookup("LOC_MPH_TOURNAMENT_PHASE_3_PHASE_BUTTON_TEXT"))
			Controls.ResetButton:SetHide(false)
			else
			Controls.StartButton:SetHide(true)
		end
		Controls.ResetButton:RegisterCallback(Mouse.eLClick,OnHostReset)
		Controls.StartButton:RegisterCallback(Mouse.eLClick,OnHostForceStart)
		Controls.PhaseButton:RegisterCallback(Mouse.eLClick,OnHostUnlock)
		Controls.ReadyCheck:RegisterCallback( Mouse.eLClick, OnReadyButton );
		Controls.StartLabel:SetText("READY TO START!")
		if b_teamer == true then
			Controls.PhaseLabel:SetText("Teamer Phase 3: Let's Go!")
			else
			Controls.PhaseLabel:SetText("FFA Phase 3: Let's Go!")
		end	
		if localID ~= hostID then
			Controls.PhaseLabel_hint:SetText("Game will start once the Host click Start Game, ask the host to Unlock to change your leader")
			Controls.PhaseLabel_hint:SetHide(false)
			else
			Controls.PhaseLabel_hint:SetText("Click the Start Game button to start the game, Unlock to let players change leaders")
			Controls.PhaseLabel_hint:SetHide(false)
		end	
		
		if b_check == false then
			OnPlayerEntryReady(LocalID)
			b_check = true
		end

	end
end

function QuickRefresh()
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	g_refreshing = g_refreshing.."."
	if localID == hostID and not GameConfiguration.IsPlayByCloud() then
		Controls.ModCheckButton:SetHide(false)
		else
		Controls.ModCheckButton:SetHide(true)	
	end
	if string.len(g_refreshing) > 30 then
		g_refreshing = "Refreshing"
	end
	if (GameConfiguration.GetValue("CPL_BAN_FORMAT") == nil) then
		g_phase = PHASE_DEFAULT
		Controls.PhaseLabel:SetHide(true)
		Controls.PhaseButton:SetHide(true)
		Controls.ResetButton:SetHide(true)
		Controls.BanLabel:SetHide(true) 
		Controls.BanPullDown:SetHide(true)
		Controls.VoteMapScriptPullDown:SetHide(true)
		Controls.VoteMapAgePullDown:SetHide(true)
		Controls.VoteMapTempPullDown:SetHide(true)
		Controls.VoteMapScriptLabel:SetHide(true)
		Controls.VoteMapAgeLabel:SetHide(true)
		Controls.VoteMapTempLabel:SetHide(true)
		return
	end

	if Network.IsPlayerHotJoining(localID) or IsCloudInProgress() or GameConfiguration.IsHotseat() or GameConfiguration.GetGameState() ~= -901772834 then
		g_phase = PHASE_DEFAULT
		Controls.ModCheckButton:SetHide(true)
		Controls.PhaseButton:SetHide(true)
		Controls.ResetButton:SetHide(true)
		Controls.PhaseLabel:SetHide(false)
		Controls.StartButton:SetHide(true)
		Controls.PickedMapLabel:SetHide(true) 
		Controls.PickedMap2Label:SetHide(true) 
		Controls.BanLabel:SetHide(true) 
		Controls.BanPullDown:SetHide(true)
		Controls.PhaseLabel_hint:SetHide(true) 
		Controls.VoteMapScriptPullDown:SetHide(true)
		Controls.VoteMapAgePullDown:SetHide(true)
		Controls.VoteMapTempPullDown:SetHide(true)
		Controls.VoteMapScriptLabel:SetHide(true)
		Controls.VoteMapAgeLabel:SetHide(true)
		Controls.VoteMapTempLabel:SetHide(true)
		return
	end

	if GameConfiguration.GetValue("CPL_BAN_FORMAT") == 1 or GameConfiguration.GetValue("CPL_BAN_FORMAT") == 0 then
		g_phase = PHASE_DEFAULT
		GameConfiguration.SetValue("BAN_1","LEADER_NONE")
		GameConfiguration.SetValue("BAN_2","LEADER_NONE")
		GameConfiguration.SetValue("BAN_3","LEADER_NONE")
		GameConfiguration.SetValue("BAN_4","LEADER_NONE")
		GameConfiguration.SetValue("BAN_5","LEADER_NONE")
		GameConfiguration.SetValue("BAN_6","LEADER_NONE")
		Controls.PickedMapLabel:SetHide(true) 
		Controls.PickedMap2Label:SetHide(true) 
	end
	
	if (GameConfiguration.GetValue("CPL_BAN_FORMAT") == 3 or GameConfiguration.GetValue("CPL_BAN_FORMAT") == 4) and GameConfiguration.GetGameState() == -901772834 then
		if g_phase == PHASE_DEFAULT then
			g_phase = PHASE_INIT
		end
	end
end

function Refresh()
	-- phase: -1 is default, 0 is tournament map ban, 1 is leader ban, 2 is leader pick, 3 is init
	-- loading state -2091470447
	-- init state -901772834
	-- joining state -818482450
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	g_refreshing = g_refreshing.."."
	if string.len(g_refreshing) > 30 then
		g_refreshing = "Refreshing"
	end	
	GameConfiguration.SetValue("MOD_BSM_ID",false)
	GameConfiguration.SetValue("MOD_BBS_ID",false)
	GameConfiguration.SetValue("MOD_BBG_ID",false)
	GameConfiguration.SetValue("MOD_MPH_ID",false)
	local enabledMods = GameConfiguration.GetEnabledMods();
	for _, curMod in ipairs(enabledMods) do
		-- Color unofficial mods to call them out.
		if curMod.Id == "3291a787-4a93-445c-998d-e22034ab15b3" or curMod.Id == "c6e5ad32-0600-4a98-a7cd-5854a1abcaaf" then
			GameConfiguration.SetValue("MOD_BSM_ID",true)
		end			
		if curMod.Id == "c88cba8b-8311-4d35-90c3-51a4a5d6654f" then
			GameConfiguration.SetValue("MOD_BBS_ID",true)
		end		
		if curMod.Id == "cb84074d-5007-4207-b662-c35a5f7be240" or curMod.Id == "cb84074d-5007-4207-b662-c35a5f7be230" then
			GameConfiguration.SetValue("MOD_BBG_ID",true)
		end				
		if curMod.Id == "619ac86e-d99d-4bf3-b8f0-8c5b8c402176" then
			GameConfiguration.SetValue("MOD_MPH_ID",true)
		end			
														 	 
	end	
	
	-- Define Settings
	g_slot_draft = 0
	if GameConfiguration.GetValue("DRAFT_SLOT_ORDER") ~= nil then
		g_slot_draft = GameConfiguration.GetValue("DRAFT_SLOT_ORDER")
	end
	g_timer = 1
	if GameConfiguration.GetValue("DRAFT_TIMER") ~= nil then
		if GameConfiguration.GetValue("DRAFT_TIMER") == true then
			g_timer = 1 
			else
			g_timer = 0
		end
	end	
		
	-- Anonymous WIP
	if GameConfiguration.GetValue("CPL_ANONYMOUS") == true then 
		for i, iPlayer in ipairs(player_ids) do	
			local playerEntry = g_PlayerEntries[iPlayer]
			if playerEntry ~= nil then
				playerEntry.PlayerName:SetText("Anon_"..iPlayer)
			end
		end
		else
		for i, iPlayer in ipairs(player_ids) do	
			local playerEntry = g_PlayerEntries[iPlayer]
			local pPlayerConfig = PlayerConfigurations[iPlayer]
			if playerEntry ~= nil and pPlayerConfig ~= nil then
				playerEntry.PlayerName:LocalizeAndSetText(pPlayerConfig:GetSlotName())
			end
		end
	end
	
	Controls.PhaseLabel_Version:SetHide(false) 
	Controls.PhaseLabel_Version:SetText("v"..g_version) 

	-- Civ+ Player mod bug
	if isCivPlayerName == true then
		Controls.PhaseLabel_hint:SetText("[COLOR_RED]For the love of God - just disable Civ+ Player Name !!! I've flagged 100x it wasn't compatible![ENDCOLOR]")
		Controls.PhaseLabel_hint:SetHide(false)
		return
		elseif isCivPlayerName == false then
		Controls.PhaseLabel_hint:SetHide(true)
	end
	

	-- Reset / Launch Controls
	if localID ~= hostID then
		Controls.PhaseButton:SetDisabled(true)
		Controls.ResetButton:SetDisabled(true)
		else
		Controls.PhaseButton:SetDisabled(false)
		if b_mods_ok == false then
			Controls.PhaseButton:SetDisabled(true)	
		end
		if g_player_status ~= nil and GameConfiguration.GetGameState() == -901772834 then
			for i, player in ipairs(g_player_status) do 
				if Network.IsPlayerConnected(player.ID) then
					if player.Status == 66 or player.Status == 0 or player.Status == 1 then
						Controls.PhaseButton:SetDisabled(true)
					end
				end
			end	
		end
		Controls.ResetButton:SetDisabled(false)
	end
	
	if GameConfiguration.GetValue("CPL_BAN_FORMAT") ~= 3 and GameConfiguration.GetValue("CPL_BAN_FORMAT") ~= 4  then
		Controls.StartButton:SetHide(true)
		g_phase = PHASE_DEFAULT
		g_banned_leader = nil
		b_teamer = false
		g_next_ID = nil
		g_last_team = -1
		g_ban_count = 0
		g_valid_count = 0
		g_total_players = 0
		g_all_players = 0
		b_check = false
		b_launch = false
		g_map_pool = {}
		Controls.PhaseLabel:SetHide(true)
		Controls.PhaseButton:SetHide(true)
		Controls.ResetButton:SetHide(true)
		Controls.VoteMapScriptPullDown:SetHide(true)
		Controls.VoteMapAgePullDown:SetHide(true)
		Controls.VoteMapTempPullDown:SetHide(true)
		Controls.VoteMapScriptLabel:SetHide(true)
		Controls.VoteMapAgeLabel:SetHide(true)
		Controls.VoteMapTempLabel:SetHide(true)
		Controls.PhaseLabel_hint:SetHide(true) 
		for i =1, 16 do
			local maplabel = Controls["MapPool_"..i.."Label"]
			maplabel:SetHide(true)
		end
		Controls.MapPoolLabel:SetHide(true)
		Controls.BanLabel:SetHide(true) 
		Controls.BanPullDown:SetHide(true)
		Controls.BanMadeLabel:SetHide(true) 
		Controls.BanMade_1:SetHide(true)
		Controls.BanMade_2:SetHide(true)
		Controls.BanMade_3:SetHide(true) 
		Controls.BanMade_4:SetHide(true) 
		Controls.BanMade_5:SetHide(true) 
		Controls.BanMade_6:SetHide(true)
		Controls.BanMade_7:SetHide(true) 
		Controls.BanMade_8:SetHide(true) 
		Controls.BanMade_9:SetHide(true) 
		Controls.BanMade_10:SetHide(true)
		Controls.PickMadeLabel:SetHide(true) 
		Controls.PickMade_1:SetHide(true)
		Controls.PickMade_2:SetHide(true)
		Controls.PickMade_3:SetHide(true) 
		Controls.PickMade_4:SetHide(true)
		Controls.PickMade_1Label:SetHide(true)
		Controls.PickMade_2Label:SetHide(true)
		Controls.PickMade_3Label:SetHide(true)
		Controls.PickMade_4Label:SetHide(true)		
		Controls.BanMade_1Label:SetHide(true)
		Controls.BanMade_2Label:SetHide(true)
		Controls.BanMade_3Label:SetHide(true)
		Controls.BanMade_4Label:SetHide(true)
		Controls.BanMade_5Label:SetHide(true)
		Controls.BanMade_6Label:SetHide(true)
		Controls.BanMade_7Label:SetHide(true)
		Controls.BanMade_8Label:SetHide(true)
		Controls.BanMade_9Label:SetHide(true)
		Controls.BanMade_10Label:SetHide(true)
		Controls.PickedMapLabel:SetHide(true) 
		Controls.PickedMap2Label:SetHide(true) 
		Controls.PickMade_1:SetIcon("ICON_LEADER_DEFAULT")
		Controls.PickMade_2:SetIcon("ICON_LEADER_DEFAULT")
		Controls.PickMade_3:SetIcon("ICON_LEADER_DEFAULT")
		Controls.PickMade_4:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_1:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_2:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_3:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_4:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_5:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_6:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_7:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_8:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_9:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_10:SetIcon("ICON_LEADER_DEFAULT")
	end
	
	PhaseVisibility()
end


function OnHostLaunch()
	Network.SendChat(".forcecheck",-2,-1)
	-- Tournament
	if GameConfiguration.GetValue("CPL_BAN_FORMAT") == 3 then

	-- Vote Draft	
		Network.SendChat(".launch",-2,-1)
		UI.PlaySound("Play_MP_Game_Launch_Timer_Beep")
		elseif GameConfiguration.GetValue("CPL_BAN_FORMAT") == 4 then

					Network.SendChat(".launch",-2,-1)
			UI.PlaySound("Play_MP_Game_Launch_Timer_Beep")			
	end
end

function OnHostSkip()
	print("OnHostSkip()")
	Network.SendChat(".skip",-2,-1)
end

function OnHostReset()
	Network.SendChat(".reset",-2,-1)
end

function OnHostForceStart()
	Network.SendChat(".force",-2,-1)
end

function OnHostUnlock()
	Network.SendChat(".unlock",-2,-1)
end

function OnConfirmBan(playerID:number,bannumber:number)
	if playerID ~= g_next_ID  then
		return
	end
	if g_banned_leader == nil  then
		return
	end
	Network.SendChat(".ban_"..bannumber.."_"..playerID.."_"..g_banned_leader,-2,-1)
	UI.PlaySound("Play_MP_Player_Ready")
	Controls.StartLabel:SetText("THANKS!")
	Controls.ReadyCheck:SetDisabled(true)
	Controls.BanLabel:SetHide(true)
	Controls.BanPullDown:SetHide(true)
end

function OnConfirmMapBan(playerID:number,bannumber:number)
	if playerID ~= g_next_ID  then
		return
	end
	if g_banned_map == nil  then
		return
	end
	Network.SendChat(".mapban_"..bannumber.."_"..playerID.."_"..g_banned_map,-2,-1)
	UI.PlaySound("Play_MP_Player_Ready")
	Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_THANKS_TEXT"))
	Controls.ReadyCheck:SetDisabled(true)
	Controls.BanLabel:SetHide(true)
	Controls.BanPullDown:SetHide(true)
end

function OnConfirmMapVote(playerID:number)
	Network.SendChat(".mapvote_"..playerID.."_"..g_map_temp.."_"..g_map_age.."_"..g_map_script,-2,-1)
	UI.PlaySound("Play_MP_Player_Ready")
	Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_THANKS_TEXT"))
	Controls.ReadyCheck:SetDisabled(true)
	Controls.MPH_VoteButton:SetDisabled(true)
	Controls.VoteMapScriptPullDown:SetDisabled(true)
	Controls.VoteMapAgePullDown:SetDisabled(true)
	Controls.VoteMapTempPullDown:SetDisabled(true)
end

function OnConfirmBanVote(playerID:number, bannumber:number)
	if g_banned_leader == nil then
		return
	end
	g_ban_count = g_ban_count + 1
	Network.SendChat(".banvote_"..playerID.."_"..g_ban_count.."_"..g_banned_leader,-2,-1)
	UI.PlaySound("Play_MP_Player_Ready")
	Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_THANKS_TEXT"))
	Controls.ReadyCheck:SetDisabled(true)
	Controls.MPH_VoteButton:SetDisabled(true)
end

function OnConfirmValid(playerID:number,valid:number)
	PlayerInfoChanged_SpecificPlayer(playerID)
	GameSetup_RefreshParameters()
	UpdateReadyButton()
	print("OnConfirmValid","g_error",g_error)
	
	if g_error == true then
		UI.PlaySound("UI_Lens_Overlay_Off");
		return
	end
	if playerID ~= g_next_ID  then
		return
	end
	local pConfig = PlayerConfigurations[playerID]
	local leaderType = nil
	if pConfig ~= nil then
		leaderType = pConfig:GetLeaderTypeName()
		if leaderType ~= nil then
			for i = 1, 10 do
				if GameConfiguration.GetValue("BAN_"..i) == leaderType then
					UI.PlaySound("UI_Lens_Overlay_Off");
					return
				end
			end
		end
	end
	Network.SendChat(".valid_"..valid.."_"..playerID,-2,-1)
	UI.PlaySound("Play_MP_Player_Ready")
	Controls.StartLabel:SetText("THANKS!")
end

function OnValidReceived(text,teamer:boolean)
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	if g_debug == true then
		print("OnValidReceived - Is Teamer?",b_teamer,text)
	end
	local valid_number = "" 
	local valid_playerID = ""
	if (string.sub(text,9,9) == "_") then
		valid_number = string.sub(text,8,8)
		valid_number = tonumber(valid_number)
		if (string.sub(text,11,11) == "_") then
			valid_playerID = string.sub(text,10,10)
			valid_playerID = tonumber(valid_playerID)
			else
			valid_playerID = string.sub(text,10,11)
			valid_playerID = tonumber(valid_playerID)
		end
		else
		valid_number = string.sub(text,8,9)
		valid_number = tonumber(valid_number)
		if (string.sub(text,12,12) == "_") then
			valid_playerID = string.sub(text,11,11)
			valid_playerID = tonumber(valid_playerID)
			else
			valid_playerID = string.sub(text,11,12)
			valid_playerID = tonumber(valid_playerID)
		end
	end
	if g_debug == true then
		print("OnValidReceived - Valid Player ID",valid_playerID)
	end
	g_valid_count = g_valid_count + 1
	if g_valid_count < 5 and tonumber(valid_playerID) ~= nil then
		if g_valid_count == 1 then
			local leader = PlayerConfigurations[tonumber(valid_playerID)]:GetLeaderTypeName()
			if leader ~= nil then
				Controls.PickMade_1:SetIcon("ICON_"..tostring(leader))
				if b_teamer == true then
					Controls.PickMade_1Label:SetText(tostring(PlayerConfigurations[tonumber(valid_playerID)]:GetTeam()+1))
				end
			end
		end	
		if g_valid_count == 2 then
			local leader = PlayerConfigurations[tonumber(valid_playerID)]:GetLeaderTypeName()
			if leader ~= nil then
				Controls.PickMade_2:SetIcon("ICON_"..tostring(leader))
				if b_teamer == true then
					Controls.PickMade_2Label:SetText(tostring(PlayerConfigurations[tonumber(valid_playerID)]:GetTeam()+1))
				end
			end
		end	
		if g_valid_count == 3 then
			local leader = PlayerConfigurations[tonumber(valid_playerID)]:GetLeaderTypeName()
			if leader ~= nil then
				Controls.PickMade_3:SetIcon("ICON_"..tostring(leader))
				if b_teamer == true then
					Controls.PickMade_3Label:SetText(tostring(PlayerConfigurations[tonumber(valid_playerID)]:GetTeam()+1))
				end
			end
		end	
		if g_valid_count == 4 then
			local leader = PlayerConfigurations[tonumber(valid_playerID)]:GetLeaderTypeName()
			if leader ~= nil then
				Controls.PickMade_4:SetIcon("ICON_"..tostring(leader))
				if b_teamer == true then
					Controls.PickMade_4Label:SetText(tostring(PlayerConfigurations[tonumber(valid_playerID)]:GetTeam()+1))
				end
			end
		end	
	end
	for i = 1, g_all_players do
		if g_cached_playerIDs[i] ~= nil then
			if g_cached_playerIDs[i].ID == valid_playerID then
				g_cached_playerIDs[i].HasPicked = true
					if g_debug == true then
						print("OnValidReceived - Remove from the List",g_cached_playerIDs[i].ID)
					end
				break
			end
		end
	end	
	
	if ((g_valid_count == g_total_players or g_valid_count > g_total_players) and g_slot_draft ~= 3) or 
		((g_valid_count == g_total_players or g_valid_count > g_total_players) and g_slot_draft == 3 and g_ban_count > 6) then
		Controls.ReadyCheck:ClearCallback(Mouse.eLClick)
		g_phase = PHASE_READY
		print("g_valid_count",g_valid_count,"g_total_players",g_total_players)
		if localID == hostID then
			Network.SendChat(".chgphase_"..g_phase,-2,-1)
			if g_slot_draft == 3 then
				Network.SendChat(".unlock",-2,-1)
			end
			g_next_ID = GetNextID()
			 print("OnValidReceived g_valid_count",g_valid_count,"g_phase",g_phase,"g_next_ID",g_next_ID )
			if g_next_ID == nil then
			 g_next_ID = 0
			 print("OnValidReceived g_valid_count",g_valid_count,"g_phase",g_phase,"g_next_ID shouldn't be nil")
			end
			Network.SendChat(".idnext_"..g_next_ID,-2,-1)
		end
		elseif g_slot_draft == 3 and g_valid_count == 4 then -- Has to be 4 after testing
			g_phase = PHASE_LEADERBAN
			print("g_valid_count",g_valid_count,"g_total_players",g_total_players,"CWC NEW Second Ban Phase")
			if localID == hostID then
				Network.SendChat(".chgphase_"..g_phase,-2,-1)
				g_next_ID = GetNextID()
							if g_next_ID == nil then
			 g_next_ID = 0
			 print("OnValidReceived g_valid_count",g_valid_count,"g_phase",g_phase,"g_next_ID shouldn't be nil")
			end
				Network.SendChat(".idnext_"..g_next_ID,-2,-1)
			end			
		else
		
		if localID == hostID then
			Network.SendChat(".chgphase_"..g_phase,-2,-1)
			g_next_ID = GetNextID()
			print("OnValidReceived g_valid_count",g_valid_count,"g_phase",g_phase,"g_next_ID is",GetNextID())
			if g_next_ID == nil then
			 g_next_ID = 0
			 print("OnValidReceived g_valid_count",g_valid_count,"g_phase",g_phase,"g_next_ID shouldn't be nil")
			end
			Network.SendChat(".idnext_"..g_next_ID,-2,-1)
		end
	
		if g_debug == true then
			print("OnValidReceived - Set g_next_ID",g_next_ID)
		end
		OnNextValid(g_valid_count)
	end
end

function OnBanMapReceived(text,teamer:boolean)
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	if g_debug == true then
		print("OnBanMapReceived - teamer?",b_teamer)
	end
	local ban_number = string.sub(text,6,6)
	local ban_map = ""
	local ban_ID = ""
	ban_number = tonumber(ban_number)
	if string.sub(text,12,12) == "_" then
		ban_map = tonumber(string.sub(text,13))
		ban_ID = tonumber(string.sub(text,11,11))
		else
		ban_map = tonumber(string.sub(text,14))
		ban_ID = tonumber(string.sub(text,11,12)	)	
	end
	if g_debug == true then
		print("OnBanMapReceived - ban_map",ban_map)
	end	
	local map_left = 0
	local map_script = ""
	for i =1, 16 do
		if g_map_pool[i] ~= nil then
			if g_map_pool[i].ID == ban_map then
				g_map_pool[i].Allowed = false
			end
			if i ~= 3 then
			if g_map_pool[i].Allowed == false then
				local label = Controls["MapPool_"..g_map_pool[i].ID.."Label"]
				label:SetText("[COLOR_Civ6Red]"..string.sub(g_map_pool[i].Map,1,5)..".[ENDCOLOR]")
				elseif g_map_pool[i].Allowed == true then
				local label = Controls["MapPool_"..g_map_pool[i].ID.."Label"]
				label:SetText(string.sub(g_map_pool[i].Map,1,5)..".")
				map_left = map_left + 1
				map_script = g_map_pool[i].Map
			end
			else
			if g_map_pool[i].Allowed == false  then
				local label = Controls["MapPool_"..g_map_pool[i].ID.."Label"]
				label:SetText("[COLOR_Civ6Red]C. Isles[ENDCOLOR]")
				elseif g_map_pool[i].Allowed == true then
				local label = Controls["MapPool_"..g_map_pool[i].ID.."Label"]
				label:SetText("C. Isles")
				map_left = map_left + 1
				map_script = g_map_pool[i].Map
			end
			end
		end
	end
	

	if map_left == 1 or  map_left < 1 then
		if map_left == 1 then
			MapConfiguration.SetValue("MAP_SCRIPT",map_script)
		end
		Controls.PickedMapLabel:SetHide(false)
		Controls.PickedMap2Label:SetHide(false)
		Controls.PickedMap2Label:SetText(map_script)
		g_ban_count = 0
		g_next_ID = nil
		g_phase = PHASE_LEADERBAN
	end
	
	if localID == hostID then
		Network.SendChat(".chgphase_"..g_phase,-2,-1)
		g_next_ID = GetNextID()
		print("OnBanMapReceived g_valid_count",g_valid_count,"map_left",map_left,"g_phase",g_phase,"g_next_ID is",GetNextID())
		Network.SendChat(".idnext_"..g_next_ID,-2,-1)
	end
	
	if g_debug == true then
		print("OnBanReceived - Set g_next_ID",g_next_ID)
	end
	
end

function OnPhaseChanged(text)
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local phase_number = string.sub(text,11)
	if tonumber(phase_number) ~= nil then
		print("OnPhaseChanged - old g_phase",g_phase,"to new phase",phase_number)	
		g_phase = tonumber(phase_number)
		PhaseVisibility()
	end
end


function OnReceiveBanVote(text:string) -- .mapvote_0_2_LEADER_PERICLES
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local voter_ID = nil
	local ban_number = nil
	local leader = ""
	
	if string.sub(text,11,11) == "_" then
		voter_ID = tonumber(string.sub(text,10,10))
		ban_number = tonumber(string.sub(text,12,12))
		leader = string.sub(text,14)
		else
		voter_ID = tonumber(string.sub(text,10,11))
		ban_number = tonumber(string.sub(text,13,13))
		leader = string.sub(text,15)
	end
	
	local keep_waiting = false
	for i, player in ipairs(g_cached_playerIDs) do	
		if player.ID == voter_ID then
			if player.HasVotedBan == false then
				print("OnReceiveBanVote: Player ",player.ID,"Ban Number",ban_number,leader)
				local playerEntry = g_PlayerEntries[player.ID];
				playerEntry.PlayerAction:SetText("[COLOR_Civ6Red]Banning "..ban_number.."/3 [ENDCOLOR]")
				if ban_number == 1 then
					player.Ban_1 = leader
					if voter_ID == localID then
						g_banned_leader = nil
						Controls.ReadyCheck:SetDisabled(false)
						Controls.MPH_VoteButton:SetDisabled(false)
					end
					elseif ban_number == 2 then
					player.Ban_2 = leader
					if voter_ID == localID then
						g_banned_leader = nil
						Controls.ReadyCheck:SetDisabled(false)
						Controls.MPH_VoteButton:SetDisabled(false)
					end
					elseif ban_number == 3 then
						if voter_ID == localID then
							Controls.BanPullDown:SetDisabled(true)
							g_banned_leader = nil
						end
					player.Ban_3 = leader
					player.HasVotedBan = true
					playerEntry.PlayerAction:SetText("Locked")
				end
				else
				print("OnReceiveBanVote: Player ",player.ID," has already voted.")
			end	
		end
		if player.HasVotedBan == false then
			keep_waiting = true
		end
	end	

	if keep_waiting == false then
		if localID == hostID then
			local count = 0 
			local banned_leader = {}
			for k, leader in pairs(m_LeaderBan) do
				count = 0
				if leader.LeaderType ~= "LEADER_NONE" then
					for i, player in ipairs(g_cached_playerIDs) do	
						if player.Ban_1 == leader.LeaderType then
							count = count + 1
						end
						if player.Ban_2 == leader.LeaderType then
							count = count + 1
						end
						if player.Ban_3 == leader.LeaderType then
							count = count + 1
						end
					end
				end	
				local tmp = { LeaderType = leader.LeaderType, BanVotes = count  }
				table.insert(banned_leader, tmp)
			end
			local sort_func = function( a,b ) return a.BanVotes > b.BanVotes end
			table.sort( banned_leader, sort_func )
			for k, leader in pairs(banned_leader) do
				print(k,leader.LeaderType,leader.BanVotes)
			end
			for i = 1, 6 do
				if banned_leader[i].BanVotes > 0 then
					Network.SendChat(".ban_"..i.."_"..hostID.."_"..banned_leader[i].LeaderType,-2,-1)
					else
					Network.SendChat(".ban_"..i.."_"..hostID.."_".."LEADER_NONE",-2,-1)
				end
			end
		end
	end
end

function OnReceiveMapVote(text:string) -- .mapvote_0_2_1_5
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local voter_ID = nil
	local temp = 4
	local age = 4
	local script = nil
	
	if string.sub(text,11,11) == "_" then
		voter_ID = tonumber(string.sub(text,10,10))
		temp = tonumber(string.sub(text,12,12))
		age = tonumber(string.sub(text,14,14))
		script = tonumber(string.sub(text,16))
		else
		voter_ID = tonumber(string.sub(text,10,11))
		temp = tonumber(string.sub(text,13,13))
		age = tonumber(string.sub(text,15,15))
		script = tonumber(string.sub(text,17))
	end
	local keep_waiting = false
	for i, player in ipairs(g_cached_playerIDs) do	
		if player.ID == voter_ID then
			if player.HasVotedMap == false then
				print("OnReceiveMapVote: Player ",player.ID," has voted ",temp,age,script)
				player.VotedScript = script
				player.VotedTemp = temp
				player.VotedAge = age
				player.HasVotedMap = true
				local playerEntry = g_PlayerEntries[player.ID];
				playerEntry.PlayerAction:SetText("Locked")
				else
				print("OnReceiveMapVote: Player ",player.ID," has already voted.")
			end	
		end
		if player.HasVotedMap == false then
			keep_waiting = true
		end
	end	

	if keep_waiting == false then
		g_phase = 12
		if localID == hostID then
			local count = 0
			local best = 0
			local map_script = ""
			for k, map in pairs(g_map_pool) do
				count = 0
				if map.Allowed == true then
					for i, player in ipairs(g_cached_playerIDs) do	
						if player.VotedScript == map.ID then
							count = count + 1
						end
					end
				end
				if count > best then
					map_script = map.Map
					best = count
				end
			end
			MapConfiguration.SetValue("MAP_SCRIPT",map_script)
			local map_age = 4
			best = 0
			for j = 1, 3 do
				count = 0
				for i, player in ipairs(g_cached_playerIDs) do	
					if player.VotedAge == j then
						count = count + 1
					end
				end
				if count > best then
					map_age = j
					best = count
				end
			end
			MapConfiguration.SetValue("world_age",map_age)		
			local map_temp = 4
			best = 0
			for j = 1, 3 do
				count = 0
				for i, player in ipairs(g_cached_playerIDs) do	
					if player.VotedTemp == j then
						count = count + 1
					end
				end
				if count > best then
					map_temp = j
					best = count
				end
			end
			MapConfiguration.SetValue("temperature",map_temp)
			Network.SendChat(".idnext_"..hostID,-2,-1)			
		end
	end
end

function OnBanReceived(text,teamer:boolean)
	print("OnBanReceived",text)
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	if g_debug == true then
		print("OnBanReceived - teamer?",b_teamer)
	end
	local ban_number = string.sub(text,6,6)
	if (string.sub(text,6,6) == "1" or string.sub(text,6,6) == "0") and string.sub(text,7,7) ~= "_" then
		ban_number = string.sub(text,6,7)
	end
	local ban_leader = ""
	local ban_ID = ""
	ban_number = tonumber(ban_number)
	if ban_number < 10 then
		if string.sub(text,9,9) == "_" then
		ban_leader = string.sub(text,10)
		ban_ID = tonumber(string.sub(text,8,8))
		else
		ban_leader = string.sub(text,11)
		ban_ID = tonumber(string.sub(text,8,9)	)	
		end
		else
		if string.sub(text,10,10) == "_" then
		ban_leader = string.sub(text,11)
		ban_ID = tonumber(string.sub(text,9,9))
		else
		ban_leader = string.sub(text,12)
		ban_ID = tonumber(string.sub(text,9,10)	)	
		end		
	end
	GameConfiguration.SetValue("BAN_"..ban_number,ban_leader)
	if ban_number == 1 then
		Controls.BanMade_1:SetHide(false)
		Controls.BanMade_1:SetIcon("ICON_"..ban_leader)
		if b_teamer == true then
			Controls.BanMade_1Label:SetHide(false)
			Controls.BanMade_1Label:SetText(tostring(PlayerConfigurations[ban_ID]:GetTeam()+1))
		end
		elseif ban_number == 2 then
		Controls.BanMade_2:SetHide(false)
		Controls.BanMade_2:SetIcon("ICON_"..ban_leader)		
		if b_teamer == true then
			Controls.BanMade_2Label:SetHide(false)
			Controls.BanMade_2Label:SetText(tostring(PlayerConfigurations[ban_ID]:GetTeam()+1))
		end
		elseif ban_number == 3 then
		Controls.BanMade_3:SetHide(false)
		Controls.BanMade_3:SetIcon("ICON_"..ban_leader)
		if b_teamer == true then
			Controls.BanMade_3Label:SetHide(false)
			Controls.BanMade_3Label:SetText(tostring(PlayerConfigurations[ban_ID]:GetTeam()+1))
		end		
		elseif ban_number == 4 then
		Controls.BanMade_4:SetHide(false)
		Controls.BanMade_4:SetIcon("ICON_"..ban_leader)	
		if b_teamer == true then
			Controls.BanMade_4Label:SetHide(false)
			Controls.BanMade_4Label:SetText(tostring(PlayerConfigurations[ban_ID]:GetTeam()+1))
		end	
		elseif ban_number == 5 then
		Controls.BanMade_5:SetHide(false)
		Controls.BanMade_5:SetIcon("ICON_"..ban_leader)	
		if b_teamer == true then
			Controls.BanMade_5Label:SetHide(false)
			Controls.BanMade_5Label:SetText(tostring(PlayerConfigurations[ban_ID]:GetTeam()+1))
		end		
		elseif ban_number == 6 then
		Controls.BanMade_6:SetHide(false)
		Controls.BanMade_6:SetIcon("ICON_"..ban_leader)		
		if b_teamer == true then
			Controls.BanMade_6Label:SetHide(false)
			Controls.BanMade_6Label:SetText(tostring(PlayerConfigurations[ban_ID]:GetTeam()+1))
		end
		elseif ban_number == 7 then
		Controls.BanMade_7:SetHide(false)
		Controls.BanMade_7:SetIcon("ICON_"..ban_leader)		
		if b_teamer == true then
			Controls.BanMade_7Label:SetHide(false)
			Controls.BanMade_7Label:SetText(tostring(PlayerConfigurations[ban_ID]:GetTeam()+1))
		end
		elseif ban_number == 8 then
		Controls.BanMade_8:SetHide(false)
		Controls.BanMade_8:SetIcon("ICON_"..ban_leader)		
		if b_teamer == true then
			Controls.BanMade_8Label:SetHide(false)
			Controls.BanMade_8Label:SetText(tostring(PlayerConfigurations[ban_ID]:GetTeam()+1))
		end
		elseif ban_number == 9 then
		Controls.BanMade_9:SetHide(false)
		Controls.BanMade_9:SetIcon("ICON_"..ban_leader)		
		if b_teamer == true then
		Controls.BanMade_9Label:SetHide(false)
		Controls.BanMade_9Label:SetText(tostring(PlayerConfigurations[ban_ID]:GetTeam()+1))
		end
		elseif ban_number == 10 then
		Controls.BanMade_10:SetHide(false)
		Controls.BanMade_10:SetIcon("ICON_"..ban_leader)		
		if b_teamer == true then
		Controls.BanMade_10Label:SetHide(false)
		Controls.BanMade_10Label:SetText(tostring(PlayerConfigurations[ban_ID]:GetTeam()+1))
		end
	end

	g_ban_count = ban_number
	if ban_number == 6 or (ban_number > 6 and g_slot_draft ~= 3) or ((ban_number > 10 or ban_number == 10) and g_slot_draft == 3) then
		g_phase = PHASE_LEADERPICK
		g_next_ID = nil
	end
	
	if localID == hostID then
		Network.SendChat(".chgphase_"..g_phase,-2,-1)
		g_next_ID = GetNextID()
		print("OnBanReceived - g_ban_count",g_ban_count,"g_phase",g_phase,"Set g_next_ID",g_next_ID)
		if g_next_ID == nil then
			g_next_ID = hostID
		end
		Network.SendChat(".idnext_"..g_next_ID,-2,-1)
		else
		OnReceiveNextID(g_next_ID)
	end
	
	if g_debug == true then
		print("OnBanReceived - Set g_next_ID",g_next_ID)
	end
	
end

function HostSkip()
	print("HostSkip()",g_phase)
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local map_left = 0
	local map_index = 0
	StopCountdown()
	if g_phase == PHASE_LEADERBAN then
		if localID == hostID then
			if g_ban_count == 0 then
				g_ban_count = 1
				else
				g_ban_count = g_ban_count + 1
			end
			Network.SendChat(".ban_"..g_ban_count.."_"..g_next_ID.."_".."LEADER_NONE",-2,-1)
		end
	elseif g_phase == PHASE_VOTE_BAN_MAP then
		
		for i, player in ipairs(g_cached_playerIDs) do	
			if player.HasVotedMap == false then
				Network.SendChat(".mapvote_"..player.ID.."_1_1_1",-2,-1)
				break
			end
		end	
	elseif g_phase == PHASE_VOTE_BAN_LEADER then
		
		for i, player in ipairs(g_cached_playerIDs) do	
			if player.HasVotedBan == false then
				Network.SendChat(".banvote_"..player.ID.."_3_LEADER_NONE",-2,-1)
				break
			end
		end	
		
	elseif g_phase == PHASE_MAPBAN then
		if localID == hostID then
			for i = 1,15 do
				if g_map_pool[i] ~= nil then
					if g_map_pool[i].Allowed == true then
							map_left = map_left + 1
							map_index = i
					end
				end
			end
		Network.SendChat(".mapban_".."1".."_"..hostID.."_"..map_index,-2,-1)
		end
	elseif g_phase == PHASE_LEADERPICK then
		if localID == hostID then
			print("HostSkip() g_valid_count",g_valid_count)
			
			-- Select a Random Leader
			m_LeaderBan = nil
			local leader_rand = ""
			if m_LeaderBan == nil then
				m_LeaderBan = {}
				local info_query = "SELECT * from Players where Domain = ?";
				local domain = "Players:Expansion2_Players"
				local info_results = DB.ConfigurationQuery(info_query, domain);
				for k , v in pairs(info_results) do
					local tmp = { LeaderType = v.LeaderType, LeaderName = v.LeaderName, LeaderIcon = v.LeaderIcon}
					if tmp.LeaderType ~= "LEADER_SPECTATOR" and tmp.LeaderType ~= "RANDOM"  then
						table.insert(m_LeaderBan, tmp)
					end
				end
				local sort_func = function( a,b ) return Locale.Lookup(a.LeaderName) < Locale.Lookup(b.LeaderName) end
				table.sort( m_LeaderBan, sort_func )
				local tmp = { LeaderType = "LEADER_NONE", LeaderName = "None", LeaderIcon = "ICON_LEADER_DEFAULT"}
				m_LeaderBan[0] = tmp
			end
			
			m_LeaderBan = GetShuffledCopyOfTable(m_LeaderBan)
			
			local num = 6
			if g_slot_draft == 3 then
				num = 10
			end

			for k, leader in pairs(m_LeaderBan) do
				local b_add = true
				for i = 1, num do
					if GameConfiguration.GetValue("BAN_"..i) ~= nil then
						if leader.LeaderType == GameConfiguration.GetValue("BAN_"..i) and leader.LeaderType ~= "LEADER_NONE" then
							b_add = false
						end
					end
				end
				if g_slot_draft == 3 then
					for i = 1, g_all_players do
						if g_cached_playerIDs[i] ~= nil then
							if g_cached_playerIDs[i].HasPicked == true then
								if PlayerConfigurations[g_cached_playerIDs[i].ID] ~= nil then
									if leader.LeaderType == PlayerConfigurations[g_cached_playerIDs[i].ID]:GetLeaderTypeName() and leader.LeaderType ~= "LEADER_NONE" then
										b_add = false
									end
								end
							end
						end
					end		
				end
				if (leader.LeaderType  == nil) then
					b_add = false
				end
				if b_add == true then
					leader_rand = leader.LeaderType
					break
				end
			end
			print("Forced Picked:",g_next_ID,leader_rand)
			if g_next_ID == nil then
				print("HostSkip: g_next_ID",g_next_ID,"Shouldn't be nil")
				g_next_ID = 0
			end
			PlayerConfigurations[g_next_ID]:SetLeaderTypeName(tostring(leader_rand))
			print("Debug:",PlayerConfigurations[g_next_ID]:GetValue("LEADER_TYPE_ID"))
			print("Debug II:",PlayerConfigurations[g_next_ID]:GetLeaderTypeName())
			Network.SendChat(".valid_"..g_valid_count.."_"..g_next_ID.."_"..tostring(leader_rand),-2,-1)
			Network.BroadcastPlayerInfo()
		end
	elseif g_phase == PHASE_READY then
		if(Network.IsNetSessionHost()) then
			Network.LaunchGame()
		end
	end

end

------------------------------------------------------------------------------
function GetShuffledCopyOfTable(incoming_table)
	-- Designed to operate on tables with no gaps. Does not affect original table.
	local len = table.maxn(incoming_table);
	local copy = {};
	local shuffledVersion = {};
	-- Make copy of table.
	for loop = 1, len do
		copy[loop] = incoming_table[loop];
	end
	-- One at a time, choose a random index from Copy to insert in to final table, then remove it from the copy.
	local left_to_do = table.maxn(copy);
	for loop = 1, len do
		local random_index = 1 + math.random (left_to_do);
		table.insert(shuffledVersion, copy[random_index]);
		table.remove(copy, random_index);
		left_to_do = left_to_do - 1;
	end
	return shuffledVersion
end

function HostUnlock()
	print("HostUnlock()",g_phase)
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	g_disabled_civ = false
	g_hide_player = 0
	PlayerEntryVisibility()
	g_disabled_slot_settings = false
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		local playerEntry = g_PlayerEntries[iPlayer];
		playerEntry.PlayerAction:SetText("Unlocked")
	end
	StopCountdown();
	StartCountdown("Draft_ReadyStart")
end

function HostReset()
	print("HostReset()",g_phase)
	StopCountdown()
	UpdateAllPlayerEntries()
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local current_format = GameConfiguration.GetValue("CPL_BAN_FORMAT")
	GameConfiguration.SetValue("CPL_BAN_FORMAT",0)
	m_countdownMode = COUNTDOWN_LAUNCH
	if current_format ~= nil then
		GameConfiguration.SetValue("CPL_BAN_FORMAT",current_format)
	end
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do
		if PlayerConfigurations[iPlayer]:GetLeaderTypeName() ~= "LEADER_SPECTATOR" then
			if g_phase ~= PHASE_READY then
				PlayerConfigurations[iPlayer]:SetLeaderTypeName(nil)
			end
		end
		local playerEntry = g_PlayerEntries[iPlayer];
		playerEntry.PlayerAction:SetText("")
	end
	g_tick_size = 4
	g_disabled_civ = false
	g_disabled_slot_settings = false
	g_phase = PHASE_DEFAULT
	g_hide_player = 0
	PlayerEntryVisibility()
	g_banned_leader = nil
	b_teamer = false
	g_next_ID = nil
	g_last_team = -1
	g_ban_count = 0
	g_valid_count = 0
	g_total_players = 0
	g_all_players = 0
	b_check = false
	b_launch = false
	g_map_pool = {}
	Controls.PhaseLabel:SetHide(true)
	Controls.PhaseButton:SetHide(true)
	Controls.ResetButton:SetHide(true)
		Controls.PhaseLabel_hint:SetHide(true) 
		Controls.MapPoolLabel:SetHide(true)
		Controls.BanLabel:SetHide(true) 
		Controls.BanPullDown:SetHide(true)
		Controls.BanMadeLabel:SetHide(true) 
		Controls.PickedMapLabel:SetHide(true) 
		Controls.PickedMap2Label:SetHide(true) 
		GameConfiguration.SetValue("BAN_1",nil)
		GameConfiguration.SetValue("BAN_2",nil)
		GameConfiguration.SetValue("BAN_3",nil)
		GameConfiguration.SetValue("BAN_4",nil)
		GameConfiguration.SetValue("BAN_5",nil)
		GameConfiguration.SetValue("BAN_6",nil)
		GameConfiguration.SetValue("BAN_7",nil)
		GameConfiguration.SetValue("BAN_8",nil)
		GameConfiguration.SetValue("BAN_9",nil)
		GameConfiguration.SetValue("BAN_10",nil)
		Controls.BanMade_1:SetHide(true)
		Controls.BanMade_2:SetHide(true)
		Controls.BanMade_3:SetHide(true) 
		Controls.BanMade_4:SetHide(true) 
		Controls.BanMade_5:SetHide(true) 
		Controls.BanMade_6:SetHide(true)
		Controls.BanMade_7:SetHide(true) 
		Controls.BanMade_8:SetHide(true) 
		Controls.BanMade_9:SetHide(true) 
		Controls.BanMade_10:SetHide(true)
		Controls.BanMade_1Label:SetHide(true)
		Controls.BanMade_2Label:SetHide(true)
		Controls.BanMade_3Label:SetHide(true)
		Controls.BanMade_4Label:SetHide(true)
		Controls.BanMade_5Label:SetHide(true)
		Controls.BanMade_6Label:SetHide(true)
		Controls.BanMade_7Label:SetHide(true)
		Controls.BanMade_8Label:SetHide(true)
		Controls.BanMade_9Label:SetHide(true)
		Controls.BanMade_10Label:SetHide(true)
		Controls.PickMadeLabel:SetHide(true) 
		Controls.PickMade_1:SetHide(true)
		Controls.PickMade_2:SetHide(true)
		Controls.PickMade_3:SetHide(true) 
		Controls.PickMade_4:SetHide(true)
		Controls.PickMade_1Label:SetHide(true)
		Controls.PickMade_2Label:SetHide(true)
		Controls.PickMade_3Label:SetHide(true)
		Controls.PickMade_4Label:SetHide(true)
		Controls.PickMade_1:SetIcon("ICON_LEADER_DEFAULT")
		Controls.PickMade_2:SetIcon("ICON_LEADER_DEFAULT")
		Controls.PickMade_3:SetIcon("ICON_LEADER_DEFAULT")
		Controls.PickMade_4:SetIcon("ICON_LEADER_DEFAULT")		
		Controls.BanMade_1:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_2:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_3:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_4:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_5:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_6:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_7:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_8:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_9:SetIcon("ICON_LEADER_DEFAULT")
		Controls.BanMade_10:SetIcon("ICON_LEADER_DEFAULT")
		GameSetup_RefreshParameters()
		UpdateAllPlayerEntries()
		if localID == hostID then
			Network.BroadcastGameConfig();
		end
end

function HostForceStart()
	local localID = Network.GetLocalPlayerID()
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		OnPlayerEntryReady(iPlayer)
	end
	UpdateAllPlayerEntries()
	local playerEntry = g_PlayerEntries[localID];
	local localPlayerButton = playerEntry.ReadyImage;
	localPlayerButton:SetHide(true)
	if(Network.IsNetSessionHost()) then
		Network.LaunchGame();
	end
end

function HostLaunch()
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local connectedCount = 0
	local allCount = 0
	local version_error = -1
	g_cached_playerIDs = {}
	g_tick_size = 1
	g_valid_count = 0 
	g_total_players = nil
	g_all_players = nil
	g_disabled_slot_settings = true
	
	-- Clean the Bans
	GameConfiguration.SetValue("BAN_1","LEADER_NONE")
	GameConfiguration.SetValue("BAN_2","LEADER_NONE")
	GameConfiguration.SetValue("BAN_3","LEADER_NONE")
	GameConfiguration.SetValue("BAN_4","LEADER_NONE")
	GameConfiguration.SetValue("BAN_5","LEADER_NONE")
	GameConfiguration.SetValue("BAN_6","LEADER_NONE")
	GameConfiguration.SetValue("BAN_7","LEADER_NONE")
	GameConfiguration.SetValue("BAN_8","LEADER_NONE")
	GameConfiguration.SetValue("BAN_9","LEADER_NONE")
	GameConfiguration.SetValue("BAN_10","LEADER_NONE")
	Controls.BanMade_1:SetIcon("ICON_LEADER_DEFAULT")
	Controls.BanMade_2:SetIcon("ICON_LEADER_DEFAULT")
	Controls.BanMade_3:SetIcon("ICON_LEADER_DEFAULT")
	Controls.BanMade_4:SetIcon("ICON_LEADER_DEFAULT")
	Controls.BanMade_5:SetIcon("ICON_LEADER_DEFAULT")
	Controls.BanMade_6:SetIcon("ICON_LEADER_DEFAULT")
	Controls.BanMade_7:SetIcon("ICON_LEADER_DEFAULT")
	Controls.BanMade_8:SetIcon("ICON_LEADER_DEFAULT")
	Controls.BanMade_9:SetIcon("ICON_LEADER_DEFAULT")
	Controls.BanMade_10:SetIcon("ICON_LEADER_DEFAULT")
	Controls.BanMade_1Label:SetHide(true)
	Controls.BanMade_2Label:SetHide(true)
	Controls.BanMade_3Label:SetHide(true)
	Controls.BanMade_4Label:SetHide(true)
	Controls.BanMade_5Label:SetHide(true)
	Controls.BanMade_6Label:SetHide(true)
	Controls.BanMade_7Label:SetHide(true)
	Controls.BanMade_8Label:SetHide(true)
	Controls.BanMade_9Label:SetHide(true)
	Controls.BanMade_10Label:SetHide(true)
		Controls.PickMadeLabel:SetHide(true) 
		Controls.PickMade_1:SetHide(true)
		Controls.PickMade_2:SetHide(true)
		Controls.PickMade_3:SetHide(true) 
		Controls.PickMade_4:SetHide(true)
		Controls.PickMade_1Label:SetHide(true)
		Controls.PickMade_2Label:SetHide(true)
		Controls.PickMade_3Label:SetHide(true)
		Controls.PickMade_4Label:SetHide(true)
	GameConfiguration.SetValue("BAN_1",nil)
	GameConfiguration.SetValue("BAN_2",nil)
	GameConfiguration.SetValue("BAN_3",nil)
	GameConfiguration.SetValue("BAN_4",nil)
	GameConfiguration.SetValue("BAN_5",nil)
	GameConfiguration.SetValue("BAN_6",nil)
	GameConfiguration.SetValue("BAN_7",nil)
	GameConfiguration.SetValue("BAN_8",nil)
	GameConfiguration.SetValue("BAN_9",nil)
	GameConfiguration.SetValue("BAN_10",nil)
	if localID == hostID then
		Network.BroadcastGameConfig();
	end
	if GameConfiguration.GetValue("CPL_BAN_FORMAT") == 3 then
		-- Tournament
		g_phase = PHASE_MAPBAN
		
		local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
		for i, iPlayer in ipairs(player_ids) do	
			if PlayerConfigurations[iPlayer]:GetLeaderTypeName() ~= "LEADER_SPECTATOR" then
				PlayerConfigurations[iPlayer]:SetLeaderTypeName(nil)
			end
			print("ID",iPlayer,"version:",g_version_map[iPlayer],"host:",g_version_map["HOST"] )
			if Network.IsPlayerConnected(iPlayer) == true and g_version_map[iPlayer] ~= g_version_map["HOST"] then
				version_error = iPlayer
				print("Error: ID",iPlayer,"version:",g_version_map[iPlayer],"host:",g_version_map["HOST"] )
			end
			if ( ( Network.IsPlayerConnected(iPlayer) or (g_debug == true  ) ) and PlayerConfigurations[iPlayer]:GetLeaderTypeName() == "LEADER_SPECTATOR") then
				OnPlayerEntryReady(iPlayer)
				allCount = allCount + 1
				tmp = { ID = iPlayer, Observer = true, Team = -1, HasPicked = true, HasBan = true, IsVisible = false }
				table.insert(g_cached_playerIDs,tmp)
			end
			if( ( Network.IsPlayerConnected(iPlayer) or (g_debug == true and PlayerConfigurations[iPlayer]:GetTeam() ~= -1) ) and PlayerConfigurations[iPlayer]:GetLeaderTypeName() ~= "LEADER_SPECTATOR") then
				connectedCount = connectedCount + 1;
				allCount = allCount + 1
				tmp = { ID = iPlayer, Observer = false, Team = PlayerConfigurations[iPlayer]:GetTeam(), HasPicked = false, HasBan = false, IsVisible = false  }
				table.insert(g_cached_playerIDs,tmp)
			end
		end
			
			
	end
	
	if GameConfiguration.GetValue("CPL_BAN_FORMAT") == 4 then
		-- Vote Draft
		g_phase = PHASE_VOTE_BAN_MAP
		
		local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
		for i, iPlayer in ipairs(player_ids) do	
			if ( ( Network.IsPlayerConnected(iPlayer) or (g_debug == true  ) ) and PlayerConfigurations[iPlayer]:GetLeaderTypeName() == "LEADER_SPECTATOR") then
				OnPlayerEntryReady(iPlayer)
				allCount = allCount + 1
				tmp = { ID = iPlayer, Observer = true, Team = -1, HasVotedMap = true, HasPicked = false, HasVotedBan = true, IsVisible = false, VotedScript = nil, VotedTemp = nil, VotedAge = nil, Ban_1 = nil, Ban_2 = nil, Ban_3 = nil  }
				table.insert(g_cached_playerIDs,tmp)
			end
			if( ( Network.IsPlayerConnected(iPlayer) or (g_debug == true and PlayerConfigurations[iPlayer]:GetTeam() ~= -1) ) and PlayerConfigurations[iPlayer]:GetLeaderTypeName() ~= "LEADER_SPECTATOR") then
				connectedCount = connectedCount + 1;
				allCount = allCount + 1
				tmp = { ID = iPlayer, Observer = false, Team = PlayerConfigurations[iPlayer]:GetTeam(), HasVotedMap = false, HasPicked = false, HasVotedBan = false, IsVisible = false, VotedScript = nil, VotedTemp = nil, VotedAge = nil, Ban_1 = nil, Ban_2 = nil, Ban_3 = nil   }
				table.insert(g_cached_playerIDs,tmp)
			end
		end
			
			
	end

	-- Error Check for Version
	local teamCounts = {};
	GetTeamCounts(teamCounts);
	for i = 0,4 do
		if teamCounts[i] ~= nil then
			if teamCounts[i] > 0 then
				b_teamer = true
			end
		end
	end
	
	if connectedCount > 1 then
		local sort_func = function( a,b ) return a.ID < b.ID end
		table.sort( g_cached_playerIDs, sort_func )
	end
	
	g_total_players = connectedCount
	g_all_players = allCount
	
	-- Build the map pool
	g_map_pool = {}
	if GameConfiguration.GetValue("DRAFT_MAP") == true then
	
	
	local pool_size = 0
	for i = 1,15 do
		if GameConfiguration.GetValue("BAN_POOL_"..i) ~= nil then
			local tmp = {}
			tmp = { Map = GameConfiguration.GetValue("BAN_POOL_"..i.."_NAME") , Allowed = GameConfiguration.GetValue("BAN_POOL_"..i), ID = i}
			table.insert(g_map_pool,tmp)
			if g_debug == true then
				print("Map Pool",tmp.Map,tmp.Allowed,tmp.ID)
			end
			if GameConfiguration.GetValue("BAN_POOL_"..i) == true then
				pool_size = pool_size + 1
			end
		end
	end
	
	local map_left = 0
	Controls.MapPoolLabel:SetHide(false)
	for i = 1, 16 do
		if g_map_pool[i] ~= nil then
			if g_map_pool[i].ID == ban_map then
				g_map_pool[i].Allowed = false
			end
			if i ~= 3 then
				if g_map_pool[i].Allowed == false then
					local label = Controls["MapPool_"..g_map_pool[i].ID.."Label"]
					label:SetText("[COLOR_Civ6Red]"..string.sub(g_map_pool[i].Map,1,5)..".[ENDCOLOR]")
					label:SetHide(false)
					elseif g_map_pool[i].Allowed == true then
					local label = Controls["MapPool_"..g_map_pool[i].ID.."Label"]
					label:SetText(string.sub(g_map_pool[i].Map,1,5)..".")
					label:SetHide(false)
					map_left = map_left + 1
				end
				else
				if g_map_pool[i].Allowed == false  then
					local label = Controls["MapPool_"..g_map_pool[i].ID.."Label"]
					label:SetText("[COLOR_Civ6Red]C. Isles[ENDCOLOR]")
					label:SetHide(false)
					elseif g_map_pool[i].Allowed == true then
					local label = Controls["MapPool_"..g_map_pool[i].ID.."Label"]
					label:SetText("C. Isles")
					label:SetHide(false)
					map_left = map_left + 1
				end
			end
		end
	end
	

	if map_left > 0 then
		-- Send the first player Action
		g_next_ID = nil
		if localID == hostID then
			Network.SendChat(".chgphase_"..g_phase,-2,-1)
			g_next_ID = GetNextID()
			print("HostLaunch() - map_left",map_left,"g_phase",g_phase,"next ID",g_next_ID)
			Network.SendChat(".idnext_"..g_next_ID,-2,-1)
		end
		else
		-- No map in the pool - skip
		g_phase = PHASE_LEADERBAN
		if GameConfiguration.GetValue("CPL_BAN_FORMAT") == 4 then
			-- Vote Draft
			g_phase = PHASE_VOTE_BAN_LEADER
		end
		g_ban_count = 0
		g_next_ID = nil
		if localID == hostID then
			Network.SendChat(".chgphase_"..g_phase,-2,-1)
			g_next_ID = GetNextID()
			print("HostLaunch() - map_left",map_left,"g_phase",g_phase,"next ID",g_next_ID)
			Network.SendChat(".idnext_"..g_next_ID,-2,-1)
		end
	end
	
	else
		g_phase = PHASE_LEADERBAN
		if GameConfiguration.GetValue("CPL_BAN_FORMAT") == 4 then
			-- Vote Draft
			g_phase = PHASE_VOTE_BAN_LEADER
		end
		g_ban_count = 0
		g_next_ID = nil
		if localID == hostID then
			Network.SendChat(".chgphase_"..g_phase,-2,-1)
			g_next_ID = GetNextID()
			print("HostLaunch() - map_left",map_left,"g_phase",g_phase,"next ID",g_next_ID)
			Network.SendChat(".idnext_"..g_next_ID,-2,-1)
		end
	end
	
end

-------------------------------------------------


function OnReceiveNextID(next_id:number)
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	Refresh()
	RefreshStatus()
	if next_id ~= nil then
		g_next_ID = next_id
	end
	if g_phase == PHASE_VOTE_BAN_MAP then
		OnVoteMap()
		if g_timer == 1 then
			StopCountdown();
			StartCountdown("Draft_MapBan")	
		end
	end
	if g_phase == PHASE_VOTE_BAN_LEADER then
		OnVoteBan()
		if g_timer == 1 then
			StopCountdown();
			StartCountdown("Draft_LeaderBan")
		end
		if localID == hostID then
			Network.BroadcastGameConfig();
		end
		RealizeGameSetup()
	end
	if g_phase == PHASE_MAPBAN then
		OnNextMap()
		if g_timer == 1 then
			StopCountdown();
			StartCountdown("Draft_MapBan")
		end
	end
	if g_phase == PHASE_LEADERBAN then
		OnNextBan()
		if g_timer == 1 then
			StopCountdown();
			StartCountdown("Draft_LeaderBan")
		end
		if localID == hostID then
			Network.BroadcastGameConfig();
		end
	end
	if g_phase == PHASE_LEADERPICK then
		if next_id ~= nil then
			PlayerConfigurationValuesToUI(next_id)
		end
		OnNextValid()
		if g_timer == 1 then
			StopCountdown();
			StartCountdown("Draft_LeaderPick")
		end
		if localID == hostID then
			Network.BroadcastGameConfig();
		end
		g_disabled_civ = true
		Controls.MPH_Leader_ConfirmButton:SetDisabled(true)
	end
	if g_phase == PHASE_READY then
		if g_timer == 1 then
			StopCountdown();
			StartCountdown("Draft_ReadyStart")
		end
	end
	for i, player in ipairs(g_cached_playerIDs) do
		local playerEntry = g_PlayerEntries[player.ID];
		playerEntry.PlayerAction:SetText("");
		if g_next_ID == player.ID then
			if g_phase == PHASE_MAPBAN or g_phase == PHASE_LEADERBAN then
				playerEntry.PlayerAction:SetText("[COLOR_Civ6Red]Banning[ENDCOLOR]")
			end
			if g_phase == PHASE_LEADERPICK then
				playerEntry.PlayerAction:SetText("[COLOR_Civ6Green]Picking[ENDCOLOR]")
				player.IsVisible = true
				if localID  == player.ID then
					g_disabled_civ = false
					Controls.MPH_Leader_ConfirmButton:SetDisabled(false)
				end
			end
			else
			if g_phase == PHASE_MAPBAN or g_phase == PHASE_LEADERBAN then
				playerEntry.PlayerAction:SetText("Locked")
			end
			if g_phase == PHASE_LEADERPICK  then
				playerEntry.PlayerAction:SetText("Locked")
				if player.IsVisible == true then
					playerEntry.PlayerAction:SetText("[COLOR_Civ6Green]Ready[ENDCOLOR]")
				end
			end
		end
		if g_phase == PHASE_VOTE_BAN_MAP  then
			playerEntry.PlayerAction:SetText("[COLOR_Civ6Green]Voting[ENDCOLOR]")
		end	
		if g_phase == PHASE_VOTE_BAN_LEADER  then
			playerEntry.PlayerAction:SetText("[COLOR_Civ6Red]Banning[ENDCOLOR]")
		end	
		if g_phase == PHASE_READY  then
			playerEntry.PlayerAction:SetText("[COLOR_Civ6Green]Ready[ENDCOLOR]")
			g_disabled_civ = true
		end	
		if player.Observer == true then
			playerEntry.PlayerAction:SetText("[COLOR_Civ6Green]Observer[ENDCOLOR]")
		end
	end
end

function GetNextID()
	print("GetNextID() g_phase",g_phase,"g_next_ID",g_next_ID,"g_slot_draft",g_slot_draft,"b_teamer",b_teamer)
	-- 0: RANDOM 1: Slot	2: CWC		3: NEW CWC
	-- first let's check our cached data from HostLaunch() exist
	if g_cached_playerIDs == nil then
		print("Error: g_cached_playerIDs is nil")
		return
	end

	local last_ID = g_next_ID
	if last_ID ~= nil then
		Network.BroadcastPlayerInfo(last_ID)
	end
	print("Last ID was:",g_next_ID)
	----------------------------------------------------------------------------
	-- Map Ban
	----------------------------------------------------------------------------
	if g_phase == PHASE_MAPBAN then
	
	----------------------------------------------------------------------------
	-- initialise (first time)
	----------------------------------------------------------------------------
		if last_ID == nil then
			-- Slot order or CWC ? Pick the first non spec player
			if g_slot_draft == 1 or g_slot_draft == 2 or g_slot_draft == 3 then
				for i, player in ipairs(g_cached_playerIDs) do
					if player.Observer == false then
						return player.ID
					end
				end
				
				else -- Random Order Initialise
				
				local count = 0
				
				for i, player in ipairs(g_cached_playerIDs) do
					if player.Observer == false then
						count = count + 1
					end
				end	

				local rnd = math.random(1,count)

				count = 0 
				for i, player in ipairs(g_cached_playerIDs) do
					if player.Observer == false then
						count = count + 1
						if count == rnd then
							return player.ID						
						end
					end
				end					
					
			end
	-----------------------------------------------------------------------------
	-- Subsequent Map Ban
	-----------------------------------------------------------------------------
			else 
			
			-- Slot Order 
			if g_slot_draft == 1 then
				local found_previous = false
				local next_in_line = nil
			
				for i, player in ipairs(g_cached_playerIDs) do
					if found_previous == true and player.Observer == false then
						next_in_line = player.ID 
						return player.ID 
					end
					if player.ID == last_ID  then
						found_previous = true
					end
				end

				if 	found_previous == true then
					-- We finished the list restart from the beginning
					for i, player in ipairs(g_cached_playerIDs) do
						if player.Observer == false then
							return player.ID
						end
					end					
				end
				
				elseif g_slot_draft == 0 or g_slot_draft == 2 or g_slot_draft == 3 then -- Random Subsequent Ban
				
				if b_teamer == true then
					-- How many unique Teams ?
					local team_tmp = {}
					local count_team = 0
					for i, player in ipairs(g_cached_playerIDs) do
						if player.Observer == false then
							if team_tmp ~= nil then
								local team_already_in = false
								for i, team in ipairs(team_tmp) do
									if player.Team == team then
										team_already_in = true
									end
								end
								if team_already_in == false then
									table.insert(team_tmp, player.Team)
									count_team = count_team + 1
								end
							end
						end
					end	
					
					-- Get previous acting team
					local previous_team = nil
					for i, player in ipairs(g_cached_playerIDs) do
						if player.ID == last_ID then
							previous_team = player.Team
							break
						end
					end	
					
					local found_previous_team = false
					local next_team = nil
					-- get next team
					for i, team in ipairs(team_tmp) do
						if found_previous_team == true then
							next_team = team
							break
						end 
						if team == previous_team then
							found_previous_team = true
						end
					end
					
					if next_team == nil then -- restart with first team
						for i, team in ipairs(team_tmp) do
							if team ~= nil then
								next_team = team
								break
							end
						end						
					end
					
					-- Get Captain of the next team
					for i, player in ipairs(g_cached_playerIDs) do
						if player.Observer == false and player.Team == next_team then
							return player.ID							
						end
					end				
					
					else -- FFA Random / basically like slot order
					local found_previous = false
					local next_in_line = nil
			
					for i, player in ipairs(g_cached_playerIDs) do
						if found_previous == true and player.Observer == false then
							next_in_line = player.ID 
							return player.ID
						end
						if player.ID == last_ID then
							found_previous = true
						end
					end

					if 	found_previous == true then
						-- We finished the list restart from the beginning
						for i, player in ipairs(g_cached_playerIDs) do
							if player.Observer == false then
								return player.ID
							end
						end					
					end
					
				end
			end
		
		end
	
	end
	-----------------------------------------------------------------------------------
	-- Leader Ban
	-----------------------------------------------------------------------------------
	if g_phase == PHASE_LEADERBAN then
	-----------------------------------------------------------------------------------
	-- initialise (first time)
	-- If HostLaunch() with no Map Ban then we start with nil
	-- If HostLaunch() with Map Ban, the id is also reset to nil while entering the leader ban
	-- => The first player in slot will always have the first ban for both map and leader
	-----------------------------------------------------------------------------------
		if last_ID == nil then
			-- Slot order? Pick the first non spec player
			if g_slot_draft == 1 or g_slot_draft == 2 or g_slot_draft == 3 then
				for i, player in ipairs(g_cached_playerIDs) do
					if player.Observer == false then
						return player.ID
					end
				end
				
				elseif g_slot_draft == 0 then -- Random Order Initialise
				
				local count = 0
				
				for i, player in ipairs(g_cached_playerIDs) do
					if player.Observer == false then
						count = count + 1
					end
				end	

				local rnd = math.random(1,count)

				count = 0 
				for i, player in ipairs(g_cached_playerIDs) do
					if player.Observer == false then
						count = count + 1
						if count == rnd then
							return player.ID						
						end
					end
				end					
					
			end
		--------------------------------------------------------------------------------
		 -- Subsequent Leader Ban
		--------------------------------------------------------------------------------	
			else
			
			----------------------------------------------------------------------------
			-- Slot Order 
			----------------------------------------------------------------------------
			if g_slot_draft == 1 then
				local found_previous = false
				local next_in_line = nil
			
				for i, player in ipairs(g_cached_playerIDs) do
					if found_previous == true and player.Observer == false then
						next_in_line = player.ID 
						return player.ID 
					end
					if player.ID == last_ID  then
						found_previous = true
					end
				end

				if 	found_previous == true then
					-- We finished the list restart from the beginning
					for i, player in ipairs(g_cached_playerIDs) do
						if player.Observer == false then
							return player.ID
						end
					end					
				end
				
			-------------------------------------------------------------------------------
			-- Non Slot: Alternate between team, CWC would alternate
			-------------------------------------------------------------------------------		
				
				elseif g_slot_draft == 0 or g_slot_draft == 2 or g_slot_draft == 3 then 
				
				if b_teamer == true then
					-- How many unique Teams ?
					local team_tmp = {}
					local count_team = 0
					for i, player in ipairs(g_cached_playerIDs) do
						if player.Observer == false then
							if team_tmp ~= nil then
								local team_already_in = false
								for i, team in ipairs(team_tmp) do
									if player.Team == team then
										team_already_in = true
									end
								end
								if team_already_in == false then
									table.insert(team_tmp, player.Team)
									count_team = count_team + 1
								end
							end
						end
					end	
					
					-- Get previous acting team
					local previous_team = nil
					for i, player in ipairs(g_cached_playerIDs) do
						if player.ID == last_ID then
							previous_team = player.Team
							break
						end
					end	
					
					local found_previous_team = false
					local next_team = nil
					-- get next team
					for i, team in ipairs(team_tmp) do
						if found_previous_team == true then
							next_team = team
							break
						end 
						if team == previous_team then
							found_previous_team = true
						end
					end
					
					if next_team == nil then -- restart with first team
						for i, team in ipairs(team_tmp) do
							if team ~= nil then
								next_team = team
								break
							end
						end						
					end
					
					-- Get Captain of the next team
					for i, player in ipairs(g_cached_playerIDs) do
						if player.Observer == false and player.Team == next_team then
							return player.ID							
						end
					end				
					
					else -- FFA Random / basically like slot order
					local found_previous = false
					local next_in_line = nil
			
					for i, player in ipairs(g_cached_playerIDs) do
						if found_previous == true and player.Observer == false then
							next_in_line = player.ID 
							return player.ID
						end
						if player.ID == last_ID then
							found_previous = true
						end
					end

					if 	found_previous == true then
						-- We finished the list restart from the beginning
						for i, player in ipairs(g_cached_playerIDs) do
							if player.Observer == false then
								return player.ID
							end
						end					
					end
					
				end
			end
		
		end
	
	end
	--------------------------------------------------------------------------------------
	-- Pick Phase
	--------------------------------------------------------------------------------------
	if g_phase == PHASE_LEADERPICK then
		print("Phase is: PHASE_LEADERPICK")
	--------------------------------------------------------------------------------------	
	-- initialise (first time)
	--------------------------------------------------------------------------------------
		if last_ID == nil then
			-- Slot order? Pick the first non spec player
			if g_slot_draft == 1 or g_slot_draft == 2 or g_slot_draft == 3 then
				for i, player in ipairs(g_cached_playerIDs) do
					if player.Observer == false and player.HasPicked == false then
						return player.ID
					end
				end
				
				elseif g_slot_draft == 0 then -- Random Order Initialise
				
				local count = 0
				
				for i, player in ipairs(g_cached_playerIDs) do
					if player.Observer == false then
						count = count + 1
					end
				end	

				local rnd = math.random(1,count)

				count = 0 
				for i, player in ipairs(g_cached_playerIDs) do
					if player.Observer == false then
						count = count + 1
						if count == rnd then
							return player.ID						
						end
					end
				end					
					
			end
			
			else -- Subsequent Pick
			
			-- Slot Order 
			if g_slot_draft == 1 or g_slot_draft == 2 or g_slot_draft == 3 then
				local found_previous = false
				local next_in_line = nil
			
				for i, player in ipairs(g_cached_playerIDs) do
					print("GetNextID()",i,player.ID,player.Observer,player.HasPicked)
					if found_previous == true and player.Observer == false and player.HasPicked == false then
						next_in_line = player.ID 
						return player.ID 
					end
					if player.ID == last_ID  then
						found_previous = true
					end
				end

				if 	found_previous == true then
					-- We finished the list restart from the beginning
					for i, player in ipairs(g_cached_playerIDs) do
						if player.Observer == false and player.HasPicked == false then
							return player.ID
						end
					end					
				end
				
				elseif g_slot_draft == 0 then -- Random Subsequent Ban
				
				if b_teamer == true then
					-- How many unique Teams ?
					local team_tmp = {}
					local count_team = 0
					for i, player in ipairs(g_cached_playerIDs) do
						if player.Observer == false and player.HasPicked == false then
							if team_tmp ~= nil then
								local team_already_in = false
								for i, team in ipairs(team_tmp) do
									if player.Team == team then
										team_already_in = true
									end
								end
								if team_already_in == false then
									table.insert(team_tmp, player.Team)
									count_team = count_team + 1
								end
							end
						end
					end	
					
					-- Get previous acting team
					local previous_team = nil
					for i, player in ipairs(g_cached_playerIDs) do
						if player.ID == last_ID then
							previous_team = player.Team
							break
						end
					end	
					
					local found_previous_team = false
					local next_team = nil
					-- get next team
					for i, team in ipairs(team_tmp) do
						if found_previous_team == true then
							next_team = team
							break
						end 
						if team == previous_team then
							found_previous_team = true
						end
					end
					
					if next_team == nil then -- restart with first team
						for i, team in ipairs(team_tmp) do
							if team ~= nil then
								next_team = team
								break
							end
						end						
					end
					
					-- Get the next non picked of the next team
					for i, player in ipairs(g_cached_playerIDs) do
						if player.Observer == false and player.Team == next_team and player.HasPicked == false then
							return player.ID							
						end
					end				
					
					else -- FFA Random / basically like slot order
					local found_previous = false
					local next_in_line = nil
			
					for i, player in ipairs(g_cached_playerIDs) do
						if found_previous == true and player.Observer == false and player.HasPicked == false then
							next_in_line = player.ID 
							return player.ID
						end
						if player.ID == last_ID then
							found_previous = true
						end
					end
					
					if 	found_previous == true then
						-- We finished the list restart from the beginning
						for i, player in ipairs(g_cached_playerIDs) do
							if player.Observer == false and player.HasPicked == false then
								return player.ID
							end
						end					
					end
					
				end
			end
		
		end
	
	end
	-- Final Phase
	if g_phase == PHASE_READY then
		return 0
	end
	
	-- VoteMap Phase
	if g_phase == PHASE_VOTE_BAN_MAP then
		return 11
	end
	
	-- VoteMap Phase
	if g_phase == PHASE_VOTE_BAN_LEADER then
		return 11
	end

end


function OnVoteMap()

	local localID = Network.GetLocalPlayerID()

	PopulateMapVotePulldown(localID)
	
	Controls.VoteMapScriptPullDown:SetHide(false)
	Controls.VoteMapAgePullDown:SetHide(false)
	Controls.VoteMapTempPullDown:SetHide(false)
	Controls.VoteMapScriptPullDown:SetDisabled(false)
	Controls.VoteMapAgePullDown:SetDisabled(false)
	Controls.VoteMapTempPullDown:SetDisabled(false)
	
	Controls.MPH_VoteButton:ClearCallback(Mouse.eLClick)
	Controls.MPH_VoteButton:SetDisabled(false)
	Controls.MPH_VoteButton:RegisterCallback(Mouse.eLClick,function() OnConfirmMapVote(localID); end)
	
	Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_MAP_VOTE_TEXT"))


end

function OnVoteBan()
	local localID = Network.GetLocalPlayerID()
	local bannumber = g_ban_count
	
	PopulateBanList(bannumber,localID)
	Controls.MPH_VoteButton:SetHide(false)
	Controls.MPH_VoteButton:ClearCallback(Mouse.eLClick)
	Controls.MPH_VoteButton:SetDisabled(false)
	Controls.MPH_VoteButton:RegisterCallback(Mouse.eLClick,function() OnConfirmBanVote(localID,bannumber); end)
	Controls.BanLabel:SetHide(false)
	Controls.BanPullDown:SetHide(false)	
	Controls.BanPullDown:SetDisabled(false)	
	Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_BAN_VOTE_TEXT"))


end

function OnNextMap()
	local map_left:number = 0
	local map_index:number = 0
	local localID = Network.GetLocalPlayerID()
	local tmp_id = -1
	local id = -1
	local bannumber = g_ban_count 
	for i = 1,15 do
		if g_map_pool[i] ~= nil then
			if g_map_pool[i].Allowed == true then
				map_left = map_left + 1
				map_index = i
			end
		end
	end
	
	if g_debug == true then
		print("OnNextMap - Ban #",bannumber, "Map Left",map_left)
	end
	
	if localID == g_next_ID then 
		if map_left == 0 or map_left == 1 then
			if map_left == 1 then
				Network.SendChat(".mapban_"..bannumber.."_"..localID.."_"..g_map_pool[map_index].ID,-2,-1)
			end
		end
	end

	if g_debug == true then
		print("OnNextMap g_next_ID",g_next_ID)
	end
	
	PopulateMapList(bannumber,g_next_ID)
	Controls.MPH_ConfirmButton:SetHide(true)
	if localID == g_next_ID then 

		local playerEntry = g_PlayerEntries[localID];
		Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_MAP_BAN_TEXT"))
		Controls.BanMapLabel:SetHide(false)
		Controls.BanMapPullDown:SetHide(false)	

		else
		if PlayerConfigurations[g_next_ID] ~= nil then
			if PlayerConfigurations[g_next_ID]:GetPlayerName() ~= nil then
				if b_teamer == false then
					Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_MAP_BAN_FFA_TEXT").." ( ID: "..g_next_ID..")")
					else
					Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_MAP_BAN_FFA_TEXT").." ( Team "..(PlayerConfigurations[g_next_ID]:GetTeam()+1).." / ID: "..g_next_ID..")")
				end
				else
				Controls.StartLabel:SetText("ERROR - phase"..g_phase.." - Ban - "..g_ban_count.." - Tot - "..g_total_players)
			end
			else
			Controls.StartLabel:SetText("ERROR - phase"..g_phase.." - Ban - "..g_ban_count.." - Tot - "..g_total_players)
		end
		Controls.BanMapLabel:SetHide(true)
		Controls.BanMapPullDown:SetHide(true)
	end
end

function OnNextBan()
	local tmp_id = -1
	local id = -1
	local bannumber = g_ban_count + 1
	if g_debug == true then
		print("OnNextBan - Ban #",bannumber)
	end
	
	if g_debug == true then
		print("OnNextBan g_next_ID",g_next_ID)
	end
	PopulateBanList(bannumber,g_next_ID)
	Controls.MPH_ConfirmButton:SetHide(true)
	local localID = Network.GetLocalPlayerID()
	if localID == g_next_ID then 
		Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_LEADER_BAN_TEXT"))
		Controls.BanLabel:SetHide(false)
		Controls.BanPullDown:SetHide(false)	
		Controls.BanPullDown:SetDisabled(false)	

		else
		if PlayerConfigurations[g_next_ID] ~= nil then
			if PlayerConfigurations[g_next_ID]:GetPlayerName() ~= nil then
				if b_teamer == false then
					Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_LEADER_BAN_FFA_TEXT").." ( ID: "..g_next_ID..")")
					else
					Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_LEADER_BAN_FFA_TEXT").." ( Team "..(PlayerConfigurations[g_next_ID]:GetTeam()+1).." / ID: "..g_next_ID..")")
				end
				else
				Controls.StartLabel:SetText("ERROR - phase"..g_phase.." - Ban - "..g_ban_count.." - Tot - "..g_total_players)
			end
			else
			Controls.StartLabel:SetText("ERROR - phase"..g_phase.." - Ban - "..g_ban_count.." - Tot - "..g_total_players)
		end
		Controls.BanLabel:SetHide(true)
		Controls.BanPullDown:SetHide(true)
	end
end

function OnNextValid()
	local valid = g_valid_count
	if g_debug == true then
		print("OnNextValid - Valid #",valid)
	end
	
	local localID = Network.GetLocalPlayerID()
	if localID == g_next_ID then 
		local playerEntry = g_PlayerEntries[localID];
		local civTooltipData : table = {
			InfoStack			= m_CivTooltip.InfoStack,
			InfoScrollPanel		= m_CivTooltip.InfoScrollPanel;
			CivToolTipSlide		= m_CivTooltip.CivToolTipSlide;
			CivToolTipAlpha		= m_CivTooltip.CivToolTipAlpha;
			UniqueIconIM		= m_CivTooltip.UniqueIconIM;		
			HeaderIconIM		= m_CivTooltip.HeaderIconIM;
			CivHeaderIconIM		= m_CivTooltip.CivHeaderIconIM;
			HeaderIM			= m_CivTooltip.HeaderIM;
			HasLeaderPlacard	= false;
		};

		Controls.MPH_Leader_ConfirmButton:ClearCallback(Mouse.eLClick)
		Controls.MPH_Leader_ConfirmButton:RegisterCallback(Mouse.eLClick, function() OnConfirmValid(localID,valid); end )
		Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_LEADER_PICK_TEXT"))
		else
		if PlayerConfigurations[g_next_ID] ~= nil then
			if PlayerConfigurations[g_next_ID]:GetPlayerName() ~= nil then
				if b_teamer == false then
					Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_LEADER_PICK_FFA_TEXT").." ( ID: "..g_next_ID..")")
					else
					Controls.StartLabel:SetText(Locale.Lookup("LOC_MPH_READY_WAITING_LEADER_PICK_FFA_TEXT").." ( Team "..(PlayerConfigurations[g_next_ID]:GetTeam()+1).." / ID: "..g_next_ID..")")
				end
				else
				Controls.StartLabel:SetText("ERROR - phase"..g_phase.." - Valid - "..g_valid_count)
			end
			else
			Controls.StartLabel:SetText("ERROR - phase"..g_phase.." - Valid - "..g_valid_count)
		end
	end
end

function OnSelectBan(num:number,playerID:number,leader:string)
	local localID = Network.GetLocalPlayerID()
	local bannumber = g_ban_count + 1
	g_banned_leader = leader
	GameConfiguration.SetValue("BAN_"..num,g_banned_leader)
	if GameConfiguration.GetValue("BAN_"..num) ~= nil then
		for k , v in pairs(m_LeaderBan) do
			if v.LeaderType == GameConfiguration.GetValue("BAN_"..num) then
				local button = Controls.BanPullDown:GetButton()
				button:SetText(Locale.Lookup(v.LeaderName))
				Controls.BanPullDown_Icon:SetIcon(v.LeaderIcon)
			end
		end
	end
	if localID == g_next_ID then 
		Controls.MPH_ConfirmButton:SetHide(false)
		Controls.MPH_ConfirmButton:ClearCallback(Mouse.eLClick)
		Controls.MPH_ConfirmButton:RegisterCallback(Mouse.eLClick, function() OnConfirmBan(localID,bannumber); end )
	end
	--Controls.MPH_VoteButton:SetHide(false)
	PhaseVisibility()
end

function OnSelectMapBan(num:number,playerID:number,ID:number)
	local localID = Network.GetLocalPlayerID()
	local bannumber = g_ban_count 
	g_banned_map = ID
	for k, map in pairs(g_map_pool) do
		if map.ID == ID then
			local button = Controls.BanMapPullDown:GetButton()
			button:SetText(map.Map)
		end
	end
	if localID == g_next_ID then 
		Controls.MPH_ConfirmButton:SetHide(false)
		Controls.MPH_ConfirmButton:ClearCallback(Mouse.eLClick)
		Controls.MPH_ConfirmButton:RegisterCallback(Mouse.eLClick, function() OnConfirmMapBan(localID,bannumber); end )
	end
	PhaseVisibility()
end

function OnSelectMapScript(playerID:number,ID:number)
	local localID = Network.GetLocalPlayerID()
	if localID ~= playerID then
		return
	end
	g_map_script = ID
	for k, map in pairs(g_map_pool) do
		if map.ID == ID then
			local button = Controls.VoteMapScriptPullDown:GetButton()
			button:SetText(map.Map)
		end
	end
	Controls.MPH_VoteButton:SetHide(false)
	PhaseVisibility()
end

function OnSelectMapAge(playerID:number,age:number, text:string)
	local localID = Network.GetLocalPlayerID()
	if localID ~= playerID then
		return
	end
	g_map_age = age
	local button = Controls.VoteMapAgePullDown:GetButton()
	button:SetText(text)
	Controls.MPH_VoteButton:SetHide(false)
	PhaseVisibility()
end

function OnSelectMapTemp(playerID:number,temp:number, text:string)
	local localID = Network.GetLocalPlayerID()
	if localID ~= playerID then
		return
	end
	g_map_temp = temp
	local button = Controls.VoteMapTempPullDown:GetButton()
	button:SetText(text)
	Controls.MPH_VoteButton:SetHide(false)
	PhaseVisibility()
end

function PopulateBanList(num:number,playerID:number)

	m_LeaderBan = nil
	if m_LeaderBan == nil then
		m_LeaderBan = {}
		local info_query = "SELECT * from Players where Domain = ?";
		local domain = "Players:Expansion2_Players"
		local info_results = DB.ConfigurationQuery(info_query, domain);
		for k , v in pairs(info_results) do
			local tmp = { LeaderType = v.LeaderType, LeaderName = v.LeaderName, LeaderIcon = v.LeaderIcon}
			if tmp.LeaderType ~= "LEADER_SPECTATOR" and tmp.LeaderType ~= "RANDOM"  then
				table.insert(m_LeaderBan, tmp)
			end
		end
		local sort_func = function( a,b ) return Locale.Lookup(a.LeaderName) < Locale.Lookup(b.LeaderName) end
		table.sort( m_LeaderBan, sort_func )
		local tmp = { LeaderType = "LEADER_NONE", LeaderName = "None", LeaderIcon = "ICON_LEADER_DEFAULT"}
		m_LeaderBan[0] = tmp
	end
	
	Controls.BanPullDown:ClearEntries()
	for k, leader in pairs(m_LeaderBan) do
		local b_add = true
		for i = 1, num do
			if GameConfiguration.GetValue("BAN_"..i) ~= nil then
				if leader.LeaderType == GameConfiguration.GetValue("BAN_"..i) and leader.LeaderType ~= "LEADER_NONE" then
					b_add = false
				end
			end
		end
		if g_slot_draft == 3 then
			for i = 1, g_all_players do
				if g_cached_playerIDs[i] ~= nil then
					if g_cached_playerIDs[i].HasPicked == true then
						if PlayerConfigurations[g_cached_playerIDs[i].ID] ~= nil then
							if leader.LeaderType == PlayerConfigurations[g_cached_playerIDs[i].ID]:GetLeaderTypeName() and leader.LeaderType ~= "LEADER_NONE" then
								b_add = false
							end
						end
					end
				end
			end		
		end
		if b_add == true then
			local controlTable = {};
			Controls.BanPullDown:BuildEntry( "InstanceOne", controlTable );
			controlTable.Button:SetText( Locale.Lookup(leader.LeaderName) );
			controlTable.LeaderIcon:SetIcon(leader.LeaderIcon)
			controlTable.Button:RegisterCallback(Mouse.eLClick, function() OnSelectBan(num,playerID,leader.LeaderType); end);
		end
	end
	Controls.BanPullDown:CalculateInternals();
	
	if GameConfiguration.GetValue("BAN_"..num) ~= nil then
		for k , v in pairs(m_LeaderBan) do
			if v.LeaderType == GameConfiguration.GetValue("BAN_"..num) then
				local button = Controls.BanPullDown:GetButton()
				button:SetText(Locale.Lookup(v.LeaderName))
				Controls.BanPullDown_Icon:SetIcon(v.LeaderIcon)
			end
		end
	end	
	
		
end

function PopulateMapList(num:number,playerID:number)
	Controls.BanMapPullDown:ClearEntries()
	for k, map in pairs(g_map_pool) do
		local b_add = true
		if map.Allowed == false then
			b_add = false
		end
		if b_add == true then
			local controlTable = {};
			Controls.BanMapPullDown:BuildEntry( "InstanceOne", controlTable );
			controlTable.Button:SetText( map.Map );
			controlTable.Button:RegisterCallback(Mouse.eLClick, function() OnSelectMapBan(num,playerID,map.ID); end);
		end
	end
	Controls.BanMapPullDown:CalculateInternals();	
end

function PopulateMapVotePulldown(playerID:number)
	Controls.VoteMapScriptPullDown:ClearEntries()
	for k, map in pairs(g_map_pool) do
		local b_add = true
		if map.Allowed == false then
			b_add = false
		end
		if b_add == true then
			local controlTable = {};
			Controls.VoteMapScriptPullDown:BuildEntry( "InstanceOne", controlTable );
			controlTable.Button:SetText( map.Map );
			controlTable.Button:RegisterCallback(Mouse.eLClick, function() OnSelectMapScript(playerID,map.ID); end);
		end
	end
	Controls.VoteMapScriptPullDown:CalculateInternals();	
	
	-- Manually Create Age Table
	Controls.VoteMapAgePullDown:ClearEntries()
	local controlTable = {};
	Controls.VoteMapAgePullDown:BuildEntry( "InstanceOne", controlTable );
	controlTable.Button:SetText( Locale.Lookup("LOC_MAP_WORLD_AGE_STANDARD_NAME") );
	controlTable.Button:RegisterCallback(Mouse.eLClick, function() OnSelectMapAge(playerID,2,Locale.Lookup("LOC_MAP_WORLD_AGE_STANDARD_NAME")); end);
	controlTable = {};
	Controls.VoteMapAgePullDown:BuildEntry( "InstanceOne", controlTable );
	controlTable.Button:SetText( Locale.Lookup("LOC_MAP_WORLD_AGE_NEW_NAME") );
	controlTable.Button:RegisterCallback(Mouse.eLClick, function() OnSelectMapAge(playerID,1,Locale.Lookup("LOC_MAP_WORLD_AGE_NEW_NAME")); end);	
	controlTable = {};
	Controls.VoteMapAgePullDown:BuildEntry( "InstanceOne", controlTable );
	controlTable.Button:SetText( Locale.Lookup("LOC_MAP_WORLD_AGE_OLD_NAME") );
	controlTable.Button:RegisterCallback(Mouse.eLClick, function() OnSelectMapAge(playerID,3,Locale.Lookup("LOC_MAP_WORLD_AGE_OLD_NAME")); end);	
	Controls.VoteMapAgePullDown:CalculateInternals();

	-- Manually Create Temperature Table
	Controls.VoteMapTempPullDown:ClearEntries()
	local controlTable = {};
	Controls.VoteMapTempPullDown:BuildEntry( "InstanceOne", controlTable );
	controlTable.Button:SetText( Locale.Lookup("LOC_MAP_TEMPERATURE_STANDARD_NAME") );
	controlTable.Button:RegisterCallback(Mouse.eLClick, function() OnSelectMapTemp(playerID,2,Locale.Lookup("LOC_MAP_TEMPERATURE_STANDARD_NAME")); end);
	controlTable = {};
	Controls.VoteMapTempPullDown:BuildEntry( "InstanceOne", controlTable );
	controlTable.Button:SetText( Locale.Lookup("LOC_MAP_TEMPERATURE_HOT_NAME") );
	controlTable.Button:RegisterCallback(Mouse.eLClick, function() OnSelectMapTemp(playerID,1,Locale.Lookup("LOC_MAP_TEMPERATURE_HOT_NAME")); end);	
	controlTable = {};
	Controls.VoteMapTempPullDown:BuildEntry( "InstanceOne", controlTable );
	controlTable.Button:SetText( Locale.Lookup("LOC_MAP_TEMPERATURE_COLD_NAME") );
	controlTable.Button:RegisterCallback(Mouse.eLClick, function() OnSelectMapTemp(playerID,3,Locale.Lookup("LOC_MAP_TEMPERATURE_COLD_NAME")); end);	
	Controls.VoteMapTempPullDown:CalculateInternals();	
	
end
-- OnPlayerInfoChanged
-------------------------------------------------
function PlayerInfoChanged_SpecificPlayer(playerID)
	-- Targeted update of another player's entry.
	local pPlayerConfig = PlayerConfigurations[playerID];
	if(g_cachedTeams[playerID] ~= pPlayerConfig:GetTeam()) then
		OnTeamChange(playerID, false);
	end

	Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	UpdatePlayerEntry(playerID);
	
	Controls.PlayerListStack:CalculateSize();
	Controls.PlayersScrollPanel:CalculateSize();
end

function OnPlayerInfoChanged(playerID)

	if GameConfiguration.GetValue("GAMEMODE_ANONYMOUS") == true then
		Anonymise_ID(playerID)
	end
	
	if(ContextPtr:IsHidden() == false) then
		-- Ignore PlayerInfoChanged events for non-displayable player slots.
		if(not IsDisplayableSlot(playerID)) then
			return;
		end

		if(playerID == Network.GetLocalPlayerID()) then
			-- If we are the host and our info changed, we need to locally refresh all the player slots.
			-- We do this because the host's ready status disables/enables pulldowns on all the other player slots.
			if(Network.IsGameHost()) then
				UpdateAllPlayerEntries();
				if g_phase == PHASE_INIT or g_phase == PHASE_DEFAULT then
					ResetStatus()
				end
			else
				-- A remote client needs to update the disabled status of all slot type pulldowns if their data was changed.
				-- We do this because readying up disables the slot type pulldown for all players.
				UpdateAllPlayerEntries_SlotTypeDisabled();

				PlayerInfoChanged_SpecificPlayer(playerID);
				
			end
		else
			PlayerInfoChanged_SpecificPlayer(playerID);
		end

		CheckGameAutoStart();	-- Player might have changed their ready status.
		UpdateReadyButton();
		
		-- Update chat target pulldown.
		PlayerTarget_OnPlayerInfoChanged( playerID, Controls.ChatPull, Controls.ChatEntry, Controls.ChatIcon, m_playerTargetEntries, m_playerTarget, false);
	end
end

function OnUploadCloudPlayerConfigComplete(success :boolean)
	if(m_exitReadyWait == true) then
		m_exitReadyWait = false;
		Close();
	end
end

-------------------------------------------------
-- OnTeamChange
-------------------------------------------------
function OnTeamChange( playerID, isBatchCall )
	local pPlayerConfig = PlayerConfigurations[playerID];
	if(pPlayerConfig ~= nil) then
		local teamID = pPlayerConfig:GetTeam();
		local playerEntry = GetPlayerEntry(playerID);
		local updateOpenEmptyTeam = false;

		-- Check for situations where we might need to update the Open Empty Team slot.
		if( (g_cachedTeams[playerID] ~= nil and GameConfiguration.GetTeamPlayerCount(g_cachedTeams[playerID]) <= 0) -- was last player on old team.
			or (GameConfiguration.GetTeamPlayerCount(teamID) <= 1) ) then -- first player on new team.
			-- this player was the last player on that team.  We might need to create a new empty team.
			updateOpenEmptyTeam = true;
		end
		
		if(g_cachedTeams[playerID] ~= nil 
			and g_cachedTeams[playerID] ~= teamID
			-- Remote clients will receive team changes during the PlayByCloud game launch process if they just wait in the staging room.
			-- That should not unready the player which can mess up the autolaunch process.
			and not IsCloudInProgress()) then 
			-- Reset the player's ready status if they actually changed teams.
			SetLocalReady(false);
		end

		-- cache the player's teamID for the next OnTeamChange.
		g_cachedTeams[playerID] = teamID;
		
		if(not isBatchCall) then
			-- There's some stuff that we have to do it to maintain the player list. 
			-- We intentionally wait to do this if we're in the middle of doing a batch of these updates.
			-- If you're doing a batch of these, call UpdateTeamList(true) when you're done.
			UpdateTeamList(updateOpenEmptyTeam);
		end
	end	
end


-------------------------------------------------
-- OnMultiplayerPingTimesChanged
-------------------------------------------------
function OnMultiplayerPingTimesChanged()
	for playerID, playerEntry in pairs( g_PlayerEntries ) do
		UpdateNetConnectionIcon(playerID, playerEntry.ConnectionStatus, playerEntry.StatusLabel);
		UpdateNetConnectionLabel(playerID, playerEntry.StatusLabel);
	end
end

function OnCloudGameKilled( matchID, success )
	if(success) then
		Close();
	else
		--Show error prompt.
		m_kPopupDialog:Close();
		m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_FAIL_TITLE")));
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_FAIL"));
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_FAIL_ACCEPT") );
		m_kPopupDialog:Open();
	end
end

function OnCloudGameQuit( matchID, success )
	if(success) then
		-- On success, close popup and exit the screen
		Close();
	else
		--Show error prompt.
		m_kPopupDialog:Close();
		m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_QUITING_GAME_FAIL_TITLE")));
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_QUITING_GAME_FAIL"));
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_MULTIPLAYER_QUITING_GAME_FAIL_ACCEPT") );
		m_kPopupDialog:Open();
	end
end

-------------------------------------------------
-- Chat
-------------------------------------------------
function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
	-- .mph_ui_modversion_mphcommence_BBS_bbsyes_BBG_bbgpum
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local bversion_display = true
	if g_player_status ~= nil then
		for i, player in ipairs(g_player_status) do 
			if player.ID == localID and player.ID ~= hostID then
				if player.Status == 3 then
					bversion_display = false
				end	
			end
		end
	end

	if localID == hostID then
		bversion_display = true
	end
	if fromPlayer == Network.GetGameHostPlayerID() then
		b_ishost = true
	end
	
	local b_isnext = false
	if fromPlayer == g_next_ID then
		b_isnext = true
	end	
	
	if string.sub(text,1,8) == ".version" then
		g_version_map[fromPlayer] = string.sub(text,10)
		if b_ishost == true then
			g_version_map["HOST"] = string.sub(text,10)
		end
		if g_debug == false then
			return
		end
	end
	
	if string.sub(text,1,18) == ".mph_ui_modversion"  then --and toPlayer == Network.GetGameHostPlayerID()
		local indexBBSs, indexBBSe = string.find(text,"_BBS_")
		local indexBBGs, indexBBGe = string.find(text,"_BBG_")
		local mph_version = string.sub(text,20,indexBBSs-1)
		local bbs_version = string.sub(text,indexBBSe+1,indexBBGs-1)
		local bbg_version = string.sub(text, indexBBGe+1)
		RefreshStatusID(fromPlayer,mph_version,bbs_version,bbg_version)

	end
	
	if string.sub(text,1,30) == "[COLOR_Civ6Green]# Running MPH" and toPlayer == Network.GetGameHostPlayerID() and bversion_display == true then
		local version = tonumber(string.sub(text,31))
		RefreshStatusID(fromPlayer,version)
		if localID ~= hostID then
			return
		end
		if g_phase == PHASE_DEFAULT then
			return
		end
	end
	
	if b_ishost == true and string.sub(text,1,25) == "[COLOR_Civ6Green]# Greeti" then
		if localID == toPlayer then
			SendVersion()
		end
		if localID ~= hostID and localID ~= toPlayer then
			return
		end
		if g_phase == PHASE_DEFAULT then
			return
		end
	end
	
	if b_ishost == true and text == ".broadcast_game" then
		Network.BroadcastGameConfig()
	end
	
	if b_ishost == true and text == ".broadcast_player_0" then
		print("query",PlayerConfigurations[0]:SetValue("NICK_NAME","paf"))
		Network.BroadcastPlayerInfo(0)
	end
	
	if b_ishost == true and text == ".broadcast_player_1" then
		Network.BroadcastPlayerInfo(1)
	end
	
	if b_ishost == true and text == ".launch" then
		HostLaunch()
		if g_debug == false then
			return
		end
	end
	
	
	if b_ishost == true and text == ".next" then
		local tmp = GetNextID()
		if tmp ~= nil then
			text = tostring(tmp)
			g_test = GetNextID()
			else
			text = "nil"
		end
		if g_debug == false then
			return
		end
	end
	
	if b_ishost == true and text == ".spec" then
		PlayerConfigurations[hostID]:SetLeaderTypeName("LEADER_SPECTATOR")
		Network.LaunchGame()
	end
	
	if string.sub(text,1,6) == ".pulse" then
		if g_debug == false then
			return
		end
	end
	
	if b_ishost == true and text == ".forcecheck" then
		if g_debug == false then
			return
		end
	end
	
	if b_ishost == true and string.sub(text,1,7) == ".idnext" then
		local tmp = string.sub(text,9)
		OnReceiveNextID(tonumber(tmp))
		text = "Next ID is: "..tmp
		if g_debug == false then
			return
		end
	end
	
	if string.sub(text,1,8) == ".mapvote" then
		OnReceiveMapVote(text)
		if g_debug == false then
			return
		end
	end
	
	
	if string.sub(text,1,8) == ".banvote" then
		OnReceiveBanVote(text)
		if g_debug == false then
			return
		end
	end
	
	if b_ishost == true and string.sub(text,1,5) == ".slot" then
		if string.sub(text,7) == "0" then
			g_slot_draft = 0
		end
		if string.sub(text,7) == "1" then
			g_slot_draft = 1
		end
		if string.sub(text,7) == "2" then
			g_slot_draft = 2
		end
		if string.sub(text,7) == "3" then
			g_slot_draft = 3
		end
		text = "g_slot_draft is "..tostring(g_slot_draft)
		if g_debug == false then
			return
		end
	end

	if b_ishost == true and string.sub(text,1,6) == ".stat_" then	
		local status = GetStatus_SpecificID(tonumber(string.sub(text,7)))
		text = string.sub(text,7).." - "..status
	end
	
	if b_ishost == true and string.sub(text,1,6) == ".timer" then
		if string.sub(text,8) == "0" then
			g_timer = 0
		end
		if string.sub(text,8) == "1" then
			g_timer = 1
		end
		text = "g_timer is "..tostring(g_timer)
		if g_debug == false then
			return
		end
	end
	
	if b_ishost == true and text == ".skip" then
		HostSkip()
		if g_debug == false then
			return
		end
	end
	
	if b_ishost == true and text == ".modlist" then
		local mods = Modding.GetActiveMods()
		if mods ~= nil then
			print(mods)
			for i,v in ipairs(mods) do
				print(i,v)
				for key,value in ipairs(v) do
					print(key,value)
				end
			end
		end
	end
	

	
	if b_ishost == true and text == ".reset" then
		HostReset()
		if g_debug == false then
			return
		end
	end
	
	if b_ishost == true and text == ".unlock" then
		HostUnlock()
		if g_debug == false then
			return
		end
	end
	
	if b_ishost == true and text == ".debug" then
		g_debug = true
		if g_debug == false then
			return
		end
	end
	
	if b_ishost == true and text == ".tournament" then
		GameConfiguration.SetValue("CPL_BAN_FORMAT",3)
		if g_debug == false then
			return
		end
	end
		
	
	if b_ishost == true and text == ".version" then
		text = g_version
	end
	
	if b_ishost == true and text == ".rand" then
		if g_total_players ~= 0 then
			text = GetRandom(GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED"),g_total_players)
			else
			text = GetRandom(GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED"),10)
		end
	end
	
	if b_ishost == true and text == ".force" then
		HostForceStart()
		return
	end
	
	if b_ishost == true and text == ".phase" then
		text = g_phase
	end

	if (b_ishost == true) and string.sub(text,1,9) == ".chgphase" then
		OnPhaseChanged(text)
		if g_debug == false then
			return
		end
	end

	if (b_isnext == true or b_ishost == true) and string.sub(text,1,4) == ".ban" then
		OnBanReceived(text)
		if g_debug == false then
			return
		end
	end
	
	if (b_isnext == true or b_ishost == true) and string.sub(text,1,7) == ".mapban" then
		OnBanMapReceived(text)
		if g_debug == false then
			return
		end
	end

	if (b_isnext == true or b_ishost == true) and string.sub(text,1,6) == ".valid" then
		OnValidReceived(text)
		if g_debug == false then
			return
		end
	end		

	OnChat(fromPlayer, toPlayer, text, eTargetType, true);
end

function OnChat( fromPlayer, toPlayer, text, eTargetType, playSounds :boolean )
	if string.lower(string.sub(text,1,4)) == ".mph" then
		return
	end

	if(ContextPtr:IsHidden() == false) then
		local pPlayerConfig = PlayerConfigurations[fromPlayer];
		local playerName = Locale.Lookup(pPlayerConfig:GetPlayerName());

		-- Selecting chat text color based on eTargetType	
		local chatColor :string = "[color:ChatMessage_Global]";
		if(eTargetType == ChatTargetTypes.CHATTARGET_TEAM) then
			chatColor = "[color:ChatMessage_Team]";
		elseif(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
			chatColor = "[color:ChatMessage_Whisper]";  
		end
		
		local chatString	= "[color:ChatPlayerName]" .. playerName;

		-- When whispering, include the whisperee's name as well.
		if(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
			local pTargetConfig :table	= PlayerConfigurations[toPlayer];
			if(pTargetConfig ~= nil) then
				local targetName = Locale.Lookup(pTargetConfig:GetPlayerName());
				chatString = chatString .. " [" .. targetName .. "]";
			end
		end

		-- Ensure text parsed properly
		text = ParseChatText(text);

		chatString			= chatString .. ": [ENDCOLOR]" .. chatColor;
		-- Add a space before the [ENDCOLOR] tag to prevent the user from accidentally escaping it																					
		chatString			= chatString .. text .. " [ENDCOLOR]";

		AddChatEntry( chatString, Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);

		if(playSounds and fromPlayer ~= Network.GetLocalPlayerID()) then
			UI.PlaySound("Play_MP_Chat_Message_Received");
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function SendChat( text )
    if( string.len( text ) > 0 ) then
		-- Parse text for possible chat commands
		local parsedText :string;
		local chatTargetChanged :boolean = false;
		local printHelp :boolean = false;
		parsedText, chatTargetChanged, printHelp = ParseInputChatString(text, m_playerTarget);
		if(chatTargetChanged) then
			ValidatePlayerTarget(m_playerTarget);
			UpdatePlayerTargetPulldown(Controls.ChatPull, m_playerTarget);
			UpdatePlayerTargetEditBox(Controls.ChatEntry, m_playerTarget);
			UpdatePlayerTargetIcon(Controls.ChatIcon, m_playerTarget);
		end

		if(printHelp) then
			ChatPrintHelp(Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);
		end

		if(parsedText ~= "") then
			-- m_playerTarget uses PlayerTargetLogic values and needs to be converted  
			local chatTarget :table ={};
			PlayerTargetToChatTarget(m_playerTarget, chatTarget);
			Network.SendChat( parsedText, chatTarget.targetType, chatTarget.targetID );
			UI.PlaySound("Play_MP_Chat_Message_Sent");
		end
    end
    Controls.ChatEntry:ClearString();
end

-------------------------------------------------
-- ParseChatText - ensures icon tags parsed properly
-------------------------------------------------
function ParseChatText(text)
	startIdx, endIdx = string.find(string.upper(text), "%[ICON_");
	if(startIdx == nil) then
		return text;
	else
		for i = endIdx + 1, string.len(text) do
			character = string.sub(text, i, i);
			if(character=="]") then
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text,i + 1));
			elseif(character==" ") then
				text = string.gsub(text, " ", "]", 1);
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text, i + 1));
			elseif (character=="[") then
				return string.sub(text, 1, i - 1) .. "]" .. ParseChatText(string.sub(text, i));
			end
		end
		return text.."]";
	end
	return text;
end

-------------------------------------------------
-------------------------------------------------

function OnMultplayerPlayerConnected( playerID )
	if GameConfiguration.GetValue("GAMEMODE_ANONYMOUS") == true then
		Anonymise_ID(playerID)
	end
	
	RefreshStatusID(playerID)
	g_phase = PHASE_DEFAULT						  
	if( ContextPtr:IsHidden() == false ) then
		if GameConfiguration.GetValue("GAMEMODE_ANONYMOUS") == false then
			OnChat( playerID, -1, PlayerConnectedChatStr, false );
		end
		UI.PlaySound("Play_MP_Player_Connect");
		UpdateFriendsList();

		-- Autoplay Host readies up as soon as the required number of network connections (human or autoplay players) have connected.
		if(Automation.IsActive() and Network.IsGameHost()) then
			local minPlayers = Automation.GetSetParameter("CurrentTest", "MinPlayers", 2);
			local connectedCount = 0;
			if(minPlayers ~= nil) then
				-- Count network connected player slots
				local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
				for i, iPlayer in ipairs(player_ids) do	
					if(Network.IsPlayerConnected(iPlayer)) then
						connectedCount = connectedCount + 1;
					end
				end

				if(connectedCount >= minPlayers) then
					Automation.Log("HostGame MinPlayers met, host readying up.  MinPlayers=" .. tostring(minPlayers) .. " ConnectedPlayers=" .. tostring(connectedCount));
					SetLocalReady(true);
				end
			end
		end
	end
end

-------------------------------------------------
-------------------------------------------------

function OnMultiplayerPrePlayerDisconnected( playerID )
	RefreshStatusID(playerID)
	if g_phase ~= PHASE_DEFAULT and g_phase ~= PHASE_READY then
		HostReset()
	end
	g_phase = PHASE_DEFAULT								  	 
	if( ContextPtr:IsHidden() == false ) then
		local playerCfg = PlayerConfigurations[playerID];
		if(playerCfg:IsHuman()) then
			if(Network.IsPlayerKicked(playerID)) then
				OnChat( playerID, -1, PlayerKickedChatStr, false );
			else
    			OnChat( playerID, -1, PlayerDisconnectedChatStr, false );
			end
			UI.PlaySound("Play_MP_Player_Disconnect");
			UpdateFriendsList();
		end
	end
end

-------------------------------------------------
-------------------------------------------------

function OnModStatusUpdated(playerID: number, modState : number, bytesDownloaded : number, bytesTotal : number,
							modsRemaining : number, modsRequired : number)
	
	if(modState == 1) then -- MOD_STATE_DOWNLOADING
		local modStatusString = downloadPendingStr;
		modStatusString = modStatusString .. "[NEWLINE][Icon_AdditionalContent]" .. tostring(modsRemaining) .. "/" .. tostring(modsRequired);
		g_PlayerModStatus[playerID] = modStatusString;
	else
		g_PlayerModStatus[playerID] = nil;
	end
	UpdatePlayerEntry(playerID);

	--[[ Prototype Mod Status Progress Bars
	local playerEntry = g_PlayerEntries[playerID];
	if(playerEntry ~= nil) then
		if(modState ~= 1) then
			playerEntry.PlayerModProgressStack:SetHide(true);
		else
			-- MOD_STATE_DOWNLOADING
			playerEntry.PlayerModProgressStack:SetHide(false);

			-- Update Progress Bar
			local progress : number = 0;
			if(bytesTotal > 0) then
				progress = bytesDownloaded / bytesTotal;
			end
			playerEntry.ModProgressBar:SetPercent(progress);

			-- Building Bytes Remaining Label
			if(bytesTotal > 0) then
				local bytesRemainingStr : string = "";
				local modSizeStr : string = BytesStr;
				local bytesDownloadedScaled : number = bytesDownloaded;
				local bytesTotalScaled : number = bytesTotal;
				if(bytesTotal > 1000000) then
					-- Megabytes
					modSizeStr = MegabytesStr;
					bytesDownloadedScaled = bytesDownloadedScaled / 1000000;
					bytesTotalScaled = bytesTotalScaled / 1000000;
				elseif(bytesTotal > 1000) then
					-- kilobytes
					modSizeStr = KilobytesStr;
					bytesDownloadedScaled = bytesDownloadedScaled / 1000;
					bytesTotalScaled = bytesTotalScaled / 1000;
				end
				bytesRemainingStr = string.format("%.02f%s/%.02f%s", bytesDownloadedScaled, modSizeStr, bytesTotalScaled, modSizeStr);
				playerEntry.BytesRemaining:SetText(bytesRemainingStr);
				playerEntry.BytesRemaining:SetHide(false);
			else
				playerEntry.BytesRemaining:SetHide(true);
			end

			-- Bulding ModProgressRemaining Label
			local modProgressStr : string = "";
			modProgressStr = modProgressStr .. " " .. tostring(modsRemaining) .. "/" .. tostring(modsRequired);
			playerEntry.ModProgressRemaining:SetText(modProgressStr);
		end
	end
	--]]
end

-------------------------------------------------
-------------------------------------------------

function OnAbandoned(eReason)
	if (not ContextPtr:IsHidden()) then

		-- We need to CheckLeaveGame before triggering the reason popup because the reason popup hides the staging room
		-- and would block the leave game incorrectly.  This fixes TTP 22192.
		CheckLeaveGame();

		if (eReason == KickReason.KICK_HOST) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_KICKED", "LOC_GAME_ABANDONED_KICKED_TITLE" );
		elseif (eReason == KickReason.KICK_NO_HOST) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_HOST_LOSTED", "LOC_GAME_ABANDONED_HOST_LOSTED_TITLE" );
		elseif (eReason == KickReason.KICK_NO_ROOM) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_ROOM_FULL", "LOC_GAME_ABANDONED_ROOM_FULL_TITLE" );
		elseif (eReason == KickReason.KICK_VERSION_MISMATCH) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_VERSION_MISMATCH", "LOC_GAME_ABANDONED_VERSION_MISMATCH_TITLE" );
		elseif (eReason == KickReason.KICK_MOD_ERROR) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_MOD_ERROR", "LOC_GAME_ABANDONED_MOD_ERROR_TITLE" );
		elseif (eReason == KickReason.KICK_MOD_MISSING) then
			local modMissingErrorStr = Modding.GetLastModErrorString();
			LuaEvents.MultiplayerPopup( modMissingErrorStr, "LOC_GAME_ABANDONED_MOD_MISSING_TITLE" );
		elseif (eReason == KickReason.KICK_MATCH_DELETED) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_MATCH_DELETED", "LOC_GAME_ABANDONED_MATCH_DELETED_TITLE" );
		else
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_CONNECTION_LOST", "LOC_GAME_ABANDONED_CONNECTION_LOST_TITLE");
		end
		Close();
	end
end

-------------------------------------------------
-------------------------------------------------

function OnMultiplayerGameLaunchFailed()
	-- Multiplayer game failed for launch for some reason.
	if(not GameConfiguration.IsPlayByCloud()) then
		SetLocalReady(false); -- Unready the local player so they can try it again.
	end

	m_kPopupDialog:Close();	-- clear out the popup incase it is already open.
	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_GAME_LAUNCH_FAILED_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_GAME_LAUNCH_FAILED"));
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_MULTIPLAYER_GAME_LAUNCH_FAILED_ACCEPT"));
	m_kPopupDialog:Open();
end

-------------------------------------------------
-------------------------------------------------

function OnLeaveGameComplete()
	-- We just left the game, we shouldn't be open anymore.
	UIManager:DequeuePopup( ContextPtr );
	g_player_status = {}
	if g_phase ~= PHASE_DEFAULT then
		HostReset()
	end
	g_phase = PHASE_DEFAULT
end

-------------------------------------------------
-------------------------------------------------

function OnBeforeMultiplayerInviteProcessing()
	-- We're about to process a game invite.  Get off the popup stack before we accidently break the invite!
	UIManager:DequeuePopup( ContextPtr );
end


-------------------------------------------------
-------------------------------------------------

function OnMultiplayerHostMigrated( newHostID : number )
	g_player_status = {}
	RefreshStatusID(playerID)
	if g_phase ~= PHASE_DEFAULT then
		HostReset()
	end
	g_phase = PHASE_DEFAULT			  	 
	if(ContextPtr:IsHidden() == false) then
		-- If the local machine has become the host, we need to rebuild the UI so host privileges are displayed.
		local localPlayerID = Network.GetLocalPlayerID();
		if(localPlayerID == newHostID) then
			RealizeGameSetup();
			BuildPlayerList();
		end

		OnChat( newHostID, -1, PlayerHostMigratedChatStr, false );
		UI.PlaySound("Play_MP_Host_Migration");
	end
end

----------------------------------------------------------------
-- Button Handlers
----------------------------------------------------------------

-------------------------------------------------
-- OnSlotType
-------------------------------------------------
function OnSlotType( playerID, id )
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	if g_disabled_slot_settings == true then
		m_kPopupDialog:Close();	
		m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MPH_SLOT_DISABLED_TITLE")));
		if localID == hostID then
			m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MPH_SLOT_HOST_DISABLED_TEXT"));
			else
			m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MPH_SLOT_DISABLED_TEXT"));
		end
		m_kPopupDialog:AddButton( "OK", function() m_kPopupDialog:Close(); end, nil, nil );
		m_kPopupDialog:Open();
		return
	end										   
	--print("playerID: " .. playerID .. " id: " .. id);
	-- NOTE:  This function assumes that the given player slot is not occupied by a player.  We
	--				assume that players having to be kicked before the slot's type can be manually changed.
	local pPlayerConfig = PlayerConfigurations[playerID];
	local pPlayerEntry = g_PlayerEntries[playerID];

	if g_slotTypeData[id].slotStatus == -1 then
		OnSwapButton(playerID);
		return;
	end

	pPlayerConfig:SetSlotStatus(g_slotTypeData[id].slotStatus);

	-- When setting the slot status to a major civ type, some additional data in the player config needs to be set.
	if(g_slotTypeData[id].slotStatus == SlotStatus.SS_TAKEN or g_slotTypeData[id].slotStatus == SlotStatus.SS_COMPUTER) then
		pPlayerConfig:SetMajorCiv();
	end

	Network.BroadcastPlayerInfo(playerID); -- Network the slot status change.

	Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	
	m_iFirstClosedSlot = -1;
	UpdateAllPlayerEntries();

	UpdatePlayerEntry(playerID);

	CheckTeamsValid();
	CheckGameAutoStart();

	if g_slotTypeData[id].slotStatus == SlotStatus.SS_CLOSED then
		Controls.PlayerListStack:CalculateSize();
		Controls.PlayersScrollPanel:CalculateSize();
	end
end

-------------------------------------------------
-- OnSwapButton
-------------------------------------------------
function OnSwapButton(playerID)
	if g_disabled_slot_settings == true then
		m_kPopupDialog:Close();	
		m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MPH_SWAP_DISABLED_TITLE")));
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MPH_SWAP_DISABLED_TEXT"));
		m_kPopupDialog:AddButton( "OK", function() m_kPopupDialog:Close(); end, nil, nil );
		m_kPopupDialog:Open();
		return
	end										 
	-- In this case, playerID is the desired playerID.
	local localPlayerID = Network.GetLocalPlayerID();
	local oldDesiredPlayerID = Network.GetChangePlayerID(localPlayerID);
	local newDesiredPlayerID = playerID;
	if(oldDesiredPlayerID == newDesiredPlayerID) then
		-- player already requested to swap to this player.  Toggle back to no player swap.
		newDesiredPlayerID = NetPlayerTypes.INVALID_PLAYERID;
	end
	Network.RequestPlayerIDChange(newDesiredPlayerID);
	OnPlayerInfoChanged(playerID)
	OnPlayerInfoChanged(newDesiredPlayerID)
	SendVersion()		  
end

-------------------------------------------------
-- OnKickButton
-------------------------------------------------
function OnKickButton(playerID)
	-- Kick button was clicked for the given player slot.
	--print("playerID " .. playerID);
	if g_disabled_slot_settings == true then
		m_kPopupDialog:Close();	
		m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MPH_KICK_DISABLED_TITLE")));
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MPH_KICK_DISABLED_TEXT"));
		m_kPopupDialog:AddButton( "OK", function() m_kPopupDialog:Close(); end, nil, nil );
		m_kPopupDialog:Open();
		return
	end					  
	UIManager:PushModal(Controls.ConfirmKick, true);
	local pPlayerConfig = PlayerConfigurations[playerID];
	if pPlayerConfig:GetSlotStatus() == SlotStatus.SS_COMPUTER then
		LuaEvents.SetKickPlayer(playerID, "LOC_SLOTTYPE_AI");
	else
		local playerName = pPlayerConfig:GetPlayerName();
		LuaEvents.SetKickPlayer(playerID, playerName);
	end
end

-------------------------------------------------
-- OnAddPlayer
-------------------------------------------------
function OnAddPlayer(playerID)
	-- Add Player was clicked for the given player slot.
	-- Set this slot to open	
	if g_disabled_slot_settings == true then
		m_kPopupDialog:Close();	
		m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MPH_ADD_DISABLED_TITLE")));
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MPH_ADD_DISABLED_TEXT"));
		m_kPopupDialog:AddButton( "OK", function() m_kPopupDialog:Close(); end, nil, nil );
		m_kPopupDialog:Open();
		return
	end										 
	
	local pPlayerConfig = PlayerConfigurations[playerID];
	local playerName = pPlayerConfig:GetPlayerName();
	m_iFirstClosedSlot = -1;
	
	pPlayerConfig:SetSlotStatus(SlotStatus.SS_OPEN);
	Network.BroadcastPlayerInfo(playerID); -- Network the slot status change.

	Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	UpdateAllPlayerEntries();

	CheckTeamsValid();
	CheckGameAutoStart();

	Controls.PlayerListStack:CalculateSize();
	Controls.PlayersScrollPanel:CalculateSize();
	Resize();	
end

-------------------------------------------------
-- OnPlayerEntryReady
-------------------------------------------------
function OnPlayerEntryReady(playerID)
	-- Every player entry ready button has this callback, but it only does something if this is for the local player.
	local localPlayerID = Network.GetLocalPlayerID();
	if(playerID == localPlayerID) then
		OnReadyButton();
	end
end

-------------------------------------------------
-- OnJoinTeamButton
-------------------------------------------------
function OnTeamPull( playerID :number, teamID :number)
	local playerConfig = PlayerConfigurations[playerID];

	if(playerConfig ~= nil and teamID ~= playerConfig:GetTeam()) then
		playerConfig:SetTeam(teamID);
		Network.BroadcastPlayerInfo(playerID);
		OnTeamChange(playerID, false);
	end

	UpdatePlayerEntry(playerID);
end

-------------------------------------------------
-- OnInviteButton
-------------------------------------------------
function OnInviteButton()
	local pFriends = Network.GetFriends(Network.GetTransportType());
	if pFriends ~= nil then
		pFriends:ActivateInviteOverlay();
	end
end

-------------------------------------------------
-- OnReadyButton
-------------------------------------------------
function OnReadyButton()
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];
 	-- If we are in Drafting disable
	if g_phase > PHASE_DEFAULT and GameConfiguration.GetGameState() == -901772834 then
		return
	end

	if(not IsCloudInProgress()) then -- PlayByCloud match already in progress, don't touch the local ready state.
		SetLocalReady(not localPlayerConfig:GetReady());
	end
	
	-- Clicking the ready button in some situations instant launches the game.
	if(GameConfiguration.IsHotseat() 
		-- Not our turn in an inprogress PlayByCloud match.  Immediately launch game so player can observe current game state.
		-- NOTE: We can only do this if GAMESTATE_LAUNCHED is set. This indicates that the game host has committed the first turn and
		--		GAMESTATE_LAUNCHED is baked into the save state.
		or (IsCloudInProgressAndNotTurn() and GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_LAUNCHED)) then 
		Network.LaunchGame();
	end
end

-------------------------------------------------
-- OnClickToCopy
-------------------------------------------------
function OnClickToCopy()
	local sText:string = Controls.JoinCodeText:GetText();
	UIManager:SetClipboardString(sText);
end

----------------------------------------------------------------
-- Screen Scripting
----------------------------------------------------------------
function SetLocalReady(newReady)
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];

	-- PlayByCloud Only - Disallow unreadying once the match has started.
	if(IsCloudInProgress() and newReady == false) then
		return;
	end

	-- When using a ready countdown, the player can not unready themselves outside of the ready countdown.
	if(IsUseReadyCountdown() 
		and newReady == false
		and not IsReadyCountdownActive()) then
		return;
	end
	
	if(newReady ~= localPlayerConfig:GetReady()) then
		
		if not GameConfiguration.IsHotseat() then
			Controls.ReadyCheck:SetSelected(newReady);
		end

		-- Show ready-to-go popup when a remote client readies up in a fresh PlayByCloud match.
		if(newReady 
			and GameConfiguration.IsPlayByCloud()
			and GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_LAUNCHED
			and not m_shownPBCReadyPopup
			and not m_exitReadyWait) then -- Do not show ready popup if we are exiting due to pressing the back button.
			ShowPBCReadyPopup();
		end

		localPlayerConfig:SetReady(newReady);
		Network.BroadcastPlayerInfo();
		UpdatePlayerEntry(localPlayerID);
		CheckGameAutoStart();
	end
end

function ShowPBCReadyPopup()
	m_shownPBCReadyPopup = true;
	local readyUpBehavior :number = UserConfiguration.GetPlayByCloudClientReadyBehavior();
	if(readyUpBehavior == PlayByCloudReadyBehaviorType.PBC_READY_ASK_ME) then
		m_kPopupDialog:Close();	-- clear out the popup incase it is already open.
		m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_PLAYBYCLOUD_REMOTE_READY_POPUP_TITLE")));
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_PLAYBYCLOUD_REMOTE_READY_POPUP_TEXT"));
		m_kPopupDialog:AddCheckBox(Locale.Lookup("LOC_REMEMBER_MY_CHOICE"), false, OnPBCReadySaveChoice);
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_PLAYBYCLOUD_REMOTE_READY_POPUP_OK"), OnPBCReadyOK );
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_PLAYBYCLOUD_REMOTE_READY_POPUP_LOBBY_EXIT"), OnPBCReadyExitGame, nil, nil );
		m_kPopupDialog:Open();
	elseif(readyUpBehavior == PlayByCloudReadyBehaviorType.PBC_READY_EXIT_LOBBY) then
		StartExitGame();
	end

	-- Nothing needs to happen for the PlayByCloudReadyBehaviorType.PBC_READY_DO_NOTHING.  Obviously.

end

function OnPBCReadySaveChoice()
	m_savePBCReadyChoice = true;
end

function OnPBCReadyOK()
	-- OK means do nothing and remain in the staging room.
	if(m_savePBCReadyChoice == true) then
		Options.SetUserOption("Interface", "PlayByCloudClientReadyBehavior", PlayByCloudReadyBehaviorType.PBC_READY_DO_NOTHING);
		Options.SaveOptions();
	end	
end

function OnPBCReadyExitGame()
	if(m_savePBCReadyChoice == true) then
		Options.SetUserOption("Interface", "PlayByCloudClientReadyBehavior", PlayByCloudReadyBehaviorType.PBC_READY_EXIT_LOBBY);
		Options.SaveOptions();
	end	

	StartExitGame();
end

-------------------------------------------------
-- Update Teams valid status
-------------------------------------------------
function CheckTeamsValid()
	m_bTeamsValid = false;
	local noTeamPlayers : boolean = false;
	local teamTest : number = TeamTypes.NO_TEAM;
    
	-- Teams are invalid if all players are on the same team.
	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		local curPlayerConfig = PlayerConfigurations[iPlayer];
		if( curPlayerConfig:IsParticipant() 
		and curPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV ) then
			local curTeam : number = curPlayerConfig:GetTeam();
			if(curTeam == TeamTypes.NO_TEAM) then
				-- If someone doesn't have a team, it means that teams are valid.
				m_bTeamsValid = true;
				return;
			elseif(teamTest == TeamTypes.NO_TEAM) then
				teamTest = curTeam;
			elseif(teamTest ~= curTeam) then
				-- people are on different teams.  Teams are valid.
				m_bTeamsValid = true;
				return;
			end
		end
	end
end

-------------------------------------------------
-- CHECK FOR GAME AUTO START
-------------------------------------------------
function CheckGameAutoStart()
	
	-- PlayByCloud Only - Autostart if we are the active turn player.
	if IsCloudInProgress() and Network.IsCloudTurnPlayer() then
		if(not IsLaunchCountdownActive()) then
			-- Reset global blocking variables so the ready button is not dirty from previous sessions.
			ResetAutoStartFlags();				
			SetLocalReady(true);
			StartLaunchCountdown();
		end
	-- Check to see if we should start/stop the multiplayer game.
	
	elseif(not Network.IsPlayerHotJoining(Network.GetLocalPlayerID())
		
		and not IsCloudInProgressAndNotTurn()
		and not Network.IsCloudLaunching()) then -- We should not autostart if we are already launching into a PlayByCloud match.
		local startCountdown = true;
				
		-- Reset global blocking variables because we're going to recalculate them.
		ResetAutoStartFlags();

		-- Count players and check to see if a human player isn't ready.
		local totalPlayers = 0;
		local totalHumans = 0;
		local noDupLeaders = GameConfiguration.GetValue("NO_DUPLICATE_LEADERS");
		local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();		
		
		for i, iPlayer in ipairs(player_ids) do	
			local curPlayerConfig = PlayerConfigurations[iPlayer];
			local curSlotStatus = curPlayerConfig:GetSlotStatus();
			local curIsFullCiv = curPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
			
			if((curSlotStatus == SlotStatus.SS_TAKEN -- Human civ
				or Network.IsPlayerConnected(iPlayer))	-- network connection on this slot, could be an multiplayer autoplay.
				and (curPlayerConfig:IsAlive() or curSlotStatus == SlotStatus.SS_OBSERVER)) then -- Dead players do not block launch countdown.  Observers count as dead but should still block launch to be consistent. 
				if(not curPlayerConfig:GetReady()) then
					print("CheckGameAutoStart: Can't start game because player ".. iPlayer .. " isn't ready");
					startCountdown = false;
					g_everyoneReady = false;
				-- Players are set to ModRrady when have they successfully downloaded and configured all the mods required for this game.
				-- See Network::Manager::OnFinishedGameplayContentConfigure()
				elseif(not curPlayerConfig:GetModReady()) then
					print("CheckGameAutoStart: Can't start game because player ".. iPlayer .. " isn't mod ready");
					startCountdown = false;
					g_everyoneModReady = false;
				end
			
			elseif(curPlayerConfig:IsHumanRequired() == true 
				and GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_PREGAME) then
				-- If this is a new game, all human required slots need to be filled by a human.  
				-- NOTE: Human required slots do not need to be filled when loading a save.
				startCountdown = false;
				g_humanRequiredFilled = false;
			end
			
			if( (curSlotStatus == SlotStatus.SS_COMPUTER or curSlotStatus == SlotStatus.SS_TAKEN) and curIsFullCiv ) then
				totalPlayers = totalPlayers + 1;
				
				if(curSlotStatus == SlotStatus.SS_TAKEN) then
					totalHumans = totalHumans + 1;
				end

				if(iPlayer >= g_currentMaxPlayers) then
					-- A player is occupying an invalid player slot for this map size.
					print("CheckGameAutoStart: Can't start game because player " .. iPlayer .. " is in an invalid slot for this map size.");
					startCountdown = false;
					g_badPlayerForMapSize = true;
				end

				-- Check for selection error (ownership rules, duplicate leaders, etc)
				local err = GetPlayerParameterError(iPlayer)
				if(err) then
					
					startCountdown = false;
					if(noDupLeaders and err.Id == "InvalidDomainValue" and err.Reason == "LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS") then
						g_duplicateLeaders = true;
					end
				end
			end
		end
		
		-- Check player count
		if(totalPlayers < g_currentMinPlayers) then
			print("CheckGameAutoStart: Can't start game because there are not enough players. " .. totalPlayers .. "/" .. g_currentMinPlayers);
			startCountdown = false;
			g_notEnoughPlayers = true;
		end

		if(GameConfiguration.IsPlayByCloud() 
			and GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_LAUNCHED
			and totalHumans < 2) then
			print("CheckGameAutoStart: Can't start game because two human players are required for PlayByCloud. totalHumans: " .. totalHumans);
			startCountdown = false;
			g_pbcMinHumanCheck = false;
		end

		if(GameConfiguration.IsMatchMaking()
			and GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_LAUNCHED
			and totalHumans < totalPlayers
			and (IsReadyCountdownActive() or IsWaitForPlayersCountdownActive())) then
			print("CheckGameAutoStart: Can't start game because we are still in the Ready/Matchmaking Countdown and we do not have a full game yet. totalHumans: " .. totalHumans .. ", totalPlayers: " .. tostring(totalPlayers));
			startCountdown = false;
			g_matchMakeFullGameCheck = false;
		end

		if(not Network.IsEveryoneConnected()) then
			print("CheckGameAutoStart: Can't start game because players are joining the game.");
			startCountdown = false;
			g_everyoneConnected = false;
		end

		if(not m_bTeamsValid) then
			print("CheckGameAutoStart: Can't start game because all civs are on the same team!");
			startCountdown = false;
		end

		-- Only the host may launch a PlayByCloud match that is not already in progress.
		if(GameConfiguration.IsPlayByCloud()
			and GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_LAUNCHED
			and not Network.IsGameHost()) then
			print("CheckGameAutoStart: Can't start game because remote client can't launch new PlayByCloud game.");
			startCountdown = false;
			g_pbcNewGameCheck = false;
		end

	
		-- Hotseat bypasses the countdown system.
		if not GameConfiguration.IsHotseat() then
			if(startCountdown) then
				-- Everyone has readied up and we can start.
				StartLaunchCountdown();
			else
				-- We can't autostart now, stop the countdown if we started it earlier.
				if(IsLaunchCountdownActive()) then
					StopCountdown();
				end
			end
		end
	end
	UpdateReadyButton();
end

function ResetAutoStartFlags()
	g_everyoneReady = true;
	g_everyoneConnected = true;
	g_badPlayerForMapSize = false;
	g_notEnoughPlayers = false;
	g_everyoneModReady = true;
	g_duplicateLeaders = false;
	g_humanRequiredFilled = true;
	g_pbcNewGameCheck = true;
	g_pbcMinHumanCheck = true;
	g_matchMakeFullGameCheck = true;
end

-------------------------------------------------
-- Leave the Game
-------------------------------------------------
function CheckLeaveGame()
	-- Leave the network session if we're in a state where the staging room should be triggering the exit.
	if not ContextPtr:IsHidden()	-- If the screen is not visible, this exit might be part of a general UI state change (like Multiplayer_ExitShell)
									-- and should not trigger a game exit.
		and Network.IsInSession()	-- Still in a network session.
		and not Network.IsInGameStartedState() then -- Don't trigger leave game if we're being used as an ingame screen. Worldview is handling this instead.
		print("StagingRoom::CheckLeaveGame() leaving the network session.");															  
		Network.LeaveGame();
	end
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnHandleExitRequest()
	print("Staging Room -Handle Exit Request");

	CheckLeaveGame();
	Controls.CountdownTimerAnim:ClearAnimCallback();
	
	-- Force close all popups because they are modal and will remain visible even if the screen is hidden
	for _, playerEntry:table in ipairs(g_PlayerEntries) do
		playerEntry.SlotTypePulldown:ForceClose();
		playerEntry.AlternateSlotTypePulldown:ForceClose();
		playerEntry.TeamPullDown:ForceClose();
		playerEntry.PlayerPullDown:ForceClose();
		playerEntry.HandicapPullDown:ForceClose();
	end

	-- Destroy setup parameters.
	HideGameSetup(function()
		-- Reset instances here.
		m_gameSetupParameterIM:ResetInstances();
	end);
	
	-- Destroy individual player parameters.
	ReleasePlayerParameters();

	-- Exit directly to Lobby
	ResetChat();
	UIManager:DequeuePopup( ContextPtr );
end

function GetPlayerEntry(playerID)
	local playerEntry = g_PlayerEntries[playerID];
	if(playerEntry == nil) then
		-- need to create the player entry.
		--print("creating playerEntry for player " .. tostring(playerID));
		playerEntry = m_playersIM:GetInstance();

		--SetupTeamPulldown( playerID, playerEntry.TeamPullDown );

		local civTooltipData : table = {
			InfoStack			= m_CivTooltip.InfoStack,
			InfoScrollPanel		= m_CivTooltip.InfoScrollPanel;
			CivToolTipSlide		= m_CivTooltip.CivToolTipSlide;
			CivToolTipAlpha		= m_CivTooltip.CivToolTipAlpha;
			UniqueIconIM		= m_CivTooltip.UniqueIconIM;		
			HeaderIconIM		= m_CivTooltip.HeaderIconIM;
			CivHeaderIconIM		= m_CivTooltip.CivHeaderIconIM;
			HeaderIM			= m_CivTooltip.HeaderIM;
			HasLeaderPlacard	= false;
		};

		SetupSplitLeaderPulldown(playerID, playerEntry,"PlayerPullDown",nil,nil,civTooltipData);
		SetupTeamPulldown(playerID, playerEntry.TeamPullDown);
		SetupHandicapPulldown(playerID, playerEntry.HandicapPullDown);

		--playerEntry.PlayerCard:RegisterCallback( Mouse.eLClick, OnSwapButton );
		--playerEntry.PlayerCard:SetVoid1(playerID);
		playerEntry.KickButton:RegisterCallback( Mouse.eLClick, OnKickButton );
		playerEntry.KickButton:SetVoid1(playerID);
		playerEntry.AddPlayerButton:RegisterCallback( Mouse.eLClick, OnAddPlayer );
		playerEntry.AddPlayerButton:SetVoid1(playerID);
		--[[ Prototype Mod Status Progress Bars
		playerEntry.PlayerModProgressStack:SetHide(true);
		--]]
		playerEntry.ReadyImage:RegisterCallback( Mouse.eLClick, OnPlayerEntryReady );
		playerEntry.ReadyImage:SetVoid1(playerID);

		g_PlayerEntries[playerID] = playerEntry;
		g_PlayerRootToPlayerID[tostring(playerEntry.Root)] = playerID;

		-- Remember starting ready status.
		local pPlayerConfig = PlayerConfigurations[playerID];
		if pPlayerConfig ~= nil then
			g_PlayerReady[playerID] = pPlayerConfig:GetReady();
			UpdatePlayerEntry(playerID);
		end

		Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	end

	return playerEntry;
end

-------------------------------------------------
-- PopulateSlotTypePulldown
-------------------------------------------------
function PopulateSlotTypePulldown( pullDown, playerID, slotTypeOptions )
	
	local instanceManager = pullDown["InstanceManager"];
	if not instanceManager then
		instanceManager = PullDownInstanceManager:new("InstanceOne", "Button", pullDown);
		pullDown["InstanceManager"] = instanceManager;
	end
	
	
	instanceManager:ResetInstances();
	pullDown.ItemCount = 0;

	for i, pair in ipairs(slotTypeOptions) do

		local pPlayerConfig = PlayerConfigurations[playerID];
		local playerSlotStatus = pPlayerConfig:GetSlotStatus();

		-- This option is a valid swap player option.
		local showSwapButton = pair.slotStatus == -1 
			and playerSlotStatus ~= SlotStatus.SS_CLOSED -- Can't swap to closed slots.
			and not pPlayerConfig:IsLocked() -- Can't swap to locked slots.
			and not GameConfiguration.IsHotseat() -- no swap option in hotseat.
			and not GameConfiguration.IsPlayByCloud() -- no swap option in PlayByCloud.
			and not GameConfiguration.IsMatchMaking() -- or when matchmaking
			and playerID ~= Network.GetLocalPlayerID();

		-- This option is a valid slot type option.
		local showSlotButton = CheckShowSlotButton(pair, playerID);
																		
																								
																																
																															   
																																					 
																					   
																						  
																									   
																																					  
																						 
																														 
																			 
																  

		-- Valid state for hotseatOnly flag
		local hotseatOnlyCheck = (GameConfiguration.IsHotseat() and pair.hotseatAllowed) or (not GameConfiguration.IsHotseat() and not pair.hotseatOnly);

		if(	hotseatOnlyCheck 

			and (showSwapButton or showSlotButton)) then

			pullDown.ItemCount = pullDown.ItemCount + 1;
			local instance = instanceManager:GetInstance();
			local slotDisplayName = pair.name;
			local slotToolTip = pair.tooltip;

			-- In PlayByCloud OPEN slots are autoflagged as HumanRequired., morph the display name and tooltip.
			if(GameConfiguration.IsPlayByCloud() and pair.slotStatus == SlotStatus.SS_OPEN) then
				slotDisplayName = "LOC_SLOTTYPE_HUMANREQ";
				slotToolTip = "LOC_SLOTTYPE_HUMANREQ_TT";
			end

			instance.Button:LocalizeAndSetText( slotDisplayName );

			if pair.slotStatus == -1 then
				local isHuman = (playerSlotStatus == SlotStatus.SS_TAKEN);
				instance.Button:LocalizeAndSetToolTip(isHuman and "TXT_KEY_MP_SWAP_WITH_PLAYER_BUTTON_TT" or "TXT_KEY_MP_SWAP_BUTTON_TT");
			else
				instance.Button:LocalizeAndSetToolTip( slotToolTip );
			end
			instance.Button:SetVoids( playerID, i );	
		end
	end

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback(OnSlotType);
	pullDown:SetDisabled(pullDown.ItemCount < 1);
end

function CheckShowSlotButton(slotData :table, playerID: number)
	local pPlayerConfig :object = PlayerConfigurations[playerID];
	local playerSlotStatus :number = pPlayerConfig:GetSlotStatus();

	if(slotData.slotStatus == -1) then
		return false;
	end

	
	-- Special conditions for changing slot types for human slots in network games.
	if(playerSlotStatus == SlotStatus.SS_TAKEN and not GameConfiguration.IsHotseat()) then
		-- You can't change human player slots outside of hotseat mode.
		return false;
	end

	-- You can't switch a civilization to open/closed if the game is at the minimum player count.
	if(slotData.slotStatus == SlotStatus.SS_CLOSED or slotData.slotStatus == SlotStatus.SS_OPEN) then
		if(playerSlotStatus == SlotStatus.SS_TAKEN or playerSlotStatus == SlotStatus.SS_COMPUTER) then -- Current SlotType is a civ
			-- In PlayByCloud OPEN slots are autoflagged as HumanRequired.
			-- We allow them to bypass the minimum player count because 
			-- a human player must occupy the slot for the game to launch. 
			if(not GameConfiguration.IsPlayByCloud() or slotData.slotStatus ~= SlotStatus.SS_OPEN) then
				if(GameConfiguration.GetParticipatingPlayerCount() <= g_currentMinPlayers)	 then
					return false;				
				end
			end
		end
	end

	-- Can't change the slot type of locked player slots.
	if(pPlayerConfig:IsLocked()) then
		return false;
	end

	-- Can't change slot type in matchmaded games. 
	if(GameConfiguration.IsMatchMaking()) then
		return false;
	end

	-- Only the host can change non-local slots.
	if(not Network.IsGameHost() and playerID ~= Network.GetLocalPlayerID()) then
		return false;
	end

	-- Can normally only change slot types before the game has started unless this is a option that can be changed mid-game in hotseat.
	if(GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME) then
		if(not slotData.hotseatInProgress or not GameConfiguration.IsHotseat()) then
			return false;
		end
	end

	return true;
end
-------------------------------------------------
-- Team Scripting
-------------------------------------------------
function GetTeamCounts( teamCountTable :table )
	for playerID, teamID in pairs(g_cachedTeams) do
		if(teamCountTable[teamID] == nil) then
			teamCountTable[teamID] = 1;
		else
			teamCountTable[teamID] = teamCountTable[teamID] + 1;
		end
	end
end

function AddTeamPulldownEntry( playerID:number, pullDown:table, instanceManager:table, teamID:number, teamName:string )
	
	local instance = instanceManager:GetInstance();
	
	if teamID >= 0 then
		local teamIconName:string = TEAM_ICON_PREFIX .. tostring(teamID);
		instance.ButtonImage:SetSizeVal(TEAM_ICON_SIZE, TEAM_ICON_SIZE);
		instance.ButtonImage:SetIcon(teamIconName, TEAM_ICON_SIZE);
		instance.ButtonImage:SetColor(GetTeamColor(teamID));
	end

	instance.Button:SetVoids( playerID, teamID );
end

function SetupTeamPulldown( playerID:number, pullDown:table )

	local instanceManager = pullDown["InstanceManager"];
	if not instanceManager then
		instanceManager = PullDownInstanceManager:new("InstanceOne", "Button", pullDown);
		pullDown["InstanceManager"] = instanceManager;
	end
	instanceManager:ResetInstances();

	local teamCounts = {};
	GetTeamCounts(teamCounts);

	local pulldownEntries = {};
	local noTeams = GameConfiguration.GetValue("NO_TEAMS");

	-- Always add "None" entry
	local newPulldownEntry:table = {};
	newPulldownEntry.teamID = -1;
	newPulldownEntry.teamName = GameConfiguration.GetTeamName(-1);
	table.insert(pulldownEntries, newPulldownEntry);

	if(not noTeams) then
		for teamID, playerCount in pairs(teamCounts) do
			if teamID ~= -1 then
				newPulldownEntry = {};
				newPulldownEntry.teamID = teamID;
				newPulldownEntry.teamName = GameConfiguration.GetTeamName(teamID);
				table.insert(pulldownEntries, newPulldownEntry);
			end
		end

		-- Add an empty team slot so players can join/create a new team
		local newTeamID :number = 0;
		while(teamCounts[newTeamID] ~= nil) do
			newTeamID = newTeamID + 1;
		end
		local newTeamName : string = tostring(newTeamID);
		newPulldownEntry = {};
		newPulldownEntry.teamID = newTeamID;
		newPulldownEntry.teamName = newTeamName;
		table.insert(pulldownEntries, newPulldownEntry);
	end

	table.sort(pulldownEntries, function(a, b) return a.teamID < b.teamID; end);

	for pullID, curPulldownEntry in ipairs(pulldownEntries) do
		AddTeamPulldownEntry(playerID, pullDown, instanceManager, curPulldownEntry.teamID, curPulldownEntry.teamName);
	end

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback( OnTeamPull );
end

function RebuildTeamPulldowns()
	for playerID, playerEntry in pairs( g_PlayerEntries ) do
		SetupTeamPulldown(playerID, playerEntry.TeamPullDown);
	end
end

function UpdateTeamList(updateOpenEmptyTeam)
	if(updateOpenEmptyTeam) then
		-- Regenerate the team pulldowns to show at least one empty team option so players can create new teams.
		RebuildTeamPulldowns();
	end

	CheckTeamsValid(); -- Check to see if the teams are valid for game start.
	CheckGameAutoStart();

	
	
	Controls.PlayerListStack:CalculateSize();
	Controls.PlayersScrollPanel:CalculateSize();
	Controls.HotseatDeco:SetHide(not GameConfiguration.IsHotseat());
end

-------------------------------------------------
-- UpdatePlayerEntry
-------------------------------------------------
function UpdateAllPlayerEntries()
	for playerID, playerEntry in pairs( g_PlayerEntries ) do
		 UpdatePlayerEntry(playerID);
	end
end

-- Update the disabled state of the slot type pulldown for all players.
function UpdateAllPlayerEntries_SlotTypeDisabled()
	for playerID, playerEntry in pairs( g_PlayerEntries ) do
		 UpdatePlayerEntry_SlotTypeDisabled(playerID);
	end
end

-- Update the disabled state of the slot type pulldown for this player.
function UpdatePlayerEntry_SlotTypeDisabled(playerID)
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];
	local playerEntry = g_PlayerEntries[playerID];
	if(playerEntry ~= nil) then

		-- Disable the pulldown if there are no items in it.
		local itemCount = playerEntry.SlotTypePulldown.ItemCount or 0;

		-- The slot type pulldown handles user access permissions internally (See PopulateSlotTypePulldown()).  
		-- However, we need to disable the pulldown entirely if the local player has readied up.
		local bCanChangeSlotType:boolean = not localPlayerConfig:GetReady() 
											and playerID ~= Network.GetLocalPlayerID()
											and itemCount > 0; -- No available slot type options.

		playerEntry.AlternateSlotTypePulldown:SetDisabled(not bCanChangeSlotType);
		playerEntry.SlotTypePulldown:SetDisabled(not bCanChangeSlotType);
	end
end

function UpdatePlayerEntry(playerID)
	local playerEntry = g_PlayerEntries[playerID];
	local hostID = Network.GetGameHostPlayerID()
	if(playerEntry ~= nil) then
		local localPlayerID = Network.GetLocalPlayerID();
		local localPlayerConfig = PlayerConfigurations[localPlayerID];
		local pPlayerConfig = PlayerConfigurations[playerID];
		local slotStatus = pPlayerConfig:GetSlotStatus();
		local isMinorCiv = pPlayerConfig:GetCivilizationLevelTypeID() ~= CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
		local isAlive = pPlayerConfig:IsAlive();
		local isActiveSlot = not isMinorCiv 
			and (slotStatus ~= SlotStatus.SS_CLOSED) 
			and (slotStatus ~= SlotStatus.SS_OPEN) 
			and (slotStatus ~= SlotStatus.SS_OBSERVER)											 
			-- In PlayByCloud, the local player still gets an active slot even if they are dead.  We do this so that players
			--		can rejoin the match to see the end game screen,
			and (isAlive or (GameConfiguration.IsPlayByCloud() and playerID == localPlayerID));
		local isHotSeat:boolean = GameConfiguration.IsHotseat();
		
		-- Has this game aleady been started?  Hot joining or loading a save game.
		local gameInProgress:boolean = GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME;

		-- NOTE: UpdatePlayerEntry() currently only has control over the team player attribute.  Everything else is controlled by 
		--		PlayerConfigurationValuesToUI() and the PlayerSetupLogic.  See CheckExternalEnabled().
		-- Can the local player change this slot's attributes (handicap; civ, etc) at this time?
		local bCanChangePlayerValues = not pPlayerConfig:GetReady()  -- Can't change a slot once that player is ready.
										and not gameInProgress -- Can't change player values once the game has been started.
										and not pPlayerConfig:IsLocked() -- Can't change the values of locked players.
										and (playerID == localPlayerID		-- You can change yourself.
											-- Game host can alter all the non-human slots if they are not ready.
											or (slotStatus ~= SlotStatus.SS_TAKEN and Network.IsGameHost() and not localPlayerConfig:GetReady())
											-- The player has permission to change everything in hotseat.
											or isHotSeat);
		

			
		local isKickable:boolean = Network.IsGameHost()			-- Only the game host may kick
			and (slotStatus == SlotStatus.SS_TAKEN or slotStatus == SlotStatus.SS_OBSERVER)
			and playerID ~= localPlayerID			-- Can't kick yourself
			and not isHotSeat;	-- Can't kick in hotseat, players use the slot type pulldowns instead.

		-- Show player card for human players only during online matches
		local hidePlayerCard:boolean = isHotSeat or slotStatus ~= SlotStatus.SS_TAKEN;
		local showHotseatEdit:boolean = isHotSeat and slotStatus == SlotStatus.SS_TAKEN;
		playerEntry.SlotTypePulldown:SetHide(hidePlayerCard);
		playerEntry.HotseatEditButton:SetHide(not showHotseatEdit);
		playerEntry.AlternateEditButton:SetHide(not hidePlayerCard);
		playerEntry.AlternateSlotTypePulldown:SetHide(not hidePlayerCard);

		if hostID == localPlayerID then
			playerEntry.PlayerVersion:SetHide(false)
			if g_player_status ~= nil and g_player_status ~= {} then
				for i, player in pairs(g_player_status) do
					if player.ID == playerID then
						if player.Status == 0 or player.Status == 1 or player.Status == 2 or player.Status == 99 then
							if player.Status == 99 then
								playerEntry.PlayerVersion:SetText("[COLOR_GREEN]OK[ENDCOLOR]")	
								else
								playerEntry.PlayerVersion:SetText("[COLOR_LIGHTBLUE]Request...[ENDCOLOR]")
							end
							elseif player.Status == 66 then
							playerEntry.PlayerVersion:SetText("[COLOR_RED]Error[ENDCOLOR]")
							elseif player.Status == 3 then
							playerEntry.PlayerVersion:SetText("[COLOR_GREEN]OK[ENDCOLOR]")							
						end
					end
				end	
				else
				playerEntry.PlayerVersion:SetHide(false)
				playerEntry.PlayerVersion:SetText("[COLOR_LIGHTBLUE]Run Check[ENDCOLOR]")
			end
			else
			playerEntry.PlayerVersion:SetHide(true)
		end

		local statusText:string = "";
		if slotStatus == SlotStatus.SS_TAKEN then
			local hostID:number = Network.GetGameHostPlayerID();
			statusText = Locale.Lookup(playerID == hostID and "LOC_SLOTLABEL_HOST" or "LOC_SLOTLABEL_PLAYER");
		elseif slotStatus == SlotStatus.SS_COMPUTER then
			statusText = Locale.Lookup("LOC_SLOTLABEL_COMPUTER");
		elseif slotStatus == SlotStatus.SS_OBSERVER then
			local hostID:number = Network.GetGameHostPlayerID();
			statusText = Locale.Lookup(playerID == hostID and "LOC_SLOTLABEL_OBSERVER_HOST" or "LOC_SLOTLABEL_OBSERVER");
		end
		
		playerEntry.PlayerStatus:SetText(statusText);
		playerEntry.AlternateStatus:SetText(statusText);

		-- Update cached ready status and play sound if player is newly ready.
		if slotStatus == SlotStatus.SS_TAKEN or slotStatus == SlotStatus.SS_OBSERVER then
			local isReady:boolean = pPlayerConfig:GetReady();
			if(isReady ~= g_PlayerReady[playerID]) then
				g_PlayerReady[playerID] = isReady;
				if(isReady == true) then
					UI.PlaySound("Play_MP_Player_Ready");
				end
			end
		end

		-- Update ready icon
		local showStatusLabel = not isHotSeat and slotStatus ~= SlotStatus.SS_OPEN;
		if not isHotSeat then
			if g_PlayerReady[playerID] or slotStatus == SlotStatus.SS_COMPUTER then
				playerEntry.ReadyImage:SetTextureOffsetVal(0,136);
			else
				playerEntry.ReadyImage:SetTextureOffsetVal(0,0);
			end

			-- Update status string
			local statusString = NotReadyStatusStr;
			local statusTTString = "";
			if(slotStatus == SlotStatus.SS_TAKEN 
				and not pPlayerConfig:GetModReady() 
				and g_PlayerModStatus[playerID] ~= nil 
				and g_PlayerModStatus[playerID] ~= "") then
				statusString = g_PlayerModStatus[playerID];
			elseif(playerID >= g_currentMaxPlayers) then
				-- Player is invalid slot for this map size.
				statusString = BadMapSizeSlotStatusStr;
				statusTTString = BadMapSizeSlotStatusStrTT;
			elseif(curSlotStatus == SlotStatus.SS_OPEN
				and pPlayerConfig:IsHumanRequired() == true 
				and GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_PREGAME) then
				-- Empty human required slot
				statusString = EmptyHumanRequiredSlotStatusStr;
				statusTTString = EmptyHumanRequiredSlotStatusStrTT;
				showStatusLabel = true;
			elseif(g_PlayerReady[playerID] or slotStatus == SlotStatus.SS_COMPUTER) then
				statusString = ReadyStatusStr;
			end

			-- Check to see if we should warning that this player is above MAX_SUPPORTED_PLAYERS.
			local playersBeforeUs = 0;
			for iLoopPlayer = 0, playerID-1, 1 do	
				local loopPlayerConfig = PlayerConfigurations[iLoopPlayer];
				local loopSlotStatus = loopPlayerConfig:GetSlotStatus();
				local loopIsFullCiv = loopPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
				if( (loopSlotStatus == SlotStatus.SS_COMPUTER or loopSlotStatus == SlotStatus.SS_TAKEN) and loopIsFullCiv ) then
					playersBeforeUs = playersBeforeUs + 1;
				end
			end
			if playersBeforeUs >= MAX_SUPPORTED_PLAYERS then
				statusString = statusString .. "[NEWLINE][COLOR_Red]" .. UnsupportedText;
				if statusTTString ~= "" then
					statusTTString = statusTTString .. "[NEWLINE][COLOR_Red]" .. UnsupportedTextTT;
				else
					statusTTString = "[COLOR_Red]" .. UnsupportedTextTT;
				end
			end

			local err = GetPlayerParameterError(playerID)
			if(err) then
				local reason = err.Reason or "LOC_SETUP_PLAYER_PARAMETER_ERROR";
				statusString = statusString .. "[NEWLINE][COLOR_Red]" .. Locale.Lookup(reason) .. "[ENDCOLOR]";
			end

			playerEntry.StatusLabel:SetText(statusString);
			playerEntry.StatusLabel:SetToolTipString(statusTTString);
		end
		playerEntry.StatusLabel:SetHide(not showStatusLabel);

		if playerID == localPlayerID then
			playerEntry.YouIndicatorLine:SetHide(false);
		else
			playerEntry.YouIndicatorLine:SetHide(true);
		end

		playerEntry.AddPlayerButton:SetHide(true);
		-- Available actions vary if the slot has an active player in it
		if(isActiveSlot) then
			playerEntry.Root:SetHide(false);
			playerEntry.PlayerPullDown:SetHide(false);
			playerEntry.ReadyImage:SetHide(isHotSeat);
			playerEntry.TeamPullDown:SetHide(false);
			playerEntry.HandicapPullDown:SetHide(false);
			playerEntry.KickButton:SetHide(not isKickable);
		else
			if(playerID >= g_currentMaxPlayers) then
				-- inactive slot is invalid for the current map size, hide it.
				playerEntry.Root:SetHide(true);
			elseif slotStatus == SlotStatus.SS_CLOSED then
				
				if (m_iFirstClosedSlot == -1 or m_iFirstClosedSlot == playerID) 
				and Network.IsGameHost() 
				and not localPlayerConfig:GetReady()			-- Hide when the host is ready (to be consistent with the player slot behavior)
				and not gameInProgress 
				and not IsLaunchCountdownActive()				-- Don't show Add Player button while in the launch countdown.
				and not GameConfiguration.IsMatchMaking() then	-- Players can't change number of slots when matchmaking.
					m_iFirstClosedSlot = playerID;
					playerEntry.AddPlayerButton:SetHide(false);
					playerEntry.Root:SetHide(false);
				else
					playerEntry.Root:SetHide(true);
				end
			elseif slotStatus == SlotStatus.SS_OBSERVER and Network.IsPlayerConnected(playerID) then
				playerEntry.Root:SetHide(false);
				playerEntry.PlayerPullDown:SetHide(true);
				playerEntry.TeamPullDown:SetHide(true);
				playerEntry.ReadyImage:SetHide(false);
				playerEntry.HandicapPullDown:SetHide(true);
				playerEntry.KickButton:SetHide(not isKickable);																						   												   
			else 
				if(gameInProgress
					-- Explicitedly always hide city states.  
					-- In PlayByCloud, the host uploads the player configuration data for city states after the gamecore resolution for new games,
					-- but this happens prior to setting the gamestate to launched in the save file during the first end turn commit.
					or (slotStatus == SlotStatus.SS_COMPUTER and isMinorCiv)) then
					-- Hide inactive slots for games in progress
					playerEntry.Root:SetHide(true);
				else
					-- Inactive slots are visible in the pregame.
					playerEntry.Root:SetHide(false);
					playerEntry.PlayerPullDown:SetHide(true);
					playerEntry.TeamPullDown:SetHide(true);
					playerEntry.ReadyImage:SetHide(true);
					playerEntry.HandicapPullDown:SetHide(true);
					playerEntry.KickButton:SetHide(true);
				end
			end
		end

		--[[ Prototype Mod Status Progress Bars
		-- Hide the player's mod progress if they are mod ready.
		-- This is how the mod progress is hidden once mod downloads are completed.
		if(pPlayerConfig:GetModReady()) then
			playerEntry.PlayerModProgressStack:SetHide(true);
		end
		--]]

		PopulateSlotTypePulldown( playerEntry.AlternateSlotTypePulldown, playerID, g_slotTypeData );
		PopulateSlotTypePulldown(playerEntry.SlotTypePulldown, playerID, g_slotTypeData);
		UpdatePlayerEntry_SlotTypeDisabled(playerID);

		if(isActiveSlot) then
			PlayerConfigurationValuesToUI(playerID); -- Update player configuration pulldown values.

            local parameters = GetPlayerParameters(playerID);
            if(parameters == nil) then
                parameters = CreatePlayerParameters(playerID);
            end

			if parameters.Parameters ~= nil then
				local parameter = parameters.Parameters["PlayerLeader"];
				local leaderType = parameter.Value.Value;
				local icons = GetPlayerIcons(parameter.Value.Domain, parameter.Value.Value);


				local playerColor = icons.PlayerColor;
				local civIcon = playerEntry["CivIcon"];
                local civIconBG = playerEntry["IconBG"];
                local colorControl = playerEntry["ColorPullDown"];
                local civWarnIcon = playerEntry["WarnIcon"];
				colorControl:SetHide(false);	

				civIconBG:SetHide(true);
                civIcon:SetHide(true);
                if (parameter.Value.Value ~= "RANDOM" and parameter.Value.Value ~= "RANDOM_POOL1" and parameter.Value.Value ~= "RANDOM_POOL2") then
                    local colorAlternate = parameters.Parameters["PlayerColorAlternate"] or 0;
        			local backColor, frontColor = UI.GetPlayerColorValues(playerColor, colorAlternate.Value);
					
					if(backColor and frontColor and backColor ~= 0 and frontColor ~= 0) then
						civIcon:SetIcon(icons.CivIcon);
        				civIcon:SetColor(frontColor);
						civIconBG:SetColor(backColor);

						civIconBG:SetHide(false);
						civIcon:SetHide(false);
	        				
						local itemCount = 0;
						if bCanChangePlayerValues then
							local colorInstanceManager = colorControl["InstanceManager"];
							if not colorInstanceManager then
								colorInstanceManager = PullDownInstanceManager:new( "InstanceOne", "Button", colorControl );
								colorControl["InstanceManager"] = colorInstanceManager;
							end

							colorInstanceManager:ResetInstances();
							for j=0, 3, 1 do					
								local backColor, frontColor = UI.GetPlayerColorValues(playerColor, j);
								if(backColor and frontColor and backColor ~= 0 and frontColor ~= 0) then
									local colorEntry = colorInstanceManager:GetInstance();
									itemCount = itemCount + 1;
	
									colorEntry.CivIcon:SetIcon(icons.CivIcon);
									colorEntry.CivIcon:SetColor(frontColor);
									colorEntry.IconBG:SetColor(backColor);
									colorEntry.Button:SetToolTipString(nil);
									colorEntry.Button:RegisterCallback(Mouse.eLClick, function()
										
										-- Update collision check color
										local primary, secondary = UI.GetPlayerColorValues(playerColor, j);
										m_teamColors[playerID] = {primary, secondary}

										local colorParameter = parameters.Parameters["PlayerColorAlternate"];
										parameters:SetParameterValue(colorParameter, j);
									end);
								end           
							end
						end

						colorControl:CalculateInternals();
						colorControl:SetDisabled(not bCanChangePlayerValues or itemCount == 0 or itemCount == 1);
					
						-- update what color we are for collision checks
						m_teamColors[playerID] = { backColor, frontColor};

						local myTeam = m_teamColors[playerID];
                        local bShowWarning = false;
						for k,v in pairs(m_teamColors) do
							if(k ~= playerID) then
								 if( myTeam and v and UI.ArePlayerColorsConflicting( v, myTeam ) ) then
                                    bShowWarning = true;
                                end
							end
						end
                        civWarnIcon:SetHide(not bShowWarning);
    					if bShowWarning == true then
    						civWarnIcon:LocalizeAndSetToolTip("LOC_SETUP_PLAYER_COLOR_COLLISION");
    					else
    						civWarnIcon:SetToolTipString(nil);
    					end
					end
                end
			end
		else
			local colorControl = playerEntry["ColorPullDown"];
			colorControl:SetHide(true);	
        end
		
		-- TeamPullDown is not controlled by PlayerConfigurationValuesToUI and is set manually.
		local noTeams = GameConfiguration.GetValue("NO_TEAMS");
		playerEntry.TeamPullDown:SetDisabled(not bCanChangePlayerValues or noTeams);
		local teamID:number = pPlayerConfig:GetTeam();
		-- If the game is in progress and this player is on a team by themselves, display it as if they are on no team.
		-- We do this to be consistent with the ingame UI.
		if(gameInProgress and GameConfiguration.GetTeamPlayerCount(teamID) <= 1) then
			teamID = TeamTypes.NO_TEAM;
		end
		if teamID >= 0 then
			-- Adjust the texture offset based on the selected team
			local teamIconName:string = TEAM_ICON_PREFIX .. tostring(teamID);
			playerEntry.ButtonSelectedTeam:SetSizeVal(TEAM_ICON_SIZE, TEAM_ICON_SIZE);
			playerEntry.ButtonSelectedTeam:SetIcon(teamIconName, TEAM_ICON_SIZE);
			playerEntry.ButtonSelectedTeam:SetColor(GetTeamColor(teamID));
			playerEntry.ButtonSelectedTeam:SetHide(false);
			playerEntry.ButtonNoTeam:SetHide(true);
		else
			playerEntry.ButtonSelectedTeam:SetHide(true);
			playerEntry.ButtonNoTeam:SetHide(false);
		end

		-- NOTE: order matters. you MUST call this after all other setup and before resize as hotseat will hide/show manipulate elements specific to that mode.
		if(isHotSeat) then
			UpdatePlayerEntry_Hotseat(playerID);		
		end

		-- Slot name toggles based on slotstatus.
		-- Update AFTER hotseat checks as hot seat checks may upate nickname.
		playerEntry.PlayerName:LocalizeAndSetText(pPlayerConfig:GetSlotName()); 
		playerEntry.AlternateName:LocalizeAndSetText(pPlayerConfig:GetSlotName()); 

		-- Update online pip status for human slots.
		if(pPlayerConfig:IsHuman()) then
			local iconStr = onlineIconStr;
			if(not Network.IsPlayerConnected(playerID)) then
				iconStr = offlineIconStr;
			end
			playerEntry.ConnectionStatus:SetText(iconStr);
		end
		
	else
		print("PlayerEntry not found for playerID(" .. tostring(playerID) .. ").");
	end
end

function OnEditName()
	local localPlayerID = Network.GetLocalPlayerID();
		m_kPopupDialog:Close();
		m_kPopupDialog:AddTitle(	  Locale.Lookup("LOC_GAME_MENU_RENAME_TITLE"));
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_RENAME_LABEL"));
		m_kPopupDialog:AddEditBox( Locale.Lookup("LOC_GAME_MENU_RENAME_BOX"), nil, OnRenameEditBox, nil)
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_GAME_MENU_RENAME_BUTTON"), OnRenameValidate );
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_CANCEL_BUTTON"), nil );
		m_kPopupDialog:Open();	
end


function OnRenameEditBox(editBox :table)
	m_nickname = editBox:GetText();
	m_nickname = tostring(m_nickname)
end


function OnRenameValidate()
	local localPlayerID = Network.GetLocalPlayerID();
	if m_nickname ~= nil then
		PlayerConfigurations[localPlayerID]:SetValue("NICK_NAME",m_nickname);
		Network.BroadcastPlayerInfo(localPlayerID);
	end
end

function Anonymise()
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();		
		
	for i, iPlayer in ipairs(player_ids) do	
		if(Network.IsPlayerConnected(iPlayer)) then
			local name :string = "Anon"
			if PlayerConfigurations[iPlayer]:GetLeaderTypeName() ~= nil then
				if PlayerConfigurations[iPlayer]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
					name = PlayerConfigurations[iPlayer]:GetPlayerName()
					else
					name = tostring(Locale.Lookup(PlayerConfigurations[iPlayer]:GetLeaderName())).." - "..iPlayer
				end
				
			end
			if PlayerConfigurations[iPlayer]:GetValue("NICK_NAME") ~= name then
				PlayerConfigurations[iPlayer]:SetValue("NICK_NAME",name);
				Network.BroadcastPlayerInfo(iPlayer);	
			end
		end
	end
end

function Anonymise_ID(playerID:number)
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();		
		
	for i, iPlayer in ipairs(player_ids) do	
		if iPlayer == playerID then
			if(Network.IsPlayerConnected(iPlayer)) then
			local name :string = "Anon"
			if PlayerConfigurations[iPlayer]:GetLeaderTypeName() ~= nil then
				if PlayerConfigurations[iPlayer]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
					name = PlayerConfigurations[iPlayer]:GetPlayerName()
					else
					name = tostring(Locale.Lookup(PlayerConfigurations[iPlayer]:GetLeaderName())).." - "..iPlayer
				end
			end
			if PlayerConfigurations[iPlayer]:GetValue("NICK_NAME") ~= name then
				PlayerConfigurations[iPlayer]:SetValue("NICK_NAME",name);
				Network.BroadcastPlayerInfo(iPlayer);	
			end
			end
		end
	end
end

function UpdatePlayerEntry_Hotseat(playerID)
	if(GameConfiguration.IsHotseat()) then
		local playerEntry = g_PlayerEntries[playerID];
		if(playerEntry ~= nil) then
			local localPlayerID = Network.GetLocalPlayerID();
			local pLocalPlayerConfig = PlayerConfigurations[localPlayerID];
			local pPlayerConfig = PlayerConfigurations[playerID];
			local slotStatus = pPlayerConfig:GetSlotStatus();

			g_hotseatNumHumanPlayers = 0;
			g_hotseatNumAIPlayers = 0;
			local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
			for i, iPlayer in ipairs(player_ids) do	
				local curPlayerConfig = PlayerConfigurations[iPlayer];
				local curSlotStatus = curPlayerConfig:GetSlotStatus();
				
				print("UpdatePlayerEntry_Hotseat: playerID=" .. iPlayer .. ", SlotStatus=" .. curSlotStatus);	
				if(curSlotStatus == SlotStatus.SS_TAKEN) then 
					g_hotseatNumHumanPlayers = g_hotseatNumHumanPlayers + 1;
				elseif(curSlotStatus == SlotStatus.SS_COMPUTER) then
					g_hotseatNumAIPlayers = g_hotseatNumAIPlayers + 1;
				end
			end
			print("UpdatePlayerEntry_Hotseat: g_hotseatNumHumanPlayers=" .. g_hotseatNumHumanPlayers .. ", g_hotseatNumAIPlayers=" .. g_hotseatNumAIPlayers);	

			if(slotStatus == SlotStatus.SS_TAKEN) then
				local nickName = pPlayerConfig:GetNickName();
				if(nickName == nil or #nickName == 0) then
					pPlayerConfig:SetHotseatName(DefaultHotseatPlayerName .. " " .. g_hotseatNumHumanPlayers);
				end
			end

			if(not g_isBuildingPlayerList and GameConfiguration.IsHotseat() and (slotStatus == SlotStatus.SS_TAKEN or slotStatus == SlotStatus.SS_COMPUTER)) then
				UpdateAllDefaultPlayerNames();
			end

			playerEntry.KickButton:SetHide(true);
			--[[ Prototype Mod Status Progress Bars
			playerEntry.PlayerModProgressStack:SetHide(true);
			--]]

			playerEntry.HotseatEditButton:RegisterCallback(Mouse.eLClick, function()
				UIManager:PushModal(Controls.EditHotseatPlayer, true);
				LuaEvents.StagingRoom_SetPlayerID(playerID);
			end);
		end
	end
end

function UpdateAllDefaultPlayerNames()
	local humanDefaultPlayerNameConfigs :table = {};
	local humanDefaultPlayerNameEntries :table = {};
	local numHumanPlayers :number = 0;
	local kPlayerIDs :table = GameConfiguration.GetMultiplayerPlayerIDs();

	for i, iPlayer in ipairs(kPlayerIDs) do
		local pCurPlayerConfig	:object = PlayerConfigurations[iPlayer];
		local pCurPlayerEntry	:object = g_PlayerEntries[iPlayer];
		local slotStatus		:number = pCurPlayerConfig:GetSlotStatus();
		
		-- Case where multiple times on one machine it appeared a config could exist
		-- for a taken player but no player object?
		local isSafeToReferencePlayer:boolean = true;
		if pCurPlayerEntry==nil and (slotStatus == SlotStatus.SS_TAKEN) then
			isSafeToReferencePlayer = false;
			UI.DataError("Mismatch player config/entry for player #"..tostring(iPlayer)..". SlotStatus: "..tostring(slotStatus));
		end
		
		if isSafeToReferencePlayer and (slotStatus == SlotStatus.SS_TAKEN) then
			local strRegEx = "^" .. DefaultHotseatPlayerName .. " %d+$"
			print(strRegEx .. " " .. pCurPlayerConfig:GetNickName());
			local isDefaultPlayerName = string.match(pCurPlayerConfig:GetNickName(), strRegEx);
			if(isDefaultPlayerName ~= nil) then
				humanDefaultPlayerNameConfigs[#humanDefaultPlayerNameConfigs+1] = pCurPlayerConfig;
				humanDefaultPlayerNameEntries[#humanDefaultPlayerNameEntries+1] = pCurPlayerEntry;
			end
		end
	end

	for i, v in ipairs(humanDefaultPlayerNameConfigs) do
		local playerConfig = humanDefaultPlayerNameConfigs[i];
		local playerEntry = humanDefaultPlayerNameEntries[i];
		playerConfig:SetHotseatName(DefaultHotseatPlayerName .. " " .. i);
		playerEntry.PlayerName:LocalizeAndSetText(playerConfig:GetNickName()); 
		playerEntry.AlternateName:LocalizeAndSetText(playerConfig:GetNickName());
	end

end

-------------------------------------------------
-- SortPlayerListStack
-------------------------------------------------
function SortPlayerListStack(a, b)
	-- a and b are the Root controls of the PlayerListEntry we are sorting.
	local playerIDA = g_PlayerRootToPlayerID[tostring(a)];
	local playerIDB = g_PlayerRootToPlayerID[tostring(b)];
	if(playerIDA ~= nil and playerIDB ~= nil) then
		local playerConfigA = PlayerConfigurations[playerIDA];
		local playerConfigB = PlayerConfigurations[playerIDB];

		if playerConfigA == nil then
			return false
		end
		
		if playerConfigB == nil then
			return true
		end
		
		-- push closed slots to the bottom
		if(playerConfigA:GetSlotStatus() == SlotStatus.SS_CLOSED) then
			return false;
		elseif(playerConfigB:GetSlotStatus() == SlotStatus.SS_CLOSED) then
			return true;
		end

		-- Finally, sort by playerID value.
		return playerIDA < playerIDB;
	elseif (playerIDA ~= nil and playerIDB == nil) then
		-- nil entries should be at the end of the list.
		return true;
	elseif(playerIDA == nil and playerIDB ~= nil) then
		-- nil entries should be at the end of the list.
		return false;
	else
		return tostring(a) < tostring(b);				
	end	
end

function UpdateReadyButton_Hotseat()
	if(GameConfiguration.IsHotseat()) then
		if(g_hotseatNumHumanPlayers == 0) then
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_READY_BLOCKED_HOTSEAT_NO_HUMAN_PLAYERS")));
			Controls.ReadyButton:SetText("");
			Controls.ReadyButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_HOTSEAT_NO_HUMAN_PLAYERS_TT");
			Controls.ReadyButton:SetDisabled(true);
		elseif(g_hotseatNumHumanPlayers + g_hotseatNumAIPlayers < 2) then
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS")));
			Controls.ReadyButton:SetText("");
			Controls.ReadyButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS_TT");
			Controls.ReadyButton:SetDisabled(true);
		elseif(not m_bTeamsValid) then
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_READY_BLOCKED_HOTSEAT_INVALID_TEAMS")));
			Controls.ReadyButton:SetText("");
			Controls.ReadyButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_HOTSEAT_INVALID_TEAMS_TT");
			Controls.ReadyButton:SetDisabled(true);
		elseif(g_badPlayerForMapSize) then
			Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_PLAYER_MAP_SIZE");
			Controls.ReadyButton:SetText("");
			Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_PLAYER_MAP_SIZE_TT", g_currentMaxPlayers);
			Controls.ReadyButton:SetDisabled(true);
		elseif(g_duplicateLeaders) then
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS")));
			Controls.ReadyButton:SetText("");
			Controls.ReadyButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
			Controls.ReadyButton:SetDisabled(true);
		else
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_START_GAME")));
			Controls.ReadyButton:SetText("");
			Controls.ReadyButton:LocalizeAndSetToolTip("");
			Controls.ReadyButton:SetDisabled(false);
		end
	end
end

function UpdateReadyButton()
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];

	if(GameConfiguration.IsHotseat()) then
		UpdateReadyButton_Hotseat();
		return;
	end

	local localPlayerEntry = GetPlayerEntry(localPlayerID);
	local localPlayerButton = localPlayerEntry.ReadyImage;
	if(m_countdownType ~= CountdownTypes.None) then
		local startLabel :string = Locale.ToUpper(Locale.Lookup("LOC_GAMESTART_COUNTDOWN_FORMAT"));  -- Defaults to COUNTDOWN_LAUNCH
		local toolTip :string = "";
		if(IsReadyCountdownActive()) then
			startLabel = Locale.ToUpper(Locale.Lookup("LOC_READY_COUNTDOWN_FORMAT"));
			toolTip = Locale.Lookup("LOC_READY_COUNTDOWN_TT");
		elseif(IsWaitForPlayersCountdownActive()) then
			startLabel = Locale.ToUpper(Locale.Lookup("LOC_WAITING_FOR_PLAYERS_COUNTDOWN_FORMAT"));
			toolTip = Locale.Lookup("LOC_WAITING_FOR_PLAYERS_COUNTDOWN_TT");
		end

		local timeRemaining :number = GetCountdownTimeRemaining();
		local intTime :number = math.floor(timeRemaining);
		if IsDraftCountdownActive() then
			intTime = intTime-2
			if intTime < 0 or intTime == 0 then
				intTime = math.max(intTime,0)
			end
		end
		Controls.StartLabel:SetText( startLabel );
		Controls.ReadyButton:LocalizeAndSetText(  intTime );
		Controls.ReadyButton:LocalizeAndSetToolTip( toolTip );
		Controls.ReadyCheck:LocalizeAndSetToolTip( toolTip );
		localPlayerButton:LocalizeAndSetToolTip( toolTip );
	elseif(IsCloudInProgressAndNotTurn()) then
		Controls.StartLabel:SetText( Locale.ToUpper(Locale.Lookup( "LOC_START_WAITING_FOR_TURN" )));
		Controls.ReadyButton:SetText("");
		Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_START_WAITING_FOR_TURN_TT" );
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_START_WAITING_FOR_TURN_TT" );
		localPlayerButton:LocalizeAndSetToolTip( "LOC_START_WAITING_FOR_TURN_TT" );
	elseif(not g_everyoneReady) then
		-- Local player hasn't readied up yet, just show "Ready"
		Controls.StartLabel:SetText( Locale.ToUpper(Locale.Lookup( "LOC_ARE_YOU_READY" )));
		Controls.ReadyButton:SetText("");
		Controls.ReadyButton:LocalizeAndSetToolTip( "" );
		Controls.ReadyCheck:LocalizeAndSetToolTip( "" );
		localPlayerButton:LocalizeAndSetToolTip( "" );
	-- Local player is ready, show why we're not in the countdown yet!
	elseif(not g_everyoneConnected) then
		-- Waiting for a player to finish connecting to the game.
		Controls.StartLabel:SetText( Locale.ToUpper(Locale.Lookup("LOC_READY_BLOCKED_PLAYERS_CONNECTING")));

		local waitingForJoinersTooltip : string = Locale.Lookup("LOC_READY_BLOCKED_PLAYERS_CONNECTING_TT");
		local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
		for i, iPlayer in ipairs(player_ids) do	
			local curPlayerConfig = PlayerConfigurations[iPlayer];
			local curSlotStatus = curPlayerConfig:GetSlotStatus();
			if(curSlotStatus == SlotStatus.SS_TAKEN and not Network.IsPlayerConnected(playerID)) then
				waitingForJoinersTooltip = waitingForJoinersTooltip .. "[NEWLINE]" .. "(" .. Locale.Lookup(curPlayerConfig:GetPlayerName()) .. ") ";
			end
		end
		Controls.ReadyButton:SetToolTipString( waitingForJoinersTooltip );
		Controls.ReadyCheck:SetToolTipString( waitingForJoinersTooltip );
		localPlayerButton:SetToolTipString( waitingForJoinersTooltip );
	elseif(g_notEnoughPlayers) then
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS");
		Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS_TT");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS_TT");
		localPlayerButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS_TT");
	elseif(not m_bTeamsValid) then
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_TEAMS_INVALID");
		Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_TEAMS_INVALID_TT" );
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_TEAMS_INVALID_TT" );
		localPlayerButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_TEAMS_INVALID_TT" );
	elseif(g_badPlayerForMapSize) then
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_PLAYER_MAP_SIZE");
		Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_PLAYER_MAP_SIZE_TT", g_currentMaxPlayers);
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_PLAYER_MAP_SIZE_TT", g_currentMaxPlayers);
		localPlayerButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_PLAYER_MAP_SIZE_TT", g_currentMaxPlayers);
	elseif(not g_everyoneModReady) then
		-- A player doesn't have the mods required for this game.
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_PLAYERS_NOT_MOD_READY");

		local waitingForModReadyTooltip : string = Locale.Lookup("LOC_READY_BLOCKED_PLAYERS_NOT_MOD_READY");
		local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
		for i, iPlayer in ipairs(player_ids) do	
			local curPlayerConfig = PlayerConfigurations[iPlayer];
			local curSlotStatus = curPlayerConfig:GetSlotStatus();
			if(curSlotStatus == SlotStatus.SS_TAKEN and not curPlayerConfig:GetModReady()) then
				waitingForModReadyTooltip = waitingForModReadyTooltip .. "[NEWLINE]" .. "(" .. Locale.Lookup(curPlayerConfig:GetPlayerName()) .. ") ";
			end
		end
		Controls.ReadyButton:SetToolTipString( waitingForModReadyTooltip );
		Controls.ReadyCheck:SetToolTipString( waitingForModReadyTooltip );
		localPlayerButton:SetToolTipString( waitingForModReadyTooltip );
	elseif(g_duplicateLeaders) then
		Controls.StartLabel:LocalizeAndSetText("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
		Controls.ReadyButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
		localPlayerButton:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
	elseif(not g_humanRequiredFilled) then
		Controls.StartLabel:LocalizeAndSetText("LOC_SETUP_ERROR_HUMANS_REQUIRED");
		Controls.ReadyButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_HUMANS_REQUIRED_TT");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_HUMANS_REQUIRED_TT");
		localPlayerButton:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_HUMANS_REQUIRED");
	elseif(not g_pbcNewGameCheck) then
		Controls.StartLabel:LocalizeAndSetText("LOC_SETUP_ERROR_PLAYBYCLOUD_REMOTE_READY");
		Controls.ReadyButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_PLAYBYCLOUD_REMOTE_READY_TT");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_PLAYBYCLOUD_REMOTE_READY_TT");
		localPlayerButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_PLAYBYCLOUD_REMOTE_READY");	
	elseif(not g_pbcMinHumanCheck) then
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_NOT_ENOUGH_HUMANS");
		Controls.ReadyButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_NOT_ENOUGH_HUMANS_TT");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_NOT_ENOUGH_HUMANS_TT");
		localPlayerButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_NOT_ENOUGH_HUMANS");			
	end

	local errorReason;
	local game_err = GetGameParametersError();
	if(game_err) then
		errorReason = game_err.Reason or "LOC_SETUP_PARAMETER_ERROR";
	end

	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		-- Check for selection error (ownership rules, duplicate leaders, etc)
		local err = GetPlayerParameterError(iPlayer)
		if(err) then
			errorReason = err.Reason or "LOC_SETUP_PLAYER_PARAMETER_ERROR"
		end
	end
	-- Block ready up when there is a civ ownership issue.  
	-- We have to do this because ownership is not communicated to the host.
	if(errorReason) then
		Controls.StartLabel:SetText("[COLOR_RED]" .. Locale.Lookup(errorReason) .. "[ENDCOLOR]");
		Controls.ReadyButton:SetDisabled(true)
		Controls.ReadyCheck:SetDisabled(true);
		localPlayerButton:SetDisabled(true);
	else
		Controls.ReadyButton:SetDisabled(false);
		Controls.ReadyCheck:SetDisabled(false);
		localPlayerButton:SetDisabled(false);
	end
end

-------------------------------------------------
-- Start Game Launch Countdown
-------------------------------------------------
function StartCountdown(countdownType :string)
	if(m_countdownType == countdownType) then
		return;
	end

	local countdownData = g_CountdownData[countdownType];
	if(countdownData == nil) then
		print("ERROR: missing countdownData for type " .. tostring(countdownType));
		return;
	end

	print("Starting Countdown Type " .. tostring(countdownType));
	m_countdownType = countdownType;

	if(countdownData.TimerType == TimerTypes.Script) then
		g_fCountdownTimer = countdownData.CountdownTime;
	else
		g_fCountdownTimer = NO_COUNTDOWN;
	end

	g_fCountdownTickSoundTime = countdownData.TickStartTime;
	g_fCountdownInitialTime = countdownData.CountdownTime;
	g_fCountdownReadyButtonTime = countdownData.CountdownTime;

	Controls.CountdownTimerAnim:RegisterAnimCallback( OnUpdateTimers );

	-- Update m_iFirstClosedSlot's player slot so it will hide the Add Player button if needed for this countdown type.
	if(m_iFirstClosedSlot ~= -1) then
		UpdatePlayerEntry(m_iFirstClosedSlot);
	end

	ShowHideReadyButtons();
end

function StartLaunchCountdown()
	--print("StartLaunchCountdown");
	local gameState = GameConfiguration.GetGameState();
	-- In progress PlayByCloud games and matchmaking games launch instantly.
	if((GameConfiguration.IsPlayByCloud() and gameState == GameStateTypes.GAMESTATE_LAUNCHED)
		or GameConfiguration.IsMatchMaking()) then
		-- Joining a PlayByCloud game already in progress has a much faster countdown to be less annoying.
		StartCountdown(CountdownTypes.Launch_Instant);
	else
		StartCountdown(CountdownTypes.Launch);
	end
end

function StartReadyCountdown()
	StartCountdown(GetReadyCountdownType());
end

-------------------------------------------------
-- Stop Launch Countdown
-------------------------------------------------
function StopCountdown()
	if(m_countdownType ~= CountdownTypes.None) then
		print("Stopping Countdown. m_countdownType=" .. tostring(m_countdownType));
	end

	Controls.TurnTimerMeter:SetPercent(0);
	m_countdownType = CountdownTypes.None;	
	g_fCountdownTimer = NO_COUNTDOWN;
	g_fCountdownInitialTime = NO_COUNTDOWN;
	UpdateReadyButton();

	-- Update m_iFirstClosedSlot's player slot so it will show the Add Player button.
	if(m_iFirstClosedSlot ~= -1) then
		UpdatePlayerEntry(m_iFirstClosedSlot);
	end

	ShowHideReadyButtons();

	Controls.CountdownTimerAnim:ClearAnimCallback();	
end


-------------------------------------------------
-- BuildPlayerList
-------------------------------------------------
function BuildPlayerList()
	ReleasePlayerParameters(); -- Release all the player parameters so they do not have zombie references to the entries we are now wiping.
	g_isBuildingPlayerList = true;
	-- Clear previous data.
	g_PlayerEntries = {};
	g_PlayerRootToPlayerID = {};
	g_cachedTeams = {};
	m_playersIM:ResetInstances();
	m_iFirstClosedSlot = -1;
	local numPlayers:number = 0;

	-- Create a player slot for every current participant and available player slot for the players.
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		local pPlayerConfig = PlayerConfigurations[iPlayer];
		if(pPlayerConfig ~= nil
			and IsDisplayableSlot(iPlayer)) then
			if(GameConfiguration.IsHotseat()) then
				local nickName = pPlayerConfig:GetNickName();
				if(nickName == nil or #nickName == 0) then
					pPlayerConfig:SetHotseatName(DefaultHotseatPlayerName .. " " .. iPlayer + 1);
				end
			end
            m_teamColors[numPlayers] = nil;
            -- Trigger a fake OnTeamChange on every active player slot to automagically create required PlayerEntry/TeamEntry
			OnTeamChange(iPlayer, true);
			numPlayers = numPlayers + 1;
            m_numPlayers = numPlayers;
		end	
	end

	UpdateTeamList(true);

	SetupGridLines(numPlayers - 1);

	g_isBuildingPlayerList = false;
end

-- ===========================================================================
-- Adjust vertical grid lines
-- ===========================================================================
function RealizeGridSize()
	Controls.PlayerListStack:CalculateSize();
	Controls.PlayersScrollPanel:CalculateSize();

	local gridLineHeight:number = math.max(Controls.PlayerListStack:GetSizeY(), Controls.PlayersScrollPanel:GetSizeY());
	for i = 1, NUM_COLUMNS do
		Controls["GridLine_" .. i]:SetEndY(gridLineHeight);
	end
	
	Controls.GridContainer:SetSizeY(gridLineHeight);
end

-------------------------------------------------
-- ResetChat
-------------------------------------------------
function ResetChat()
	m_ChatInstances = {}
	Controls.ChatStack:DestroyAllChildren();
	ChatPrintHelpHint(Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);
end

-------------------------------------------------
--	Should only be ticking if there are timers active.
-------------------------------------------------


function OnUpdateTimers( uiControl:table, fProgress:number )


	local fDTime:number = UIManager:GetLastTimeDelta();

	if(m_countdownType == CountdownTypes.None) then
		Controls.CountdownTimerAnim:ClearAnimCallback();
	else
		UpdateCountdownTimeRemaining();
		local timeRemaining :number = GetCountdownTimeRemaining();
		if IsDraftCountdownActive() then
			Controls.TurnTimerMeter:SetPercent((timeRemaining-2) / g_fCountdownInitialTime);
			else
			Controls.TurnTimerMeter:SetPercent(timeRemaining / g_fCountdownInitialTime);
		end
		if( IsLaunchCountdownActive() and not Network.IsEveryoneConnected() ) then
			-- not all players are connected anymore.  This is probably due to a player join in progress.
			StopCountdown();
		elseif( timeRemaining <= 0 ) then
			local stopCountdown = true;
			local checkForStart = false;
			if( IsLaunchCountdownActive() ) then
				-- Timer elapsed, launch the game if we're the netsession host.
				if(Network.IsNetSessionHost()) then
					Network.LaunchGame();
				end
			elseif( IsDraftCountdownActive() ) then	
				if(Network.IsNetSessionHost()) then
					OnHostSkip();
				end				
				StopCountdown();
			elseif( IsReadyCountdownActive() ) then
				-- Force ready the local player
				SetLocalReady(true);

				if(IsUseWaitingForPlayersCountdown()) then
					-- Transition to the Waiting For Players countdown.
					StartCountdown(CountdownTypes.WaitForPlayers);
					stopCountdown = false;
				end
			elseif( IsWaitForPlayersCountdownActive() ) then
				-- After stopping the countdown, recheck for start.  This should trigger the launch countdown because all players should be past their ready countdowns.
				checkForStart = true;			
			end

			if(stopCountdown == true) then
				StopCountdown();
			end

			if(checkForStart == true) then
				CheckGameAutoStart();
			end
		else
			-- Update countdown tick sound.
			if( timeRemaining < g_fCountdownTickSoundTime) then
				g_fCountdownTickSoundTime = g_fCountdownTickSoundTime-1; -- set countdown tick for next second.
				UI.PlaySound("Play_MP_Game_Launch_Timer_Beep");
			end

			-- Update countdown ready button.
			if( timeRemaining < g_fCountdownReadyButtonTime) then
				g_fCountdownReadyButtonTime = g_fCountdownReadyButtonTime-1; -- set countdown tick for next second.
				UpdateReadyButton();
			end
		end
	end
end

function UpdateCountdownTimeRemaining()
	local countdownData :table = g_CountdownData[m_countdownType];
	if(countdownData == nil) then
		print("ERROR: missing countdown data!");
		return;
	end

	if(countdownData.TimerType == TimerTypes.NetworkManager) then
		-- Network Manager timer updates itself.
		return;
	end

	local fDTime:number = UIManager:GetLastTimeDelta();
	g_fCountdownTimer = g_fCountdownTimer - fDTime;
end

-------------------------------------------------
-------------------------------------------------
function OnShow()
	-- Fetch g_currentMaxPlayers because it might be stale due to loading a save.
	g_currentMaxPlayers = math.min(MapConfiguration.GetMaxMajorPlayers(), 50);
	m_shownPBCReadyPopup = false;
	m_exitReadyWait = false;
	
	if GameConfiguration.GetValue("GAMEMODE_ANONYMOUS") == true then
		Anonymise_ID(Network.GetLocalPlayerID())
	end

	local networkSessionID:number = Network.GetSessionID();
	if m_sessionID ~= networkSessionID then
		-- This is a fresh session.
		m_sessionID = networkSessionID;

		StopCountdown();

		-- When using the ready countdown mode, start the ready countdown if the player is not already readied up.
		-- If the player is already readied up, we just don't allow them to unready.
		local localPlayerID :number = Network.GetLocalPlayerID();
		local localPlayerConfig :table = PlayerConfigurations[localPlayerID];
		if(IsUseReadyCountdown() 
			and localPlayerConfig ~= nil
			and localPlayerConfig:GetReady() == false) then
			StartReadyCountdown();
		end
	end

	InitializeReadyUI();
	ShowHideInviteButton();	
	ShowHideEditButton();	
	ShowHideTopLeftButtons();
	RealizeGameSetup();
	BuildPlayerList();
	PopulateTargetPull(Controls.ChatPull, Controls.ChatEntry, Controls.ChatIcon, m_playerTargetEntries, m_playerTarget, false, OnChatPulldownChanged);
	ShowHideChatPanel();

	local pFriends = Network.GetFriends();
	if (pFriends ~= nil) then
		pFriends:SetRichPresence("civPresence", Network.IsGameHost() and "LOC_PRESENCE_HOSTING_GAME" or "LOC_PRESENCE_IN_STAGING_ROOM");
	end

	UpdateFriendsList();
	RealizeInfoTabs();
	RealizeGridSize();

	-- Forgive me universe!
	Controls.ReadyButton:SetOffsetY(isHotSeat and -16 or -18);

	if(Automation.IsActive()) then
		if(not Network.IsGameHost()) then
			-- Remote clients ready up immediately.
			SetLocalReady(true);
		else
			local minPlayers = Automation.GetSetParameter("CurrentTest", "MinPlayers", 2);
			if (minPlayers ~= nil) then
				-- See if we are going to be the only one in the game, set ourselves ready. 
				if (minPlayers == 1) then
					Automation.Log("HostGame MinPlayers==1, host readying up.");
					SetLocalReady(true);
				end
			end
		end
	end
end


function OnChatPulldownChanged(newTargetType :number, newTargetID :number)
	local textControl:table = Controls.ChatPull:GetButton():GetTextControl();
	local text:string = textControl:GetText();
	Controls.ChatPull:SetToolTipString(text);
end

-------------------------------------------------
-------------------------------------------------
function InitializeReadyUI()
	-- Set initial ready check state.  This might be dirty from a previous staging room.
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];

	if(IsCloudInProgressAndNotTurn()) then
		-- Show the ready check as unselected while in an inprogress PlayByCloud match where it is not our turn.  
		-- Clicking the ready button will instant launch the match so the player can observe the current game state.
		Controls.ReadyCheck:SetSelected(false);
	else
		Controls.ReadyCheck:SetSelected(localPlayerConfig:GetReady());
	end

	-- Hotseat doesn't use the readying mechanic (countdown; ready background elements; ready column). 
	local isHotSeat:boolean = GameConfiguration.IsHotseat();
	Controls.LargeCompassDeco:SetHide(isHotSeat);
	Controls.TurnTimerBG:SetHide(isHotSeat);
	Controls.TurnTimerMeter:SetHide(isHotSeat);
	Controls.TurnTimerHotseatBG:SetHide(not isHotSeat);
	Controls.ReadyColumnLabel:SetHide(isHotSeat);

	ShowHideReadyButtons();
end

-------------------------------------------------
-------------------------------------------------
function ShowHideInviteButton()
	local canInvite :boolean = CanInviteFriends(true);

	Controls.InviteButton:SetHide( not canInvite );
end

-------------------------------------------------
function ShowHideEditButton()
	local gameInProgress:boolean = GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME;
	local isHotSeat:boolean = GameConfiguration.IsHotseat();
	local isPBC:boolean = GameConfiguration.IsPlayByCloud();
	
	if 	gameInProgress or isHotSeat or isPBC or g_phase == PHASE_MAPBAN or g_phase == PHASE_LEADERBAN or g_phase == PHASE_LEADERPICK then
		Controls.EditNameButton:SetHide(true);
		else
		Controls.EditNameButton:SetHide(false);
	end
	
	if GameConfiguration.GetValue("GAMEMODE_ANONYMOUS") == true then
		Controls.EditNameButton:SetHide(true);
	end
end

-------------------------------------------------

-------------------------------------------------
-------------------------------------------------
function ShowHideTopLeftButtons()
	local showEndGame :boolean = GameConfiguration.IsPlayByCloud() and Network.IsGameHost();
	local showQuitGame : boolean = GameConfiguration.IsPlayByCloud();

	Controls.EndGameButton:SetHide( not showEndGame);
	Controls.QuitGameButton:SetHide( not showQuitGame);

	Controls.LeftTopButtonStack:CalculateSize();	
end

-------------------------------------------------
-------------------------------------------------
function ShowHideReadyButtons()
	-- show ready button when in not in a countdown or hotseat.
	local showReadyCheck = not GameConfiguration.IsHotseat() and (m_countdownType == CountdownTypes.None);
	Controls.ReadyCheckContainer:SetHide(not showReadyCheck);
	Controls.ReadyButtonContainer:SetHide(showReadyCheck);
end

-------------------------------------------------
-------------------------------------------------
function ShowHideChatPanel()
	if(GameConfiguration.IsHotseat() or not UI.HasFeature("Chat") or GameConfiguration.IsPlayByCloud()) then
		Controls.ChatContainer:SetHide(true);
	else
		Controls.ChatContainer:SetHide(false);
	end
	--Controls.TwinPanelStack:CalculateSize();
end

-------------------------------------------------------------------------------
-- Setup Player Interface
-- This gets or creates player parameters for a given player id.
-- It then appends a driver to the setup parameter to control a visual 
-- representation of the parameter
-------------------------------------------------------------------------------
function SetupSplitLeaderPulldown(playerId:number, instance:table, pulldownControlName:string, civIconControlName, leaderIconControlName, tooltipControls:table)
	local localPlayerID = Network.GetLocalPlayerID();
	


	local parameters = GetPlayerParameters(playerId);
	if(parameters == nil) then
		parameters = CreatePlayerParameters(playerId);
	end

	-- Need to save our master tooltip controls so that we can update them if we hop into advanced setup and then go back to basic setup
	if (tooltipControls.HasLeaderPlacard) then
		m_tooltipControls = {};
		m_tooltipControls = tooltipControls;
	end

	-- Defaults
	if(leaderIconControlName == nil) then
		leaderIconControlName = "LeaderIcon";
	end
		
	local control = instance[pulldownControlName];
	local leaderIcon = instance[leaderIconControlName];
	local civIcon = instance["CivIcon"];
	local civIconBG = instance["IconBG"];
	local civWarnIcon = instance["WarnIcon"];
	local scrollText = instance["ScrollText"];										  
	local instanceManager = control["InstanceManager"];
	if not instanceManager then
		instanceManager = PullDownInstanceManager:new( "InstanceOne", "Button", control );
		control["InstanceManager"] = instanceManager;
	end

	local colorControl = instance["ColorPullDown"];
	local colorInstanceManager = colorControl["InstanceManager"];
	if not colorInstanceManager then
		colorInstanceManager = PullDownInstanceManager:new( "InstanceOne", "Button", colorControl );
		colorControl["InstanceManager"] = colorInstanceManager;
	end
    colorControl:SetDisabled(true);

	local controls = parameters.Controls["PlayerLeader"];
	if(controls == nil) then
		controls = {};
		parameters.Controls["PlayerLeader"] = controls;
	end

	m_currentInfo = {										
		CivilizationIcon = "ICON_CIVILIZATION_UNKNOWN",
		LeaderIcon = "ICON_LEADER_DEFAULT",
		CivilizationName = "LOC_RANDOM_CIVILIZATION",
		LeaderName = "LOC_RANDOM_LEADER"
	};



	civWarnIcon:SetHide(true);
	civIconBG:SetHide(true);

	table.insert(controls, {
		UpdateValue = function(v)
			local button = control:GetButton();

			if(v == nil) then
				button:LocalizeAndSetText("LOC_SETUP_ERROR_INVALID_OPTION");
				button:ClearCallback(Mouse.eMouseEnter);
				button:ClearCallback(Mouse.eMouseExit);
			else
				local caption = v.Name;
				if(v.Invalid) then
					local err = v.InvalidReason or "LOC_SETUP_ERROR_INVALID_OPTION";
					caption = caption .. "[NEWLINE][COLOR_RED](" .. Locale.Lookup(err) .. ")[ENDCOLOR]";
				end

				if(scrollText ~= nil) then
					scrollText:SetText(caption);
					button:LocalizeAndSetText("");			   
				else
					button:SetText(caption);
				end
				local icons = GetPlayerIcons(v.Domain, v.Value);
				local playerColor = icons.PlayerColor or "";
				if(leaderIcon) then
					leaderIcon:SetIcon(icons.LeaderIcon);
				end

				if(not tooltipControls.HasLeaderPlacard) then
					-- Upvalues
					local info;
					local domain = v.Domain;
					local value = v.Value;
					button:RegisterCallback( Mouse.eMouseEnter, function() 
						if(info == nil) then info = GetPlayerInfo(domain, value, playerId); end
						DisplayCivLeaderToolTip(info, tooltipControls, false); 
					end);
					
					button:RegisterCallback( Mouse.eMouseExit, function() 
						if(info == nil) then info = GetPlayerInfo(domain, value, playerId); end
						DisplayCivLeaderToolTip(info, tooltipControls, true); 
					end);
				end

				local primaryColor, secondaryColor = UI.GetPlayerColorValues(playerColor, 0);
				if v.Value == "RANDOM" or v.Value == "RANDOM_POOL1" or v.Value == "RANDOM_POOL2" or primaryColor == nil then
					civIconBG:SetHide(true);
					civIcon:SetHide(true);
					civWarnIcon:SetHide(true);
                    colorControl:SetDisabled(true);
				else

					local colorCount = 0;
					for j=0, 3, 1 do
						local backColor, frontColor = UI.GetPlayerColorValues(playerColor, j);
						if(backColor and frontColor and backColor ~= 0 and frontColor ~= 0) then
							colorCount = colorCount + 1;
						end
					end

					local notExternalEnabled = not CheckExternalEnabled(playerId, true, true, nil);
					colorControl:SetDisabled(notExternalEnabled or colorCount == 0 or colorCount == 1);

                    -- also update collision check color
                    -- Color collision checking.
					local myTeam = m_teamColors[playerId];
					local bShowWarning = false;
					for k , v in pairs(m_teamColors) do
						if(k ~= playerId) then
							if( myTeam and v and myTeam[1] == v[1] and myTeam[2] == v[2] ) then
								bShowWarning = true;
							end
						end
					end
					civWarnIcon:SetHide(not bShowWarning);
    				if bShowWarning == true then
    					civWarnIcon:LocalizeAndSetToolTip("LOC_SETUP_PLAYER_COLOR_COLLISION");
    				else
    					civWarnIcon:SetToolTipString(nil);
    				end	
                end
			end		
		end,
		UpdateValues = function(values)
			instanceManager:ResetInstances();
            local iIteratedPlayerID = 0;

			-- Avoid creating call back for each value.
			local hasPlacard = tooltipControls.HasLeaderPlacard;
			local OnMouseExit = function()
				DisplayCivLeaderToolTip(m_currentInfo, tooltipControls, not hasPlacard);
			end;

			for i,v in ipairs(values) do
				local icons = GetPlayerIcons(v.Domain, v.Value);
				local playerColor = icons.PlayerColor;

				local entry = instanceManager:GetInstance();
				
				local caption = v.Name;
				if(v.Invalid) then 
					local err = v.InvalidReason or "LOC_SETUP_ERROR_INVALID_OPTION";
					caption = caption .. "[NEWLINE][COLOR_RED](" .. Locale.Lookup(err) .. ")[ENDCOLOR]";
				end

				if(entry.ScrollText ~= nil) then
					entry.ScrollText:SetText(caption);
				else
					entry.Button:SetText(caption);
				end
				entry.LeaderIcon:SetIcon(icons.LeaderIcon);
				
				-- Upvalues
				local info;
				local domain = v.Domain;
				local value = v.Value;
				
				entry.Button:RegisterCallback( Mouse.eMouseEnter, function() 
					if(info == nil) then info = GetPlayerInfo(domain, value, playerId); end
					DisplayCivLeaderToolTip(info, tooltipControls, false);
				 end);

				entry.Button:RegisterCallback( Mouse.eMouseExit,OnMouseExit);
				entry.Button:SetToolTipString(nil);			

				entry.Button:RegisterCallback(Mouse.eLClick, function()
					if(info == nil) then info = GetPlayerInfo(domain, value); end

					--  if the user picked random, hide the civ icon again
					local primaryColor, secondaryColor = UI.GetPlayerColorValues(playerColor, 0);
					 m_teamColors[playerId] = {primaryColor, secondaryColor};

                    -- set default alternate color to the primary
					local colorParameter = parameters.Parameters["PlayerColorAlternate"]; 
					parameters:SetParameterValue(colorParameter, 0);

                    -- set the team
                    local leaderParameter = parameters.Parameters["PlayerLeader"];
					parameters:SetParameterValue(leaderParameter, v);

					if(playerId == 0) then
						m_currentInfo = info;
					end
				end);
			end
			control:CalculateInternals();
		end,
		SetEnabled = function(enabled, parameter)
			local notExternalEnabled = not CheckExternalEnabled(playerId, enabled, true, parameter);
			local singleOrEmpty = #parameter.Values <= 1;

            control:SetDisabled(notExternalEnabled or singleOrEmpty);
		end,
	--	SetVisible = function(visible)
	--		control:SetHide(not visible);
	--	end
	});
end

-- ===========================================================================
function OnGameSetupTabClicked()
	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================

function RealizeShellTabs()
	m_shellTabIM:ResetInstances();

	local gameSetup:table = m_shellTabIM:GetInstance();
	gameSetup.Button:SetText(LOC_GAME_SETUP);
	gameSetup.SelectedButton:SetText(LOC_GAME_SETUP);
	gameSetup.Selected:SetHide(true);
	gameSetup.Button:RegisterCallback( Mouse.eLClick, OnGameSetupTabClicked );

	AutoSizeGridButton(gameSetup.Button,250,32,10,"H");
	AutoSizeGridButton(gameSetup.SelectedButton,250,32,20,"H");
	gameSetup.TopControl:SetSizeX(gameSetup.Button:GetSizeX());

	local stagingRoom:table = m_shellTabIM:GetInstance();
	stagingRoom.Button:SetText(LOC_STAGING_ROOM);
	stagingRoom.SelectedButton:SetText(LOC_STAGING_ROOM);
	stagingRoom.Button:SetDisabled(not Network.IsInSession());
	stagingRoom.Selected:SetHide(false);

	AutoSizeGridButton(stagingRoom.Button,250,32,20,"H");
	AutoSizeGridButton(stagingRoom.SelectedButton,250,32,20,"H");
	stagingRoom.TopControl:SetSizeX(stagingRoom.Button:GetSizeX());
	
	Controls.ShellTabs:CalculateSize();
end

-- ===========================================================================
function OnGameSummaryTabClicked()
	-- TODO
end

function OnFriendsTabClicked()
	-- TODO
end

-- ===========================================================================
function BuildGameSetupParameter(o, parameter)

	local parent = GetControlStack(parameter.GroupId);
	local control;
	
	-- If there is no parent, don't visualize the control.  This is most likely a player parameter.
	if(parent == nil or not parameter.Visible) then
		return;
	end;

	
	local c = m_gameSetupParameterIM:GetInstance();		
	c.Root:ChangeParent(parent);

	-- Store the root control, NOT the instance table.
	g_SortingMap[tostring(c.Root)] = parameter;		
			
	c.Label:SetText(parameter.Name);
	c.Value:SetText(parameter.DefaultValue);
	c.Root:SetToolTipString(parameter.Description);

	control = {
		Control = c,
		UpdateValue = function(value, p)
			local t:string = type(value);
			if(p.Array) then
				local valueText;

				if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
					valueText = Locale.Lookup("LOC_SELECTION_EVERYTHING");
				else
					valueText = Locale.Lookup("LOC_SELECTION_NOTHING");
				end

				-- Remove random leaders from the Values table that is used to determine number of leaders selected
				for i = #p.Values, 1, -1 do
					local kItem:table = p.Values[i];
					if kItem.Value == "RANDOM" or kItem.Value == "RANDOM_POOL1" or kItem.Value == "RANDOM_POOL2" then
						table.remove(p.Values, i);
					end
				end
				if(t == "table") then
					local count = #value;
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						if(count == 0) then
							valueText = Locale.Lookup("LOC_SELECTION_EVERYTHING");
						elseif(count == #p.Values) then
							valueText = Locale.Lookup("LOC_SELECTION_NOTHING");
						else
							valueText = Locale.Lookup("LOC_SELECTION_CUSTOM", #p.Values-count);
						end
					else
						if(count == 0) then
							valueText = Locale.Lookup("LOC_SELECTION_NOTHING");
						elseif(count == #p.Values) then
							valueText = Locale.Lookup("LOC_SELECTION_EVERYTHING");
						else
							valueText = Locale.Lookup("LOC_SELECTION_CUSTOM", count);
						end
					end
				end
				c.Value:SetText(valueText);
				c.Value:SetToolTipString(parameter.Description);												
			else
				if t == "table" then
					c.Value:SetText(value.Name);
				elseif t == "boolean" then
					c.Value:SetText(Locale.Lookup(value and "LOC_MULTIPLAYER_TRUE" or "LOC_MULTIPLAYER_FALSE"));
				else
					c.Value:SetText(tostring(value));
				end
			end			
		end,
		SetVisible = function(visible)
			c.Root:SetHide(not visible);
		end,
		Destroy = function()
			g_StringParameterManager:ReleaseInstance(c);
		end,
	};

	o.Controls[parameter.ParameterId] = control;
end

function RealizeGameSetup()
	BuildGameState();

	m_gameSetupParameterIM:ResetInstances();
	BuildGameSetup(BuildGameSetupParameter);

	BuildAdditionalContent();
end


-- ===========================================================================
--	Can join codes be used in the current lobby system?
-- ===========================================================================
function ShowJoinCode()
	local pbcMode			:boolean = GameConfiguration.IsPlayByCloud() and (GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_LOAD_PREGAME or GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_PREGAME);
	local crossPlayMode		:boolean = (Network.GetTransportType() == TransportType.TRANSPORT_EOS);
	local eosAllowed		:boolean = (Network.GetNetworkPlatform() == NetworkPlatform.NETWORK_PLATFORM_EOS) and GameConfiguration.IsInternetMultiplayer();
	return pbcMode or crossPlayMode or eosAllowed;
end

-- ===========================================================================
function BuildGameState()
	-- Indicate that this game is for loading a save or already in progress.
	local gameState = GameConfiguration.GetGameState();
	if(gameState ~= GameStateTypes.GAMESTATE_PREGAME) then
		local gameModeStr : string;

		if(gameState == GameStateTypes.GAMESTATE_LOAD_PREGAME) then
			-- in the pregame for loading a save
			gameModeStr = loadingSaveGameStr;
			if (GameConfiguration.GetValue("CPL_BAN_FORMAT") == 3 or GameConfiguration.GetValue("CPL_BAN_FORMAT") == 4) then
				g_phase = PHASE_READY
			end																												   
		else
			-- standard game in progress
			gameModeStr = gameInProgressGameStr;
		end
		Controls.GameStateText:SetHide(false);
		Controls.GameStateText:SetText(gameModeStr);
	else
		Controls.GameStateText:SetHide(true);
	end

	-- A 'join code' is a short string that can be sent through the MP system
	-- to allow other players to connect to the same session of the game.
	-- Originally only for PBC but added to support other MP game types.
	local joinCode :string = Network.GetJoinCode();
	Controls.JoinCodeRoot:SetHide( ShowJoinCode()==false );
	if joinCode ~= nil and joinCode ~= "" then
		Controls.JoinCodeText:SetText(joinCode);
	else
		Controls.JoinCodeText:SetText("---");			-- Better than showing nothing?
	end

	Controls.AdditionalContentStack:CalculateSize();
	Controls.ParametersScrollPanel:CalculateSize();
end

-- ===========================================================================
function BuildAdditionalContent()
	m_modsIM:ResetInstances();
	local enabledMods = GameConfiguration.GetEnabledMods();
	b_mph_game = false
	b_spec_game = false
	isCivPlayerName = false
	local count = 0
	for _, curMod in ipairs(enabledMods) do
		count = count + 1
		local modControl = m_modsIM:GetInstance();
		local modTitleStr : string = curMod.Title;
		-- Color unofficial mods to call them out.
		if curMod.Id == "6e52c135-00e7-44b5-a7de-6588a4f38797" then
			isCivPlayerName = true
			modTitleStr =  "[COLOR_RED]".. modTitleStr .. "[ENDCOLOR]";
		end
		if curMod.Id == "619ac86e-d99d-4bf3-b8f0-8c5b8c402176" then
			modTitleStr =  "[COLOR_LIGHTBLUE]".. modTitleStr .. "[ENDCOLOR] (local: "..GetLocalModVersion(curMod.Id)..")";
			b_mph_game = true
		end
		if curMod.Id == "3291a787-4a93-445c-998d-e22034ab15b3" or curMod.Id == "c6e5ad32-0600-4a98-a7cd-5854a1abcaaf" then
			modTitleStr =  "[COLOR_LIGHTBLUE]".. modTitleStr .. "[ENDCOLOR]";
			b_spec_game = true
		end		
		if curMod.Id == "c88cba8b-8311-4d35-90c3-51a4a5d6654f" then
			modTitleStr =  "[COLOR_LIGHTBLUE]".. modTitleStr .. "[ENDCOLOR] (local: "..GetLocalModVersion(curMod.Id)..")";
			b_bbs_game = true
			s_bbs_id = curMod.Id
		end	
		if curMod.Id == "cb84074d-5007-4207-b662-c35a5f7be230" 
			or curMod.Id == "cb84074d-5007-4207-b662-c35a5f7be217"
			or curMod.Id == "cb84074d-5007-4207-b662-c35a5f7be240" then
			modTitleStr =  "[COLOR_LIGHTBLUE]".. modTitleStr .. "[ENDCOLOR] (local: "..GetLocalModVersion(curMod.Id)..")";
			b_bbg_game = true
			s_bbg_id = curMod.Id
		end			
		if(not curMod.Official) then
			modTitleStr = ColorString_ModGreen .. modTitleStr .. "[ENDCOLOR]";
		end
		modControl.ModTitle:SetText(modTitleStr);
	end



	Controls.AdditionalContentStack:CalculateSize();
	Controls.ParametersScrollPanel:CalculateSize();
end

-- ===========================================================================
function RealizeInfoTabs()
	m_infoTabsIM:ResetInstances();
	local friends:table;
	local gameSummary:table

	gameSummary = m_infoTabsIM:GetInstance();
	gameSummary.Button:SetText(LOC_GAME_SUMMARY);
	gameSummary.SelectedButton:SetText(LOC_GAME_SUMMARY);
	gameSummary.Selected:SetHide(not g_viewingGameSummary);

	gameSummary.Button:RegisterCallback(Mouse.eLClick, function()
		g_viewingGameSummary = true;
		Controls.Friends:SetHide(true);
		friends.Selected:SetHide(true);
		gameSummary.Selected:SetHide(false);
		Controls.ParametersScrollPanel:SetHide(false);
	end);

	AutoSizeGridButton(gameSummary.Button,200,32,10,"H");
	AutoSizeGridButton(gameSummary.SelectedButton,200,32,20,"H");
	gameSummary.TopControl:SetSizeX(gameSummary.Button:GetSizeX());

	if not GameConfiguration.IsHotseat() then
		friends = m_infoTabsIM:GetInstance();
		friends.Button:SetText(LOC_FRIENDS);
		friends.SelectedButton:SetText(LOC_FRIENDS);
		friends.Selected:SetHide(g_viewingGameSummary);
		friends.Button:SetDisabled(not Network.IsInSession());
		friends.Button:RegisterCallback( Mouse.eLClick, function()
			g_viewingGameSummary = false;
			Controls.Friends:SetHide(false);
			friends.Selected:SetHide(false);
			gameSummary.Selected:SetHide(true);
			Controls.ParametersScrollPanel:SetHide(true);
			UpdateFriendsList();
		end );

		AutoSizeGridButton(friends.Button,200,32,20,"H");
		AutoSizeGridButton(friends.SelectedButton,200,32,20,"H");
		friends.TopControl:SetSizeX(friends.Button:GetSizeX());
	end

	Controls.InfoTabs:CalculateSize();
end

-------------------------------------------------
function UpdateFriendsList()

	if ContextPtr:IsHidden() or GameConfiguration.IsHotseat() then
		Controls.InfoContainer:SetHide(true);
		return;
	end

	m_friendsIM:ResetInstances();
	Controls.InfoContainer:SetHide(false);
	local friends:table = GetFriendsList();
	local bCanInvite:boolean = CanInviteFriends(false) and Network.HasSingleFriendInvite();

	-- DEBUG
	--for i = 1, 19 do
	-- /DEBUG
	for _, friend in pairs(friends) do
		local instance:table = m_friendsIM:GetInstance();

		-- Build the dropdown for the friend list
		local friendActions:table = {};
		BuildFriendActionList(friendActions, bCanInvite and not IsFriendInGame(friend));

		-- end build
		local friendPlayingCiv:boolean = friend.PlayingCiv; -- cache value to ensure it's available in callback function

		PopulateFriendsInstance(instance, friend, friendActions, 
			function(friendID, actionType) 
				if actionType == "invite" then
					local statusText:string = friendPlayingCiv and "LOC_PRESENCE_INVITED_ONLINE" or "LOC_PRESENCE_INVITED_OFFLINE";
					instance.PlayerStatus:LocalizeAndSetText(statusText);
				end
			end
		);

	end
	-- DEBUG
	--end
	-- /DEBUG

	Controls.FriendsStack:CalculateSize();
	Controls.FriendsScrollPanel:CalculateSize();
	Controls.FriendsScrollPanel:GetScrollBar():SetAndCall(0);

	if Controls.FriendsScrollPanel:GetScrollBar():IsHidden() then
		Controls.FriendsScrollPanel:SetOffsetX(8);
	else
		Controls.FriendsScrollPanel:SetOffsetX(3);
	end

	if table.count(friends) == 0 then
		Controls.InviteButton:SetAnchor("C,C");
		Controls.InviteButton:SetOffsetY(0);
	else
		Controls.InviteButton:SetAnchor("C,B");
		Controls.InviteButton:SetOffsetY(27);
	end
end

function IsFriendInGame(friend:table)
	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		local curPlayerConfig = PlayerConfigurations[iPlayer];
		local steamID = curPlayerConfig:GetNetworkIdentifer();
		if( steamID ~= nil and steamID == friend.ID and Network.IsPlayerConnected(iPlayer) ) then
			return true;
		end
	end
	return fasle;
end

-------------------------------------------------
function SetupGridLines(numPlayers:number)
	g_GridLinesIM:ResetInstances();
	RealizeGridSize();
	local nextY:number = GRID_LINE_HEIGHT;
	local gridSize:number = Controls.GridContainer:GetSizeY();
	local numLines:number = math.max(numPlayers, gridSize / GRID_LINE_HEIGHT);
	for i:number = 1, numLines do
		g_GridLinesIM:GetInstance().Control:SetOffsetY(nextY);
		nextY = nextY + GRID_LINE_HEIGHT;
	end
end

-------------------------------------------------
-------------------------------------------------
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues( "StagingRoom" );
	end
end

function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue("StagingRoom", "isHidden", ContextPtr:IsHidden());
end

function OnGameDebugReturn( context:string, contextTable:table )
	if context == "StagingRoom" and contextTable["isHidden"] == false then
		if ContextPtr:IsHidden() then
			ContextPtr:SetHide(false);
		else
			OnShow();
		end
	end	
end

-- ===========================================================================
--	LUA Event
--	Show the screen
-- ===========================================================================
function OnRaise(resetChat:boolean)
	-- Make sure HostGame screen is on the stack
	LuaEvents.StagingRoom_EnsureHostGame();

	UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
end

-- ===========================================================================
function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	Controls.MainWindow:SetSizeY(screenY-( Controls.LogoContainer:GetSizeY()-Controls.LogoContainer:GetOffsetY() ));
	local window = Controls.MainWindow:GetSizeY() - Controls.TopPanel:GetSizeY();
	Controls.ChatContainer:SetSizeY(window/2 -80)
	Controls.PrimaryStackGrid:SetSizeY(window-Controls.ChatContainer:GetSizeY() -75 )
	Controls.InfoContainer:SetSizeY(window/2 -80)
	Controls.PrimaryPanelStack:CalculateSize()
	RealizeGridSize();
end

-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
	Resize();
  end
end

-- ===========================================================================
function StartExitGame()
	if(GetReadyCountdownType() == CountdownTypes.Ready_PlayByCloud) then
		-- If we are using the PlayByCloud ready countdown, the local player needs to be set to ready before they can leave.
		-- If we are not ready, we set ready and wait for that change to propagate to the backend.
		local localPlayerID :number = Network.GetLocalPlayerID();
		local localPlayerConfig :table = PlayerConfigurations[localPlayerID];
		if(localPlayerConfig:GetReady() == false) then
			m_exitReadyWait = true;
			SetLocalReady(true);

			-- Next step will be in OnUploadCloudPlayerConfigComplete.
			return;
		end
	end

	Close();
end

-- ===========================================================================
function OnEndGame_Start()
	Network.CloudKillGame();

	-- Show killing game popup
	m_kPopupDialog:Close(); -- clear out the popup incase it is already open.
	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_PROMPT"));
	m_kPopupDialog:Open();

	-- Next step is in OnCloudGameKilled.
end

function OnQuitGame_Start()
	Network.CloudQuitGame();

	-- Show killing game popup
	m_kPopupDialog:Close(); -- clear out the popup incase it is already open.
	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_QUITING_GAME_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_QUITING_GAME_PROMPT"));
	m_kPopupDialog:Open();

	-- Next step is in OnCloudGameQuit.
end

function OnExitGameAskAreYouSure()
	if(GameConfiguration.IsPlayByCloud()) then
		-- PlayByCloud immediately exits to streamline the process and avoid confusion with the popup text.
		StartExitGame();
		return;
	end

	m_kPopupDialog:Close();	-- clear out the popup incase it is already open.
	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_GAME_MENU_QUIT_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_QUIT_WARNING"));
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), StartExitGame, nil, nil, "PopupButtonInstanceRed" );
	m_kPopupDialog:Open();
end

function OnEndGameAskAreYouSure()
	m_kPopupDialog:Close(); -- clear out the popup incase it is already open.
	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_GAME_MENU_END_GAME_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_END_GAME_WARNING"));
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnEndGame_Start, nil, nil, "PopupButtonInstanceRed" );
	m_kPopupDialog:Open();
end

function OnQuitGameAskAreYouSure()
	m_kPopupDialog:Close(); -- clear out the popup incase it is already open.
	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_GAME_MENU_QUIT_GAME_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_QUIT_GAME_WARNING"));
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnQuitGame_Start, nil, nil, "PopupButtonInstanceRed" );
	m_kPopupDialog:Open();
end


-- ===========================================================================
function GetInviteTT()
	if( Network.GetNetworkPlatform() == NetworkPlatform.NETWORK_PLATFORM_EOS ) then
		return Locale.Lookup("LOC_EPIC_INVITE_BUTTON_TT");
	end

	return Locale.Lookup("LOC_INVITE_BUTTON_TT");
end



-- ===========================================================================
--	Initialize screen
-- ===========================================================================
function Initialize()
	local localPlayerID = Network.GetLocalPlayerID();
	local hostID = Network.GetGameHostPlayerID()

	m_kPopupDialog = PopupDialog:new( "StagingRoom" );
	
	SetCurrentMaxPlayers(MapConfiguration.GetMaxMajorPlayers());
	SetCurrentMinPlayers(MapConfiguration.GetMinMajorPlayers());
	Events.SystemUpdateUI.Add(OnUpdateUI);
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShowHandler(OnShow);
	Controls.EditNameButton:RegisterCallback( Mouse.eLClick, OnEditName );
	Controls.EditNameButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnExitGameAskAreYouSure );
	Controls.BackButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ModCheckButton:RegisterCallback( Mouse.eLClick, OnModCheck );
	Controls.ModCheckButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ChatEntry:RegisterCommitCallback( SendChat );
	Controls.InviteButton:RegisterCallback( Mouse.eLClick, OnInviteButton );
	Controls.InviteButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.EndGameButton:RegisterCallback( Mouse.eLClick, OnEndGameAskAreYouSure );
	Controls.EndGameButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);	
	Controls.QuitGameButton:RegisterCallback( Mouse.eLClick, OnQuitGameAskAreYouSure );
	Controls.QuitGameButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);	
	Controls.ReadyButton:RegisterCallback( Mouse.eLClick, OnReadyButton );
	Controls.ReadyButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ReadyCheck:RegisterCallback( Mouse.eLClick, OnReadyButton );
	Controls.ReadyCheck:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.JoinCodeText:RegisterCallback( Mouse.eLClick, OnClickToCopy );

	Controls.InviteButton:SetToolTipString(GetInviteTT());

	Events.MapMaxMajorPlayersChanged.Add(OnMapMaxMajorPlayersChanged); 
	Events.MapMinMajorPlayersChanged.Add(OnMapMinMajorPlayersChanged);
	Events.MultiplayerPrePlayerDisconnected.Add( OnMultiplayerPrePlayerDisconnected );
	Events.GameConfigChanged.Add(OnGameConfigChanged);
	Events.PlayerInfoChanged.Add(OnPlayerInfoChanged);
	Events.GameCoreEventPublishComplete.Add(OnTick)											
	Events.UploadCloudPlayerConfigComplete.Add(OnUploadCloudPlayerConfigComplete);
	Events.ModStatusUpdated.Add(OnModStatusUpdated);
	Events.MultiplayerChat.Add( OnMultiplayerChat );
	Events.MultiplayerGameAbandoned.Add( OnAbandoned );
	Events.MultiplayerGameLaunchFailed.Add( OnMultiplayerGameLaunchFailed );
	Events.LeaveGameComplete.Add( OnLeaveGameComplete );
	Events.BeforeMultiplayerInviteProcessing.Add( OnBeforeMultiplayerInviteProcessing );
	Events.MultiplayerHostMigrated.Add( OnMultiplayerHostMigrated );
	Events.MultiplayerPlayerConnected.Add( OnMultplayerPlayerConnected );
	Events.MultiplayerPingTimesChanged.Add(OnMultiplayerPingTimesChanged);
	Events.SteamFriendsStatusUpdated.Add( UpdateFriendsList );
	Events.SteamFriendsPresenceUpdated.Add( UpdateFriendsList );
	Events.CloudGameKilled.Add(OnCloudGameKilled);
	Events.CloudGameQuit.Add(OnCloudGameQuit);
	


	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.HostGame_ShowStagingRoom.Add( OnRaise );
	LuaEvents.JoiningRoom_ShowStagingRoom.Add( OnRaise );
	LuaEvents.EditHotseatPlayer_UpdatePlayer.Add(UpdatePlayerEntry);
	LuaEvents.Multiplayer_ExitShell.Add( OnHandleExitRequest );

	Controls.TitleLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_STAGING_ROOM")));
	
	g_version = GetLocalModVersion("619ac86e-d99d-4bf3-b8f0-8c5b8c402176")
		
	ResizeButtonToText(Controls.BackButton);
	ResizeButtonToText(Controls.EndGameButton);
	ResizeButtonToText(Controls.QuitGameButton);
	RealizeShellTabs();
	RealizeInfoTabs();
	SetupGridLines(0);
	Resize();
	ResetStatus();

end

Initialize();



