-- ===========================================================================
--	MPH Options
-- ===========================================================================
include("Civ6Common");
include("InstanceManager");
include("PopupDialog");
print("MPH very own In Game option menu")

-- ===========================================================================
--	Variable
-- ===========================================================================
local m_active = false
local b_admin = false
local m_extraTime
local _kPopupDialog:table;


-- Quick utility function to determine if Rise and Fall is installed.
function HasExpansion1()
	local xp1ModId = "1B28771A-C749-434B-9053-D1380C553DE9";
	return Modding.IsModInstalled(xp1ModId);
end

-- Quick utility function to determine if Rise and Fall is installed.
function HasExpansion2()
	local xpModId = "4873eb62-8ccc-4574-b784-dda455e74e68";
	return Modding.IsModInstalled(xpModId);
end

function IsInGame()
	if(GameConfiguration ~= nil) then
		return GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME;
	end
	return false;
end

function OnShow()
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	m_active = true
	ContextPtr:SetHide(false);
	
	if hostID == localID then
		Controls.WindowTitle:SetText(Locale.Lookup("LOC_MPH_ADMIN_OPTIONS"))
		b_admin  = true
		else
		Controls.WindowTitle:SetText(Locale.Lookup("LOC_MPH_PLAYER_OPTIONS"))
	end
	
	SetupButtons()
end

function SetupButtons()
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	local currentTurn = Game.GetCurrentGameTurn()
	local startingTurn = GameConfiguration.GetStartTurn()
	Controls.RemapButton:SetHide(not b_admin)
	Controls.RetimeButton:SetHide(not b_admin)
	Controls.ResyncButton:SetHide(not b_admin)
	Controls.ForceEndButton:SetHide(not b_admin)
	if GameConfiguration.GetValue("GAMEMODE_SUDDEN_DEATH") ~= true then
		Controls.RetimeButton:SetDisabled(true)
	end

	if b_admin == true then
		Controls.RemapButton:RegisterCallback( Mouse.eLClick, OnHostRemap )
		Controls.RetimeButton:RegisterCallback( Mouse.eLClick, OnHostRetime )
	end

	Controls.IrrVoteButton:SetDisabled(true)
	Controls.RemapVoteButton:SetDisabled(true)

	if hostID == localID then
		Controls.RemapVoteButton:RegisterCallback( Mouse.eLClick, OnVoteRemap )
		Controls.RemapVoteButton:SetDisabled(false)
		Controls.ResyncButton:RegisterCallback( Mouse.eLClick, OnHostResync )
		Controls.ResyncButton:SetDisabled(false)
		Controls.ForceEndButton:RegisterCallback( Mouse.eLClick, OnHostForceEnd )
		Controls.ForceEndButton:SetDisabled(false)

		else
		Controls.RemapVoteButton:RegisterCallback( Mouse.eLClick, OnRequestVoteRemap )
		if currentTurn < (GameConfiguration.GetStartTurn()+8) then
			Controls.RemapVoteButton:SetDisabled(false)
		end
		if PlayerConfigurations[localID] ~= nil then
			if PlayerConfigurations[localID]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
				Controls.RemapVoteButton:SetDisabled(false)
			end
		end
	end
	Controls.UIRefreshButton:SetHide(false)
	Controls.UIRefreshButton:RegisterCallback( Mouse.eLClick, OnLocalUIRefresh )
end

-- ===========================================================================
--	Functions
-- ===========================================================================

function OnLocalUIRefresh()
		_kPopupDialog:Close();
		_kPopupDialog:AddTitle(	  Locale.Lookup("LOC_GAME_MENU_UI_REFRESH_TITLE"));
		_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_UI_REFRESH_LABEL"));
		_kPopupDialog:AddButton( Locale.Lookup("LOC_GAME_MENU_UI_REFRESH_BUTTON"), OnLocalUIRefreshValidate );
		_kPopupDialog:AddButton( Locale.Lookup("LOC_CANCEL_BUTTON"), nil );
		_kPopupDialog:Open();
end

function OnLocalUIRefreshValidate()
	print("OnLocalUIRefreshValidate()")
	LuaEvents.InGame_OnLocalUIRefresh()
	OnReturn()
	
