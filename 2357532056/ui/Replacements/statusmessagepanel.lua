-- Copyright 2016-2019, Firaxis Games
-- Non-interactive messages (e.g., Gossip and combat results) that appear in the upper-center of the screen.

include( "InstanceManager" );
print("MPH StatusMessagePanel Replacement")

-- =========================================================================== 
--	CONSTANTS
-- =========================================================================== 
local debug_testActive				:boolean = false;	-- (false) Enable test messages and hot keys D, and G
local DEFAULT_TIME_TO_DISPLAY		:number = 7;		-- Seconds to display the message
local TXT_PLAYER_CONNECTED_CHAT		:string = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_CHAT" );
local TXT_PLAYER_DISCONNECTED_CHAT  :string	= Locale.Lookup( "LOC_MP_PLAYER_DISCONNECTED_CHAT" );
local TXT_PLAYER_KICKED_CHAT		:string	= Locale.Lookup( "LOC_MP_PLAYER_KICKED_CHAT" );


-- =========================================================================== 
--	MEMBERS
-- =========================================================================== 
local m_gossipIM		:table = InstanceManager:new( "GossipMessageInstance", "Root", Controls.GossipStack );
local m_statusIM		:table = InstanceManager:new( "StatusMessageInstance", "Root", Controls.DefaultStack );
local m_kGossip			:table = {};
local m_isGossipExpanded:boolean = false;
local m_kMessages		:table = {};
local g_spec			:boolean = false;
local g_anon			:boolean = false;		


-- =========================================================================== 
--	FUNCTIONS
-- =========================================================================== 


-- =========================================================================== 
--	EVENT
--	subType	when gossip it's the db enum for the gossip type
-- =========================================================================== 
function OnStatusMessage( message:string, displayTime:number, type:number, subType:number )
	if Game.GetLocalPlayer() == nil then
		return
	end
	
	local localPlayerID = Game.GetLocalPlayer()
	if PlayerConfigurations[localPlayerID]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
		g_spec = true
	end

	if (type == ReportingStatusTypes.GOSSIP) and not g_spec then
		AddGossip( subType, message, displayTime );
	end

	if (type == ReportingStatusTypes.DEFAULT) then
		AddDefault( message, displayTime );
	end

	RealizeMainAreaPosition();
end

-- =========================================================================== 
--	Realize the first Gossip in the list.
-- =========================================================================== 
function RealizeFirstGossip()
	local num:number = table.count(m_kGossip);
	if num < 1 then
		return;
	end	
	local uiInstance:table= m_kGossip[1].uiInstance;
	if uiInstance.Root:IsHidden() then
		uiInstance.Root:SetHide( false );
	end
	uiInstance.ExpandButton:SetHide( num == 1 );
	uiInstance.ExpandButton:SetSelected( m_isGossipExpanded );
end

