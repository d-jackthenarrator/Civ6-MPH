include "occ_StateUtils"

--[[ =======================================================================

	OCC Custom Unit Commands - Definitions

		Data and callbacks for enabling custom unit commands to appear and 
		work in the Unit Panel UI. These definitions mimic what appears in 
		data for common unit commands, and are used in the replacement 
		UnitPanel script.

-- =========================================================================]]

m_ScenarioUnitCommands = {};
local ms_WallImprov :number		= GameInfo.Improvements["IMPROVEMENT_GREAT_WALL"].Index;
--[[ =======================================================================
	BUILDWALL

	Create the Wall 
-- =========================================================================]]
m_ScenarioUnitCommands.BUILDWALL = {};

-- Study Command State Properties
m_ScenarioUnitCommands.BUILDWALL.Properties = {};

-- Study Command UI Data
m_ScenarioUnitCommands.BUILDWALL.EventName		= "ScenarioCommand_BUILDWALL";
m_ScenarioUnitCommands.BUILDWALL.CategoryInUI	= "SPECIFIC";
m_ScenarioUnitCommands.BUILDWALL.Icon			= "ICON_UNITOPERATION_BUILD_IMPROVEMENT";
m_ScenarioUnitCommands.BUILDWALL.ToolTipString	= Locale.Lookup("LOC_UNITCOMMAND_BUILDWALL_NAME") .. "[NEWLINE][NEWLINE]" .. 
												Locale.Lookup("LOC_UNITCOMMAND_BUILDWALL_DESCRIPTION");
m_ScenarioUnitCommands.BUILDWALL.DisabledToolTipString = Locale.Lookup("LOC_UNITCOMMAND_BUILDWALL_DISABLED_TT");
m_ScenarioUnitCommands.BUILDWALL.VisibleInUI	= true;

-- ===========================================================================
function m_ScenarioUnitCommands.BUILDWALL.CanUse(pUnit : object)
	if (pUnit == nil) then
		return false;
	end

	return GameInfo.Units[pUnit:GetType()].UnitType == "UNIT_EXPANSIONIST";
end

-- ===========================================================================
function m_ScenarioUnitCommands.BUILDWALL.IsVisible(pUnit : object)
	return pUnit ~= nil and pUnit:GetMovesRemaining() > 0;
end

-- ===========================================================================
function m_ScenarioUnitCommands.BUILDWALL.IsDisabled(pUnit : object)
	if (pUnit == nil or pUnit:GetMovesRemaining() == 0) then
		return true;
	end
	local eUnitOwner = pUnit:GetOwner()


	local iPlotId : number = pUnit:GetPlotId();
	local pPlot : object = Map.GetPlotByIndex(iPlotId);
	if (pPlot == nil) then
		return true;
	end
	local ePlotOwner = pPlot:GetOwner()
	
	-- Not in a city
	local pCity : object = CityManager.GetCityAt(pPlot:GetX(), pPlot:GetY());
	if (pCity ~= nil) then
		return true;
	end
	
	-- Not Already a Wall
	if pPlot:GetImprovementType() == ms_WallImprov then
		return true;
	end
	
	-- Not on a district
	if (pPlot:GetDistrictType() > -1) then
		return true;
	end

	-- Not on water
	if (pPlot:IsWater() == true) then
		return true;
	end
	
	-- Not in foreign territory
	if (ePlotOwner ~= eUnitOwner) and (ePlotOwner ~= -1) then
		return true;
	end

	return false;
end
