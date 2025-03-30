local Freeway = script:FindFirstAncestor("Freeway")
local Packages = Freeway.Packages


local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")

local React = require(Packages.React)
local Cryo = require(Packages.Cryo)
local StudioComponents = require(Packages.studiocomponents)

local e = React.createElement

local Widget = React.Component:extend("Widget")

local PieceComponent = require(script.Parent.PieceComponent)
local PieceDetailsComponent = require(script.Parent.PieceDetailsComponent)
local PluginEnum = require(script.Parent.Enum)
local ui_commons = require(script.Parent.ui_commons)
local t_u = require(script.Parent.tags_util)
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local DEBUG_USE_EDITABLE_IMAGES = true
-- local ok, areEditableImagesEnabled = pcall(function()

-- 	-- TODO MI check if the SaveAssetAsync beta is enabled
-- 	-- Instance.new("EditableImage"):WritePixels(Vector2.zero, Vector2.one, { 0, 0, 0, 0 })
-- end)
-- if not (ok and areEditableImagesEnabled) then
-- 	DEBUG_USE_EDITABLE_IMAGES = false
-- end
local MODE_LIST = 0
local MODE_PIECE_DETAILS = 1

local updateUIStateAutomatically = true

function Widget:willUnmount()
	self.onSelectionChanged:Disconnect()
	task.cancel(self.updateThread)
end

function Widget:componentDidMount()
	self.onSelectionChanged = Selection.SelectionChanged:Connect(function()
		self:updateSelectedWirersState()
	end)

end

function Widget:updateSelectedWirersState() 
	local selection = Selection:Get()
	local result = ui_commons:buildWireableModelsForListMode(selection)
	self:setState({selectedWirersModel = result})
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


function Widget:init()
	self:setState({
		selection = Selection:Get(),
		pieces = {},
		offline = false,
		mode = MODE_LIST
	})
	self:updateSelectedWirersState()
 	self.updateThread = task.spawn(function()
 		while updateUIStateAutomatically do	

			-- fetching data, should be externalized and listen to events from object_fetcher
			local pieces = self.props.fetcher.pieces
			local pendingSaving = self.props.fetcher.pending_save

			local currentPiece = nil
			if self.state.currentPiece ~= nil 
				then 
					currentPiece = self.props.fetcher.pieces_map[self.state.currentPiece.id]
				else
			end
			

			self:setState({
				pieces = pieces, 
				pendingSaving = pendingSaving,
				currentPiece = currentPiece,
				offline = self.props.fetcher.offline
			})
			task.wait(1)
		end

    end)
	
end



function Widget:render()
	
	local theme = settings().Studio.Theme

--	if true then return self:renderPlayground() end

	local element = e('Frame', {				
		Size = UDim2.new(1, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 0, 		
		BackgroundTransparency = 1
	}, 
		{
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
				
				LayoutOrder = 0,
				[React.Event.MouseButton1Click] = function()
	
					local pieces = self.props.fetcher.pieces
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
			
			statusPanel = self:renderStatusPanel(), 

			back = self.state.mode == MODE_PIECE_DETAILS and e("TextButton", {
				Text = '< Back',
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.new(0, 0, 0, 0),
				TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.DialogButtonText),
				BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.DialogButton),
				BorderSizePixel = 0,
				Font = Enum.Font.BuilderSansBold,
				TextSize = PluginEnum.FontSizeNavigationButton,
				LayoutOrder = 2,
				[React.Event.MouseButton1Click] = function()
					local lMode = self.state.mode+1
					if lMode > MODE_PIECE_DETAILS then
						lMode = MODE_LIST
					end
					self:setState({mode = lMode})
				end
			}),
			-- scrolling content frame
			e("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(1, 0, 1, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				LayoutOrder = 3,
				ScrollingDirection = Enum.ScrollingDirection.Y,
			}, {
				uiListLayout = e("UIListLayout", {
					Padding = UDim.new(0, 4),
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					
				}),
				-- uiPadding = e("UIPadding", {
				-- 	PaddingLeft = UDim.new(0, PluginEnum.PaddingHorizontal),
				-- 	PaddingRight = UDim.new(0, PluginEnum.PaddingHorizontal),
				-- 	PaddingTop = UDim.new(0, PluginEnum.PaddingVertical),
				-- 	PaddingBottom = UDim.new(0, PluginEnum.PaddingVertical),
					
				-- }),
				content =  if self.state.mode == MODE_LIST then self:renderList() else self:renderPieceDetails(),
		
			})
		}
	)


	return element
end

