-- ===========================================================================
--	MP Helper by D. / Jack The Narrator 
--  Custom Chat Panel Module
--	Civilization VI, Firaxis Games
-- ===========================================================================
include("ChatPanel.lua");
print("MPH Chat Panel")

-- ===========================================================================
--	ORIGINAL VARIABLES
-- ===========================================================================
BASE_OnChat = OnChat
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

-- ===========================================================================
function OnChat( fromPlayer, toPlayer, text, eTargetType, playSounds :boolean )
	if text == nil then
		return
	end
	if ( (string.sub(string.lower(text),1,4) == ".mph"))  then
		print("MPH Command",text)
		return
	end
	
	BASE_OnChat(fromPlayer, toPlayer, text, eTargetType, playSounds);
end

-- ===========================================================================