-- {'tag': 'prop'}

-- wiring persistance via tags
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local TAG_WIRED = "wired"
local TAG_PREFIX = "piece:"
local DEEP_SUFFIX = ':deep'

local TagUtils = {
    
    mutex_table = {}
}

function TagUtils.getInstanceWires(instance: Instance)
	local property_wires = getInstanceWiresInternal(instance)['obj']
    local cleaned_up = {}
    for object_id, property in property_wires do
        property = string.gsub(property, DEEP_SUFFIX, "")    
        cleaned_up[object_id] = property
    end    
    return cleaned_up
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

function TagUtils.wireInstance(instance: Instance, object_id, property: string, deep: boolean)
	local wires = TagUtils.getInstanceWires(instance)

	-- remove existing wire for property
	for w_piece_id, w_property in wires do
		if w_property == property then
			wires[w_piece_id] = nil
			break
		end
	end
	if deep then
		property = property .. DEEP_SUFFIX
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


function TagUtils.isDeepWired(instance: Instance, property: string): boolean
    local property_wires = getInstanceWiresInternal(instance)['obj']
    for _, current_property in property_wires do
        local property_replaced, count = string.gsub(current_property, DEEP_SUFFIX, "")    
        if property == property_replaced and count > 0 then
            return true
        end
    end    

    return false
end



function getInstanceWiresInternal(instance: Instance): {obj: {}, tag: string}
    if not instance:HasTag(TAG_WIRED) then 
        return {obj = {}, tag = ""} 
    end
    for _, tag in instance:GetTags() do
        local replaced, count = string.gsub(tag, TAG_PREFIX, "")
        if count < 1  then
            --print('skipping tag ' .. tag)
            continue
        end
        -- todo MI handle json parsing errors
        local property_wires = HttpService:JSONDecode(replaced) :: {}

        return {obj = property_wires, tag = tag}
    end
    return {obj = {}, tag = ""}
end


function TagUtils.setInstanceWiresRespectDeep(instance: Instance, wires: {}, respect_deep: boolean?)
    if TagUtils.mutex_table[instance] ~= nil then
        task.wait(0.01)
    end
    TagUtils.mutex_table[instance] = true



    -- cleanup tags
    local internal_wires = getInstanceWiresInternal(instance)
    local current_wires = internal_wires['obj']
    local current_tag = internal_wires['tag']
    --print('set_instance_wires_respect_deep!', wires)
    
    instance:RemoveTag(TAG_WIRED)
    if current_tag ~= nil then -- if wired
        --print('removing old tag: ' .. current_tag)
        instance:removeTag(current_tag) -- remove old wiring tag
    end

    -- re-setup tags
    local counter = 0;
    for object_id, property in wires do
        counter = counter + 1
        if respect_deep then
            for current_object_id, current_property in current_wires do
                local property_replaced, count = string.gsub(current_property, DEEP_SUFFIX, "") 
                if current_object_id == object_id and property_replaced == property then
                    if count > 0 then 
                        wires[object_id] = property .. DEEP_SUFFIX
                    end
                    break
                end
            end
        end
        
    end
    
    if counter == 0 then return
    end

    local tagsJson = TAG_PREFIX .. HttpService:JSONEncode(wires)
    instance:AddTag(tagsJson)

    instance:AddTag(TAG_WIRED)


    TagUtils.mutex_table[instance] = nil
end    

function TagUtils.setInstanceWires(instance: Instance, wires: {})
	TagUtils.setInstanceWiresRespectDeep(instance, wires, true)
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
