------------------------------------------------------------------------------
--	FILE:	 mph_diplomacy_no_fs.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by MPH
------------------------------------------------------------------------------

DELETE from DiplomaticActions 		WHERE DiplomaticActionType='DIPLOACTION_DECLARE_FRIENDSHIP';
DELETE from DiplomaticStateActions 	WHERE DiplomaticActionType='DIPLOACTION_DECLARE_FRIENDSHIP';
DELETE from AiFavoredItems 			WHERE Item='DIPLOACTION_DECLARE_FRIENDSHIP';