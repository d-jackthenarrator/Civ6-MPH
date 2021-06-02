include "SupportFunctions"
include "occ_StateUtils"
print("-- OCC Rules --")
-- ===========================================================================
--	Black Death Scenario - Rules
-- ===========================================================================
RULES = {};

-- Common Variables
RULES.UnitCharges = {}
RULES.UnitCharges[GameInfo.Units["UNIT_EXPANSIONIST"].Hash] = {
	Base = 3,
}