function Widget:renderStatusPanel()

	local theme = settings().Studio.Theme

	return e("Frame", {
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = 1, 
		BackgroundTransparency = 1

	}, {
		uiListLayout = e("UIListLayout", {
			Padding = UDim.new(2, 2),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal
		}),
		uiPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, PluginEnum.PaddingHorizontal),
			PaddingRight = UDim.new(0, PluginEnum.PaddingHorizontal),
			PaddingTop = UDim.new(0, PluginEnum.PaddingVertical),
			PaddingBottom = UDim.new(0, PluginEnum.PaddingVertical),
			
		}), 
		-- savingLoadingDots = e(StudioComponents.LoadingDots, {
		-- 	LayoutOrder = 1,
		-- 	AutomaticSize = Enum.AutomaticSize.None,
		-- 	Size = UDim2.new(0, 5, 0, 5),
		-- }),

		offlineIndicatorLabel = self.state.offline  and e('TextLabel', {
			Size = UDim2.new(0, 20, 0, 20),
			AutomaticSize = Enum.AutomaticSize.XY,
			Text = 'Please launch Freeway desktop app',
			Font = Enum.Font.BuilderSansMedium,
			TextSize = PluginEnum.FontSizeTextPrimary,
			--TextColor3 = PluginEnum.ColorTextPrimary,
			BackgroundColor3 = PluginEnum.ColorBackground,
			TextColor3 = PluginEnum.ColorTextPrimary,
			BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2
		}), 

		
		saveIndicatorLabel = #self.props.fetcher.asset_save_queue~=0  and e('TextLabel', {
			Size = UDim2.new(0, 20, 0, 20),
			AutomaticSize = Enum.AutomaticSize.XY,
			Text = 'Saving ' .. #self.props.fetcher.asset_save_queue .. ' asset(s)',
			Font = Enum.Font.BuilderSansMedium,
			TextSize = PluginEnum.FontSizeTextPrimary,
			--TextColor3 = PluginEnum.ColorTextPrimary,
			BackgroundColor3 = PluginEnum.ColorBackground,
			TextColor3 = Color3.fromRGB(255, 208, 0),

			BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2
		}), 
		-- savingIndicatorLabel = #self.props.fetcher.add_to_asset_save_queue~=0 and e("TextLabel", {
		-- 	Text = 'Saving ' .. #self.state.pendingSaving .. ' dynamic piece(s) to Roblox',
		-- 	AutomaticSize = Enum.AutomaticSize.XY,
		-- 	Size = UDim2.new(0, 70, 0, 0),
		-- 	TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButtonText),
		-- 	BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButton),
		-- 	BorderSizePixel = 0,
		-- 	Font = Enum.Font.BuilderSansBold,
		-- 	TextSize = 20,
			
		-- 	LayoutOrder = 2
		-- }),


		savePending = #self.state.pendingSaving~=0 and e("TextButton", {
			Text = 'Save ' .. #self.state.pendingSaving .. ' dynamic piece(s) to Roblox',
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(0, 70, 0, 0),
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButtonText),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButton),
			BorderSizePixel = 0,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 20,
			
			LayoutOrder = 3,
			[React.Event.MouseButton1Click] = function()
				for _, piece in self.state.pendingSaving do
					self.props.fetcher:add_to_asset_save_queue(piece)
				end
				print('started saving')
			end
		}),

	})
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
		uiPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, PluginEnum.PaddingHorizontal),
			PaddingRight = UDim.new(0, PluginEnum.PaddingHorizontal),
			PaddingTop = UDim.new(0, PluginEnum.PaddingVertical),
			PaddingBottom = UDim.new(0, PluginEnum.PaddingVertical),
			
		}),
		pieceDetails = e(PieceDetailsComponent, {
				piece = self.state.currentPiece, 
				fetcher = self.props.fetcher
			}
		),
	})
end

function Widget:renderWirers()
	local models = self.state.selectedWirersModel
	local wirerComponents = {}
	local i = -20
	for _, model in models do
		for _, m in model do 
			wirerComponents['wirer_' .. i] = ui_commons:buildInstanceWirerComponent(i, m, false, nil, self.props.fetcher,  
			function(instances, propertyName) 

				local recordingId = ChangeHistoryService:TryBeginRecording('wire')
				local newPieceId = self.props.fetcher:createPiece(propertyName .. ".png")
				print('newPieceId', newPieceId)
				for _, instance in instances do
					t_u:wire_instance(instance, newPieceId, propertyName)
					self.props.fetcher:update_instance_if_needed(instance)
				end
				ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)

			end, 
			function(instances, propertyName) 
				print('unwire!')
			end)
		end
		i = i + 1
	end
	return wirerComponents
end



function Widget:renderList()
	-- local instanceWirers = self:renderWirers() TODO MI: disable for the initial release
	local instanceWirers = {}
	-- print('render list')
	if #self.state.selection == 0 and #self.state.pieces == 0 then
		local theme = settings().Studio.Theme

		local element = e("TextLabel", {
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = 4,
			Text = "To start iterating on meshes and images, place a bitmap file to a working folder or select and instance with an image property or a MeshPart and click ‘Wire’",
			Font = Enum.Font.BuilderSans,
			TextSize = PluginEnum.FontSizeTextPrimary,
			TextColor3 = PluginEnum.ColorTextPrimary,
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Light),
			BackgroundTransparency=1,
			BorderSizePixel = 0,
			TextWrapped=true,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		return element
	end

	local pieceComponents  = {}
	local k = t_u:table_size(instanceWirers) + 1	
	for _, piece in self.state.pieces do 
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
		pieceComponents['piece_' .. k] = newPieceComponent
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
	
	local element = e("ScrollingFrame", {
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
	return element
end
return Widget
