
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local Packages = script:FindFirstAncestor("Freeway").Packages
local CollectionService = game:GetService("CollectionService")
local StudioService = game:GetService("StudioService")

local t_u = require(script.Parent.tags_util)
local base64 = require(Packages.base64)
local WireableProperties = require(script.Parent.WireableProperties)

local POLL_RATE = 3 -- seconds

local BASE_URL = 'http://localhost:3000'




local object_fetcher = {
    cache = {},
    pieces = {}, 
    pieces_map = {}, 
    piece_is_wired = {},
    download_queue = {}, 
    asset_save_queue = {},
    pending_save = {},
    updatedAt = -3,
    relaunched = true,
    enabled = false, 
    offline = false,
    updateAvailable = false -- TODO MI Implement update checker
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
            operationId: string
        }
    },
    updatedAt: number,
    uploadedAt: number, 
    deletedAt: number
}

type PiecesSyncState = {
    updatedAt: number,
    pieces: {[string]: Piece}
}


local pieces_sync_state : PiecesSyncState = {
    updatedAt = -1, -- MI: Product opinion: update all wired instances on startup to the most recent pieces values
}



CollectionService:GetInstanceAddedSignal('wired'):Connect(function(instance)
    print('object_fetcher:GetInstanceAddedSignal:AddedTag')
     object_fetcher:update_instance_if_needed(instance)
end)

CollectionService:GetInstanceRemovedSignal('wired'):Connect(function(instance)
     --object_fetcher:update_instance_if_needed(instance)
     print('implement me!')
end)

local function createPieceNetwork(name, content) 
    
    local url = BASE_URL .. '/api/pieces/'
    local data = {name=name}
    local jsonData = HttpService:JSONEncode(data)
    
    local res = HttpService:PostAsync(url, jsonData)

    local json = HttpService:JSONDecode(res)
    return json
end


function object_fetcher:createPiece(name, content)

    local status, errOrResult = pcall(function () 
        return createPieceNetwork(name, content) 
    end)
    if not status then
        return nil
    else 
        return errOrResult.id
    end
end

function object_fetcher:pieceHasAsset(piece)
	local hasAsset = false
	for i, upload in piece.uploads do
		if upload.hash == piece.hash then
			hasAsset = true
			break
		end
	end
	return hasAsset
end

function object_fetcher:add_to_asset_save_queue(piece)
    local exists = false
    for i, queued_piece in object_fetcher.asset_save_queue do
        if piece.id == queued_piece.id and piece.hash == queued_piece.hash then
            print('add_to_asset_save_queue: already in the queue: ', piece.id, ' / ', piece.hash)
            exists = true
            break
        end
    end
    if not exists then
        print('add_to_asset_save_queue: adding: ', piece.id, ' / ', piece.hash)
        table.insert(object_fetcher.asset_save_queue, piece)
    end
end

local function hasToBeAnAsset(instance, properyName) 
    local propertyConfig = WireableProperties:get_image_property_configuration(instance.ClassName, properyName)
    if propertyConfig == nil then return false end
    return not propertyConfig['editableImage'] and not propertyConfig['localAsset']
end

function object_fetcher:update_instance_if_needed(instance) 
    local wires = t_u:get_instance_wires(instance)
    update_wired_instances(instance, wires, false)
end 

local function updateAssetIdForPieceNetwork(pieceId, hash, assetId) 
    local url = BASE_URL .. '/api/pieces/' .. pieceId .. '/uploads'
    local data = {hash=hash, assetId= "" .. assetId}
    local jsonData = HttpService:JSONEncode(data)
    local res = HttpService:PostAsync(url, jsonData)
    
    local json = HttpService:JSONDecode(res)
    return json
end

function object_fetcher:updateAssetIdForPiece(pieceId, hash, assetId)
    local status, errOrResult = pcall(function() 
        updateAssetIdForPieceNetwork(pieceId, hash, assetId)
    end)
        
    if not status then
        print("Can't update asset id for pieceId: ", pieceId, "error: ", errOrResult)
        return false
    else 
        return true
    end
