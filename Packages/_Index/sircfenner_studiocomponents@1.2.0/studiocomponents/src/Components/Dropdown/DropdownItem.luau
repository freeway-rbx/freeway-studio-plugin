local React = require(script.Parent.Parent.Parent.Parent:FindFirstChild('react'))

local Constants = require(script.Parent.Parent.Parent:FindFirstChild('Constants'))
local useTheme = require(script.Parent.Parent.Parent:FindFirstChild('Hooks'):FindFirstChild('useTheme'))

local BaseIcon = require(script.Parent.Parent:FindFirstChild('Foundation'):FindFirstChild('BaseIcon'))

local DropdownTypes = require(script.Parent:FindFirstChild('Types'))

type DropdownItemProps = {
	Id: string,
	Text: string,
	Icon: DropdownTypes.DropdownItemIcon?,
	LayoutOrder: number,
	Height: number,
	TextInset: number,
	Selected: boolean,
	OnSelected: (item: string) -> ()
}

local function DropdownItem(props: DropdownItemProps)
	local theme = useTheme()
	local hovered, setHovered = React.useState(false)

	local modifier = Enum.StudioStyleGuideModifier.Default
	if props.Selected then
		modifier = Enum.StudioStyleGuideModifier.Selected
	elseif hovered then
		modifier = Enum.StudioStyleGuideModifier.Hover
	end

	local iconNode: React.Node?
	if props.Icon then
		local iconColor = Color3.fromRGB(255, 255, 255)
		if props.Icon.UseThemeColor then
			iconColor = theme:GetColor(Enum.StudioStyleGuideColor.MainText)
		elseif props.Icon.Color then
			iconColor = props.Icon.Color
		end

		local iconProps = (table.clone(props.Icon) :: any) :: BaseIcon.BaseIconProps
		iconProps.Color = iconColor
		iconProps.AnchorPoint = Vector2.new(0, 0.5)
		iconProps.Position = UDim2.fromScale(0, 0.5)
		iconProps.Size = UDim2.fromOffset(props.Icon.Size.X, props.Icon.Size.Y)
		iconProps.Disabled = nil
		iconProps.LayoutOrder = nil

		iconNode = React.createElement(BaseIcon, iconProps)
	end

	return React.createElement("Frame", {
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, props.Height),
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Item, modifier),
		BorderSizePixel = 0,
	}, {
		Button = React.createElement("TextButton", {
			Position = UDim2.fromOffset(0, 1),
			Size = UDim2.new(1, 0, 1, -1),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			[React.Event.InputBegan] = function(_, input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					setHovered(true)
				end
			end,
			[React.Event.InputEnded] = function(_, input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					setHovered(false)
				end
			end,
			[React.Event.Activated] = function()
				props.OnSelected(props.Id)
			end,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, props.TextInset),
				PaddingBottom = UDim.new(0, 2),
			}),
			Icon = iconNode,
			Label = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(1, if props.Icon then -props.Icon.Size.X - 4 else 0, 1, 0),
				Font = Constants.DefaultFont,
				TextSize = Constants.DefaultTextSize,
				TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText, modifier),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = props.Text,
			}),
		}),
	})
end

return DropdownItem
