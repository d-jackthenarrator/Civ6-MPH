-- Copyright 2016-2020, Firaxis Games
-- (Multiplayer) lastmove_UI.lua By D. / Jack The Narrator
print("-- Last Move First Move Mode UI Script--");

-- ===========================================================================
--	Variables
-- ===========================================================================
local m_turn = 0
local b_sent_last = false
local b_sent_clean = false
local iLastMoveRange = 15
local iLastMoveCleanDelay = 10

-- ===========================================================================
--	New Functions
-- ===========================================================================
function OnLocalPlayerTurnBegin()
	b_sent_last = false
	b_sent_clean = false
end

function OnTurnTimerUpdated(elapsedTime :number, maxTurnTime :number)
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	if localID ~= hostID  then
		return
	end
	if(maxTurnTime <= 0) or elapsedTime == nil or maxTurnTime == nil then
		return
	end
	-- Host not in an infinite turn
	-- Clean 
	if (elapsedTime > iLastMoveCleanDelay and b_sent_clean == false) then
		print("Send Clean UI - maxTurnTime",maxTurnTime," - elapsedTime - ",elapsedTime)
		local kParameters:table = {};
		kParameters.OnStart = "OnHostCommandLastMoveClean";
		UI.RequestPlayerOperation(hostID, PlayerOperations.EXECUTE_SCRIPT, kParameters);
		b_sent_clean = true
	end	
	-- Last Move Kicks In
	if ( ( (maxTurnTime - elapsedTime) < iLastMoveRange ) and b_sent_last == false and maxTurnTime > 0) then
		print("Send Start Debuff UI")
		local kParameters:table = {};
		kParameters.OnStart = "OnHostCommandLastMoveStart";
		UI.RequestPlayerOperation(hostID, PlayerOperations.EXECUTE_SCRIPT, kParameters);
		b_sent_last = true
	end	
end


-- ===========================================================================
function Initialize()
	Events.LocalPlayerTurnBegin.Add(		OnLocalPlayerTurnBegin );
	Events.TurnTimerUpdated.Add(			OnTurnTimerUpdated );
end
Initialize();
