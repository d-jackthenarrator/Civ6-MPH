-- Copyright 2016-2019, Firaxis Games
-- (Multiplayer) OCC UI By D. / Jack The Narrator
print("MPH OCC Panel")
include("InstanceManager");

-- ===========================================================================
--	Variables
-- ===========================================================================
local ms_ScoutWaveTurn = 5
local ms_WaveSize = 4
local ms_OnlineWaveInterval = 15
local ms_QuickWaveInterval = 25
local ms_StandardWaveInterval = 40
local ms_EpicWaveInterval = 50
local ms_MarathonWaveInterval = 66
local NO_PLAYER = -1;

-- ===========================================================================
--	Events
-- ===========================================================================

function OnPlayerTurnActivated()
	local localPlayer:number = Game.GetLocalPlayer();
	if localPlayer == nil then
		ContextPtr:SetHide(true);
		return
	end
	local b_first_wave = false
	local currentTurn = Game.GetCurrentGameTurn();
	local remainingTurn = 0
	if currentTurn < ms_ScoutWaveTurn then
		remainingTurn = ms_ScoutWaveTurn  - currentTurn
		b_first_wave = true
		else
		if GameConfiguration.GetGameSpeedType() == -1649545904 then
			if currentTurn < ms_OnlineWaveInterval then
				remainingTurn =  ms_OnlineWaveInterval - currentTurn
				else
				remainingTurn = currentTurn % ms_OnlineWaveInterval
				remainingTurn = ms_OnlineWaveInterval - remainingTurn
			end
		end
		if GameConfiguration.GetGameSpeedType() == -1424172973 then
			if currentTurn < ms_QuickWaveInterval then
				remainingTurn =  ms_QuickWaveInterval - currentTurn
				else
				remainingTurn = currentTurn % ms_QuickWaveInterval
				remainingTurn = ms_QuickWaveInterval - remainingTurn
			end
		end
		if GameConfiguration.GetGameSpeedType() == 327976177 then
			if currentTurn < ms_StandardWaveInterval then
				remainingTurn =  ms_StandardWaveInterval - currentTurn
				else
				remainingTurn = currentTurn % ms_StandardWaveInterval
				remainingTurn = ms_StandardWaveInterval - remainingTurn
			end
		end
	
		if GameConfiguration.GetGameSpeedType() == 341116999 then
			if currentTurn < ms_EpicWaveInterval then
				remainingTurn =  ms_EpicWaveInterval - currentTurn
				else
				remainingTurn = currentTurn % ms_EpicWaveInterval
				remainingTurn = ms_EpicWaveInterval - remainingTurn
			end
		end
	
		if GameConfiguration.GetGameSpeedType() == 137894519 then
			if currentTurn < ms_MarathonWaveInterval then
				remainingTurn =  ms_MarathonWaveInterval - currentTurn
				else
				remainingTurn = currentTurn % ms_MarathonWaveInterval
				remainingTurn = ms_MarathonWaveInterval - remainingTurn
			end
		end		
	end
	
	local msg = "in "..tostring(remainingTurn).." "
	if remainingTurn > 1 then
		msg = msg.."Turns"
		else
		msg = msg.."Turn"
	end
	Controls.Turn_Label:SetText(tostring(msg))
	
	if b_first_wave == true then
		Controls.NextWave_Label:SetText(tostring("2x  "))
		Controls.UnitIcon:SetIcon("ICON_UNIT_SCOUT_PORTRAIT")
		else
		local unit, number = GetWaveUnit(localPlayer)
		number = tostring(number)
		number = number.."x"
		Controls.NextWave_Label:SetText(tostring(number.."  "))
		unit = "ICON_"..tostring(unit)
		unit = unit.."_PORTRAIT"
		Controls.UnitIcon:SetIcon(tostring(unit))
	end
	
	if PlayerConfigurations[Game.GetLocalPlayer()]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
		Controls.NextWave_Label:SetText(tostring("-- "))
		Controls.UnitIcon:SetIcon("ICON_UNIT_SETTLER_PORTRAIT")
		Controls.Turn_Label:SetText(tostring("In -- Turns"))
	end
end

-- ===========================================================================
--	Other Functions
-- ===========================================================================

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

function OnDiplomacyHideIngameUI()
	OnHide()
end

function OnDiplomacyShowIngameUI()
	OnShow()
end

function OnFullscreenMapShown()
	OnHide()
end

function OnFullscreenMapClosed()
	OnShow()
end

function OnProjectBuiltShown()
	OnHide()
end

function OnProjectBuiltClosed()
	OnShow()
end

function OnDisasterRevealPopupShown()
	OnHide()
end

function OnDisasterRevealPopupClosed()
	OnShow()
end

function OnNaturalWonderPopupShown()
	OnHide()
end

function  OnNaturalWonderPopupClosed()
	OnShow()
end

function OnRockBandMoviePopupShown()
	OnHide()
end

function OnRockBandMoviePopupClosed()
	OnShow()
end

function OnWonderBuiltPopupShown()
	OnHide()
end

function OnWonderBuiltPopupClosed()
	OnShow()
end

function OnHide()
	ContextPtr:SetHide(true)
end

function OnShow()
	ContextPtr:SetHide(false)
end

function Initialize()
	OnHide()
	local localPlayer:number = Game.GetLocalPlayer();
	if GameConfiguration.GetValue("GAMEMODE_ONECITY") ~= true  then
		return
		else
		OnShow()
		Events.LocalPlayerTurnBegin.Add(OnPlayerTurnActivated);
		Events.ResearchCompleted.Add(OnPlayerTurnActivated);
		Events.ResearchChanged.Add(OnPlayerTurnActivated);
		LuaEvents.DiplomacyActionView_HideIngameUI.Add( OnDiplomacyHideIngameUI );
		LuaEvents.DiplomacyActionView_ShowIngameUI.Add( OnDiplomacyShowIngameUI );
		LuaEvents.FullscreenMap_Shown.Add( OnFullscreenMapShown );
		LuaEvents.FullscreenMap_Closed.Add(	OnFullscreenMapClosed );
		LuaEvents.ProjectBuiltPopup_Shown.Add( OnProjectBuiltShown );
		LuaEvents.ProjectBuiltPopup_Closed.Add( OnProjectBuiltClosed );
		LuaEvents.NaturalDisasterPopup_Shown.Add( OnDisasterRevealPopupShown );
		LuaEvents.NaturalDisasterPopup_Closed.Add( OnDisasterRevealPopupClosed );
		LuaEvents.NaturalWonderPopup_Shown.Add( OnNaturalWonderPopupShown );
		LuaEvents.NaturalWonderPopup_Closed.Add( OnNaturalWonderPopupClosed );
		LuaEvents.RockBandMoviePopup_Shown.Add( OnRockBandMoviePopupShown );
		LuaEvents.RockBandMoviePopup_Closed.Add( OnRockBandMoviePopupClosed );
		LuaEvents.WonderBuiltPopup_Shown.Add( OnWonderBuiltPopupShown );
		LuaEvents.WonderBuiltPopup_Closed.Add(	OnWonderBuiltPopupClosed );
	end

end
Initialize();
