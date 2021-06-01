------------------------------------------------------------------------------
--	FILE:	 CPL_helper.lua
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Gameplay script - Lua Handling
-------------------------------------------------------------------------------
-- logs
-- v0.1 added CPL auto-pause
-- v0.2 added auto Freeze
--	added the Command logic
--	added the Trading logic
-- v0.3 trading logic should be working
-- v0.4 added the maximum friendship logic
-- v0.5 CC, Scrap, Irr Vote
--	Max Friendship
--	Max City States
--	Logging events
-- v0.6 Allies Trading
--	Restrict AI trading
--	Forced Turn command
-- v0.7 Fixed some bug
--	Change the commands to match the discord bot
-- 	Sudden-Death
--	Capturing captured CS does trigger an automatic raze
-- v0.8 Remapvote
--	Beef up free cities
-- v0.9 	Prevent unsolited friendship above threshold
--			Added The first move/last move debuff
-- v0.92	Nerfed Free Cities
-- v0.93	Introduce a Smart Timer	
-- v0.94	Dynamic timer
--			Added a mechanism to further prevent desync when a player lag excessively
--			Added a toogle to control free city flip in FFA
--			Nerfed free cities
--			Added .time command to modify the dynamic timer ingame
--			Improved the lua.log reporting to track the players ID better
-- v0.95		Cleaned up the code with one main teamer boolean
--				Modulated the turns better (+10% if it is a Teamer, +15% if at war)
--				Made a smart timer toogle
--				Free Cities now need to wait for turn 50 to get walls 
-- v0.96	Added Draft/Ban support in game
-- v0.97	Map Pool
--			Slightly quicker timer
-- v0.98	Clarify the draft mechanism with more visual clues
--			Remove the extra 10% time in Teamers when in Tournament
-- v0.99	Auto flag the doom Civ+ Player Name
--			Check player's mod version
--			More timers
-- v1.00 	Recoded the Staging Room
-- v1.01	New CWC slot draft
--		UI for MPH
--		Built in Game Video Support for Victory Screen
--		gg would trigger a concede victory
-- v1.02	Improved interface stability
--		Introduced a first Voting Draft interface
-- v1.03	Added Observer support for random compatibility
--		Added Draft pool
--		Added Anonymous Front End layer
--		Added No private chat Front End layer
--		Further exposed the localization for translation if needed
--		Only one video can be played
-- v1.04	Minor UI bug fixes and text
-- v1.06	Handle New Frontier Pass
--		Completely redesigned the code for an UI oriented interface
--		Currently support: Remap, vote remap, drop pause, smart timer, esport drafting
-- v1.08 	Added Casual timer
--		CWC new format
--		Bug fixes
-- v1.09
--		Alliance and Trading restrictions
--		Improved Front End
-- v1.10
--		World Congress timer no longer infinite
--		Added No Frienship, no surprise wars option
-- v1.2.3
--		Updated version number
--		Congress no longer can be skipped on lag
-- v1.3.2
-- 		Random leader picked
--		ConfigurationUpdate changes for CWC
-- v1.3.3
--		Added an event debug
--		Moved the timer codes to UI (no real reason to have it on the Core side for calculation as the implementation is UI anyway)
-- v1.3.4
--		Presets Updated
-- v1.3.5
--		OCC Updated

print("MPH Gamescript")


-- ===========================================================================
--	NEW VARIABLES
-- ===========================================================================
ExposedMembers.LuaEvents = LuaEvents
local g_version = "v1.3.5"
local Drop_Data = {};
local b_freecity = false
local g_turn_start_time = 0
local b_teamer = false
local g_timeshift = 0
local b_debug = false

-- ===========================================================================
--	GLOBAL FLAGS
-- ===========================================================================


-- =========================================================================== 
--	NEW EVENTS
-- =========================================================================== 

function OnGameTurnStarted(turn)
	-- local time
	g_turn_start_time = os.date('%Y-%m-%d %H:%M:%S')
	b_clean = false
	b_debuff = false
	local seed = Game.GetRandNum(100, "MPH Track Local State")
	print("OnGameTurnStarted: Turn",turn,"Local State:",seed,g_turn_start_time)
	Game:SetProperty("LOCAL_SEED",seed)
	Game:SetProperty("LOCAL_TURN",turn)