end

function OnHostRemap()
	LuaEvents.MPHMenu_OnHostRemap()
	OnReturn()
end

function OnHostForceEnd()
		_kPopupDialog:Close();
		_kPopupDialog:AddTitle(	  Locale.Lookup("LOC_GAME_MENU_FORCEEND_TITLE"));
		_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_FORCEEND_LABEL"));
		_kPopupDialog:AddButton( Locale.Lookup("LOC_GAME_MENU_FORCEEND_BUTTON"), OnHostForceEndValidate );
		_kPopupDialog:AddButton( Locale.Lookup("LOC_CANCEL_BUTTON"), nil );
		_kPopupDialog:Open();
end

function OnHostForceEndValidate()
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs()
	for i, iPlayer in ipairs(player_ids) do
		if Network.IsPlayerConnected(iPlayer) == true and iPlayer ~= hostID then
			Network.SendChat(".mph_ui_forceend_now",-2,iPlayer)
		end
	end
	UI.RequestAction(ActionTypes.ACTION_ENDTURN, { REASON = "UserForced" } );
end

function OnRequestHostForceEnd()
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	if localID ~= hostID then
		Network.SendChat(".mph_ui_log_received_general_request_to_force_endturn",-2,hostID)	
		UI.RequestAction(ActionTypes.ACTION_ENDTURN, { REASON = "UserForced" } );
		print("Turn was force-ended by host")
	end
	OnReturn()
end

function OnHostResync()
		_kPopupDialog:Close();
		_kPopupDialog:AddTitle(	  Locale.Lookup("LOC_GAME_MENU_RESYNC_TITLE"));
		_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_RESYNC_LABEL"));
		_kPopupDialog:AddButton( Locale.Lookup("LOC_GAME_MENU_RESYNC_BUTTON"), OnHostResyncValidate );
		_kPopupDialog:AddButton( Locale.Lookup("LOC_CANCEL_BUTTON"), nil );
		_kPopupDialog:Open();
end

function OnHostResyncValidate()
	print("OnHostResyncValidate()")
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	if (localID == hostID and GameConfiguration.IsPaused() == false) then
		local localPlayerID = localID;
		local localPlayerConfig = PlayerConfigurations[localPlayerID];
		local newPause = not localPlayerConfig:GetWantsPause();
		localPlayerConfig:SetWantsPause(newPause);
		Network.BroadcastPlayerInfo();
	end
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs()
	for i, iPlayer in ipairs(player_ids) do
		if Network.IsPlayerConnected(iPlayer) == true and iPlayer ~= hostID then
			Network.SendChat(".mph_ui_resync_now",-2,iPlayer)
		end
	end

end

function OnRequestHostResync()
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	if localID ~= hostID then
		Network.SendChat(".mph_ui_log_received_general_request_to_resync_to_host",-2,hostID)
	end
	OnReturn()
end

function OnRequestHostResyncSeed()
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	if localID ~= hostID then
		Network.SendChat(".mph_ui_log_received_targetted_request_to_resync_to_host_incorrect_seeds",-2,hostID)
		Network.RequestSnapshot()
		Network.TriggerTestSync()
	end
	OnReturn()
end

function OnHostRetime()
		_kPopupDialog:Close();
		_kPopupDialog:AddTitle(	  Locale.Lookup("LOC_GAME_MENU_RETIME_TITLE"));
		_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_RETIME_LABEL"));
		_kPopupDialog:AddEditBox( Locale.Lookup("LOC_GAME_MENU_RETIME_BOX"), nil, OnHostRetimeEditBox, nil)
		_kPopupDialog:AddButton( Locale.Lookup("LOC_GAME_MENU_RETIME_BUTTON"), OnHostRetimeValidate );
		_kPopupDialog:AddButton( Locale.Lookup("LOC_CANCEL_BUTTON"), nil );
		_kPopupDialog:Open();
end

function OnHostRetimeEditBox(editBox :table)
	m_extraTime = editBox:GetText();
end

