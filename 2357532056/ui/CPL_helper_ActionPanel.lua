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
local b_congress = false
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
	local pCongressMeetingData = Game.GetWorldCongress():GetMeetingStatus();
	local turnsToNextCongress = pCongressMeetingData.TurnsLeft;
	
	b_congress = false
	b_fired = false
	b_received = false
	b_adjusted = false
	i_lag = 0
	
	if turnsToNextCongress == 0 or turnsToNextCongress == 1 then
		b_congress = true
	end
	
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
	local pCongressMeetingData = Game.GetWorldCongress():GetMeetingStatus();
	local turnsToNextCongress = pCongressMeetingData.TurnsLeft;

	if turnsToNextCongress == 0 or turnsToNextCongress == 1 then
		b_congress = true
	end

	local remaining_time = 0
	if maxTurnTime ~= nil and elapsedTime ~= nil then
		remaining_time = maxTurnTime - elapsedTime
	end
	if maxTurnTime > 40 and localID == hostID then
		if remaining_time < 30 and b_fired == false and GameConfiguration.GetValue("CPL_SMARTTIMER") ~= 1 and b_congress == false then
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

	if b_received == true and b_adjusted == false and GameConfiguration.GetValue("CPL_SMARTTIMER") ~= 1 and localID ~= hostID and b_congress == false then
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
			if (elapsedTime > maxTurnTime + 1)  then
				if HasEmergencyProposals() == true then
					b_congress = true
				end		
				if b_congress == false  and localID ~= hostID then
					print("Turned Actively Halted")
					UI.RequestAction(ActionTypes.ACTION_ENDTURN, { REASON = "UserForced" } );
				end
			end
		end
	end
		
	BASE_OnTurnTimerUpdated(elapsedTime,maxTurnTime)

end

function OnEmergencyEvent_MPH()
	print("OnEmergencyEvent()")
	b_congress = true
end

function OnSpecialSessionNotificationAdded_MPH()
	print("OnSpecialSessionNotificationAdded()")
	b_congress = true
end

function GetSortedProposalCategories(kProposals:table)
	local kSortedCategories:table = {};
	if kProposals ~= nil then
		for proposalType, kProposalCategory in pairs(kProposals) do
			local kProposalDef = GameInfo.ProposalTypes[proposalType];
			if kProposalDef and table.count(kProposalCategory.ProposalsOfType) > 0 then

				local kSorted:table = {
					type = proposalType,
					kData = kProposalDef,
					kCategory = kProposalCategory
				};
				table.insert(kSortedCategories, kSorted);

			elseif kProposalDef == nil then
				UI.DataError("Undefined Proposal Category: " .. proposalType .. " in World Congress Step 2!");
			end
		end

		table.sort(kSortedCategories, function(a, b) return a.kData.Sort < b.kData.Sort; end);
	end
	return kSortedCategories;
end

function HasEmergencyProposals()
	local kSortedCategories:table = GetSortedProposalCategories(Game.GetWorldCongress():GetEmergencies(Game.GetLocalPlayer()).Proposals);
	for _, kSorted in ipairs(kSortedCategories) do
		if kSorted.kCategory.ProposalsOfType and table.count(kSorted.kCategory.ProposalsOfType) > 0 then
			return true;
		end
	end
	return false;
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


LuaEvents.WorldCongressPopup_OnSpecialSessionNotificationAdded.Add(OnSpecialSessionNotificationAdded_MPH);	
Events.LocalPlayerTurnBegin.Add( OnLocalPlayerTurnBegin_MPH );
Events.MultiplayerChat.Add( OnMultiplayerChat_MPH );
Events.EmergencyAvailable.Add( OnEmergencyEvent_MPH );