end

local function fetchFromNetwork(piece)
    local url = BASE_URL .. '/api/pieces/' .. piece.id .. '/raw'
    print('fetchFromNetwork URL: ' .. url)
    local res = HttpService:GetAsync(url)
    local json = HttpService:JSONDecode(res)

    
    -- TODO: MI mark pieces that can't be instantiated a broken, ignore in the future
    if piece.type == 'image' then
        local width = json['width']
        local height = json['height']
        local b64string = json['base64']
        local options = { Size = Vector2.new(width, height) }
        local editableImage = AssetService:CreateEditableImage(options)
        local decodedData = base64.decode(buffer.fromstring(b64string))
        editableImage:WritePixelsBuffer(Vector2.zero, editableImage.Size, decodedData)
        local content = Content.fromObject(editableImage)
        object_fetcher.cache[piece.id] = {object = content, hash = piece.hash}
        return content
    end
    if piece.type == 'mesh' then
        local b64string = json['base64']
        local decodedData = base64.decode(buffer.fromstring(b64string))
        local meshString = buffer.tostring(decodedData)
        local mesh = HttpService:JSONDecode(meshString)
        local em = RbxToEditableMesh(mesh)
        object_fetcher.cache[piece.id] = {object = em, hash = piece.hash}
        print('cached a mesh')
        return
    end

    print('!piece type not implemented:', piece.type)
end 

-- download queue handler

local downloadThread = task.spawn(function ()
    while true do
        if object_fetcher.enabled ~= true then 
            task.wait(0.5) 
            continue 
        end 
        if #object_fetcher.download_queue > 0 then  
            local piece = object_fetcher.download_queue[1]
            local cached =  object_fetcher.cache[piece.id]
            local exists = object_fetcher.pieces_map[piece.id] ~= nil

            if exists and (cached == nil or cached.hash ~= piece.hash) then 
                local status, err = pcall(fetchFromNetwork, piece)    
                if not status then
                    print('Can\'t fetch piece ', piece.id, ' from the filesystem. fetchFromNetwork:', err)
                end 
            else 
--                print('skipping download, have cached version ')
            end

            table.remove(object_fetcher.download_queue, 1)
        else 
            task.wait(0.1)
        end
    end 
end)


function saveAsset(object, piece) 
    local AssetService = game:GetService("AssetService")

    local editableObject = object.object
    -- add vertices, faces, and uvs to the mesh
    local assetType = Enum.AssetType.Mesh
    if piece.type == 'image' then 
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
        Name = piece.name,
        Description = piece.name .. ", saved by Freeway",
    }

    local ok, result, idOrUploadErr = pcall(function()
        return AssetService:CreateAssetAsync(editableObject, assetType, requestParameters)
    end)

    if not ok then
        warn(`error calling CreateAssetAsync: {result}`)
        return {ok=false, assetIdOrError = idOrUploadErr, result = result}
    elseif result == Enum.CreateAssetResult.Success then
        print(`success, new asset id: {idOrUploadErr}`)

        -- TODO MI: Update asset id right away in wired instances
        local result = object_fetcher:updateAssetIdForPiece(piece.id, piece.hash, idOrUploadErr)

        if not result then
            print(`could not update the asset id for piece `, piece.id)
            return {ok=true, assetIdOrError = idOrUploadErr}
        else 
            print(`updated the asset id for piece `, piece.id)	
            return {ok=true, assetIdOrError = idOrUploadErr}
        end
    else
        warn(`upload error in CreateAssetAsync: {result}, {idOrUploadErr}`)
        return {ok=false, assetIdOrError = idOrUploadErr, result=result}
    end

end