function OnHostRetimeValidate()
	print("OnHostRetimeValidate")
	print(m_extraTime)
	if tonumber(m_extraTime) ~= nil then
		if tonumber(m_extraTime) > 0 then
			LuaEvents.MPHMenu_OnHostRetime(tonumber(m_extraTime))
			local hostID = Network.GetGameHostPlayerID()
			local player_ids = GameConfiguration.GetMultiplayerPlayerIDs()
			for i, iPlayer in ipairs(player_ids) do
				if Network.IsPlayerConnected(iPlayer) == true and iPlayer ~= hostID then
					Network.SendChat(".mph_ui_sudden_death_adjust_"..tonumber(m_extraTime),-2,iPlayer)
				end
			end
		end
	end
end

function OnRequestVoteRemap()
	print("OnRequestVoteRemap()")
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	Network.SendChat(".mph_ui_vote_remap_request",-2,-1)
	OnReturn()
end

function OnVoteRemap()
	Network.SendChat(".mph_ui_vote_remap",-2,-1)
	OnReturn()
end

function OnRequestHostVoteRemap()
	print("OnRequestHostVoteRemap()")
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	if localID ~= hostID then
		return
	end
	Network.SendChat(".mph_ui_vote_remap",-2,-1)
	OnReturn()
end

function OnRequestHostSeedCheck(text,sender_id)
	-- prefix is m for Map and g for Game
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	local map_seed = MapConfiguration.GetValue("RANDOM_SEED")
	local game_seed = MapConfiguration.GetValue("GAME_SYNC_RANDOM_SEED")
	
	if hostID ~= localID then
		return
	end
	local seed_type = string.sub(string.lower(text),1,1)
	
	if seed_type == "m" then
		local check_seed = tonumber(string.sub(string.lower(text),2))
		print("Map seed from player "..sender_id.." is: "..tostring(check_seed))
		if check_seed ~= tonumber(map_seed) then
			-- instruct a targetted resync
			Network.SendChat(".mph_ui_resync_seed",-2,sender_id)
			else
			return
		end
	end
	
	if seed_type == "g" then
		local check_seed = tonumber(string.sub(string.lower(text),2))
		print("Game seed from player "..sender_id.." is: "..tostring(check_seed))
		if check_seed ~= tonumber(game_seed) then
			-- instruct a targetted resync
			Network.SendChat(".mph_ui_resync_seed",-2,sender_id)
			else
			return
		end
	end
end

-- ===========================================================================
--	Listening function
-- ===========================================================================

