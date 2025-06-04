local Freeway = script:FindFirstAncestor("Freeway")

local React = require(Freeway.Packages.React)
local StudioPluginContext = require(Freeway.Studio.StudioPluginContext)
local StudioPluginGui = require(Freeway.Studio.StudioPluginGui)
local StudioSharedToolbar = require(Freeway.Studio.StudioSharedToolbar)
local VersionWarning = require(Freeway.VersionWarning)
local Widget = require(Freeway.Widget)

local App = React.Component:extend("App")

function App:init()
	self:setState({
		guiEnabled = false,
	})
	VersionWarning:runVersionChecking()
end

function App:render()
	local pluginName = "Freeway"

	return React.createElement(StudioPluginContext.Provider, {
		value = self.props.plugin,
	}, {
		gui = React.createElement(StudioPluginGui, {
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
			widget = React.createElement(Widget, { fetcher = self.props.fetcher }),
		}),
		sharedToolbarButton = React.createElement(StudioSharedToolbar, {
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
