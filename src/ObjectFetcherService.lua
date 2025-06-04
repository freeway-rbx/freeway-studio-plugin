local Freeway = script:FindFirstAncestor("Freeway")

local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local StudioService = game:GetService("StudioService")

local WireableProperties = require(Freeway.WireableProperties)
local base64 = require(Freeway.Packages.base64)
local TagUtils = require(Freeway.TagUtils)

local POLL_RATE_SECONDS = 3
local BASE_URL = "http://localhost:3000"

local ObjectFetcherService = {
	cache = {},
	pieces = {},
	pieces_map = {},
	object_is_wired = {},
	download_queue = {},
	asset_save_queue = {},

	pending_save = {},

	updatedAt = -3,
	relaunched = true,
	enabled = false,
	offline = false,
	updateAvailable = false, -- TODO MI Implement update checker
}

export type Piece = {
	id: string,
	role: string, -- "asset|editable"
	type: string, --  "image|mesh|meshtexturepack|pbrpack",
	name: string,
	dir: string,
	hash: string,
	uploads: {
		{
			assetId: string,
			decalId: string,
			hash: string,
			operationId: string,
		}
	},
	updatedAt: number,
	uploadedAt: number,
	deletedAt: number,
}

type PiecesSyncState = {
	updatedAt: number,
	pieces: { [string]: Piece }?,
}

type ObjectInfo = {
	id: string,
	childId: string, -- includes sub-children, e.g. material-r, or material-c
	hash: string,
	type: string, -- "image/mesh/animation",
	name: string,
}

local pieces_sync_state: PiecesSyncState = {
	updatedAt = -1, -- MI: Product opinion: update all wired instances on startup to the most recent pieces values
}

local connections: { RBXScriptConnection } = {}
table.insert(
	connections,
	CollectionService:GetInstanceAddedSignal("wired"):Connect(function(instance)
		ObjectFetcherService:update_instance_if_needed(instance)
	end)
)

table.insert(
	connections,
	CollectionService:GetInstanceRemovedSignal("wired"):Connect(function(instance)
		--ObjectFetcherService:update_instance_if_needed(instance)
		print("implement me!")
	end)
)

function ObjectFetcherService:anchor_part_name()
	return "~freeway_anchor_do_not_delete"
end

function ObjectFetcherService:find_anchor_part(instance: Instance)
	local parent = instance.Parent
	if parent == nil then
		print("###parent is nil for instance", instance.Name)
	end

	while parent ~= game do
		if not parent:IsA("Model") then
			parent = parent.Parent
			continue
		end

		local children = parent:GetChildren()
		for _, child in children do
			if child.Name == self:anchor_part_name() then
				return child
			end
		end
		parent = parent.Parent
	end
	return nil
end

local function createPieceNetwork(name, content)
	local url = BASE_URL .. "/api/pieces/"
	local data = { name = name }
	local jsonData = HttpService:JSONEncode(data)

	local res = HttpService:PostAsync(url, jsonData)

	local json = HttpService:JSONDecode(res)
	return json
end

function ObjectFetcherService:createPiece(name, content)
	local status, errOrResult = pcall(function()
		return createPieceNetwork(name, content)
	end)
	if not status then
		return nil
	else
		return errOrResult.id
	end
end

function cache_key_for_object(object: ObjectInfo)
	local key = object.id
	if object.childId ~= nil then
		key = key .. ":" .. object.childId
	end
	return key
end

function ObjectFetcherService:meshes_from_children_traverse(node, meshes)
	if node == nil then
		return
	end
	if node.isMesh then
		table.insert(meshes, node)
		return
	end
	for _, child in node.children do
		ObjectFetcherService:meshes_from_children_traverse(child, meshes)
	end
end

function ObjectFetcherService:meshes_from_children(children)
	if children == nil then
		return nil
	end

	local meshes = {}
	for _, child in children do
		ObjectFetcherService:meshes_from_children_traverse(child, meshes)
	end
	return meshes
end

function ObjectFetcherService:find_children_by_path(piece, path)
	if piece.metadata == nil then
		return nil
	end
	if piece.metadata.children == nil then
		return nil
	end

	local split = string.split(path, "/")
	local current = { piece.metadata }
	print("### find_children_by_path: split path", HttpService:JSONEncode(split))
	for _, childName in split do
		local found = false
		for _, child in current do
			if child.name == childName then
				current = child.children or {}
				found = true
				break
			end
		end
		if not found then
			return {}
		end
	end

	local meshes = ObjectFetcherService:meshes_from_children(current)
	return meshes
end

function find_child_by_id_traverse(node, child_id)
	if node == nil then
		return nil
	end

	if node.id ~= nil and node.id == child_id then
		return node
	end
	if node.children == nil then
		return nil
	end

	for _, child in node.children do
		local foundChild = find_child_by_id_traverse(child, child_id)
		if foundChild ~= nil then
			return foundChild
		end
	end

	return nil
end

