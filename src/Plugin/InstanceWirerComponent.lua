local ContentProvider = game:GetService("ContentProvider")
local Freeway = script:FindFirstAncestor("Freeway")
local Packages = Freeway.Packages
local StudioComponents = require(Packages.studiocomponents)

local Cryo = require(Packages.Cryo)

local React = require(Packages.React)
local Selection = game:GetService("Selection")

local e = React.createElement

local InstanceWirerComponent = React.Component:extend("InstanceWirerComponent")
local PluginEnum = require(script.Parent.Enum)


type StateData = {
	source: Instance?,
	propertyName: string,
	imageType: string,
	shownImage: string,
	productInfo: { Name: string, Creator: { Name: string } },
	hasPolling: boolean,
	isPolling: boolean,
	sessionData: SessionData,
}

type SessionData = {
	sessionId: string,
	lastUpdated: string,
	asset: string?,
	outAsset: string?,
}

-- -- functional components definition
-- local function newInstanceWirerComponent(props)
	
-- 	local state = self:setState(props)

--     local text = React.createElement("TextButton", {
--         Text = string.format("Clicked %d times", count)
--         -- Clicking the button updates the count, which re-renders the component
--         [React.Event.Activated] = function()
--             setCount(count + 1)
--         end
--     })
-- 	-- text:setTe
-- end

-- local function Component()
-- 	local selection, setSelection = React.useState(Selection:Get())

-- 	React.useEffect(function()
-- 		local onSelectionChanged = Selection.SelectionChanged:Connect(function()
-- 			print('selection changed')
-- 			setSelection(Selection:Get())
-- 		end)

-- 		print("mounted")

-- 		return function()
-- 			onSelectionChanged:Disconnect()
-- 			print("unmounted")
-- 		end
-- 	end, {}) -- {} means no dependencies
-- end

-- local function Text(props: {
-- 	text: string
-- })
-- 	return React.createElement("TextLabel", {
-- 		Text = props.text,
-- 	})
-- end

-- local function Button(props: {
-- 	onClick: () -> (),
-- })
-- 	return React.createElement("TextButton", {
-- 		[React.Event.Activated] = props.onClick,
-- 	})
-- end



function InstanceWirerComponent:onClickSyncButton()

end

function InstanceWirerComponent:didMount()
end

function InstanceWirerComponent:willUnmount()
	--self:onClickDisconnectButton()
end



function InstanceWirerComponent:init()
end

function InstanceWirerComponent.getDerivedStateFromProps(props)
	return props
end

function InstanceWirerComponent:render()
	local properties =  {}
	for i, _ in self.props.properties do
		local p = self:renderPropertyWires(i)
		properties['property_' .. i] = p;
	end
	
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = self.props.index
		
	}, {
		Cryo.Dictionary.join({
				uiListLayout = e("UIListLayout", {
					Padding = UDim.new(0, PluginEnum.PaddingVertical),
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
					
				}),
			}, {header0 = self:renderHeaderAndLink(0)}, properties) 
	})
end

