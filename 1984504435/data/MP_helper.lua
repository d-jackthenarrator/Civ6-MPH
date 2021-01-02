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



-- ===========================================================================
--	NEW VARIABLES
-- ===========================================================================
ExposedMembers.LuaEvents = LuaEvents
local g_version = "v1.09"
local Drop_Data = {};
local b_freecity = false
local g_turn_start_time = 0
local b_onecity = false
local b_teamer = false
local g_timeshift = 0

-- ===========================================================================
--	GLOBAL FLAGS
-- ===========================================================================



-- =========================================================================== 
--	NEW FUNCTIONS
-- =========================================================================== 

function Init_Properties()
	Game:SetProperty("MPH_REMAP_MODE", 0) 
	local player_ids = PlayerManager.GetAliveMajorIDs();
	for i, iPlayer in ipairs(player_ids) do
		if Players[iPlayer] ~= nil then
			Game:SetProperty("MPH_RESYNC_ARMED_"..iPlayer,0)
		end
	end	
end

function OnHostInstructsRemap(ePlayer : number, params : table)
	print("OnHostInstructsRemap",ePlayer,os.date())
	if params.GameSeed ~= nil then
		print("params.GameSeed",params.GameSeed)
		print("params.MapSeed",params.MapSeed)
		Game:SetProperty("MPH_GAMESEED",params.GameSeed)
		Game:SetProperty("MPH_MAPSEED",params.MapSeed)
		Game:SetProperty("MPH_REMAP_MODE",1)
	end
end

GameEvents.OnHostInstructsRemap.Add(OnHostInstructsRemap)

function OnPlayerReceivedRemapInstructions(ePlayer : number, params : table)
	print("OnPlayerReceivedRemapInstructions",ePlayer)
	if params.Player ~= nil then
		print("params.Player",params.Player)
		Game:SetProperty("MPH_REMAP_READY_"..params.Player,1)
	end
end

GameEvents.OnPlayerReceivedRemapInstructions.Add(OnPlayerReceivedRemapInstructions)

function SmartTimer()
	-- 0: Competitive
	-- 1: None
	-- 2: Lege
	-- 3: S1AL
	-- 4: Sephis
	if GameConfiguration.GetValue("CPL_SMARTTIMER") == 1 then
		return
	end

	local tot_cities = 0
	local tot_units = 0
	local tot_humans = 0
	local b_war = false
	local b_pantheon = false
	local currentTurn = Game.GetCurrentGameTurn()
	for i = 0, PlayerManager.GetWasEverAliveMajorsCount() -1 do
		if Players[i]:IsAlive() == true then
			if Players[i]:IsHuman() == true then
				tot_humans = tot_humans + 1
				tot_cities = tot_cities + Players[i]:GetCities():GetCount()
				tot_units = tot_units + Players[i]:GetUnits():GetCount()
				if Players[i]:GetReligion():CanCreatePantheon() == true then
					b_pantheon = true
				end
				if Players[i]:GetDiplomacy():IsAtWarWithHumans() == true then
					b_war = true
				end
			end
		end
	end
	local avg_cities = 0
	local avg_units = 0
	if tot_humans > 0 then
		avg_cities = math.floor( tot_cities / tot_humans )
		avg_units = math.floor( tot_units / tot_humans )
	end

	local timer = 0
	if GameConfiguration.GetValue("CPL_SMARTTIMER") == 0 then
		timer = 30 + avg_cities * 4 + avg_units * 1  + g_timeshift
	

	if currentTurn > 5 and currentTurn < 11 then
		timer = timer 
	end	
	if currentTurn > 10 and currentTurn < 21 then
		timer = timer + 10
	end	
	if currentTurn > 20 and currentTurn < 51 then
		timer = timer + 30
	end
	if currentTurn > 50 and currentTurn < 76 then
		timer = timer + 40
	end
	if currentTurn > 75 and currentTurn < 101 then
		timer = timer + 50
	end
	if currentTurn > 100 then
		timer = timer + 60
	end
	if b_teamer == true then
		if GameConfiguration.GetValue("CPL_BAN_FORMAT") ~= 3 then
			print("More time: Teamer!")
			timer = math.floor(timer * 1.1)
		end
	end
	if b_war == true then
		if GameConfiguration.GetValue("CPL_BAN_FORMAT") ~= 3 then
			print("More time: War!")
			timer = math.floor(timer * 1.15)
			else
			print("More time: War!")
			timer = math.floor(timer * 1.05)			
		end
	end
	if b_pantheon == true then
		print("More time: Pantheon!")
		timer = timer + 15
	end
	end

	if GameConfiguration.GetValue("CPL_SMARTTIMER") == 2 then

	if currentTurn < 16 then
		timer = 15 + g_timeshift
	end	
	if currentTurn > 15 and currentTurn < 71 then
		timer = 45 + g_timeshift
	end	
	if currentTurn > 70 then
		timer = 75 + g_timeshift
	end

	end

	if GameConfiguration.GetValue("CPL_SMARTTIMER") == 3 then


	timer = 65 + avg_cities * 4 + avg_units * 1  + g_timeshift
	
	if currentTurn > -1 and currentTurn < 10 then
		timer = timer - 15
	end	
	if currentTurn > 44 and currentTurn < 90 then
		timer = timer + 15
	end	
	if currentTurn > 89 then
		timer = timer + 30
	end	
	
	end
	
	if GameConfiguration.GetValue("CPL_SMARTTIMER") == 5 then


	timer = 95 + avg_cities * 4 + avg_units * 1  + g_timeshift
	
	if currentTurn > -1 and currentTurn < 10 then
		timer = timer - 25
	end	
	if currentTurn > 44 and currentTurn < 90 then
		timer = timer + 30
	end	
	if currentTurn > 89 then
		timer = timer + 20
	end	
	
	end


	if GameConfiguration.GetValue("CPL_SMARTTIMER") == 4 then


	timer = 30 + currentTurn + g_timeshift
	

	end

	print("timer",timer)
	Game:SetProperty("CPL_TIMER",timer)
end

-- =========================================================================== 
--	NEW EVENTS
-- =========================================================================== 

function OnAdjustTime(time_value:number)
	g_timeshift = time_value
	SmartTimer()
end

LuaEvents.UITimeAdjust.Add( OnAdjustTime )

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

function OnGameTurnStarted(player)
	-- local time
	print("Last turn lenght",os.time()-g_turn_start_time)
	SmartTimer()
	g_turn_start_time = os.time()
	b_clean = false
	b_debuff = false
	print("OnGameTurnStarted",g_turn_start_time)

end

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


-- =========================================================================== 
--	One City Challenge
-- =========================================================================== 

--Tables
local fortPlots:table = {}; --{int, PlotIndex} --have to keep a list of forts because Events.ImprovementRemovedFromMap does not keep track of the type of improvement
local conqueredForts:table = {}; --{int, PlotIndex} --to track the forts that belong to a city being conquered
local removeFortPlotsConquered:table = {}; --{int, PlotIndex} --forts assigned here for RemoveFortPlots to determine how to proceed with plot removal
local razedForts:table = {}; --{int, PlotIndex} --forts assigned here for OnCityRemoved to rebuild them for owner

--Flags
local inGame:boolean = false;
local pillaged:boolean = false;
local remotePillaged:boolean = false;
local razedOrTraded:boolean = false;
local cityConquered:boolean = false;

--For Tracking
local removedCityPlot;
local removedCityOwner;
local conqueredCityPlot;
local cityNewOwner;
local cityOriginalOwner;

--Counters
local cityConqueredCount:number = 0;
local addConqueredFortsCounter:number = 0;
local removeConqueredFortsCounter:number = 0;

function OneCity_Init()
	local pAllPlayerIDs : table = PlayerManager.GetAliveIDs();	
	for _,iPlayerID in ipairs(pAllPlayerIDs) do
	
		local pPlayer : object = Players[iPlayerID];
		local pPlayerUnits : object = pPlayer:GetUnits();
		-- Disable Settler builds
		pPlayerUnits:SetBuildDisabled(GameInfo.Units["UNIT_SETTLER"].Index, true);
		if pPlayer:IsHuman() == false then
			pPlayerUnits:SetBuildDisabled(GameInfo.Units["UNIT_EXPANSIONIST"].Index, true);
			else
			pPlayerUnits:SetBuildDisabled(GameInfo.Units["UNIT_EXPANSIONIST"].Index, false);
		end
	end
end

function OnPlayerTurnActivated_OneCity(playerID:number)
	local pAllPlayerIDs : table = PlayerManager.GetAliveIDs();	
	for _,iPlayerID in ipairs(pAllPlayerIDs) do
	
		local pPlayer : object = Players[iPlayerID];
		local pPlayerUnits : object = pPlayer:GetUnits();
		local pPlayerCities = pPlayer:GetCities();
		
		
		if pPlayerCities:GetCount() > 0 then
			for k, pUnit in pPlayerUnits:Members() do
				if pUnit:GetName() == "LOC_UNIT_SETTLER_NAME" then
					print("One City Challenge: Destroy Setter",iPlayerID)
					pPlayerUnits:Destroy(pUnit)	
				end				
			end
		end
	end
end

function OnCityConquered_OneCity(capturerID,  ownerID, cityID , cityX, cityY)
	local pPlayer = Players[capturerID];
	local pPlayerCities:table = pPlayer:GetCities();
	local pTreasury = pPlayer:GetTreasury()
	local pThisCity = pPlayerCities:FindID(cityID);
	local num_citizen = pThisCity:GetPopulation()
	
	-- One City Challenge ? Then Raze it, and give gold to the winner
	if b_onecity == true then
		print("One City Challenge: Raze City",cityID)
		CityManager.DestroyCity(pThisCity)
		if tonumber(num_citizen) ~= nil then
			local gold_given = tonumber(num_citizen)*100
			pTreasury:SetGoldBalance(pTreasury:GetGoldBalance()+gold_given)
		end
	end
	
	
	
