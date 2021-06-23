-------------------------------------------------------------------------------
-- SetupParameters.lua
-- Logic that visualizes data-defined parameters and updates a variant map with 
-- their values.
-------------------------------------------------------------------------------
print("SetupParameter for MPH")
-- Set this to true to enable detailed logging of setup parameters.
local SetupParameters_EnableLogging = false;

-- Set this to true to enable detailed profiling of setup parameters.
local SetupParameters_EnableProfiling = false;


if(SetupParameters_EnableLogging and print) then
	SetupParameters_Log = print;
else
	SetupParameters_Log = function() end;
end

if(SetupParameters_EnableProfiling and GetTickCount and where and print) then
	local startTicks = 0;
	local stepTicks = 0;
	local blockTicks = 0;

	function BeginProfiling(t)
		startTicks = GetTickCount();
		stepTicks = startTicks;
	end

	function EndProfiling(label)
		print("Profile:", (GetTickCount() - startTicks) * 0.0001, label or where(2));
	end
	function ProfileStep(step)
		local v = GetTickCount();
		print("Profile:", (v - stepTicks) * 0.0001, step);
		stepTicks = v;
	end

	function BeginProfileBlock() 
		blockTicks = GetTickCount();
	end

	function EndProfileBlock(label)
		print("Profile:", (GetTickCount() - blockTicks) * 0.0001, label or where(2));
	end
else
	function BeginProfiling(t) end;
	function EndProfiling() end;
	function ProfileStep(step) end;
	function BeginProfileBlock() end;
	function EndProfileBlock() end;
end

QueryChanges = 0;
QueryCache = {};
ResultsId = 1;
-------------------------------------------------------------------------------
-- Global function for caching the result of a database query with arguments.
-------------------------------------------------------------------------------
function CachedQuery(sql, ...)
	
	-- If the database has been updated.  Invalidate the cache.
	local changes = DB.ConfigurationChanges();
	if(changes ~= QueryChanges) then
		QueryCache = {};
		QueryChanges = changes;
	end

	-- Is there a cached entry for this?
	local cache = QueryCache[sql];
	if(cache == nil) then
		cache = {};
		QueryCache[sql] = cache;
	end


	local arg_count = select("#", ...);
	local args = {};
	for arg_index = 1, arg_count, 1 do
		args[arg_index] = select(arg_index, ...);
	end

	-- Obtain the cached results.
	local results;
	for i, v in ipairs(cache) do

		local match = true;
		for arg_index, arg_value in ipairs(args) do
			if(v[arg_index] ~= arg_value) then
				match = false;
				break;
			end
		end

		if(match) then
			results = v[0];
			break;
		end
	end

	-- Otherwise query ourselves.
	if(results == nil) then
		local entry = args;
		results = DB.ConfigurationQuery(sql, ...);
		results.Id = ResultsId;
		ResultsId = ResultsId + 1;

		entry[0] = results;
		table.insert(cache, entry);
	end

	return results;
end

-------------------------------------------------------------------------------
-- Global functions for parsing domains into pieces and caching the result.
-------------------------------------------------------------------------------
local _WildcardChar = string.byte("*");
local _WildCardDomains = {};
local _DomainParts = {};

local _CacheFunction = function(cache, func) 
	local f = function(v)
		local result = cache[v];
		if(result ~= nil) then
			return result;
		else
			result = func(v);
			cache[v] = result;
			return result;
		end
	end

	return f;
end
local sbyte = string.byte;
local _IsWildCard = _CacheFunction(_WildCardDomains, function(d)
	-- Optimization NOTE: Is string.find(domain, "*") ~= nil faster?
	local len = #d;
	for i = 1, len, 1 do
		if(sbyte(d, i) == _WildcardChar) then
			return true;
		end
	end
	return false;
end);

local sgmatch = string.gmatch;
local _SplitDomain = _CacheFunction(_DomainParts, function(d)
	local i = 1;
	local v = {};

	for w in sgmatch(d, "[^:]+") do
		v[i] = w;
		i = i + 1;
	end

	return v;
end);

local _CacheDomainParts = function(domains)
	for d,_ in pairs(domains) do
		_IsWildCard(d);
		_SplitDomain(d);
	end
end


-------------------------------------------------------------------------------
-- Beginning of actual SetupParameter code.
-------------------------------------------------------------------------------
SetupParameters = {};

-------------------------------------------------------------------------------
-- Constructs a new instance of the SetupParameters object.
-------------------------------------------------------------------------------
function SetupParameters.new(playerId)
	local o = {
		PlayerId = playerId,
		Controls = {}
	};
	setmetatable(o, {__index = SetupParameters});

	return o;
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Allocates any needed resources, such as cached queries.
-- Should be called before use.
-------------------------------------------------------------------------------
function SetupParameters:Initialize()
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Releases any resources (such as cached queries) that were created.
-------------------------------------------------------------------------------
function SetupParameters:Shutdown()

end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Perform a simple refresh on all parameters.  This will update both config-only. 
-------------------------------------------------------------------------------
function SetupParameters:Refresh()
	self:UpdateParameters(self:Data_DiscoverParameters());
end

-------------------------------------------------------------------------------
-- Perform a full refresh on all parameters.  This will update both config 
-- and UI.
-------------------------------------------------------------------------------
function SetupParameters:FullRefresh()
	self:UpdateParameters(self:Data_DiscoverParameters());
	self:UpdateVisualization();
end