-- lookup a mesh or a material by id
function ObjectFetcherService:find_child_by_id(piece, child_id)
	if child_id == nil then
		return nil
	end

	local split = string.split(child_id, "-")
	-- handle materials, TODO handle animations
	local pbr_channel = nil
	if #split > 1 then
		child_id = split[1]
		pbr_channel = split[2]
	end

	local child = find_child_by_id_traverse(piece.metadata, child_id)

	if child ~= nil and pbr_channel == nil then
		return child
	end

	-- handle materials
	if piece.metadata.materials == nil or #piece.metadata.materials == 0 then
		return nil
	end
	local result = nil
	for _, material in piece.metadata.materials do
		if material.id == child_id then
			result = material
		end
	end

	if result == nil then
		return nil
	end

	if result.channels == nil then
		return nil
	end
	-- print('ObjectFetcherService:find_child_by_id: found material with channels', result.id, child_id, pbr_channel)

	if pbr_channel == nil then
		return {
			id = result.id,
			name = result.name,
			channels = result.channels,
		}
	end

	local channel = channel_from_material(result, pbr_channel)
	if channel == nil then
		return nil
	end

	return {
		id = result.id,
		childId = pbr_channel,
		name = result.name,
		hash = channel.hash,
		uploads = channel.uploads,
		type = "image",
	}
end

function channel_from_material(material, channelName)
	if material == nil then
		return nil
	end
	if material.channels == nil then
		return nil
	end
	for _, channel in material.channels do
		if channel.name == channelName then
			return channel
		end
	end
	return nil
end

function update_object_hash(piece, object: ObjectInfo)
	local child = ObjectFetcherService:find_child_by_id(piece, object.childId)
	if child ~= nil then
		object.hash = child.hash
	end
end

function ObjectFetcherService:objectHasAsset(piece, child_id)
	local upload = get_current_asset(piece, child_id)
	return upload ~= nil
end

function is_object_info_equal(info1: ObjectInfo, info2: ObjectInfo): boolean
	return info1.id == info2.id and info1.childId == info2.childId and info1.hash == info2.hash
end

function ObjectFetcherService:add_object_to_queue(object: ObjectInfo, queue: table, queue_name: string)
	local exists = false
	for _, queued_object in queue do
		if is_object_info_equal(object, queued_object) then
			exists = true
			break
		end
	end
	if not exists then
		table.insert(queue, object)
	end
end

function ObjectFetcherService:add_to_asset_save_queue(object: ObjectInfo)
	ObjectFetcherService:add_object_to_queue(object, ObjectFetcherService.asset_save_queue, "asset_save_queue")
end

local function hasToBeAnAsset(instance, properyName)
	local propertyConfig = WireableProperties:get_image_property_configuration(instance.ClassName, properyName)
	if propertyConfig == nil then
		return false
	end
	return not propertyConfig["editableImage"] and not propertyConfig["localAsset"]
end

function ObjectFetcherService:update_instances_if_needed(instances)
	for _, instance in instances do
		ObjectFetcherService:update_instance_if_needed(instance)
	end
end

function ObjectFetcherService:update_instance_if_needed(instance: Instance)
	local wires = TagUtils.getInstanceWires(instance)
	update_wired_instances(instance, wires, false)
end

function updateAssetIdForPieceNetwork(objectInfo, assetId)
	local suffix = ""
	if objectInfo.type == "image" then
		if objectInfo.childId ~= nil then -- update gltf material channel,
			-- @Post('/:id/material/:materialId/channel/:channel/upload')
			local spit = string.split(objectInfo.childId, "-")
			if #spit < 2 then
				print(
					"ObjectFetcherService:updateAssetIdForPieceNetwork: invalid childId",
					objectInfo.id,
					objectInfo.childId
				)
				return
			end
			suffix = "/material/" .. spit[1] .. "/channel/" .. spit[2] .. "/upload"
		else
			suffix = "/uploads" -- image on the file system
		end
	elseif objectInfo.type == "mesh" then
		if objectInfo.childId == nil then
			print(
				"ObjectFetcherService:updateAssetIdForPieceNetwork: can't update mesh without childId",
				objectInfo.id,
				objectInfo.childId
			)
			return
		else
			-- @Post('/:id/mesh/:meshId/upload')
			suffix = "/mesh/" .. objectInfo.childId .. "/upload"
		end
	end

	local url = BASE_URL .. "/api/pieces/" .. objectInfo.id .. suffix
	local data = { hash = objectInfo.hash, assetId = "" .. assetId }
	local jsonData = HttpService:JSONEncode(data)
	local res = HttpService:PostAsync(url, jsonData)

	local json = HttpService:JSONDecode(res)
	return json
end

function ObjectFetcherService:updateAssetIdForPiece(pieceId, childId)
	local status, errOrResult = pcall(function()
		updateAssetIdForPieceNetwork(pieceId, childId)
	end)

	if not status then
		print("Can't update asset id for pieceId: ", pieceId, "error: ", errOrResult)
		return false
	else
		return true
	end
end