end


-- Below Code is borrowed from TC_ of Civfanatics (with his blessing of course - I was just lazy) and adjusted for One City Challenge

function OnImprovementAddedToMapTC(locX, locY, eImprovementType, eOwner)
	
	local plot = Map.GetPlot(locX, locY);
	local plotIndex = plot:GetIndex();
	local improvementData:table = GameInfo.Improvements[eImprovementType];

	if(eOwner ~= -1) and (eOwner ~= 63)  and ((improvementData.ImprovementType == "IMPROVEMENT_SAILOR_WATCHTOWER")) then
		
		print("OnImprovementAddedToMapTC()---------------------");
--		print("    OnImprovementAddedToMapTC(): plotIndex = " .. plotIndex);
		
--		print("    OnImprovementAddedToMapTC: this improvement was a fort");
		local plot = Map.GetPlot(locX, locY);
		local plotIndex = plot:GetIndex();
		
		-- If fort is built on a resource, in order for the resource to be removed correctly in player resources we have to:
		-- Remove fort, then remove resource, then replace fort
		if (plot:GetResourceType() ~= -1) then
			
--			print("    OnImprovementAddedToMapTC: Fort built on resource. plot:GetResourceType() = " .. plot:GetResourceType() ..". Removing fort, removing resource, replacing fort");
			ImprovementBuilder.SetImprovementType(plot, -1); --remove fort --Nothing will happen in OnImprovementRemovedTC because this fort has not been added into table fortPlots yet
			ResourceBuilder.SetResourceType(plot, -1); --remove resource
			ImprovementBuilder.SetImprovementType(plot, eImprovementType, eOwner); --replace fort
			
			return -- Skip AddToFortTable because OnImprovementAddedToMapTC is called again when we rebuild the fort, as described above
		end

		AddToFortTable(locX, locY);

		-----------------------------------------------------------------------------------------

		if inGame then

			if cityConquered then

				local conqueredFortsTableLength = Tablelength(conqueredForts);
				if conqueredFortsTableLength > 0 then

					for i, conqueredFortPlotIndex in pairs(conqueredForts) do

						if plotIndex == conqueredFortPlotIndex then

							addConqueredFortsCounter = addConqueredFortsCounter + 1;
--							print("    OnImprovementAddedToMapTC: addConqueredFortsCounter = " .. addConqueredFortsCounter);
							break
						end
					end

--					print("    OnImprovementAddedToMapTC: conqueredFortsTableLength = " .. conqueredFortsTableLength);
					if addConqueredFortsCounter == conqueredFortsTableLength then
--						print("    OnImprovementAddedToMapTC: addConqueredFortsCounter = conqueredFortsTableLength - HandleConqueredForts()");
						HandleConqueredForts();				
					end
				end			
			else 
			
--				print("    OnImprovementAddedToMapTC: not conquered - granting fort plots for player " .. eOwner);
				GrantFortPlots( locX, locY, eOwner );

				local removedFortsTableLength = Tablelength(removeFortPlotsConquered);
				if removedFortsTableLength > 0 then

					for i, removedFortPlotIndex in pairs(removeFortPlotsConquered) do

						if plotIndex == removedFortPlotIndex then

							removeConqueredFortsCounter = removeConqueredFortsCounter + 1;
--						print("    OnImprovementAddedToMapTC: addConqueredFortsCounter = " .. addConqueredFortsCounter);
							break
						end
					end

					if removeConqueredFortsCounter == removedFortsTableLength then
--						
						CheckCityForNonAttachedTiles( conqueredCityPlot ); --this is where it gets called during a city conquered event string				
					end
				end				
			end
		else
--			print("    OnImprovementAddedToMapTC: inGame = false - skipping");
		end
	end
end

--==================================================================================================================================================================
function OnImprovementRemovedFromMapTC( locX :number, locY :number, eOwner :number )
	
	local plot = Map.GetPlot(locX, locY);
	local plotIndex = plot:GetIndex();

	for fort,fortPlotIndex in pairs(fortPlots) do -- look through our table of fort plots
		
		if fortPlotIndex == plotIndex then --if this improvement was a fort from our table of forts
			
			print("OnImprovementRemovedFromMapTC-----------------------");

			print("    OnImprovementRemovedFromMapTC: this improvement was a fort - plotIndex, x, y, owner = " .. plotIndex .. ", " .. locX .. ", " .. locY .. ", " .. eOwner);
			RemoveFromFortTable(locX, locY);

			-- in the case of building a city over a fort, end function immediately
			if IsPlotCity(locX, locY) then 
				return
			end
	
			if (cityConquered) then

				print("    OnImprovementRemovedFromMapTC: cityConquered = true - assigning forts to conqueredForts");
				AddToConqueredFortsTable(locX, locY);

			elseif (razedOrTraded) then
				
				print("    OnImprovementRemovedFromMapTC: razedOrTraded = true - assigning forts to razedForts");
				AddToRazedFortsTable(locX, locY);			
			
			--if cityConquered == false and razedOrTrade == false
			else 
				
				print("    OnImprovementRemovedFromMapTC: cityConquered = false and razedOrTraded = false; calling RemoveFortPlots");
				RemoveFortPlots( locX, locY, eOwner );

			end
			break --if we analyzed this fort, we are done with the loop			

		end
	end
end

--==================================================================================================================================================================
function OnImprovementChangedTC( locX :number, locY :number, improvementType, improvementOwner, resource, isPillaged, isWorked)
	
	local improvementData:table = GameInfo.Improvements[improvementType];

	if(improvementOwner ~= -1) and (improvementOwner ~= 63) and (isPillaged == 1) and ((improvementData.ImprovementType == "IMPROVEMENT_SAILOR_WATCHTOWER")) then
		
		print("OnImprovementChangedTC-----------------------");

		local plot = Map.GetPlot(locX, locY);
		local plotIndex = plot:GetIndex();
		print("    OnImprovementChangedTC: this improvement is a fort - plotIndex = " .. plotIndex);

		--================ CHECK FOR LAND COMBAT UNITS IN FORT PLOT ===================
		local unitsInPlot = Units.GetUnitsInPlot(plot);
		local playerWithLandCombatUnitOnFort;
			
		--print("    OnImprovementChangedTC Debug: unitsInPlot table length = " .. Tablelength(unitsInPlot));
		for _,unit in pairs(unitsInPlot) do
					
			local unitData:table = GameInfo.Units[unit:GetType()];
				
			if unitData.FormationClass == "FORMATION_CLASS_LAND_COMBAT" then
				playerWithLandCombatUnitOnFort = unit:GetOwner();
				break
			end
		end
		--==========================================================
		pillaged = false; --reset
		remotePillaged = false; --reset
		if playerWithLandCombatUnitOnFort then --If there is a combat land unit on the fort
			
			if playerWithLandCombatUnitOnFort == improvementOwner then	--when owner has a unit on the fort while it's pillaged, we don't consider it a remote pillage because we want to keep the plots
				print("    OnImprovementChangedTC: Pillaged while owner's land unit on fort. Don't remove plot ownership.");
				return --end function so plots are left as they are

			--If the fort is pillaged and there is an enemy land unit standing on the fort, then immediately give that fort to the player and end function
			--If we did not do this here, the game would give that fort to the player on their following turn so long as the unit stays on that tile
			elseif Players[playerWithLandCombatUnitOnFort]:GetDiplomacy():IsAtWarWith(improvementOwner) then
				pillaged = true; --used to identify case in RemoveFortPlots()
				print("    OnImprovementChangedTC: Pillaged with enemy land unit on fort. Set pillaged = true. Remove/Rebuild fort.");
				RemoveFort(locX, locY);
				BuildFort(locX, locY, playerWithLandCombatUnitOnFort);
				return

			else --if this fort was pillaged, and there isn't an owned or enemy land unit on the fort
				remotePillaged = true; --new
				print("    OnImprovementChangedTC: remotePillaged = true");
			end

		else --new
			remotePillaged = true; --new
			print("    OnImprovementChangedTC: remotePillaged = true");
		end

		if remotePillaged then

			local nearestCityToFortPlot = GetNearestCityOrCap(locX, locY, improvementOwner, -1);
			local distanceFromNearestCity = Map.GetPlotDistance(locX, locY, nearestCityToFortPlot:GetX(), nearestCityToFortPlot:GetY());

			--If the fort is within 2 tiles of the nearest city owned by the same player, then do nothing with the plots
			if distanceFromNearestCity < 3 then 
				return
			
			--If the fort is not garrisoned by it's owners' combat unit, nor garrisoned by an enemy unit, nor within 2 tiles of a city belonging to its owner, then call RemoveFortPlots()
			else
				print("    OnImprovementChangedTC: Call RemoveFortPlots() under case remotePillaged.");
				RemoveFortPlots( locX, locY, improvementOwner );
			end
		end
	end
end

--==================================================================================================================================================================
function OnCityConqueredTC(iVictoriousPlayer, iDefeatedPlayer, iNewCityID, iCityPlotX, iCityPlotY)

	
	cityConquered = true;
	conqueredCityPlot = Map.GetPlot(iCityPlotX, iCityPlotY);
	cityNewOwner = iVictoriousPlayer;
	cityOriginalOwner = iDefeatedPlayer;
	
	cityConqueredCount = 0;
	conqueredForts = {};
--	print("Clear conqueredForts Table--------------------------");
	addConqueredFortsCounter = 0;
	removeConqueredFortsCounter = 0;
--	print("    OnCityConqueredTC(): reset cityConqueredCount, conqueredForts; cityConquered = true; cityNewOwner = ".. cityNewOwner .. ", cityOriginalOwner = " .. iDefeatedPlayer);
	
end

--==================================================================================================================================================================
function OnDistrictRemovedTC(playerID:number, districtID:number, cityID:number, districtX:number, districtY:number, districtType:number)



	if ( districtType == GameInfo.Districts["DISTRICT_CITY_CENTER"].Index ) then