-------------------------------------------------------------------------------
-- Perform an update with the supplied parameters.
-- Returns true if Update should probably be called again due to changes made.
-- Does *not* update the UI.  UpdateVisualization() should be called after.
-------------------------------------------------------------------------------
function SetupParameters:UpdateParameters(parameters)
	BeginProfiling();	

	SetupParameters_Log("Updating Parameters - " .. tostring(self.PlayerId or "Game"));
	local old_params = self.Parameters or {};
	local new_params = parameters or {}; 

	-- Handle parameters that no longer exist first.
	local params_to_wipe = {};
	for pid, p in pairs(old_params) do
		ProfileStep("Parameter List - ParameterId:"..tostring(p.ParameterId).." - Value:"..tostring(p.Value));
		if(new_params[pid] == nil) then
			-- Next, wipe out any configuration values associated with the parameter.
			table.insert(params_to_wipe, p);	
		end
	end

	-- Handle any new parameters.
	local params_by_group = {};
	for pid, p in pairs(new_params) do
		local group = params_by_group[p.GroupId];
		if(group == nil) then
			group = {};
			params_by_group[p.GroupId] = group;
		end

		table.insert(group, p);
	end

	-- Sort individual groups and place group in array to be sorted.
	-- This might be overkill, but we want the order of operations to be consistent across all machines.
	local sorted_groups = {};
	
	for gid, g in pairs(params_by_group) do
		self.Utility_SortValues(g);
		table.insert(sorted_groups, {gid, g});
	end

	table.sort(sorted_groups, function(a,b) return a[1] < b[1] end);

	ProfileStep("Sort Parameters.");
	
	local params_to_write = {};

	for i, group in ipairs(sorted_groups) do
		local gid = group[1];
		local g = group[2];

		for ii, p in ipairs(g) do
		
			local pid = p.ParameterId;

			local old_param = old_params[pid];
			
			-- This logic needs to be performed for both new and existing parameters.
			-- Fetch the values from configuration and update parameter value.
			-- Sync will return true if the sync'd value doesn't match config.
			local should_write = self:Parameter_SyncConfigurationValues(p);  

			local value = p.Value;
			if(type(value) == "table" and value.Value ~= nil) then
				value = value.Value;
			end

			SetupParameters_Log("Parameter - " .. tostring(p.ParameterId) .. " : " .. tostring(value));

			-- If needed, push the parameter value into the configuration.
			if(should_write and self:Config_CanWriteParameter(p)) then
				SetupParameters_Log("Parameter needs to update config.");
				table.insert(params_to_write, p);
			end 
		end
	end

	self.Parameters = new_params;

	ProfileStep("Sync Parameters.");

	-- Writes are batched to minimize event dispatch.
	if(#params_to_wipe > 0 or #params_to_write > 0) then
		self:Config_BeginWrite();

		local parameters_changed = false;
		for i,p in ipairs(params_to_wipe) do
			SetupParameters_Log("Wiping parameter - " .. p.ParameterId);
			if(self:Config_ClearParameterValues(p)) then
				parameters_changed = true;
			else
				SetupParameters_Log("Could not wipe parameter - " .. p.ParameterId);
			end
		end

		for i,p in ipairs(params_to_write) do
			local value = p.Value;
			if(type(value) == "table") then
				value = value.Value;
			end

			SetupParameters_Log("Writing parameter - " .. p.ParameterId .. " to " .. tostring(value) .. "(" .. type(value) .. ")");
			if(self:Config_WriteParameterValues(p)) then
				parameters_changed = true;
			else
				SetupParameters_Log("Could not write parameter - " .. p.ParameterId);
			end 
		end

		self:Config_EndWrite(parameters_changed);
	else
		SetupParameters_Log("Nothing to change.");
	end	

	ProfileStep("Write Parameters.");

	SetupParameters_Log("Checking static configuration updates");
	if(self.ConfigurationUpdates) then
		local updates = {};
		for i,v in ipairs(self.ConfigurationUpdates) do
			if(v.Static) then
				local value = self:Config_Read(v.SourceGroup, v.SourceId);
				if(value == v.SourceValue or value == DB.MakeHash(v.SourceValue) or (type(value) == "boolean" and value == false and v.SourceValue == 0) or (type(value) == "boolean" and value == true and v.SourceValue == 1)) then
					local update_value = v.Hash and DB.MakeHash(v.TargetValue) or v.TargetValue;
					local current_value = self:Config_Read(v.TargetGroup, v.TargetId);

					-- If this is a boolean type convert to a 0 or 1 numeric type.
					if(type(current_value) == "boolean") then
						current_value = current_value and 1 or 0;
					end																   
					if(current_value ~= update_value) then
						table.insert(updates, {
							v.TargetGroup,
							v.TargetId,
							v.TargetValue,
							update_value
						});
					end
				end
			end
		end

		if(#updates > 0) then
			self:Config_BeginWrite();
			for i,v in ipairs(updates) do
				SetupParameters_Log("Writing additional config values - " .. tostring(v[2]) .. " = " .. tostring(v[3]));
				self:Config_Write(v[1], v[2], v[4]);
			end
			self:Config_EndWrite(true);
		end
	end

	ProfileStep("Additional Configuration Updates.");
	EndProfiling("UpdateParameters");
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Syncronize the UI to the current parameter data.
-------------------------------------------------------------------------------
function SetupParameters:UpdateVisualization()
	BeginProfiling();
	SetupParameters_Log("Visualizing Parameters - " .. tostring(self.PlayerId or "Game"));

	local old_params = self.VisualParameters or {};
	local new_params = self.Parameters or {}; 

	self:UI_BeforeRefresh();
	ProfileStep("UI_BeforeRefresh");

	-- Handle parameters that no longer exist first.
	for pid, p in pairs(old_params) do
		if(new_params[pid] == nil) then
			-- First, tell UI that the parameter is being destroyed.
			self:UI_DestroyParameter(p);
		end
	end

	ProfileStep("UI_DestroyParameter");

	-- Handle any new parameters.
	local params_by_group = {};
	for pid, p in pairs(new_params) do
		local group = params_by_group[p.GroupId];
		if(group == nil) then
			group = {};
			params_by_group[p.GroupId] = group;
		end

		table.insert(group, p);
	end

	ProfileStep("Index new parameters");

	-- Sort individual groups and place group in array to be sorted.
	-- This might be overkill, but we want the order of operations to be consistent across all machines.
	local sorted_groups = {};
	for gid, g in pairs(params_by_group) do
		self.Utility_SortValues(g);
		table.insert(sorted_groups, {gid, g});
	end

	table.sort(sorted_groups, function(a,b) return a[1] < b[1] end);

	ProfileStep("Sort parameters");

	for i, group in ipairs(sorted_groups) do
		local gid = group[1];
		local g = group[2];

		
		BeginProfileBlock();
		self:UI_BeforeRefreshGroup(gid);
		EndProfileBlock("UI_BeforeRefreshGroup");

		for ii, p in ipairs(g) do
		
			local pid = p.ParameterId;

			local old_param = old_params[pid];
			
			-- Is this a newly added parameter?
			if(old_param == nil) then
				-- Tell UI about the new parameter.
				BeginProfileBlock();
				self:UI_CreateParameter(p);
				EndProfileBlock("UI_CreateParameter");
			end

			-- With values properly synchronized, it's time to notify UI of the changes.
			BeginProfileBlock();
			self:UI_SetParameterPossibleValues(p);   
			EndProfileBlock("UI_SetParameterPossibleValues - " .. p.ParameterId);

			BeginProfileBlock();
			self:UI_SetParameterValue(p);
			EndProfileBlock("UI_SetParameterValue");
			
			BeginProfileBlock();
			self:UI_SetParameterEnabled(p);
			EndProfileBlock("UI_SetParameterEnabled");
			
			BeginProfileBlock();
			self:UI_SetParameterVisible(p);
			EndProfileBlock("UI_SetParameterVisible");
 
		end

		BeginProfileBlock();
		self:UI_AfterRefreshGroup(gid);
		EndProfileBlock("UI_AfterRefreshGroup");
	end
	ProfileStep("Create/Update parameters");

	self.VisualParameters = new_params;
	self:UI_AfterRefresh();
	ProfileStep("UI_AfterRefresh");

	EndProfiling("UpdateVisualization");
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Set the value of a parameter.
-- This will update the configuration as well as trigger any UI updates.
-------------------------------------------------------------------------------
function SetupParameters:SetParameterValue(p, v)
	p.Value = v;
	self:Config_BeginWrite();
	local result = self:Config_WriteParameterValues(p);
	self:Config_EndWrite(result);
end
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- DebugPrint()
-- Print out all parameters.
-------------------------------------------------------------------------------
function SetupParameters:DebugPrint()
	for pid, p in pairs(ConfigurationParameters.Parameters) do
		print("Id: " .. pid);
		print("* Name: " .. p.Name);
		print("* Group: " .. p.GroupId);
		print("* Default Value: " .. tostring(p.DefaultValue));

		if(p.Values ~= nil) then
			local value_names = {};
			for i,v in ipairs(p.Values) do
				table.insert(value_names, v.Name);
			end

			print("* Possible Values: " .. table.concat(value_names, ", "));
		end
	end 
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Auxiliary  Methods
-- The methods below are used by  the primary methods.
-- Some of these do not perform any action (namely the UI_* methods).
-- The intent is for these methods to be overridden per-instance to perform
-- the necessary tasks.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called before configuration values will be written.
-------------------------------------------------------------------------------
function SetupParameters:Config_BeginWrite()
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Determine whether a parameter is allowed to be written to.
-------------------------------------------------------------------------------
function SetupParameters:Config_CanWriteParameter(parameter)
	--TODO: Migrate these checks to a separate predicate.
	-- Check ChangeableAfterGameStart state.
	local gameState = GameConfiguration.GetGameState(); 
	if(not parameter.ChangeableAfterGameStart and gameState ~= GameStateTypes.GAMESTATE_PREGAME) then
		return false;
	end

	-- Check ChangeableAfterPlayByCloudMatchCreate state.
	if(not parameter.ChangeableAfterPlayByCloudMatchCreate 
		and GameConfiguration.IsPlayByCloud()
		and Network.IsInSession()) then
		return false;
	end

	if (not Network.IsInSession() or Network.IsNetSessionHost() or self.PlayerId == Network.GetLocalPlayerID()) then

		-- As long as this isn't hot seat, Human players will provide their own settings (including filtered domains)
		if(self.PlayerId and not GameConfiguration.IsHotseat() and self.PlayerId ~= Network.GetLocalPlayerID()) then
			local playerConfig = PlayerConfigurations[self.PlayerId];
			return not playerConfig:IsHuman();
		else
			return true;
		end 

		
	else
		return false;
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Wipes out any configuration values that the parameter is mapped to.
-------------------------------------------------------------------------------
function SetupParameters:Config_ClearParameterValues(parameter)

	if(self:Config_CanWriteParameter(parameter)) then
		return self:Config_Write(parameter.ConfigurationGroup, parameter.ConfigurationId, nil);
	else
		return false;
	end	
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called after configuration values have been written.
-------------------------------------------------------------------------------
function SetupParameters:Config_EndWrite()
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Reads in a single value from the configuration.
-------------------------------------------------------------------------------
function SetupParameters:Config_Read(group, id)
	if(group == "Game") then
		return GameConfiguration.GetValue(id);
	elseif(group == "Map") then
		return MapConfiguration.GetValue(id);
	elseif(group == "Player" and self.PlayerId ~= nil) then
		return PlayerConfigurations[self.PlayerId]:GetValue(id);
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Reads and returns configuration values that the parameter is mapped to.
-------------------------------------------------------------------------------
function SetupParameters:Config_ReadParameterValues(parameter)
	local value = self:Config_Read(parameter.ConfigurationGroup, parameter.ConfigurationId);

	-- The value may be a hash value.  Attempt to translate.
	if(value ~= nil and parameter.Values ~= nil and type(value) == "number" ) then
		for i, v in ipairs(parameter.Values) do
			local hash = v.Hash;
			if(hash == nil) then
				hash = DB.MakeHash(v.Value);
				v.Hash = hash;
			end

			if(hash == value) then
				value = v.Value;
				break;
			end
		end
	end

	return value;
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Writes a single value to the configuration.
-------------------------------------------------------------------------------
function SetupParameters:Config_Write(group, id, value)
	if(group == "Game" and self.PlayerId == nil) then
		GameConfiguration.SetValue(id, value);
		--print("Game", id,value)
	elseif(group == "Map" and self.PlayerId == nil) then
		MapConfiguration.SetValue(id, value);
		--print("Map", id,value)
	elseif(group == "Player" and self.PlayerId ~= nil) then
		--print("Player", id,value)
		SetupParameters_Log("Config_Write- Player" .. tostring(id) .. " = " .. tostring(value));
		PlayerConfigurations[self.PlayerId]:SetValue(id, value);
	else
		return false;
	end

	if(self.ConfigurationUpdates) then
		for i,v in ipairs(self.ConfigurationUpdates) do
			if(v.SourceGroup == group and v.SourceId == id) then
				if(value == v.SourceValue or value == DB.MakeHash(v.SourceValue) or (type(value) == "boolean" and value == false and v.SourceValue == 0) or (type(value) == "boolean" and value == true and v.SourceValue == 1)) then
					local update_value = v.Hash and DB.MakeHash(v.TargetValue) or v.TargetValue;
					SetupParameters_Log("Writing additional config values - " .. tostring(v.TargetId) .. " = " .. tostring(v.TargetValue));
					self:Config_Write(v.TargetGroup, v.TargetId, update_value);
				end
			end
		end
	end

	return true;
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Writes out the current value of the parameter to configuration.
-------------------------------------------------------------------------------
function SetupParameters:Config_WriteParameterValues(parameter)

	if (self:Config_CanWriteParameter(parameter)) then
		local value = parameter.Value;


		if(parameter.Array) then
			if(value) then
				-- Transform parameter value to a configuration value.
				local values = {};
				if(parameter.Hash) then
					for i,v in ipairs(value) do
						values[i] = v.Hash or DB.MakeHash(v.Value);
					end
				else
					for i,v in ipairs(value) do
						values[i] = v.Value;
					end
				end

				value = values;
			end
		else
			-- If this comes from a multi-value, obtain the inner value.
			if(type(value) == "table") then
				value = value.Value;
			end
		
			if(parameter.Hash and value ~= nil) then
				value = DB.MakeHash(value);
			end
		end

		local result = self:Config_Write(parameter.ConfigurationGroup, parameter.ConfigurationId, value);
		if(result) then
			self:Config_WriteAuxParameterValues(parameter);		
		end
		return result
	else
		return false;
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Writes out the auxiliary values of the parameter to configuration.
-------------------------------------------------------------------------------
function SetupParameters:Config_WriteAuxParameterValues(parameter)
	if(parameter.DomainConfigurationId) then
		self:Config_Write(parameter.ConfigurationGroup, parameter.DomainConfigurationId, parameter.Domain);
	end

	if(parameter.DomainValuesConfigurationId) then
		local values;
		if(type(parameter.Values) == "table") then
				
			local scratch = {};
			for i,v in ipairs(parameter.Values) do
				if(v.Invalid ~= true) then
					table.insert(scratch, tostring(v.Domain) .. "::" .. tostring(v.Value));
				end
			end

			values = table.concat(scratch, ",");
		end

		self:Config_Write(parameter.ConfigurationGroup, parameter.DomainValuesConfigurationId, values);
	end

	if(parameter.ValueNameConfigurationId) then
		local bundle = (parameter.Value ~= nil) and Locale.Bundle(parameter.Value.RawName);
		self:Config_Write(parameter.ConfigurationGroup, parameter.ValueNameConfigurationId, bundle);
	end

	if(parameter.NameArrayConfigurationId) then
		
		-- Avoid table lookups by copying to local
		local paramValue = parameter.Value;
		local paramRawName = parameter.RawName;
		local paramConfigGroup = parameter.ConfigurationGroup;
		local paramNameArrayConfigurationId = parameter.NameArrayConfigurationId;
		
		local config_value = self:Config_Read(paramConfigGroup, paramNameArrayConfigurationId);
		local tvalue = type(paramValue);
		if(tvalue == "boolean" and paramValue == true) then

			local bundle = Locale.Bundle(paramRawName) or paramRawName;

			-- Add the value to the list.
			if(config_value == nil) then
				config_value = {bundle};
			else
				for i,v in ipairs(config_value or {}) do
					if(v == bundle) then
						config_value = nil;
						break;
					end
				end

				if(config_value) then
					table.insert(config_value, bundle);
				end
			end	

			if(config_value) then
				self:Config_Write(paramConfigGroup, paramNameArrayConfigurationId, config_value);
			end
		else
			-- Remove it from the list.
			-- Do nothing if config_value is nil.
			if(config_value) then

				local bundle = Locale.Bundle(paramRawName) or paramRawName;

				-- Since the table contains only unique value, a simple iterate and remove will suffice.
				for i,v in ipairs(config_value) do
					if(v == bundle) then
						table.remove(config_value, i);
						break;
					end
				end

				-- If the array is empty, remove the value, otherwise update.
				if(#config_value > 0) then
					self:Config_Write(paramConfigGroup, paramNameArrayConfigurationId, config_value);
				else
					self:Config_Write(paramConfigGroup, paramNameArrayConfigurationId, nil);
				end
			end
		end
	end										
	if(parameter.ValueDomainConfigurationId) then
		local domain = (type(parameter.Value) == "table") and parameter.Value.Domain;
		self:Config_Write(parameter.ConfigurationGroup, parameter.ValueDomainConfigurationId, domain);
	end

	-- KLUDGE!  This should be in PlayerSetupLogic.lua
	-- Extend auxilery values to include CivilizationTypeName and Hash
	if(parameter.ParameterId == "PlayerLeader") then
	
		local civilizationType = (parameter.Value ~= nil) and GetPlayerCivilization(parameter.Value.Domain, parameter.Value.Value);
		local civilizationTypeId = (civilizationType) and DB.MakeHash(civilizationType);

		self:Config_Write("Player", "CIVILIZATION_TYPE_NAME", civilizationType);
		self:Config_Write("Player", "CIVILIZATION_TYPE_ID", civilizationTypeId);
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Returns a map of all discovered parameters using the latest configuration.
-------------------------------------------------------------------------------
function SetupParameters:Data_DiscoverParameters()
	BeginProfiling();
	SetupParameters_Log("Discovering Parameters");

	--Cache data.
	local queries = {};
	for i, row in ipairs(CachedQuery("SELECT * from Queries")) do
		queries[row.QueryId] = row;
	end

	local query_parameters = {};
	for i, row in ipairs(CachedQuery("SELECT * from QueryParameters")) do
		local query = queries[row.QueryId];
		if(query) then
			local parameters = query.Parameters;
			if(parameters == nil) then
				parameters = {};
				query.Parameters = parameters;
			end

			parameters[tonumber(row.Index)] = row;
		end
	end

	local parameter_queries = {};	
	for i, row in ipairs(CachedQuery("SELECT * from ParameterQueries")) do
		parameter_queries[row.ParameterQueryId] = row;
	end

	for i, row in ipairs(CachedQuery("SELECT * from ParameterQueryCriteria")) do
		local pq = parameter_queries[row.ParameterQueryId];
		if(pq) then
			if(pq.Criteria == nil) then pq.Criteria = {}; end
			table.insert(pq.Criteria, row);
		end
	end

	for i, row in ipairs(CachedQuery("SELECT * from ParameterQueryDependencies")) do
		local pq = parameter_queries[row.ParameterQueryId];
		if(pq) then
			if(pq.Dependencies == nil) then pq.Dependencies = {}; end
			table.insert(pq.Dependencies, row);
		end
	end

	local domain_override_queries = {};
	for i, row in ipairs(CachedQuery("SELECT * FROM DomainOverrideQueries")) do
		table.insert(domain_override_queries, row);
	end

	local domain_range_queries = {};
	for i, row in ipairs(CachedQuery("SELECT * FROM DomainRangeQueries")) do
		table.insert(domain_range_queries, row);
	end

	-- Domain values.
	local domain_value_queries = {};
	for i, row in ipairs(CachedQuery("SELECT * FROM DomainValueQueries")) do
		table.insert(domain_value_queries, row);
	end

	-- Domain value filters.
	local domain_value_filter_queries = {};
	for i, row in ipairs(CachedQuery("SELECT * FROM DomainValueFilterQueries")) do
		table.insert(domain_value_filter_queries, row);
	end

	-- Domain value unions.
	local domain_union_queries = {};
	for i, row in ipairs(CachedQuery("SELECT * FROM DomainValueUnionQueries")) do
		table.insert(domain_union_queries, row);
	end

	-- Cross reference parameters with criteria and dependencies.
	local parameter_criteria = {};
	for i, query in ipairs(CachedQuery("SELECT * from ParameterCriteriaQueries")) do
		local q = queries[query.QueryId];
		if(q) then
			for _, row in ipairs(self:Data_Query(q)) do
				local criteria = {
					ParameterId = row[query.ParameterIdField],
					ConfigurationGroup = row[query.ConfigurationGroupField],
					ConfigurationId = row[query.ConfigurationIdField],
					Operator = row[query.OperatorField],
					ConfigurationValue = row[query.ConfigurationValueField],
				};

				local c = parameter_criteria[criteria.ParameterId];
				if(c == nil) then
					c = {};
					parameter_criteria[criteria.ParameterId] = c;
				end 
				table.insert(c, criteria);
			end
		end
	end

	local parameter_dependencies = {};
	for i, query in ipairs(CachedQuery("SELECT * from ParameterDependencyQueries")) do
		local q = queries[query.QueryId];
		if(q) then
			for _, row in ipairs(self:Data_Query(q)) do
				local criteria = {
					ParameterId = row[query.ParameterIdField],
					ConfigurationGroup = row[query.ConfigurationGroupField],
					ConfigurationId = row[query.ConfigurationIdField],
					Operator = row[query.OperatorField],
					ConfigurationValue = row[query.ConfigurationValueField],
				};

				local c = parameter_dependencies[criteria.ParameterId];
				if(c == nil) then
					c = {};
					parameter_dependencies[criteria.ParameterId] = c;
				end 
				table.insert(c, criteria);
			end
		end
	end
	
	local configuration_updates = {};
	for i, query in ipairs(CachedQuery("SELECT * from ConfigurationUpdateQueries")) do
		local q = queries[query.QueryId];
		if(q) then
			for _, row in ipairs(self:Data_Query(q)) do
				local config_update = {
					SourceGroup = row[query.SourceGroupField],
					SourceId = row[query.SourceIdField],
					SourceValue = row[query.SourceValueField],
					TargetGroup = row[query.TargetGroupField],
					TargetId = row[query.TargetIdField],
					TargetValue = row[query.TargetValueField],
					Hash = self.Utility_ToBool(row[query.HashField]),
					Static = self.Utility_ToBool(row[query.StaticField])
				};

				table.insert(configuration_updates, config_update);
			end
		end
	end
	self.ConfigurationUpdates = configuration_updates;

	ProfileStep("Cache Data");

	-- Query for Parameters.
	local parameters = {};
	for pqid, pq in pairs(parameter_queries) do
		if(self:Parameter_MeetsCriteria(pq.Dependencies)) then
			local q = queries[pq.QueryId];
			if(q) then		
				for i, row in ipairs(self:Data_Query(q)) do
					local p = {
						Query = pq,
						ParameterId = row[pq.ParameterIdField],
						RawName = row[pq.NameField],
						Name = Locale.Lookup(row[pq.NameField]),
						Description = Locale.Lookup(row[pq.DescriptionField] or ""),
						Domain = row[pq.DomainField],
						Hash = self.Utility_ToBool(row[pq.HashField]),
						Array = self.Utility_ToBool(row[pq.ArrayField]),
						DefaultValue = row[pq.DefaultValueField],
						ConfigurationGroup = row[pq.ConfigurationGroupField],
						ConfigurationId = row[pq.ConfigurationIdField],								
						DomainConfigurationId = row[pq.DomainConfigurationIdField],
						DomainValuesConfigurationId = row[pq.DomainValuesConfigurationIdField],
						ValueNameConfigurationId = row[pq.ValueNameConfigurationIdField],
						ValueDomainConfigurationId = row[pq.ValueDomainConfigurationIdField],
						NameArrayConfigurationId = row[pq.NameArrayConfigurationIdField],
						GroupId = row[pq.GroupField],
						Visible = self.Utility_ToBool(row[pq.VisibleField]),
						ReadOnly = self.Utility_ToBool(row[pq.ReadOnlyField]),
						SupportsSinglePlayer = self.Utility_ToBool(row[pq.SupportsSinglePlayerField]),
						SupportsLANMultiplayer = self.Utility_ToBool(row[pq.SupportsLANMultiplayerField]),
						SupportsInternetMultiplayer = self.Utility_ToBool(row[pq.SupportsInternetMultiplayerField]),
						SupportsHotSeat = self.Utility_ToBool(row[pq.SupportsHotSeatField]),
						SupportsPlayByCloud = self.Utility_ToBool(row[pq.SupportsPlayByCloudField]),
						ChangeableAfterGameStart = self.Utility_ToBool(row[pq.ChangeableAfterGameStartField]),
						ChangeableAfterPlayByCloudMatchCreate = self.Utility_ToBool(row[pq.ChangeableAfterPlayByCloudMatchCreateField]),
						UxHint = row[pq.UxHintField],
						SortIndex = row[pq.SortIndexField],
						Criteria = parameter_criteria[row[pq.ParameterIdField]]
					};	

					local default_value = p.DefaultValue;
					if(default_value ~= nil) then
						if(p.Domain == "bool") then
							p.DefaultValue = self.Utility_ToBool(default_value);		
						elseif(p.Domain == "int" or p.Domain == "uint") then
							p.DefaultValue = tonumber(default_value);
						end
					end				

					if(self:Parameter_GetRelevant(p) and self:Parameter_MeetsCriteria(parameter_dependencies[p.ParameterId])) then			
						self:Parameter_PostProcess(p);											 
						parameters[p.ParameterId] = p;
					end
				end
			end
		end
	end

	ProfileStep("Query Parameters");


	-- Check parameter query criteria then parameter criteria.
	for pqid, pq in pairs(parameter_queries) do
		pq.MeetsCriteria = pq.Criteria == nil or self:Parameter_MeetsCriteria(pq.Criteria);
	end

	for pid, p in pairs(parameters) do
		p.MeetsCriteria = p.Query.MeetsCriteria and (p.Criteria == nil or self:Parameter_MeetsCriteria(p.Criteria));
	end
	--
	ProfileStep("Check Parameter Criteria");

	-- Populate parameter domain (as well as cross-reference default values)
	local pod_domains = {
		["bool"] = true,
		["int"] = true,
		["uint"] = true,
		["text"] = true
	};

	-- Query for Domain Ranges.
	local domain_ranges = {};
	for _, drq in ipairs(domain_range_queries) do
		local q = queries[drq.QueryId];
		if(q) then
			for i, row in ipairs(self:Data_Query(q)) do
				local dr = {
					Type = "IntRange",
					Query = drq,
					Domain = row[drq.DomainField],
					MinimumValue = tonumber(row[drq.MinimumValueField]) or 0,
					MaximumValue = tonumber(row[drq.MaximumValueField]) or 0,
				}

				if(dr.MinimumValue ~= nil and dr.MaximumValue ~= nil) then
					domain_ranges[dr.Domain] = dr;
				else
					SetupParameters_Log("Setup Parameter Error! IntRange domain lacks constraints Min: " .. tostring(dr.MinimumValue) .. " Max: " .. tostring(dr.MaximumValue));
				end
			end
		end
	end
	ProfileStep("Query Domain Ranges");

	-- Query for Domain Values.
	local union_values = {};
	for _, dvq in ipairs(domain_value_queries) do
		local q = queries[dvq.QueryId];
		if(q) then
			
			local dq = self:Data_Query(q)
			for i, row in ipairs(dq) do

				local dv = {
					QueryId = dq.Id,
					QueryIndex = i,
					Domain = row[dvq.DomainField],
					Value = row[dvq.ValueField],
					RawName  = row[dvq.NameField]  or "",
					RawDescription = row[dvq.DescriptionField] or "",
					Name = Locale.Lookup(row[dvq.NameField]  or ""),
					Icon = row[dvq.IconField],
					SortIndex = row[dvq.SortIndexField],
				};
					
				-- Add domain value.
				local values = union_values[dv.Domain];
				if(values == nil) then 
					values = {};
					union_values[dv.Domain] = values;	
				end
					 
				table.insert(values, dv);
			end
		end
	end
	ProfileStep("Query Domain Values");


	-- Populate intersect values per domain
	local intersect_values = {};
	local difference_values = {};
	for _, dvq in ipairs(domain_value_filter_queries) do
		local q = queries[dvq.QueryId];
		if(q) then
			
			for i, row in ipairs(self:Data_Query(q)) do

				local domain = row[dvq.DomainField];
				local value = row[dvq.ValueField];
				local filter = row[dvq.FilterField];

				local filter_values;
				if(filter == "intersect") then
					filter_values = intersect_values;
				elseif(filter == "difference") then
					filter_values = difference_values;
				end

				-- Add domain value.
				local values = filter_values[domain];
				if(values == nil) then 
					values = {}; 
					filter_values[domain] = values;	
				end
				 
				values[value] = true;
			end
		end
	end
	ProfileStep("Perform Domain Intersects");

	-- Populate domain unions
	local domain_unions = {};
	for _, du in ipairs(domain_union_queries) do
		local q = queries[du.QueryId];
		if(q) then		
			for i, row in ipairs(self:Data_Query(q)) do

				local domain = row[du.DomainField];
				local other_domain = row[du.OtherDomainField];

				local unions = domain_unions[domain];
				if(unions == nil) then
					unions = {};
					domain_unions[domain] = unions;
				end

				table.insert(unions, other_domain);
			end
		end
	end
	ProfileStep("Perform Domain Unions");
				
	-- Parse domains and split 
	_CacheDomainParts(domain_ranges);		-- from domain_range definitions.
	_CacheDomainParts(union_values);
	_CacheDomainParts(intersect_values);
	_CacheDomainParts(difference_values);

	local ForEachMatchedDomain = function(d, set, func)
		local parts = _SplitDomain(d);
		for domain, values in pairs(set) do
			local domainParts = _SplitDomain(domain);
			local match = true;
			for i = 1, #parts, 1 do
				local a = parts[i];
				local b = domainParts[i];
				if(a ~= "*" and b ~="*" and a ~= b) then
					match = false;
					break;
				end
			end

			if(match) then
				func(domain, values);
			end
		end
	end

	local domain_values = {};
	local _EnumerateDomainValues;
	_EnumerateDomainValues = _CacheFunction(domain_values, function(domain)
		local values = {};

		-- Populate with union'd domain values.
		local unions = domain_unions[domain];
		if(unions) then
			for _,d in ipairs(unions) do
				-- This will recursively populate values.
				local v = _EnumerateDomainValues(d);
				for i, dv in ipairs(v) do
					table.insert(values, dv);
				end
			end
		end

		-- Populate with values from this domain.
		ForEachMatchedDomain(domain, union_values, function(d, v)
			for i, dv in ipairs(v) do
				table.insert(values, dv);
			end
		end);

		-- Filter (intersection)
		ForEachMatchedDomain(domain, intersect_values, function(d, intersect)
			local new_values = {};
			for i, dv in ipairs(values) do
				if(intersect[dv.Value]) then
					table.insert(new_values, dv);
				end
			end
			
			values = new_values;
		end);

		-- Filter (difference)
		ForEachMatchedDomain(domain, difference_values, function(d, difference)
			local new_values = {};
		
			for i, dv in ipairs(values) do
				if(difference[dv.Value] == nil) then
					table.insert(new_values, dv);
				end
			end
			
			values = new_values;
		end);

		return values;
	end);
	ProfileStep("Parse Domain Values");


	local domain_overrides = {};
	for _, doq in ipairs(domain_override_queries) do
		local q = queries[doq.QueryId];
		if(q) then
			for i, row in ipairs(self:Data_Query(q)) do
				local pid = row[doq.ParameterIdField];
				local domain = row[doq.DomainField]
				if(pid and domain) then
					domain_overrides[pid] = domain;
				end
			end
		end
	end
	ProfileStep("Query Domain Overrides");
	
	local count = 0;
	for pid, p in pairs(parameters) do
		count = count + 1;
	end
	SetupParameters_Log("Parameter Count - " .. count);

	for pid, p in pairs(parameters) do
		
		-- Override, if necessary.
		p.Domain = domain_overrides[pid] or p.Domain;
		local domain = p.Domain;

		-- Is this a multi-value domain?
		if(pod_domains[domain] == nil) then

			local range = domain_ranges[domain];
			if(range) then
				if(range.Type ~= "IntRange") then
					error("Invalid domain range type.");
				end

				p.Values = range;
			else
				local values = _EnumerateDomainValues(domain);
			
				-- Sort Values.
				self.Utility_SortValues(values);	

				p.AllValues = values;
				-- Call a hook to filter possible values for the parameter.
				values = self:Parameter_FilterValues(p, values);	

				-- Assign.
				p.Values = values;
			end
		end
		
		Modding.UpdateParameter(p);
		p.Enabled = self:Parameter_GetEnabled(p);
	end

	ProfileStep("Finalize Parameters");
		
	return parameters;
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Execute a database query and return an iterator object.
-- The database query may have arguments mapped to the configuration.
-------------------------------------------------------------------------------
function SetupParameters:Data_Query(query)
	-- This is a bit of hard-coded trickery.
	-- It's to deal with how Lua handles nil values in tables..
	local args = {};

	local parameters = query.Parameters;
	if(parameters ~= nil) then
		for i = 1, 4, 1 do
			local p = parameters[i];
			if(p ~= nil) then
				if(p.ConfigurationGroup == "Player" and p.ConfigurationId == "PLAYER_ID" and self.PlayerId) then
					args[i] = self.PlayerId;
				else			
					args[i] = self:Config_Read(p.ConfigurationGroup, p.ConfigurationId);
				end
			end
		end
	end

	return CachedQuery(query.SQL, args[1], args[2], args[3], args[4]);
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Determine the civilization of a given leader and domain.
-- This is utilized by Parameter_FilterValues for preventing duplicate civs.
-- Like Parameter_FilterValues, this method should probably exist in 
-- GameSetupLogic or PlayerSetupLogic.
-------------------------------------------------------------------------------
function GetPlayerCivilization(domain, leader_type)
	if(leader_type ~= "RANDOM" and leader_type ~= "RANDOM_POOL1" and leader_type ~= "RANDOM_POOL2") then
		local info_query = "SELECT CivilizationType from Players where Domain = ? and LeaderType = ? LIMIT 1";
		local info_results = CachedQuery(info_query, domain, leader_type);
		
		if(info_results and #info_results == 1) then
			return info_results[1].CivilizationType;
		end
	end
end

-------------------------------------------------------------------------------
-- Filter possible values for a given parameter.
-- NOTE: This method probably should be migrated to GameSetupLogic or
-- PlayerSetupLogic as it's not core to SetupParameters and is more of a game 
-- detail.
-- D. / Jack The Narrator: values here are the output of an earlier query. Format is
-- .QueryIndex - Number 138
-- .Name -- String Pericles
-- .QueryId - Number 50 
-- .RawName - String LOC_LEADER_PERICLES_NAME
-- .SortIndex - Number 100
-- .RawDescription - String LOC_TRAIT_LEADER_SURROUNDED_BY_GLORY_DESCRIPTION
-- .Value - String LEADER_PERICLES
-- .Domain - String Players:Expansion2_Players
-- Additional output
-- .Invalid - Boolean true
-- .InvalidReason - String LOC_SETUP_ERROR_LEADER_NOT_OWNED
-------------------------------------------------------------------------------
function SetupParameters:Parameter_FilterValues(parameter, values)
	if(parameter.ParameterId == "PlayerLeader") then
		
	
		local unique_leaders = GameConfiguration.GetValue("NO_DUPLICATE_LEADERS");
		local unique_civilizations = GameConfiguration.GetValue("NO_DUPLICATE_CIVILIZATIONS");
		local restricted_draft = GameConfiguration.GetValue("CPL_RESTRICTED_DRAFT");
		local is_spectator = GameConfiguration.GetValue("IS_LOCAL_OBSERVER");
		local unique_bans = false
		if GameConfiguration.GetValue("CPL_BAN_FORMAT") ~= nil then
			if GameConfiguration.GetValue("CPL_BAN_FORMAT") > 0 then
				unique_bans = true
			end
		end


		local leaders_in_use;
		local leaders_in_draft;
		local civilizations_in_use;
		local leaders_in_bans;
		local random_in_ban;

		local InsertIntoDuplicateBucket = function(map, key, other_key)
			local bucketA = map[key];
			local bucketB = map[other_key];

			if(bucketA == nil and bucketB == nil) then
				bucketA = {key, other_key};
				map[key] = bucketA;
				map[other_key] = bucketA;

			elseif(bucketA == nil and bucketB ~= nil) then
				table.insert(bucketB, key);
				map[key] = bucketB;

			elseif(bucketA ~= nil and bucketB == nil) then
				table.insert(bucketA, other_key);
				map[other_key] = bucketA;
			
			elseif(bucketA ~= nil and bucketB ~= nil and bucketA ~= bucketB) then
				-- consolidate buckets
				-- if A is a dupe of B and B is a dupe of C, then A is a dupe of C.
				for i,v in ipairs(bucketB) do
					table.insert(bucketA, v);
					map[v] = bucketA;
				end

			elseif(bucketA == bucketB) then
				-- buckets are same, no need to do anything since they are already dupes of each other
			end
		end;

		local duplicate_civilizations;
		if(unique_civilizations) then
			duplicate_civilizations = {};
			for i, row in ipairs(CachedQuery("SELECT CivilizationType, OtherCivilizationType from DuplicateCivilizations where Domain = ?", parameter.Domain)) do
				InsertIntoDuplicateBucket(duplicate_civilizations, row.CivilizationType, row.OtherCivilizationType);
			end
		end

		local duplicate_leaders;
		if(unique_leaders or unique_bans) then
			duplicate_leaders = {};
			for i, row in ipairs(CachedQuery("SELECT LeaderType, OtherLeaderType from DuplicateLeaders where Domain = ?", parameter.Domain)) do
				InsertIntoDuplicateBucket(duplicate_leaders, row.LeaderType, row.OtherLeaderType);
			end
		end
		
		local banned_leaders;
		if(unique_bans) then
			banned_leaders = {};
			for i, row in ipairs(CachedQuery("SELECT LeaderType, OtherLeaderType from DuplicateLeaders where Domain = ?", parameter.Domain)) do
				InsertIntoDuplicateBucket(banned_leaders, row.LeaderType, row.OtherLeaderType);
			end
		end
		
		local drafted_leaders;
		if(restricted_draft) then
			drafted_leaders = {};
			for i, row in ipairs(CachedQuery("SELECT LeaderType, OtherLeaderType from DuplicateLeaders where Domain = ?", parameter.Domain)) do
				InsertIntoDuplicateBucket(drafted_leaders, row.LeaderType, row.OtherLeaderType);
			end
		end
		

		if(unique_civilizations or unique_leaders) then

			civilizations_in_use = {};
			leaders_in_use = {};

			local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
			for i, player_id in ipairs(player_ids) do	
				if(player_id ~= self.PlayerId) then
					local playerConfig = PlayerConfigurations[player_id];
					if(playerConfig) then
						local civilization = playerConfig:GetCivilizationTypeName();
						if(type(civilization) == "string" and playerConfig:GetLeaderTypeName() ~= "LEADER_SPECTATOR") then
							civilizations_in_use[civilization] = true;

							local dupes = duplicate_civilizations and duplicate_civilizations[civilization];
							if(dupes) then
								for i,v in ipairs(dupes) do
									civilizations_in_use[v] = true;
								end
							end 
						end

						local leader = playerConfig:GetLeaderTypeName();
						if(type(leader) == "string" and leader ~= "LEADER_SPECTATOR") then
							leaders_in_use[leader] = true;

							local dupes = duplicate_leaders and duplicate_leaders[leader];
							if(dupes) then
								for i,v in ipairs(dupes) do
									leaders_in_use[v] = true;
								end
							end 
						end
					end
				end
			end
		end
		
		if(unique_bans) then
			leaders_in_bans = {};
			for i = -1, 10 do	
				if(GameConfiguration.GetValue("BAN_"..i) ~= nil) then
					local leader = GameConfiguration.GetValue("BAN_"..i)
					if(type(leader) == "string") then
						leaders_in_bans[leader] = true;
						local dupes = banned_leaders and banned_leaders[leader];
						if(dupes) then
							for i,v in ipairs(dupes) do
								if tostring(v) == tostring(leader) then
									leaders_in_bans[v] = true;
								end	
							end
						end
					end
				end
			end	
		end
		
		if(restricted_draft) then
			SetupParameters_Log("restricted_draft ")
			leaders_in_draft = {};
			local count = nil
			local pool_size = 6
			local current_pool = 0
			math.randomseed(GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED")+Network.GetLocalPlayerID())
			count = 0
			for i,v in ipairs(values) do
				if v.Value ~= nil then
					if(type(v.Value) == "string") then
						count = count + 1
					end
				end
			end
			local size = count
			local completed = false
			for j= 1, 20 do
				local limit = 0
				local possible_leader = true
				limit = math.random(1,size)
				SetupParameters_Log(limit)
				count = 0
				local lookfwd = false
				if completed == false and  possible_leader == true then
				for i,v in ipairs(values) do
					count = count + 1 
					if ( count == limit or lookfwd == true) then
						possible_leader = true
						if v.Value == "RANDOM" or v.Value == "LEADER_SPECTATOR" then
							possible_leader = false
						end
						if (leaders_in_bans and unique_bans == true and GameConfiguration.GetValue("CPL_BAN_FORMAT") > 1) then
							if leaders_in_bans[v.Value] == true then
								possible_leader = false
							end
						end
						if (leaders_in_use and unique_leaders == true) then
							if leaders_in_use[v.Value] == true then
								possible_leader = false
							end						
						end
						if leaders_in_draft[v.Value] ~= nil then
							possible_leader = false
						end
						if possible_leader == true then
							current_pool = current_pool + 1
							if current_pool < pool_size then 
								leaders_in_draft[v.Value] = true
								lookfwd = false
								possible_leader = false
								break
								else
								lookfwd = false	
								possible_leader = false
								break		
							end
							else
							lookfwd = true
							possible_leader = true
							
						end
					end
				end
				count = 0
				for i,v in ipairs(leaders_in_draft) do 
					if leaders_in_draft[v.Value] == true then
						count = count + 1
						SetupParameters_Log(v.Value)
					end
				end
				end
				if count == 5 then
					SetupParameters_Log("Needed Iterations")
					SetupParameters_Log(j)
					completed = true
					break
				end
			end	
		end
		SetupParameters_Log("Implementing Restrictions")
		local new_values = {};
		
		local gameInProgress = GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME;
	
		local checkOwnership = true;
		if(GameConfiguration.IsAnyMultiplayer()) then
			local checkComputerSlots = Network.IsGameHost() and not gameInProgress;

			local curPlayerConfig = PlayerConfigurations[self.PlayerId];
			local curSlotStatus = curPlayerConfig:GetSlotStatus();
			local localPlayerId = Network.GetLocalPlayerID();
			checkOwnership = self.PlayerId == localPlayerId or (checkComputerSlots and curSlotStatus == SlotStatus.SS_COMPUTER);
		end

		for i,v in ipairs(values) do
			local reason;
			if(checkOwnership and not Modding.IsLeaderAllowed(self.PlayerId, v.Value)) then
				reason = "LOC_SETUP_ERROR_LEADER_NOT_OWNED";
			elseif(unique_leaders and leaders_in_use[v.Value]) then
				reason = "LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS";
			elseif( unique_bans and ( GameConfiguration.GetValue("CPL_BAN_FORMAT") > 1 and leaders_in_bans[v.Value] ) ) then
				reason = "LOC_SETUP_ERROR_NO_BANNED_LEADERS";
			elseif( unique_bans and (GameConfiguration.GetValue("CPL_BAN_FORMAT") == 1 and (v.Value == "RANDOM" or v.Value == "RANDOM_POOL1" or v.Value == "RANDOM_POOL2") ) ) then 
				reason = "LOC_SETUP_ERROR_NO_RANDOM_LEADERS";
			elseif(restricted_draft == true and (not (leaders_in_draft[v.Value] == true)) and v.Value ~= "LEADER_SPECTATOR" and v.Value ~= "RANDOM" and v.Value ~= "RANDOM_POOL2" and v.Value ~= "RANDOM_POOL1" and checkOwnership and curSlotStatus ~= SlotStatus.SS_COMPUTER and GameConfiguration.GetGameState() == -901772834 ) then
				reason = "LOC_SETUP_ERROR_NOT_DRAFTED_LEADERS";
			elseif(unique_civilizations) then
				local civilization = GetPlayerCivilization(v.Domain, v.Value);
				if(civilization and civilizations_in_use[civilization]) then
					reason = "LOC_SETUP_ERROR_NO_DUPLICATE_CIVILIZATIONS";
				end
			end

			if(reason == nil) then
				table.insert(new_values, v);
			else
				local new_value = {};

				-- Copy data from value.
				for k,v in pairs(v) do
					new_value[k] = v;
				end

				-- Mark value as invalid.
				new_value.Invalid = true;
				new_value.InvalidReason = reason;
				table.insert(new_values, new_value);
			end
		end
		if is_spectator == true then
			local tmp = {}
			tmp = { Value = "LEADER_SPECTATOR", Name = "[COLOR_GREEN]Spectator[ENDCOLOR]", RawName = "LOC_LEADER_SPECTATOR_NAME", Domain = "Players:Observer", RawDescription = "LOC_TRAIT_LEADER_SPECTATOR_DESCRIPTION", SortIndex = 999}
			table.insert(new_values, tmp);
		end
		return new_values;
	else -- Passthrough for ParameterId ~= Leader
		return values;
	end
end

-------------------------------------------------------------------------------
-- Determine if the parameter should be enabled.
-------------------------------------------------------------------------------
function SetupParameters:Parameter_GetEnabled(parameter)
	
	-- Disable if parameter does not meet criteria or is read-only.
	-- Otherwise, If a game is in session, disable unless you are host.
	-- Otherwise, enable.

	-- Disable if the parameter is Invalid but *not* if the parameter is Error.
	-- This is because an Error'd parameter may be correctable if the user selects a different value.
	-- While an invalid parameter cannot be corrected.
	if(parameter.Invalid) then
		return false;
	end
	if((not parameter.MeetsCriteria) or parameter.ReadOnly) then
		return false;
	end

	-- Check ChangeableAfterGameStart state.
	local gameState = GameConfiguration.GetGameState(); 
	if(not parameter.ChangeableAfterGameStart and gameState ~= GameStateTypes.GAMESTATE_PREGAME) then
		return false;
	end

	-- Check ChangeableAfterPlayByCloudMatchCreate state.
	if(not parameter.ChangeableAfterPlayByCloudMatchCreate 
		and GameConfiguration.IsPlayByCloud()
		and Network.IsInSession()) then
		return false;
	end

	-- Rules for once the network session has been created.
	if(Network.IsInSession()) then
		-- Some parameters can only be changed before the network session is created.
		if(parameter.ParameterId == "Ruleset"				-- Can't change because the ruleset cascades to pretty much everything.
			or parameter.ParameterId == "NoTeams"           -- Can't change because the no teams setting cascades to the player configuration team setting.
			                                                -- This should be removed once the player configuration team pulldown is handled like a proper player parameter.
			or parameter.GroupId == "GameModes" ) then      -- Can't change game modes because the lobby has the game mode specified in it.'											
			return false;
		end		

		-- Non-local player parameters can only be changed by the game host unless this is a matchmaking configuration.
		if(self.PlayerId ~= Network.GetLocalPlayerID()
			and (GameConfiguration.IsMatchMaking() or not Network.IsGameHost()) ) then
			return false;
		end
	end

	return true;
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Determine if the parameter is relevant to this instance.
-- Parameters that are not relevant are completely ignored.
-------------------------------------------------------------------------------
function SetupParameters:Parameter_GetRelevant(parameter)
	return true;
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Returns true if a parameter meets its criteria.
-------------------------------------------------------------------------------
function Exists(entry, set)
	
	if(entry == nil) then
		return false
	end

	if(type(set) ~= "string") then
		print("Invalid type for 'set', expected string.");
		return false;
	end

	--Split up set into a comma delimited list of values.
	local values;
	if(string.find(set, ",") == nil) then
		values = {set};
	else
		values = {};
		
		-- Split using pattern matching.  
		local lastPos = 1;
		local pat = "(.-),()";
		for part, pos in string.gmatch(set, pat) do
			table.insert(values, part);
			lastPos = pos;
		end

		-- Handle the last field
		table.insert(values, string.sub(set, lastPos));
    end

	-- Trim whitespace from each value.
	for i,v in ipairs(values) do
		values[i] = string.gsub(v, "^%s*(.-)%s*$", "%1");
	end

	if(#values == 0) then
		return true;
	else
		-- Trim whitespace from 'entry'
		entry = string.gsub(entry, "^%s*(.-)%s*$", "%1");

		for i,v in ipairs(values) do
			if(entry == v) then
				return true;
			end
		end

		return false;
	end
end						   
local CriteriaOperators = {
	["Equals"] = function(a,b) return a == b; end,
	["NotEquals"] = function(a,b) return a ~= b; end,
	["LessThan"] = function(a, b) return a < b; end,
	["LessThanEquals"] = function(a,b) return a <= b; end,
	["GreaterThan"] = function(a,b) return a > b; end,
	["GreaterThanEquals"] = function(a,b) return a >= b; end,
	["Exists"] = function(a,b) return Exists(a,b); end,
	["NotExists"] = function(a,b) return not Exists(a,b); end
};

function SetupParameters:Parameter_MeetsCriteria(criteria)
	if(criteria) then
		for i, v in ipairs(criteria) do
			local cmp = CriteriaOperators[v.Operator];
			if(cmp ~= nil) then
				local expected_value = v.ConfigurationValue;
				local actual_value = self:Config_Read(v.ConfigurationGroup, v.ConfigurationId);

				local t = type(actual_value);
				if(t =="boolean") then

					local a = self.Utility_ToBool(actual_value);
					local b = self.Utility_ToBool(expected_value);
					if(not cmp(a, b)) then
						return false;
					end

				elseif(t == "number") then
					-- If expected value was a string, and the config value was a number, use the hash.
					if(type(expected_value) == "string") then
						expected_value = DB.MakeHash(expected_value);					
					end

					local a = tonumber(actual_value);
					local b = tonumber(expected_value);

					if(not cmp(a,b)) then
						return false;
					end		
				else
					if(not cmp(actual_value, expected_value)) then
						return false;
					end
				end
			else
				SetupParameters_Log("Warning! Could not find criteria operator - " .. tostring(v.Operator));
			end
		end
	end

	return true;
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Perform any additional operations on the parameter after it has been 
-- created.
-------------------------------------------------------------------------------
function SetupParameters:Parameter_PostProcess(parameter)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Determine whether a parameter's auxiliary configuration values are out-of-date.
-------------------------------------------------------------------------------
function SetupParameters:Parameter_SyncAuxConfigurationValues(parameter)

	if(parameter.DomainConfigurationId) then
		local domain = self:Config_Read(parameter.ConfigurationGroup, parameter.DomainConfigurationId);
		if(domain ~= parameter.Domain) then
			return true;
		end
	end

	if(parameter.ValueDomainConfigurationId) then
		local value_domain = self:Config_Read(parameter.ConfigurationGroup, parameter.ValueDomainConfigurationId);
		
		local parameter_domain = (type(parameter.Value) == "table") and parameter.Value.Domain;
		if(parameter_domain ~= value_domain) then
			return true;
		end
	end

	if(parameter.DomainValuesConfigurationId) then
		local values;
		if(type(parameter.Values) == "table") then
				
			local scratch = {};
			for i,v in ipairs(parameter.Values) do
				if(v.Invalid ~= true) then
					table.insert(scratch, tostring(v.Domain) .. "::" .. tostring(v.Value));
				end
			end

			values = table.concat(scratch, ",");
		end
		local config_values = self:Config_Read(parameter.ConfigurationGroup, parameter.DomainValuesConfigurationId);
		if(values ~= config_values) then
			-- NOTE: This could happen if the other player has different DLC ownership rights that result in the set
			-- being smaller or larger than what we've detected.  This should not cause the parameter
			-- to be placed in an error state.
			return true;
		end
	end

	if(parameter.ValueNameConfigurationId) then
		local bundle = (parameter.Value ~= nil) and Locale.Bundle(parameter.Value.RawName);
		local config_bundle = self:Config_Read(parameter.ConfigurationGroup, parameter.ValueNameConfigurationId);
		if(bundle ~= config_bundle) then
			-- NOTE: This could happen if the other player has additional translations that others do not have.
			-- In this situation, if we must update the parameter but cannot, this should not cause the parameter
			-- to be placed in an error state.			
			return true;
		end
	end

	-- KLUDGE!  This should be in PlayerSetupLogic.lua
	-- Extend auxilery values to include CivilizationTypeName and Hash
	if(parameter.ParameterId == "PlayerLeader") then
		local civilizationType = (parameter.Value ~= nil) and GetPlayerCivilization(parameter.Value.Domain, parameter.Value.Value);
		local civilizationTypeId = (civilizationType) and DB.MakeHash(civilizationType);

		local config_civilizationType = self:Config_Read("Player", "CIVILIZATION_TYPE_NAME");
		local config_civilizationTypeId = self:Config_Read("Player", "CIVILIZATION_TYPE_ID");

		return civilizationType ~= config_civilizationType or civilizationTypeId ~= config_civilizationTypeId;
	end
end
  
-------------------------------------------------------------------------------
-- Fetches the configuration value for a parameter and attempts to assign it.
-- returns true if the value was constrained in some way and needs to be
-- rewritten.
-- This disregards the present value of the parameter.  
-------------------------------------------------------------------------------
function SetupParameters:Parameter_SyncConfigurationValues(parameter)

	local config_value = self:Config_ReadParameterValues(parameter);

	-- TODO:
	-- Presuming that whether or not we can write to the config is
	-- exposed as it's own method (e.g Config_CanWriteParameter())
	-- When a parameter value is out of sync and cannot be reconciled
	-- if we are unable to write to the config, place the parameter in an error state.
	
	-- Wipe error state.
	parameter.Error = nil;

	if(parameter.Values and parameter.Values.Type == "IntRange") then
		local minValue = parameter.Values.MinimumValue;
		local maxValue = parameter.Values.MaximumValue;

		if(config_value) then
			-- Does the current Value match config_value?
			if(parameter.Value == config_value) then
				-- Only worry about auxiliary values if we can actually write them.
				if(self:Config_CanWriteParameter(parameter)) then
					return self:Parameter_SyncAuxConfigurationValues(parameter); 
				else
					return false;
				end
			else
				-- Is the value between our minimum and maximum value?
				if(config_value >= minValue and config_value <= maxValue) then
					parameter.Value = config_value;

					-- Only worry about auxiliary values if we can actually write them.
					if(self:Config_CanWriteParameter(parameter)) then
						return self:Parameter_SyncAuxConfigurationValues(parameter); 
					else
						return false;
					end
				end
			end
		end

		if(self:Config_CanWriteParameter(parameter)) then
			-- Try default value.
			local default_value = parameter.DefaultValue;
			if(default_value) then
				if(default_value >= minValue and default_value <= maxValue) then
					parameter.Value = default_value;
					return true;
				end
			end

			parameter.Value = minValue;
			return true;
		else
			-- We're in an error state :(
			parameter.Error = {Id = "MissingDomainValue"};
			return false;
		end
	elseif(parameter.Values) then
		if(parameter.Array) then
			-- An array! Parameter can contain 0-N values from 'Values'.
			if(config_value) then
				-- Generate parameter value and mark as needed sync.
				local new_values = {};
				for i,cv in ipairs(config_value) do
					local v;
					-- Find parameter value that matches config value.					
					for _,pv in ipairs(parameter.Values) do
						if(cv == pv.Value) then
							v = pv;
							break;
						end
					end

					if(v) then
						table.insert(new_values, v);

						-- Check if this value has been marked as 'Invalid'. If so, flag the parameter as Error.
						if(v.Invalid) then
							parameter.Error = {
								Id = "InvalidDomainValue",
								Reason = v.InvalidReason
							}
						end

					else
						SetupParameters_Log("Cannot find config_value in domain - " .. parameter.ConfigurationId .. " - " .. tostring(cv));
					end
				end

				parameter.Value = new_values;
				-- Only worry about auxiliary values if we can actually write them.
				if(self:Config_CanWriteParameter(parameter)) then
					return self:Parameter_SyncAuxConfigurationValues(parameter); 
				else
					return false;
				end
			else
				-- No config value!
				-- Check Default value!
				if(parameter.DefaultValue == "*") then
					local values = {};
					for i,v in ipairs(parameter.Values) do
						values[i] = v;
					end

					parameter.Value = values;
					return true;
				else
					if(parameter.DefaultValue ~= nil) then
						SetupParameters_Log("Only '*' is supported for array parameter default values. - " .. parameter.ParameterId);
					end

					-- Wipe the parameter value.
					parameter.Value = nil;
					-- Only worry about auxiliary values if we can actually write them.
					if(self:Config_CanWriteParameter(parameter)) then
						return self:Parameter_SyncAuxConfigurationValues(parameter); 
					else
						return false;
					end
				end				
			end

		else
			-- Not an array, parameter must contain a value from 'Values'.
			if(config_value) then
				-- Does the current Value match config_value?
				if(parameter.Value and parameter.Value.Value == config_value) then
				
					if(parameter.Value.Value.Invalid) then

						parameter.Error = {
							Id = "InvalidDomainValue",
							Reason = v.InvalidReason
						}
					end
					return self:Parameter_SyncAuxConfigurationValues(parameter);

				else
					-- Does config_value exist in Values?
					for i, v in ipairs(parameter.Values) do
						if(v.Value == config_value) then
							parameter.Value = v;

							if(v.Invalid) then
								parameter.Error = {
									Id = "InvalidDomainValue",
									Reason = v.InvalidReason
								}
							end
							return self:Parameter_SyncAuxConfigurationValues(parameter);
						end
					end

					SetupParameters_Log("Cannot find config_value in domain - " .. parameter.ConfigurationId .. " - " .. tostring(config_value));
						
												
										  
									 
						 
				 
				end
			end

			if(self:Config_CanWriteParameter(parameter)) then
				-- Try default value.
				local default_value = parameter.DefaultValue;
				for i, v in ipairs(parameter.Values) do
					if(v.Value == default_value) then
						parameter.Value = v;
						return true;
					end
				end

				-- blech! get the first valid value.
				local first_value;
				for i,v in ipairs(parameter.Values) do
					if(v.Invalid ~= true) then
						first_value = v;
						break;
					end
				end

								 
										   
				if(first_value) then
					SetupParameters_Log("Defaulting to first value - " .. parameter.ConfigurationId);
					parameter.Value = first_value;
					return true;
				else
					-- We're in an error state :(
					parameter.Error = {Id = "MissingDomainValue"};
					return false;
				end
			else
				-- We're in an error state :(
				parameter.Error = {Id = "MissingDomainValue"};
				return false;
			end
	  
								
												 
				
		end
	else
		-- Start with either the configuration value or the default value.
		local old_value = config_value;
		if(old_value == nil) then
			old_value = parameter.DefaultValue;
		end
	
		-- Use the domain to cast the value to the correct type.
		local domain = parameter.Domain;
		if(domain == "bool") then	
			parameter.Value = self.Utility_ToBool(old_value);	
		elseif(domain == "int" or domain == "uint") then
			parameter.Value = tonumber(old_value);
		else
			parameter.Value = old_value;
		end

		if(parameter.Value == config_value) then
			
			-- Only worry about auxiliary values if we can actually write them.
			if(self:Config_CanWriteParameter(parameter)) then
				return self:Parameter_SyncAuxConfigurationValues(parameter); 
			else
				return false;
			end
		else
			return true;
		end
	end
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called after all UI update actions have been performed.
-------------------------------------------------------------------------------
function SetupParameters:UI_AfterRefresh()
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called after a UI group is updated.
-------------------------------------------------------------------------------
function SetupParameters:UI_AfterRefreshGroup(gid)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called before the UI has been refreshed.
-------------------------------------------------------------------------------
function SetupParameters:UI_BeforeRefresh()
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Called before a UI group is updated.
-- Note: Parameters from this group may have been destroyed prior to this 
-- getting called.
-------------------------------------------------------------------------------
function SetupParameters:UI_BeforeRefreshGroup(gid)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Calls a hook which notifies UI of the new parameter.
-- NOTE: Only the static things need to be initialized.  Other fields will
-- be updated later.
-------------------------------------------------------------------------------
function SetupParameters:UI_CreateParameter(parameter)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Calls a hook which notifies UI that a parameter no longer exists.
-------------------------------------------------------------------------------
function SetupParameters:UI_DestroyParameter(parameter)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Calls a hook which updates the value of the parameter.
-------------------------------------------------------------------------------
function SetupParameters:UI_SetParameterValue(parameter)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Calls a hook which updates whether the parameter is enabled.
-------------------------------------------------------------------------------
function SetupParameters:UI_SetParameterEnabled(parameter)
end

-------------------------------------------------------------------------------
-- Calls a hook which updates whether the parameter is visible.
-------------------------------------------------------------------------------
function SetupParameters:UI_SetParameterVisible(parameter)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Calls a hook which all possible values of a parameter.
-- This is only executed if the parameter is a multi-value parameter.
-------------------------------------------------------------------------------
function SetupParameters:UI_SetParameterPossibleValues(parameter)
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- A sort function between two parameters.
-------------------------------------------------------------------------------
function SetupParameters.Utility_SortFunction(a, b)
	if(a.SortIndex ~= b.SortIndex) then
		return (a.SortIndex or 0) < (b.SortIndex or 0);
	else
		return Locale.Compare(a.Name, b.Name) == -1;
	end
end

-------------------------------------------------------------------------------
-- Sorts a table in-place first using SortIndex then using Name.
-------------------------------------------------------------------------------
function SetupParameters.Utility_SortValues(t)
	table.sort(t, SetupParameters.Utility_SortFunction);
end
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Utility to interpret booleans differently than standard Lua.
-- Nonzero numbers are true, 0 is false.
-- "true" strings are true, any other string is false.
-------------------------------------------------------------------------------
function SetupParameters.Utility_ToBool(v)
	local t = type(v);
	if(t == "boolean") then
		return v;
	elseif(t == "number") then
		return v ~= 0;
	elseif(t == "string") then
		local n = tonumber(v);
		if(n ~= nil) then
			return n ~= 0;
		else
			return v == "true";
		end
	end

	return false;
end
-------------------------------------------------------------------------------
