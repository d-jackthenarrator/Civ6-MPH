-------------------------------------------------
-- Player Setup Logic
-------------------------------------------------
include( "InstanceManager" );
include( "GameSetupLogic" );
include( "SupportFunctions" );
include( "Civ6Common" ); --GetLeaderUniqueTraits

g_PlayerParameters = {};
local m_currentInfo = {											--m_currentInfo is a duplicate of the data which is currently selected for the local player
		CivilizationIcon = "ICON_CIVILIZATION_UNKNOWN",
		LeaderIcon = "ICON_LEADER_DEFAULT",
		CivilizationName = "LOC_RANDOM_CIVILIZATION",
		LeaderName = "LOC_RANDOM_LEADER"
	};

local m_tooltipControls = {};

-------------------------------------------------------------------------------
-- Parameter Hooks
-------------------------------------------------------------------------------
function Player_ReadParameterValues(o, parameter)
	
	-- This is a bit of a hack.   First, obtain the player's type ID to see if it's -1.
	-- If not -1, then use typename.
	if(parameter.ParameterId == "PlayerLeader") then	
		local playerConfig = PlayerConfigurations[o.PlayerId];
		if(playerConfig) then

			local value = playerConfig:GetLeaderTypeID();
			if(value ~= -1) then
				value = playerConfig:GetLeaderTypeName();
			else
				value = "RANDOM";
			end


			return value;
		end
	else
		return SetupParameters.Config_ReadParameterValues(o, parameter);
	end
end

function Player_WriteParameterValues(o, parameter)

	-- This is a hack.  Right now changing a player's leader requires many explicit calls in a specific order.
	-- Ultimately, this *should* be a matter of setting a single key that represents the player.
	-- This was pulled from PlayerSetupLogic.
	if(parameter.ParameterId == "PlayerLeader" and o:Config_CanWriteParameter(parameter)) then	
		local playerConfig = PlayerConfigurations[o.PlayerId];
		if(playerConfig) then
			if(parameter.Value ~= nil) then
				local value = parameter.Value.Value;
				if(value == -1 or value == "RANDOM") then
					playerConfig:SetLeaderName(nil);
					playerConfig:SetLeaderTypeName(nil);
				else
					local leaderType:string = parameter.Value.Value;

					playerConfig:SetLeaderName(parameter.Value.RawName or parameter.Value.Name);


					playerConfig:SetLeaderTypeName(leaderType);
				end
			else
				playerConfig:SetLeaderName(nil);
				playerConfig:SetLeaderTypeName(nil);
			end

			o:Config_WriteAuxParameterValues(parameter);					
			
			Network.BroadcastPlayerInfo(o.PlayerId);
			return true;
		end
	else
		local result = SetupParameters.Config_WriteParameterValues(o, parameter);
		if(result and o.PlayerId ~= nil) then
			Network.BroadcastPlayerInfo(o.PlayerId);
		end
		return result;
	end
end


-- The method used to create a UI control associated with the parameter.
function Player_UI_CreateParameter(o, parameter)
	-- Do nothing for now.  Player controls are explicitly instantiated in the UIs.
end


-- Called whenever a parameter is no longer relevant and should be destroyed.
function Player_UI_DestroyParameter(o, parameter)
	-- Do nothing for now.  Player controls are explicitly instantiated in the UIs.
end