--		print("    OnDistrictRemovedTC: District was city center");
		local plot = Map.GetPlot(districtX, districtY);
		removedCityPlot = plot;
		removedCityOwner = playerID;

		if not cityConquered then
			razedOrTraded = true;
		end

		if cityConquered and ( conqueredCityPlot:GetIndex() == plot:GetIndex() )then
			cityConqueredCount = cityConqueredCount + 1;
--			print("    OnDistrictRemovedTC: cityConqueredCount = " .. cityConqueredCount);
		end

		if cityConqueredCount == 2 then
			cityConquered = false; --we use this marker through the city conquered event string. Events.DistrictRemoved fires twice for each district during a conquer. 
--			print("    OnDistrictRemovedTC: cityConquered = false");
		end    
	else
--		print("    OnDistrictRemovedTC: District was not city center");
	end
end

--==================================================================================================================================================================
function OnCityRemovedTC(playerID, cityID)


	--we do all of this so that the plots surrounding forts that were previously owned by this city are now given to the fort
	local winnerForts:table = {};
	local otherForts:table = {};

	if cityConquered then

--		print("    OnCityRemovedTC(): fortPlots table length before loop = " .. Tablelength(fortPlots));
		for i, fortPlotIndex in pairs(fortPlots) do
		
--			print("    OnCityRemovedTC(): looking at fortPlotIndex = " .. fortPlotIndex);
			local fortPlot = Map.GetPlotByIndex(fortPlotIndex);
			local owner = fortPlot:GetOwner();
			local distanceFromRemovedCityToFort = Map.GetPlotDistance(fortPlot:GetX(), fortPlot:GetY(), removedCityPlot:GetX(), removedCityPlot:GetY());
--			print("    OnCityRemovedTC(): distanceFromRemovedCityToFort = " .. distanceFromRemovedCityToFort);
--			print("    OnCityRemovedTC(): owner, cityNewOwner = " .. owner .. ", " .. cityNewOwner);
			
			--collect forts within 7 plots of removed city into two tables: winnerForts and otherForts
			if distanceFromRemovedCityToFort < 7 and owner == cityNewOwner then
			
				table.insert(winnerForts, fortPlotIndex);

			elseif distanceFromRemovedCityToFort < 7 and (owner ~= -1) and (owner ~= 63) then

				table.insert(otherForts, fortPlotIndex);		
			end
		end

		--call grant forts for winner forts first so they receive first dibs on the plots
		if (Tablelength(winnerForts) > 0) then
	
			for i, winnerFortPlotIndex in pairs(winnerForts) do

				local winnerFortPlot = Map.GetPlotByIndex(winnerFortPlotIndex);
				local owner = winnerFortPlot:GetOwner();

--				print("    OnCityRemovedTC(): GrantFortPlots for winnerFort index " .. winnerFortPlotIndex);
				GrantFortPlots( winnerFortPlot:GetX(), winnerFortPlot:GetY(), owner );

			end
		end

		--call grant forts for other forts
		if (Tablelength(otherForts) > 0) then
	
			for i, otherFortPlotIndex in pairs(otherForts) do

				local otherFortPlot = Map.GetPlotByIndex(otherFortPlotIndex);
				local owner = otherFortPlot:GetOwner();

--				print("    OnCityRemovedTC(): GrantFortPlots for otherFort index " .. otherFortPlotIndex);
				GrantFortPlots( otherFortPlot:GetX(), otherFortPlot:GetY(), owner );

			end
		end
	end

	if razedOrTraded then


		--Rebuild all razedForts for the previous owner
		for i, fortPlotIndex in pairs(razedForts) do

			local fortPlot = Map.GetPlotByIndex(fortPlotIndex);
--			print("    OnCityRemovedTC(): fortPlot:GetX, fortPlot:GetY, removedCityOwner = " .. fortPlot:GetX() .. ", " .. fortPlot:GetY() .. ", " .. removedCityOwner);
			BuildFort(fortPlot:GetX(), fortPlot:GetY(), removedCityOwner ); --POINTER OR INDEX? DECIDE AT LINE 255

		end

		--Check all nearby and make sure they update their claim
		for i, fortPlotIndex in pairs(fortPlots) do

			local fortPlot = Map.GetPlotByIndex(fortPlotIndex);
			local ignore:boolean = false;
			
			--if fort was already processed as a razedOrTraded fort, mark to ignore this fort
			for i, razedOrTradedFortPlotIndex in pairs(razedForts) do
			
				if (razedOrTradedFortPlotIndex == fortPlotIndex) then  
					ignore = true;
				end
			end

			--if not ignoring this fort, make sure its plots are claimed appropriately
			--we should check to see if fort is within 5 tiles, but this causes problems when its the capital city which has forts further than that
			if not ignore then
				
				local owner = fortPlot:GetOwner();
				GrantFortPlots( fortPlot:GetX(), fortPlot:GetY(), owner );

			end
		end

--		print("    OnCityRemovedTC(): set razedOrTraded = false, razedForts = {}.");
		razedOrTraded = false;
		razedForts = {}; 
--		print("    OnCityRemovedTC(): Clear razedForts Table");

	end
end

--==================================================================================================================================================================
function OnCityInitializedTC(playerID, cityID, x, y)

	
	local conqueredFortsTableLength = Tablelength(conqueredForts);

	if (cityConquered and (conqueredFortsTableLength == 0) ) then
--		print("    OnCityInitializedTC(): conqueredFortsTableLength = 0 - setting cityConquered = false, to stop our normal code sequence");
		cityConquered = false;
	end
end



--==================================================================================================================================================================
function OnUnitMoveCompleteTC(iPlayer, iunitID, iPlotX, iPlotY)    --if plot is a fort, and isn't owned, claim plots. also, repair if pillaged
	
	local plot = Map.GetPlot(iPlotX, iPlotY);
	local unitData:table = GameInfo.Units[Players[iPlayer]:GetUnits():FindID(iunitID):GetType()];

	if ( IsPlotFort(iPlotX, iPlotY) ) and plot:IsImprovementPillaged() and (unitData.FormationClass == "FORMATION_CLASS_LAND_COMBAT") then
		
		print("OnUnitMoveCompleteTC----------------------");
		print("    OnUnitMoveCompleteTC(): Land Combat unit moved onto a pillaged fort.");

		if plot:IsOwned() then
			
			if plot:GetOwner() == iPlayer then --if the unit and the fort belong to the same player
				print("    OnUnitMoveCompleteTC(): Owner repairing and reclaiming fort.");
				ImprovementBuilder.SetImprovementPillaged(plot, false); --repair fort
				GrantFortPlots( iPlotX, iPlotY, plot:GetOwner() ); --update adjacent plots
			
			elseif Players[iPlayer]:GetDiplomacy():IsAtWarWith(plot:GetOwner()) then --if unit owner is at war with fort owner   NIL VALUE HERE SOMEWHERE
				print("    OnUnitMoveCompleteTC(): Enemy unit taking control of pillaged fort.");
				pillaged = true; --set marker so RemoveFortPlots knows how to handle
				RemoveFort(iPlotX, iPlotY); --remove fort owner's fort
				BuildFort(iPlotX, iPlotY, iPlayer); --build fort for player with unit on fort
			end
		
		else
			print("    OnUnitMoveCompleteTC(): Fort is unowned. Unit is repairing and taking control of fort.");
			ImprovementBuilder.SetImprovementPillaged(plot, false); --repair fort
			GrantFortPlots( iPlotX, iPlotY, iPlayer ); --give plots to unit owner
		end			
	end
end

--==================================================================================================================================================================
function OnLoadGameViewStateDoneTC()
	
	print("OnLoadGameViewStateDoneTC: inGame = true");
	inGame = true;

end

--==================================================================================================================================================================

function RemoveFort(locX, locY)

	print("RemoveFort--------------------------");

	local plot = Map.GetPlot(locX, locY);
	local plotIndex = plot:GetIndex();

--	print("    RemoveFort(): plotIndex = " .. plotIndex);

	ImprovementBuilder.SetImprovementType(plot, -1);

end

--==================================================================================================================================================================
function BuildFort(locX, locY, owner)
	
	print("BuildFort--------------------------");

	local plot = Map.GetPlot(locX, locY);
	local plotIndex = plot:GetIndex();

--	print("    BuildFort, plotIndex = " .. plotIndex);

	local iFortImprovementType = GameInfo.Improvements["IMPROVEMENT_SAILOR_WATCHTOWER"].Index;
	ImprovementBuilder.SetImprovementType(plot, iFortImprovementType, owner);

end

--==================================================================================================================================================================
function GrantFortPlots( locX, locY, owner )

	print("GrantFortPlots()-------------------------");
	
	if(owner == -1)then 
		print("    GrantFortPlots(): owner = -1 -Ending function")
		return 
	end

	local fortPlot = Map.GetPlot(locX, locY);
	
	local player = Players[owner];
	local playerCities = player:GetCities();
	local playerCapital = playerCities:GetCapitalCity();
		
	local nearestCityToFortPlot = GetNearestCityOrCap(fortPlot:GetX(),fortPlot:GetY(), owner, -1);
	local distanceFromNearestCityToFortPlot = Map.GetPlotDistance(fortPlot:GetX(),fortPlot:GetY(),nearestCityToFortPlot:GetX(),nearestCityToFortPlot:GetY());
	local cityThatFortPlotBelongsTo;
--	print("    GrantFortPlots(): owner = " .. owner .. ", plotIndex = " .. fortPlot:GetIndex() .. ", playerCapital = " .. playerCapital:GetName());

	--Give ownership of the fort tile to the player's city. Could be player placing a new fort, a player pillaging an enemy fort, or plots being updated from a new city being built
	if (not fortPlot:IsOwned()) or (fortPlot:GetOwner() == owner) then
