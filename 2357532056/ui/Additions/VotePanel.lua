-- Copyright 2016-2019, Firaxis Games
-- (Multiplayer) Pause Panel
include("PopupPriorityLoader_", true);
include("InstanceManager");
include("PopupDialog");
include( "PlayerSetupLogic" );
include( "GameSetupLogic" );
print("MPH Remap Panel")

-- ===========================================================================
--	Variables
-- ===========================================================================
local _kPopupDialog	: table;			-- Custom due to Utmost popup status
local m_votetype = -1 -- 0 is remap
local m_roletype = -1
local m_forced = false
local b_remap_passed = false
local b_remap_armed = false
local b_remap_armed_ui = false
local b_HasSavedSeeds = false
local g_cached_playerIDs = {} -- keep a track of who has voted on which team
-- timer variables kept convention from stagingroom
local g_fCountdownTimer = 10
local g_fCountdownTickSoundTime = 10
local g_fCountdownInitialTime = 10
local g_fCountdownReadyButtonTime = 10
local g_timer = -1
local hostID = Network.GetGameHostPlayerID()
local localID = Network.GetLocalPlayerID()
local tick = os.clock()
local tick_2 = os.clock()
local map_sd = 0
local game_sd = 0


-- ===========================================================================
--	New Functions
-- ===========================================================================
function OnVoteRemap()
	-- Preparing the panel
	m_votetype = 0
	g_cached_playerIDs = {}
	m_forced = false
	ContextPtr:SetHide(false);
	Controls.VoteContainer:SetHide(false)
	Controls.TimerContainer:SetHide(false)
	Controls.RemapContainer:SetHide(true)
	Controls.Button_Obs:SetHide(true)
	Controls.VoteTitle:SetText(Locale.Lookup("LOC_MPH_VOTEPANEL_TITLE_REMAP_TEXT"))
	Controls.VoteLabel:SetText(Locale.Lookup("LOC_MPH_VOTEPANEL_LABEL_REMAP_TEXT"))
	Controls.VoteFeedback:SetText(Locale.Lookup("LOC_MPH_VOTEPANEL_FEEDBACK_REMAP_DEFAULT_TEXT"))
	Controls.CountdownTimerAnim:RegisterAnimCallback( OnUpdateTimers );	
	g_timer = 1
	g_fCountdownTimer = 60;
	g_fCountdownTickSoundTime = g_fCountdownTimer - 50; -- start countdown ticks in 50 secs.
	g_fCountdownInitialTime = g_fCountdownTimer;
	g_fCountdownReadyButtonTime = g_fCountdownTimer;
	localID = Network.GetLocalPlayerID()
	hostID = Network.GetGameHostPlayerID()
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs()
	
	-- Refreshing the players list
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
		if iPlayer == localID then
			m_roletype = status
		end
		tmp = { ID = id, Team = team, Status = status, Name = namestr, Vote = 0 }
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
	
	UpdatePlayerList()
	UpdateVoteOptions()
	

end

