local Freeway = script:FindFirstAncestor("Freeway")

local Cryo = require(Freeway.Packages.Cryo)
local InstanceWirerComponent = require(Freeway.Components.InstanceWirerComponent)
local PluginEnum = require(Freeway.Enum)
local React = require(Freeway.Packages.React)
local WireableProperties = require(Freeway.WireableProperties)
local TagUtils = require(Freeway.TagUtils)

local UIUtils = {}

function UIUtils.buildWireableModelsForListMode(instances: { Instance })
	local wireables = {}
	for _, instance in instances do
		if
			WireableProperties["image"][instance.ClassName] ~= nil
			or WireableProperties["mesh"][instance.ClassName] ~= nil
		then
			table.insert(wireables, instance)
		end
	end

	local wirersModelMeshes = UIUtils.buildWirersModel(wireables, "mesh")
	local wirersModelImages = UIUtils.buildWirersModel(wireables, "image")

	return { wirersModelMeshes, wirersModelImages }
end

function UIUtils.buildWirersModel(instances, pieceType, pieceId)
	local result = {}
	for _, instance in instances do
		local wirerModelByType = result[instance.ClassName]
		if wirerModelByType == nil then
			local properties = nil

			if WireableProperties[pieceType][instance.ClassName] ~= nil then
				for name, _ in WireableProperties[pieceType][instance.ClassName] do
					if properties == nil then
						properties = {}
					end
					table.insert(properties, name)
				end
			end
			if properties == nil then
				continue
			end -- this instance can't be wired
			wirerModelByType = {
				instances = {},
				properties = properties,
			}
			result[instance.ClassName] = wirerModelByType
		end
		table.insert(wirerModelByType.instances, instance)
	end

	for className, wirerModel in result do
		local count = #wirerModel.instances
		if count > 1 then
			wirerModel.header = count .. " " .. className .. "s"
		else
			wirerModel.header = wirerModel.instances[1].Name
		end

		-- per-property wiring state -- wired to current, not wired, etc
		local properties_wire_state = {}
		for j, instance in wirerModel.instances do
			local instanceWires = TagUtils.getInstanceWires(instance)
			for piece_id, property in instanceWires do
				local prop_wire_st = properties_wire_state[property]
				if prop_wire_st == nil then
					prop_wire_st = {}
				end
				prop_wire_st[piece_id] = true
				properties_wire_state[property] = prop_wire_st
			end
		end

		for _, property in wirerModel.properties do -- add empty for properties that are not wired
			if properties_wire_state[property] == nil then
				properties_wire_state[property] = {}
			end
		end

		wirerModel.combinedPropertyState = {}
		for property, wire_state in properties_wire_state do
			local count = TagUtils.table_size(wire_state)
			-- print('property->wireState', property, wire_state, count)

			if count == 0 then
				wirerModel.combinedPropertyState[property] = PluginEnum.WIRED_NOT
				continue
			end
			if count > 1 then
				wirerModel.combinedPropertyState[property] = PluginEnum.WIRED_MIXED
				continue
			end

			-- if only wired to one piece id:
			if pieceId ~= nil then
				if wire_state[pieceId] and #wirerModel.instances == count then
					wirerModel.combinedPropertyState[property] = PluginEnum.WIRED_ALL_CURRENT
					continue
				elseif wire_state[pieceId] then
					wirerModel.combinedPropertyState[property] = PluginEnum.WIRED_TO_CURRENT_AND_UNWIRED
					continue
				else
					wirerModel.combinedPropertyState[property] = PluginEnum.WIRED_ALL_OTHER
					wirerModel.combinedPropertyState["piece_id_" .. property] = Cryo.Dictionary.keys(wire_state)[1]
				end
			elseif count == 1 then
				wirerModel.combinedPropertyState[property] = PluginEnum.WIRED_ALL_OTHER
				wirerModel.combinedPropertyState["piece_id_" .. property] = Cryo.Dictionary.keys(wire_state)[1]
			end
		end
		-- print('!!wireState', wirerModel.combinedPropertyState)
	end
	return result
end

function UIUtils.buildInstanceWirerComponent(i, wirerModel, showSelectButton, piece, fetcher, onWire, onUnwire)
	local e = React.createElement(InstanceWirerComponent, {
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
			onWire(instances, propertyName)
			-- for _, instance in instances do
			-- 	-- print('wire instance', instance, self.props.piece.id, propertyName)
			-- 	TagUtils.wireInstance(instance, self.props.piece.id, propertyName)
			-- 	self.props.fetcher:update_instance_if_needed(instance)
			-- end
			-- ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)
		end,
		onUwireClick = function(instances, propertyName)
			-- local recordingId = ChangeHistoryService:TryBeginRecording('wire')
			onUnwire(instances, propertyName)
			-- for _, instance in instances do
			-- 	-- print('unwire all')
			-- 	TagUtils.unwireInstance(instance, propertyName)
			-- end
			-- ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)
		end,
	})

	return e
end

return UIUtils