local assetSaveThread = task.spawn(function()
    while true do
        if not object_fetcher.enabled then 
                task.wait(0.5) 
                continue 
        end 
        if #object_fetcher.asset_save_queue > 0 then
            -- print('saveassetsthread', 'tick')

            local piece = object_fetcher.asset_save_queue[1] 
            -- get the most recent piece from the mapping, saving_queue might be stale
            piece = object_fetcher.pieces_map[piece.id]
            if piece == nil then 
                table.remove(object_fetcher.asset_save_queue, 1) -- remove piece that doesn't exist anymore from the saving queue
                continue
            end

            local cached =  object_fetcher.cache[piece.id]
            if cached.hash ~= piece.hash then -- new version of the asset is not cached locally
                --print('saveassetsthread: has mismatch for ', piece.id, 'cached/current: ', cached.hash, '/', piece.hash)
                -- 1. if it's already queued for download -- let's just wait
                local downloading = false
                for i, download_piece in object_fetcher.download_queue do
                    downloading = download_piece.id == piece.id and download_piece.hash == piece.hash
                    if downloading then break end
                end
                
                if downloading then 
                    -- print('saveassetsthread', 'waiting for ', piece.id, piece.hash, ' to download...') 
                    task.wait(0.2)
                    continue 
                else 
                    -- TODO MI: add to download queue? 
                    print('saveassetsthread', 'implement me! Piece content is not cached and is not downloading') 
                    task.wait(0.2)
                    continue 
                end
            end
            if not object_fetcher:pieceHasAsset(piece) then
                local result = saveAsset(cached, piece)
                if result.ok then
                    print('saved asset')                    
                else
                    print('error saving asset: ', result, 'removing')
                end
            else 
            end
            table.remove(object_fetcher.asset_save_queue, 1) -- saved asset!   
        else
            task.wait(0.5) 
        end
    end
end)


function add_to_pending_save_if_needed(piece, instance, propertyName)
    if not object_fetcher:pieceHasAsset(piece) and not hasToBeAnAsset(instance, propertyName) then
        -- check if already in the pendind save and if not insert
    end
end
function updatePendingSave() 
    local pending_save = {}

    for wiredPieceId in object_fetcher.piece_is_wired do
        local p = object_fetcher.pieces_map[wiredPieceId]; 
        if p == nil then continue end
        if not object_fetcher:pieceHasAsset(p) then
            table.insert(pending_save, p) 
        end
    end    
    object_fetcher.pending_save = pending_save

end


function filterUpdatedAfter(timestamp, pieces) 
    local recents = {}

    if pieces == nil then return recents end
    for _, piece in pieces do
        if get_piece_update_time(piece) > timestamp then
            table.insert(recents, piece)
        end
    end
    return recents 
end

