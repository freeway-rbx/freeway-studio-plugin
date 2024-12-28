local Freeway = script:FindFirstAncestor("Freeway")
local Packages = Freeway.Packages

local React = require(Packages.React)
local e = React.createElement

local Cryo = require(Packages.Cryo)


local WireableProperties = require(script.Parent.WireableProperties)
local InstanceWirerComponent = require(script.Parent.InstanceWirerComponent)
local PluginEnum = require(script.Parent.Enum)
local t_u = require(script.Parent.tags_util)


local ui_commons = {}


function ui_commons:buildWireableModelsForListMode(instances)
	local wireables = {}
	for _, instance in instances do
		if WireableProperties['texture'][instance.ClassName] ~= nil or 
		WireableProperties['mesh'][instance.ClassName] ~= nil then
			table.insert(wireables, instance)
		end
	end	

	local wirersModelMeshes = self:buildWirersModel(wireables, 'mesh')
	local wirersModelImages = self:buildWirersModel(wireables, 'image')
	return {wirersModelMeshes, wirersModelImages}
end


function ui_commons:buildWirersModel(instances, pieceType, pieceId) 
    local result = {}
	for _, instance in instances do
		local wirerModelByType = result[instance.ClassName]
		if wirerModelByType == nil then 
			local properties = nil
			if (pieceType == 'image') then
				properties = WireableProperties['texture'][instance.ClassName]
			elseif (pieceType == 'mesh') then 
				properties = WireableProperties['mesh'][instance.ClassName]
			end

			--if properties == nil then properties = {} end
			if properties == nil then continue end -- this instance can't be wired
			wirerModelByType = {
				instances = {},
				properties = properties
			} 
			result[instance.ClassName] = wirerModelByType
		end
		table.insert(wirerModelByType.instances, instance)
	end


	for className, wirerModel in result do
		local count = #wirerModel.instances
		if count > 1 
			then wirerModel.header = count .. ' ' .. className  .. 's' 
			else wirerModel.header = wirerModel.instances[1].Name
		end


		-- per-property wiring state -- wired to current, not wired, etc
		local properties_wire_state = {}
		for j, instance in wirerModel.instances do
			local instanceWires = t_u:get_instance_wires(instance)
			for piece_id, property in instanceWires do
				local prop_wire_st = properties_wire_state[property]
				if prop_wire_st == nil then prop_wire_st = {} end
				prop_wire_st[piece_id] = true
				properties_wire_state[property] = prop_wire_st
			end
		end

		for _, property in wirerModel.properties do -- add empty for properties that are not wired
			
			if properties_wire_state[property] == nil then properties_wire_state[property]  = {} end
		end

		wirerModel.combinedPropertyState = {}
		for property, wire_state in properties_wire_state do
			local count = t_u:table_size(wire_state)
			-- print('property->wireState', property, wire_state, count)
			
			if count == 0 then wirerModel.combinedPropertyState[property] = PluginEnum.WIRED_NOT continue  end
			if count > 1 then wirerModel.combinedPropertyState[property] = PluginEnum.WIRED_MIXED continue end
			
			-- if only wired to one piece id: 
			if pieceId ~= nil then
				if wire_state[pieceId] and #wirerModel.instances == count then 
					wirerModel.combinedPropertyState[property] = PluginEnum.WIRED_ALL_CURRENT continue
				elseif wire_state[pieceId] then 
					wirerModel.combinedPropertyState[property] = PluginEnum.WIRED_TO_CURRENT_AND_UNWIRED continue	
				else 
					wirerModel.combinedPropertyState[property] = PluginEnum.WIRED_ALL_OTHER 
					wirerModel.combinedPropertyState['piece_id_' .. property] = Cryo.Dictionary.keys(wire_state)[1]
				end 
			elseif count == 1 then
				wirerModel.combinedPropertyState[property] = PluginEnum.WIRED_ALL_OTHER 
				wirerModel.combinedPropertyState['piece_id_' .. property] = Cryo.Dictionary.keys(wire_state)[1]
			end
		end	
		-- print('!!wireState', wirerModel.combinedPropertyState)
	end
	return result
end


function ui_commons:buildInstanceWirerComponent(i, wirerModel, showSelectButton, piece, fetcher)
	local e =  e(
		InstanceWirerComponent, 
		{
			index = i,
			instances = wirerModel.instances, 
			properties = wirerModel.properties,
			header = wirerModel.header,
			fetcher = fetcher,
			piece = piece,
			showSelectButton = showSelectButton,
			combinedPropertyState = wirerModel.combinedPropertyState,

			onClick = function(instances, propertyName)
				-- local recordingId = ChangeHistoryService:TryBeginRecording('wire')
				-- for _, instance in instances do
				-- 	-- print('wire instance', instance, self.props.piece.id, propertyName)
				-- 	t_u:wire_instance(instance, self.props.piece.id, propertyName)
				-- 	self.props.fetcher:update_instance_if_needed(instance)
				-- end
				-- ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)
			end, 
			onUwireClick = function(instances, propertyName) 
				-- local recordingId = ChangeHistoryService:TryBeginRecording('wire')

				-- for _, instance in instances do
				-- 	-- print('unwire all')
				-- 	t_u:unwire_instance(instance, propertyName)
				-- end
				-- ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)

			end
		})

	return e
end

return ui_commons
