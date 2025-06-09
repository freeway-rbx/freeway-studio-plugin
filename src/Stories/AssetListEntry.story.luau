local Freeway = script:FindFirstAncestor("Freeway")

local React = require(Freeway.Packages.React)
local ReactRoblox = require(Freeway.Packages.ReactRoblox)

local e = React.createElement
local AssetListEntry = require(Freeway.Components.AssetListEntry)

local function OnClick()
	print("Clicked")
end

return function(target)
	local root = ReactRoblox.createRoot(Instance.new("Folder"))
	root:render(ReactRoblox.createPortal(
		e("Frame", {
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.85),
			BackgroundTransparency = 1,
		}, {
			UIListLayout = e("UIListLayout", {
				Padding = UDim.new(0, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.Name,
			}),

			TextureEntry = e(AssetListEntry, {
				Icon = "rbxassetid://138180362075438",
				Title = "Texture_1.png",
				Actions = {
					{ Title = "⚡️ Rewire", ButtonStyle = "MainButton", OnActivated = OnClick },
					{ Title = "Delete", OnActivated = OnClick },
				},
			}),

			TextureEntry2 = e(AssetListEntry, {
				Icon = "rbxassetid://12376249776",
				Title = "Mesh_1",
				Actions = {
					{ Title = "⚡️ Rewire", ButtonStyle = "MainButton", OnActivated = OnClick },
					{ Title = "Delete", OnActivated = OnClick },
				},
			}),

			ActionExample = e(AssetListEntry, {
				Icon = "rbxassetid://12769106192",
				Title = "ActionExample",
				Actions = {
					{ Title = "Actions", ButtonStyle = "MainButton", OnActivated = OnClick },
					{ Title = "Are", OnActivated = OnClick },
					{ Title = "Very", OnActivated = OnClick },
					{ Title = "Customizable", OnActivated = OnClick, ButtonStyle = "MainButton" },
				},
			}),
		}),
		target
	))

	return function()
		root:unmount()
	end
end