function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
	print(text)
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	local b_ishost = false
	if fromPlayer == Network.GetGameHostPlayerID() then
		b_ishost = true
	end
	
	-- Requesting a VoteMap
	if (string.lower(text) == ".mph_ui_vote_remap_request" and localID == hostID)  then
		OnRequestHostVoteRemap()
		return
	end
	
	-- Requesting a Kick
	
	if ( (string.sub(string.lower(text),1,13) == ".mph_ui_kick_") and localID == hostID)  then
		local kick_id = string.sub(text,14)
		if kick_id ~= nil then
			kick_id = tonumber(kick_id)
			print("Kick UI: Player",kick_id)
			if hostID ~= kick_id then
				Network.KickPlayer(kick_id);
			end
		end
		return
	end
	
	-- Receiving a Seed Check
	
	if ((string.sub(string.lower(text),1,20) == ".mph_ui_checkseed_id") and localID == hostID)  then
		-- Network.SendChat(".mph_ui_checkseed_id_"..tostring(playerID).."_turn_"..g_local_turn.."_seed_"..g_local_seed,-2,hostID)
		-- .mph_ui_checkseed_id_5_turn_2_seed_66
		local indexTurns, indexTurne = string.find(text,"_turn_")
		local indexSeeds, indexSeede = string.find(text,"_seed_")
		local sender_id = string.sub(text,22,indexTurns-1)
		local turn_checked = string.sub(text,indexTurne+1,indexSeeds-1)
		local seed_checked = string.sub(text, indexSeede+1)
		if turn_checked == g_local_turn then
			if seed_checked == g_local_seed then
				print("Seed Check: Player "..tostring(sender_id).." is in sync. State:"..tostring(seed_checked).." Turn:"..tostring(turn_checked))
			else
				print("Seed Check: ERROR Player "..tostring(sender_id).." is out-of-sync. Local State:"..tostring(g_local_seed).." Player State:"..tostring(seed_checked).." Turn:"..tostring(turn_checked))
				local name = PlayerConfigurations[tonumber(sender_id)]
				if name == nil then
					name = "Player "..tostring(sender_id)
					else
					name = tostring(PlayerConfigurations[tonumber(sender_id)]:GetPlayerName())
				end
				Network.SendChat(name.." is out of sync with the host!",-2,-1)
				print("Seed Check: Player Kicked",tonumber(sender_id))
				if hostID ~= tonumber(sender_id) then
					Network.KickPlayer(tonumber(sender_id));
				end
			end
			
		end
		return
	end
	
	-- Requesting a General Resync
	
	if (string.lower(text) == ".mph_ui_resync_now" and fromPlayer == hostID)  then
		OnRequestHostResync()
		return
	end
	
	-- Requesting a General Force End Turn
	
	if (string.lower(text) == ".mph_ui_forceend_now" and fromPlayer == hostID)  then
		OnRequestHostForceEnd()
		return
	end
	
	-- Requesting a Seed Resync
	
	if (string.lower(text) == ".mph_ui_resync_seed" and fromPlayer == hostID)  then
		OnRequestHostResyncSeed()
		return
	end
	
	-- Logging Information
	
	if (string.sub(string.lower(text),1,11) == ".mph_ui_log")  then
		local tmp = tostring(string.sub(text,12))
		print(tmp,"fromPlayer ID: ",fromPlayer)
		return
	end
	
	-- Requesting a Seed Check
	
	if (string.sub(string.lower(text),1,12)== ".mph_ui_seed" and localID == hostID)  then
		local tmp = tostring(string.sub(text,14))
		--OnRequestHostSeedCheck(tmp,fromPlayer)
		return
	end
	
	-- Test
	
	if (string.lower(text)== ".mph_ui_requestsnap" and localID == fromPlayer)  then
		print("Network.RequestSnapshot()",Network.RequestSnapshot())
		return
	end
	
	if (string.lower(text)== ".mph_ui_triggertest" and localID == fromPlayer)  then
		print("Network.TriggerTestSync()",Network.TriggerTestSync())
		return
	end	
	
	if (string.lower(text)== ".mph_ui_forceresync" and localID == fromPlayer)  then
		print("Network.ForceResync()",Network.ForceResync())
		return
	end		
	
	
end

function OnLoadScreenClose()
	print("OnLoadScreenClose()")
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	local map_seed = MapConfiguration.GetValue("RANDOM_SEED")
	local game_seed = MapConfiguration.GetValue("GAME_SYNC_RANDOM_SEED")
	print("m",map_seed,"g",game_seed)
	if hostID ~= localID then
		Network.SendChat(".mph_ui_seed_m"..tostring(map_seed),-2,-1)
		Network.SendChat(".mph_ui_seed_g"..tostring(game_seed),-2,-1)
	end
end

-- ===========================================================================
--	Callback
-- ===========================================================================
function OnShutdown()
	ContextPtr:SetHide(true);
	m_active = false
	LuaEvents.MPHMenu_Click.Remove( OnShow );
	LuaEvents.EscMenu_Show.Remove( OnReturn );
	Events.MultiplayerChat.Remove( OnMultiplayerChat );
	Events.LoadScreenClose.Remove( OnLoadScreenClose );
	
end

function OnReturn()
	ContextPtr:SetHide(true);
	m_active = false
end


-- ===========================================================================
function Initialize()
	ContextPtr:SetShutdown( OnShutdown );
	m_active = false
	ContextPtr:SetHide(true);
	Controls.ReturnButton:RegisterCallback( Mouse.eLClick, OnReturn );
	Controls.ReturnButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	_kPopupDialog = PopupDialog:new( "MPHOptions" );

	LuaEvents.MPHMenu_Click.Add( OnShow );
	LuaEvents.EscMenu_Show.Add( OnReturn );
	Events.MultiplayerChat.Add( OnMultiplayerChat );
	Events.LoadScreenClose.Add( OnLoadScreenClose );

end
Initialize();