function UpdateVoteOptions()
	hostID = Network.GetGameHostPlayerID()
	localID = Network.GetLocalPlayerID()
	-- Remap
	if m_votetype == 0 then
		if m_roletype == 0 then
			Controls.VoteButton_Left:SetText(Locale.Lookup("LOC_MPH_VOTELEFT_BUTTON_1_REMAP_TEXT"))
			Controls.VoteButton_Left:SetHide(false)
			Controls.VoteButton_Left:SetDisabled(false)
			Controls.VoteButton_Left:RegisterCallback( Mouse.eLClick, OnVoteLeft );
			Controls.VoteButton_Right:SetText(Locale.Lookup("LOC_MPH_VOTERIGHT_BUTTON_1_REMAP_TEXT"))
			Controls.VoteButton_Right:SetHide(false)
			Controls.VoteButton_Right:SetDisabled(false)
			Controls.VoteButton_Right:RegisterCallback( Mouse.eLClick, OnVoteRight );
			Controls.Button_Confirm:SetHide(true)
			elseif m_roletype == 1 then	
			Controls.VoteButton_Left:SetText(Locale.Lookup("LOC_MPH_VOTELEFT_BUTTON_1_REMAP_TEXT"))
			Controls.VoteButton_Left:SetHide(false)
			Controls.VoteButton_Left:SetDisabled(true)
			Controls.VoteButton_Left:ClearCallback(Mouse.eLClick)
			Controls.VoteButton_Right:SetText(Locale.Lookup("LOC_MPH_VOTERIGHT_BUTTON_1_REMAP_TEXT"))
			Controls.VoteButton_Right:SetHide(false)
			Controls.VoteButton_Right:SetDisabled(true)
			Controls.VoteButton_Right:ClearCallback(Mouse.eLClick)
			Controls.Button_Confirm:SetHide(true)	
			elseif m_roletype == 2 then	
			Controls.VoteButton_Left:SetText(Locale.Lookup("LOC_MPH_VOTELEFT_BUTTON_1_REMAP_TEXT"))
			Controls.VoteButton_Left:SetHide(true)
			Controls.VoteButton_Left:SetDisabled(true)
			Controls.VoteButton_Left:ClearCallback(Mouse.eLClick)
			Controls.VoteButton_Right:SetText(Locale.Lookup("LOC_MPH_VOTERIGHT_BUTTON_1_REMAP_TEXT"))
			Controls.VoteButton_Right:SetHide(true)
			Controls.VoteButton_Right:SetDisabled(true)
			Controls.VoteButton_Right:ClearCallback(Mouse.eLClick)
			Controls.Button_Confirm:SetHide(false)	
			Controls.Button_Confirm:SetText(Locale.Lookup("LOC_MPH_CONFIRM_BUTTON_1_REMAP_TEXT"))
			if hostID == localID  and b_remap_passed == true then
				Controls.Button_Confirm:SetText(Locale.Lookup("LOC_MPH_CONFIRM_BUTTON_HOST_REMAP_TEXT"))
				Controls.Button_Confirm:RegisterCallback( Mouse.eLClick, OnHostConfirmResults );
				else
				Controls.Button_Confirm:RegisterCallback( Mouse.eLClick, OnConfirmResults );
			end
			elseif m_roletype == -7 then	
			Controls.VoteButton_Left:SetText(Locale.Lookup("LOC_MPH_VOTELEFT_BUTTON_1_REMAP_TEXT"))
			Controls.VoteButton_Left:SetHide(true)
			Controls.VoteButton_Left:SetDisabled(true)
			Controls.VoteButton_Left:ClearCallback(Mouse.eLClick)
			Controls.VoteButton_Right:SetText(Locale.Lookup("LOC_MPH_VOTERIGHT_BUTTON_1_REMAP_TEXT"))
			Controls.VoteButton_Right:SetHide(true)
			Controls.VoteButton_Right:SetDisabled(true)
			Controls.VoteButton_Right:ClearCallback(Mouse.eLClick)
			if g_fCountdownTimer > 0 then
				Controls.Button_Confirm:SetHide(true)
				else
				Controls.Button_Obs:SetHide(false)
				Controls.Button_Obs:SetText(Locale.Lookup("LOC_MPH_CONFIRM_BUTTON_1_REMAP_TEXT"))
				Controls.Button_Obs:RegisterCallback( Mouse.eLClick, OnConfirmResults );
				
			end
			Controls.Button_Confirm:SetText(Locale.Lookup("LOC_MPH_CONFIRM_BUTTON_1_REMAP_TEXT"))
			Controls.Button_Confirm:RegisterCallback( Mouse.eLClick, OnConfirmResults );
			if hostID == localID  and b_remap_passed == true then
				Controls.Button_Obs:SetHide(true)
				Controls.Button_Confirm:SetHide(false)
				Controls.Button_Confirm:SetText(Locale.Lookup("LOC_MPH_CONFIRM_BUTTON_HOST_REMAP_TEXT"))
				Controls.Button_Confirm:RegisterCallback( Mouse.eLClick, OnHostConfirmResults );
				else
				if g_fCountdownTimer == 0 or g_fCountdownTimer < 0 or g_timer == -1 then
					Controls.Button_Confirm:SetHide(false)
					Controls.Button_Obs:SetHide(true)
				end
				Controls.Button_Confirm:RegisterCallback( Mouse.eLClick, OnConfirmResults );
			end
			else	
			Controls.VoteButton_Left:SetText(Locale.Lookup("LOC_MPH_VOTELEFT_BUTTON_1_REMAP_TEXT"))
			Controls.VoteButton_Left:SetHide(true)
			Controls.VoteButton_Left:SetDisabled(true)
			Controls.VoteButton_Left:ClearCallback(Mouse.eLClick)
			Controls.VoteButton_Right:SetText(Locale.Lookup("LOC_MPH_VOTERIGHT_BUTTON_1_REMAP_TEXT"))
			Controls.VoteButton_Right:SetHide(true)
			Controls.VoteButton_Right:SetDisabled(true)
			Controls.VoteButton_Right:ClearCallback(Mouse.eLClick)
			Controls.Button_Confirm:SetHide(false)
			Controls.Button_Confirm:SetText(Locale.Lookup("LOC_MPH_CONFIRM_BUTTON_1_REMAP_TEXT"))
			if hostID == localID and b_remap_passed == true then
				Controls.Button_Confirm:SetText(Locale.Lookup("LOC_MPH_CONFIRM_BUTTON_HOST_REMAP_TEXT"))
				Controls.Button_Confirm:RegisterCallback( Mouse.eLClick, OnHostConfirmResults );
				else
				Controls.Button_Confirm:RegisterCallback( Mouse.eLClick, OnConfirmResults );
			end
		end	
	end
	
