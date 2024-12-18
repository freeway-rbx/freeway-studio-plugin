local Freeway = script:FindFirstAncestor("Freeway")
local Packages = Freeway.Packages


local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")

local React = require(Packages.React)
local Cryo = require(Packages.Cryo)

local e = React.createElement

local Widget = React.Component:extend("Widget")

local PieceComponent = require(script.Parent.PieceComponent)
local PieceDetailsComponent = require(script.Parent.PieceDetailsComponent)
local PluginEnum = require(script.Parent.Enum)
--local fetcher = require(script.Parent.object_fetcher)

local DEBUG_USE_EDITABLE_IMAGES = true
local ok, areEditableImagesEnabled = pcall(function()
	Instance.new("EditableImage"):WritePixels(Vector2.zero, Vector2.one, { 0, 0, 0, 0 })
end)
if not (ok and areEditableImagesEnabled) then
	DEBUG_USE_EDITABLE_IMAGES = false
end
local MODE_LIST = 0
local MODE_PIECE_DETAILS = 1

local updateUIStateAutomatically = true

function Widget:willUnmount()
	--self.onSelectionChanged:Disconnect()
	task.cancel(self.updateThread)

end


export type Piece = {
    id: string,
    role: string, -- "asset|editable"
    type: string, --  "image|mesh|meshtexturepack|pbrpack"
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


function getPieces(fetcher): { Piece }
    -- todo MI handle errors
	return fetcher.pieces
end


function Widget:init()
	print('Widget:init') 

	-- local elements  = {}
	-- local i = 1
	-- while i < 5 do
	-- 	elements[i] = 'elememnt ' .. i
	-- 	i = i + 1
	-- end

	-- self:setState({elements = elements})



	self:setState({
		selection = Selection:Get(),
		pieces = {},
		mode = MODE_LIST
	})
 	self.updateThread = task.spawn(function()
        print("WIDGET starting polling")

 		while updateUIStateAutomatically do	
			local pieces = getPieces(self.props.fetcher)
			local currentPiece = nil
			if self.state.currentPiece ~= nil 
				then 
					currentPiece = self.props.fetcher.pieces_map[self.state.currentPiece.id]
				else
			end
			
			self:setState({
				pieces = pieces, 
				currentPiece = currentPiece

			})
			task.wait(1)
		end

    end)
	
end



function Widget:render()
	


	-- print('about to render')
	local theme = settings().Studio.Theme

--	if true then return self:renderPlayground() end


	local element = e("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(1, 0, 1, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, {
		uiListLayout = e("UIListLayout", {
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			
		}),

		fetchButton = not updateUIStateAutomatically and e("TextButton", {
			Text = 'Refresh UI',
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(0, 0, 0, 0),
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButtonText),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButton),
			BorderSizePixel = 0,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 40,
			
			LayoutOrder = 1,
			[React.Event.MouseButton1Click] = function()

				local pieces = getPieces()
				local currentPiece = nil
				if self.state.currentPiece ~= nil 
				    then 
						currentPiece = self.props.fetcher.pieces_map[self.state.currentPiece.id]
					else
				end
				
				self:setState({
					pieces = pieces, 
					currentPiece = currentPiece

				})
			end
		}),

		back = self.state.mode == MODE_PIECE_DETAILS and e("TextButton", {
			Text = '[X]',
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(0, 0, 0, 0),
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButtonText),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButton),
			BorderSizePixel = 0,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 40,
			LayoutOrder = 2,
			[React.Event.MouseButton1Click] = function()
				local lMode = self.state.mode+1
				if lMode > MODE_PIECE_DETAILS then
					lMode = MODE_LIST
				end
				self:setState({mode = lMode})
			end
		}),
		content =  if self.state.mode == MODE_LIST then self:renderList() else self:renderPieceDetails(),

	})

	return element
end