function InstanceWirerComponent:renderPropertyWires(i)

	local property_wiring_state = self.props.combinedPropertyState[self.props.properties[i]]
	local show_unwire = property_wiring_state ~= PluginEnum.WIRED_NOT
	local show_wire = property_wiring_state ~= PluginEnum.WIRED_ALL_CURRENT
	local wireLabel = 'Wire'
	local unwireLabel = 'Unwire'
	-- property preview
	local content = nil -- todo MI: put placeholder
	if property_wiring_state == PluginEnum.WIRED_ALL_CURRENT then 
		if self.props.piece ~= nil then 
			content = self.props.fetcher:fetch(self.props.piece)
		end	
	end

	if property_wiring_state == PluginEnum.WIRED_ALL_OTHER then 
		local piece_id = self.props.combinedPropertyState['piece_id_' .. self.props.properties[i]]
		content = self.props.fetcher:fetch(self.props.fetcher.pieces_map[piece_id])
	end
	
	if self.props.piece ~= nil and self.props.piece.type ~= 'image' then content = nil end
	

	if  #self.props.instances > 1  then 
		wireLabel = 'Wire All' unwireLabel = 'Unwire All'
	end
	
	local isWiredToCurrent = property_wiring_state == PluginEnum.WIRED_ALL_CURRENT
	local wiredTransparency = 1
	if property_wiring_state == PluginEnum.WIRED_ALL_CURRENT then
		wiredTransparency = 0
	end

	
	
	return e('Frame', {				
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = self.props.index + 1, 		
		BackgroundTransparency = 1
		},
		{
			Cryo.Dictionary.join({
				uiListLayout = e("UIListLayout", {
					Padding = UDim.new(0, PluginEnum.PaddingHorizontal),
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal, 
					VerticalAlignment =  Enum.VerticalAlignment.Center,
					--HorizontalFlex = Enum.UIFlexAlignment.Fill
				}),
			}, {
				uiPadding = e("UIPadding", {
					PaddingTop = UDim.new(0, PluginEnum.PaddingVertical),
					PaddingBottom = UDim.new(0, PluginEnum.PaddingVertical),
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
					LayoutOrder = 0,
					TextTransparency = wiredTransparency
		
				  }),
				imagePreview = content == nil and e('ImageLabel', {
					
					Size = UDim2.new(0, PluginEnum.PreviewSize, 0, PluginEnum.PreviewSize),
					AutomaticSize = Enum.AutomaticSize.None,
					BorderSizePixel = 0,
					Image = 'http://www.roblox.com/asset/?id=699259085',
					
					LayoutOrder = 1
				}),
				imageLivePreview = content ~= nil and e('ImageLabel', {
					
					Size = UDim2.new(0, PluginEnum.PreviewSize, 0, PluginEnum.PreviewSize),
					AutomaticSize = Enum.AutomaticSize.None,
					BorderSizePixel = 0,
					ImageContent = content,
					
					LayoutOrder = 1
				}),
				name = e(StudioComponents.Label, {
					Size = UDim2.new(0, 70, 0, 0),
					Text = self.props.properties[i],
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 2,
				}),
				-- name = e('TextLabel', {
				-- 	Size = UDim2.new(0, 0, 0, 0),
				-- 	AutomaticSize = Enum.AutomaticSize.X,
				-- 	Text = self.props.properties[i],
				-- 	Font = Enum.Font.BuilderSansMedium,
				-- 	TextSize = PluginEnum.FontSizeTextPrimary,
				-- 	TextColor3 = PluginEnum.ColorTextPrimary,
				-- 	BackgroundColor3 = PluginEnum.ColorBackground,
				-- 	BorderSizePixel = 0,
				-- 	TextXAlignment = Enum.TextXAlignment.Left,
				-- 	LayoutOrder = 2
				-- }),
				wireButton = show_wire and  e(StudioComponents.Button, {
					Text = wireLabel,
					AutomaticSize = Enum.AutomaticSize.X,
					LayoutOrder = 3,
					OnActivated = function()
						self.props.onClick(self.props.instances, self.props.properties[i])
					end
				}),
				-- wireButton = show_wire and e("TextButton", {
				-- 	Text = wireLabel,
				-- 	AutomaticSize = Enum.AutomaticSize.XY,
				-- 	Size = UDim2.new(0, 0, 0, 0),
				-- 	TextColor3 = PluginEnum.ColorButtonNavigationText,
				-- 	BackgroundColor3 = PluginEnum.ColorButtonNavigationBackground,
				-- 	BorderSizePixel = 0,
				-- 	Font = Enum.Font.BuilderSansBold,
				-- 	TextSize = PluginEnum.FontSizeNavigationButton,
				-- 	LayoutOrder = 3,
				-- 	[React.Event.MouseButton1Click] = function()
				-- 		self.props.onClick(self.props.instances, self.props.properties[i])
				-- 	end,
				-- }), 
				unwireButton = e(StudioComponents.Button, {
					Text = unwireLabel,
					AutomaticSize = Enum.AutomaticSize.X,

					LayoutOrder = 4,
					OnActivated = function()
						self.props.onUwireClick(self.props.instances, self.props.properties[i])
					end
				}),
				-- unwireButton = show_unwire and e("TextButton", {
				-- 	Text = unwireLabel,
				-- 	AutomaticSize = Enum.AutomaticSize.XY,
				-- 	Size = UDim2.new(0, 0, 0, 0),
				-- 	TextColor3 = PluginEnum.ColorButtonSecondaryActionText,
				-- 	BackgroundColor3 = PluginEnum.ColorButtonSecondaryActionBackground,
				-- 	BorderSizePixel = 0,
				-- 	Font = Enum.Font.BuilderSansBold,
				-- 	TextSize = PluginEnum.FontSizeNavigationButton,
				-- 	LayoutOrder = 3,
				-- 	[React.Event.MouseButton1Click] = function()
				-- 		self.props.onUwireClick(self.props.instances, self.props.properties[i])
				-- 	end,
				-- })

			})
		}
		)
end

function InstanceWirerComponent:renderHeaderAndLink(layoutOrder)
	return e('Frame', {				
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = layoutOrder, 
		BackgroundTransparency = 1,
		
		},
		{
			
			uiListLayout = e("UIListLayout", {
				--Padding = UDim.new(0, PluginEnum.PaddingHorizontal),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal, 
				VerticalAlignment =  Enum.VerticalAlignment.Center,
				HorizontalFlex = Enum.UIFlexAlignment.Fill
			}),
			header =  e("TextLabel", {
				Size = UDim2.new(0.5, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = self.props.header,
				Font = Enum.Font.BuilderSansMedium,
				TextSize = PluginEnum.FontSizeTextPrimary,
				TextColor3 = PluginEnum.ColorTextPrimary,
				BackgroundColor3 = PluginEnum.ColorBackground,
				BorderSizePixel = 0,
				BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1
			}),
			select = self.props.showSelectButton and e("TextButton", {
				Text = '<u>Select</u>',
				Size = UDim2.new(0, 40, 0 , 20),
				RichText = true,
				TextColor3 = PluginEnum.ColorTextPrimary,
				TextXAlignment = Enum.TextXAlignment.Right,
				BorderSizePixel = 0,
				Font = Enum.Font.BuilderSans,
				TextSize = PluginEnum.FontSizeTextPrimary,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				[React.Event.MouseButton1Click] = function()
					Selection:Add(self.props.instances)
				end,
			})

		    
		})	

end
return InstanceWirerComponent