-- =========================================================================== 
--	Add a gossip entry.
-- =========================================================================== 
function AddGossip( eGossipType:number, message:string, optionalDisplayTime:number )
	if optionalDisplayTime == nil or optionalDisplayTime == 0 then
		optionalDisplayTime = DEFAULT_TIME_TO_DISPLAY;
	end

	-- Add visually
	local uiInstance	:table = m_gossipIM:GetInstance();
	local kGossipData	:table = GameInfo.Gossips[eGossipType];		-- Lookup via hash
	if kGossipData then
		uiInstance.Icon:SetIcon("ICON_GOSSIP_"..kGossipData.GroupType);
		uiInstance.IconBack:SetIcon("ICON_GOSSIP_"..kGossipData.GroupType);
	else
		UI.DataError("The gossip type '"..tostring(eGossipType).."' could not be found in the database; icon will not be set.");
	end

	uiInstance.Message:SetText( message );
	
	-- Add the data (including reference to visual)
	local kEntry:table = {
		eGossipType = eGossipType,
		message		= message,
		displayTime = optionalDisplayTime,
		uiInstance	= uiInstance
	};
	table.insert( m_kGossip, kEntry);

	local GOSSIP_VERTICAL_PADDING	:number = 20;
	local verticalSpace				:number = uiInstance.Message:GetSizeY() + GOSSIP_VERTICAL_PADDING;
	
	uiInstance.Root:SetHide( false );
	uiInstance.Content:SetSizeY( verticalSpace );
	uiInstance.Anim:SetEndPauseTime( optionalDisplayTime );
	uiInstance.Anim:SetToBeginning();
	uiInstance.ExpandButton:SetHide( true );

	-- This may or may not be the first button and if this is the second gossip
	-- then the first gossip needs to be realized to show the collapse button.
	RealizeFirstGossip( uiInstance );

	-- If showing all gossips or if this is the first in the list, then start animation.
	local isFirstGossip:boolean = table.count(m_kGossip)==1;	
	if m_isGossipExpanded or (m_isGossipExpanded==false and isFirstGossip) then
		uiInstance.Anim:Play();		
	end

	-- Now thata data exists, create lambdas that passes it in.
	uiInstance.Anim:RegisterEndCallback(					function() OnGossipEndAnim(kEntry,uiInstance) end );
	uiInstance.Button:RegisterCallback( Mouse.eLClick,		function() OnGossipClicked(kEntry,uiInstance); end );
	uiInstance.Button:RegisterCallback( Mouse.eRClick,		function() OnGossipClicked(kEntry,uiInstance); end );
	uiInstance.ExpandButton:RegisterCallback( Mouse.eLClick,function() OnToggleGossipExpand(kEntry,uiInstance); end );
	
	-- Hide this if not the first and list is collapsed.
	local numGossips:number = table.count(m_kGossip);
	if m_isGossipExpanded==false and (numGossips > 1) then
		uiInstance.Root:SetHide( true );
	end
end

-- ===========================================================================
function RemoveGossip( kEntry:table, uiInstance:table )
	-- Remove callbacks and visuals
	uiInstance.Anim:ClearEndCallback();	
	uiInstance.Anim:ClearAnimCallback();	
	m_gossipIM:ReleaseInstance( uiInstance );	
	-- Remove data
	for i,kTableEntry in ipairs(m_kGossip) do
		if kTableEntry == kEntry then
			table.remove( m_kGossip, i, 1);
			break;
		end
	end

	-- Look through and set animation appropriately.
	for i,kTableEntry in ipairs(m_kGossip) do
		local uiInstance :table = kTableEntry.uiInstance;
		uiInstance.Anim:SetToEnd();
		if i==1 then
			uiInstance.Anim:Play();
		else
			uiInstance.Anim:Stop();
		end
		uiInstance.Root:SetHide( m_isGossipExpanded==false );
	end
	RealizeFirstGossip();

	Controls.DefaultStack:CalculateSize();
end

-- ===========================================================================
function RemoveAllGossip()
	if table.count(m_kGossip) == 0 then
		return;
	end
	for i,kTableEntry in ipairs(m_kGossip) do
		local uiInstance :table = kTableEntry.uiInstance;
		uiInstance.Anim:Stop();
		uiInstance.Root:SetHide( true );
	end
	m_gossipIM:ResetInstances();
	m_kGossip = {};
end

-- ===========================================================================
--	UI Callback
--	Clicked to dismiss message
-- ===========================================================================
function OnGossipClicked( kEntry:table, uiInstance:table )
	UI.PlaySound("Play_UI_Click");
	RemoveGossip(kEntry, uiInstance );
end

-- ===========================================================================
--	UI Callback
--	Clicked to dismiss message
-- ===========================================================================
function OnToggleGossipExpand( kEntry:table, uiInstance:table )

	m_isGossipExpanded = not m_isGossipExpanded;

	-- Expanded: Show all and reset animation.
	if m_isGossipExpanded then
		for i,kGossip in ipairs(m_kGossip) do
			local uiInstance:table = kGossip.uiInstance;
			uiInstance.Root:SetHide( false );
			uiInstance.ExpandButton:SetSelected( true );
			uiInstance.Anim:SetToEnd();
			if i==1 then
				uiInstance.Anim:Play();
			else
				uiInstance.Anim:Stop();
			end
		end
		return;
	end

	-- Collapsed: only showing the first gossip.
	for i,kGossip in ipairs(m_kGossip) do
		local uiInstance:table = kGossip.uiInstance;
		uiInstance.Root:SetHide( i>1 );
		uiInstance.ExpandButton:SetSelected( false );
		uiInstance.Anim:SetToEnd();
		if i==1 then
			uiInstance.Anim:Play();
		else
			uiInstance.Anim:Stop();
			uiInstance.ExpandButton:SetHide( true );
		end
	end
