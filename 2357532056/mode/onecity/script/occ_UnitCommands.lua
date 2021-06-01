
include "occ_StateUtils"
--[[ =======================================================================

	OCC Custom Unit Commands - Logic

	Receivers for custom unit command events are defined here. They handle
	EXECUTE_SCRIPT commands triggered in the replacement Unit Panel UI script.
-- =========================================================================]]

--	Initial State Data for units that use these commands

-- ===========================================================================
--	CONSTANT
-- ===========================================================================

local ms_WallImprov :number		= GameInfo.Improvements["IMPROVEMENT_GREAT_WALL"].Index;



-- ===========================================================================
--	BUILDWALL
-- ===========================================================================

function ScenarioCommand_BUILDWALL(eOwner : number, iUnitID : number)
	local pPlayer = Players[eOwner];
	if (pPlayer == nil) then
		return;
	end

	local pUnit = pPlayer:GetUnits():FindID(iUnitID);
	if (pUnit == nil) then
		return;
	end
	
	local pPlot : object = Map.GetPlot(pUnit:GetX(), pUnit:GetY());
	if (pPlot == nil) then
		return;
	end

	local sLog = "Executing BUILDWALL Command for " .. pUnit:GetName();
	print(sLog);

	-- Put Improvements
	ImprovementBuilder.SetImprovementType(pPlot, ms_WallImprov, eOwner);
	pPlot:SetOwner(eOwner)
	-- Give Territory
	
	for i=0,5,1 do --Look at each adjacent plot
		
		local adjacentPlot = Map.GetAdjacentPlot(pPlot:GetX(),pPlot:GetY(), i);

		if (adjacentPlot ~= nil) and (not adjacentPlot:IsOwned()) then
			adjacentPlot:SetOwner(eOwner)
		end
	end

	-- Flyover text
	--local message:string  = Locale.Lookup("TEST");
	--Game.AddWorldViewText(0, message, pUnit:GetX(), pUnit:GetY());

	-- Report to the application side that we did something.  This helps with visualization
	UnitManager.ReportActivation(pUnit, "BUILDWALL");



	-- Refresh or init Charges property
	local iNumChargesUsed : number = GetObjectState(pUnit, g_PropertyKeys.Charges);
	if (iNumChargesUsed == nil) then
		iNumChargesUsed = 1;		
	else
		iNumChargesUsed = iNumChargesUsed + 1;
	end

	-- If the unit has used all its charges, remove it
	local iMaxCharges : number = GetObjectState(pUnit, g_PropertyKeys.MaxCharges) or 1;
	if (iNumChargesUsed >= iMaxCharges) then
		SetObjectState(pUnit, g_PropertyKeys.Charges, nil);
		UnitManager.Kill(pUnit);
		return;
	end

	-- Otherwise, update charges and consume its turn
	SetObjectState(pUnit, g_PropertyKeys.Charges, iNumChargesUsed);
	UnitManager.FinishMoves(pUnit);
end
GameEvents.ScenarioCommand_BUILDWALL.Add(ScenarioCommand_BUILDWALL)