local function fetchFromNetwork(object: ObjectInfo)
	local suffix = ""

	if object.type == "image" then
		if object.childId == nil then
			suffix = "/raw" -- image on the file system
		else
			-- '/:id/material/:materialId/channel/:channel/raw
			local split = string.split(object.childId, "-")
			if #split < 2 then
				warn("[FREEWAY] - fetchFromNetwork: invalid childId for material channel:", object.id, object.childId)
				return
			end
			suffix = "/material/" .. split[1] .. "/channel/" .. split[2] .. "/raw"
		end
	elseif object.type == "mesh" then
		if object.childId == nil then
			warn("[FREEWAY] - fetchFromNetwork: empty childId for mesh, ", object.id, object.childId)
		else
			-- '/:id/mesh/:meshId/raw'
			suffix = "/mesh/" .. object.childId .. "/raw"
		end
	else
		warn("[FREEWAY] - fetchFromNetwork: unknown type:", object.type, object)
		return
	end

	local url = BASE_URL .. "/api/pieces/" .. object.id .. suffix

	local res = HttpService:GetAsync(url)
	local json = HttpService:JSONDecode(res)

	-- TODO: MI mark objects that can't be instantiated broken, ignore in the future
	if object.type == "image" then
		local width = json["width"]
		local height = json["height"]
		local b64string = json["base64"]
		local options = { Size = Vector2.new(width, height) }
		local editableImage = AssetService:CreateEditableImage(options)
		local decodedData = base64.decode(buffer.fromstring(b64string))
		editableImage:WritePixelsBuffer(Vector2.zero, editableImage.Size, decodedData)
		local content = Content.fromObject(editableImage)
		ObjectFetcherService.cache[cache_key_for_object(object)] = { object = content, hash = object.hash }
		return content
	end
	if object.type == "mesh" then
		--print("mesh: fetched mesh, about to cache", object.id, object.childId, object.hash)
		local em = RbxToEditableMesh(json.mesh)
		print("mesh: fetched mesh, caching", object.id, object.childId, object.hash)
		ObjectFetcherService.cache[cache_key_for_object(object)] = { object = em, hash = object.hash }
		ObjectFetcherService.cache[cache_key_for_object(object) .. "_tr"] = json.translation
		return
	end

	print("Object type not implemented:", object.type, object)
end

function ObjectFetcherService:mesh_translation(object: ObjectInfo)
	return ObjectFetcherService.cache[cache_key_for_object(object) .. "_tr"]
end

-- download queue handler
local downloadThread = task.spawn(function()
	while true do
		if ObjectFetcherService.enabled ~= true then
			task.wait(0.5)
			continue
		end

		if #ObjectFetcherService.download_queue > 0 then
			local object = ObjectFetcherService.download_queue[1]
			local cached = ObjectFetcherService.cache[cache_key_for_object(object)]
			local exists = ObjectFetcherService:object_exists(object)

			if exists and (cached == nil or cached.hash ~= object.hash) then
				local status, err = pcall(fetchFromNetwork, object)
				if not status then
					warn("[FREEWAY] - Can't fetch object ", object, " from the filesystem. fetchFromNetwork:", err)
				end
			end

			table.remove(ObjectFetcherService.download_queue, 1)

			-- TODO MI update all instances wired to this object
			ObjectFetcherService:update_instances_wired_to_object(object)
		else
			task.wait(0.1)
		end
	end
end)

function ObjectFetcherService:update_instances_wired_to_object(object: ObjectInfo)
	local instance_wires = TagUtils.ts_get_all_wired_in_dm()

	for instance, wires in instance_wires do
		local wired_to_object = false
		for wire, _ in wires do
			local split = string.split(wire, ":")
			local piece_id = split[1]
			local child_id = nil
			if #split > 1 then
				child_id = split[2]
			end
			local object1 = ObjectFetcherService:construct_object(piece_id, child_id)
			if object1.id == object.id and object1.childId == object.childId and object1.hash == object.hash then
				wired_to_object = true
			end
		end

		if wired_to_object then
			update_wired_instances(instance, wires, false)
		end
	end
end

function saveAsset(object, objectInfo: ObjectInfo)
	local editableObject = object.object
	-- add vertices, faces, and uvs to the mesh
	local assetType = Enum.AssetType.Mesh
	if objectInfo.type == "image" then
		assetType = Enum.AssetType.Image
		editableObject = editableObject.Object
		print("saveAsset", "Editable Image", editableObject)
	end
	local loggedInUserId = StudioService:GetUserId()
	local resultUserId = loggedInUserId
	local resultCreatorType = Enum.AssetCreatorType.User

	if game.CreatorType == Enum.CreatorType.Group then
		resultUserId = game.CreatorId
		resultCreatorType = Enum.AssetCreatorType.Group
	end

	local requestParameters = {
		CreatorId = resultUserId,
		CreatorType = resultCreatorType,
		Name = objectInfo.name,
		Description = objectInfo.name .. ", saved by Freeway",
	}

	local ok, result, idOrUploadErr = pcall(function()
		return AssetService:CreateAssetAsync(editableObject, assetType, requestParameters)
	end)

	if not ok then
		warn(`error calling CreateAssetAsync: {result}`)
		return { ok = false, assetIdOrError = idOrUploadErr, result = result }
	elseif result == Enum.CreateAssetResult.Success then
		print(`success, new asset id: {idOrUploadErr}`)

		-- TODO MI: Update asset id right away in wired instances
		local result = ObjectFetcherService:updateAssetIdForPiece(objectInfo, idOrUploadErr)

		if not result then
			print(
				`could not update the asset id for piece `,
				objectInfo.id,
				objectInfo.childId,
				"error: ",
				idOrUploadErr
			)
			return { ok = false, assetIdOrError = idOrUploadErr }
		else
			print(`updated the asset id for piece `, objectInfo.id, objectInfo.childId, "to: ", idOrUploadErr)
			return { ok = true, assetIdOrError = idOrUploadErr }
		end
	else
		warn(`upload error in CreateAssetAsync: {result}, {idOrUploadErr}`)
		return { ok = false, assetIdOrError = idOrUploadErr, result = result }
	end
