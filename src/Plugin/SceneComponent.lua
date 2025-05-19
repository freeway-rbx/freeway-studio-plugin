--!strict
local Packages = script:FindFirstAncestor("Freeway").Packages

local HttpService = game:GetService("HttpService")
local Cryo = require(Packages.Cryo)

local React = require(Packages.React)

local e = React.createElement

local SceneComponent = React.Component:extend("SceneComponent")
local PluginEnum = require(script.Parent.Enum)
local StudioComponents = require(Packages.studiocomponents)
local t_u = require(script.Parent.tags_util)
local Selection = game:GetService("Selection")




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

function SceneComponent:didMount()
end

function SceneComponent:willUnmount()
	--self:onClickDisconnectButton()
end

function SceneComponent:init()
end

function SceneComponent:getDerivedStateFromProps(props)
	return props
end




function SceneComponent:traverseModel(node, depth, list, parents) 
	local i = 0
	local offset = ""
	while i < depth do
		offset = "     " .. offset
		i = i + 1
	end

	local displayName = node.name

	local font = Enum.Font.BuilderSans
	if depth == 0 then font = Enum.Font.BuilderSansBold end


	local e = e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = #list + 3 

	}, {
		Cryo.Dictionary.join({
			uiListLayout = e("UIListLayout", {
				Padding = UDim.new(0, 0),
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.None

			})
		}, {
			offset = e('TextLabel', {
				Size = UDim2.new(0, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = offset,
				Font = font,
				TextSize = PluginEnum.FontSizeTextPrimary,
				TextColor3 = PluginEnum.ColorTextPrimary,
				BackgroundColor3 = PluginEnum.ColorBackground,
				BorderSizePixel = 0,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1
			}),

			treeNodeElement = e('TextLabel', {
				Size = UDim2.new(0, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = displayName,
				Font = font,
				TextSize = PluginEnum.FontSizeTextPrimary,
				TextColor3 = PluginEnum.ColorTextPrimary,
				BackgroundColor3 = PluginEnum.ColorBackground,
				BorderSizePixel = 0,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2
			}), 
			insertAndWire =  (node.isMesh or node.name =='Scene' or node.name == 'root') and e(StudioComponents.Button, {
				LayoutOrder = 5,
				Text = "Insert",
				Size = UDim2.new(0, 30, 0, 30),
				AutomaticSize = Enum.AutomaticSize.X,
				OnActivated =  function() 



					local camera = workspace.CurrentCamera
					-- Position 10 studs in front of camera
					local cameraPosition = camera.CFrame.Position
					local cameraLookVector = camera.CFrame.LookVector
					local partPosition = cameraPosition + (cameraLookVector * 10)

					
					local partsToUpdate = {}
					local part = nil
					
					if self.props.piece.type == 'mesh' then

						if node.isMesh then
							part = self:createMeshPart(node, workspace, partsToUpdate)
							table.insert(partsToUpdate, part)
							part.Position = partPosition
							local tr = self.props.fetcher:mesh_translation({id = self.props.piece.id, childId = node.id})
							if tr ~= nil then
								part.Position = part.Position + Vector3.new(tr[1], tr[2], tr[3])
							else 
								print('mesh translation is nil', {id = self.props.piece.id, childId = node.id})
							end

						else
							part = Instance.new("Model")
							part.Parent = workspace
							part.Name = self.props.piece.name .. ":" .. node.name 
							local childPath = ""
							for _, item in parents do
								print("list: ",  item.name .. "/")
							end
							childPath = childPath .. node.name

							t_u:wire_instance(part, self.props.piece.id .. ":" .. childPath, "Model")

							local anchor = Instance.new("Part")
							anchor.Parent = part
							anchor.Position = partPosition
							anchor.Size = Vector3.new(0.1, 0.1, 0.1)
							anchor.Color = Color3.fromRGB(255, 0, 0)
							anchor.Transparency = 0.5
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
						end
					elseif self.props.piece.type == 'image' then
						part = Instance.new("Part")
						part.Parent = workspace
						part.Size = Vector3.new(2, 2, 0.5)
						part.Name = "Part"
						part.CanCollide = true
						local decal = Instance.new("Decal")
						decal.Parent = part
						t_u:wire_instance(decal, self.props.piece.id, "Texture")
						table.insert(partsToUpdate, part)
						part.Position = partPosition

					end
	
					Selection:Set({part})

					self.props.fetcher:update_instances_if_needed(partsToUpdate)
				end
			  })
		}
		)
	})
	
	

	table.insert(list, e)

	if node.children == nil then return end
	table.insert(parents, node)
	for key, child in node.children do 
		if key == 'hash' then continue end
		self:traverseModel(child, depth+1, list, parents)
	end
		
end

function SceneComponent:createMeshPart(node, parent, partsToUpdate)
	local part = nil
	if self.props.piece.type == 'mesh' then
		part = Instance.new("MeshPart")
		part.Name = node.name
		part.Size = Vector3.new(2, 2, 2)
		part.CanCollide = true
		part.Parent = parent
		t_u:wire_instance(part, "" .. self.props.piece.id .. ":" .. node.id, "MeshId")
		local material = self.props.fetcher:get_material_channels_for_mesh(self.props.piece, node.id)
		local surfaceAppearance = nil;
		print("ADDING SURFACE APPEARANCE", material ~= nil and material.channels ~= nil and #material.channels > 0)
		if material ~= nil and material.channels ~= nil and #material.channels > 0 then
			
			surfaceAppearance = Instance.new("SurfaceAppearance")
			surfaceAppearance.Parent = part
			surfaceAppearance.Name = "SurfaceAppearance"


			for _, channel in material.channels do
				local propertyName = "ColorMap"
				if channel.name == 'n' then
					propertyName = "NormalMap"
				elseif channel.name == 'm' then
					propertyName = "MetalnessMap"
				elseif channel.name == 'r' then
					propertyName = "RoughnessMap"
				end

				t_u:wire_instance(surfaceAppearance, "" .. self.props.piece.id .. ":" .. material.id .. "-" .. channel.name, propertyName)
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
			children = {self.props.piece.metadata}
		}
	end 


	local tree, parents = {}, {}
	self:traverseModel(model, 0, tree, parents)

	local nodesMap = {}
	for i, node in tree do
		nodesMap["treeNode" .. i] = node
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = self.props.index, 
	}, {
		Cryo.Dictionary.join({
			uiListLayout = e("UIListLayout", {
				Padding = UDim.new(0, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalFlex = Enum.UIFlexAlignment.Fill

			})
		}, nodesMap
		)
	})

end

return SceneComponent
