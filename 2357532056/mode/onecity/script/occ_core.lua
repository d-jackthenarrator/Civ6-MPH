------------------------------------------------------------------------------
--	FILE:	 occ_core.lua
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Gameplay script - Lua Handling
-------------------------------------------------------------------------------
include "occ_StateUtils"
include "occ_UnitCommands"
-- ===========================================================================
--	NEW VARIABLES
-- ===========================================================================
local b_onecity = false
local ms_WallImprov :number		= GameInfo.Improvements["IMPROVEMENT_GREAT_WALL"].Index;
local ms_ScoutWaveTurn = 5
local ms_WaveSize = 4
local ms_OnlineWaveInterval = 15
local ms_QuickWaveInterval = 25
local ms_StandardWaveInterval = 40
local ms_EpicWaveInterval = 50
local ms_MarathonWaveInterval = 66
local NO_PLAYER = -1;

-- ===========================================================================
--	GLOBAL FLAGS
-- ===========================================================================


-- =========================================================================== 
--	NEW EVENTS
-- =========================================================================== 

function OnImprovementPillaged(iPlotIndex :number, eImprovement :number)
	if(iPlotIndex == NO_PLOT) then
		print("ERROR: no plot");
		return;
	end
	
	if(eImprovement == ms_WallImprov) then
		local improvPlot :object = Map.GetPlotByIndex(iPlotIndex);
		if(improvPlot == nil) then
			print("ERROR: improvPlot missing");
			return;
		end
		
		if(improvPlot:GetImprovementOwner() ~= NO_PLAYER) then
			local pOwner :object = Players[improvPlot:GetImprovementOwner()];
			if(pOwner ~= nil) then
				local pCapitalCity = pOwner:GetCities():GetCapitalCity()
				if pCapitalCity ~= nil then
					local distance = Map.GetPlotDistance(pCapitalCity:GetIndex(),improvPlot:GetIndex())
					if distance > 4 then
						improvPlot:SetOwner(NO_PLAYER)
						for i=0,5,1 do --Look at each adjacent plot
							local adjacentPlot = Map.GetAdjacentPlot(improvPlot:GetX(),improvPlot:GetY(), i);

							if (adjacentPlot ~= nil) and (adjacentPlot:IsOwned()) and (adjacentPlot:GetOwner() == improvPlot:GetImprovementOwner()) then
								local distance_adj = Map.GetPlotDistance(adjacentPlot:GetIndex(),adjacentPlot:GetIndex())
								if distance_adj > 4 then
									adjacentPlot:SetOwner(NO_PLAYER)
								end
							end
						end
					end
					ImprovementBuilder.SetImprovementType(improvPlot, -1, NO_PLAYER); 
				end
			end
		end
	end
end

function OnGameTurnStarted_OneCity(turn)
	-- Cannot ever have more than one city
	local pAllPlayerIDs : table = PlayerManager.GetAliveIDs();	
	for _,iPlayerID in ipairs(pAllPlayerIDs) do
	
		local pPlayer : object = Players[iPlayerID];
		local pPlayerCities : object = pPlayer:GetCities();
		for i, pCity in pPlayerCities:Members() do
			if pCity ~= nil then
				if pCity:GetOriginalOwner() ~= pCity:GetOwner() then
					CityManager.DestroyCity(pCity)
				end
			end
		end
	end
	
	-- Waves trigger
	local b_wave = false
	-- Speed = Hash / Max Turn
	-- Marathon = 137894519 / 1500
	-- Epic = 341116999 / 750
	-- Standard = 327976177 / 500
	-- Quick = -1424172973 / 330
	-- Online = -1649545904 / 250 
	
	if GameConfiguration.GetGameSpeedType() == -1649545904 then
		if turn % ms_OnlineWaveInterval == 0 then
			b_wave = true
		end
	end
	
	if GameConfiguration.GetGameSpeedType() == -1424172973 then
		if turn % ms_QuickWaveInterval == 0 then
			b_wave = true
		end
	end
	
	if GameConfiguration.GetGameSpeedType() == 327976177 then
		if turn % ms_StandardWaveInterval == 0 then
			b_wave = true
		end
	end
	
	if GameConfiguration.GetGameSpeedType() == 341116999 then
		if turn % ms_EpicWaveInterval == 0 then
			b_wave = true
		end
	end
	
	if GameConfiguration.GetGameSpeedType() == 137894519 then
		if turn % ms_MarathonWaveInterval == 0 then
			b_wave = true
		end
	end
	
	if b_wave == true or turn == ms_ScoutWaveTurn then
		OnWaveTriggered(turn)
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

