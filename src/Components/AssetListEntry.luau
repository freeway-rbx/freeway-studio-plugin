local Freeway = script:FindFirstAncestor("Freeway")
local React = require(Freeway.Packages.React)
local StudioComponents = require(Freeway.Packages.studiocomponents)

local e = React.createElement

local function AssetListEntry(props: {
	Title: string,
	Icon: string?,
	Actions: { { Title: string, OnActivated: () -> (), ButtonStyle: ("MainButton" | "Button")? } }?,
})
	local actionButtons = {}

	if props.Actions then
		for index, action in props.Actions do
			local ButtonComponent = if action.ButtonStyle
				then StudioComponents[action.ButtonStyle] or StudioComponents.Button
				else StudioComponents.Button

			actionButtons[action.Title] = e(ButtonComponent, {
				Text = action.Title,
				OnActivated = action.OnActivated,
				AutomaticSize = Enum.AutomaticSize.XY,
				LayoutOrder = index,
			})
		end
	end

	return e("Frame", {
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),

		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0.005, 0),
			PaddingRight = UDim.new(0.005, 0),
			PaddingTop = UDim.new(0.1, 0),
			PaddingBottom = UDim.new(0.1, 0),
		}),

		UIListLayout = e("UIListLayout", {
			Padding = UDim.new(0, 20),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			FillDirection = Enum.FillDirection.Horizontal,
		}),

		Icon = e("ImageLabel", {
			BackgroundTransparency = 0,
			Size = UDim2.fromScale(0, 1),
			Image = props.Icon,
			BackgroundColor3 = Color3.fromRGB(60, 60, 60),
			LayoutOrder = 1,
		}, {
			UIAspectRatioConstraint = e("UIAspectRatioConstraint", {
				DominantAxis = Enum.DominantAxis.Height,
				AspectType = Enum.AspectType.ScaleWithParentSize,
				AspectRatio = 1,
			}),

			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
		}),

		Title = e("TextLabel", {
			Text = props.Title,
			Font = Enum.Font.SourceSansBold,
			TextScaled = true,
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.4, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			LayoutOrder = 2,
		}, {
			UISizeConstraint = e("UISizeConstraint", {
				MinSize = Vector2.new(0, 0),
				MaxSize = Vector2.new(500, 200),
			}),

			UIStroke = e("UIStroke", {
				Thickness = 1,
				Color = Color3.fromRGB(0, 0, 0),
				Transparency = 0,
			}),

			UITextSizeConstraint = e("UITextSizeConstraint", {
				MinTextSize = 0,
				MaxTextSize = 20,
			}),
		}),

		ActionButtonHolder = e("Frame", {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			LayoutOrder = 3,
		}, {
			UIListLayout = e("UIListLayout", {
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				FillDirection = Enum.FillDirection.Horizontal,
			}),

			ActionButtons = e(React.Fragment, nil, actionButtons),
		}),
	})
end

return AssetListEntry