--		print ("    GrantFortPlots(): FortPlot: Setting Owner");
		if distanceFromNearestCityToFortPlot > 3 then
			WorldBuilder.CityManager():SetPlotOwner(fortPlot, playerCapital);
			cityThatFortPlotBelongsTo = playerCapital;
		else
			WorldBuilder.CityManager():SetPlotOwner(fortPlot, nearestCityToFortPlot);
			cityThatFortPlotBelongsTo = nearestCityToFortPlot;
		end
	else
--		print("    GrantFortPlots(): FortPlot: Owned by other player -- shouldn't be seeing this");
	end		
--	print("    GrantFortPlots(): FortPlot: Nearest city distance = " .. distanceFromNearestCityToFortPlot);	

	for i=0,5,1 do --Look at each adjacent plot
		
		local adjacentPlot = Map.GetAdjacentPlot(fortPlot:GetX(), fortPlot:GetY(), i);

		if(not adjacentPlot:IsOwned()) or (adjacentPlot:GetOwner() == owner) then

			local adjacentPlotIsFort = IsPlotFort(adjacentPlot:GetX(), adjacentPlot:GetY());
			local adjacentPlotIsDistrict = IsPlotDistrict(adjacentPlot:GetX(), adjacentPlot:GetY());
			local adjacentPlotIsCity = IsPlotCity(adjacentPlot:GetX(), adjacentPlot:GetY());

			if (not adjacentPlotIsDistrict) and (not adjacentPlotIsCity) and (not adjacentPlotIsFort) then --if adjacent plot is not a district, city, or fort
				
				local nearestCityToAdjacentPlot = GetNearestCityOrCap(adjacentPlot:GetX(),adjacentPlot:GetY(), owner, -1);
				local distanceFromNearestCityToAdjacentPlot = Map.GetPlotDistance(adjacentPlot:GetX(),adjacentPlot:GetY(),nearestCityToAdjacentPlot:GetX(),nearestCityToAdjacentPlot:GetY());

				if distanceFromNearestCityToAdjacentPlot > 3 then
					WorldBuilder.CityManager():SetPlotOwner(adjacentPlot, cityThatFortPlotBelongsTo);	 --give adjacent plot to same city as fort plot	if adjacent plot is not within 3 tiles of another city
				else
					WorldBuilder.CityManager():SetPlotOwner(adjacentPlot, nearestCityToAdjacentPlot);	--give adjacent plot to nearest city if within 3 plots
				end		

			else
--				print ("    GrantFortPlots(): AdjacentPlot is a district, city, or fort - skipping grant ownership");
			end

		else
--			print ("    GrantFortPlots(): AdjacentPlot: Owned by other player");
		end
	end
end

--==================================================================================================================================================================
function RemoveFortPlots( locX :number, locY :number, eOwner :number)
	
	print("RemoveFortPlots()--------------------------");
	
	if(eOwner == -1)then 
--		print("    RemoveFortPlots(): owner = -1 -Ending function")
		return 
	end

	local conquered:boolean = false;

	local fortPlot = Map.GetPlot(locX, locY);
	local fortPlotIndex = fortPlot:GetIndex();

	if not pillaged and not remotePillaged then
		for i, conqueredFortPlotIndex in pairs(removeFortPlotsConquered) do
		
--			print("    RemoveFortPlots(): checking conqueredFortPlotIndex " .. conqueredFortPlotIndex);
			if conqueredFortPlotIndex == fortPlotIndex then

--				print("    RemoveFortPlots(): conquered = true ");
				conquered = true;
--				print("    RemoveFortPlots(): removed plot from removeFortPlotsConquered - new table length = " .. conqueredFortPlotIndex);
			end
		end
	end
		
	--------------------------------------------------------------CASE: CONQUERED------------------------------------------------------------------------------------
	--                                                   giving fort back to original owner
	--                                                      RemoveFortPlots(cityNewOwner)

	if conquered then

		print("    RemoveFortPlots(): CASE: CONQUERED");
--		print("    RemoveFortPlots(): remove fortPlot ownership");
		fortPlot:SetOwner(-1);

		for i=0,5,1 do
		
--			print("-------- RemoveFortPlots - ADJACENTPLOT " .. (i + 1) .. " of 6 --------");
			local adjacentPlot = Map.GetAdjacentPlot(fortPlot:GetX(), fortPlot:GetY(), i);

			local adjacentPlotIsOwned = isPlotOwned(adjacentPlot:GetX(), adjacentPlot:GetY());
			local adjacentPlotBelongsToPlayer = false;
			local adjacentPlotHasFort = false;
			local adjacentPlotIsDistrict = false;
			local adjacentPlotIsCity = false;

			if adjacentPlotIsOwned then 

				adjacentPlotBelongsToPlayer = isPlotBelongToPlayer(adjacentPlot:GetX(), adjacentPlot:GetY(), eOwner);

				if adjacentPlotBelongsToPlayer then
					
					adjacentPlotHasFort = IsPlotFort(adjacentPlot:GetX(), adjacentPlot:GetY());
					adjacentPlotIsDistrict = IsPlotDistrict(adjacentPlot:GetX(), adjacentPlot:GetY());
					adjacentPlotIsCity = IsPlotCity(adjacentPlot:GetX(), adjacentPlot:GetY());
					
					local distanceToConqueredCity = Map.GetPlotDistance(adjacentPlot:GetX(),adjacentPlot:GetY(),conqueredCityPlot:GetX(),conqueredCityPlot:GetY());
		
					if adjacentPlotIsDistrict == false and adjacentPlotIsCity == false and adjacentPlotHasFort == false and distanceToConqueredCity > 1 then

--						print("    RemoveFortPlots(): Adjacent plot is owned, and does not hold a district or fort, and is greater than 1 tile from conquered city - remove ownership (to reclaim for previous owner)");
						adjacentPlot:SetOwner(-1);
			
					else
--						print("    RemoveFortPlots(): Adjacent plot is owned, but holds a district or fort or is adjacent to city - retain ownership");
					end
				else
--					print("    RemoveFortPlots(): Adjacent plot is not owned by this player - retain ownership");
				end
			else
--				print("    RemoveFortPlots(): Adjacent plot is not owned");
			end
		end
	
	-----------------------------------------------------CASE: PILLAGED WITH CLAIM CHANGE------------------------------------------------------------
	--                                              fort plots changing ownership due to pillage
	--                                                       with an enemy land unit
	--                                                      RemoveFortPlots(fortOwner)

	elseif pillaged then
		
		print(" -- RemoveFortPlots(): CASE: PILLAGED --");
		fortPlot:SetOwner(-1);

		for i=0,5,1 do

			local adjacentPlot = Map.GetAdjacentPlot(fortPlot:GetX(), fortPlot:GetY(), i);
			local adjacentPlotIsOwned = isPlotOwned(adjacentPlot:GetX(), adjacentPlot:GetY());

			if adjacentPlotIsOwned then 

				local adjacentPlotBelongsToPlayer = isPlotBelongToPlayer(adjacentPlot:GetX(), adjacentPlot:GetY(), eOwner);
				local adjacentPlotHasFort = IsPlotFort(adjacentPlot:GetX(), adjacentPlot:GetY());
				local adjacentPlotIsAdjacentToOwnedFort = IsAdjacentToOwnedFort(adjacentPlot:GetX(), adjacentPlot:GetY(), eOwner);
				local adjacentPlotIsDistrict = IsPlotDistrict(adjacentPlot:GetX(), adjacentPlot:GetY());
				local adjacentPlotIsCity = IsPlotCity(adjacentPlot:GetX(), adjacentPlot:GetY());
				local nearestCityToAdjacentPlot = GetNearestCityOrCap(adjacentPlot:GetX(), adjacentPlot:GetY(), eOwner, -1);
				local adjacentPlotDistanceToCity = Map.GetPlotDistance(adjacentPlot:GetX(),adjacentPlot:GetY(),nearestCityToAdjacentPlot:GetX(),nearestCityToAdjacentPlot:GetY());

				if adjacentPlotBelongsToPlayer then
					
--					print("    RemoveFortPlots(): adjacentPlotHasFort = " .. tostring(adjacentPlotHasFort));
--					print("    RemoveFortPlots(): adjacentPlotIsAdjacentToOwnedFort = " .. tostring(adjacentPlotIsAdjacentToOwnedFort));
--					print("    RemoveFortPlots(): adjacentPlotIsDistrict = " .. tostring(adjacentPlotIsDistrict));
--					print("    RemoveFortPlots(): adjacentPlotIsCity = " .. tostring(adjacentPlotIsCity));
--					print("    RemoveFortPlots(): adjacentPlotDistanceToCity = " .. tostring(adjacentPlotDistanceToCity));

					if adjacentPlotHasFort or adjacentPlotIsAdjacentToOwnedFort or adjacentPlotIsDistrict or adjacentPlotIsCity or (adjacentPlotDistanceToCity == 1) then					
--							print("    RemoveFortPlots(): Adjacent plot holds a fort, is adjacent to an owned fort or city, or holds a district. Retain ownership");
					else					
--							print("    RemoveFortPlots(): Removing ownership of adjacent plot");
						adjacentPlot:SetOwner(-1);
					end
				else