end

local assetSaveThread = task.spawn(function()
	while true do
		if not ObjectFetcherService.enabled then
			task.wait(0.5)
			continue
		end
		if #ObjectFetcherService.asset_save_queue > 0 then
			-- print('saveassetsthread', 'tick')

			local objectInfo = ObjectFetcherService.asset_save_queue[1]
			-- get the most recent piece from the mapping, saving_queue might be stale
			local piece = ObjectFetcherService.pieces_map[objectInfo.id]
			update_object_hash(piece, objectInfo)
			if piece == nil or not ObjectFetcherService:object_exists(objectInfo) then
				table.remove(ObjectFetcherService.asset_save_queue, 1) -- remove piece that doesn't exist anymore from the saving queue
				continue
			end

			local cached = ObjectFetcherService.cache[cache_key_for_object(objectInfo)]
			if cached == nil or cached.hash ~= objectInfo.hash then -- new version of the asset is not cached locally
				--print('saveassetsthread: has mismatch for ', piece.id, 'cached/current: ', cached.hash, '/', piece.hash)
				-- 1. if it's already queued for download -- let's just wait
				local downloading = false
				for i, download_object in ObjectFetcherService.download_queue do
					downloading = is_object_info_equal(download_object, objectInfo)
					if downloading then
						break
					end
				end

				if downloading then
					-- print('saveassetsthread', 'waiting for ', piece.id, piece.hash, ' to download...')
					task.wait(0.2)
					continue
				else
					-- TODO MI: add to download queue?
					print(
						"saveassetsthread",
						"implement me! Piece content is not cached and is not downloading",
						objectInfo.id,
						objectInfo.childId
					)
					task.wait(0.2)
					continue
				end
			end
			if not ObjectFetcherService:objectHasAsset(piece, objectInfo.childId) then
				local result = saveAsset(cached, objectInfo)
				if result.ok then
					print("saved asset")
				else
					print("error saving asset: ", result, "removing")
				end
			else
			end
			table.remove(ObjectFetcherService.asset_save_queue, 1) -- saved asset!
		else
			task.wait(0.5)
		end
	end
end)

function updatePendingSave()
	local pending_save = {}

	for wiredObjectId in ObjectFetcherService.object_is_wired do
		local split = string.split(wiredObjectId, ":")
		local childId = nil

		if #split > 1 then
			childId = split[2]
		end
		local objectInfo = ObjectFetcherService:construct_object(split[1], childId)
		ObjectFetcherService:name_object(objectInfo)

		if objectInfo == nil then
			continue
		end
		local piece = ObjectFetcherService.pieces_map[objectInfo.id]
		if not ObjectFetcherService:objectHasAsset(piece, objectInfo.childId) then
			table.insert(pending_save, objectInfo)
		end
	end
	ObjectFetcherService.pending_save = pending_save
end

function filterUpdatedAfter(timestamp, pieces)
	local recents = {}

	if pieces == nil then
		return recents
	end
	for _, piece in pieces do
		if get_piece_update_time(piece) > timestamp then
			table.insert(recents, piece)
		end
	end
	return recents
end

function mostRecentTimestampForPieces(timestamp, pieces)
	if pieces == nil then
		return timestamp
	end

	for _, piece in pieces do
		local piece_ts = get_piece_update_time(piece)
		if piece_ts > timestamp then
			timestamp = piece_ts
		end
	end
	return timestamp
end

local fetchThread = task.spawn(function()
	while true do
		if not ObjectFetcherService.enabled then
			task.wait(0.5)
			continue
		end

		local function fetchPiecesFromNetwork()
			local res = HttpService:GetAsync(BASE_URL .. "/api/pieces")
			local json = HttpService:JSONDecode(res)
			local pieces = json :: { Piece }
			if pieces == nil then
				pieces = {}
			end
			ObjectFetcherService.offline = false
			ObjectFetcherService.pieces = pieces

			local tmp_pieces_map = {}
			local counter = 0
			for _, p in pieces do
				tmp_pieces_map[p.id] = p
				counter = counter + 1
			end
			ObjectFetcherService.pieces_map = tmp_pieces_map

			local recents = filterUpdatedAfter(ObjectFetcherService.updatedAt, pieces)

			local recent_pieces_map = {}
			for _, p in recents do
				recent_pieces_map[p.id] = p
			end

			local function process_recents(recents_map: { [string]: Piece })
				-- 1. fetch all wired instances
				local instanceWires = TagUtils.ts_get_all_wired_in_dm()
				-- 1.1 pre-fetch all wired assets
				for _, wires in instanceWires do
					for object_id, _ in wires do
						local split = string.split(object_id, ":")
						local piece_id = split[1]
						local child_id = nil
						if #split > 1 then
							child_id = split[2]
						end

						local piece = ObjectFetcherService.pieces_map[piece_id]

						if piece == nil or (child_id ~= nil and not has_child(piece, child_id)) then
							-- a piece exists in the place, but is removed from the Freeway folder
							continue
						end

						local objectInfo = ObjectFetcherService:construct_object(piece.id, child_id)
						ObjectFetcherService:fetch(objectInfo)
					end
				end

				-- 1.2 wait until all assets are downloaded
				while true do
					if #ObjectFetcherService.download_queue == 0 then
						break
					else
						task.wait(0.05)
					end
				end

				-- 2. find instances wired to the recents
				for instance, wires in instanceWires do
					for object_id, _ in wires do
						local split = string.split(object_id, ":")
						local piece_id = split[1]
						if recents_map[piece_id] ~= nil then -- wired to one of the recents
							update_wired_instances(instance, wires, false)
						end
					end
				end
			end

			process_recents(recent_pieces_map)

			local function process_pieces()
				-- 1. fetch all wired instances
				local instanceWires = TagUtils.ts_get_all_wired_in_dm()
				local object_is_wired = {}
				for _, wires in instanceWires do
					for object_id, _ in wires do
						object_is_wired[object_id] = true
					end
				end
				ObjectFetcherService.object_is_wired = object_is_wired

				-- 2. cleanup wires for missing pieces, and update all if the plugin was just relaunched
				for instance, wires in instanceWires do
					update_wired_instances(instance, wires, not ObjectFetcherService.relaunched)
				end
				ObjectFetcherService.relaunched = false

				-- 3. Update assets pending saving
				updatePendingSave()
			end
			process_pieces()

			if
				ObjectFetcherService.updatedAt ~= mostRecentTimestampForPieces(ObjectFetcherService.updatedAt, recents)
			then
				ObjectFetcherService.updatedAt = mostRecentTimestampForPieces(ObjectFetcherService.updatedAt, recents)
			end
		end

		local RunService = game:GetService("RunService")
		if not RunService:IsRunning() then
			local status, err = pcall(fetchPiecesFromNetwork)
			if not status then
				-- MI bubble the error up, display in UI
				ObjectFetcherService.offline = true
				print("Please launch Freeway app", err)
			end
			--print('tick, is running ', RunService:IsRunning(), RunService:IsRunMode()) -- TODO MI Why it doesn't detect it's running?
		end
		task.wait(POLL_RATE_SECONDS)
	end
end)

