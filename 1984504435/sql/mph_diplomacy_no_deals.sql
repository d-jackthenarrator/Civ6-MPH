------------------------------------------------------------------------------
--	FILE:	 mph_diplomacy_no_deals.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by MPH
------------------------------------------------------------------------------

DELETE from GameCapabilities WHERE GameCapability='CAPABILITY_DIPLOMACY_DEALS';