-------------------------------------------------------------------------------
-- Create parameters for all players.
-------------------------------------------------------------------------------
function CreatePlayerParameters(playerId, bHeadless)
	SetupParameters_Log("Creating player parameters for Player " .. tonumber(playerId));

	-- Don't create player parameters for minor city states.  The configuration database doesn't know city state parameter values (like city state leader types) so it will stomp on them.
	local playerConfig = PlayerConfigurations[playerId];
	--if(playerConfig == nil or playerConfig:GetCivilizationLevelTypeID() ~= CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV) then
	--	return nil;
	--end

	local parameters = SetupParameters.new(playerId);
	
	-- Setup hooks.
	parameters.Parameter_GetRelevant = GetRelevantParameters;
	parameters.Config_EndWrite = Parameters_Config_EndWrite;

	-- Player specific hooks.
	-- This player logic is a bit weird due to some assumptions made in the staging room.
	-- Right now player-based parameters are not dynamically generated :(
	-- Instead, the leader pulldown, optional team pulldown and optional handicap pulldown
	-- are all allocated by the UI explicitly.
	-- Team pulldown is entirely managed in the staging room =\
	-- For now, the UI logic looks for predefined controls and populates but does not generate.
	-- In the future, I hope this can be more like the GameSetup and allow for unique player parameters to be created.
	parameters.Config_ReadParameterValues = Player_ReadParameterValues;
	parameters.Config_WriteParameterValues = Player_WriteParameterValues;


	-- Stub out Visualization function to do nothing if headless.
	-- While the UI_ methods should no longer be called because of this, nil them out just in case.
	if(bHeadless) then
		parameters.UpdateVisualization = function() end
	end
	parameters.UI_CreateParameter = (bHeadless ~= true) and Player_UI_CreateParameter;
	parameters.UI_DestroyParameter = (bHeadless ~= true) and Player_UI_DestroyParameter;
	parameters.UI_SetParameterPossibleValues = (bHeadless ~= true) and UI_SetParameterPossibleValues;
	parameters.UI_SetParameterValue = (bHeadless ~= true) and UI_SetParameterValue;
	parameters.UI_SetParameterEnabled = (bHeadless ~= true) and UI_SetParameterEnabled;
	parameters.UI_SetParameterVisible = (bHeadless ~= true) and UI_SetParameterVisible;

	parameters:Initialize();

	-- Treat g_PlayerParameters as an array to guarantee order of operations.
	table.insert(g_PlayerParameters, {playerId, parameters});
	table.sort(g_PlayerParameters, function(a,b) 
		return a[1] < b[1];
	end);

	return parameters;
end

function GetPlayerParameters(player_id)
	for i, v in ipairs(g_PlayerParameters) do
		if(v[1] == player_id) then
			return v[2];
		end
	end
end

function RebuildPlayerParameters(bHeadless)
	g_PlayerParameters = {};

	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
	SetupParameters_Log("There are " .. #player_ids .. " participating players.");
	for i, player_id in ipairs(player_ids) do	
		CreatePlayerParameters(player_id, bHeadless);
	end
end

function RefreshPlayerParameters()
	SetupParameters_Log("Refresh Player Parameters");
	for i,v in ipairs(g_PlayerParameters) do
		v[2]:Refresh();
	end
	SetupParameters_Log("End Refresh Player Parameters");
end

function VisualizePlayerParameters()
	SetupParameters_Log("Visualizing Player Parameters");
	for i,v in ipairs(g_PlayerParameters) do
		v[2]:UpdateVisualization();
	end
	SetupParameters_Log("End Visualizing Player Parameters");
end

function ReleasePlayerParameters()
	SetupParameters_Log("Releasing Player Parameters");
	for i,v in ipairs(g_PlayerParameters) do
		v[2]:Shutdown();
	end

	g_PlayerParameters = {};
end

function GetPlayerParameterError(playerId)
	for i, pp in ipairs(g_PlayerParameters) do
		local id = pp[1];
		if(id == playerId) then

			local p = pp[2];	
			if(p and p.Parameters) then
				-- For now, test a specific parameter.
				-- This could probably be generalized to enumerate all
				-- parameters.
				local playerLeader = p.Parameters["PlayerLeader"];
				if(playerLeader) then
					-- TTP 31558 - In multiplayer, Open and Closed slots have nil for most of their player configuration values because the slots have not been reset yet.
					-- On the client, the player setup logic will try to change the nil values to their default values and fail because the client does not have write access.
					-- This is OK and should not count as a player parameter error, which would block game start incorrectly.
					local pPlayerConfig = PlayerConfigurations[playerId];
					if(pPlayerConfig ~= nil and not pPlayerConfig:IsParticipant()) then
						return nil;
					else
						return playerLeader.Error;
					end
				end
			end
		end
	end
end

function GetGameParametersError()
	if(g_GameParameters) then
		return g_GameParameters.Error or g_GameParameters.Stalled and "Stalled";
	end
end

function CanShowLeaderAbility(playerInfo : table)
	if (playerInfo.LeaderAbilityName and playerInfo.LeaderAbilityDescription and playerInfo.LeaderAbilityIcon) then
		return playerInfo.LeaderAbilityName ~= "NONE" and playerInfo.LeaderAbilityDescription ~= "NONE" and playerInfo.LeaderAbilityIcon ~= "NONE";
	end
	return false;
end

function CanShowCivAbility(playerInfo : table)
	if (playerInfo.CivilizationAbilityName and playerInfo.CivilizationAbilityDescription and playerInfo.CivilizationAbilityIcon) then
		return playerInfo.CivilizationAbilityName ~= "NONE" and playerInfo.CivilizationAbilityDescription ~= "NONE" and playerInfo.CivilizationAbilityIcon ~= "NONE";
	end
	return false;
end    

-- Obtain additional information about a specific player value.
-- Returns a table containing the following fields:
--	CivilizationIcon					-- The icon id representing the civilization.
--	LeaderIcon							-- The icon id representing the leader.
--	CivilizationName					-- The name of the Civilization.
--	LeaderName							-- The name of the Leader.
--	LeaderType							-- The type name of the leader (to derive the standing portrait/background images)
--  LeaderAbility = {					-- (nullable) A table containing details about the Leader's primary ability.
--		Name							-- The name of the Leader's primary ability.
--		Description						-- The description of the Leader's primary ability.
--		Icon							-- The icon of the Leader's primary ability.
--  },
--  CivilizationAbility = {				-- (nullable) A table containing details about the Civilization's primary ability.
--		Name							-- The name of the Civilization's primary ability.
--		Description						-- The description of the Civilization's primary ability.
--		Icon							-- The icon of the Civilization's primary ability.
--  },
--	Uniques = {							-- (nullable) An array of unique items.
--		{
--			Name,						-- The name of the unique item.
--			Description,				-- The description of the unique item.
--			Icon,						-- The icon of the unique item.
--		}
--	},

local _GetPlayerIconsCache = {};
local _GetPlayerIconsDefaultValue = {
	LeaderIcon = "ICON_LEADER_DEFAULT",  
	CivIcon = "ICON_CIVILIZATION_UNKNOWN"
};

function GetPlayerIcons(domain, leader_type)
	-- Kludge:  We're special casing random for now.
	-- this will eventually change and 'RANDOM' will
	-- be just another row in the players entry.
	-- This can't happen until GameCore supports 
	-- multiple 'random' pools.

	
	
	if(leader_type ~= "RANDOM") then

		-- Does the cache need to be invalidated?
		local changes = DB.ConfigurationChanges();
		if(changes ~= _GetPlayerIconsCache[1]) then
			_GetPlayerIconsCache = {changes};
		end

		-- Create single key to look up rather than use a 2D array.
		local key = domain .. "|" .. leader_type;
		local value = _GetPlayerIconsCache[key];
		if(value) then
			return value;
		else
			local info_query = "SELECT CivilizationIcon, LeaderIcon, PlayerColor from Players where Domain = ? and LeaderType = ? LIMIT 1";
			local results = CachedQuery(info_query, domain, leader_type);		
			if(results) then
				local row = results[1];
				if row == nil then
					return _GetPlayerIconsDefaultValue;
				end
				local playerColor = row.PlayerColor or leader_type;

				local info = {
					LeaderIcon = row.LeaderIcon, 
					CivIcon = row.CivilizationIcon,
					PlayerColor = playerColor
				};
				
				-- Cache it.
				_GetPlayerIconsCache[key] = info;

				return info;
			end
		end
	end

	return _GetPlayerIconsDefaultValue;
end

function GetPlayerInfo(domain, leader_type)
	-- Kludge:  We're special casing random for now.
	-- this will eventually change and 'RANDOM' will
	-- be just another row in the players entry.
	-- This can't happen until GameCore supports 
	-- multiple 'random' pools.
	if(leader_type ~= "RANDOM") then
		local info_query = "SELECT CivilizationIcon, LeaderIcon, LeaderName, CivilizationName, LeaderAbilityName, LeaderAbilityDescription, LeaderAbilityIcon, CivilizationAbilityName, CivilizationAbilityDescription, CivilizationAbilityIcon, Portrait, PortraitBackground, PlayerColor from Players where Domain = ? and LeaderType = ? LIMIT 1";
		local item_query = "SELECT Name, Description, Icon from PlayerItems where Domain = ? and LeaderType = ? ORDER BY SortIndex";
		local info_results = CachedQuery(info_query, domain, leader_type);
		local item_results = CachedQuery(item_query, domain, leader_type);
		
		if(info_results and item_results) then
			local info = {};
			info.LeaderType = leader_type;
			for i,row in ipairs(info_results) do
				
				info.PlayerColor = row.PlayerColor or leader_type;
				info.CivilizationIcon= row.CivilizationIcon;
				info.LeaderIcon= row.LeaderIcon;
				info.LeaderName = row.LeaderName;
				info.CivilizationName = row.CivilizationName;
				info.Portrait = row.Portrait;
				info.PortraitBackground = row.PortraitBackground;
				if (CanShowLeaderAbility(row)) then
					info.LeaderAbility = {
						Name = row.LeaderAbilityName,
						Description = row.LeaderAbilityDescription,
						Icon = row.LeaderAbilityIcon
					};
				end

				if (CanShowCivAbility(row)) then
					info.CivilizationAbility = {
						Name = row.CivilizationAbilityName,
						Description = row.CivilizationAbilityDescription,
						Icon = row.CivilizationAbilityIcon
					};
				end
			end

			info.Uniques = {};
			for i,row in ipairs(item_results) do
				table.insert(info.Uniques, {
					Name = row.Name,
					Description = row.Description,
					Icon = row.Icon
				});
			end
			return info;
		end
	end

	return {
		CivilizationIcon = "ICON_CIVILIZATION_UNKNOWN",
		LeaderIcon = "ICON_LEADER_DEFAULT",
		CivilizationName = "LOC_RANDOM_CIVILIZATION",
		LeaderName = "LOC_RANDOM_LEADER",
	};
end

function GenerateToolTipFromPlayerInfo(info)
	local lines = {};
	table.insert(lines, Locale.Lookup(info.LeaderName));
	table.insert(lines, Locale.Lookup(info.CivilizationName));
	if(info.CivilizationAbility) then
		local ability = info.CivilizationAbility;
		table.insert(lines, "--------------------------------");
		table.insert(lines, Locale.Lookup(ability.Name));
		table.insert(lines, Locale.Lookup(ability.Description));
	end

	if(info.LeaderAbility) then
		local ability = info.LeaderAbility;
		table.insert(lines, "--------------------------------");
		table.insert(lines, Locale.Lookup(ability.Name));
		table.insert(lines, Locale.Lookup(ability.Description));
	end

	if(info.Uniques and #info.Uniques > 0) then
		table.insert(lines, "--------------------------------");
		for i,v in ipairs(info.Uniques) do
			table.insert(lines, Locale.Lookup(v.Name));
			table.insert(lines, Locale.Lookup(v.Description) .. "[NEWLINE]");

		end
	end
	
	return table.concat(lines, "[NEWLINE]");
end

-- ===========================================================================
--	Correctly displays a special flyout for the leader selection dropdown.
--	info:				The leader and civ info that we will use to set the data
--	tooltipControls:	All of the data required for generating the tooltip.  Includes:
--							InfoStack			table	- The primary stack which holds all the data for the panel
--							InfoScrollPanel		table	- The scrollpanel for the flyout
--							UniqueIconIM		table	- Instance manager for the unique civ abilities/units
--							HeaderIconIM		table	- Instance manager for the header icon (has a different backing)
--							HeaderIM			table	- Instance manager for the headers 
--							CivToolTipSlide		table	- Flyout animation slide
--							CivToolTipAlpha		table	- Flyout animation alpha
--							HasLeaderPlacard	boolean - Indicates whether or not this tooltip should also display the leader placard flyout
--							LeaderBG			table	- The background image displayed behind the leader
--							LeaderImage			table	- The leader image
--							DummyImage			table	- This dummy image is used so that we can calculate the ratio of the original leader image.  
--														  We use this to determine how to position the leader within the placard.
--							CivLeaderSlide		table	- Flyout leader placard slide
--							CivLeaderAlpha		table	- Flyout leader placard alpha
--						<< This data is passed from the contexts where we pick leaders - AdvancedSetup and StagingRoom >>
--	alwaysHide:			A boolean indicating that we should always hide both flyouts.  The "Random" leader selection will always be hidden for example
-- ===========================================================================
function DisplayCivLeaderToolTip(info:table, tooltipControls:table, alwaysHide:boolean)

	function ShowControl(alpha, slide)
		if(alpha and slide) then
			if (alpha:IsReversing()) then
				alpha:Reverse();
				slide:Reverse();
			else
				alpha:Play();
				slide:Play();
			end
		end
	end

	function HideControl(alpha, slide) 
		if(alpha and slide) then
			if (not alpha:IsReversing()) then
				alpha:Reverse();
				slide:Reverse();
			else
				alpha:Play();
				slide:Play();
			end
		end
	end

	local showLeaderPortrait = false;
	local showToolTip = false;
	if(not alwaysHide and info.CivilizationName ~= "LOC_RANDOM_CIVILIZATION") then --If we are showing leader data flyouts, then make sure we are playing forwards, and play until shown
		showLeaderPortrait, showToolTip = SetUniqueCivLeaderData(info, tooltipControls);
	end

	if(showLeaderPortrait) then
		ShowControl(tooltipControls.CivLeaderAlpha, tooltipControls.CivLeaderSlide);
	else
		HideControl(tooltipControls.CivLeaderAlpha, tooltipControls.CivLeaderSlide);	
	end

	if(showToolTip) then
		ShowControl(tooltipControls.CivToolTipAlpha, tooltipControls.CivToolTipSlide);
	else
		HideControl(tooltipControls.CivToolTipAlpha, tooltipControls.CivToolTipSlide);	
	end
end

-- ===========================================================================
function UpdateCivLeaderToolTip()
	if m_currentInfo.LeaderType ~= nil then
		SetUniqueCivLeaderData(m_currentInfo, m_tooltipControls);
	end
end

-- ===========================================================================
--	Sets all of the data for the Unique Civilization/Leader flyout and sizes the controls accordingly
--	info				The leader and civ info that we will use to set the data
--	tooltipControls		The controls that the info data will be attached to
-- ===========================================================================
function SetUniqueCivLeaderData(info:table, tooltipControls:table)

	local hasLeaderPlacard = false;
	local hasTooltipInfo = false;

	tooltipControls.HeaderIconIM:ResetInstances();
	tooltipControls.UniqueIconIM:ResetInstances();
	tooltipControls.HeaderIM:ResetInstances();
	tooltipControls.CivHeaderIconIM:ResetInstances();

	-- Check to make sure this player panel has the leader placard
	if tooltipControls.HasLeaderPlacard then
		-- Unload leader textures
		tooltipControls.LeaderImage:UnloadTexture();
		tooltipControls.LeaderBG:UnloadTexture();
		tooltipControls.DummyImage:UnloadTexture();

		-- Set leader placard
		local leaderPortrait:string;
		if info.Portrait then
			leaderPortrait = info.Portrait;
		else
			leaderPortrait = info.LeaderType .. "_NEUTRAL";
		end
	
		tooltipControls.DummyImage:SetTexture(leaderPortrait);
		local imageRatio = tooltipControls.DummyImage:GetSizeX()/tooltipControls.DummyImage:GetSizeY();
		if(imageRatio > .51) then
 			tooltipControls.LeaderImage:SetTextureOffsetVal(30,10)
		else
			tooltipControls.LeaderImage:SetTextureOffsetVal(10,50)
		end
		tooltipControls.LeaderImage:SetTexture(leaderPortrait);

		local leaderBGImage:string;
		if info.PortraitBackground then
			leaderBGImage = info.PortraitBackground;
		else
			leaderBGImage = info.LeaderType .. "_BACKGROUND";
		end
		tooltipControls.LeaderBG:SetTexture(leaderBGImage);
		hasLeaderPlacard = true;
	end

	-- Set Leader unique data
	if (info.LeaderAbility) then
		local leaderHeader = tooltipControls.HeaderIM:GetInstance();
		leaderHeader.Header:SetText(Locale.ToUpper(Locale.Lookup(info.LeaderName)));
		local leaderAbility = tooltipControls.HeaderIconIM:GetInstance();
		leaderAbility.Icon:SetIcon(info.LeaderIcon);
		leaderAbility.Header:SetText(Locale.ToUpper(Locale.Lookup(info.LeaderAbility.Name)));
		leaderAbility.Description:LocalizeAndSetText(info.LeaderAbility.Description);
	end
	
	-- Set Civ unique data
	if (info.CivilizationAbility) then
		local civHeader = tooltipControls.HeaderIM:GetInstance();
		civHeader.Header:SetText(Locale.ToUpper(Locale.Lookup(info.CivilizationName)));
		local civAbility = tooltipControls.CivHeaderIconIM:GetInstance();

		civAbility.Icon:SetIcon(info.CivilizationIcon);

		local backColor, frontColor = UI.GetPlayerColorValues(info.PlayerColor, info.PlayerColorIndex or 0);
		if(backColor and frontColor and backColor ~= 0 and frontColor ~= 0) then
			civAbility.Icon:SetColor(frontColor);
			civAbility.IconBG:SetColor(backColor);
		end


		civAbility.Header:SetText(Locale.ToUpper(Locale.Lookup(info.CivilizationAbility.Name)));
		civAbility.Description:LocalizeAndSetText(info.CivilizationAbility.Description);
		hasTooltipInfo = true;
	end

	-- Set Civ unique units data
	for _, item in ipairs(info.Uniques) do
		local instance:table = {};
		instance = tooltipControls.UniqueIconIM:GetInstance();
		instance.Icon:SetIcon(item.Icon);
		local headerText:string = Locale.ToUpper(Locale.Lookup( item.Name ));
		instance.Header:SetText( headerText );
		instance.Description:SetText(Locale.Lookup(item.Description));
		hasTooltipInfo = true;
	end

	tooltipControls.InfoStack:CalculateSize();
	tooltipControls.InfoStack:ReprocessAnchoring();
	tooltipControls.InfoScrollPanel:CalculateSize();

	return hasLeaderPlacard, hasTooltipInfo;
end

-- Checks external conditions where this player parameter should be disabled.
function CheckExternalEnabled(playerID:number, inputEnabled:boolean, lockCheck:boolean, parameter)
	-- Early out if the input enabled status is already disabled.
	if(not inputEnabled) then
		return false;
	end

	-- Just use inputEnabled if this is singleplayer. 
	if(not GameConfiguration.IsAnyMultiplayer()) then
		return inputEnabled;
	end

	local pPlayerConfig = PlayerConfigurations[playerID];
	
	-- Disable if player has readied up.
	if(pPlayerConfig:GetReady()) then
		return false;
	end

	-- Disable if the game is already in progress.
	local gameInProgress:boolean = GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME;
	if(gameInProgress) then
		return false;
	end

	-- Disable if the local player doesn't have control over this player slot.
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];
	local slotStatus = pPlayerConfig:GetSlotStatus();
	if(not GameConfiguration.IsHotseat() -- local player can change everything in hotseat.
		and playerID ~= localPlayerID -- local player always has control of themselves.
		-- Game host can alter all the non-human slots if the host is not ready.
		and (not Network.IsGameHost()
			or slotStatus == SlotStatus.SS_TAKEN
			or localPlayerConfig:GetReady())) then
		return false;
	end

	-- Disable HandicapTypeID if matchmaking
	if(GameConfiguration.IsMatchMaking() 
		and parameter ~= nil 
		and parameter.ParameterId == "PlayerDifficulty") then
		return false; 
	end										 
	if(lockCheck and pPlayerConfig:IsLocked()) then
		return false;
	end

	return true;
end

-------------------------------------------------------------------------------
-- Setup Player Interface
-- This gets or creates player parameters for a given player id.
-- It then appends a driver to the setup parameter to control a visual 
-- representation of the parameter
-------------------------------------------------------------------------------
function SetupLeaderPulldown(
	playerId:number, 
	instance:table, 
	pulldownControlName:string, 
	civIconControlName, 
	civIconBGControlName, 
	leaderIconControlName, 
	tooltipControls:table,
	colorPullDownName,
	colorWarnName	
)
	local parameters = GetPlayerParameters(playerId);
	if(parameters == nil) then
		parameters = CreatePlayerParameters(playerId);
	end

	-- Need to save our master tooltip controls so that we can update them if we hop into advanced setup and then go back to basic setup
	if (tooltipControls.HasLeaderPlacard) then
		m_tooltipControls = {};
		m_tooltipControls = tooltipControls;
	end

	-- Defaults
	if(civIconControlName == nil) then
		civIconControlName = "CivIcon";
	end

	if(civIconBGControlName == nil) then
		civIconBGControlName = "CivIconBG";
	end

	if(leaderIconControlName == nil) then
		leaderIconControlName = "LeaderIcon";
	end
		
	local control = instance[pulldownControlName];
	local civIcon = instance[civIconControlName];
	local civIconBG = instance[civIconBGControlName];
	local leaderIcon = instance[leaderIconControlName];
	local instanceManager = control["InstanceManager"];
	
	-- Jersey support
	colorPullDownName = colorPullDownName or "ColorPullDown";
	colorWarnName = colorWarnName or "WarnIcon";
	
	local colorControls;
	local colorControl = instance[colorPullDownName];
	local colorWarnIcon = instance[colorWarnName];
	local colorInstanceManager;
	if(colorControl) then
		colorInstanceManager = colorControl["InstanceManager"]	
		if (colorInstanceManager == nil) then
			colorInstanceManager = PullDownInstanceManager:new( "InstanceOne", "Button", colorControl );
			colorControl["InstanceManager"] = colorInstanceManager;
		end

		if(colorInstanceManager) then
			colorControls = parameters.Controls["PlayerColorAlternate"];
			if(colorControls == nil) then
				colorControls = {};
				parameters.Controls["PlayerColorAlternate"] = colorControls;
			end
		end
	end

	if(colorControl) then
		colorControl:SetDisabled(true);
	end

	if(colorWarnIcon) then
		colorWarnIcon:SetHide(true);
	end
	
	if not instanceManager then
		instanceManager = PullDownInstanceManager:new( "InstanceOne", "Button", control );
		control["InstanceManager"] = instanceManager;
	end

	local controls = parameters.Controls["PlayerLeader"];
	if(controls == nil) then
		controls = {};
		parameters.Controls["PlayerLeader"] = controls;
	end

	m_currentInfo = {										
		CivilizationIcon = "ICON_CIVILIZATION_UNKNOWN",
		LeaderIcon = "ICON_LEADER_DEFAULT",
		CivilizationName = "LOC_RANDOM_CIVILIZATION",
		LeaderName = "LOC_RANDOM_LEADER"
	};
	
	local useJerseySelection = (colorControls ~= nil);


	-- Utility function to test setup parameter values for equality.
	function ValuesMatch(a,b)
		local at = type(a);
		local bt = type(b);

		if(at ~= bt) then
			return false;
		elseif(at == "number") then
			return a == b;
		elseif(at == "table") then
			return a.QueryId == b.QueryId and a.QueryIndex == b.QueryIndex and a.Invalid == b.Invalid and a.InvalidReason == b.InvalidReason
		else
			return a == b;
		end
	end
		
	local cache = {};
	if(useJerseySelection) then
		table.insert(colorControls, {
			UpdateValue = function(v)
				local refresh = true;

				local leaderParameter = parameters.Parameters["PlayerLeader"];
				local colorIndex = v or 0;
				if(	leaderParameter and ValuesMatch(leaderParameter.Value, cache.PlayerValue) and
					ValuesMatch(colorIndex, cache.PlayerColorValue)) then
					refresh = false;
				end

				if(refresh) then
					local button = control:GetButton();
									
					local icons;
					if(leaderParameter.Value) then
						icons = GetPlayerIcons(leaderParameter.Value.Domain, leaderParameter.Value.Value);
					end

					local backColor, frontColor = UI.GetPlayerColorValues(icons.PlayerColor, colorIndex);		
					if(backColor and frontColor and backColor ~= 0 and frontColor ~= 0) then
						civIcon:SetSizeVal(36,36);
						civIcon:SetIcon(icons.CivIcon);
        				civIcon:SetColor(frontColor);
						civIconBG:SetColor(backColor);
						civIconBG:SetHide(false);
					else
						civIcon:SetSizeVal(45,45);
						civIcon:SetIcon(icons.CivIcon, 45);
        				civIcon:SetColor(UI.GetColorValue(1,1,1,1));
						civIconBG:SetHide(true);
					end

					cache.PlayerColorValue = pcv;
				end				
			end,
			UpdateValues = function(values, parameter)

				local leaderParameter = parameters.Parameters["PlayerLeader"];
				if(	leaderParameter and ValuesMatch(leaderParameter.Value, cache.PlayerValue)) then
					refresh = false;
				end
				
				local icons;
				if(leaderParameter.Value) then
					icons = GetPlayerIcons(leaderParameter.Value.Domain, leaderParameter.Value.Value);
				end
				
				local itemCount = 0;
				colorInstanceManager:ResetInstances();

				if(icons) then
					for j = 0, 3, 1 do					
						local backColor, frontColor = UI.GetPlayerColorValues(icons.PlayerColor, j);
						if(backColor and frontColor and backColor ~= 0 and frontColor ~= 0) then
							local colorEntry = colorInstanceManager:GetInstance();
							itemCount = itemCount + 1;
	
							colorEntry.CivIcon:SetIcon(icons.CivIcon);
							colorEntry.CivIcon:SetColor(frontColor);
							colorEntry.CivIconBG:SetColor(backColor);
							colorEntry.Button:SetToolTipString(nil);
							colorEntry.Button:RegisterCallback(Mouse.eLClick, function()
								if(playerId == 0 and m_currentInfo) then
									m_currentInfo.PlayerColorIndex = j;
								end

								parameters:SetParameterValue(parameter, j);
							end);
						end           
					end
				end

				colorControl:CalculateInternals();

				local notExternalEnabled = not CheckExternalEnabled(playerId, true, true, parameter);
				local singleOrEmpty = itemCount == 0 or itemCount == 1;

				colorControl:SetDisabled(notExternalEnabled or singleOrEmpty);
			end,
			SetEnabled = function(enabled, parameter)
				local notExternalEnabled = not CheckExternalEnabled(playerId, enabled, true, parameter);
				--local singleOrEmpty = #parameter.Values <= 1;
				--colorControl:SetDisabled(notExternalEnabled or singleOrEmpty);
			end
		});
	end

	table.insert(controls, {
		UpdateValue = function(v)
			local refresh = true;

			local leaderParameter = parameters.Parameters["PlayerLeader"];
			local colorParameter = parameters.Parameters["PlayerColorAlternate"];
			local colorIndex = colorParameter and colorParameter.Value or 0;

			-- Compare PlayerValue (value) and PlayerColorValues (int) w/ cache.
			if(	ValuesMatch(leaderParameter.Value, cache.PlayerValue) and
				ValuesMatch(colorIndex, cache.PlayerColorValue)) then
				refresh = false;
			end
						
			if(refresh) then
				-- If this is player 0, update the placard.
				if(playerId == 0) then
					local info = GetPlayerInfo(v.Domain, v.Value); 
					info.PlayerColorIndex = colorIndex;
					
					m_currentInfo = info;
				end

				local button = control:GetButton();

				if(v == nil) then
					button:LocalizeAndSetText("LOC_SETUP_ERROR_INVALID_OPTION");
					button:ClearCallback(Mouse.eMouseEnter);
					button:ClearCallback(Mouse.eMouseExit);
				else
					local caption = v.Name;
					if(v.Invalid) then
						local err = v.InvalidReason or "LOC_SETUP_ERROR_INVALID_OPTION";
						caption = caption .. "[NEWLINE][COLOR_RED](" .. Locale.Lookup(err) .. ")[ENDCOLOR]";
					end

					button:SetText(caption);
			
					local icons = GetPlayerIcons(v.Domain, v.Value);

					local backColor, frontColor = UI.GetPlayerColorValues(icons.PlayerColor, colorIndex);
					if(backColor and frontColor and backColor ~= 0 and frontColor ~= 0) then
						civIcon:SetSizeVal(36,36);
						civIcon:SetIcon(icons.CivIcon);
        				civIcon:SetColor(frontColor);
						civIconBG:SetColor(backColor);
						civIconBG:SetHide(false);
					else
						civIcon:SetSizeVal(45,45);
						civIcon:SetIcon(icons.CivIcon, 45);
        				civIcon:SetColor(UI.GetColorValue(1,1,1,1));
						civIconBG:SetHide(true);
					end
										
					if(leaderIcon) then
						leaderIcon:SetIcon(icons.LeaderIcon);
					end

					if(not tooltipControls.HasLeaderPlacard) then
						local info; -- Up-value
						local domain = v.Domain;
						local value = v.Value;
						button:RegisterCallback( Mouse.eMouseEnter, function() 
							if(info == nil) then info = GetPlayerInfo(domain, value); end
							info.PlayerColorIndex = colorIndex;
							DisplayCivLeaderToolTip(info, tooltipControls, false); 
						end);
						button:RegisterCallback( Mouse.eMouseExit, function() 
							DisplayCivLeaderToolTip(nil, tooltipControls, true); 
						end);
					end

					cache.PlayerValue = v;
					cache.PlayerColorValue = colorIndex;
				end		
			end
		end,
		UpdateValues = function(values)

			local refresh = false;
			local cValues = cache.PlayerValues;
			if(cValues and #cValues == #values) then
				for i,v in ipairs(values) do
					local cv = cValues[i];
					if(not ValuesMatch(cv,v)) then
						refresh = true;
						break;
					end
				end
			else
				refresh = true;
			end

			if(refresh) then
				instanceManager:ResetInstances();

				-- Avoid creating call back for each value.
				local hasPlacard = tooltipControls.HasLeaderPlacard;
				local OnMouseExit = function()
					DisplayCivLeaderToolTip(m_currentInfo, tooltipControls, not hasPlacard);
				end;

				for i,v in ipairs(values) do
					
					local icons = GetPlayerIcons(v.Domain, v.Value);

					local entry = instanceManager:GetInstance();
				
					local caption = v.Name;
					if(v.Invalid) then 
						local err = v.InvalidReason or "LOC_SETUP_ERROR_INVALID_OPTION";
						caption = caption .. "[NEWLINE][COLOR_RED](" .. Locale.Lookup(err) .. ")[ENDCOLOR]";
					end

					local backColor, frontColor = UI.GetPlayerColorValues(icons.PlayerColor, 0);
					if(backColor and frontColor and backColor ~= 0 and frontColor ~= 0) then
						entry.CivIcon:SetSizeVal(36,36);
						entry.CivIcon:SetIcon(icons.CivIcon);
        				entry.CivIcon:SetColor(frontColor);
						entry.CivIconBG:SetColor(backColor);
						entry.CivIconBG:SetHide(false);
					else
						entry.CivIcon:SetSizeVal(45,45);
						entry.CivIcon:SetIcon(icons.CivIcon, 45);
        				entry.CivIcon:SetColor(UI.GetColorValue(1,1,1,1));
						entry.CivIconBG:SetHide(true);
					end

					entry.Button:SetText(caption);
					entry.LeaderIcon:SetIcon(icons.LeaderIcon);

					local info;
					local domain = v.Domain;
					local value = v.Value;

					entry.Button:RegisterCallback( Mouse.eMouseEnter, function() 
						if(info == nil) then info = GetPlayerInfo(domain, value); end
						DisplayCivLeaderToolTip(info, tooltipControls, false); 
					end);

					entry.Button:RegisterCallback( Mouse.eMouseExit, OnMouseExit);
					entry.Button:SetToolTipString(nil);			

					entry.Button:RegisterCallback(Mouse.eLClick, function()
						local parameter = parameters.Parameters["PlayerLeader"];
						parameters:SetParameterValue(parameter, v);

						-- Reset Jersey Color
						-- TODO: Ideally, this should try to select a jersey that doesn't conflict.
						local colorParameter = parameters.Parameters["PlayerColorAlternate"];
						if(colorParameter) then
							parameters:SetParameterValue(colorParameter, 0);
						end

					end);
				end
				control:CalculateInternals();
				cache.PlayerValues = values;
			end
		end,
		SetEnabled = function(enabled, parameter)
			local notExternalEnabled = not CheckExternalEnabled(playerId, enabled, true, parameter);
			local singleOrEmpty = #parameter.Values <= 1;

			control:SetDisabled(notExternalEnabled or singleOrEmpty);
		end,
	--	SetVisible = function(visible)
	--		control:SetHide(not visible);
	--	end
	});
end

function SetupHandicapPulldown(playerId, control)
	local parameters = GetPlayerParameters(playerId);
	if(parameters == nil) then
		parameters = CreatePlayerParameters(playerId);
	end

	parameters.Controls["PlayerDifficulty"] = {
		UpdateValue = function(value)
			local button = control:GetButton();
			button:SetText( value and value.Name or nil);
		end,
		UpdateValues = function(values)
			control:ClearEntries();
			for i,v in ipairs(values) do
				local entry = {};
				control:BuildEntry( "InstanceOne", entry );
				entry.Button:SetText(v.Name);
				entry.Button:SetToolTipString(v.Description);			
				entry.Button:RegisterCallback(Mouse.eLClick, function()
					local parameter = parameters.Parameters["PlayerDifficulty"];
					parameters:SetParameterValue(parameter, v);
				end);
			end
			control:CalculateInternals();
		end,
		SetEnabled = function(enabled, parameter)
			control:SetDisabled(not CheckExternalEnabled(playerId, enabled, false, parameter));
		end,
	};
end

function PlayerConfigurationValuesToUI(playerId)
	local parameters = GetPlayerParameters(playerId);
	if(parameters == nil) then
		parameters = CreatePlayerParameters(playerId);
	end

	GameSetup_RefreshPlayerParameter(playerId);
end

function UpdatePlayerEntry(playerId)
	GameSetup_RefreshPlayerParameter(playerId);
end

-- This event listener may be called during the act of refreshing parameters.
-- This commonly happens if the setup parameters need to update default values.
-- When this happens, simply mark that we need to do an additional refresh afterwards.
g_Refreshing = false;
g_NeedsAdditionalRefresh = false;
g_RefreshCounter = 0;
MAX_REFRESH_DEPTH = 10;

function GameSetup_RefreshParameters()
	if(g_Refreshing) then
		SetupParameters_Log("An additional refresh was requested!");
		g_NeedsAdditionalRefresh = true;
	else
		g_Refreshing = true;
		g_RefreshCounter = g_RefreshCounter + 1;
		g_NeedsAdditionalRefresh = false;

		-- Hang protection.
		-- If we loop too many times, just mark any parameters that still need to be written 
		-- as errors and bail.
		if(g_RefreshCounter > MAX_REFRESH_DEPTH) then
			SetupParameters_Log("Refreshed too many times! Setting error state and skipping to prevent hang.");
			g_RefreshCounter = 0;
			g_Refreshing = false;	
			g_GameParameters.Stalled = true;

			g_GameParameters:UpdateVisualization();
			VisualizePlayerParameters();

			if(UI_PostRefreshParameters) then
				UI_PostRefreshParameters();
			end
		else
			SetupParameters_Log("Refreshing Game parameters");
			if(g_GameParameters == nil) then
				BuildGameSetup();
			else
				g_GameParameters:Refresh();
			end
		
			SetupParameters_Log("Refreshing Player parameters");
			RefreshPlayerParameters();
		
			g_GameParameters.Stalled = nil;
			g_Refreshing = false;

			if(g_NeedsAdditionalRefresh) then
				SetupParameters_Log("Refreshing parameters again due to an intermediate request.")
				return GameSetup_RefreshParameters();
			else
				SetupParameters_Log("Finished Refreshing");
				SetupParameters_Log("Visualizing parameters"); 
				g_RefreshCounter = 0;

				g_GameParameters:UpdateVisualization();
				VisualizePlayerParameters();

				if(UI_PostRefreshParameters) then
					UI_PostRefreshParameters();
				end
			end
		end
	end
end

function GameSetup_RefreshPlayerParameter(playerId)
	SetupParameters_Log("Refreshing parameters for player " .. tostring(playerId));
	local parameters = GetPlayerParameters(playerId);
	if(parameters) then

		g_Refreshing = true;
		parameters:Refresh();
		g_Refreshing = false;

		if(g_NeedsAdditionalRefresh) then
			SetupParameters_Log("Refreshing all parameters, to be sure.")
			return GameSetup_RefreshParameters();
		else
			parameters:UpdateVisualization();
		end
	else
		SetupParameters_Log("Player parameters not found!");
	end
end

function GameSetup_ConfigurationChanged()
	SetupParameters_Log("Configuration Changed!");
	GameSetup_RefreshParameters();
end