function RbxToEditableMesh(rbxMesh): EditableMesh
	local em = AssetService:CreateEditableMesh({})
	local vID, uvID, nID, fID = {}, {}, {}, {}
	local id = 0
	for _, v in rbxMesh.v do
		id = em:AddVertex(Vector3.new(v[1], v[2], v[3]))
		table.insert(vID, id)
	end

	for _, uv in rbxMesh.uv do
		id = em:AddUV(Vector2.new(uv[1], uv[2]))
		table.insert(uvID, id)
	end

	for _, vn in rbxMesh.vn do
		id = em:AddNormal(Vector3.new(vn[1], vn[2], vn[3]))
		table.insert(nID, id)
	end
	local faces = {}
	for _, face in rbxMesh.faces do
		if #face.v == 3 then
			table.insert(faces, face)
		end
		if #face.v == 4 then
			-- 1-2-3 / 1-3-4
			local face1 = { v = { face.v[1], face.v[2], face.v[3] } }
			local face2 = { v = { face.v[1], face.v[3], face.v[4] } }
			table.insert(faces, face1)
			table.insert(faces, face2)
		end
	end
	for _, face in faces do
		-- v1[/vt1][/vn1] v2[/vt2][/vn2] v3[/vt3][/vn3] ...
		if #face.v ~= 3 then
			print("not a tri-face, return")
		end
		id = em:AddTriangle(vID[face.v[1][1]], vID[face.v[2][1]], vID[face.v[3][1]])
		table.insert(fID, id)
		em:SetFaceUVs(id, { uvID[face.v[1][2]], uvID[face.v[2][2]], uvID[face.v[3][2]] })
		em:SetFaceNormals(id, { nID[face.v[1][3]], nID[face.v[2][3]], nID[face.v[3][3]] })
	end
	return em
end

function ObjectFetcherService:fetch(objectInfo: ObjectInfo)
	local obj = self.cache[cache_key_for_object(objectInfo)]

	--    print('fetch piece with id and hash: ', piece.id, piece.hash)
	if objectInfo.type == "mesh" then
		-- print('mesh: fetch: target',  objectInfo.id, objectInfo.childId, objectInfo.hash)
		if obj == nil then
			-- print('mesh: no cache for target')
		else
			-- print('mesh: fetch: cached object vs target ', objectInfo.hash == obj.hash, objectInfo.hash, obj.hash)
		end
	end
	if obj ~= nil and obj.hash == objectInfo.hash then
		if obj.type == "mesh" then
			-- print('mesh: mesh cached, returning', objectInfo.id, objectInfo.childId, objectInfo.type)
		end
		return obj.object
	end

	ObjectFetcherService:type_object(objectInfo)
	--print('mesh: add object to queue: ', objectInfo.id, objectInfo.childId, objectInfo.type)

	ObjectFetcherService:add_object_to_queue(objectInfo, ObjectFetcherService.download_queue, "download queue")

	return nil
end

function get_current_asset(piece: Piece, child_id: String)
	local uploads = piece.uploads
	local hash = piece.hash

	if child_id ~= nil then
		local child = ObjectFetcherService:find_child_by_id(piece, child_id)
		if child == nil then
			return nil
		end
		hash = child.hash
		if child.uploads ~= nil then
			uploads = child.uploads
		else
			uploads = {}
		end
	end

	if uploads == nil then
		return nil
	end

	for i, upload in uploads do
		if upload.hash == hash then
			return upload
		end
	end

	return nil
end

