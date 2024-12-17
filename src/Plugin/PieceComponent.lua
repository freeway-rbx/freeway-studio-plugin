--!strict
local Packages = script:FindFirstAncestor("Freeway").Packages

local HttpService = game:GetService("HttpService")
local Cryo = require(Packages.Cryo)

local React = require(Packages.React)

local e = React.createElement

local PieceComponent = React.Component:extend("PieceComponent")
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


function PieceComponent:onClickSyncButton()
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

function PieceComponent:didMount()
	 -- add listener for tags changes
		-- if self.state.source and self.state.propertyName then
		-- 	self.state.source:GetPropertyChangedSignal(self.state.propertyName):Connect(function()
		-- 		self.state.shownImage = self.state.source[self.state.propertyName]
		-- 		self.props.onSessionDataChanged(self)
		-- 	end)
		-- end
end

function PieceComponent:willUnmount()
	--self:onClickDisconnectButton()
end

function PieceComponent:init()
end

function PieceComponent:getDerivedStateFromProps(props)
	return props
end

function PieceComponent:render_new() 
	return React.createElement("TextButton", {
		AnchorPoint = Vector2.new(0.8, 0.5),
		Position = UDim2.fromScale(0.459, 0.5),
		Size = UDim2.fromScale(1, 0.1),
		Text = "0",
	  }, {
		frame = React.createElement("Frame", {
		  AutomaticSize = Enum.AutomaticSize.XY,
		  BackgroundColor3 = Color3.fromRGB(240, 248, 51),
		  BackgroundTransparency = 0.7,
		  Size = UDim2.fromScale(0.66, 1),
		}, {
		  uIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		  }),
	  
		  imageLabel = React.createElement("ImageLabel", {
			Image = "http://www.roblox.com/asset/?id=699259085",
			LayoutOrder = 3,
			Size = UDim2.fromOffset(30, 30),
		  }),
	  
		  textLabel = React.createElement("TextLabel", {
			Active = true,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Color3.fromRGB(241, 0, 211),
			BorderSizePixel = 0,
			LayoutOrder = 4,
			Size = UDim2.fromScale(1, 0),
			Text = "Label Text asdfa sdfdsaf sad fasfasd fas sfdf asdf asd f asdfasd fasd asf ",
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		  }, {
			uIFlexItem = React.createElement("UIFlexItem", {
			  FlexMode = Enum.UIFlexMode.Shrink,
			}),
		  }),
	  
		  textLabel1 = React.createElement("TextLabel", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
			LayoutOrder = 1,
			Position = UDim2.fromScale(0, 0.457),
			Size = UDim2.fromOffset(9, 10),
			Text = "X",
			TextColor3 = Color3.fromRGB(0, 0, 0),
			TextSize = 14,
		  }),
	  
		  uIPadding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5)
		  }),
		}),
	  })
	  
end
function PieceComponent:render()
	local content = self.props.fetcher:fetch(self.props.piece)

	if self.props.piece.type ~= 'image' then content = nil end 	
	local wiredLabelTransparency = 1
	if self.props.fetcher.piece_is_wired[self.props.piece.id] then 
		wiredLabelTransparency = 0
	end 

	
	return React.createElement("TextButton", {
		AnchorPoint = Vector2.new(0.8, 0.5),
		Position = UDim2.fromScale(0.459, 0.5),
		Size = UDim2.new(1, 0, 0, 65),
		BackgroundColor3 = PluginEnum.ColorBackground,
		BackgroundTransparency=0, 
		Text="",
		[React.Event.MouseButton1Click] = function() self.props.onClick() end,
	  }, {
		frame = React.createElement("Frame", {
		  AutomaticSize = Enum.AutomaticSize.XY,
		  BackgroundColor3 = Color3.fromRGB(240, 248, 51),
		  BackgroundTransparency = 1,
		  Size = UDim2.fromScale(1, 1),
		}, {
		  uIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		  }),
	  
		  imagePreview = content ~= nil and e('ImageLabel', {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = PluginEnum.ColorBackground,
			BorderSizePixel = 0,
			ImageContent = content,
			LayoutOrder = 3,
			Size = UDim2.fromOffset(PluginEnum.PreviewSize, PluginEnum.PreviewSize),
		  }),
	  
		  pieceName = React.createElement("TextLabel", {
			Active = true,
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = 4,
			Size = UDim2.fromScale(1, 0),
			TextWrapped = true,
			Text = self.props.piece.name,
			Font = Enum.Font.BuilderSansMedium,
			TextSize = PluginEnum.FontSizeTextPrimary,
			TextColor3 = PluginEnum.ColorTextPrimary,
			BackgroundColor3 = PluginEnum.ColorBackground,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left,

		  }, {
			uIFlexItem = React.createElement("UIFlexItem", {
			  FlexMode = Enum.UIFlexMode.Shrink,
			}),
		  }),
	  
		  wireState = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0.457),
			Size = UDim2.fromOffset(9, 10),
			Text = '⚡️',
			Font = Enum.Font.BuilderSansMedium,
			TextSize = PluginEnum.FontSizeTextPrimary,
			TextColor3 = PluginEnum.ColorTextPrimary,
			BackgroundColor3 = PluginEnum.ColorBackground,
			
			BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			TextTransparency = wiredLabelTransparency

		  }),
	  
		  uiPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, PluginEnum.PaddingHorizontal),
			PaddingRight = UDim.new(0, PluginEnum.PaddingHorizontal),
			PaddingTop = UDim.new(0, PluginEnum.PaddingVertical),
			PaddingBottom = UDim.new(0, PluginEnum.PaddingVertical),
		}),
	  })
	})
	


end

return PieceComponent