end

function UpdatePlayerList()
	print("UpdatePlayerList()")
	hostID = Network.GetGameHostPlayerID()
	localID = Network.GetLocalPlayerID()
	-- g_cached_playerIDs: ID = id, Team = team, Status = status, Name = name
	local displayed_list = ""
	count = 0
	for i, player in ipairs(g_cached_playerIDs) do
		count = count + 1
		if count % 2 == 0 then
			displayed_list = displayed_list.."             "
			else
			displayed_list = displayed_list.."[NEWLINE]"
		end
		if player.Status == 0 then
			displayed_list = displayed_list..Locale.Lookup(player.Name).." ("..player.Team..")"
			elseif player.Status == -2 then
			displayed_list = displayed_list.."[COLOR_Grey]" .. Locale.Lookup(player.Name) .. " ("..player.Team.." - AI)[ENDCOLOR]"
			elseif player.Status == -4 then
			displayed_list = displayed_list.."[COLOR_Grey]" .. Locale.Lookup(player.Name) .. " ("..player.Team..")[ENDCOLOR]"
			elseif player.Status == -5 then
			displayed_list = displayed_list.."[COLOR_Grey]" .. Locale.Lookup(player.Name) .. " ("..player.Team.." - No Vote)[ENDCOLOR]"
			elseif player.Status == -7 then
			displayed_list = displayed_list.."[COLOR_Blue]" .. Locale.Lookup(player.Name) .. " (Observer)[ENDCOLOR]"
			elseif player.Status == 1 then 
			displayed_list = displayed_list.."[COLOR_Civ6Green]" .. Locale.Lookup(player.Name) .. " ("..player.Team..")[ENDCOLOR]"
			elseif player.Status == 2 then
				if player.Vote == 1 then
					displayed_list = displayed_list.."[COLOR_Civ6Green]" .. Locale.Lookup(player.Name) .. " ("..player.Team..")[ENDCOLOR]"
					else
					displayed_list = displayed_list.."[COLOR_Civ6Red]" .. Locale.Lookup(player.Name) .. " ("..player.Team..")[ENDCOLOR]"
				end
		end
		if player.ID == localID then
			m_roletype = player.Status
		end
	end	
	Controls.PlayerList:SetText(displayed_list)
end

function OnVoteLeft()
	hostID = Network.GetGameHostPlayerID()
	localID = Network.GetLocalPlayerID()
	UI.PlaySound("Confirm_Bed_Positive")
	if localID ~= hostID then
		Network.SendChat(".mph_ui_vote_remap_"..localID.."_1",-2,hostID)
		else
		OnHostReceiveVote(".mph_ui_vote_remap_"..localID.."_1")
	end
end

function OnVoteRight()
	hostID = Network.GetGameHostPlayerID()
	localID = Network.GetLocalPlayerID()
	UI.PlaySound("Confirm_Bed_Positive")
	if localID ~= hostID then
		Network.SendChat(".mph_ui_vote_remap_"..localID.."_0",-2,hostID)
		else
		OnHostReceiveVote(".mph_ui_vote_remap_"..localID.."_0")
	end