-- =========================================================================== 
--	One City Challenge
-- =========================================================================== 


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

function OnWaveTriggered(turn)
		
	local pAllPlayerIDs : table = PlayerManager.GetAliveIDs();	
	for _,iPlayerID in ipairs(pAllPlayerIDs) do
	
		local pPlayer : object = Players[iPlayerID];
		local pPlayerCities : object = pPlayer:GetCities();
		local playerUnits = pPlayer:GetUnits()
		if pPlayer:IsMajor() == true and pPlayerCities ~= nil then
		
			local unitType = "UNIT_SCOUT"
			local unitNumber = ms_WaveSize
			if turn == ms_ScoutWaveTurn then
				unitType = "UNIT_SCOUT"
				unitNumber = 2
				else -- Normal Wave
				unitType, unitNumber = GetWaveUnit(iPlayerID)
			end
	
			local unitIndex = GameInfo.Units[unitType].Index
	
			if unitIndex == nil then
				print("Invalid Unit",unitType)
				return
			end
		
				
			local capitalCity = pPlayerCities:GetCapitalCity();
			if capitalCity ~= nil then
				for i = 1, unitNumber, 1 do
					playerUnits:Create(unitIndex, capitalCity:GetX(), capitalCity:GetY())	
				end	
			end
		end
	end
end

function GetWaveUnit(iPlayerID)
	local unitType = "UNIT_SCOUT"
	local unitNumber = ms_WaveSize
	
	local pPlayer : object = Players[iPlayerID];
	
	if pPlayer == nil then
		print("GetWaveUnit",iPlayerID,"Invalid Player")
		return unitType, unitNumber
	end
	
	local era = pPlayer:GetEra()
	local leader = PlayerConfigurations[iPlayerID]:GetLeaderTypeName()
	

