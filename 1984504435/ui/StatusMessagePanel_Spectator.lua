include("StatusMessagePanel");
print("StatusMessagePanel for BSM")
-- Duplicated with MPH for mod compatibility

-- ===========================================================================
--	EVENT OVERRIDE
-- ===========================================================================
function OnStatusMessage( message:string, displayTime:number, type:number, subType:number )
	local bspec = false
	local spec_ID = 0
	if (Game:GetProperty("SPEC_NUM") ~= nil) then
		for k = 1, Game:GetProperty("SPEC_NUM") do
			if ( Game:GetProperty("SPEC_ID_"..k)~= nil) then
				if Game.GetLocalPlayer() == Game:GetProperty("SPEC_ID_"..k) then
					bspec = true
					spec_ID = k
				end
			end
		end
	end
	if (type == ReportingStatusTypes.GOSSIP) then
		if bspec == false then
			AddGossip( subType, message, displayTime );
		end
	end

	if (type == ReportingStatusTypes.DEFAULT) then
		AddDefault( message, displayTime );
	end

	RealizeMainAreaPosition();
end

LuaEvents.StatusMessage.Add( OnStatusMessage );

-- ===========================================================================
--	EVENT OVERRIDE
-- ===========================================================================
function OnMultplayerPlayerConnected( playerID:number )
	if playerID == -1 or playerID == 1000 then
		return;
	end

	if( ContextPtr:IsHidden() == false and GameConfiguration.IsNetworkMultiplayer() ) then
		local pPlayerConfig :table = PlayerConfigurations[playerID];
		local name :string = "Player"
		if pPlayerConfig:GetNickName() ~= nil then
			name = pPlayerConfig:GetNickName()
			else
			name = pPlayerConfig:GetPlayerName()
		end
		local statusMessage :string= Locale.Lookup(name) .. " " .. TXT_PLAYER_CONNECTED_CHAT;
		OnStatusMessage( statusMessage, DEFAULT_TIME_TO_DISPLAY, ReportingStatusTypes.DEFAULT );
	end
end

-- ===========================================================================
--	EVENT OVERRIDE
-- ===========================================================================
function OnMultiplayerPrePlayerDisconnected( playerID:number )
	if playerID == -1 or playerID == 1000 then
		return;
	end

	if( ContextPtr:IsHidden() == false and GameConfiguration.IsNetworkMultiplayer() ) then
		local pPlayerConfig :table = PlayerConfigurations[playerID];
		local statusMessage :string= Locale.Lookup(pPlayerConfig:GetPlayerName());
		local name :string = "Player"
		if pPlayerConfig:GetNickName() ~= nil then
			name = pPlayerConfig:GetNickName()
			else
			name = pPlayerConfig:GetPlayerName()
		end
		statusMessage = Locale.Lookup(name);
		if(Network.IsPlayerKicked(playerID)) then
			statusMessage = statusMessage .. " " .. TXT_PLAYER_KICKED_CHAT;
		else
    		statusMessage = statusMessage .. " " .. TXT_PLAYER_DISCONNECTED_CHAT;
		end
		OnStatusMessage(statusMessage, DEFAULT_TIME_TO_DISPLAY, ReportingStatusTypes.DEFAULT);
	end
end