end

function OnConfirmResults()
	print("OnConfirmResults()")
	m_votetype = -1
	m_roletype = -1
	ContextPtr:SetHide(true);
	g_cached_playerIDs = {}
end

function OnHostConfirmResults()
	print("OnHostConfirmResults()")
	hostID = Network.GetGameHostPlayerID()
	localID = Network.GetLocalPlayerID()
	if  b_remap_passed == true and m_votetype == 0 then
		UserConfiguration.SaveCheckpoint();
		Controls.VoteContainer:SetHide(true)
		Controls.RemapContainer:SetHide(false)
		Controls.RemapLabel:SetText(Locale.Lookup("LOC_MPH_REMAPPANEL_LABEL_TEXT"))
		Controls.MapSeedEdit:ClearString()
		Controls.GameSeedEdit:ClearString()
		if hostID == localID and b_remap_passed == true then
			Controls.Remap_Confirm:SetHide(false)
			Controls.Remap_Confirm:SetText(Locale.Lookup("LOC_MPH_CONFIRM_BUTTON_HOST_REMAP_TEXT"))
			if m_forced == true then
				Controls.Remap_Abort:SetHide(false)
				Controls.Remap_Abort:SetText(Locale.Lookup("LOC_MPH_CONFIRM_BUTTON_HOST_REMAP_CANCEL_TEXT"))
				Controls.Remap_Abort:RegisterCallback( Mouse.eLClick, OnClose );
				else
				Controls.Remap_Abort:SetHide(true)
			end
			Controls.Remap_Confirm:RegisterCallback( Mouse.eLClick, OnHostRemap );
		end
	end
	m_votetype = -1
	m_roletype = -1
	g_cached_playerIDs = {}
end

-- ===========================================================================
-- Remap
-- ===========================================================================

function OnHostRemap_Menu()
	hostID = Network.GetGameHostPlayerID()
	localID = Network.GetLocalPlayerID()
	if localID ~= hostID then
		return
	end
	Controls.VoteTitle:SetText(Locale.Lookup("LOC_MPH_VOTEPANEL_TITLE_REMAP_ADMIN_TEXT"))

	Controls.MapSeedDisplay:SetText("Map Seed #"..map_sd)
	Controls.GameSeedDisplay:SetText("Game Seed #"..game_sd)
	Controls.VoteTitle:SetText(Locale.Lookup("LOC_MPH_VOTEPANEL_TITLE_REMAP_ADMIN_TEXT"))
	ContextPtr:SetHide(false);
	b_remap_passed = true
	m_forced = true
	m_votetype = 0
	OnHostConfirmResults()
end

