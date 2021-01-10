------------------------------------------------------------------------------
--	FILE:	 sql/mph_alliance_no_cultural.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by MPH
------------------------------------------------------------------------------

DELETE from Types WHERE Type='DIPLOACTION_ALLIANCE_CULTURAL';
DELETE from Types WHERE Type='ALLIANCE_CULTURAL';
DELETE from Alliances WHERE AllianceType='ALLIANCE_CULTURAL';
DELETE from DiplomaticActions WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_CULTURAL';
DELETE from DiplomaticStateActions WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_CULTURAL';
DELETE from AiFavoredItems WHERE Item='ALLIANCE_CULTURAL';
DELETE from DiplomacyStatementTypes WHERE Type='CREATE_CULTURAL_ALLIANCE'; 
DELETE from DiplomacySelections WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_CULTURAL'; 
DELETE from AllianceEffects WHERE AllianceType='ALLIANCE_CULTURAL'; 