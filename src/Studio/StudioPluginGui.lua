local Freeway = script:FindFirstAncestor("Freeway")

local Cryo = require(Freeway.Packages.Cryo)
local React = require(Freeway.Packages.React)
local ReactRoblox = require(Freeway.Packages.ReactRoblox)
local StudioPluginContext = require(Freeway.Studio.StudioPluginContext)

local StudioPluginGui = React.PureComponent:extend("StudioPluginGui")

StudioPluginGui.defaultProps = {
	initDockState = Enum.InitialDockState.Right,
	active = false,
	overridePreviousState = false,
	floatingSize = Vector2.new(0, 0),
	minimumSize = Vector2.new(0, 0),
	zIndexBehavior = Enum.ZIndexBehavior.Sibling,
}

function StudioPluginGui:init()
	local floatingSize = self.props.floatingSize
	local minimumSize = self.props.minimumSize

	local dockWidgetPluginGuiInfo = DockWidgetPluginGuiInfo.new(
		self.props.initDockState,
		self.props.active,
		self.props.overridePreviousState,
		floatingSize.X,
		floatingSize.Y,
		minimumSize.X,
		minimumSize.Y
	)

	local pluginGui = self.props.plugin:CreateDockWidgetPluginGui(self.props.id, dockWidgetPluginGuiInfo)

	pluginGui.Name = self.props.id
	pluginGui.Title = self.props.title
	pluginGui.ZIndexBehavior = self.props.zIndexBehavior

	if self.props.onInitialState then
		self.props.onInitialState(pluginGui.Enabled)
	end

	pluginGui:BindToClose(function()
		if self.props.onClose then
			self.props.onClose()
		else
			pluginGui.Enabled = false
		end
	end)

	self.pluginGui = pluginGui
end

function StudioPluginGui:render()
	return ReactRoblox.createPortal(
		React.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			Transparency = 1,
			BorderSizePixel = 0,
		}, self.props.children),
		self.pluginGui
	)
end

function StudioPluginGui:didUpdate(lastProps)
	if self.props.active ~= lastProps.active then
		-- This is intentionally in didUpdate to make sure the initial active state
		-- (if the PluginGui is open initially) is preserved.

		-- Studio widgets are very unreliable and sometimes need to be flickered
		-- in order to force them to render correctly
		-- This happens within a single frame so it doesn't flicker visibly
		self.pluginGui.Enabled = self.props.active
		self.pluginGui.Enabled = not self.props.active
		self.pluginGui.Enabled = self.props.active
	end
end

function StudioPluginGui:willUnmount()
	self.pluginGui:Destroy()
end

local function StudioPluginGuiWrapper(props)
	return React.createElement(StudioPluginContext.Consumer, {
		render = function(plugin)
			return React.createElement(
				StudioPluginGui,
				Cryo.Dictionary.join(props, {
					plugin = plugin,
				})
			)
		end,
	})
end

return StudioPluginGuiWrapper