function OnHostRemap()
	local str = Controls.MapSeedEdit:GetText();
	hostID = Network.GetGameHostPlayerID()
	if tonumber(str) ~= nil then
		MapConfiguration.SetValue("RANDOM_SEED", tonumber(str));
		else
		MapConfiguration.SetValue("RANDOM_SEED", MapConfiguration.GetValue("RANDOM_SEED")+1);
	end
	str = Controls.GameSeedEdit:GetText();
	if tonumber(str) ~= nil then
		GameConfiguration.SetValue("GAME_SYNC_RANDOM_SEED", tonumber(str));
		else
		GameConfiguration.SetValue("GAME_SYNC_RANDOM_SEED", GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED")+1);
	end
	Network.BroadcastGameConfig()
	--print("New Game Seed",GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED"))
	--print("New Map Seed",MapConfiguration.GetValue("RANDOM_SEED"));
	--local player_ids = GameConfiguration.GetMultiplayerPlayerIDs()
	--for i, iPlayer in ipairs(player_ids) do
	--	if Players[iPlayer] ~= nil then
	--		if Network.IsPlayerConnected(iPlayer) == true and iPlayer ~= hostID then
	--			Network.SendChat(".mph_ui_remap_triggered",-2,iPlayer)
	--			Network.SendChat(".mph_ui_remap_map_"..MapConfiguration.GetValue("RANDOM_SEED"),-2,iPlayer)
	--			Network.SendChat(".mph_ui_remap_rng_"..GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED"),-2,iPlayer)
	--		end
	--	end
	--end
	--b_RemapArmed = true
	
	ConfirmRestart()
end

function ConfirmRestart()
	local localID = Network.GetLocalPlayerID()
	if localID == Network.GetGameHostPlayerID() then
		if _kPopupDialog == nil then
		_kPopupDialog = PopupDialog:new( "VotePanel" );
		end
		if (GameConfiguration.IsPaused() == true) then
			local pausePlayerID  = GameConfiguration.GetPausePlayer();
			local localPlayerConfig = PlayerConfigurations[pausePlayerID];
			if(localPlayerConfig) then
				localPlayerConfig:SetWantsPause(false);
			end
			Network.BroadcastPlayerInfo();
		end
		if (not _kPopupDialog:IsOpen()) then
			_kPopupDialog:AddCountDown(10,OnYesRestart)
			_kPopupDialog:AddTitle("Restart Game");
			_kPopupDialog:AddText("Are you sure to restart the game?");
			_kPopupDialog:AddButton( "Yes", OnYesRestart, nil, nil, "PopupButtonInstanceRed" );
			_kPopupDialog:AddButton( "No", OnNoRestart );
			_kPopupDialog:Open();
		end
	end
end


function OnYesRestart( )
	--Network.BroadcastGameConfig()
	--local player_ids = GameConfiguration.GetMultiplayerPlayerIDs()
	--for i, iPlayer in ipairs(player_ids) do
	--	if Players[iPlayer] ~= nil then
	--		if Network.IsPlayerConnected(iPlayer) == true and iPlayer ~= hostID then
	--			Network.SendChat(".mph_ui_remap_execute", -2,-1)
	--		end
	--	end
	--end	
	_kPopupDialog:Close();
	ContextPtr:SetHide(true);
	GameConfiguration.SetValue("GAME_HOST_IS_JUST_RELOADING","Y")
	Network.BroadcastGameConfig();
	--local kParameters:table = {};
	--kParameters.GameSeed = GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED")
	--kParameters.MapSeed = MapConfiguration.GetValue("RANDOM_SEED")
	--kParameters.OnStart = "OnHostInstructsRemap";
	--if (GameConfiguration.IsPaused() == true) then
	--	local pausePlayerID  = GameConfiguration.GetPausePlayer();
	--	local localPlayerConfig = PlayerConfigurations[pausePlayerID];
	--	if(localPlayerConfig) then
	--		localPlayerConfig:SetWantsPause(false);
	--	end
	--	Network.BroadcastPlayerInfo();
	--end
	Network.SendChat("Initiating Remap",-2,Network.GetGameHostPlayerID())
	Network.SendChat("----------------",-2,Network.GetGameHostPlayerID())
	Network.SendChat("You'll be resynced to the new game once the Host has fully loaded.",-2,Network.GetGameHostPlayerID())
	OnLocalHostRestart()
	--UI.RequestPlayerOperation(Network.GetGameHostPlayerID(), PlayerOperations.EXECUTE_SCRIPT, kParameters);
	--print("UI -> OnHostInstructsRemap",kParameters.GameSeed,kParameters.MapSeed,os.date())
end

function OnNoRestart( )
	_kPopupDialog:Close();
	ContextPtr:SetHide(true);
end


function OnHostReceiveVote(text)
	print("OnHostReceiveVote")
	hostID = Network.GetGameHostPlayerID()
	localID = Network.GetLocalPlayerID()
	if hostID ~= localID or m_votetype < 0 then
		return
	end
	local sender_id = -1
	local sender_vote = -1
	-- remap Network.SendChat(".mph_ui_vote_remap_"..localID.."_L",-2,hostID)
	if m_votetype == 0 then
		if string.lower(string.sub(text,21,21)) == "_" then
			sender_id = string.lower(string.sub(text,20,20))
			sender_vote = string.lower(string.sub(text,22)) 
			
			else
			sender_id = string.lower(string.sub(text,20,21))
			sender_vote = string.lower(string.sub(text,23))			
		end
		sender_id = tonumber(sender_id)
		sender_vote = tonumber(sender_vote)
		for i, player in ipairs(g_cached_playerIDs) do
			if player.ID == sender_id then
				player.Vote = sender_vote
				if sender_vote ~= 66 then
					player.Status = 1
					else
					player.Status = -5
				end
				print(player.Name,"has voted",player.Vote)
			end
		end

		-- send receipt confirmation
		local everyone_voted = true
		for i, player in ipairs(g_cached_playerIDs) do 
			if player.Status ~= -3 and player.Status ~= -2 then
				if (player.ID ~= hostID) then
					Network.SendChat(".mph_ui_voted_"..sender_id.."_"..sender_vote,-2,player.ID)
					else
					OnReceiveVote(".mph_ui_voted_"..sender_id.."_"..sender_vote)
				end
			end
			if player.Status == 0 then
				everyone_voted = false
			end
		end
		print("everyone_voted",everyone_voted)
		-- Determine the vote
		if everyone_voted == true then
			local total_votes = 0
			local sum_votes = 0
			for i, player in ipairs(g_cached_playerIDs) do 
				if player.Status == 1 then
					total_votes = total_votes + 1
					sum_votes = sum_votes + player.Vote
				end
			end
			
			local b_pass = false
			if (sum_votes == total_votes / 2 or sum_votes > total_votes / 2) and total_votes > 0 then
				b_pass = true
			end
			for i, player in ipairs(g_cached_playerIDs) do 
				if player.Status ~= -3 and player.Status ~= -2 then
					if b_pass == true then
						if (player.ID ~= localID) then
							Network.SendChat(".mph_ui_voted_pass",-2,player.ID)
							else
							OnReceiveVote(".mph_ui_voted_pass")
						end
						else
						if (player.ID ~= localID) then
							Network.SendChat(".mph_ui_voted_fail",-2,player.ID)
							else
							OnReceiveVote(".mph_ui_voted_fail")
						end
					end
				end
			end

		end
	end	
end

function OnReceiveVote(text)
	print("OnReceiveVote")
	hostID = Network.GetGameHostPlayerID()
	localID = Network.GetLocalPlayerID()
	local sender_id = -1
	local sender_vote = -1
	-- remap Network.SendChat(".mph_ui_voted_"..sender_id.."_"..sender_vote,-2,player.ID)
	if m_votetype == 0 then
		if tonumber(string.lower(string.sub(text,15,15))) ~= nil then
			if string.lower(string.sub(text,16,16)) == "_" then
				sender_id = tonumber(string.lower(string.sub(text,15,15)))
				sender_vote  = tonumber(string.lower(string.sub(text,17)))
				else
				sender_id = tonumber(string.lower(string.sub(text,15,16)))
				sender_vote  = tonumber(string.lower(string.sub(text,18)))
			end
			
			for i, player in ipairs(g_cached_playerIDs) do
				if player.ID == sender_id then
					player.Status = 1
					player.Vote = sender_vote
					if player.Vote ~= 66 then
						print(player.Name,"has voted",player.Vote)
						else
						print(player.Name,"hasn't voted")
						player.Status = -5
					end
				end
			end
			
			elseif string.lower(string.sub(text,15)) == "pass" then
			StopCountdown(); 
			g_fCountdownTimer = 0
			Controls.VoteFeedback:SetText(Locale.Lookup("LOC_MPH_VOTEPANEL_FEEDBACK_REMAP_PASS_TEXT"))
			b_remap_passed = true
			for i, player in ipairs(g_cached_playerIDs) do
				if player.Status == 1 then
					player.Status = 2
				end
			end
			
			elseif string.lower(string.sub(text,15)) == "fail" then
			StopCountdown(); 
			g_fCountdownTimer = 0
			Controls.VoteFeedback:SetText(Locale.Lookup("LOC_MPH_VOTEPANEL_FEEDBACK_REMAP_FAIL_TEXT"))
			b_remap_passed = false
			for i, player in ipairs(g_cached_playerIDs) do
				if player.Status == 1 then
					player.Status = 2
				end
			end
			
		end
	end
	


	UpdatePlayerList()
	UpdateVoteOptions()
end

-------------------------------------------------
--	Timer Functions
-------------------------------------------------
function OnUpdateTimers( uiControl:table, fProgress:number )

	local fDTime:number = UIManager:GetLastTimeDelta();

	-- Update launch countdown.
	if(g_fCountdownInitialTime ~= -1) then
		g_fCountdownTimer = g_fCountdownTimer - fDTime;
		Controls.TurnTimerMeter:SetPercent(g_fCountdownTimer / g_fCountdownInitialTime);
		local intTime = math.floor(g_fCountdownTimer);
		Controls.TimerButton:LocalizeAndSetText(  intTime );
		Controls.TimerButton:LocalizeAndSetToolTip( "" );
		if( g_fCountdownTimer <= 0 ) then
			StopCountdown(); 
			else
			-- Update countdown tick sound.
			if( g_fCountdownTimer < g_fCountdownTickSoundTime) and g_timer == 1 then
				g_fCountdownTickSoundTime = g_fCountdownTickSoundTime-1; -- set countdown tick for next second.
				UI.PlaySound("Play_MP_Game_Launch_Timer_Beep");
			end

		end
	end

	if(g_fCountdownTimer <= 0) then
		-- Both timers have elapsed, we no longer have to tick.
		Controls.CountdownTimerAnim:ClearAnimCallback();			
	end
end

function StopCountdown()
	hostID = Network.GetGameHostPlayerID()
	localID = Network.GetLocalPlayerID()
	Controls.TimerContainer:SetHide(true)
	UpdatePlayerList()
	UpdateVoteOptions()
	g_fCountdownTimer = 0
	g_timer = -1
	-- Remap
	if m_votetype == 0 then
		if localID == hostID then
			for i, player in ipairs(g_cached_playerIDs) do
				if player.Status == 0 then
					player.Status = -5
					OnHostReceiveVote(".mph_ui_vote_remap_"..localID.."_66")
				end
			end		
		end
	end
end



-- ===========================================================================
--	Listening function
-- ===========================================================================

function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
	hostID = Network.GetGameHostPlayerID()
	localID = Network.GetLocalPlayerID()
	local b_ishost = false
	if fromPlayer == Network.GetGameHostPlayerID() then
		b_ishost = true
	end
	
	-- Triggering a VoteMap	
	if b_ishost == true and hostID ~= localID and (string.lower(text) == ".mph_ui_snap")  then
		print("Snapshot Requested")
		Network.RequestSnapshot()
		return
	end
	
		
	if b_ishost == true and (string.lower(text) == ".mph_ui_vote_remap" or string.lower(text) == ".vremap")  then
		OnVoteRemap()
		return
	end
	
	if b_ishost == true and (string.lower(text) == ".mph_ui_remap_triggered")  then
		b_RemapArmed = true
		return
	end
	
	if b_ishost == true and (string.lower(string.sub(text,1,17)) == ".mph_ui_remap_map")  then
		MapConfiguration.SetValue("RANDOM_SEED",tonumber(string.sub(text,19)))
		Network.BroadcastGameConfig()
		Network.SendChat(".mph_ui_log_received_mapseed_"..tostring(tonumber(string.sub(text,19))),-2,hostID)
		return
	end
	
	if b_ishost == true and (string.lower(string.sub(text,1,17)) == ".mph_ui_remap_rng")  then
		GameConfiguration.SetValue("GAME_SYNC_RANDOM_SEED",tonumber(string.sub(text,19)))
		Network.BroadcastGameConfig()
		Network.SendChat(".mph_ui_log_received_gameseed_"..tostring(tonumber(string.sub(text,19))),-2,hostID)
		return
	end
	
	if b_ishost == true and string.lower(text) == ".mph_ui_remap_execute" and b_RemapArmed == true then
		Network.BroadcastGameConfig();
		Network.BroadcastPlayerInfo();
		Network.BroadcastGameConfig();
		Network.BroadcastPlayerInfo();
		Network.BroadcastGameConfig();
		Network.SendChat(".mph_ui_log_received_remap_request_mapseed_"..tostring(MapConfiguration.GetValue("RANDOM_SEED")).."_gameseed_"..tostring(GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED")),-2,hostID)	
		Network.RestartGame();
		return
	end
	
	if b_ishost == true and string.lower(string.sub(text,1,13)) == ".mph_ui_voted" then
		OnReceiveVote(text)
		return
	end
	
	if string.lower(string.sub(text,1,13)) == ".mph_ui_vote_" and hostID == localID then
		OnHostReceiveVote(text)
		return
	end
		
end

function OnLocalHostRestart()
	if localID ~= hostID then
		print("OnLocalHostRestart() - Not the Host")
	end
	print(tick,"REMAP - HOST IS RESTARTING",os.date())
	GameConfiguration.SetValue("GAME_HOST_IS_JUST_RELOADING","Y")
	Network.BroadcastGameConfig();	
	if (GameConfiguration.IsPaused() == false) then
		local localPlayerID = hostID;
		local localPlayerConfig = PlayerConfigurations[localPlayerID];
		local newPause = not localPlayerConfig:GetWantsPause();
		localPlayerConfig:SetWantsPause(newPause);
		Network.BroadcastPlayerInfo();
	end
	Network.RestartGame();	
end

function OnRefresh()
	if tick + 1 < os.clock() then
		--print(tick,"Local Status:",Game:GetProperty("MPH_RESYNC_ARMED_"..localID),"RESTART?",GameConfiguration.GetValue("GAME_HOST_IS_JUST_RELOADING"),Game:GetProperty("MPH_REMAP_MODE"))
		-- triggering a Host Request (Restart Context - Pre Host Restart)
		--if Game:GetProperty("MPH_REMAP_MODE") == 1 and localID == hostID then
		--print(tick,"REMAP",Game:GetProperty("MPH_REMAP_MODE"),"SEED",Game:GetProperty("MPH_GAMESEED"),Game:GetProperty("MPH_MAPSEED"),os.date())
		-- Arming the seeds manually 
		--	if Game:GetProperty("MPH_GAMESEED") ~= nil and Game:GetProperty("MPH_MAPSEED") ~= nil then
		--		if (GameConfiguration.IsPaused() == false) then
		--			local localPlayerID = hostID;
		--			local localPlayerConfig = PlayerConfigurations[localPlayerID];
		--			local newPause = not localPlayerConfig:GetWantsPause();
		--			localPlayerConfig:SetWantsPause(newPause);
		--			Network.BroadcastPlayerInfo();
		--		end
		--		MapConfiguration.SetValue("RANDOM_SEED",Game:GetProperty("MPH_MAPSEED"))
		--		GameConfiguration.SetValue("GAME_SYNC_RANDOM_SEED", Game:GetProperty("MPH_GAMESEED"))
		--		GameConfiguration.SetValue("GAME_HOST_IS_JUST_RELOADING","Y")
		--		Network.BroadcastGameConfig();
		--		print(tick,"REMAP - HOST IS RESTARTING",os.date())
		--		Network.RestartGame();
		--		return
		--	end
		--end

		-- triggering a Snapshot Request (Restart Context - Host has Fully Loaded)
		if localID == hostID and GameConfiguration.GetValue("GAME_HOST_IS_JUST_RELOADING") == "Y" then
			print(tick,"Host Command: Snapshot Request",os.date())
			GameConfiguration.SetValue("GAME_HOST_IS_JUST_RELOADING","N")
			Network.BroadcastGameConfig();			
			Network.SendChat(".mph_ui_snap",-2,-1)
			return	
		end
		tick = os.clock()
	end
end

-- ===========================================================================
--	Callback
-- ===========================================================================
function OnShutdown()
	ContextPtr:SetHide(true);
	print("MPH Shutdown - UI Refresh")
	Events.GameCoreEventPublishComplete.Remove ( OnRefresh );
	LuaEvents.MPHMenu_OnHostRemap.Remove(OnHostRemap_Menu)
	Events.MultiplayerChat.Remove( OnMultiplayerChat );
end

function OnClose()
	ContextPtr:SetHide(true);
end


-- ===========================================================================
function Initialize()

	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetHide(true);

	map_sd = tostring(MapConfiguration.GetValue("RANDOM_SEED"))
	game_sd = tostring(GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED"))
	
	Controls.VoteStack:CalculateSize();
	Events.MultiplayerChat.Add( OnMultiplayerChat );
	_kPopupDialog = PopupDialog:new( "VotePanel" );
	
	LuaEvents.MPHMenu_OnHostRemap.Add(OnHostRemap_Menu)
	print("MPH Activate - UI Refresh")
	Events.GameCoreEventPublishComplete.Add ( OnRefresh );
end
Initialize();