end

--------------------------------------------------------------------------------
function OnCapturedCityState(playerID,cityID)
	print("OnCapturedCityState", playerID,cityID)
	local pPlayer = Players[ReceiverID]
	local pCity = CityManager.GetCity(playerID, cityID) 
	print(Locale.Lookup(pCity:GetName()))
	CityManager.DestroyCity(pCity)

end

LuaEvents.UICPLRazeCity.Add( OnCapturedCityState );

function OnIrr(playerID:number)
	print("OnIrr Remove all AI convenants", playerID)
	local pPlayer = Players[playerID]
	local team = pPlayer:GetTeam();

	-- FFA
	if b_teamer == false then
		print("OnIrr - FFA")
		local playerCities = pPlayer:GetCities()
		for i, pCity in playerCities:Members() do
			if pCity ~= nil then
				--pCity:ChangeLoyalty(-999)
				CityManager.TransferCityToFreeCities(pCity)
			end
		end
		return
	end
	
	-- Teamer
	for i = 0, PlayerManager.GetWasEverAliveMajorsCount() -1 do
		if Players[i]:IsAlive() == true and i ~= playerID then
			Players[playerID]:GetDiplomacy():SetHasDelegationAt(i,false)
			Players[playerID]:GetDiplomacy():SetHasEmbassyAt(i,false)
			if team == nil or team == -1 then
				-- FFA
				else
				-- Teamer
				local team_other = Players[i]:GetTeam()
				if team_other ~= team then
					--Players[playerID]:GetDiplomacy():SetHasAllied(i,false)
					--Players[playerID]:GetDiplomacy():SetHasDeclaredFriendship(i,false) Only work in FireTuner environement ?
				end 
			end
		end	
	end
	

end

LuaEvents.UICPLPlayerIrr.Add( OnIrr );

-----------------------------------------------------------------------------------------

