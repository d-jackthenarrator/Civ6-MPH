------------------------------------------------------------------------------
--	FILE:	 sql/mph_alliance_no_religious.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by MPH
------------------------------------------------------------------------------

DELETE from Types WHERE Type='DIPLOACTION_ALLIANCE_RELIGIOUS';
DELETE from Types WHERE Type='ALLIANCE_RELIGIOUS';
DELETE from Alliances WHERE AllianceType='ALLIANCE_RELIGIOUS';
DELETE from DiplomaticActions WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_RELIGIOUS';
DELETE from DiplomaticStateActions WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_RELIGIOUS';
DELETE from AiFavoredItems WHERE Item='ALLIANCE_RELIGIOUS';
DELETE from DiplomacyStatementTypes WHERE Type='CREATE_RELIGIOUS_ALLIANCE'; 
DELETE from DiplomacySelections WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_RELIGIOUS'; 
DELETE from AllianceEffects WHERE AllianceType='ALLIANCE_RELIGIOUS';  