-- 40 Aluminium
-- 41 Coal
-- 42 Horse 
-- 43 Iron if pPlayer:GetResources():HasResource(43) == true then
-- 44 Niter
-- 45 Oil
-- 46 Uranium
	local playerTechs	:table	= pPlayer:GetTechs();
	
	
	
	-- Information --

		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_ROBOTICS"].Index) and pPlayer:GetResources():HasResource(46)  then
			unitNumber = 1
			return "UNIT_GIANT_DEATH_ROBOT", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_COMPOSITES"].Index) and pPlayer:GetResources():HasResource(45)  then
			return "UNIT_MODERN_ARMOR", unitNumber
		end

	-- Atomic --

		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_SYNTHETIC_MATERIALS"].Index) and pPlayer:GetResources():HasResource(40)  then
			return "UNIT_HELICOPTER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_PLASTICS"].Index) then
			return "UNIT_SPEC_OPS", unitNumber
		end

	-- Modern --

		-- UU --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_REPLACEABLE_PARTS"].Index) and leader == "LEADER_JOHN_CURTIN" then
			unitNumber = unitNumber + 1
			return "UNIT_DIGGER", unitNumber
		end
		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_COMBUSTION"].Index) and pPlayer:GetResources():HasResource(45)  then
			return "UNIT_TANK", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_STEEL"].Index) and pPlayer:GetResources():HasResource(45)  then
			return "UNIT_ARTILLERY", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_REPLACEABLE_PARTS"].Index) then
			return "UNIT_INFANTRY", unitNumber
		end

	
	-- Industrial --

		-- UU --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_BALLISTICS"].Index) and pPlayer:GetResources():HasResource(43) and (leader == "LEADER_T_ROOSEVELT" or leader == "LEADER_T_ROOSEVELT_ROUGHRIDER") then
			unitNumber = unitNumber + 1
			return "UNIT_AMERICAN_ROUGH_RIDER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_BALLISTICS"].Index) and pPlayer:GetResources():HasResource(43) and (leader == "LEADER_JADWIGA") then
			unitNumber = unitNumber + 1
			return "UNIT_POLISH_HUSSAR", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_SCIENCE"].Index) and pPlayer:GetResources():HasResource(44) and (leader == "LEADER_VICTORIA" or leader == "LEADER_ELEANOR_ENGLAND") then
			unitNumber = unitNumber + 2
			return "UNIT_ENGLISH_REDCOAT", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_SCIENCE"].Index) and pPlayer:GetResources():HasResource(44) and (leader == "LEADER_CATHERINE_DE_MEDICI" or leader == "LEADER_CATHERINE_DE_MEDICI_ALT" or leader == "LEADER_ELEANOR_FRANCE") then
			unitNumber = unitNumber + 2
			return "UNIT_FRENCH_GARDE_IMPERIALE", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_BALLISTICS"].Index) and leader == "LEADER_SEONDEOK" then
			unitNumber = unitNumber + 1
			return "UNIT_KOREAN_HWACHA", unitNumber
		end
		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_BALLISTICS"].Index) and pPlayer:GetResources():HasResource(43)  then
			return "UNIT_CUIRASSIER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_SCIENCE"].Index) and pPlayer:GetResources():HasResource(44)  then
			return "UNIT_LINE_INFANTRY", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_BALLISTICS"].Index) then
			return "UNIT_FIELD_CANNON", unitNumber
		end

	
	-- Renaissance --

		-- UU --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_METAL_CASTING"].Index) and leader == "LEADER_KRISTINA"  then
			unitNumber = unitNumber + 1
			return "UNIT_SWEDEN_CAROLEAN", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_GUNPOWDER"].Index) and pPlayer:GetResources():HasResource(44) and leader == "LEADER_PHILIP_II"  then
			unitNumber = unitNumber + 2
			return "UNIT_SPANISH_CONQUISTADOR", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_GUNPOWDER"].Index) and pPlayer:GetResources():HasResource(44) and leader == "LEADER_SULEIMAN"  then
			unitNumber = unitNumber + 2
			return "UNIT_SULEIMAN_JANISSARY", unitNumber
		end
		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_METAL_CASTING"].Index) and pPlayer:GetResources():HasResource(44)  then
			return "UNIT_BOMBARD", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_METAL_CASTING"].Index) then
			return "UNIT_PIKE_AND_SHOT", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_GUNPOWDER"].Index) and pPlayer:GetResources():HasResource(44)  then
			return "UNIT_MUSKETMAN", unitNumber
		end

	
	
	-- Medieval --

		-- UU --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MACHINERY"].Index) and leader == "LEADER_PACHACUTI" then
			unitNumber = unitNumber + 3
			return "UNIT_INCA_WARAKAQ", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MACHINERY"].Index) and leader == "LEADER_LADY_TRIEU" then
			unitNumber = unitNumber
			return "UNIT_VIETNAMESE_VOI_CHIEN", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_STIRRUPS"].Index) and leader == "LEADER_SALADIN" and pPlayer:GetResources():HasResource(43) then
			unitNumber = unitNumber + 1
			return "UNIT_ARABIAN_MAMLUK", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_STIRRUPS"].Index) and leader == "LEADER_MANSA_MUSA" and pPlayer:GetResources():HasResource(43) then
			unitNumber = unitNumber + 1
			return "UNIT_MALI_MANDEKALU_CAVALRY", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_APPRENTICESHIP"].Index) and pPlayer:GetResources():HasResource(43) and leader == "LEADER_HOJO" then
			unitNumber = unitNumber + 2
			return "UNIT_JAPANESE_SAMURAI", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_APPRENTICESHIP"].Index) and pPlayer:GetResources():HasResource(43) and leader == "LEADER_HARDRADA" then
			unitNumber = unitNumber + 2
			return "UNIT_NORWEGIAN_BERSERKER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_CASTLES"].Index) and pPlayer:GetResources():HasResource(42) and leader == "LEADER_MATTHIAS_CORVINUS" then
			unitNumber = unitNumber + 1
			return "UNIT_HUNGARY_BLACK_ARMY", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_CASTLES"].Index) and pPlayer:GetResources():HasResource(42) and leader == "LEADER_MENELIK" then
			unitNumber = unitNumber + 1
			return "UNIT_ETHIOPIAN_OROMO_CAVALRY", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_TACTICS"].Index) and leader == "LEADER_SHAKA" then
			unitNumber = unitNumber + 2
			return "UNIT_ZULU_IMPI", unitNumber
		end
		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_STIRRUPS"].Index) and pPlayer:GetResources():HasResource(42) and pPlayer:GetResources():HasResource(43) then
			return "UNIT_KNIGHT", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_APPRENTICESHIP"].Index) and pPlayer:GetResources():HasResource(43) then
			return "UNIT_MAN_AT_ARMS", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_CASTLES"].Index) and pPlayer:GetResources():HasResource(42)then
			return "UNIT_COURSER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_MILITARY_TACTICS"].Index) then
			return "UNIT_PIKEMAN", unitNumber
		end

	-- Classical --

		-- UU --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_IRON_WORKING"].Index) and pPlayer:GetResources():HasResource(43) and leader == "LEADER_TRAJAN" then
			unitNumber = unitNumber + 2
			return "UNIT_ROMAN_LEGION", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_IRON_WORKING"].Index) and pPlayer:GetResources():HasResource(43) and leader == "LEADER_MVEMBA" then
			unitNumber = unitNumber + 1
			return "UNIT_KONGO_SHIELD_BEARER", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_HORSEBACK_RIDING"].Index) and pPlayer:GetResources():HasResource(42) and leader == "LEADER_ALEXANDER" then
			unitNumber = unitNumber + 1
			return "UNIT_MACEDONIAN_HETAIROI", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_IRON_WORKING"].Index) and pPlayer:GetResources():HasResource(43) and leader == "LEADER_ALEXANDER" then
			unitNumber = unitNumber + 1
			return "UNIT_MACEDONIAN_HYPASPIST", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_IRON_WORKING"].Index) and pPlayer:GetResources():HasResource(43) and leader == "LEADER_CYRUS" then
			unitNumber = unitNumber + 1
			return "UNIT_PERSIAN_IMMORTAL", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_IRON_WORKING"].Index) and pPlayer:GetResources():HasResource(43) and leader == "LEADER_KUPE" then
			unitNumber = unitNumber + 1
			return "UNIT_MAORI_TOA", unitNumber
		end
		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_HORSEBACK_RIDING"].Index) and pPlayer:GetResources():HasResource(42) then
			return "UNIT_HORSEMAN", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_IRON_WORKING"].Index) and pPlayer:GetResources():HasResource(43) then
			return "UNIT_SWORDMAN", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_ENGINEERING"].Index) then
			unitNumber = unitNumber + 1
			return "UNIT_CATAPULT", unitNumber
		end

	-- Ancient --

		-- UU --
		if leader == "LEADER_POUNDMAKER" then
			unitNumber = unitNumber + 1
			return "UNIT_CREE_OKIHTCITAW", unitNumber
		end
		if leader == "LEADER_GILGAMESH" then
			unitNumber = unitNumber + 1
			return "UNIT_SUMERIAN_WAR_CART", unitNumber
		end
		if leader == "LEADER_MONTEZUMA" then
			unitNumber = unitNumber + 2
			return "UNIT_AZTEC_EAGLE_WARRIOR", unitNumber
		end
		if leader == "LEADER_AMBIORIX" then
			unitNumber = unitNumber + 2
			return "UNIT_GAUL_GAESATAE", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_THE_WHEEL"].Index) and leader == "LEADER_CLEOPATRA" then
			unitNumber = unitNumber + 1
			return "UNIT_EGYPTIAN_CHARIOT_ARCHER", unitNumber
		end			
		if playerTechs:HasTech(GameInfo.Technologies["TECH_BRONZE_WORKING"].Index) and (leader == "LEADER_GORGO" or leader == "LEADER_PERICLES") then
			unitNumber = unitNumber + 2
			return "UNIT_HOPLITE", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_ARCHERY"].Index) and leader == "LEADER_LADY_SIX_SKY" then
			unitNumber = unitNumber + 1
			return "UNIT_MAYAN_HULCHE", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_ARCHERY"].Index) and leader == "LEADER_AMANITORE" then
			unitNumber = unitNumber + 1
			return "UNIT_NUBIAN_PITATI", unitNumber
		end
		-- NORMAL --
		if playerTechs:HasTech(GameInfo.Technologies["TECH_THE_WHEEL"].Index) then
			return "UNIT_HEAVY_CHARRIOT", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_BRONZE_WORKING"].Index) then
			return "UNIT_SPEARMAN", unitNumber
		end
		if playerTechs:HasTech(GameInfo.Technologies["TECH_ARCHERY"].Index) then
			return "UNIT_ARCHER", unitNumber
		end
		return "UNIT_WARRIOR", unitNumber


end


-------------------------------------------------------

function Initialize()
	print("-- OCC ON --");
	
	if GameConfiguration.GetValue("GAMEMODE_ONECITY") == true then
		OneCity_Init()
		b_onecity = true
		GameEvents.PlayerTurnStarted.Add(OnPlayerTurnActivated_OneCity);
		GameEvents.OnGameTurnStarted.Add(OnGameTurnStarted_OneCity);
		GameEvents.OnImprovementPillaged.Add(OnImprovementPillaged);
	end
end


Initialize();