function FreeCities_Sronger()
	if GameConfiguration.GetValue("CPL_FREECITY_STRONGER") == 0 then
		return
	end
	-- Free Cities
	local max_era = 0
	local second_era = 0
	local count = 0
		if Players[62] ~= nil then
			if Players[62]:IsAlive() then
				-- 0 Ancient
				-- 1 Classical
				-- 2 Medieval
				-- 3 Renaissance
				-- 4 Industrial
				-- 5 Modern
				-- 6 Atomic
				-- 7 Information
				for k = 0, PlayerManager.GetWasEverAliveMajorsCount() -1 do
					if Players[k] ~= nil then
						if Players[k]:IsAlive() == true then
							--if Players[k]:GetEras():GetEra() > max_era then
							--	second_era = max_era
							--	max_era = Players[k]:GetEras():GetEra()
							--end
							max_era = max_era + Players[k]:GetEras():GetEra()
							count = count + 1
						end 
					end		
				end
				local currentTurn = Game.GetCurrentGameTurn()
				print ("CPL Helper Free City Module: Turn " .. tostring(currentTurn));
				local FreeCities = Players[62]:GetCities()
				local monument_idx = 0
				local wall_idx = 0
				for building in GameInfo.Buildings() do
					if (building.BuildingType == "BUILDING_MONUMENT") then
						monument_idx = building.Index
						elseif building.BuildingType == "BUILDING_WALLS" then
						wall_idx = building.Index
					end
				end
				max_era = max_era / count
				--max_era = second_era
				for i, FreeCity in FreeCities:Members() do
					if FreeCity ~= nil then
						if FreeCity:GetBuildings():HasBuilding(monument_idx) == false then
							FreeCity:GetBuildQueue():CreateBuilding(monument_idx)
						end
						if Game.GetCurrentGameTurn() >= 50 then
							if FreeCity:GetBuildings():HasBuilding(wall_idx) == false then
								FreeCity:GetBuildQueue():CreateBuilding(wall_idx)
							end
						end
						mac_era = -1
						if Game.GetCurrentGameTurn() % 10 == 0 then
							local FreeUnits = Players[62]:GetUnits()
							local rng = TerrainBuilder.GetRandomNumber(100,"test")/100
							if max_era > 0.1 and  max_era < 1 then
								FreeUnits:Create(GameInfo.Units["UNIT_ARCHER"].Index, FreeCity:GetX(), FreeCity:GetY())
								elseif max_era > 0.9 and max_era < 1.5 then
								FreeUnits:Create(GameInfo.Units["UNIT_SWORDMAN"].Index, FreeCity:GetX(), FreeCity:GetY())
								elseif max_era > 1.49 and max_era < 2.5 then
									if rng > 0.25 then
										FreeUnits:Create(GameInfo.Units["UNIT_CROSSBOWMAN"].Index, FreeCity:GetX(), FreeCity:GetY())
										else
										FreeUnits:Create(GameInfo.Units["UNIT_KNIGHT"].Index, FreeCity:GetX(), FreeCity:GetY())
									end
								elseif max_era > 2.49 and max_era < 3.75 then
									if rng > 0.25 then
										FreeUnits:Create(GameInfo.Units["UNIT_CROSSBOWMAN"].Index, FreeCity:GetX(), FreeCity:GetY())
										else
										FreeUnits:Create(GameInfo.Units["UNIT_BOMBARD"].Index, FreeCity:GetX(), FreeCity:GetY())
									end
								elseif max_era > 3.74 and max_era < 4.75 then
									if rng > 0.25 then
										FreeUnits:Create(GameInfo.Units["UNIT_FIELD_CANNON"].Index, FreeCity:GetX(), FreeCity:GetY())
										else
										FreeUnits:Create(GameInfo.Units["UNIT_CAVALRY"].Index, FreeCity:GetX(), FreeCity:GetY())
									end
								elseif max_era > 4.74 and max_era < 5.75 then
									if rng > 0.05 then
										FreeUnits:Create(GameInfo.Units["UNIT_FIELD_CANNON"].Index, FreeCity:GetX(), FreeCity:GetY())
										else
										FreeUnits:Create(GameInfo.Units["UNIT_TANK"].Index, FreeCity:GetX(), FreeCity:GetY())
									end
								elseif max_era > 5.74 and max_era < 6.75 then
									if rng > 0.25 then
										FreeUnits:Create(GameInfo.Units["UNIT_ARTILLERY"].Index, FreeCity:GetX(), FreeCity:GetY())
										else
										FreeUnits:Create(GameInfo.Units["UNIT_TANK"].Index, FreeCity:GetX(), FreeCity:GetY())
									end
								elseif max_era > 6.74  then
									if rng > 0.005 then
										FreeUnits:Create(GameInfo.Units["UNIT_MODERN_ARMOR"].Index, FreeCity:GetX(), FreeCity:GetY())
										else
										FreeUnits:Create(GameInfo.Units["UNIT_GIANT_DEATH_ROBOT"].Index, FreeCity:GetX(), FreeCity:GetY())
									end
							end
						end
					end
				end
			end
		end
end


-------------------------------------------------------------------------------------------------------------------------------
-- Drop/Restore Mechanics

function OnDrop(playerID:number)
	print("Ondrop: Saving Player",playerID,"'s data")
	-- Drop_Player Table
	local Drop_P = {}
	-- Units
	local pPlayer = Players[playerID];
	local pPlayerUnits = pPlayer:GetUnits();
	local tmp_unit = {}
	local counter = 0
	for i, unit in pPlayerUnits:Members() do
		counter = counter + 1
		tmp_unit[counter] = { ID = unit:GetID(), moves = unit:GetMovesRemaining()}
		print("unit:GetMovesRemaining()",unit:GetMovesRemaining())
		UnitManager.ChangeMovesRemaining(unit, -99)
		print("unit:GetMovesRemaining()",unit:GetMovesRemaining())
		print("counter",counter,"tmp_unit[counter] ",tmp_unit[counter] ,"tmp_unit[counter].ID",tmp_unit[counter].ID,"tmp_unit[counter].moves",tmp_unit[counter].moves) 
	end
	tmp_unit["count"] = counter
	Drop_P = { unit = tmp_unit }
	Drop_Data[playerID] = Drop_P
end

LuaEvents.UICPLPlayerDrop.Add( OnDrop );

