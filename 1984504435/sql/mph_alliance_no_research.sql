------------------------------------------------------------------------------
--	FILE:	 sql/mph_alliance_no_research.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by MPH
------------------------------------------------------------------------------

DELETE from Types WHERE Type='DIPLOACTION_ALLIANCE_RESEARCH';
DELETE from Types WHERE Type='ALLIANCE_RESEARCH';
DELETE from Alliances WHERE AllianceType='ALLIANCE_RESEARCH';
DELETE from DiplomaticActions WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_RESEARCH';
DELETE from DiplomaticStateActions WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_RESEARCH';
DELETE from AiFavoredItems WHERE Item='ALLIANCE_RESEARCH';
DELETE from DiplomacyStatementTypes WHERE Type='CREATE_RESEARCH_ALLIANCE'; 
DELETE from DiplomacySelections WHERE DiplomaticActionType='DIPLOACTION_ALLIANCE_RESEARCH'; 
DELETE from AllianceEffects WHERE AllianceType='ALLIANCE_RESEARCH'; 