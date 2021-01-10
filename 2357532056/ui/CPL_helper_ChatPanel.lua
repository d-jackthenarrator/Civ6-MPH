-- ===========================================================================
--	MP Helper by D. / Jack The Narrator 
--  Custom Chat Panel Module
--	Civilization VI, Firaxis Games
-- ===========================================================================
include("ChatPanel.lua");
print("Custom ChatPanel for MP Helper")
local PlayerConnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_CHAT" );

BASE_OnChat = OnChat; 
-- ===========================================================================
--	ORIGINAL VARIABLES
-- ===========================================================================

-- ===========================================================================
--	NEW VARIABLES
-- ===========================================================================

function OnChat( fromPlayer, toPlayer, text, eTargetType, playSounds :boolean )
	if(GameConfiguration.IsNetworkMultiplayer()) then
		if GameConfiguration.GetValue("GAMEMODE_ANONYMOUS") == true then
			if string.find(text, "Connected") ~= nil 
				or string.find(text, "Connecté") ~= nil 
				or string.find(text, "Conectado") ~= nil 
				or string.find(text, "подключен") ~= nil then
				text = "Anon Connected"
				fromPlayer = Network.GetGameHostPlayerID()
			end
		end
	end	


	if string.lower(text) == ".observe" then
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.START_OBSERVER_MODE, nil);
	end

	if string.lower(string.sub(text,1,4)) == ".mph" then
		return
	end
	
	BASE_OnChat( fromPlayer, toPlayer, text, eTargetType, playSounds )
end

------------------------------------------------- 
-- Override
-------------------------------------------------
function OnMultplayerPlayerConnected( playerID )
	if(GameConfiguration.IsNetworkMultiplayer()) then
		if GameConfiguration.GetValue("GAMEMODE_ANONYMOUS") == false then
			OnChat( playerID, -1, PlayerConnectedChatStr, false );
		end
		UI.PlaySound("Play_MP_Player_Connect");
		BuildPlayerList();
	end
end