function RestoreUnits(unit_table:table,playerID:number)
	print("RestoreUnits", playerID)
	if unit_table["count"] < 1 then
		return
	end

	
	local pPlayer = Players[playerID];
	local pPlayerUnits = pPlayer:GetUnits();
	-- Restore all the units
	local counter = 0
	for i, unit in pPlayerUnits:Members() do
		local unit_ID = unit:GetID()
		for k = 1, unit_table["count"] do
			if unit_ID == unit_table[k].ID then
				UnitManager.ChangeMovesRemaining(unit, unit_table[k].moves)
				print(unit:GetID(),unit:GetMovesRemaining())
				counter = counter + 1
				break
			end
		end
		if counter == unit_table["count"] then
			break
		end
	end
	
end

function OnConnect(playerID:number)
	print("OnConnect", playerID)
	RestoreUnits(Drop_Data[playerID].unit,playerID)
end


LuaEvents.UICPLPlayerConnect.Add( OnConnect );

-- =========================================================================== 
--	Sudden Death
-- =========================================================================== 

function OnTimerExpires(playerID:number)
	print("OnTimerExpires Script", playerID)
	local pPlayer = Players[playerID];
	local pPlayerUnits:table = pPlayer:GetUnits();	
	local pPlayerCities:table = pPlayer:GetCities();
	for _,pUnit in pPlayerUnits:Members() do
		pPlayerUnits:Destroy(pUnit)
	end	
	for _,pCity in pPlayerCities:Members() do
		CityManager.DestroyCity(pCity)
	end
end


LuaEvents.UISuddenDeathTimeExpireAI.Add( OnTimerExpires );

function OnTimeSaved(timeleft:number)
	print("OnTimeSaved", timeleft)
	Game:SetProperty("MPH_SD_TIME_LEFT", timeleft );	
end


LuaEvents.UISuddenDeathSavetime.Add( OnTimeSaved );


--==================================================================================================================================================================
function Tablelength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function FindTableIndex(t,val)
    for k,v in ipairs(t) do 
        if v == val then return k end
    end
end

function NoMoreStack()
	if ( Game.GetCurrentGameTurn() ~= GameConfiguration.GetStartTurn()) then
	for i = 0, PlayerManager.GetAliveMajorsCount() - 1 do
		if (PlayerConfigurations[i]:GetLeaderTypeName() ~= "LEADER_SPECTATOR" and PlayerConfigurations[i]:GetHandicapTypeID() ~= 2021024770) then
			local pPlayerCulture:table = Players[i]:GetCulture();
			if pPlayerCulture:GetProgressingCivic() == -1 and pPlayerCulture:GetCultureYield()>0 then
				print("Player",PlayerConfigurations[i]:GetLeaderTypeName()," forgot to pick a civic: Adjust. Turn",Game.GetCurrentGameTurn())
				for k = 0, 58 do
					if (pPlayerCulture:HasCivic(k) == false) then
						pPlayerCulture:SetProgressingCivic(k)
						break
					end	
				end
			end
			local pPlayerTechs:table = Players[i]:GetTechs();
			if pPlayerTechs:GetResearchingTech() == -1 and pPlayerTechs:GetScienceYield()>0 then
				print("Player",PlayerConfigurations[i]:GetLeaderTypeName()," forgot to pick a tech: Adjust. Turn",Game.GetCurrentGameTurn())
				for k = 0, 73 do
					if (pPlayerTechs:HasTech(k) == false) then
						pPlayerTechs:SetResearchingTech(k)
						break
					end	
				end
			end
		end		
	end
	end	
end

-------------------------------------------------------
-- Event Debugging
-------------------------------------------------------

