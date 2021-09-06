-------------------------------------------------
-- Multiplayer Host Game Screen
-------------------------------------------------
include("LobbyTypes");		--MPLobbyTypes
include("ButtonUtilities");
include("InstanceManager");
include("PlayerSetupLogic");
include("PopupDialog");
include("Civ6Common");



-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local LOC_GAME_SETUP		:string = Locale.Lookup("LOC_MULTIPLAYER_GAME_SETUP");
local LOC_STAGING_ROOM		:string = Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_STAGING_ROOM"));
local RELOAD_CACHE_ID		:string = "HostGame";

local MIN_SCREEN_Y			:number = 768;
local SCREEN_OFFSET_Y		:number = 20;
local MIN_SCREEN_OFFSET_Y	:number = -93;
--local SCROLL_SIZE_DEFAULT	:number = 620;
--local SCROLL_SIZE_IN_SESSION:number = 662;

-- ===========================================================================
--	Globals
-- ===========================================================================
local m_lobbyModeName:string = MPLobbyTypes.STANDARD_INTERNET;
local m_shellTabIM:table = InstanceManager:new("ShellTab", "TopControl", Controls.ShellTabs);
local m_kPopupDialog:table;
local m_pCityStateWarningPopup:table = PopupDialog:new("CityStateWarningPopup");
local m_InSession = false
local m_Preset = -1;
local b_visible = false;


function OnSetParameterValues(pid: string, values: table)
	local indexed_values = {};
	if(values) then
		for i,v in ipairs(values) do
			indexed_values[v] = true;
		end
	end

	if(g_GameParameters) then
		local parameter = g_GameParameters.Parameters and g_GameParameters.Parameters[pid] or nil;
		if(parameter and parameter.Values ~= nil) then
			local resolved_values = {};
			for i,v in ipairs(parameter.Values) do
				if(indexed_values[v.Value]) then
					table.insert(resolved_values, v);
				end
			end		
			g_GameParameters:SetParameterValue(parameter, resolved_values);
			Network.BroadcastGameConfig();	
		end
	end	
end

-- ===========================================================================
function OnSetParameterValue(pid: string, value: number)
	if(g_GameParameters) then
		local kParameter: table = g_GameParameters.Parameters and g_GameParameters.Parameters[pid] or nil;
		if(kParameter and kParameter.Value ~= nil) then	
            g_GameParameters:SetParameterValue(kParameter, value);
			Network.BroadcastGameConfig();	
		end
	end	