--						print("    RemoveFortPlots(): adjacent plot does not belong to fort owner");
				end
			end
		end

		local nearestCityToFortPlot = GetNearestCityOrCap(locX, locY, eOwner, -1);
		local distanceToCity = Map.GetPlotDistance(locX, locY, nearestCityToFortPlot:GetX(), nearestCityToFortPlot:GetY());
		if distanceToCity < 3 then 
			CheckCityForNonAttachedTiles( Map.GetPlot( nearestCityToFortPlot:GetX(X), nearestCityToFortPlot:GetY(Y)) );
		end

		pillaged = false; --reset flag


	------------------------------------------------------------CASE: RAZED -----------------------------------------------------------
	--										No need to remove ownership of plots in this case
	--                                 Traded case does not happen here. It is moved to FULL REMOVE
	                                          
	elseif razedOrTraded then
		print(" -- RemoveFortPlots(): CASE: razedOrTraded -- do nothing");
	
	---------------------------------------------------------CASE: FULL REMOVE------------------------------------------------------------
	--            player removes fort    -or-    player loses claim on fort due to remote pillage    -or-    city traded
	--                                                   RemoveFortPlots(fortOwner)

		
	else --else remotePillaged or normal
		
		if eOwner == fortPlot:GetOwner() then --If this is false, it signals a city traded event. Possibly liberated too.

			print(" -- RemoveFortPlots(): CASE: FULL REMOVE --");

			fortPlot:SetOwner(-1); --we do this initially so that the adjacent plots will not consider this fort as owned under any circumstance

				local adjacentPlot;
				local adjacentPlotIsOwned = false;


			-- Handle Adjacent Plots
			for i=0,5,1 do

				adjacentPlot = Map.GetAdjacentPlot(fortPlot:GetX(), fortPlot:GetY(), i);
				adjacentPlotIsOwned = isPlotOwned(adjacentPlot:GetX(), adjacentPlot:GetY());
			
				if (adjacentPlotIsOwned == true) then 

					local adjacentPlotBelongsToPlayer = isPlotBelongToPlayer(adjacentPlot:GetX(), adjacentPlot:GetY(), eOwner);
					local adjacentPlotHasFort = IsPlotFort(adjacentPlot:GetX(), adjacentPlot:GetY());
					local adjacentPlotIsAdjacentToOwnedFort = IsAdjacentToOwnedFort(adjacentPlot:GetX(), adjacentPlot:GetY(), eOwner);
					local adjacentPlotIsAdjacentToUnownedCityOwnedBy = IsAdjacentToUnownedCityOwnedBy(adjacentPlot:GetX(), adjacentPlot:GetY(), eOwner);
					local adjacentPlotIsAdjacentToUnownedFortOwnedBy = IsAdjacentToUnownedFortOwnedBy(adjacentPlot:GetX(), adjacentPlot:GetY(), eOwner);
					local adjacentPlotIsDistrict = IsPlotDistrict(adjacentPlot:GetX(), adjacentPlot:GetY());
					local adjacentPlotIsCity = IsPlotCity(adjacentPlot:GetX(), adjacentPlot:GetY());				

					if adjacentPlotBelongsToPlayer then
					
						local nearestCityToAdjacentPlot = GetNearestCityOrCap(adjacentPlot:GetX(), adjacentPlot:GetY(), eOwner, -1);
						local adjacentPlotDistanceToCity = Map.GetPlotDistance(adjacentPlot:GetX(),adjacentPlot:GetY(),nearestCityToAdjacentPlot:GetX(),nearestCityToAdjacentPlot:GetY());
					
						if adjacentPlotHasFort or adjacentPlotIsAdjacentToOwnedFort or adjacentPlotIsDistrict or adjacentPlotIsCity or (adjacentPlotDistanceToCity < 6) then
						
							print("    RemoveFortPlots(): Adjacent plot at (" .. adjacentPlot:GetX() .. ", " .. adjacentPlot:GetY() .. ") holds a fort, is adjacent to an owned fort, holds a district, or is within 5 plots from city. Retain ownership");

						elseif adjacentPlotIsAdjacentToUnownedCityOwnedBy ~= -1 then --if the adjacent plot we are look at is next to a city owned by a different player
						
							local nearestForeignPlayerCityToPlot = GetNearestCityOrCap(adjacentPlot:GetX(), adjacentPlot:GetY(), adjacentPlotIsAdjacentToUnownedCityOwnedBy, -1);
							print("    RemoveFortPlots(): Adjacent plot at (" .. adjacentPlot:GetX() .. ", " .. adjacentPlot:GetY() .. ") is being reassigned to .. " .. tostring(nearestForeignPlayerCityToPlot:GetName()));
							WorldBuilder.CityManager():SetPlotOwner(adjacentPlot, nearestForeignPlayerCityToPlot);

						elseif adjacentPlotIsAdjacentToUnownedFortOwnedBy ~= -1 then --if the adjacent plot we are look at is next to a fort owned by a different player
						
							local nearestForeignPlayerCityToPlot = GetNearestCityOrCap(adjacentPlot:GetX(), adjacentPlot:GetY(), adjacentPlotIsAdjacentToUnownedFortOwnedBy, -1);
							local distanceFromNearestForeignCityToPlot = Map.GetPlotDistance(adjacentPlot:GetX(),adjacentPlot:GetY(),nearestForeignPlayerCityToPlot:GetX(),nearestForeignPlayerCityToPlot:GetY());
	--						print("    RemoveFortPlots(): Fort Plot: Assigning to player " .. fortPlotIsAdjacentToUnownedCityOwnedBy .. ", city " .. fortPlotIsAdjacentToUnownedCityOwnedBy:GetName());
						
							if distanceFromNearestForeignCityToPlot < 4 then --grant plot to that city
								WorldBuilder.CityManager():SetPlotOwner(adjacentPlot, nearestForeignPlayerCityToPlot);
								print("    RemoveFortPlots(): Adjacent plot at (" .. adjacentPlot:GetX() .. ", " .. adjacentPlot:GetY() .. ") is being reassigned to .. " .. tostring(nearestForeignPlayerCityToPlot:GetName()));

							else --grant plot to that player's capital
								local foreignPlayer = Players[adjacentPlotIsAdjacentToUnownedFortOwnedBy];
								local foreignPlayerCities = foreignPlayer:GetCities();
								local foreignPlayerCapital = foreignPlayerCities:GetCapitalCity();
								print("    RemoveFortPlots(): Adjacent plot at (" .. adjacentPlot:GetX() .. ", " .. adjacentPlot:GetY() .. ") is being reassigned to .. " .. tostring(foreignPlayerCapital:GetName()));
								WorldBuilder.CityManager():SetPlotOwner(adjacentPlot, foreignPlayerCapital);
							end

						else --If this plot isn't a fort, district or city, and its not within 5 tiles of an owned city, and it's not adjacent to ANY fort or city, then remove ownership
					
							print("    RemoveFortPlots(): Removing ownership of adjacent plot at (" .. adjacentPlot:GetX() .. ", " .. adjacentPlot:GetY() .. ")");
							adjacentPlot:SetOwner(-1);

						end

					else
						print("    RemoveFortPlots(): adjacent plot at (" .. adjacentPlot:GetX() .. ", " .. adjacentPlot:GetY() .. ") does not belong to fort owner. Skipping.");
					end
				end
			end	
		
			local nearestCityToFortPlot = GetNearestCityOrCap(locX, locY, eOwner, -1);	
			local fortPlotDistanceToOwnedCity = Map.GetPlotDistance(locX, locY, nearestCityToFortPlot:GetX(), nearestCityToFortPlot:GetY());
			local fortPlotIsAdjacentToOwnedFort = IsAdjacentToOwnedFort(locX, locY, eOwner);
			local fortPlotIsAdjacentToUnownedFortOwnedBy = IsAdjacentToUnownedFortOwnedBy( locX, locY, eOwner);
			local fortPlotIsAdjacentToUnownedCityOwnedBy = IsAdjacentToUnownedCityOwnedBy( locX, locY, eOwner);

			--handle fortPlot		
			if fortPlotIsAdjacentToOwnedFort == false and (fortPlotDistanceToOwnedCity > 1) then --if fort plot IS NOT adjacent to an owned fort AND is not adjacent to an owned city
					
				if (fortPlotIsAdjacentToUnownedCityOwnedBy ~= -1) then -- if fort plot IS next to a city owned by another player, give plot to that city's owner

					local nearestForeignPlayerCityToFortPlot = GetNearestCityOrCap(locX, locY, fortPlotIsAdjacentToUnownedCityOwnedBy, -1);
					print("    RemoveFortPlots(): Fort plot is adjacent to foreign city. Assigning plot to player " .. fortPlotIsAdjacentToUnownedCityOwnedBy);
					WorldBuilder.CityManager():SetPlotOwner(fortPlot, nearestForeignPlayerCityToFortPlot);
							
				elseif (fortPlotIsAdjacentToUnownedFortOwnedBy ~= -1) then -- if fort plot IS next to a fort owned by another player, give plot to that fort's owner

					local nearestForeignPlayerCityToFortPlot = GetNearestCityOrCap(locX, locY, fortPlotIsAdjacentToUnownedFortOwnedBy, -1);
					print("    RemoveFortPlots(): Fort plot is adjacent to foreign fort. Assigning plot to player " .. fortPlotIsAdjacentToUnownedFortOwnedBy .. ", city " .. nearestForeignPlayerCityToFortPlot:GetName());
					WorldBuilder.CityManager():SetPlotOwner(fortPlot, nearestForeignPlayerCityToFortPlot);

				elseif fortPlotDistanceToOwnedCity > 5 then
					print("    RemoveFortPlots(): Fort plot is not adjacent to any fort or city, and is further than 5 plots from nearest owned city. No ownership.");

				else
					print("    RemoveFortPlots(): Fort plot is not adjacent to any fort or city, and is within 5 plots from nearest owned city. Keeping fort plot for owner " .. tostring(eOwner));
					WorldBuilder.CityManager():SetPlotOwner(fortPlot, nearestCityToFortPlot);
				end

			else
				print("    RemoveFortPlots(): Fort plot is adjacent to owned fort or city - keeping fort plot");
				WorldBuilder.CityManager():SetPlotOwner(fortPlot, nearestCityToFortPlot);
			end
			--shouldn't need this because if the plots are near the city, they are kept in this case
			--CheckCityForNonAttachedTiles( Map.GetPlot( nearestCityToFortPlot:GetX(), nearestCityToFortPlot:GetY() ) );

		else --city traded
			local nearestCityToFortPlot = GetNearestCityOrCap(locX, locY, eOwner, -1);
			CheckCityForNonAttachedTiles( Map.GetPlot( nearestCityToFortPlot:GetX(), nearestCityToFortPlot:GetY() ) );
			print("    RemoveFortPlots(): eOwner =/= fortPlot:GetOwner(). City Traded. Not removing plot ownership.");
		end
	end
	remotePillaged = false;
	-----------------------------------------------------------------------------------------------------------------------------------------
