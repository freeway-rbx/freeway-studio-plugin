-- {'tag': 'prop'}

-- wiring persistance via tags
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local TAG_WIRED = "wired"
local TAG_PREFIX = "piece:"

local TagUtils = {}

function TagUtils.getInstanceWires(instance: Instance)
	if not instance:HasTag(TAG_WIRED) then
		return {}
	end
	for _, tag in instance:GetTags() do
		local replaced, count = string.gsub(tag, TAG_PREFIX, "")
		if count < 1 then
			--print('skipping tag ' .. tag)
			continue
		end
		-- todo MI handle json parsing errors
		local property_wires = HttpService:JSONDecode(replaced) :: {}
		return property_wires
	end
	return {}
end

function TagUtils.shouldRebuildWirersStat(selectedInstances, instance)
	local updateWirersState = false
	for _, selectedInstance in selectedInstances do
		if selectedInstance == instance then
			updateWirersState = true
			break
		end
	end
	return updateWirersState
end

function TagUtils.wireInstance(instance: Instance, object_id, property: string)
	local wires = TagUtils.getInstanceWires(instance)

	-- remove existing wire for property
	for w_piece_id, w_property in wires do
		if w_property == property then
			wires[w_piece_id] = nil
			break
		end
	end
	wires[object_id] = property
	TagUtils.setInstanceWires(instance, wires)
end

function TagUtils.unwireInstance(instance: Instance, property: string)
	local wires = TagUtils.getInstanceWires(instance)
	local resulting_wires = {}
	for piece_id, piece_property in wires do
		if piece_property == property then
			continue
		end
		resulting_wires[piece_id] = property
	end
	TagUtils.setInstanceWires(instance, resulting_wires)
end

function TagUtils.setInstanceWires(instance: Instance, wires: {})
	instance:RemoveTag(TAG_WIRED)

	for _, tag in instance:GetTags() do
		local _, count = string.gsub(tag, TAG_PREFIX, "")
		if count < 1 then
			continue
		end
		instance:RemoveTag(tag)
	end

	-- re-setup tags
	local counter = 0
	for _, _ in wires do
		counter = counter + 1
	end

	if counter == 0 then
		return
	end

	local tagsJson = TAG_PREFIX .. HttpService:JSONEncode(wires)
	instance:AddTag(tagsJson)
	instance:AddTag(TAG_WIRED)
end

function TagUtils.ts_get_all_wired_in_dm(): { [Instance]: { string: string } }
	local instance_wires = {}
	for _, inst in CollectionService:GetTagged(TAG_WIRED) do -- TODO MI: Filter invalid instance types
		instance_wires[inst] = TagUtils.getInstanceWires(inst)
	end
	return instance_wires
end

function TagUtils.isInstanceWired(instance: Instance): boolean
	return instance:HasTag(TAG_WIRED)
end

function TagUtils.tableSize(tab: { [any]: any }): number
	local count = 0
	for _, _ in tab do
		count = count + 1
	end
	return count
end

return TagUtils
