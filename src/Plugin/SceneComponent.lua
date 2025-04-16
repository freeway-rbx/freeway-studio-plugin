--!strict
local Packages = script:FindFirstAncestor("Freeway").Packages

local HttpService = game:GetService("HttpService")
local Cryo = require(Packages.Cryo)

local React = require(Packages.React)

local e = React.createElement

local SceneComponent = React.Component:extend("SceneComponent")
local PluginEnum = require(script.Parent.Enum)


export type Piece = {
    id: string,
    role: string, -- "asset|editable"
    type: string, --  "image|mesh|meshtexturepack|pbrpack"
	name: string,
	hash: string,
    dir: string,

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




function SceneComponent:traverseModel(node, depth, list) 
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

		}
		)
	})
	
	

	table.insert(list, e)

	if node.children == nil then return end

	for key, child in node.children do 
		if key == 'hash' then continue end
		self:traverseModel(child, depth+1, list)
	end
		
end


function SceneComponent:render()
	-- self.props.piece
	-- selg.props.meta 
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
	if self.props.meta ~= nil then
		model = {
			name = self.props.piece.name,
			children = self.props.meta
		}
	end

	local tree = {}
	self:traverseModel(model, 0, tree)

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
