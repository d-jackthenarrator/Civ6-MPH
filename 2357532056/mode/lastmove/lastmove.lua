------------------------------------------------------------------------------
--	FILE:	 lastmove.lua
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Gameplay script - Handle Last Move Frist Move
-------------------------------------------------------------------------------

print("-- Last Move First Move Mode Gameplay Script--");

-- ===========================================================================
--	NEW VARIABLES
-- ===========================================================================
ExposedMembers.LuaEvents = LuaEvents
local Last_Data = {};
local b_debuff = false
local b_clean = true
local NO_PLAYER :number = -1;

-- =========================================================================== 
--	NEW FUNCTIONS
-- =========================================================================== 

function ApplyDebuff(playerID:number, unitID:number)
	unit = UnitManager.GetUnit(playerID, unitID)

	if unit ~= nil then
		local unitAbilities = unit:GetAbility()
		if unitAbilities ~= nil then
			if (unitAbilities:GetAbilityCount("ABILITY_LAST_MOVED")==0) then
				unitAbilities:ChangeAbilityCount("ABILITY_LAST_MOVED",1)
			end
			if (unitAbilities:GetAbilityCount("ABILITY_LAST_MOVED_READY")==1) then
				unitAbilities:ChangeAbilityCount("ABILITY_LAST_MOVED_READY",-1)
			end
		end
	end

end

-- =========================================================================== 
--	NEW EVENTS
-- =========================================================================== 

function OnCombatOccurred(attackerPlayerID :number, attackerUnitID :number, defenderPlayerID :number, defenderUnitID :number)
	if(attackerPlayerID == NO_PLAYER ) then
		return;
	end

	local pAttackerPlayerConfig :object = PlayerConfigurations[attackerPlayerID];
	local pAttackerPlayer :object = Players[attackerPlayerID];
	local pAttackingUnit :object = pAttackerPlayer:GetUnits():FindID(attackerUnitID);

	if pAttackingUnit ~= nil then
		OnLastMove(attackerPlayerID,attackerUnitID)
	end

	if(defenderPlayerID == NO_PLAYER
		or defenderUnitID == NO_UNIT) then
		return;
	end

	local pDefenderPlayerConfig = PlayerConfigurations[defenderPlayerID];
	local pDefenderPlayer = Players[defenderPlayerID];
	local unit = pDefenderPlayer:GetUnits():FindID(defenderUnitID);
	local unitAbilities = unit:GetAbility()
	if unitAbilities ~= nil and b_debuff == false then
		if (unitAbilities:GetAbilityCount("ABILITY_LAST_MOVED")==1) then
			unitAbilities:ChangeAbilityCount("ABILITY_LAST_MOVED",-1)
			if unitAbilities:GetAbilityCount("ABILITY_LAST_MOVED_READY") == 0 or unitAbilities:GetAbilityCount("ABILITY_LAST_MOVED_READY") == -1 then
				unitAbilities:ChangeAbilityCount("ABILITY_LAST_MOVED_READY",1)
			end
		end
	end
end


GameEvents.OnCombatOccurred.Add(OnCombatOccurred);

function OnUnitMoved( playerID:number, unitID:number )
	if b_debuff == false then
		return
	end
	
	if Players[playerID] ~= nil then
		if Players[playerID]:IsMajor() then
			OnLastMove(playerID,unitID)
		end
	end
end

function OnLastMove(playerID:number, unitID:number)
	print("OnLastMove", playerID,unitID)
	local tmp = {player = playerID, unit = unitID}
	table.insert(Last_Data,tmp)
end

GameEvents.OnUnitMoved.Add(OnUnitMoved)

function OnHostCommandLastMoveClean(ePlayer : number,params : table)
	print("Clean Received on the Script Side")
	RemoveDebuff()
end

GameEvents.OnHostCommandLastMoveClean.Add( OnHostCommandLastMoveClean );

function OnHostCommandLastMoveStart(ePlayer : number,params : table)
	print("Start Received on the Script Side")
	b_debuff = true
end

GameEvents.OnHostCommandLastMoveStart.Add( OnHostCommandLastMoveStart );



function RemoveDebuff()
	print("RemoveDebuff()")
	b_clean = true
	for i = 0, PlayerManager.GetWasEverAliveMajorsCount() -1 do
		if Players[i] ~= nil then
			if Players[i]:IsAlive() == true and Players[i]:IsHuman() == true then
				local pPlayerUnits = Players[i]:GetUnits()
				for k, unit in pPlayerUnits:Members() do
					if unit ~= nil then
						local unitAbilities = unit:GetAbility()
						if unitAbilities ~= nil then
							if (unitAbilities:GetAbilityCount("ABILITY_LAST_MOVED")==1) then
								unitAbilities:ChangeAbilityCount("ABILITY_LAST_MOVED",-1)
								if unitAbilities:GetAbilityCount("ABILITY_LAST_MOVED_READY") == 0 or unitAbilities:GetAbilityCount("ABILITY_LAST_MOVED_READY") == -1 then
									unitAbilities:ChangeAbilityCount("ABILITY_LAST_MOVED_READY",1)
								end
							end
						end
					end
				end
			end
		end
	end	
end



-----------------------------------------------------------------------------------------

function OnGameTurnStarted()
	print("OnGameTurnStarted()")
	-- Last Move
	for i = 0, PlayerManager.GetWasEverAliveMajorsCount() -1 do
		if Players[i] ~= nil then
			if Players[i]:IsAlive() == true and Players[i]:IsHuman() == true then
				local pPlayerUnits = Players[i]:GetUnits()
				for k, unit in pPlayerUnits:Members() do
					if unit ~= nil then
						local unitAbilities = unit:GetAbility()
						if unitAbilities ~= nil then
							if (unitAbilities:GetAbilityCount("ABILITY_LAST_MOVED_READY")==1) then
								unitAbilities:ChangeAbilityCount("ABILITY_LAST_MOVED_READY",-1)
								print("Clean Buff",i,unit,"turn",Game.GetCurrentGameTurn())
							end
						end
					end
				end
			end
		end
	end	
	if Last_Data ~= nil then
		local pUnit
		for i, row in pairs(Last_Data) do
			if row.player ~= nil and row.unit ~= nil then
				print("OnGameTurnStarted",row.player,row.unit)
				pUnit = UnitManager.GetUnit(row.player, row.unit)
				if pUnit ~= nil then
					local unitAbilities = pUnit:GetAbility()
					if unitAbilities ~= nil then
						print("unitAbilities:GetAbilityCount(ABILITY_LAST_MOVED)",unitAbilities:GetAbilityCount("ABILITY_LAST_MOVED"))
						if (unitAbilities:GetAbilityCount("ABILITY_LAST_MOVED")==0) then
							unitAbilities:ChangeAbilityCount("ABILITY_LAST_MOVED",1)
							print("OnGameTurnStarted - Applied Debuff",row.player,row.unit,pUnit,"turn",Game.GetCurrentGameTurn())
							print("unitAbilities:GetAbilityCount(ABILITY_LAST_MOVED) Add Debuff",unitAbilities:GetAbilityCount("ABILITY_LAST_MOVED"))
						end
					end
				end
			end	
		end
	end

	Last_Data = {}
	b_debuff = false
end

GameEvents.OnGameTurnStarted.Add(OnGameTurnStarted);