end

-- ===========================================================================
function OnGossipEndAnim( kEntry:table, uiInstance:table )
	RemoveGossip( kEntry, uiInstance );
end






-- =========================================================================== 
--	Add default message (e.g., combat messages)
-- =========================================================================== 
function AddDefault( message, displayTime )

	-- TODO: Simplify
	local type = ReportingStatusTypes.DEFAULT 
	local kTypeEntry :table = m_kMessages[type];
	if (kTypeEntry == nil) then
		-- New type
		m_kMessages[type] = {
			InstanceManager = nil,
			MessageInstances= {}
		};
		kTypeEntry = m_kMessages[type];

		kTypeEntry.InstanceManager	= m_statusIM;
	end

	local uiInstance:table = kTypeEntry.InstanceManager:GetInstance();
	table.insert( kTypeEntry.MessageInstances, uiInstance );

	if displayTime==nil or displayTime==0 then
		displayTime = DEFAULT_TIME_TO_DISPLAY;
	end
	uiInstance.Message:SetText( message );

	uiInstance.Button:RegisterCallback( Mouse.eLClick, function() OnMessageClicked(kTypeEntry,uiInstance) end );
	uiInstance.Anim:SetEndPauseTime( displayTime );		
	uiInstance.Anim:RegisterEndCallback( function() OnEndAnim(kTypeEntry,uiInstance) end );
	uiInstance.Anim:SetToBeginning();
	uiInstance.Anim:Play();		

	Controls.DefaultStack:CalculateSize();
end

-- ===========================================================================
function RemoveMessage( kTypeEntry:table, uiInstance:table )
	uiInstance.Anim:ClearEndCallback();
	Controls.DefaultStack:CalculateSize();
	kTypeEntry.InstanceManager:ReleaseInstance( uiInstance );
end

-- ===========================================================================
function OnEndAnim( kTypeEntry:table, uiInstance:table )
	RemoveMessage( kTypeEntry, uiInstance );
end

-- ===========================================================================
function OnMessageClicked( kTypeEntry:table, uiInstance:table )
	RemoveMessage( kTypeEntry, uiInstance );
end

-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnMultplayerPlayerConnected( playerID:number )
	if playerID == -1 or playerID == 1000 then
		return;
	end

	if( ContextPtr:IsHidden() == false and GameConfiguration.IsNetworkMultiplayer() ) then
		local pPlayerConfig :table = PlayerConfigurations[playerID];
		local statusMessage :string= Locale.Lookup(pPlayerConfig:GetPlayerName()) .. " " .. TXT_PLAYER_CONNECTED_CHAT;
		if g_anon == true and not g_spec then
			statusMessage = "Player #"..playerID.. " " .. TXT_PLAYER_CONNECTED_CHAT;	
		end
		OnStatusMessage( statusMessage, DEFAULT_TIME_TO_DISPLAY, ReportingStatusTypes.DEFAULT );
	end
end

-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnMultiplayerPrePlayerDisconnected( playerID:number )
	if playerID == -1 or playerID == 1000 then
		return;
	end

	if( ContextPtr:IsHidden() == false and GameConfiguration.IsNetworkMultiplayer() ) then
		local pPlayerConfig :table = PlayerConfigurations[playerID];
		local statusMessage :string= Locale.Lookup(pPlayerConfig:GetPlayerName());
		if g_anon == true and not g_spec then
			statusMessage = "Player #"..playerID;	
		end
		if(Network.IsPlayerKicked(playerID)) then
			statusMessage = statusMessage .. " " .. TXT_PLAYER_KICKED_CHAT;
		else
    		statusMessage = statusMessage .. " " .. TXT_PLAYER_DISCONNECTED_CHAT;
		end
		OnStatusMessage(statusMessage, DEFAULT_TIME_TO_DISPLAY, ReportingStatusTypes.DEFAULT);
	end
