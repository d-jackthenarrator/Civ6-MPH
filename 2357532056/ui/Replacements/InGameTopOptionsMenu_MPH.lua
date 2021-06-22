-- Copyright 2017-2019, Firaxis Games
------------------------------------------------------------------------------
--	FILE:	 InGameTopOptionsMenu_MPH.lua
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: UI - Esc Main Menu
-------------------------------------------------------------------------------
include( "InGameTopOptionsMenu" );

-- ===========================================================================
--	OVERRIDES
-- ===========================================================================
BASE_LateInitialize = LateInitialize;
BASE_OnYes = OnYes
BASE_SetupButtons = SetupButtons
local g_cached_playerIDs = {}
local ms_ExitToMain		: boolean = true;
local m_isSimpleMenu	: boolean = false;
local m_isLoadingDone   : boolean = false;
local m_isRetired		: boolean = false;
local m_isEndGameOpen	: boolean = false;
local m_isNeedRestoreOptions		: boolean = false;
local m_isNeedRestoreSaveGameMenu	: boolean = false;
local m_isNeedRestoreLoadGameMenu	: boolean = false;
local m_isClosing		: boolean = false;
local m_kPopupDialog	: table;			-- Custom due to Utmost popup status
-- ===========================================================================
function OnExpansionIntro()
	Controls.PauseWindow:SetHide(true);
	LuaEvents.InGameTopOptionsMenu_ShowExpansionIntro();
end


-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function SetupButtons()
	local localID = Network.GetLocalPlayerID()
	LuaEvents.EscMenu_Show()
	
	BASE_SetupButtons();
	
	local bWorldBuilder = WorldBuilder and WorldBuilder:IsActive();
	local bIsMultiplayer = GameConfiguration.IsAnyMultiplayer();
	local bIsCloud = GameConfiguration.IsPlayByCloud()
	-- Eventually remove this check.  Retiring after winning is perfectly fine
	-- so long as we update the tooltip to no longer state the player will be defeated.
	local bAlreadyWon = false;
	local me = Game.GetLocalPlayer();
	if(me) then
		local localPlayer = Players[me];
		if(localPlayer) then
			if(Game.GetWinningTeam() == localPlayer:GetTeam()) then
				bAlreadyWon = true;
			end
		end
	end
	Controls.RetireButton:SetHide(bIsAutomation or bIsCloud or bAlreadyWon or bWorldBuilder)
	if bIsMultiplayer == true then
		Controls.RetireButton:ClearCallback( Mouse.eLClick )
		Controls.RetireButton:RegisterCallback( Mouse.eLClick, OnConcedeCheck );
	end
	if PlayerConfigurations[localID] ~= nil then
		if PlayerConfigurations[localID]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
			Controls.RetireButton:SetHide(true)
		end
	end
	Controls.MainStack:CalculateSize();
end


function LateInitialize()	
	BASE_LateInitialize();
	CreateTeamList()
	Events.MultiplayerChat.Add( OnMultiplayerChat );
	
	local isWorldBuilder :boolean = WorldBuilder and WorldBuilder:IsActive();
	if (isWorldBuilder) then
		Controls.ExpansionNewFeatures:SetHide(true);
		Controls.HelperButton:SetHide(true);
		else
		Controls.ExpansionNewFeatures:SetHide(false);
		Controls.ExpansionNewFeatures:RegisterCallback( Mouse.eLClick, OnExpansionIntro );
		Controls.ExpansionNewFeatures:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		
		Controls.HelperButton:SetHide(false);
		Controls.HelperButton:RegisterCallback( Mouse.eLClick, OnHelper );
		Controls.HelperButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	end
	
end

-- ===========================================================================
function CreateTeamList()
	local bIsMultiplayer = GameConfiguration.IsAnyMultiplayer();
	
	if bIsMultiplayer == false then
		return
	end
	
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs()
	local count = 0
	for i, iPlayer in ipairs(player_ids) do
		if Players[iPlayer] ~= nil then
		local tmp = {}
		local name = PlayerConfigurations[iPlayer]:GetPlayerName()
		local id = iPlayer
		local team = Players[iPlayer]:GetTeam()
		local status = -1
		if PlayerConfigurations[iPlayer]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
			status = -7
			elseif Players[iPlayer]:IsAlive() == false then
			status = -3
			elseif Players[iPlayer]:IsMajor() == false then
			status = -4
			elseif Network.IsPlayerConnected(iPlayer) == false then
			status = -2
			else
			status = 0
		end
		local namestr = Locale.Lookup(name)
		if string.len(namestr) > 12 then
			namestr = string.sub(namestr,1,11).."."
		end
		tmp = { ID = id, Team = team, Status = status, Name = namestr }
		if status ~= -4 then
			table.insert(g_cached_playerIDs,tmp)	
			count = count + 1
		end
		end
	end
	
	if count > 0 then
		local sort_func = function( a,b ) return a.Team < b.Team end
		table.sort( g_cached_playerIDs, sort_func )
	end