function mostRecentTimestampForPieces(timestamp, pieces)
    if pieces == nil then return timestamp end

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
        if not object_fetcher.enabled then 
                task.wait(0.5) 
                continue 
        end 

        local function fetchPiecesFromNetwork() 
            local res = HttpService:GetAsync(BASE_URL .. '/api/pieces')
            local json = HttpService:JSONDecode(res)
            local pieces = json :: { Piece }
            if pieces == nil then pieces = {} end
            object_fetcher.offline = false
            object_fetcher.pieces = pieces

            local tmp_pieces_map = {}
            for _, p in pieces do
                tmp_pieces_map[p.id] = p
            end
            object_fetcher.pieces_map = tmp_pieces_map
            
            local recents = filterUpdatedAfter(object_fetcher.updatedAt, pieces)

            local recent_pieces_map = {}
            for _, p in recents do
                recent_pieces_map[p.id] = p
            end


            
            local function process_recents(recents_map: { [string]: Piece })
                -- 1. fetch all wired instances
                local instanceWires = t_u.ts_get_all_wired_in_dm()
                -- 1.1 pre-fetch all wired assets
                for _, wires in instanceWires do 
                    for piece_id, _ in wires do
                        local piece_to_fetch = object_fetcher.pieces_map[piece_id]
                        if(piece_to_fetch == nil) then
                            -- a piece exists in the place, but is removed from the Freeway folder
                            continue;
                        end
                        object_fetcher:fetch(piece_to_fetch)
                    end
                end
                
                -- 1.2 wait until all assets are downloaded
                while true do
                    if #object_fetcher.download_queue == 0 then
                        break
                    else
                        task.wait(0.1)
                    end 
                end

                -- 2. find instances wired to the recents                 
                for instance, wires in instanceWires do
                    for piece_id, _ in wires do
                        if recents_map[piece_id] ~= nil then -- wired to one of the recents
                            update_wired_instances(instance, wires, false)
                        end
                    end 
                end    
            end

            
            process_recents(recent_pieces_map)
            
            local function process_pieces()
                -- 1. fetch all wired instances
                local instanceWires = t_u.ts_get_all_wired_in_dm()
                local piece_is_wired = {}
                for _, wires in instanceWires do
                    for piece_id, _ in wires do
                        piece_is_wired[piece_id] = true
                    end 
                end
                object_fetcher.piece_is_wired = piece_is_wired
                
                -- 2. cleanup wires for missing pieces, and update all if the plugin was just relaunched
                for instance, wires in instanceWires do
                    update_wired_instances(instance, wires, not object_fetcher.relaunched)
                end
                object_fetcher.relaunched = false
                
                -- 3. Update assets pending saving
                updatePendingSave()
            end
            process_pieces()

            if object_fetcher.updatedAt ~= mostRecentTimestampForPieces(object_fetcher.updatedAt, recents) then
                print("updating timestamp: from: ", object_fetcher.updatedAt, 'to:', mostRecentTimestampForPieces(object_fetcher.updatedAt, recents))
                object_fetcher.updatedAt = mostRecentTimestampForPieces(object_fetcher.updatedAt, recents)
            end
        end

        local RunService = game:GetService("RunService")
        if not RunService:IsRunning() then 
            local status, err = pcall(fetchPiecesFromNetwork)    
            if not status then
                -- MI bubble the error up, display in UI
                object_fetcher.offline = true
                print('Please launch Freeway app', err)
            end
            --print('tick, is running ', RunService:IsRunning(), RunService:IsRunMode()) -- TODO MI Why it doesn't detect it's running?
        end
        task.wait(POLL_RATE)
    
    end

end)


function RbxToEditableMesh(rbxMesh):EditableMesh 
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
            local face1 = {v = {face.v[1], face.v[2], face.v[3]}}
            local face2 = {v = {face.v[1], face.v[3], face.v[4]}}
            table.insert(faces, face1)
            table.insert(faces, face2)
        end
    end
	for _, face in faces do
		-- v1[/vt1][/vn1] v2[/vt2][/vn2] v3[/vt3][/vn3] ...
		if #face.v ~= 3 then print('not a tri-face, return') end		
		id = em:AddTriangle(vID[face.v[1][1]], vID[face.v[2][1]], vID[face.v[3][1]])
		table.insert(fID, id)
		em:SetFaceUVs(id, {uvID[face.v[1][2]], uvID[face.v[2][2]], uvID[face.v[3][2]]})
		em:SetFaceNormals(id, {nID[face.v[1][3]], nID[face.v[2][3]],nID[face.v[3][3]]})
	end
	return em
end

function object_fetcher:fetch(piece)
    local obj = self.cache[piece.id]
    
--    print('fetch piece with id and hash: ', piece.id, piece.hash)

    if obj ~= nil and obj.hash == piece.hash then 
        --print('returning cached version')
        return obj.object 
    end

    -- print('add piece to queue: ', piece.id)
    table.insert(self.download_queue, piece)
    return nil


end

function get_current_asset_id(piece: Piece): string
    for _, upload in piece.uploads do
        if piece.hash ~= upload.hash then continue end
        return upload.assetId
    end
    return nil
end

function get_piece_update_time(piece: Piece): number 
    --print('get_piece_update_time: ' .. piece.id)
    local uploadedAt = nil 
    if (piece.uploadedAt ~= nil) then uploadedAt = piece.uploadedAt else uploadedAt = piece.updatedAt end
    --print('updatedAt: ' .. piece.updatedAt .. ', uploadedAt: ' .. uploadedAt)
    if(piece.updatedAt > uploadedAt) 
        then return piece.updatedAt
        else return uploadedAt
    end

end