end

-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnLocalTurnEnd( a,b,c )	
	local playerID	:number = Game.GetLocalPlayer();
	if playerID == -1 or playerID == 1000 then return; end;
	RemoveAllGossip();
end

-- ===========================================================================
--	Testing: When on the "G" and "D" keys generate messages.
-- ===========================================================================
function DebugTest()
	OnStatusMessage("Press D,F or G to generate gossip.  Hold Shift+D or G to generate notifications.", 7, ReportingStatusTypes.DEFAULT );
	ContextPtr:SetInputHandler( 
		function( pInputStruct ) 
			local uiMsg = pInputStruct:GetMessageType();
			if uiMsg == KeyEvents.KeyUp then 
				local key = pInputStruct:GetKey();
				local type = pInputStruct:IsShiftDown() and ReportingStatusTypes.DEFAULT or ReportingStatusTypes.GOSSIP ;
				local subType = DB.MakeHash("GOSSIP_MAKE_DOW");
				if key == Keys.D then OnStatusMessage("Testing out status message ajsdkl akds dk dkdkj dkdkd ajksaksdkjkjd dkadkj f djkdkjdkj dak sdkjdjkal dkd kd dk adkj dkkadj kdjd kdkjd jkd jd dkj djkd dkdkdjdkdkjdkd djkd dkd dkjd kdjdkj d", 7, type, subType); return true; end
				if key == Keys.F then OnStatusMessage("The rain in Spain will dry quickly in Madrid.", 7, type, subType); return true; end
				if key == Keys.G then OnStatusMessage("Testing out gossip message", nil, type, subType ); return true; end
			end	
			return false;
		end, true);
end


-- ===========================================================================
--	Position to just below the height of the diplomacy ribbon scroll area
-- ===========================================================================
function RealizeMainAreaPosition()
	
	local m_uiRibbonScroll :table	= ContextPtr:LookUpControl( "/InGame/DiplomacyRibbon/ScrollContainer" );
	if m_uiRibbonScroll == nil then
		return
	end
	local ribbonHeight:number = m_uiRibbonScroll:GetSizeY();

	-- Bail if no change.
	local EXTRA_CLEARANCE	:number = 50;
	local currentOffsetY	:number = Controls.MainArea:GetOffsetY();
	if currentOffsetY == (ribbonHeight + EXTRA_CLEARANCE) then
		return;
	end

	-- Set starting height of stack to just below ribbon.	
	Controls.MainArea:SetOffsetY( ribbonHeight + EXTRA_CLEARANCE );	
end


-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnShutdown()
	Events.LocalPlayerTurnEnd.Remove( OnLocalTurnEnd );
	Events.StatusMessage.Remove( OnStatusMessage );
	Events.MultiplayerPlayerConnected.Remove( OnMultplayerPlayerConnected );
	Events.MultiplayerPrePlayerDisconnected.Remove( OnMultiplayerPrePlayerDisconnected );
end

-- ===========================================================================
function LateInitialize()
	RealizeMainAreaPosition();
	if GameConfiguration.GetValue("GAMEMODE_ANONYMOUS") == true then
		g_anon = true
	end

	Events.LocalPlayerTurnEnd.Add( OnLocalTurnEnd );
	Events.StatusMessage.Add( OnStatusMessage );
	Events.MultiplayerPlayerConnected.Add( OnMultplayerPlayerConnected );
	Events.MultiplayerPrePlayerDisconnected.Add( OnMultiplayerPrePlayerDisconnected );
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnInit()
	LateInitialize();
end

-- ===========================================================================
--	
-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	if debug_testActive then DebugTest(); end	-- Enable debug mode?
	if GameConfiguration.GetValue("GAMEMODE_ANONYMOUS") == true then
		g_anon = true
	end
end
if GameCapabilities.HasCapability("CAPABILITY_DISPLAY_HUD_GOSSIP_LIST") then
	Initialize();
end

