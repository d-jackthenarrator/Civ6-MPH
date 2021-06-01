-- ===========================================================================
--	Unit Panel Replacement/Extension
--	OCC
-- ===========================================================================

print("OCC Replacement for Unit Panel")
-- ===========================================================================
-- INCLUDE XP2 FILE
-- ===========================================================================
include "UnitPanel_Expansion2"
include "occ_UnitCommandDefs"
include "occ_StateUtils"

-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- ===========================================================================
XP2_GetUnitActionsTable = GetUnitActionsTable;

-- ===========================================================================
--	OVERRIDE BASE FUNCTIONS
-- ===========================================================================

function GetUnitActionsTable(pUnit : object)
	local pBaseActionsTable : table = XP2_GetUnitActionsTable(pUnit);

	-- Scenario Unit Commands
	--	Test all custom commands in table defined in "OCC_UnitCommands" to add
	--	to the selected unit's table.
	for sCommandKey, pCommandTable in pairs(m_ScenarioUnitCommands) do
		
		--if UnitManager.CanStartCommand(pUnit, UnitCommandTypes.EXECUTE_SCRIPT) then
			local bVisible : boolean = true;
			if (pCommandTable.IsVisible ~= nil) then
				bVisible = pCommandTable.IsVisible(pUnit);
			end
			if (bVisible) then

				if (pCommandTable.CanUse ~= nil and pCommandTable.CanUse(pUnit) == true) then

					local bIsDisabled : boolean = false;
					if (pCommandTable.IsDisabled ~= nil) then
						bIsDisabled = pCommandTable.IsDisabled(pUnit);
					end
			
					local sToolTipString : string = pCommandTable.ToolTipString or "Undefined Unit Command";

					local pCallback : ifunction = function()
						local pSelectedUnit = UI.GetHeadSelectedUnit();
						if (pSelectedUnit == nil) then
							return;
						end

						local tParameters = {};
						tParameters[UnitCommandTypes.PARAM_NAME] = pCommandTable.EventName or "";
						UnitManager.RequestCommand(pSelectedUnit, UnitCommandTypes.EXECUTE_SCRIPT, tParameters);
					end

					if (bIsDisabled and pCommandTable.DisabledToolTipString ~= nil) then
						sToolTipString = sToolTipString .. "[NEWLINE][NEWLINE]" .. pCommandTable.DisabledToolTipString;
					end

					AddActionToTable(pBaseActionsTable, pCommandTable, bIsDisabled, sToolTipString, UnitCommandTypes.EXECUTE_SCRIPT, pCallback);
				end
			end
		end
	--end

	return pBaseActionsTable;
end


