-- ===========================================================================
--	MP Helper by D. / Jack The Narrator 
--  Custom Chat Panel Module
--	Civilization VI, Firaxis Games
-- ===========================================================================
include("ChatPanel.lua");
print("MPH Anonymous Chat Panel")

-- ===========================================================================
--	ORIGINAL VARIABLES
-- ===========================================================================

-- ===========================================================================
--	NEW VARIABLES
-- ===========================================================================

------------------------------------------------- 
-- Override
-------------------------------------------------
function OnMultplayerPlayerConnected( playerID )
	print("OnMultplayerPlayerConnected",playerID )
	if(GameConfiguration.IsNetworkMultiplayer()) then
		if GameConfiguration.GetValue("GAMEMODE_ANONYMOUS") == false then
			OnChat( playerID, -1, PlayerConnectedChatStr, false );
		end
		UI.PlaySound("Play_MP_Player_Connect");
		BuildPlayerList();
	end
end