------------------------------------------------------------------------------
--	FILE:	 sql/mph_alliance_no_military.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by MPH
------------------------------------------------------------------------------

DELETE from Types WHERE Type='DIPLOACTION_ALLIANCE_MILITARY';
DELETE from Types WHERE Type='ALLIANCE_MILITARY';
DELETE from Alliances WHERE AllianceType='ALLIANCE_MILITARY';
DELETE from DiplomaticActions WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_MILITARY';
DELETE from DiplomaticStateActions WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_MILITARY';
DELETE from AiFavoredItems WHERE Item='ALLIANCE_MILITARY';
DELETE from DiplomacyStatementTypes WHERE Type='CREATE_MILITARY_ALLIANCE'; 
DELETE from DiplomacySelections WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_MILITARY'; 
DELETE from AllianceEffects WHERE AllianceType='ALLIANCE_MILITARY'; 