end

--==================================================================================================================================================================
function HandleConqueredForts()

	print("HandleConqueredForts--------------------")

--	print("    HandleConqueredForts: set cityConquered = false");
	cityConquered = false;

--	print("    HandleConqueredForts(): initial conqueredForts table length = " .. Tablelength(conqueredForts));
--	print("    HandleConqueredForts(): cityNewOwner = " .. cityNewOwner);
--	print("    HandleConqueredForts(): cityOriginalOwner = " .. cityOriginalOwner);

	for i, conqueredFortPlotIndex in pairs(conqueredForts) do
		
--		print("    HandleConqueredForts(): inside loop. Table length = " .. Tablelength(conqueredForts));

		local conqueredFortPlot = Map.GetPlotByIndex(conqueredFortPlotIndex);

		if Players[cityOriginalOwner]:IsAlive() then
			
--			print("    HandleConqueredForts(): conqueredForts table length = " .. Tablelength(conqueredForts));
--			print("    HandleConqueredForts(): inserting plot " .. conqueredFortPlotIndex .. " into removeFortPlotsConquered table");
			table.insert(removeFortPlotsConquered, conqueredFortPlotIndex); --place this fort into removeFortPlotsConquered table for reference in RemoveFortPlots

--			print("    HandleConqueredForts(): rebuild fort for player who lost city since fort was still standing when city taken");
			RemoveFort(conqueredFortPlot:GetX(), conqueredFortPlot:GetY());
			BuildFort(conqueredFortPlot:GetX(), conqueredFortPlot:GetY(), cityOriginalOwner); --buildFort will trigger grantFortPlots, which will assign the forts to the players (new) cap

		else --if player is dead, forts are automatically transferred to new owner 
			
--			print("    HandleConqueredForts(): GrantFortPlots() for winner due to taking player's last city");
			GrantFortPlots(conqueredFortPlot:GetX(), conqueredFortPlot:GetY(), cityNewOwner); --reassigns the captured fort plots to the winning player's capital

		end
--		print("    HandleConqueredForts(): removing fort from conqueredFortPlotIndex");
	end

	conqueredForts = {}; 
--	print("Clear conqueredForts Table--------------------")
--	print("    HandleConqueredForts(): outside loop, end of function. Table length = " .. Tablelength(conqueredForts));

end


function AddToFortTable(locX, locY)
	
	print("AddToFortTable--------------------------");
	local addPlotToTable = true;
	local plot = Map.GetPlot(locX, locY);
	local plotIndex = plot:GetIndex();

	for fort,fortPlotIndex in pairs(fortPlots) do
			
		if fortPlotIndex == plotIndex then

			addPlotToTable = false;
			break

		end
	end

	if addPlotToTable then

--		print("    AddToFortTable(): Adding plot to table fortPlots - plotIndex = " .. plotIndex);
		table.insert(fortPlots, plotIndex);

	else

--		print("    AddToFortTable(): Not adding plotIndex " .. plotIndex .. " to fortPlots because it already exists in the table");

	end

	local tableLength = Tablelength(fortPlots);
--	print("    AddToFortTable(): fortPlots table length = " .. tableLength);

end
--==================================================================================================================================================================

function RemoveFromFortTable(locX, locY)
	
	print("RemoveFromFortTable--------------------------");

	local plot = Map.GetPlot(locX, locY);
	local plotIndex = plot:GetIndex();
	local fortPlotsTableIndex = FindTableIndex(fortPlots,plotIndex);
--	print("    RemoveFromFortTable(): Removing plot from table fortPlots - plot:GetIndex() = " .. plotIndex);
	table.remove(fortPlots, fortPlotsTableIndex);

	local tableLength = Tablelength(fortPlots);
--	print("    RemoveFromFortTable(): fortPlots table length = " .. tableLength);

end
--==================================================================================================================================================================

function AddToConqueredFortsTable(locX, locY)
	
	print("AddToConqueredFortsTable--------------------------");

	local addPlotToTable = true;
	local plot = Map.GetPlot(locX, locY);
	local plotIndex = plot:GetIndex();

	for fort,fortPlotIndex in pairs(conqueredForts) do
			
		if fortPlotIndex == plotIndex then

			addPlotToTable = false;
			break

		end
	end

	if addPlotToTable then

--		print("    AddToConqueredFortsTable(): Adding plot to table conqueredForts - plotIndex = " .. plotIndex);
		table.insert(conqueredForts, plotIndex);

	else

--		print("    AddToConqueredFortsTable(): Not adding plotIndex " .. plotIndex .. " to conqueredForts because it already exists in the table");

	end

	local tableLength = Tablelength(conqueredForts);
--	print("    AddToConqueredFortsTable(): conqueredForts table length = " .. tableLength);

end
--==================================================================================================================================================================

function AddToRazedFortsTable(locX, locY)
	
	print("AddToRazedFortsTable--------------------------");

	local addPlotToTable = true;
	local plot = Map.GetPlot(locX, locY);
	local plotIndex = plot:GetIndex();

	for fort,fortPlotIndex in pairs(razedForts) do
			
		if fortPlotIndex == plotIndex then

			addPlotToTable = false;
			break

		end
	end

	if addPlotToTable then

--		print("    AddToRazedFortsTable(): Adding plot to table razedForts - plotIndex = " .. plotIndex);
		table.insert(razedForts, plotIndex);

	else

--		print("    AddToRazedFortsTable(): Not adding plotIndex " .. plotIndex .. " to razedForts because it already exists in the table");

	end

	local tableLength = Tablelength(razedForts);
--	print("    AddToRazedFortsTable(): razedForts table length = " .. tableLength(razedForts));

end
--==================================================================================================================================================================

function isPlotOwned(locX, locY)

	--print("In isPlotOwned()");
	local plot = Map.GetPlot(locX, locY);

	if (plot:IsOwned()) then

		--print("isPlotOwned = true");
		return true;

	else

		--print("isPlotOwned = false");
		return false;

	end
end
--==================================================================================================================================================================

function isPlotBelongToPlayer(locX, locY, eOwner)

	--print("In isPlotBelongToPlayer(), eOwner = " .. eOwner);
	local plot = Map.GetPlot(locX, locY);

	if (eOwner ~= -1) and (plot:GetOwner() == eOwner) then

		--print("isPlotBelongToPlayer = true");
		return true;

	else

		--print("isPlotBelongToPlayer = false");
		return false;

	end
end
--==================================================================================================================================================================

function IsPlotFort(locX, locY)
	
	--print("In IsPlotFort()");
	local plot = Map.GetPlot(locX, locY);
	local improvement = plot:GetImprovementType();
	local improvementData:table = GameInfo.Improvements[improvement];

	if (improvement ~= -1) and ((improvementData.ImprovementType == "IMPROVEMENT_SAILOR_WATCHTOWER") ) then

		--print("IsPlotFort = true");
		return true;

	else

		--print("IsPlotFort = false");
		return false;

	end
end
--==================================================================================================================================================================

function IsPlotDistrict(locX, locY)

	--print("In IsPlotDistrict()");
	local plot = Map.GetPlot(locX, locY);
	local districtType = plot:GetDistrictType();
	
	if districtType ~= -1 then

		--print("IsPlotDistrict = true");
		return true;

	else
		
		--print("IsPlotDistrict = false");
		return false;

	end
end
--==================================================================================================================================================================

function IsPlotCity(locX, locY)
	
	local plot = Map.GetPlot(locX, locY);
	local isCity = plot:IsCity();
	return isCity;

end
--==================================================================================================================================================================

function IsAdjacentToOwnedFort(locX, locY, eOwner)

	--print("In IsAdjacentToOwnedFort(), locX, locY, eOwner = " .. locX .. ", " .. locY .. ", " .. eOwner);
	for i=0,5,1 do
		
		--print("-------- IsAdjacentToOwnedFort() " .. (i+1) .. " of 6 --------");
		local adjacentPlot = Map.GetAdjacentPlot(locX, locY, i);

		local adjacentPlotIsOwned = isPlotOwned(adjacentPlot:GetX(), adjacentPlot:GetY());

		local adjacentPlotBelongsToPlayer = false;
		local adjacentPlotIsFort = false;

		if adjacentPlotIsOwned then
			adjacentPlotBelongsToPlayer = isPlotBelongToPlayer(adjacentPlot:GetX(), adjacentPlot:GetY(), eOwner);
			adjacentPlotIsFort = IsPlotFort(adjacentPlot:GetX(), adjacentPlot:GetY());

			if adjacentPlotBelongsToPlayer and adjacentPlotIsFort then

				--print("IsAdjacentToOwnedFort: " .. (i+1) .. " of 6: RETURN TRUE");
				return true;

			end
		end
	end

	--print("IsAdjacentToOwnedFort: " .. (i+1) .. " of 6: RETURN FALSE");
	return false;

end
--==================================================================================================================================================================

