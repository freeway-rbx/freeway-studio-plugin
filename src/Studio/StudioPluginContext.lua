local Freeway = script:FindFirstAncestor("Freeway")

local React = require(Freeway.Packages.React)

local StudioPluginContext = React.createContext(nil)

return StudioPluginContext
