------------------------------------------------------------------------------
--	FILE:	 sql/mph_alliance_no_economic.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by MPH
------------------------------------------------------------------------------

DELETE from Types WHERE Type='DIPLOACTION_ALLIANCE_ECONOMIC';
DELETE from Types WHERE Type='ALLIANCE_ECONOMIC';
DELETE from Alliances WHERE AllianceType='ALLIANCE_ECONOMIC';
DELETE from DiplomaticActions WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_ECONOMIC';
DELETE from DiplomaticStateActions WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_ECONOMIC';
DELETE from AiFavoredItems WHERE Item='ALLIANCE_ECONOMIC';
DELETE from DiplomacyStatementTypes WHERE Type='CREATE_ECONOMIC_ALLIANCE'; 
DELETE from DiplomacySelections WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_ECONOMIC'; 
DELETE from AllianceEffects WHERE AllianceType='ALLIANCE_ECONOMIC'; 