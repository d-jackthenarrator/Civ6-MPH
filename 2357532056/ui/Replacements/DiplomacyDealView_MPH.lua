-- ===========================================================================
-- Diplomacy Trade View Manager
-- ===========================================================================

-- ===========================================================================
-- INCLUDES
-- ===========================================================================
local isXP2 = false;
local isTradingAllowed = true;
local isGoldTradingAllowed = true;
local isFavorTradingAllowed = true;
local isStrategicsTradingAllowed = true;
local isLuxuriesTradingAllowed = true;
local isCitiesTradingAllowed = true;
local isCaptivesTradingAllowed = true;
local isGreatWorksTradingAllowed = true;
local isAgreementsTradingAllowed = true;

if GameConfiguration.GetValue("DIPLOMATIC_DEAL") == true then
	isTradingAllowed = false
	print("MPH - No Trading")
end

if GameConfiguration.GetValue("NO_TRADING_FAVOR") == true then
	isFavorTradingAllowed = false
	print("MPH - No Trading Favor")
end

if GameConfiguration.GetValue("NO_TRADING_GOLD") == true then
	isGoldTradingAllowed = false
	print("MPH - No Trading Gold")
end

if GameConfiguration.GetValue("NO_TRADING_STRATEGICS") == true then
	isStrategicsTradingAllowed = false
	print("MPH - No Trading Strategic")
end

if GameConfiguration.GetValue("NO_TRADING_LUXURIES") == true then
	isLuxuriesTradingAllowed = false
	print("MPH - No Trading Luxuries")
end

if GameConfiguration.GetValue("NO_TRADING_CITIES") == true then
	isCitiesTradingAllowed = false
	print("MPH - No Trading Cities")
end

if GameConfiguration.GetValue("NO_TRADING_CAPTIVES") == true then
	isCaptivesTradingAllowed = false
	print("MPH - No Trading Captibve")
end

if GameConfiguration.GetValue("NO_TRADING_GREATWORKS") == true then
	isGreatWorksTradingAllowed = false
	print("MPH - No Trading Great Works")
end

if GameConfiguration.GetValue("NO_TRADING_AGREEMENTS") == true then
	isAgreementsTradingAllowed = false
	print("MPH - No Trading Agreements")
end

if Modding.IsModActive("4873eb62-8ccc-4574-b784-dda455e74e68") == true then
	--include("DiplomacyDealView_Expansion2.lua");
	isXP2 = true;
end

--include("DiplomacyDealView_Expansion2.lua")
print("MPH DiplomacyDealView")
-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================


BASE_PopulateAvailableGold = PopulateAvailableGold;
BASE_PopulateAvailableResources = PopulateAvailableResources;
BASE_PopulateAvailableLuxuryResources =  PopulateAvailableLuxuryResources;
BASE_PopulateAvailableStrategicResources = PopulateAvailableStrategicResources;
BASE_PopulateAvailableCaptives = PopulateAvailableCaptives;
BASE_PopulateAvailableGreatWorks = PopulateAvailableGreatWorks;
BASE_PopulateAvailableCities = PopulateAvailableCities;
BASE_PopulateAvailableAgreements = PopulateAvailableAgreements;

if isXP2 == true then
	BASE_PopulateAvailableFavor = PopulateAvailableFavor;
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================

function PopulateAvailableFavor(player: table, iconList: table)
	if isTradingAllowed == false or isFavorTradingAllowed == false then
		return 0;
	end
	
	return BASE_PopulateAvailableFavor(player,iconList);
	
end

function PopulateAvailableGold(player : table, iconList : table)

	if isTradingAllowed == false or isGoldTradingAllowed == false then
		return 0;
	end
	
	return BASE_PopulateAvailableGold(player,iconList);
	
end

function PopulateAvailableResources(player : table, iconList : table, className : string)
	if isTradingAllowed == false then
		return 0;
	end
	
	return BASE_PopulateAvailableResources(player , iconList, className)
end

function PopulateAvailableStrategicResources(player : table, iconList : table)

	if isTradingAllowed == false or isStrategicsTradingAllowed == false then
		return 0;
	end
	
	return BASE_PopulateAvailableStrategicResources(player,iconList);
	
end

function PopulateAvailableLuxuryResources(player : table, iconList : table)

	if isTradingAllowed == false or isLuxuriesTradingAllowed == false then
		return 0;
	end
	
	return BASE_PopulateAvailableLuxuryResources(player,iconList);
	
end

function PopulateAvailableAgreements(player : table, iconList : table)

	if isTradingAllowed == false or isAgreementsTradingAllowed == false then
		return 0;
	end
	
	return BASE_PopulateAvailableAgreements(player,iconList);
	
end

function PopulateAvailableCities(player : table, iconList : table)

	if isTradingAllowed == false or isCitiesTradingAllowed == false then
		return 0;
	end
	
	return BASE_PopulateAvailableCities(player,iconList);
	
end

function PopulateAvailableGreatWorks(player : table, iconList : table)

	if isTradingAllowed == false or isGreatWorksTradingAllowed == false then
		return 0;
	end
	
	return BASE_PopulateAvailableGreatWorks(player,iconList);
	
end

function PopulateAvailableCaptives(player : table, iconList : table)

	if isTradingAllowed == false or isCaptivesTradingAllowed == false then
		return 0;
	end
	
	return BASE_PopulateAvailableCaptives(player,iconList);
	
end




