local Freeway = script:FindFirstAncestor("Freeway")
local Packages = Freeway.Packages

local React = require(Packages.React)

local e = React.createElement

local App = React.Component:extend("App")

local StudioSharedToolbar = require(script.Parent.Studio.StudioSharedToolbar)
local StudioPluginContext = require(script.Parent.Studio.StudioPluginContext)
local StudioPluginGui = require(script.Parent.Studio.StudioPluginGui)
local Widget = require(script.Parent.Widget)
local VersionWarning = require(script.Parent.VersionWarning)

function App:init()
	self:setState({
		guiEnabled = false,
	})
	VersionWarning:runVersionChecking()
end

function App:render()
	local pluginName = "Freeway"

	return e(StudioPluginContext.Provider, {
		value = self.props.plugin,
	}, {
		gui = e(StudioPluginGui, {
			id = pluginName,
			title = pluginName,
			active = self.state.guiEnabled,

			initDockState = Enum.InitialDockState.Left,
			overridePreviousState = false,
			floatingSize = Vector2.new(250, 200),
			minimumSize = Vector2.new(250, 200),

			zIndexBehavior = Enum.ZIndexBehavior.Sibling,

			onInitialState = function(initialState)
				self.props.fetcher:setEnabled(initialState)
				self:setState({
					guiEnabled = initialState,
				})
			end,

			onClose = function()
				self.props.fetcher:setEnabled(false)
				self:setState({
					guiEnabled = false,
				})
			end,
		}, {
			widget = e(Widget, {fetcher = self.props.fetcher}),
		}),
		sharedToolbarButton = e(StudioSharedToolbar, {
			combinerName = "Freeway-Toolbar",
			toolbarName = "Freeway",
			buttonName = "Freeway",
			buttonIcon = "rbxassetid://103592658908979",
			buttonTooltip = "Toggle the Asset Sync widget",
			buttonEnabled = true,
			buttonActive = self.state.guiEnabled,
			fetcher = self.props.fetcher,
			onClick = function()
				self.props.fetcher:setEnabled(not self.state.guiEnabled)
				self:setState(function(state)
					return {
						guiEnabled = not state.guiEnabled,
					}
				end)
			end,
		}),
	})
end

return App
