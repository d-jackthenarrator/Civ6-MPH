--==========================================================================================================================
-- One City Challenge by D. / Jack The Narrator
--==========================================================================================================================
-----------------------------------------------
-- Expensionist
-----------------------------------------------

INSERT INTO Types (Type, Kind) VALUES ('UNIT_EXPANSIONIST', 'KIND_UNIT');
INSERT INTO TypeTags (Type, Tag) VALUES ('UNIT_EXPANSIONIST', 'CLASS_LANDCIVILIAN');
INSERT INTO Units	(
		UnitType,
		BaseMoves,		
		Cost,
		AdvisorType,
		BaseSightRange,
		ZoneOfControl,
		Domain,
		FormationClass,
		Name,		
		Description,
		CanCapture,
		CostProgressionModel,
		CostProgressionParam1,
		PurchaseYield,
		PrereqCivic
		)
VALUES  (
		'UNIT_EXPANSIONIST',
		'2',	
		'60', 
		'ADVISOR_GENERIC',
		'2', 
		0,
		'DOMAIN_LAND', 
		'FORMATION_CLASS_CIVILIAN', 
		'LOC_EXPANSIONIST_NAME', 
		'LOC_EXPANSIONIST_DESC',
		0, 
		'COST_PROGRESSION_PREVIOUS_COPIES', 
		'20', 
		'YIELD_GOLD', 
		'CIVIC_EARLY_EMPIRE'
		);


-----------------------------------------------
-- Create the new walls
-----------------------------------------------
UPDATE Improvements
Set TraitType=NULL
WHERE ImprovementType='IMPROVEMENT_GREAT_WALL';

UPDATE Improvements
Set Name='LOC_IMPROVEMENT_OCC_WALL_NAME'
WHERE ImprovementType='IMPROVEMENT_GREAT_WALL';

UPDATE Improvements
Set Description='LOC_IMPROVEMENT_OCC_WALL_DESC'
WHERE ImprovementType='IMPROVEMENT_GREAT_WALL';

UPDATE Improvements
Set CanBuildOutsideTerritory=1
WHERE ImprovementType='IMPROVEMENT_GREAT_WALL';

UPDATE Improvements
Set Buildable=0
WHERE ImprovementType='IMPROVEMENT_GREAT_WALL';

UPDATE Improvement_ValidBuildUnits
Set UnitType='UNIT_EXPANSIONIST'
WHERE ImprovementType='IMPROVEMENT_GREAT_WALL';

-----------------------------------------------
-- ModifierArguments -- Religious Settlement
-----------------------------------------------
UPDATE ModifierArguments
Set Value='UNIT_EXPANSIONIST'
WHERE ModifierId='RELIGIOUS_SETTLEMENTS_SETTLER_MODIFIER' AND Name='UnitType';

UPDATE ModifierArguments
Set Value=2
WHERE ModifierId='RELIGIOUS_SETTLEMENTS_SETTLER_MODIFIER' AND Name='Amount';

-----------------------------------------------
-- ModifierArguments -- Monumentality Settlement
-----------------------------------------------
UPDATE ModifierArguments
Set Value='UNIT_EXPANSIONIST'
WHERE ModifierId='COMMEMORATION_INFRASTRUCTURE_SETTLER_DISCOUNT_MODIFIER' AND Name='UnitType';

-----------------------------------------------
-- MajorStartingUnits
-----------------------------------------------
UPDATE MajorStartingUnits 
SET Quantity = '1' 
WHERE Unit = 'UNIT_SETTLER';

-----------------------------------------------
-- Start with 3 Radius
-----------------------------------------------

INSERT INTO TraitModifiers (TraitType, ModifierId) VALUES ('TRAIT_LEADER_MAJOR_CIV', 'TRAIT_INCREASED_TILES_MAX');

INSERT INTO Modifiers (ModifierId, ModifierType) VALUES ('TRAIT_INCREASED_TILES_MAX', 'MODIFIER_PLAYER_ADJUST_CITY_TILES');

INSERT INTO ModifierArguments (ModifierId, Name, Value) VALUES ('TRAIT_INCREASED_TILES_MAX', 'Amount', '30');

-----------------------------------------------
-- Buff Trade Routes
-----------------------------------------------

UPDATE GlobalParameters
SET Value = '40' 
WHERE Name = 'TRADE_ROUTE_BASE_RANGE';

UPDATE GlobalParameters
SET Value = '40' 
WHERE Name = 'TRADE_ROUTE_LAND_RANGE_REFUEL';

UPDATE GlobalParameters
SET Value = '40' 
WHERE Name = 'TRADE_ROUTE_WATER_RANGE_REFUEL';

UPDATE GlobalParameters
SET Value = '8' 
WHERE Name = 'TRADE_ROUTE_GOLD_PER_DESTINATION_DISTRICT';

UPDATE GlobalParameters
SET Value = '8' 
WHERE Name = 'TRADE_ROUTE_GOLD_PER_ORIGIN_DISTRICT';

UPDATE GlobalParameters
SET Value = '5' 
WHERE Name = 'TRADING_POST_GOLD_IN_FOREIGN_CITY';

UPDATE GlobalParameters
SET Value = '2' 
WHERE Name = 'TRADING_POST_GOLD_IN_OWN_CITY';

-----------------------------------------------
-- Growth And Amenities
-----------------------------------------------

UPDATE GlobalParameters
SET Value = '4' 
WHERE Name = 'CITY_AMENITIES_FOR_FREE';

UPDATE GlobalParameters
SET Value = '12' 
WHERE Name = 'CITY_GROWTH_THRESHOLD';