end
-- This driver is for launching a multi-select option in a separate window.
-- ===========================================================================
function CreateMultiSelectWindowDriver(o, parameter, parent)

	if(parent == nil) then
		parent = GetControlStack(parameter.GroupId);
	end
			
	-- Get the UI instance
	local c :object = g_ButtonParameterManager:GetInstance();	

	local parameterId = parameter.ParameterId;
	local button = c.Button;
	button:RegisterCallback( Mouse.eLClick, function()
		LuaEvents.MultiSelectWindow_Initialize(o.Parameters[parameterId]);
		Controls.MultiSelectWindow:SetHide(false);
	end);

	-- Store the root control, NOT the instance table.
	g_SortingMap[tostring(c.ButtonRoot)] = parameter;

	c.ButtonRoot:ChangeParent(parent);
	if c.StringName ~= nil then
		c.StringName:SetText(parameter.Name);
	end

	local cache = {};

	local kDriver :table = {
		Control = c,
		Cache = cache,
		UpdateValue = function(value, p)
			local valueText = value and value.Name or nil;
			local valueAmount :number = 0;
		
			if(valueText == nil) then
				if(value == nil) then
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						valueText = "LOC_SELECTION_EVERYTHING";
					else
						valueText = "LOC_SELECTION_NOTHING";
					end
				elseif(type(value) == "table") then
					local count = #value;
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						if(count == 0) then
							valueText = "LOC_SELECTION_EVERYTHING";
						elseif(count == #p.Values) then
							valueText = "LOC_SELECTION_NOTHING";
						else
							valueText = "LOC_SELECTION_CUSTOM";
							valueAmount = #p.Values - count;
						end
					else
						if(count == 0) then
							valueText = "LOC_SELECTION_NOTHING";
						elseif(count == #p.Values) then
							valueText = "LOC_SELECTION_EVERYTHING";
						else
							valueText = "LOC_SELECTION_CUSTOM";
							valueAmount = count;
						end
					end
				end
			end				

			c.Button:SetToolTipString(parameter.Description);

			if(cache.ValueText ~= valueText) or (cache.ValueAmount ~= valueAmount) then
				local button = c.Button;			
				button:LocalizeAndSetText(valueText, valueAmount);
				cache.ValueText = valueText;
				cache.ValueAmount = valueAmount;
			end
		end,
		UpdateValues = function(values, p) 
			-- Values are refreshed when the window is open.
		end,
		SetEnabled = function(enabled, p)
			c.Button:SetDisabled(not enabled or #p.Values <= 1);
		end,
		SetVisible = function(visible)
			c.ButtonRoot:SetHide(not visible);
		end,
		Destroy = function()
			g_ButtonParameterManager:ReleaseInstance(c);
		end,
	};	

	return kDriver;
end

-- ===========================================================================
-- This driver is for launching the city-state picker in a separate window.
-- ===========================================================================
function CreateCityStatePickerDriver(o, parameter, parent)

	if(parent == nil) then
		parent = GetControlStack(parameter.GroupId);
	end
			
	-- Get the UI instance
	local c :object = g_ButtonParameterManager:GetInstance();	

	local parameterId = parameter.ParameterId;
	local button = c.Button;
	button:RegisterCallback( Mouse.eLClick, function()
		LuaEvents.CityStatePicker_Initialize(o.Parameters[parameterId], g_GameParameters);
		Controls.CityStatePicker:SetHide(false);
	end);

	-- Store the root control, NOT the instance table.
	g_SortingMap[tostring(c.ButtonRoot)] = parameter;

	c.ButtonRoot:ChangeParent(parent);
	if c.StringName ~= nil then
		c.StringName:SetText(parameter.Name);
	end

	local cache = {};

	local kDriver :table = {
		Control = c,
		Cache = cache,
		UpdateValue = function(value, p)
			local valueText = value and value.Name or nil;
			local valueAmount :number = 0;
		
			if(valueText == nil) then
				if(value == nil) then
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						valueText = "LOC_SELECTION_EVERYTHING";
					else
						valueText = "LOC_SELECTION_NOTHING";
					end
				elseif(type(value) == "table") then
					local count = #value;
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						if(count == 0) then
							valueText = "LOC_SELECTION_EVERYTHING";
						elseif(count == #p.Values) then
							valueText = "LOC_SELECTION_NOTHING";
						else
							valueText = "LOC_SELECTION_CUSTOM";
							valueAmount = #p.Values - count;
						end
					else
						if(count == 0) then
							valueText = "LOC_SELECTION_NOTHING";
						elseif(count == #p.Values) then
							valueText = "LOC_SELECTION_EVERYTHING";
						else
							valueText = "LOC_SELECTION_CUSTOM";
							valueAmount = count;
						end
					end
				end
			end				

			c.Button:SetToolTipString(parameter.Description);

			if(cache.ValueText ~= valueText) or (cache.ValueAmount ~= valueAmount) then
				local button = c.Button;			
				button:LocalizeAndSetText(valueText, valueAmount);
				cache.ValueText = valueText;
				cache.ValueAmount = valueAmount;
			end
		end,
		UpdateValues = function(values, p) 
			-- Values are refreshed when the window is open.
		end,
		SetEnabled = function(enabled, p)
			c.Button:SetDisabled(not enabled or #p.Values <= 1);
		end,
		SetVisible = function(visible)
			c.ButtonRoot:SetHide(not visible);
		end,
		Destroy = function()
			g_ButtonParameterManager:ReleaseInstance(c);
		end,
	};	

	return kDriver;
end

-- ===========================================================================
-- This driver is for launching the leader picker in a separate window.
-- ===========================================================================
function CreateLeaderPickerDriver(o, parameter, parent)

	if(parent == nil) then
		parent = GetControlStack(parameter.GroupId);
	end
			
	-- Get the UI instance
	local c :object = g_ButtonParameterManager:GetInstance();	

	local parameterId:string = parameter.ParameterId;
	local button:table = c.Button;
	button:RegisterCallback( Mouse.eLClick, function()
		LuaEvents.LeaderPicker_Initialize(o.Parameters[parameterId], g_GameParameters);
		Controls.LeaderPicker:SetHide(false);
	end);
	button:SetToolTipString(parameter.Description);

	-- Store the root control, NOT the instance table.
	g_SortingMap[tostring(c.ButtonRoot)] = parameter;

	c.ButtonRoot:ChangeParent(parent);
	if c.StringName ~= nil then
		c.StringName:SetText(parameter.Name);
	end

	local cache:table = {};

	local kDriver :table = {
		Control = c,
		Cache = cache,
		UpdateValue = function(value, p)
			local valueText = value and value.Name or nil;
			local valueAmount :number = 0;

			-- Remove random leaders from the Values table that is used to determine number of leaders selected
			for i = #p.Values, 1, -1 do
				local kItem:table = p.Values[i];
				if kItem.Value == "RANDOM" or kItem.Value == "RANDOM_POOL1" or kItem.Value == "RANDOM_POOL2" then
					table.remove(p.Values, i);
				end
			end
		
			if(valueText == nil) then
				if(value == nil) then
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						valueText = "LOC_SELECTION_EVERYTHING";
					else
						valueText = "LOC_SELECTION_NOTHING";
					end
				elseif(type(value) == "table") then
					local count = #value;
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						if(count == 0) then
							valueText = "LOC_SELECTION_EVERYTHING";
						elseif(count == #p.Values) then
							valueText = "LOC_SELECTION_NOTHING";
						else
							valueText = "LOC_SELECTION_CUSTOM";
							valueAmount = #p.Values - count;
						end
					else
						if(count == 0) then
							valueText = "LOC_SELECTION_NOTHING";
						elseif(count == #p.Values) then
							valueText = "LOC_SELECTION_EVERYTHING";
						else
							valueText = "LOC_SELECTION_CUSTOM";
							valueAmount = count;
						end
					end
				end
			end				

			if(cache.ValueText ~= valueText) or (cache.ValueAmount ~= valueAmount) then
				local button:table = c.Button;			
				button:LocalizeAndSetText(valueText, valueAmount);
				cache.ValueText = valueText;
				cache.ValueAmount = valueAmount;
			end
		end,
		UpdateValues = function(values, p) 
			-- Values are refreshed when the window is open.
		end,
		SetEnabled = function(enabled, p)
			c.Button:SetDisabled(not enabled or #p.Values <= 1);
		end,
		SetVisible = function(visible)
			c.ButtonRoot:SetHide(not visible);
		end,
		Destroy = function()
			g_ButtonParameterManager:ReleaseInstance(c);
		end,
	};	

	return kDriver;
end																			  
function GameParameters_UI_CreateParameterDriver(o, parameter, parent, ...)
	if(parameter.ParameterId == "CityStates") then
		return CreateCityStatePickerDriver(o, parameter);
	elseif(parameter.ParameterId == "LeaderPool1" or parameter.ParameterId == "LeaderPool2") then
	return CreateLeaderPickerDriver(o, parameter);																						  
	elseif(parameter.Array) then
		return CreateMultiSelectWindowDriver(o, parameter);
	else
		return GameParameters_UI_DefaultCreateParameterDriver(o, parameter, parent, ...);
	end
end

-- The method used to create a UI control associated with the parameter.
-- Returns either a control or table that will be used in other parameter view related hooks.
function GameParameters_UI_CreateParameter(o, parameter)
	local func = g_ParameterFactories[parameter.ParameterId];

	local control;
	if(func)  then
		control = func(o, parameter);
	else
		control = GameParameters_UI_CreateParameterDriver(o, parameter);
	end

	o.Controls[parameter.ParameterId] = control;
end

-- ===========================================================================
-- Perform validation on setup parameters.
-- ===========================================================================
function UI_PostRefreshParameters()
	-- Most of the options self-heal due to the setup parameter logic.
	-- However, player options are allowed to be in an 'invalid' state for UI
	-- This way, instead of hiding/preventing the user from selecting an invalid player
	-- we can allow it, but display an error message explaining why it's invalid.

	-- This is ily used to present ownership errors and custom constraint errors.
	Controls.SaveConfigButton:SetDisabled(false);
	Controls.ConfirmButton:SetDisabled(false);
	Controls.ConfirmButton:SetToolTipString(nil);

	local game_err = GetGameParametersError();
	if(game_err) then
		Controls.SaveConfigButton:SetDisabled(true);
		Controls.ConfirmButton:SetDisabled(true);
		Controls.ConfirmButton:LocalizeAndSetToolTip("LOC_SETUP_PARAMETER_ERROR");

	end
end

-- ===========================================================================
--	Input Handler
-- ===========================================================================
function OnInputHandler( uiMsg, wParam, lParam )
	if uiMsg == KeyEvents.KeyUp then
		if wParam == Keys.VK_ESCAPE then
			LuaEvents.Multiplayer_ExitShell();
		end
	end
	return true;
end

-- ===========================================================================
function Refresh()
	local isInSession:boolean = Network.IsInSession();
	if m_InSession == false and isInSession == true then
	-- Refresh the mod list
	
	local enabledMods = GameConfiguration.GetEnabledMods();
	local bMods = false
	for _, curMod in ipairs(enabledMods) do
		if curMod.Id == "c88cba8b-8311-4d35-90c3-51a4a5d6654f" then
			bMods = true
		end													 	 
	end
	if bMods == false and GameConfiguration.GetValue("SpawnRecalculation") == true then
		local r = math.random()
		if r < 0.1 then
			GameConfiguration.SetValue("SpawnRecalculation",false)
		end
	end
	end
end


function OnShow()
	CheckPreset()
	RebuildPlayerParameters(true);
	GameSetup_RefreshParameters();
	Refresh()

	-- Hide buttons if we're already in a game
	local isInSession:boolean = Network.IsInSession();
	Controls.ModsButton:SetHide(isInSession);
	Controls.ConfirmButton:SetHide(isInSession);
	
	ShowDefaultButton();
	ShowLoadConfigButton();
	Controls.LoadButton:SetHide(not GameConfiguration.IsHotseat() or isInSession);
	Controls.RefreshConfigButton:SetHide(not isInSession);
	--[[
	local sizeY:number = isInSession and SCROLL_SIZE_IN_SESSION or SCROLL_SIZE_DEFAULT;
	Controls.DecoGrid:SetSizeY(sizeY);
	Controls.DecoBorder:SetSizeY(sizeY + 6);
	Controls.ParametersScrollPanel:SetSizeY(sizeY - 2);
	--]]

	RealizeShellTabs();
end

-- ===========================================================================
function ShowDefaultButton()
	local showDefaultButton = not GameConfiguration.IsSavedGame()
								and not Network.IsInSession();

	Controls.DefaultButton:SetHide(not showDefaultButton);
end

function ShowLoadConfigButton()
	local showLoadConfig = not GameConfiguration.IsSavedGame()
								and not Network.IsInSession();

	Controls.LoadConfigButton:SetHide(not showLoadConfig);
end

-- ===========================================================================
function OnHide( isHide, isInit )
	b_visible = false
	ReleasePlayerParameters();
	HideGameSetup();
end

-------------------------------------------------
-- Restore Default Settings Button Handler
-------------------------------------------------
function OnDefaultButton()
	print("Resetting Setup Parameters");

	-- Get the game name since we wish to persist this.
	local gameMode = GameModeTypeForMPLobbyType(m_lobbyModeName);
	local gameName = GameConfiguration.GetValue("GAME_NAME");
	GameConfiguration.SetToDefaults(gameMode);
	GameConfiguration.RegenerateSeeds();

	-- Kludge:  SetToDefaults assigns the ruleset to be standard.
	-- Clear this value so that the setup parameters code can guess the best 
	-- default.
	GameConfiguration.SetValue("RULESET", nil);
	
	-- Only assign GAME_NAME if the value is valid.
	if(gameName and #gameName > 0) then
		GameConfiguration.SetValue("GAME_NAME", gameName);
	end
	return GameSetup_RefreshParameters();
end

-------------------------------------------------------------------------------
-- Event Listeners
-------------------------------------------------------------------------------
Events.FinishedGameplayContentConfigure.Add(function(result)
	if(ContextPtr and not ContextPtr:IsHidden() and result.Success) then
		GameSetup_RefreshParameters();
		Refresh();
	end
end);

-------------------------------------------------
-- Mods Setting Button Handler
-- TODO: Remove this, and place contents mods screen into the ParametersStack (in the SecondaryParametersStack, or in its own ModsStack)
-------------------------------------------------
function ModsButtonClick()
	UIManager:QueuePopup(Controls.ModsMenu, PopupPriority.Current);	
end


-- ===========================================================================
--	Host Game Button Handler
-- ===========================================================================
function OnConfirmClick()
	-- UINETTODO - Need to be able to support coming straight to this screen as a dedicated server
	--SERVER_TYPE_STEAM_DEDICATED,	// Steam Game Server, host does not play.

	local serverType = ServerTypeForMPLobbyType(m_lobbyModeName);
	print("OnConfirmClick() m_lobbyModeName: " .. tostring(m_lobbyModeName) .. " serverType: " .. tostring(serverType));
	
	-- GAME_NAME must not be empty.
	local gameName = GameConfiguration.GetValue("GAME_NAME");	
	if(gameName == nil or #gameName == 0) then
		GameConfiguration.SetToDefaultGameName();
	end
	
	if AreNoCityStatesInGame() or AreAllCityStateSlotsUsed() then
		HostGame(serverType);
	else
		m_pCityStateWarningPopup:ShowOkCancelDialog(Locale.Lookup("LOC_CITY_STATE_PICKER_TOO_FEW_WARNING"), function() HostGame(serverType); end);
	end
end

-- ===========================================================================
function HostGame(serverType:number)
	Network.HostGame(serverType);
end

-- ===========================================================================
function AreNoCityStatesInGame()
	local kParameters:table = g_GameParameters["Parameters"];
	return (kParameters["CityStates"] == nil);
end

-- ===========================================================================
function AreAllCityStateSlotsUsed()
	
	local kParameters		:table = g_GameParameters["Parameters"];
	local cityStateSlots	:number = kParameters["CityStateCount"].Value;
	local totalCityStates	:number = #kParameters["CityStates"].AllValues;
	local excludedCityStates:number = kParameters["CityStates"].Value ~= nil and #kParameters["CityStates"].Value or 0;

	if (totalCityStates - excludedCityStates) < cityStateSlots then
		return false;
	end

	return true;
end

-------------------------------------------------
-- Refresh Game Seeds
-------------------------------------------------
function OnRefreshConfig()
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	if hostID == localID then
		local map_seed = MapConfiguration.GetValue("RANDOM_SEED")
		local game_seed = GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED")
		local rng = math.random()*100000
		rng = math.floor(rng)
		if map_seed ~= nil and tonumber(map_seed) ~= nil then
			map_seed = tonumber(map_seed)+rng
			else
			map_seed = rng
		end
		game_seed = map_seed - 1
		GameConfiguration.SetValue("GAME_SYNC_RANDOM_SEED",game_seed)
		MapConfiguration.SetValue("RANDOM_SEED",map_seed)
		Network.BroadcastGameConfig();
		Network.BroadcastPlayerInfo();
		print("OnRefreshConfig(): Seeds refreshed",map_seed,game_seed)
		else
		print("OnRefreshConfig(): Not the Host")
	end
end



-------------------------------------------------
-- Load Configuration Button Handler
-------------------------------------------------
function OnLoadConfig()
	local serverType = ServerTypeForMPLobbyType(m_lobbyModeName);
	LuaEvents.HostGame_SetLoadGameServerType(serverType);
	local kParameters = {};
	kParameters.FileType = SaveFileTypes.GAME_CONFIGURATION;
	UIManager:QueuePopup(Controls.LoadGameMenu, PopupPriority.Current, kParameters);
end

-------------------------------------------------
-- Load Configuration Button Handler
-------------------------------------------------
function OnSaveConfig()
	local kParameters = {};
	kParameters.FileType = SaveFileTypes.GAME_CONFIGURATION;
	UIManager:QueuePopup(Controls.SaveGameMenu, PopupPriority.Current, kParameters);
end

function OnAbandoned(eReason)
	if (not ContextPtr:IsHidden()) then

		-- We need to CheckLeaveGame before triggering the reason popup because the reason popup hides the host game screen.
		-- and would block the leave game incorrectly.  This fixes TTP 22192.  See CheckLeaveGame() in stagingroom.lua.
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
		LuaEvents.Multiplayer_ExitShell();
	end
end

function CheckLeaveGame()
	-- Leave the network session if we're in a state where the host game should be triggering the exit.
	if not ContextPtr:IsHidden()	-- If the screen is not visible, this exit might be part of a general UI state change (like Multiplayer_ExitShell)
									-- and should not trigger a game exit.
		and Network.IsInSession()	-- Still in a network session.
		and not Network.IsInGameStartedState() then -- Don't trigger leave game if we're being used as an ingame screen. Worldview is handling this instead.
		print("HostGame::CheckLeaveGame() leaving the network session.");																   
		Network.LeaveGame();
	end
end

-- ===========================================================================
-- Event Handler: LeaveGameComplete
-- ===========================================================================
function OnLeaveGameComplete()
	-- We just left the game, we shouldn't be open anymore.
	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
-- Event Handler: BeforeMultiplayerInviteProcessing
-- ===========================================================================
function OnBeforeMultiplayerInviteProcessing()
	-- We're about to process a game invite.  Get off the popup stack before we accidently break the invite!
	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
-- Event Handler: ChangeMPLobbyMode
-- ===========================================================================
function OnChangeMPLobbyMode(newLobbyMode)
	m_lobbyModeName = newLobbyMode;
end

-- ===========================================================================
function RealizeShellTabs()
	m_shellTabIM:ResetInstances();

	local gameSetup:table = m_shellTabIM:GetInstance();
	gameSetup.Button:SetText(LOC_GAME_SETUP);
	gameSetup.SelectedButton:SetText(LOC_GAME_SETUP);
	gameSetup.Selected:SetHide(false);

	AutoSizeGridButton(gameSetup.Button,250,32,10,"H");
	AutoSizeGridButton(gameSetup.SelectedButton,250,32,20,"H");
	gameSetup.TopControl:SetSizeX(gameSetup.Button:GetSizeX());

	if Network.IsInSession() then
		local stagingRoom:table = m_shellTabIM:GetInstance();
		stagingRoom.Button:SetText(LOC_STAGING_ROOM);
		stagingRoom.SelectedButton:SetText(LOC_STAGING_ROOM);
		stagingRoom.Button:RegisterCallback( Mouse.eLClick, function() LuaEvents.HostGame_ShowStagingRoom() end );
		stagingRoom.Selected:SetHide(true);

		AutoSizeGridButton(stagingRoom.Button,250,32,20,"H");
		AutoSizeGridButton(stagingRoom.SelectedButton,250,32,20,"H");
		stagingRoom.TopControl:SetSizeX(stagingRoom.Button:GetSizeX());
	end

	Controls.ShellTabs:CalculateSize();
	Controls.ShellTabs:ReprocessAnchoring();
end

-------------------------------------------------
-- Leave the screen
-------------------------------------------------
function HandleExitRequest()
	-- Check to see if the screen needs to also leave the network session.
	CheckLeaveGame();

	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================
function OnRaiseHostGame()
	-- "Raise" means the host game screen is being shown for a fresh game.  Game configuration need to be defaulted.
	local gameMode = GameModeTypeForMPLobbyType(m_lobbyModeName);
	GameConfiguration.SetToDefaults(gameMode);

	-- Kludge:  SetToDefaults assigns the ruleset to be standard.
	-- Clear this value so that the setup parameters code can guess the best 
	-- default.
	GameConfiguration.SetValue("RULESET", nil);

	UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
end

-- ===========================================================================
function OnEnsureHostGame()
	-- "Ensure" means the host game screen needs to be shown for a game in progress (don't default game configuration).
	if ContextPtr:IsHidden() then
		UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
	end
end

-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues( RELOAD_CACHE_ID );
	end
end

-- ===========================================================================
function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isHidden", ContextPtr:IsHidden());
	LuaEvents.MultiSelectWindow_SetParameterValues.Remove(OnSetParameterValues);
	LuaEvents.CityStatePicker_SetParameterValues.Remove(OnSetParameterValues);
	LuaEvents.CityStatePicker_SetParameterValue.Remove(OnSetParameterValue);																		 
	LuaEvents.LeaderPicker_SetParameterValues.Remove(OnSetParameterValues);																	
end

-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context == RELOAD_CACHE_ID and contextTable["isHidden"] == false then
		UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
	end	
end

-- ===========================================================================
-- Load Game Button Handler
-- ===========================================================================
function LoadButtonClick()
	local serverType = ServerTypeForMPLobbyType(m_lobbyModeName);
	LuaEvents.HostGame_SetLoadGameServerType(serverType);
	UIManager:QueuePopup(Controls.LoadGameMenu, PopupPriority.Current);	
end

-- ===========================================================================
function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	if(screenY >= MIN_SCREEN_Y + (Controls.LogoContainer:GetSizeY()+ Controls.LogoContainer:GetOffsetY() * 2)) then
		Controls.MainWindow:SetSizeY(screenY-(Controls.LogoContainer:GetSizeY() + Controls.LogoContainer:GetOffsetY() * 2));
		Controls.DecoBorder:SetSizeY(SCREEN_OFFSET_Y + Controls.MainWindow:GetSizeY()-(Controls.BottomButtonStack:GetSizeY() + Controls.LogoContainer:GetSizeY()));
	else
		Controls.MainWindow:SetSizeY(screenY);
		Controls.DecoBorder:SetSizeY(MIN_SCREEN_OFFSET_Y + Controls.MainWindow:GetSizeY()-(Controls.BottomButtonStack:GetSizeY()));
	end
	Controls.MainGrid:ReprocessAnchoring();
end

-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
	Resize();
  end
end

-- ===========================================================================
function OnExitGame()
	m_InSession = false
	LuaEvents.Multiplayer_ExitShell();
end

-- ===========================================================================
function Default_Natural_Wonders()
	local default = {}
	default = {
				"FEATURE_BARRINGER_CRATER",
				"FEATURE_BIOLUMINESCENT_BAY",
				"FEATURE_CERRO_DE_POTOSI",
				"FEATURE_DALLOL",
				"FEATURE_GRAND_MESA",
				"FEATURE_KRAKATOA",
				"FEATURE_LAKE_VICTORIA",
				"FEATURE_LENCOIS_MARANHENSES",
				"FEATURE_OUNIANGA",
				"FEATURE_MOSI_OA_TUNYA",
				"FEATURE_MOTLATSE_CANYON",
				"FEATURE_KAILASH",
				"FEATURE_NAMIB",
				"FEATURE_OLD_FAITHFUL",			
				"FEATURE_SINAI",
				"FEATURE_SALAR_DE_UYUNI",
				"FEATURE_WULINGYUAN",	
				"FEATURE_SALAR_DE_UYUNI",
				"FEATURE_SRI_PADA",
				"FEATURE_GIBRALTAR",					
				"FEATURE_VREDEFORT_DOME"
				}
	GameConfiguration.SetValue("EXCLUDE_NATURAL_WONDERS",default)
end

function Squadron_Natural_Wonders()
	local default = {}
	default = {
				"FEATURE_LYSEFJORDEN",
				"FEATURE_GIANTS_CAUSEWAY"
				}
	GameConfiguration.SetValue("EXCLUDE_NATURAL_WONDERS",default)
end

function CheckPreset()
	local currentPreset = GameConfiguration.GetValue("MPH_PRESET")
	print("CheckPreset()",currentPreset,m_Preset,isInSession)
	if currentPreset == nil then
		return
	end
	
	if m_Preset ~= currentPreset then
		if m_Preset == -1 then
			Default_Natural_Wonders()
		end
		-- None
		if currentPreset == 0 then
			print("Applied Default Settings")
			Default_Natural_Wonders()
		end
		-- CWC
		if currentPreset == 1 then
			print("Applied CWC Settings")
			Default_Natural_Wonders()
		end
		-- FFA
		if currentPreset == 2 then
			print("Applied Default Settings")
			Default_Natural_Wonders()
		end
		-- Squadron
		if currentPreset == 3 then
			print("Applied Squadron Settings")
			Squadron_Natural_Wonders()
		end	
		Network.BroadcastGameConfig();	
		OnUpdateUI()
	end
	
	m_Preset = currentPreset

end


-- ===========================================================================
function OnExitGameAskAreYouSure()
	if Network.IsInSession() then
		if (not m_kPopupDialog:IsOpen()) then
			m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_QUIT_WARNING"));
			m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
			m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnExitGame, nil, nil, "PopupButtonInstanceRed" );
			m_kPopupDialog:Open();
		end
	else
		OnExitGame();
	end
end

-- ===========================================================================
function Initialize()
	
	CheckPreset()
	Events.SystemUpdateUI.Add(OnUpdateUI);

	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler(OnInputHandler);
	ContextPtr:SetShowHandler(OnShow);
	ContextPtr:SetHideHandler(OnHide);

	Controls.DefaultButton:RegisterCallback( Mouse.eLClick, OnDefaultButton);
	Controls.LoadConfigButton:RegisterCallback( Mouse.eLClick, OnLoadConfig);
	Controls.SaveConfigButton:RegisterCallback( Mouse.eLClick, OnSaveConfig);
	Controls.RefreshConfigButton:RegisterCallback( Mouse.eLClick, OnRefreshConfig );
	Controls.ConfirmButton:RegisterCallback( Mouse.eLClick, OnConfirmClick );
	Controls.ModsButton:RegisterCallback( Mouse.eLClick, ModsButtonClick );

	Events.MultiplayerGameAbandoned.Add( OnAbandoned );
	Events.LeaveGameComplete.Add( OnLeaveGameComplete );
	Events.BeforeMultiplayerInviteProcessing.Add( OnBeforeMultiplayerInviteProcessing );
	Events.GameConfigChanged.Add(CheckPreset);
	
	LuaEvents.ChangeMPLobbyMode.Add( OnChangeMPLobbyMode );
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.Lobby_RaiseHostGame.Add( OnRaiseHostGame );
	LuaEvents.MainMenu_RaiseHostGame.Add( OnRaiseHostGame );
	LuaEvents.Multiplayer_ExitShell.Add( HandleExitRequest );
	LuaEvents.StagingRoom_EnsureHostGame.Add( OnEnsureHostGame );
	LuaEvents.Mods_UpdateHostGameSettings.Add(GameSetup_RefreshParameters);		-- TODO: Remove when mods are managed by this screen

	LuaEvents.MultiSelectWindow_SetParameterValues.Add(OnSetParameterValues);
	LuaEvents.CityStatePicker_SetParameterValues.Add(OnSetParameterValues);																		
	LuaEvents.CityStatePicker_SetParameterValue.Add(OnSetParameterValue);																	  
	LuaEvents.LeaderPicker_SetParameterValues.Add(OnSetParameterValues);																 
	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnExitGameAskAreYouSure);
	Controls.LoadButton:RegisterCallback( Mouse.eLClick, LoadButtonClick );


	ResizeButtonToText( Controls.DefaultButton );
	ResizeButtonToText( Controls.BackButton );
	Resize();

	-- Custom popup setup	
	m_kPopupDialog = PopupDialog:new( "InGameTopOptionsMenu" );
end
Initialize();