function IsAdjacentToUnownedFortOwnedBy(locX, locY, eOwner)
	
	--print("In IsAdjacentToUnownedFortOwnedBy(), eOwner = " .. eOwner);

	for i=0,5,1 do
		
		--print("-------- IsAdjacentToUnownedFortOwnedBy() " .. (i+1) .. " of 6 --------");
		local adjacentPlot = Map.GetAdjacentPlot(locX, locY, i);

		local adjacentPlotIsOwned = isPlotOwned(adjacentPlot:GetX(), adjacentPlot:GetY());

		local adjacentPlotBelongsToPlayer = false;
		local adjacentPlotIsFort = false;

		if adjacentPlotIsOwned then
			adjacentPlotBelongsToPlayer = isPlotBelongToPlayer(adjacentPlot:GetX(), adjacentPlot:GetY(), eOwner);
			adjacentPlotIsFort = IsPlotFort(adjacentPlot:GetX(), adjacentPlot:GetY());

			if (not adjacentPlotBelongsToPlayer) and adjacentPlotIsFort then

				local fortPlotOwner = adjacentPlot:GetOwner();

				--print("IsAdjacentToUnownedFortOwnedBy: " .. (i+1) .. " of 6: RETURN Player " .. fortPlotOwner);
				return fortPlotOwner;

			end
		end
	end

	--print("IsAdjacentToUnownedFortOwnedBy: " .. (i+1) .. " of 6: RETURN -1 (false)");
	return -1;

end
--==================================================================================================================================================================

function IsAdjacentToUnownedCityOwnedBy(locX, locY, eOwner)

	--print("In IsAdjacentToUnownedFortOwnedBy(), eOwner = " .. eOwner);

	for i=0,5,1 do
		
		--print("-------- IsAdjacentToUnownedFortOwnedBy() " .. (i+1) .. " of 6 --------");
		local adjacentPlot = Map.GetAdjacentPlot(locX, locY, i);

		local adjacentPlotIsOwned = isPlotOwned(adjacentPlot:GetX(), adjacentPlot:GetY());

		local adjacentPlotBelongsToPlayer = false;
		local adjacentPlotIsCity = false;

		if adjacentPlotIsOwned then
			adjacentPlotBelongsToPlayer = isPlotBelongToPlayer( adjacentPlot:GetX(), adjacentPlot:GetY(), eOwner );
			adjacentPlotIsCity = IsPlotCity( adjacentPlot:GetX(), adjacentPlot:GetY() );

			if (not adjacentPlotBelongsToPlayer) and adjacentPlotIsCity then

				local fortPlotOwner = adjacentPlot:GetOwner();

				--print("IsAdjacentToUnownedFortOwnedBy: " .. (i+1) .. " of 6: RETURN Player " .. fortPlotOwner);
				return fortPlotOwner;

			end
		end
	end

	--print("IsAdjacentToUnownedFortOwnedBy: " .. (i+1) .. " of 6: RETURN -1 (false)");
	return -1;

end
--==================================================================================================================================================================

function GetNearestCityOrCap(locX, locY, owner, excludedCityPlotIndex)

--	print("GetNearestCityOrCap---------------------");
--	print("    GetNearestCity(): eOwner = " .. owner);

	if(owner ~= -1) then

		local maxDistance = 6;		
		local nearestCityDistance = 1000;
		local nearestCity = nil;
		local nearestCityPop = 0;
		local player = Players[owner];
		local playerCities = player:GetCities();

		if playerCities ~= nil then
			for _,city in playerCities:Members() do
				
				local plot = Map.GetPlot(city:GetX(),city:GetY());
				local plotIndex = plot:GetIndex();

				--print("GetNearestCityOrCap(): excludedCityPlotIndex, conqueredCityPlotIndex = " .. excludedCityPlotIndex .. ", " .. plotIndex);
				if excludedCityPlotIndex ~= plotIndex then

					local distance = Map.GetPlotDistance(locX,locY,city:GetX(),city:GetY());
					local cityPop = city:GetPopulation();
					local cityDistricts = city:GetDistricts():GetNumDistricts();

					--if this city is the closest so far  -or-  If if it is same closeness but this one has higher pop
					if (distance < nearestCityDistance) or (distance == nearestCityDistance and cityPop > nearestCityPop) then 
						nearestCityDistance = distance;
						nearestCity = city;
						nearestCityPop = cityPop;
					end

				else
--					print("    GetNearestCity(): Excluding " .. city:GetName());
				end
			end
		end

		if(nearestCityDistance <= maxDistance) then
--			print("    GetNearestCity(): " .. nearestCity:GetName());
			return nearestCity;
		else
--			print("    GetNearestCity(): Return capital due to no cities within 6 tiles - " .. playerCities:GetCapitalCity():GetName());
			return playerCities:GetCapitalCity();
		end
	end
end
--==================================================================================================================================================================

function CheckCityForNonAttachedTiles( cityPlot )

	print("CheckCityForNonAttachedTiles()---------------------");
	local connectedPlots:table = {};
	local checkPlotsAdjacentToThesePlots:table = {};
	local newConnectedPlots:table = {};
	local iterate:boolean = true;

	local cityOwner = cityPlot:GetOwner();	
	
	--add city plot to connectedPlots and checkPlotsAdjacentToThesePlots
	table.insert(connectedPlots, cityPlot);
	table.insert(checkPlotsAdjacentToThesePlots, cityPlot);

	--as long as we are finding new adjacent plots to add to connectedPlots, continue to iterate through the plots	
	while iterate == true do
--		print("    CheckCityForNonAttachedTiles(): WHILE INITIAL: connectedPlots, checkPlotsAdjacentToThesePlots, newConnectedPlots = " .. Tablelength(connectedPlots) .. ", " .. Tablelength(checkPlotsAdjacentToThesePlots) .. ", " .. Tablelength(newConnectedPlots));
		for i, plot in pairs(checkPlotsAdjacentToThesePlots) do --for each checkPlotsAdjacentToThesePlots
		
			for i=0,5,1 do --for each plot adjacent to the currently evaluated connectedPlot
				
				local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), i);
				local adjacentPlotBelongsToPlayer = isPlotBelongToPlayer(adjacentPlot:GetX(), adjacentPlot:GetY(), cityOwner); --**********************
--				print("    CheckCityForNonAttachedTiles(): adjacentPlot:GetIndex(), adjacentPlotBelongsToPlayer, connectedPlots TableLength = " .. adjacentPlot:GetIndex() .. ", " .. tostring(adjacentPlotBelongsToPlayer) .. ", " .. Tablelength(connectedPlots));
				if adjacentPlotBelongsToPlayer then
										
					--Check to make sure this adjacent plot is not already in connectedPlots
					local adjacentPlotAlreadyInConnectedPlots = false;
					for i, connectedPlot in pairs(connectedPlots) do

						if connectedPlot:GetIndex() == adjacentPlot:GetIndex() then
--							print("    CheckCityForNonAttachedTiles(): SKIP PLOT");
							adjacentPlotAlreadyInConnectedPlots = true;
							break
						end
					end
					
					--If this adjacent plot is not in connectedPlots, then add it to the appropriate tables	
					if adjacentPlotAlreadyInConnectedPlots == false then
						table.insert(connectedPlots, adjacentPlot);
						table.insert(newConnectedPlots, adjacentPlot);		
					end
				end
--				print("    CheckCityForNonAttachedTiles(): WHILE FOR: connectedPlots, checkPlotsAdjacentToThesePlots, newConnectedPlots = " .. Tablelength(connectedPlots) .. ", " .. Tablelength(checkPlotsAdjacentToThesePlots) .. ", " .. Tablelength(newConnectedPlots));
			end			
		end

		if Tablelength(newConnectedPlots) == 0 then
			iterate = false;
--			print("    CheckCityForNonAttachedTiles(): Tablelength(newConnectedPlots) == 0. Iterate = false.");
		end

		checkPlotsAdjacentToThesePlots = {}; --clear checkPlotsAdjacentToThesePlots
		
		--Move newConnectedPlots into checkPlotsAdjacentToThesePlots
		for i, plot in pairs(newConnectedPlots) do
			table.insert(checkPlotsAdjacentToThesePlots, plot);
		end

--		print("    CheckCityForNonAttachedTiles(): Inside while loop: connectedPlots table length = " .. Tablelength(connectedPlots));
--		print("    CheckCityForNonAttachedTiles(): Inside while loop: newConnectedPlots table length = " .. Tablelength(newConnectedPlots));
--		print("    CheckCityForNonAttachedTiles(): Inside while loop: checkPlotsAdjacentToThesePlots table length = " .. Tablelength(checkPlotsAdjacentToThesePlots));
		
		newConnectedPlots = {}; --clear newConnectedPlots
--		print("    CheckCityForNonAttachedTiles(): WHILE FINAL: connectedPlots, checkPlotsAdjacentToThesePlots, newConnectedPlots = " .. Tablelength(connectedPlots) .. ", " .. Tablelength(checkPlotsAdjacentToThesePlots) .. ", " .. Tablelength(newConnectedPlots));
	end

--	print("    CheckCityForNonAttachedTiles(): FINAL connectedPlots table length = " .. Tablelength(connectedPlots));
	removeFortPlotsConquered = {}; --this variable is used in OnImprovementAddedToMapTC to track when to call CheckCityForNonAttachedTiles in a city conquered event string

--================================== SECOND PART ===========================================
	local cityOwnedPlots = GetCityPlots(cityPlot, cityOwner);

--	print("    CheckCityForNonAttachedTiles(): PART 2: INITIAL city, connected table lengths = " .. Tablelength(cityOwnedPlots) .. ", " ..Tablelength(connectedPlots));

	--copy cityOwnedPlots into disconnectedCityPlots
	local disconnectedCityPlots:table = {};
	for i, plot in pairs(cityOwnedPlots) do
		table.insert(disconnectedCityPlots, plot);
	end
	
	--find city plots that arent connected. Save them in table disconnectedCityPlots.
	for i, connectedPlot in pairs(connectedPlots) do
		
		for i, cityOwnedPlot in pairs(disconnectedCityPlots) do

			if cityOwnedPlot:GetIndex() == connectedPlot:GetIndex() then				
				table.remove(disconnectedCityPlots, i);
				break
			end
		end
	end

--	print("    CheckCityForNonAttachedTiles(): PART 2: MIDDLE city, connected, disconnected table lengths = " .. Tablelength(cityOwnedPlots) .. ", " ..Tablelength(connectedPlots) .. ", " .. Tablelength(disconnectedCityPlots));
	
	--REMOVE DISCONNECTED PLOTS
	for i, plot in pairs(disconnectedCityPlots) do
