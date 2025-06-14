if not plugin then
	return
end

local RunService = game:GetService("RunService")

if RunService:IsRunning() then
	warn("[FREEWAY] - Don't run Freeway in play mode")
	return
end

local Freeway = script

local App = require(Freeway.Components.App)
local React = require(Freeway.Packages.React)
local ReactRoblox = require(Freeway.Packages.ReactRoblox)
local ObjectFetcherService = require(Freeway.ObjectFetcherService)

local app = React.createElement(App, {
	plugin = plugin,
	fetcher = ObjectFetcherService,
})

local tree = ReactRoblox.createRoot(Instance.new("Folder"))
tree:render(ReactRoblox.createPortal(app, game:GetService("CoreGui")))

plugin.Unloading:Connect(function()
	tree:unmount()
	ObjectFetcherService:stop()
end)
