-- Copyright 2016-2019, Firaxis Games
-- (Multiplayer) Drop Control By D. / Jack The Narrator
print("MPH Drop Control")
include("InstanceManager");
include("PopupDialog");

-- ===========================================================================
--	Variables
-- ===========================================================================
UIEvents = ExposedMembers.LuaEvents;
local _kPopupDialog = {}
local g_dropped_player_list = {};
local m_visible = false
local m_last_update = 0

-- ===========================================================================
--	New Functions
-- ===========================================================================
function OnMultiplayerPrePlayerDisconnected( playerID )
	--print ("Time Disconnect", os.date("%c"))
	ContextPtr:SetHide(false);
	local hostID = Network.GetGameHostPlayerID()
	local localID = Network.GetLocalPlayerID()
	m_visible = true
	if localID == hostID then
		Controls.HostLabel:SetText(Locale.Lookup("LOC_MPH_DROP_HOST_WARNING_TEXT"))
		Controls.Button_Resume:RegisterCallback( Mouse.eLClick, OnHostResume );
		Controls.Button_Resume:SetText(Locale.Lookup("LOC_MPH_DROP_HOST_BUTTON_TEXT"))
		else
		Controls.HostLabel:SetText("")
		Controls.Button_Resume:RegisterCallback( Mouse.eLClick, OnClose );
		Controls.Button_Resume:SetText(Locale.Lookup("LOC_MPH_DROP_NORMAL_BUTTON_TEXT"))
	end
	
	if (localID == hostID and GameConfiguration.IsPaused() == false) then
		local localPlayerID = localID;
		local localPlayerConfig = PlayerConfigurations[localPlayerID];
		local newPause = not localPlayerConfig:GetWantsPause();
		localPlayerConfig:SetWantsPause(newPause);
		Network.BroadcastPlayerInfo();
	end
	
	UpdateData(playerID,true)
	UIEvents.UICPLPlayerDrop( playerID );
end


function OnMultplayerPlayerConnected( playerID )
	--print ("Time Connected", os.date("%c"))
	if g_dropped_player_list ~= {} then
		for i, player in ipairs(g_dropped_player_list) do
			if player.ID == playerID and player.IsDropped == true then
				UIEvents.UICPLPlayerConnect( playerID );
				UpdateData(playerID,false)
				GameConfiguration.SetTurnTimerType("TURNTIMER_NONE")
				Network.BroadcastGameConfig()
			end
		end	
	end

end

function UpdateData(playerID:number,disconnected:boolean)
	if disconnected == true then
		if g_dropped_player_list == {} then
			local tmp = {}
			tmp = { ID = playerID, RefTime = math.floor(Automation.GetTime()), ElapsedTime = 0, IsDropped = true }
			table.insert(g_dropped_player_list,tmp)
			else
			local b_exist = false
			for i, player in ipairs(g_dropped_player_list) do
				if player.ID == playerID then
					player.RefTime = math.floor(Automation.GetTime())
					player.IsDropped = true
					b_exist = true
				end
			end
			if b_exist == false then
				tmp = { ID = playerID, RefTime = math.floor(Automation.GetTime()), ElapsedTime = 0, IsDropped = true }
				table.insert(g_dropped_player_list,tmp)			
			end
		end
		Events.GameCoreEventPublishComplete.Add ( OnTimeTicks );
		else
		if g_dropped_player_list ~= {} then
			for i, player in ipairs(g_dropped_player_list) do
				if player.ID == playerID then
					player.IsDropped = false
				end
			end	
		end
		local b_allback = true
		if g_dropped_player_list ~= {} then
			for i, player in ipairs(g_dropped_player_list) do
				if player.IsDropped == true then
					b_allback = false
				end
			end	
		end 
		if b_allback == true then
			Events.GameCoreEventPublishComplete.Remove ( OnTimeTicks );
			OnClose()
		end
	end
end

function OnTimeTicks()
	local currentTime = math.floor(Automation.GetTime())
	local b_everyoneisingame = true
	for i, player in ipairs(g_dropped_player_list) do
		if player.IsDropped == true then
			b_everyoneisingame = false
			if currentTime > player.RefTime then
				player.ElapsedTime = player.ElapsedTime + currentTime - player.RefTime
				player.RefTime = currentTime
			end
		end
	end	
	if m_visible == true and (m_last_update < currentTime + 10) then
		m_last_update = currentTime
		UpdateText()
	end
	if b_everyoneisingame == true then
		Events.GameCoreEventPublishComplete.Remove ( OnTimeTicks );
		OnClose()
	end
end

function UpdateText()
	local str = ""
	for i, player in ipairs(g_dropped_player_list) do
		if player.IsDropped == true then
			str = str..tostring(Locale.Lookup(PlayerConfigurations[player.ID]:GetPlayerName())).."  -  "
			if player.ElapsedTime > 600 then
				str = str.."[COLOR_Civ6Red]"..tostring(player.ElapsedTime).."[ENDCOLOR][NEWLINE]"
				else
				str = str.."[COLOR_Civ6Green]"..tostring(player.ElapsedTime).."[ENDCOLOR][NEWLINE]"
			end
		end
	end	
	Controls.DropPlayerList:SetText(tostring(str))
end

-- ===========================================================================
--	Callback
-- ===========================================================================
function OnShutdown()
	ContextPtr:SetHide(true);
	Events.MultiplayerPlayerConnected.Remove ( OnMultplayerPlayerConnected )
	Events.MultiplayerPrePlayerDisconnected.Remove ( OnMultiplayerPrePlayerDisconnected )
end

function OnHostResume()
	m_visible = false
	ConfirmResume()
end

function ConfirmResume()
	local localID = Network.GetLocalPlayerID()
	if localID == Network.GetGameHostPlayerID() then
		if _kPopupDialog == nil then
		_kPopupDialog = PopupDialog:new( "VotePanel" );
		end

		if (not _kPopupDialog:IsOpen()) then
			_kPopupDialog:AddCountDown(30,OnYesResume)
			_kPopupDialog:AddTitle("Resume Game");
			_kPopupDialog:AddText("Are you sure to resume the game?");
			_kPopupDialog:AddButton( "Yes", OnYesResume, nil, nil, "PopupButtonInstanceRed" );
			_kPopupDialog:AddButton( "No", OnNoResume );
			_kPopupDialog:Open();
		end
	end
end


function OnYesResume( )
	ContextPtr:SetHide(true);
	for i, player in ipairs(g_dropped_player_list) do
		if player.IsDropped == true then
			player.IsDropped = false
			player.RefTime =  math.floor(Automation.GetTime())
			UIEvents.UICPLPlayerConnect( player.ID );
		end
	end	
	m_visible = false
	_kPopupDialog:Close();
	ContextPtr:SetHide(true);
end

function OnNoResume( )
	_kPopupDialog:Close();
	ContextPtr:SetHide(false);
	m_visible = true
end


function OnClose()
	ContextPtr:SetHide(true);
	m_visible = false
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetHide(true);
	ContextPtr:SetShutdown( OnShutdown );
	Controls.DropTitle:SetText(Locale.Lookup("LOC_MPH_DROP_TITLE_TEXT"))
	Controls.DropLabel:SetText(Locale.Lookup("LOC_MPH_DROP_LABEL_TEXT"))
	_kPopupDialog = PopupDialog:new( "DropControl" );
	Events.MultiplayerPlayerConnected.Add( OnMultplayerPlayerConnected );
	Events.MultiplayerPrePlayerDisconnected.Add( OnMultiplayerPrePlayerDisconnected );
end
Initialize();