--		print("    CheckCityForNonAttachedTiles(): PART 3: Checking plot in disconnectedCityPlots");	
		local nearestCityToPlot = GetNearestCityOrCap(plot:GetX(), plot:GetY(), cityOwner, -1);	
		local plotDistanceToOwnedCity = Map.GetPlotDistance(plot:GetX(), plot:GetY(), nearestCityToPlot:GetX(), nearestCityToPlot:GetY());
--		print("    CheckCityForNonAttachedTiles(): PART 3: IsPlotFort = " .. tostring( IsPlotFort( plot:GetX(), plot:GetY() )));
--		print("    CheckCityForNonAttachedTiles(): PART 3: IsAdjacentToOwnedFort = " .. tostring(IsAdjacentToOwnedFort(plot:GetX(), plot:GetY(), cityOwner)));
--		print("    CheckCityForNonAttachedTiles(): PART 3: IsPlotDistrict = " .. tostring(IsPlotDistrict(plot:GetX(), plot:GetY())));
--		print("    CheckCityForNonAttachedTiles(): PART 3: plotDistanceToOwnedCity = " .. tostring(plotDistanceToOwnedCity));
		if not (IsPlotFort(plot:GetX(), plot:GetY())) and not (IsAdjacentToOwnedFort(plot:GetX(), plot:GetY(), cityOwner)) and not (IsPlotDistrict(plot:GetX(), plot:GetY())) and (plotDistanceToOwnedCity > 1) then
--			print("    CheckCityForNonAttachedTiles(): PART 3: 1");
			if ( IsAdjacentToUnownedCityOwnedBy(plot:GetX(), plot:GetY(), cityOwner) ~= -1 ) then
--				print("    CheckCityForNonAttachedTiles(): PART 3: 2");
				local nearestForeignPlayerCityToFortPlot = GetNearestCityOrCap(plot:GetX(), plot:GetY(), IsAdjacentToUnownedCityOwnedBy(plot:GetX(), plot:GetX(), cityOwner), -1);
				WorldBuilder.CityManager():SetPlotOwner(plot, nearestForeignPlayerCityToFortPlot);

			elseif ( IsAdjacentToUnownedFortOwnedBy(plot:GetX(), plot:GetY(), cityOwner) ~= -1 ) then
				local nearestForeignPlayerCityToFortPlot = GetNearestCityOrCap(plot:GetX(), plot:GetY(), IsAdjacentToUnownedFortOwnedBy(plot:GetX(), plot:GetY(), cityOwner), -1);
--				print("    CheckCityForNonAttachedTiles(): PART 3: 3. nearestForeignPlayerCityToFortPlot = " .. nearestForeignPlayerCityToFortPlot:GetName());
				WorldBuilder.CityManager():SetPlotOwner(plot, nearestForeignPlayerCityToFortPlot);

			else
--				print("    CheckCityForNonAttachedTiles(): PART 3: 4");
--				print("    CheckCityForNonAttachedTiles(): removing plot ownership. PlotX, PlotY = " .. tostring(plot:GetX()) .. ", " .. tostring(plot:GetX()) );
				plot:SetOwner(-1);
				
				--Remove this plot from cityOwnedPlots
				for i, cityOwnedPlot in pairs(cityOwnedPlots) do			
					if plot:GetIndex() == cityOwnedPlot:GetIndex() then				
						table.remove(cityOwnedPlots, i);
						break
					end
				end								
			end	
		end
	end
--	print("    CheckCityForNonAttachedTiles(): PART 2: FINAL city, connected, disconnected table lengths = " .. Tablelength(cityOwnedPlots) .. ", " ..Tablelength(connectedPlots) .. ", " .. Tablelength(disconnectedCityPlots));
end
--==================================================================================================================================================================

function GetCityPlots(cityPlot, cityOwner) --Thank you LeeS
	print("GetCityPlots()---------------------------------");
	local cityPlots = {};
	local range = 15;
	--local iCityOwner = cityPlot:GetOwner();
	local plotX = cityPlot:GetX();
	local plotY = cityPlot:GetY();	
	local city = Cities.GetCityInPlot(plotX, plotY);

	for dx = -range, range - 1, 1 do
		for dy = -range, range - 1, 1 do
--			print("    GetCityPlots():plotX, plotY, dx, dy, range = " .. tostring(plotX) .. ", " .. tostring(plotY) .. ", " .. tostring(dx) .. ", " .. tostring(dy) .. ", " .. tostring(range));
			local pOtherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, range);--			
--			print("    GetCityPlots(): 1");
			if pOtherPlot and (pOtherPlot:GetOwner() == cityOwner) then				
--				print("    GetCityPlots(): 2");

				if ((Cities.GetPlotWorkingCity(pOtherPlot:GetIndex()) ~= nil)) then
--					print("    GetCityPlots(): 1B (Cities.GetPlotWorkingCity(pOtherPlot:GetIndex()) ~= nil)");
--					print("    GetCityPlots(): cityPlot, 2B Cities.GetPlotWorkingCity(pOtherPlot:GetIndex()), 4B Cities.GetPlotPurchaseCity(pOtherPlot:GetIndex())) = " .. tostring(cityPlot) .. ", " .. tostring(Cities.GetPlotWorkingCity(pOtherPlot:GetIndex())) .. ", " .. tostring(Cities.GetPlotPurchaseCity(pOtherPlot:GetIndex())));
				end				
				if ((city == Cities.GetPlotWorkingCity(pOtherPlot:GetIndex()))) then
--					print("    GetCityPlots(): 2B (cityPlot == Cities.GetPlotWorkingCity(pOtherPlot:GetIndex()))");
				end
				if ((Cities.GetPlotWorkingCity(pOtherPlot:GetIndex()) == nil)) then
--					print("    GetCityPlots(): 3B (Cities.GetPlotWorkingCity(pOtherPlot:GetIndex()) == nil)");
				end
				if ((city == Cities.GetPlotPurchaseCity(pOtherPlot:GetIndex()))) then
--					print("    GetCityPlots(): 4B (cityPlot == Cities.GetPlotPurchaseCity(pOtherPlot:GetIndex()))");
				end

				if ((Cities.GetPlotWorkingCity(pOtherPlot:GetIndex()) ~= nil) and (city == Cities.GetPlotWorkingCity(pOtherPlot:GetIndex()))) then
					table.insert(cityPlots, pOtherPlot);
				elseif ((Cities.GetPlotWorkingCity(pOtherPlot:GetIndex()) == nil) and (city == Cities.GetPlotPurchaseCity(pOtherPlot:GetIndex()))) then
					table.insert(cityPlots, pOtherPlot);
				end
			end
		end
	end
--	print("    GetCityPlots():FINAL cityPlots table length = " .. Tablelength(cityPlots));
	return cityPlots;
end
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
	print("No more stack check turn", Game.GetCurrentGameTurn())
	if ( Game.GetCurrentGameTurn() ~= GameConfiguration.GetStartTurn()) then
	for i = 0, PlayerManager.GetAliveMajorsCount() - 1 do
		if (PlayerConfigurations[i]:GetLeaderTypeName() ~= "LEADER_SPECTATOR" and PlayerConfigurations[i]:GetHandicapTypeID() ~= 2021024770) then
			local pPlayerCulture:table = Players[i]:GetCulture();
			if pPlayerCulture:GetProgressingCivic() == -1 and pPlayerCulture:GetCultureYield()>0 then
				print("Player",PlayerConfigurations[i]:GetLeaderTypeName()," forgot to pick a civic")
				for k = 0, 58 do
					if (pPlayerCulture:HasCivic(k) == false) then
						pPlayerCulture:SetProgressingCivic(k)
						break
					end	
				end
			end
			local pPlayerTechs:table = Players[i]:GetTechs();
			if pPlayerTechs:GetResearchingTech() == -1 and pPlayerTechs:GetScienceYield()>0 then
				print("Player",PlayerConfigurations[i]:GetLeaderTypeName()," forgot to pick a tech")
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

function Initialize()
	print("-- Init D. CPL Helper Gameplay Script"..g_version.." --");
	Init_Properties()
	GameEvents.OnGameTurnStarted.Add(OnGameTurnStarted);
	GameEvents.OnGameTurnStarted.Add(NoMoreStack);
	if (GameConfiguration.GetValue("CPL_LASTMOVE_OPT") ~= nil) then
		if (GameConfiguration.GetValue("CPL_LASTMOVE_OPT") == true) then
			print("Last Move Debuff Mechanics is On")
			b_last_move = true
		end
	end
	for i = 0, PlayerManager.GetWasEverAliveMajorsCount() -1 do
		if Players[i]:IsAlive() == true then
			if Players[i]:GetTeam() ~= i then
				b_teamer = true
			end
		end
	end

	if GameConfiguration.GetValue("GAMEMODE_ONECITY") == true then
		OneCity_Init()
		b_onecity = true
		GameEvents.CityConquered.Add(OnCityConquered_OneCity);
		GameEvents.PlayerTurnStarted.Add(OnPlayerTurnActivated_OneCity);
		Events.ImprovementAddedToMap.Add(OnImprovementAddedToMapTC);
		Events.ImprovementRemovedFromMap.Add(OnImprovementRemovedFromMapTC);
		Events.ImprovementChanged.Add(OnImprovementChangedTC);
		GameEvents.CityConquered.Add(OnCityConqueredTC);
		Events.DistrictRemovedFromMap.Add(OnDistrictRemovedTC);
		Events.CityRemovedFromMap.Add(OnCityRemovedTC);
		Events.CityInitialized.Add(OnCityInitializedTC);
		Events.UnitMoveComplete.Add(OnUnitMoveCompleteTC);
		Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDoneTC);
	end
end


Initialize();
