-- Copyright 2016-2019, Firaxis Games
-- (Multiplayer) Pause Panel
include("PopupPriorityLoader_", true);
-- timer variables kept convention from stagingroom
local g_fCountdownTimer = 10
local g_fCountdownTickSoundTime = 5
local g_fCountdownInitialTime = 10
local g_fCountdownReadyButtonTime = 10
local g_timer = -1;


-- ===========================================================================
-- Internal Functions
function OpenPausePanel()
	if(ContextPtr:IsHidden() == true) then
		g_timer = -1
		UIManager:QueuePopup(ContextPtr, PopupPriority.PausePanel);	

		Controls.PopupAlphaIn:SetToBeginning();
		Controls.PopupAlphaIn:Play();
		Controls.PopupSlideIn:SetToBeginning();
		Controls.PopupSlideIn:Play();
	end
end 

function UpdatePausePanelButton()
	local pausePlayerID : number = GameConfiguration.GetPausePlayer();
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	local is_spectator = false
	
	if GameConfiguration.IsAnyMultiplayer() == false then
		Controls.Button_Confirm:SetHide(true)
		Controls.TimerContainer:SetHide(true)
		return
	end
	
	if g_timer == 1  then
		Controls.TimerContainer:SetHide(false)
		Controls.CountdownLabel:SetHide(false)
		Controls.CountdownLabel:SetText(Locale.Lookup("LOC_MPH_PAUSE_COUNDOWN_LABEL_TEXT"))
		else
		Controls.TimerContainer:SetHide(true)
		Controls.CountdownLabel:SetHide(true)
	end
	
	
	if PlayerConfigurations[localID] ~= nil then
		if PlayerConfigurations[localID]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
			is_spectator = true
		end
	end
	
	if pausePlayerID == localID or localID == hostID or is_spectator == true then
		Controls.Button_Confirm:SetHide(false)
		Controls.Button_Confirm:SetText(Locale.Lookup("LOC_MPH_PAUSE_COUNDOWN_TEXT"))
		Controls.Button_Confirm:RegisterCallback( Mouse.eLClick, OnCountdownPauseSend );
		else
		Controls.Button_Confirm:SetHide(true)
	end
	
	if g_timer == 1 then
		Controls.Button_Confirm:SetHide(true)
	end
end 

function OnCountdownPauseSend()
	local localID = Network.GetLocalPlayerID()
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs()
	for i, iPlayer in ipairs(player_ids) do
		if Players[iPlayer] ~= nil then
			if Network.IsPlayerConnected(iPlayer) == true and iPlayer ~= localID then
				Network.SendChat(".mph_ui_start_pause_coundown", -2,-1)
			end
		end
	end	
	OnCountdownPauseInit()
end 

function OnCountdownPauseInit()
	Controls.CountdownTimerAnim:RegisterAnimCallback( OnUpdateTimers );	
	g_timer = 1
	g_fCountdownTimer = 10;
	g_fCountdownTickSoundTime = g_fCountdownTimer - 5; -- start countdown ticks in 5 secs.
	g_fCountdownInitialTime = g_fCountdownTimer;
	g_fCountdownReadyButtonTime = g_fCountdownTimer;
	UpdatePausePanelButton()
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
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	Controls.TimerContainer:SetHide(true)
	Controls.CountdownLabel:SetHide(true)
	local localPlayerConfig = PlayerConfigurations[localID];
	localPlayerConfig:SetWantsPause(false);
	Network.BroadcastPlayerInfo();
end



-- ===========================================================================
function ClosePausePanel()
	print("ClosePausePanel()",os.time())								 
	UIManager:DequeuePopup( ContextPtr );
end


-- ===========================================================================
function CheckPausedState()
	print("CheckPausedState()",os.time())								  
	if(not GameConfiguration.IsPaused()) then
		ClosePausePanel();
		return;
	else
		local pausePlayerID : number = GameConfiguration.GetPausePlayer();
		if (pausePlayerID ==  PlayerTypes.OBSERVER or pausePlayerID == PlayerTypes.NONE) then
			ClosePausePanel();
			return;
		end

		-- Get pause player
		local pausePlayer = PlayerConfigurations[pausePlayerID];
		local pausePlayerName : string = pausePlayer:GetPlayerName();
		Controls.WaitingLabel:LocalizeAndSetText("LOC_GAME_PAUSED_BY", pausePlayerName);

		OpenPausePanel();
		UpdatePausePanelButton()		
	end
end

-- ===========================================================================
--	Listening function
-- ===========================================================================

function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	local pausePlayerID : number = GameConfiguration.GetPausePlayer();
	local b_ishost = false
	local b_isspec = false
	if fromPlayer == Network.GetGameHostPlayerID() then
		b_ishost = true
	end
	if PlayerConfigurations[fromPlayer] ~= nil then
		if PlayerConfigurations[fromPlayer]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
			b_isspec = true
		end
	end
	
	-- Triggering a Countdown
	
	if string.lower(text) == ".mph_ui_start_pause_coundown" and (b_ishost or b_isspec or fromPlayer == pausePlayerID) then
		OnCountdownPauseInit()
		return
	end
			
end

-- ===========================================================================
--	Event
-- ===========================================================================
function OnGameConfigChanged()
	CheckPausedState();
end


-- ===========================================================================
--	Event
-- ===========================================================================
function OnMenu()
    LuaEvents.PausePanel_OpenInGameOptionsMenu();
end

-- ===========================================================================
--	Callback
-- ===========================================================================
function OnShutdown()
	Events.GameConfigChanged.Remove(CheckPausedState);
	Events.PlayerInfoChanged.Remove(CheckPausedState);
	Events.LoadScreenClose.Remove(CheckPausedState);
	Events.MultiplayerChat.Remove( OnMultiplayerChat );
end

-- ===========================================================================
function Initialize()

	ContextPtr:SetShutdown( OnShutdown );
	Events.MultiplayerChat.Add( OnMultiplayerChat );
	if(not GameConfiguration.IsHotseat() and not WorldBuilder.IsActive()) then
		CheckPausedState();

		Events.GameConfigChanged.Add(CheckPausedState);
		Events.PlayerInfoChanged.Add(CheckPausedState);
		Events.LoadScreenClose.Add(CheckPausedState);

		Controls.PauseStack:CalculateSize();
	else
		ContextPtr:SetHide(true);
	end
end
Initialize();
