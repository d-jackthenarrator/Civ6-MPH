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
local b_pulse = false
local b_pulse_2 = false
local b_pulse_3 = false
local b_pulse_4 = false



-- ===========================================================================
--	NEW EVENTS
-- ===========================================================================

function OnLocalPlayerTurnBegin()
	local localID = Network.GetLocalPlayerID()
	local hostID = Network.GetGameHostPlayerID()
	
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
				GameConfiguration.SetValue("TURN_TIMER_TIME", 150)
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

Events.LocalPlayerTurnBegin.Add(		OnLocalPlayerTurnBegin );