function ObjectFetcherService:get_material_channels_for_mesh(piece: Piece, child_id: String): { string }
	local child = ObjectFetcherService:find_child_by_id(piece, child_id)
	if child == nil then
		return nil
	end
	if child.materials == nil or #child.materials == 0 then
		return nil
	end
	local childMaterial = child.materials[1]

	if piece.metadata.materials == nil or #piece.metadata.materials == 0 then
		return nil
	end
	local result = nil
	for _, material in piece.metadata.materials do
		if material.name == childMaterial then
			result = material
		end
	end

	if result == nil then
		return nil
	end

	return {
		id = result.id,
		channels = result.channels,
	}
end

function get_current_asset_id(piece: Piece, child_id: String): string
	local upload = get_current_asset(piece, child_id)
	if upload == nil then
		return nil
	end
	return upload.assetId
end

function get_piece_update_time(piece: Piece): number
	--print('get_piece_update_time: ' .. piece.id)
	local uploadedAt = nil
	if piece.uploadedAt ~= nil then
		uploadedAt = piece.uploadedAt
	else
		uploadedAt = piece.updatedAt
	end
	--print('updatedAt: ' .. piece.updatedAt .. ', uploadedAt: ' .. uploadedAt)
	if piece.updatedAt > uploadedAt then
		return piece.updatedAt
	else
		return uploadedAt
	end
end

function get_extension(inputString)
	local lastDotIndex = inputString:find("%.[^.]*$")
	if lastDotIndex then
		return inputString:sub(lastDotIndex + 1)
	end
	return inputString
end

function has_child(piece: Piece, child_id: string): boolean
	if piece == nil then
		return false
	end
	if child_id == nil then
		return false
	end
	if piece.metadata == nil then
		return false
	end

	local child = ObjectFetcherService:find_child_by_id(piece, child_id)
	return child ~= nil
end

function ObjectFetcherService:object_exists(objectInfo: ObjectInfo)
	local piece = ObjectFetcherService.pieces_map[objectInfo.id]
	if piece == nil then
		-- print("!!!object_existst: piece not found: ", objectInfo.id)
		for key, value in ObjectFetcherService.pieces_map do
			print(key, value)
		end
		return false
	end
	if objectInfo.childId ~= nil and not has_child(piece, objectInfo.childId) then
		-- print("object_existst: doesn't have child", objectInfo.childId)
		return false
	end
	return true
end

function ObjectFetcherService:construct_object(piece_id: string, child_id: string): ObjectInfo
	local piece = ObjectFetcherService.pieces_map[piece_id]
	if piece == nil then
		return nil
	end
	local object = { id = piece.id, childId = child_id, hash = piece.hash, type = piece.type }
	local child = ObjectFetcherService:find_child_by_id(ObjectFetcherService.pieces_map[object.id], object.childId)
	if child ~= nil then
		object.hash = child.hash
	end

	ObjectFetcherService:type_object(object)

	if object.type == "mesh" and object.childId == nil then
		print("mesh: construct_object: mesh with empty childId", object.id, object.childId)
	end
	return object
end

function ObjectFetcherService:type_object(object: ObjectInfo)
	local child = ObjectFetcherService:find_child_by_id(ObjectFetcherService.pieces_map[object.id], object.childId)
	if child == nil then
		object.type = ObjectFetcherService.pieces_map[object.id].type -- use piece type as a type
		return
	end

	if child.isMesh then
		object.type = "mesh"
		return
	end

	-- if a object is a material channel
	local split = string.split(object.childId, "-")
	if #split > 1 then
		object.type = "image"
	end
end

function ObjectFetcherService:name_object(object: ObjectInfo)
	local child = ObjectFetcherService:find_child_by_id(ObjectFetcherService.pieces_map[object.id], object.childId)
	if child == nil then
		object.name = ObjectFetcherService.pieces_map[object.id].name -- use piece name as a name
		return
	end

	if child.name ~= nil then
		object.name = child.name
		return
	end

	local split = string.split(object.childId, "-")
	if #split > 1 then
		object.name = ObjectFetcherService:find_child_by_id(ObjectFetcherService.pieces_map[object.id], split[1]).name -- use child's parent name, e.g. a name of the material
		object.name = object.name .. "-" .. split[2] -- add the channel name
	end
end

