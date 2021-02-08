-- ===========================================================================
-- CPL Helper overrides for the Action Panel
-- ===========================================================================
include("ActionPanel_Expansion2");
print("CPL Helper - Action Panel")

BASE_OnTurnTimerUpdated = OnTurnTimerUpdated;
BASE_SetEndTurnWaiting = SetEndTurnWaiting;

UIEvents = ExposedMembers.LuaEvents;
-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local START_TURN_TIMER_TICK_SOUND = 10;  -- Start making turn timer ticking sounds when the turn timer is lower than this seconds.
local WORLD_CONGRESS_STAGE_1:number = DB.MakeHash("TURNSEG_WORLDCONGRESS_1");
local WORLD_CONGRESS_STAGE_2:number = DB.MakeHash("TURNSEG_WORLDCONGRESS_2");
local b_fired = false
local b_received = false
local b_adjusted = false
local i_lag = 0
local b_pulse = false
local b_pulse_2 = false
local b_pulse_3 = false
local b_pulse_4 = false



-- ===========================================================================
--	NEW EVENTS
-- ===========================================================================

function OnLocalPlayerTurnBegin_MPH()
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	
	b_fired = false
	b_received = false
	b_adjusted = false
	i_lag = 0
	if localID == hostID then
	
	if GameConfiguration.GetValue("CPL_SMARTTIMER") ~= 1 then
		if (Game:GetProperty("CPL_TIMER") ~= nil) then
				GameConfiguration.SetValue("TURN_TIMER_TIME", Game:GetProperty("CPL_TIMER"))
				GameConfiguration.SetTurnTimerType("TURNTIMER_STANDARD")
				Network.BroadcastGameConfig()
		end
	end
	
	local turnSegment = Game.GetCurrentTurnSegment();
	if GameConfiguration.GetValue("CPL_SMARTTIMER") ~= 1 then
		if turnSegment == WORLD_CONGRESS_STAGE_1 then
				GameConfiguration.SetTurnTimerType("TURNTIMER_STANDARD")
				GameConfiguration.SetValue("TURN_TIMER_TIME", 240)
				Network.BroadcastGameConfig()	
			elseif turnSegment == WORLD_CONGRESS_STAGE_2 then			
				GameConfiguration.SetTurnTimerType("TURNTIMER_STANDARD")
				GameConfiguration.SetValue("TURN_TIMER_TIME", 240)
				Network.BroadcastGameConfig()		
		end
	end
	
	end

	b_pulse = false
	b_pulse_2 = false
	b_pulse_3 = false
	b_pulse_4 = false
end

function OnTurnTimerUpdated(elapsedTime :number, maxTurnTime :number)
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs()
	local remaining_time = 0
	if maxTurnTime ~= nil and elapsedTime ~= nil then
		remaining_time = maxTurnTime - elapsedTime
	end
	if maxTurnTime > 40 and localID == hostID then
		if remaining_time < 30 and b_fired == false and GameConfiguration.GetValue("CPL_SMARTTIMER") ~= 1 then
			print("Timer Adjusted",elapsedTime,maxTurnTime)
			for i, iPlayer in ipairs(player_ids) do
				if Network.IsPlayerConnected(iPlayer) == true and iPlayer ~= hostID then
					Network.SendChat(".mph_ui_pulse30",-2,iPlayer)
				end
			end
			b_fired = true
			b_received = true
		end
	end
	if b_received == true and b_adjusted == false and GameConfiguration.GetValue("CPL_SMARTTIMER") ~= 1 and localID ~= hostID then
		if maxTurnTime ~= nil and elapsedTime ~= nil then
			local lag = math.max((maxTurnTime - elapsedTime) - 30,0)
			i_lag = lag
			print("lag time is",i_lag,maxTurnTime,elapsedTime)
			b_adjusted = true
		end
	end
	
	if maxTurnTime ~= nil then
		maxTurnTime = math.max(maxTurnTime - i_lag,0)
		if elapsedTime ~= nil then
			if elapsedTime > maxTurnTime or elapsedTime == maxTurnTime then
				UI.RequestAction(ActionTypes.ACTION_ENDTURN, { REASON = "UserForced" } );
			end
		end
	end
		
	BASE_OnTurnTimerUpdated(elapsedTime,maxTurnTime)

end



-- ===========================================================================
--	Listening function
-- ===========================================================================

function OnMultiplayerChat_MPH( fromPlayer, toPlayer, text, eTargetType )
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	local b_ishost = false
	if fromPlayer == Network.GetGameHostPlayerID() then
		b_ishost = true
	end
	
	-- Requesting a VoteMap
	
	if (string.lower(text) == ".mph_ui_pulse30" and b_ishost)  then
		b_received = true
		return
	end
end


	
Events.LocalPlayerTurnBegin.Add( OnLocalPlayerTurnBegin_MPH );
Events.MultiplayerChat.Add( OnMultiplayerChat_MPH );