function Widget:renderPieceDetails()

	return e("Frame", {
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 3, 
		BackgroundTransparency = 1

	}, {
		uiListLayout = e("UIListLayout", {
			Padding = UDim.new(2, 2),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		pieceDetails = e(PieceDetailsComponent, {
				piece = self.state.currentPiece, 
				fetcher = self.props.fetcher
			}
		),
	})
end


function Widget:renderList()
	local instanceWirers = {}
	-- print('render list')
	if #self.state.selection == 0 and #self.state.pieces == 0 then
		print('selections are nil')
		local theme = settings().Studio.Theme

		local element = e("TextLabel", {
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = 1,
			Text = "To start iterating on meshes and images, select an instance with an image property and click ‘Wire’ or place a bitmap file to a working folder.",
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 20,
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.DialogButtonText),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Light),
			BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		return element
	end
	local pieceComponents  = {}
	local k = 1	
	for _, piece in self.state.pieces do 
		-- print('reset pieces: ', piece.id, piece.hash)
		local newPieceComponent = e(
			PieceComponent, 
			{
				piece = piece,
				index = k,
				fetcher = self.props.fetcher, 
				onClick = function()
					self:setState({
						mode = MODE_PIECE_DETAILS,
						currentPiece = piece})
				end, 
				LayoutOrder = k
			}
		)
		pieceComponents[k] = newPieceComponent
		k = k + 1
	end

	return e("Frame", {
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize=Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		LayoutOrder = 3
	}, 
		Cryo.Dictionary.join({uiListLayout = e("UIListLayout", {
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			
		})}, instanceWirers, pieceComponents)
	)
end

function Widget:renderPlayground()

	local i = 1
	local elements = {}
	for k, element in self.state.elements do
		
		local sourceText = e(
			'Frame', {				
			Size = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = i,
			}, {
				Cryo.Dictionary.join({
					uiListLayout = e("UIListLayout", {
						Padding = UDim.new(0, PluginEnum.PaddingHorizontal),
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Horizontal, 
						VerticalAlignment =  Enum.VerticalAlignment.Center
					}),
				}, {
					uiPadding = e("UIPadding", {
						PaddingLeft = UDim.new(0, PluginEnum.PaddingHorizontal),
						PaddingRight = UDim.new(0, PluginEnum.PaddingHorizontal),
						PaddingTop = UDim.new(0, PluginEnum.PaddingVertical),
						PaddingBottom = UDim.new(0, PluginEnum.PaddingVertical),
						
				}),
			
					imagePreview = e('ImageLabel', {
						
						Size = UDim2.new(0, PluginEnum.PreviewSize, 0, PluginEnum.PreviewSize),
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundColor3 = PluginEnum.ColorBackground,
						BorderSizePixel = 0,
						Image='http://www.roblox.com/asset/?id=699259085',
						LayoutOrder = 1,
					}),
					name = e('TextLabel', {
						Size = UDim2.new(0, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.XY,
						Text = element,
						Font = Enum.Font.BuilderSansMedium,
						TextSize = PluginEnum.FontSizeTextPrimary,
						TextColor3 = PluginEnum.ColorTextPrimary,
						BackgroundColor3 = PluginEnum.ColorBackground,
						BorderSizePixel = 0,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 2
					}),
					openButton = e("TextButton", {
						Text = 'Open',
						AutomaticSize = Enum.AutomaticSize.XY,
						Size = UDim2.new(0, 0, 0, 0),
						TextColor3 = PluginEnum.ColorButtonNavigationText,
						BackgroundColor3 = PluginEnum.ColorButtonNavigationBackground,
						BorderSizePixel = 0,
						Font = Enum.Font.BuilderSansBold,
						TextSize = PluginEnum.FontSizeNavigationButton,
						LayoutOrder = 3,
						[React.Event.MouseButton1Click] = function()
						end,
					})
				})
		})

		elements[i] = sourceText
		i = i +1
	end
	
	print('elements count: ' .. #elements)

	local elemen = e("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.XY,
			ScrollingDirection = Enum.ScrollingDirection.XY,
	}, {
		Cryo.Dictionary.join({
			uiListLayout = e("UIListLayout", {
				Padding = UDim.new(0, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}, elements)
	}

	)
	return elemen
end
return Widget