function ObjectFetcherService:create_new_mesh_part(parent: Instance, node: meshNode, piece: Piece)
	local part = Instance.new("MeshPart")
	part.Name = node.name
	part.Size = Vector3.new(2, 2, 2)
	part.CanCollide = true
	part.Parent = parent
	TagUtils.wireInstance(part, "" .. piece.id .. ":" .. node.id, "MeshId")
	local material = ObjectFetcherService:get_material_channels_for_mesh(piece, node.id)
	local surfaceAppearance = nil
	print("ADDING SURFACE APPEARANCE", material ~= nil and material.channels ~= nil and #material.channels > 0)
	if material ~= nil and material.channels ~= nil and #material.channels > 0 then
		surfaceAppearance = Instance.new("SurfaceAppearance")
		surfaceAppearance.Parent = part
		surfaceAppearance.Name = "SurfaceAppearance"

		for _, channel in material.channels do
			local propertyName = "ColorMap"
			if channel.name == "n" then
				propertyName = "NormalMap"
			elseif channel.name == "m" then
				propertyName = "MetalnessMap"
			elseif channel.name == "r" then
				propertyName = "RoughnessMap"
			end

			TagUtils.wireInstance(
				surfaceAppearance,
				"" .. piece.id .. ":" .. material.id .. "-" .. channel.name,
				propertyName
			)
		end
		-- table.insert(partsToUpdate, surfaceAppearance)
	end
end

function ObjectFetcherService:reset_texture_channel(instance: Instance, propertyName: string): meshNode
	print("### resetting texture channel", instance, propertyName)
	local imagePropertyConfig = WireableProperties:get_image_property_configuration(instance.ClassName, propertyName)
	print("### image prop config", imagePropertyConfig)
	if imagePropertyConfig["editableProperty"] ~= nil then
		instance[imagePropertyConfig["editableProperty"]] = Content.none
	end
end
function ObjectFetcherService:update_material_if_needed(parent: Instance, node: meshNode, piece: Piece)
	print("## update_material_if_needed")
	local surfaceAppearance = nil
	for _, child in parent:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			surfaceAppearance = child
			break
		end
	end
	local material = ObjectFetcherService:get_material_channels_for_mesh(piece, node.id)
	if (material == nil or material.channels == nil or #material.channels == 0) and surfaceAppearance ~= nil then
		-- remove surface appearance if no material is found
		print(
			"## update_material_if_needed REMOVING SURFACE APPEARANCE",
			material == nil or material.channels == nil or #material.channels == 0
		)
		surfaceAppearance:Destroy()
		return
	end

	if material ~= nil and material.channels ~= nil and #material.channels > 0 then
		print("ADDING SURFACE APPEARANCE", material ~= nil and material.channels ~= nil and #material.channels > 0)
		if surfaceAppearance == nil then
			-- create a new surface appearance if it doesn't exist
			surfaceAppearance = Instance.new("SurfaceAppearance")
			surfaceAppearance.Parent = parent
			surfaceAppearance.Name = "SurfaceAppearance"
		end
		surfaceAppearance.Parent = parent
		local properties = { ColorMap = false, NormalMap = false, MetalnessMap = false, RoughnessMap = false }
		for _, channel in material.channels do
			local propertyName = "ColorMap"
			if channel.name == "n" then
				propertyName = "NormalMap"
			elseif channel.name == "m" then
				propertyName = "MetalnessMap"
			elseif channel.name == "r" then
				propertyName = "RoughnessMap"
			end
			properties[propertyName] = true
			TagUtils.wireInstance(
				surfaceAppearance,
				"" .. piece.id .. ":" .. material.id .. "-" .. channel.name,
				propertyName
			)
		end
		for channelName, state in properties do
			if not state then
				-- reset the channel if it is not in the material
				ObjectFetcherService:reset_texture_channel(surfaceAppearance, channelName)
			end
		end
	end
end

function update_wired_instances(instance: Instance, wires: {}, cleanup_only: boolean): number
	local needsTagsUpdate = false

	for object_id, propertyName in wires do
		local split = string.split(object_id, ":")
		local piece_id = split[1]
		local child_id = nil
		local pbr = nil
		if #split > 1 then
			child_id = split[2]
		end

		-- 1. check if the piece (and it's child) still exists and was recently updated
		local piece = ObjectFetcherService.pieces_map[piece_id]

		local missingChild = true
		if propertyName ~= "Model" then
			missingChild = not ObjectFetcherService:object_exists({ id = piece_id, childId = child_id })
		else
			if piece == nil then
				print("###Model is wired to a piece that does not exist: " .. piece_id .. ", " .. child_id)
				TagUtils.unwireInstance(instance, propertyName)
				continue
			end
			-- for gltf sub-hierarchies, e.g. scenes or collections, first add/remove mesh parts, add/remove surface appearances
			-- TODO MI check if the instance is a model
			local meshes = ObjectFetcherService:find_children_by_path(piece, child_id)

			local mesh_map, mesh_part_state = {}, {}
			for _, mesh in meshes do
				mesh_map[mesh.id] = mesh
				mesh_part_state[mesh.id] = false
			end

			local removed, inserted = 0, 0

			for _, descendant in instance:GetDescendants() do
				if not TagUtils.isInstanceWired(descendant) then
					continue
				end
				local wires = TagUtils.getInstanceWires(descendant)
				if not descendant:IsA("MeshPart") then
					continue
				end
				for object_id, propertyName in wires do
					if propertyName ~= "MeshId" then
						continue
					end

					local split = string.split(object_id, ":")
					local piece_id = split[1]
					local child_id = nil
					if #split > 1 then
						child_id = split[2]
					end
					if piece_id ~= piece.id then
						continue
					end
					mesh_part_state[child_id] = true

					if mesh_map[child_id] == nil then
						print(
							"## update_wired_instances: removing mesh part",
							descendant,
							"for piece",
							piece_id,
							"child",
							child_id
						)
						descendant:Destroy()
						removed = removed + 1
					else
						print("## update_material_if_needed")
						ObjectFetcherService:update_material_if_needed(descendant, mesh_map[child_id], piece)
					end
				end
			end
			for mesh_id, mesh_part_exists in mesh_part_state do
				if not mesh_part_exists then
					-- insert new mesh part with material
					ObjectFetcherService:create_new_mesh_part(instance, mesh_map[mesh_id], piece)
					inserted = inserted + 1
				end
			end

			if removed ~= 0 or inserted ~= 0 then
				print("###updated the model, inserted: ", inserted, "removed: ", removed)
			end

			continue
		end
		--        print('11update_wired_instances: ', piece_id, child_id, 'missingChild:', missingChild, piece == nil)
		if piece == nil or missingChild then
			print("remove a wire with non-existent object_id: " .. object_id, "cleanup only", cleanup_only)
			print("TODO Implement the resetting of the Editable/Local asset")
			wires[object_id] = nil -- remove wire for missing piece
			needsTagsUpdate = true
			continue
		end
		if cleanup_only then
			continue
		end

		local object = ObjectFetcherService:construct_object(piece_id, child_id)
		ObjectFetcherService:name_object(object)

		-- 2. Update wired instance according to the piece type
		-- 2.1 images. Based on 3 possible image content types set either Roblox asset Id, or local asset id, or editable image
		if object.type == "image" then
			local imagePropertyConfig =
				WireableProperties:get_image_property_configuration(instance.ClassName, propertyName)
			local hasAsset = ObjectFetcherService:objectHasAsset(piece, child_id)
			-- print(instance.ClassName, propertyName, hasAsset, get_current_asset_id(piece, child_id))
			if hasAsset then
				local assetId = get_current_asset_id(piece, child_id)
				local assetUrl = "rbxassetid://" .. assetId
				instance[propertyName] = assetUrl
				continue
			end

			-- if the property only supports Roblox cloud assets, kick off a saving task and update image property in the next cycle
			-- example: SurfaceAppearance roughness/metalness/normal map
			if hasToBeAnAsset(instance, propertyName) then
				--                print('update_wired_instances: add to asset save queue', object.id, object.childId, object.hash, debug.traceback())
				local cached = ObjectFetcherService.cache[cache_key_for_object(object)]
				if cached == nil then
					ObjectFetcherService:add_object_to_queue(
						object,
						ObjectFetcherService.download_queue,
						"download queue"
					)
				end
				ObjectFetcherService:add_to_asset_save_queue(object)
				continue
			end

			if imagePropertyConfig["editableImage"] then -- try editable image first, default to local asset otherwise
				-- TODO MI take object hash into account!
				local ei = ObjectFetcherService:fetch(object)
				if ei == nil then
					print("cant fetch image to set Content for ", piece.id, child_id)
					continue
				end
				print("about to apply EditableImage")
				instance[imagePropertyConfig["editableProperty"]] = ei
			elseif imagePropertyConfig["localAsset"] then
				local extension = "png"
				-- local status, parsed_extension = pcall(function() return get_extension(piece.name) end)
				-- if status then
				--     extension = parsed_extension
				-- end
				local assetUrl = "rbxasset://freeway/" .. piece.id .. "-" .. piece.hash .. "." .. extension
				instance[propertyName] = assetUrl
			end
		elseif object.type == "mesh" then -- if a gltf file
			-- print('mesh:about to apply mesh 1')

			local hasAsset = ObjectFetcherService:objectHasAsset(piece, child_id)
			local child = ObjectFetcherService:find_child_by_id(piece, child_id)

			if not child.isMesh then -- material image channel, handle in the image piece above?
				print("mesh: material image channels are not implemented yet!", child.isMesh, child)
				continue
			end
			local newMeshPart
			-- print('mesh: about to apply mesh2')
			if not hasAsset then
				local em = ObjectFetcherService:fetch(object)
				if em == nil then
					print("mesh: waiting for a cached mesh", object.id, object.childId, object.hash)
					continue
				end
				-- print('mesh: about to apply mesh as Editable', object.id, object.childId, object.hash)

				newMeshPart = AssetService:CreateMeshPartAsync(Content.fromObject(em))
			else
				-- print('mesh: about to apply mesh as Asset', object.id, object.childId, object.hash)
				local assetId = get_current_asset_id(piece, child_id)
				local assetUrl = "rbxassetid://" .. assetId
				newMeshPart = AssetService:CreateMeshPartAsync(Content.fromUri(assetUrl))
			end
			instance.Size = newMeshPart.MeshSize
			instance:ApplyMesh(newMeshPart)
			local anchor = ObjectFetcherService:find_anchor_part(instance)
			if anchor ~= nil then
				local tr = ObjectFetcherService:mesh_translation(object)
				instance.Position = anchor.Position + Vector3.new(tr[1], tr[2], tr[3])
			end
		else
			print("! Unsupported Piece type: " .. piece.type)
		end
	end
	-- 4. persist current wiring config to tags
	if needsTagsUpdate then
		print("tags need an update!")
		TagUtils.setInstanceWires(instance, wires)
	end

	return maxTimestamp
end

function ObjectFetcherService:meshes_list(node)
	local meshes = {}
	meshes_list_traverse(node, meshes)
	return meshes
end

function meshes_list_traverse(node, meshes)
	if node.isMesh then
		table.insert(meshes, node)
		return
	end

	if node.children == nil or #node.children == 0 then
		return nil
	end

	for _, child in node.children do
		meshes_list_traverse(child, meshes)
	end
end

function ObjectFetcherService:setEnabled(enabled: boolean)
	self.enabled = enabled
end

function ObjectFetcherService:stop()
	task.cancel(downloadThread)
	task.cancel(fetchThread)
	task.cancel(assetSaveThread)

	for _, item in connections do
		item:Disconnect()
	end
end

return ObjectFetcherService
