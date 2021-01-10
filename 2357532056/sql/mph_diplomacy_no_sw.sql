------------------------------------------------------------------------------
--	FILE:	 mph_diplomacy_no_sw.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by MPH
------------------------------------------------------------------------------

DELETE from DiplomaticActions 		WHERE DiplomaticActionType='DIPLOACTION_DECLARE_SURPRISE_WAR';
DELETE from DiplomaticStateActions 	WHERE DiplomaticActionType='DIPLOACTION_DECLARE_SURPRISE_WAR';
DELETE from AiFavoredItems 			WHERE Item='DIPLOACTION_DECLARE_SURPRISE_WAR';