--!strict
local Freeway = script:FindFirstAncestor("Freeway")

local Selection = game:GetService("Selection")

local Cryo = require(Freeway.Packages.Cryo)
local PluginEnum = require(Freeway.Enum)
local React = require(Freeway.Packages.React)
local StudioComponents = require(Freeway.Packages.studiocomponents)
local TagUtils = require(Freeway.TagUtils)

local SceneComponent = React.Component:extend("SceneComponent")
local e = React.createElement


local AssetListEntry = require(Freeway.Components.AssetListEntry)


function SceneComponent:onClickSyncButton()
	local state = self.state
	local ok, response = pcall(function()
		-- call sync long running method and return
		return false
	end)
	-- if not ok or not response.Success then
	-- 	if typeof(response) == "table" then
	-- 		warn("Request failed:", response.StatusCode, response.StatusMessage)
	-- 	else
	-- 		warn("Request failed:", response)
	-- 	end
	-- 	return
	-- end
end

function SceneComponent:didMount() end

function SceneComponent:willUnmount()
	--self:onClickDisconnectButton()
end

function SceneComponent:init() end

function SceneComponent:getDerivedStateFromProps(props)
	return props
end




function SceneComponent:renderTree(node, i, parents, depth)
	local title = node.name

	local childPath = ""
	for _, item in parents do
		childPath = childPath .. item.name .. "/"
	end

	local localDepth = depth

	local insertObject = function()
		local camera = workspace.CurrentCamera
		-- Position 10 studs in front of camera
		local cameraPosition = camera.CFrame.Position
		local cameraLookVector = camera.CFrame.LookVector
		local partPosition = cameraPosition + (cameraLookVector * 10)

		local partsToUpdate = {}
		local part = nil

		if self.props.piece.type == "mesh" then
			if node.isMesh then
				part = self:createMeshPart(node, workspace, partsToUpdate)
				table.insert(partsToUpdate, part)
				part.Position = partPosition
				local tr =
					self.props.fetcher:mesh_translation({ id = self.props.piece.id, childId = node.id })
				if tr ~= nil then
					part.Position = part.Position + Vector3.new(tr[1], tr[2], tr[3])
				else
					print("mesh translation is nil", { id = self.props.piece.id, childId = node.id })
				end
			else
				part = Instance.new("Model")
				part.Parent = workspace
				part.Name = self.props.piece.name .. ":" .. node.name
				
				childPath = childPath .. node.name

				local anchor = Instance.new("Part")
				anchor.Parent = part
				anchor.Position = partPosition
				anchor.Size = Vector3.new(0.001, 0.001, 0.001)
				anchor.Color = Color3.fromRGB(255, 0, 0)
				anchor.Transparency = 1.0
				anchor.Anchored = true
				anchor.Name = self.props.fetcher:anchor_part_name()
				anchor.Locked = true
				anchor.CanCollide = false
				anchor.CanTouch = false

				local meshes = self.props.fetcher:meshes_list(node)
				for _, mesh in meshes do
					local meshPart = self:createMeshPart(mesh, part, partsToUpdate)

					table.insert(partsToUpdate, meshPart)
					meshPart.Position = partPosition
				end


				if localDepth ~= 0 then
					TagUtils.wireInstance(part, self.props.piece.id .. ":" .. childPath, "Model")
				else 					
					TagUtils.wireInstance(part, self.props.piece.id .. ":root" , "Model")
				end 
			end
		elseif self.props.piece.type == "image" then
			part = Instance.new("Part")
			part.Parent = workspace
			part.Size = Vector3.new(2, 2, 0.5)
			part.Name = "Part"
			part.CanCollide = true
			local decal = Instance.new("Decal")
			decal.Parent = part
			TagUtils.wireInstance(decal, self.props.piece.id, "Texture")
			table.insert(partsToUpdate, part)
			part.Position = partPosition
		end

		Selection:Set({ part })

		self.props.fetcher:update_instances_if_needed(partsToUpdate)
	end


	if node.children == nil then

		return React.createElement(AssetListEntry, {
						Icon = "rbxassetid://12376249776",
						Title = title,
						LayoutOrder = i,
						Actions = {
							{ Title = "⚡️ Insert", ButtonStyle = "Button", OnActivated = insertObject},
						},
					})
	end
	

	if depth ~= 0 then
		table.insert(parents, node)
	end

	local childrenElements = {}
	
	local counter = 0
	if depth == 0 and node.children[1].name == "root" then
		table.insert(parents, node.children[1])
		depth = depth + 1
		node = node.children[1]
	end

	if depth == 1 and node.children[1].name == "Scene" then
		table.insert(parents, node.children[1])
		depth = depth + 1
		node = node.children[1]
	end

	for i, child in node.children do
		if child == "hash" then
			continue
		end
		childrenElements['node_' .. i] = self:renderTree(child, i, parents, depth + 1)
		counter = counter + 1
	end

	
	return React.createElement(StudioComponents.Collapsible, {
		Title = title,
		IsBlockStyle = false,
		Actions  = 

			{
				e(StudioComponents.Button, {
					Text = "⚡️ Insert",
					OnActivated = insertObject,
					AutomaticSize = Enum.AutomaticSize.XY,
					LayoutOrder = 5,
				})

			},
		LayoutOrder = i
	}, childrenElements)
end




function SceneComponent:createMeshPart(node, parent, partsToUpdate)
	local part = nil
	if self.props.piece.type == "mesh" then
		part = Instance.new("MeshPart")
		part.Name = node.name
		part.Size = Vector3.new(2, 2, 2)
		part.CanCollide = true
		part.Parent = parent
		TagUtils.wireInstance(part, "" .. self.props.piece.id .. ":" .. node.id, "MeshId", true)
		local material = self.props.fetcher:get_material_channels_for_mesh(self.props.piece, node.id)
		local surfaceAppearance = nil
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
					"" .. self.props.piece.id .. ":" .. material.id .. "-" .. channel.name,
					propertyName
				)
			end
			table.insert(partsToUpdate, surfaceAppearance)
		end
	end
	return part
end

function SceneComponent:render()
	local model = {
		name = "",
		type = "scene",
		-- children = {
		-- 	{
		-- 		name = "Group1",
		-- 		type = "group",
		-- 		children = {
		-- 			{
		-- 				name = "Mesh",
		-- 				type = "mesh",
		-- 				material = "material1",
		-- 				children = {}
		-- 			}
		-- 		}
		-- 	},
		-- 	{
		-- 		name = "Mesh2",
		-- 		type = "mesh",
		-- 		material = "material1",
		-- 		children = {}
		-- 	}
		-- },
		-- materials = {
		-- 	{name = "material1", type="material"},
		-- 	{name = "material2", type="material"}
		-- }
	}
	if self.props.piece.metadata ~= nil then
		
		model = {
			name = self.props.piece.name,
			children = { self.props.piece.metadata },
		}
	end
	
	local elements = self:renderTree(model, 1, {}, 0)
	
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = self.props.index,
		BorderSizePixel = 0,
	}, {
		Cryo.Dictionary.join({
			uiListLayout = React.createElement("UIListLayout", {
				Padding = UDim.new(0, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
			}),
		}, {elements = elements}),
	})
end

return SceneComponent