function get_extension(inputString)
    local lastDotIndex = inputString:find("%.[^.]*$")
    if lastDotIndex then
        return inputString:sub(lastDotIndex + 1)
    end
    return inputString
end

function update_wired_instances(instance: Instance, wires: {}, cleanup_only: boolean): number
    local needsTagsUpdate = false

    for piece_id, propertyName in wires do 
        -- 1. check if the piece still exists and was recently updated
        local piece = object_fetcher.pieces_map[piece_id]
        if piece == nil then
            print('remove a wire with non-existent piece_id: ' .. piece_id, 'cleanup only', cleanup_only)
            print('TODO Implement the resetting of the Editable/Local asset')
            wires[piece_id] = nil -- remove wire for missing piece
            needsTagsUpdate = true
            continue
        end
        if cleanup_only then continue end

        -- 2. Update wired instance according to the piece type
        -- 2.1 images. Based on 3 possible image content types set either Roblox asset Id, or local asset id, or editable image
        if piece.type == 'image' then
            local imagePropertyConfig = WireableProperties:get_image_property_configuration(instance.ClassName, propertyName)
            local hasAsset = object_fetcher:pieceHasAsset(piece)
            print(instance.ClassName, propertyName, hasAsset, get_current_asset_id(piece))
            if hasAsset then
                local assetId = get_current_asset_id(piece)
                local assetUrl = 'rbxassetid://' .. assetId
                instance[propertyName] = assetUrl
                continue
            end

            -- if the property only supports Roblox cloud assets, kick off a saving task and update image property in the next cycle
            -- example: SurfaceAppearance roughness/metalness/normal map
            if hasToBeAnAsset(instance, propertyName) then
                object_fetcher:add_to_asset_save_queue(piece)
                continue
            end 


            if imagePropertyConfig['editableImage'] then -- try editable image first, default to local asset otherwise
                print('set editable image..')
                local ei = object_fetcher:fetch(piece)
                if ei == nil then
                    print('cant fetch image to set Content for ', piece.id)
                    continue
                end
                print('about to apply EditableImage')
                instance[imagePropertyConfig['editableProperty']] = ei
            elseif imagePropertyConfig['localAsset'] then
                print('set local asset..')
                local extension = 'png'
                -- local status, parsed_extension = pcall(function() return get_extension(piece.name) end)
                -- if status then 
                --     extension = parsed_extension
                -- end
                local assetUrl = 'rbxasset://freeway/' .. piece.id .. '-' .. piece.hash .. '.' .. extension
                instance[propertyName] = assetUrl
            end

        elseif piece.type == 'mesh' then
            local hasAsset = object_fetcher:pieceHasAsset(piece)
            local newMeshPart
            if not hasAsset then
                local em = object_fetcher:fetch(piece)
                if em == nil then
                    print('cant fetch mesh to set', piece.id)
                    continue
                end
                print('about to apply mesh')

                newMeshPart = AssetService:CreateMeshPartAsync(Content.fromObject(em))
            else
                local assetId = get_current_asset_id(piece)
                local assetUrl = 'rbxassetid://' .. assetId
                newMeshPart = AssetService:CreateMeshPartAsync(Content.fromUri(assetUrl))
            end
            instance.Size = newMeshPart.MeshSize
            instance:ApplyMesh(newMeshPart)

        else
            print('! Unsupported Piece type: ' .. piece.type)
        end
    end
    -- 4. persist current wiring config to tags
    if needsTagsUpdate then 
        print('tags need update!')
        t_u:set_instance_wires(instance, wires) 
    end

    return maxTimestamp
end


-- function object_fetcher:pause()
--     task.pause(downloadThread)
--     task.pause(fetchThread)
-- end

-- function object_fetcher:pause()
--     task.re(downloadThread)
--     task.pause(fetchThread)
-- end

function object_fetcher:setEnabled(enabled)
    print("object_fetcher:setEnabled: ", enabled)
    self.enabled = enabled
end

function object_fetcher:stop()
    task.cancel(downloadThread)
    task.cancel(fetchThread)
    task.cancel(assetSaveThread)

end



return object_fetcher