end


-- ============================================================================
function OnYes( )

	if(ms_ExitToMain) then
		Network.SendChat(".manual_disconnect_main_menu", -2,-1)	
	else
		Network.SendChat(".manual_disconnect_desktop", -2,-1)	
	end
	
	BASE_OnYes()
end

-- ===========================================================================
function OnHelper()
	LuaEvents.MPHMenu_Click()
	Controls.PauseWindow:SetHide(true);
	Close()
end

function OnConcedeCheck()
	if m_kPopupDialog == nil then
		m_kPopupDialog = PopupDialog:new( "EndGameMenu" );
	end
	if (not m_kPopupDialog:IsOpen()) then
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_RETIRE_WARNING"));
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnConcede, nil, nil, "PopupButtonInstanceRed" );
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), OnNotConcede, nil, nil );
		m_kPopupDialog:Open();
	end
end

function OnConcede()
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	if hostID == localID then -- Host is conceeding
		-- Host Directly trigger the EndGameMenu Locally
		HostConcedeControl(hostID)
		else -- Let the Host Know
		Network.SendChat(".mph_ui_triger_concede",-2,hostID)
	end
end

function OnNotConcede()
	print("OnNotConcede")
	print(Input.GetActiveContext())
	OnShow()
end

function OnConcedeRemotely()
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	CloseImmediately();
	LuaEvents.MPHMenu_Concede()
end

function OnConcedeWinRemotely()
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	CloseImmediately();
	LuaEvents.MPHMenu_ConcedeWin()
end

function HostConcedeControl(losingID:number)
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	local losingTeam = Players[losingID]:GetTeam()
	if hostID == localID then
		for i, player in ipairs(g_cached_playerIDs) do
			if Players[player.ID] ~= nil then
				if player.Status > -1 and player.ID ~= hostID and player.Team == losingTeam then
					Network.SendChat(".mph_ui_concede_loss",-2,player.ID)
				end
				if player.Status > -1 and player.ID == hostID and player.Team == losingTeam then
					-- Host is on losing team
					OnConcedeRemotely()
				end
			end
		end
		local count = 0
		local otherTeam = -66
		for i, player in ipairs(g_cached_playerIDs) do
			if Players[player.ID] ~= nil then
				if player.Status > -1 and player.Team ~= losingTeam and player.Team ~= otherTeam then
					count = count + 1
					otherTeam = player.Team
				end
			end
		end
		-- There is only one other team so they must be the winners !
		if count == 1 or count == 0 then
			for i, player in ipairs(g_cached_playerIDs) do
				if Players[player.ID] ~= nil then
					if ((player.Status > -1 and player.Team == otherTeam) or player.Status == -7) then
						if player.ID ~= hostID then
							Network.SendChat(".mph_ui_concede_win",-2,player.ID)
						end
					end
					if player.ID == hostID and (player.Status == -7 or (player.Status > -1 and player.Team == otherTeam and player.Team ~= losingTeam)) then
						-- Host is on the winning team
						OnConcedeWinRemotely()
					end
				end
			end	
		end	
		else
		return
	end
end

-- ===========================================================================
--	Listening function
-- ===========================================================================

function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	local b_ishost = false
	if fromPlayer == Network.GetGameHostPlayerID() then
		b_ishost = true
	end
	
	-- Triggering a Concede
	
	if string.lower(text) == ".mph_ui_triger_concede" then
		HostConcedeControl( fromPlayer )
		return
	end
	
	if string.lower(text) == "gg" and localID == fromPlayer then
		LuaEvents.InGame_OpenInGameOptionsMenu();
		OnConcedeCheck()
		return
	end
	
	if string.lower(text) == ".mph_ui_concede_loss" and b_ishost == true and toPlayer == localID then
		OnConcedeRemotely()
		return
	end
	
	if string.lower(text) == ".mph_ui_concede_win" and b_ishost == true and toPlayer == localID then
		OnConcedeWinRemotely()
		return
	end
	
end
