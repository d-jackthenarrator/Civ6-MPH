--==========================================================================================================================
-- One City Challenge by SailorCat, D. / Jack The Narrator, TC_
--==========================================================================================================================
-----------------------------------------------

INSERT INTO Types (Type, Kind) VALUES ('IMPROVEMENT_SAILOR_WATCHTOWER', 'KIND_IMPROVEMENT');
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
		BuildCharges,
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
		'1', 
		'CIVIC_EARLY_EMPIRE'
		);
------------------------------------------------

INSERT INTO Improvements	(
		ImprovementType,
		Name,		
		Description,
		Icon,
		Buildable,
		PlunderType,
		TilesRequired,
		SameAdjacentValid,
		Domain,		
		CanBuildOutsideTerritory,
		DefenseModifier,
		GrantFortification
		)
VALUES  (
		'IMPROVEMENT_SAILOR_WATCHTOWER', -- ImprovementType
		'LOC_IMPROVEMENT_SAILOR_WATCHTOWER_NAME', -- Name		
		'LOC_IMPROVEMENT_SAILOR_WATCHTOWER_DESCRIPTION', -- Description
		'ICON_IMPROVEMENT_SAILOR_WATCHTOWER', -- Icon
		1, -- Buildable
		'NO_PLUNDER',
		1, -- TilesRequired
		1, -- SameAdjacentValid
		'DOMAIN_LAND', -- Domain
		1, -- CanBuildOutsideTerritory
		'2',
		'2'
		);
-----------------------------------------------
-- Improvement_ValidBuildUnits
-- 
-----------------------------------------------
INSERT INTO Improvement_ValidBuildUnits
		(ImprovementType,					UnitType)
VALUES  (
		'IMPROVEMENT_SAILOR_WATCHTOWER', -- ImprovementType
		'UNIT_EXPANSIONIST'
		);
-----------------------------------------------
-- Improvement_ValidTerrains
-----------------------------------------------
INSERT INTO Improvement_ValidTerrains
		(ImprovementType,					TerrainType)
SELECT	'IMPROVEMENT_SAILOR_WATCHTOWER',	TerrainType
FROM Terrains WHERE Water != 1 AND Mountain != 1;
-----------------------------------------------
-- Improvement_ValidFeatures
-----------------------------------------------
INSERT INTO Improvement_ValidFeatures
		(ImprovementType,					FeatureType)
SELECT	'IMPROVEMENT_SAILOR_WATCHTOWER',	FeatureType
FROM Features WHERE Coast = 0 AND NaturalWonder = 0 AND FeatureType NOT IN (SELECT FeatureType FROM Feature_ValidTerrains WHERE TerrainType = 'TERRAIN_COAST') AND FeatureType NOT LIKE '%VOLCAN%' AND FeatureType != 'FEATURE_GEOTHERMAL_FISSURE';

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
