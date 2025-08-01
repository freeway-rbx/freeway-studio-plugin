local Freeway = script:FindFirstAncestor("Freeway")

local CreateSharedToolbar = require(Freeway.Packages.CreateSharedToolbar)
local Cryo = require(Freeway.Packages.Cryo)
local React = require(Freeway.Packages.React)
local StudioPluginContext = require(Freeway.Studio.StudioPluginContext)

local StudioSharedToolbar = React.Component:extend("StudioSharedToolbar")

StudioSharedToolbar.defaultProps = {
	buttonEnabled = true,
	buttonActive = false,
}

function StudioSharedToolbar:init()
	local toolbarSettings = {} :: CreateSharedToolbar.SharedToolbarSettings
	self.toolbarSettings = toolbarSettings
	toolbarSettings.CombinerName = self.props.combinerName
	toolbarSettings.ToolbarName = self.props.toolbarName
	toolbarSettings.ButtonName = self.props.buttonName
	toolbarSettings.ButtonIcon = self.props.buttonIcon
	toolbarSettings.ButtonTooltip = self.props.buttonTooltip
	toolbarSettings.ClickedFn = self.props.onClick
	CreateSharedToolbar(self.props.plugin, toolbarSettings)
	toolbarSettings.Button.ClickableWhenViewportHidden = true
end

function StudioSharedToolbar:render()
	return nil
end

function StudioSharedToolbar:didUpdate(lastProps)
	if self.props.buttonName ~= lastProps.buttonName then
		self.toolbarSettings.Button.Name = self.props.buttonName
	end

	if self.props.buttonIcon ~= lastProps.buttonIcon then
		self.toolbarSettings.Button.Icon = self.props.buttonIcon
	end

	if self.props.buttonEnabled ~= lastProps.buttonEnabled then
		self.toolbarSettings.Button.Enabled = self.props.buttonEnabled
	end

	if self.props.buttonActive ~= lastProps.buttonActive then
		self.toolbarSettings.Button:SetActive(self.props.buttonActive)
	end
end

local function StudioSharedToolbarWrapper(props)
	return React.createElement(StudioPluginContext.Consumer, {
		render = function(plugin)
			return React.createElement(
				StudioSharedToolbar,
				Cryo.Dictionary.join(props, {
					plugin = plugin,
				})
			)
		end,
	})
end

return StudioSharedToolbarWrapper