function Debug_OnGameTurnStarted(arg1,arg2)
	print("Debug_OnGameTurnStarted",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_PlayerTurnStarted(arg1,arg2)
	print("Debug_PlayerTurnStarted",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_PlayerTurnStartComplete(arg1,arg2)
	print("Debug_PlayerTurnStartComplete",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_OnPlayerTurnEnded(arg1,arg2)
	print("Debug_PlayerTurnEnded",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_PlayerTurnActivated(arg1,arg2)
	print("Debug_PlayerTurnActivated",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_LocalPlayerTurnBegin(arg1,arg2)
	print("Debug_LocalPlayerTurnBegin",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_LocalPlayerTurnEnd(arg1,arg2)
	print("Debug_LocalPlayerTurnEnd",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_RemotePlayerTurnBegin(arg1,arg2)
	print("Debug_RemotePlayerTurnBegin",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_RemotePlayerTurnEnd(arg1,arg2)
	print("Debug_RemotePlayerTurnEnd",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_TurnEnd(arg1,arg2)
	print("Debug_TurnEnd",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_ConnectedToNetSessionHost(arg1,arg2)
	print("Debug_ConnectedToNetSessionHost",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_MultiplayerPlayerConnected(arg1,arg2)
	print("Debug_MultiplayerPlayerConnected",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_MultiplayerPrePlayerDisconnected(arg1,arg2)
	print("Debug_MultiplayerPrePlayerDisconnected",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_MultiplayerSnapshotRequested(arg1,arg2)
	print("Debug_MultiplayerSnapshotRequested",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_MultiplayerSnapshotProcessed(arg1,arg2)
	print("Debug_MultiplayerSnapshotProcessed",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_MultiplayerHostMigrated(arg1,arg2)
	print("Debug_MultiplayerHostMigrated",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_MultiplayerMatchHostMigrated(arg1,arg2)
	print("Debug_MultiplayerMatchHostMigrated",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_SteamServersDisconnected(arg1,arg2)
	print("Debug_SteamServersDisconnected",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_PlayerInfoChanged(arg1,arg2)
	print("Debug_PlayerInfoChanged",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end

function Debug_GameConfigChanged(arg1,arg2)
	print("Debug_PlayerInfoChanged",os.date('%Y-%m-%d %H:%M:%S'),"arg1",arg1,"arg2",arg2)
end
-------------------------------------------------------

function Initialize()
	print("-- Init D. CPL Helper Gameplay Script"..g_version.." --");
	
	if b_debug == true then
		GameEvents.OnGameTurnStarted.Add(Debug_OnGameTurnStarted);
		GameEvents.PlayerTurnStarted.Add(Debug_PlayerTurnStarted);
		GameEvents.PlayerTurnStartComplete.Add(Debug_PlayerTurnStartComplete);
		GameEvents.OnPlayerTurnEnded.Add(Debug_OnPlayerTurnEnded);
		Events.PlayerTurnActivated.Add(Debug_PlayerTurnActivated);
		Events.LocalPlayerTurnBegin.Add(Debug_LocalPlayerTurnBegin );
		Events.LocalPlayerTurnEnd.Add(Debug_LocalPlayerTurnEnd );
		Events.RemotePlayerTurnBegin.Add( Debug_RemotePlayerTurnBegin);
		Events.RemotePlayerTurnEnd.Add( Debug_RemotePlayerTurnEnd );
		Events.TurnEnd.Add(Debug_TurnEnd)
		Events.ConnectedToNetSessionHost.Add ( Debug_ConnectedToNetSessionHost );
		Events.MultiplayerPlayerConnected.Add( Debug_MultiplayerPlayerConnected );
		Events.MultiplayerPrePlayerDisconnected.Add( Debug_MultiplayerPrePlayerDisconnected );
		Events.MultiplayerSnapshotRequested.Add(Debug_MultiplayerSnapshotRequested);
		Events.MultiplayerSnapshotProcessed.Add(Debug_MultiplayerSnapshotProcessed);
		Events.MultiplayerHostMigrated.Add(Debug_MultiplayerHostMigrated);
		Events.MultiplayerMatchHostMigrated.Add(Debug_MultiplayerMatchHostMigrated);
		Events.SteamServersDisconnected.Add( Debug_SteamServersDisconnected)
		Events.PlayerInfoChanged.Add(Debug_PlayerInfoChanged);
		Events.GameConfigChanged.Add(Debug_GameConfigChanged);
	end
	GameEvents.OnGameTurnStarted.Add(OnGameTurnStarted);
	GameEvents.OnGameTurnStarted.Add(NoMoreStack);
	for i = 0, PlayerManager.GetWasEverAliveMajorsCount() -1 do
		if Players[i]:IsAlive() == true then
			if Players[i]:GetTeam() ~= i then
				b_teamer = true
			end
		end
	end

end


Initialize();
