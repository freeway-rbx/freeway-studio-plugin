--!strict
local Packages = script:FindFirstAncestor("Freeway").Packages
local React = require(Packages.React)
local Cryo = require(Packages.Cryo)

local e = React.createElement
local StudioComponents = require(Packages.studiocomponents)

local Selection = game:GetService("Selection")
local CollectionService = game:GetService("CollectionService")
local AssetService = game:GetService("AssetService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local PieceDetailsComponent = React.Component:extend("PieceDetailsComponent")

local InstanceWirerComponent = require(script.Parent.InstanceWirerComponent)
local PluginEnum = require(script.Parent.Enum)
local t_u = require(script.Parent.tags_util)
local ui_commons = require(script.Parent.ui_commons)

function PieceDetailsComponent:didMount()
	-- print('PieceDetailsComponent:didMount', self.state.selectedWirersModel)
end

function PieceDetailsComponent:willUnmount()
	self.onSelectionChanged:Disconnect()
end

function PieceDetailsComponent:init()
	self:updateSelectedWirersState()
	self.onSelectionChanged = Selection.SelectionChanged:Connect(function()
		self:updateSelectedWirersState()
	end)
	self:updateDMWirerState()

	CollectionService:GetInstanceAddedSignal("wired"):Connect(function(instance)
		local updateWirersState = t_u:shouldRebuildWirersStat(Selection:Get(), instance)
		if updateWirersState then
			self:updateSelectedWirersState()
		end
		self:updateDMWirerState()
	end)

	CollectionService:GetInstanceRemovedSignal("wired"):Connect(function(instance)
		local updateWirersState = t_u:shouldRebuildWirersStat(Selection:Get(), instance)
		if updateWirersState then
			self:updateSelectedWirersState()
		end

		self:updateDMWirerState()
	end)
end

function PieceDetailsComponent:buildWirersModel(instances)
	return ui_commons:buildWirersModel(instances, self.props.piece.type, self.props.piece.id)
end

function PieceDetailsComponent:updateDMWirerState()
	local instancesToWires = t_u.ts_get_all_wired_in_dm()
	local instancesWiredToCurrentPiece = {}
	for instance, wires in instancesToWires do
		if wires[self.props.piece.id] ~= nil then
			table.insert(instancesWiredToCurrentPiece, instance)
		end
	end
	local result = self:buildWirersModel(instancesWiredToCurrentPiece)
	self:setState({ dmWirersModel = result })
end

function PieceDetailsComponent:updateSelectedWirersState()
	local selection = Selection:Get()
	local result = self:buildWirersModel(selection)
	self:setState({ selectedWirersModel = result })
end

function PieceDetailsComponent.getDerivedStateFromProps(props)
	return props
end

function PieceDetailsComponent:buildInstanceWirerComponent(i, wirerModel, showSelectButton)
	return e(InstanceWirerComponent, {
		index = i,
		instances = wirerModel.instances,
		properties = wirerModel.properties,
		header = wirerModel.header,
		fetcher = self.props.fetcher,
		piece = self.props.piece,
		showSelectButton = showSelectButton,
		combinedPropertyState = wirerModel.combinedPropertyState,

		onClick = function(instances, propertyName)
			local recordingId = ChangeHistoryService:TryBeginRecording("wire")
			for _, instance in instances do
				-- print('wire instance', instance, self.props.piece.id, propertyName)
				t_u:wire_instance(instance, self.props.piece.id, propertyName)
				self.props.fetcher:update_instance_if_needed(instance)
			end
			ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)
		end,
		onUwireClick = function(instances, propertyName)
			local recordingId = ChangeHistoryService:TryBeginRecording("wire")

			for _, instance in instances do
				-- print('unwire all')
				t_u:unwire_instance(instance, propertyName)
			end
			ChangeHistoryService:FinishRecording(recordingId, Enum.FinishRecordingOperation.Commit)
		end,
	})
end

function PieceDetailsComponent:render()
	local state = self.state

	local selectionInstanceWirers = {}
	local dmInstanceWirers = {}

	local i = 4
	local hasSelectionToWire = false
	for _, wirerModel in state.selectedWirersModel do
		-- print('redo wirers')
		local newInstanceWirer = self:buildInstanceWirerComponent(i, wirerModel, false)
		selectionInstanceWirers["selectionInstanceWirer" .. i] = newInstanceWirer
		hasSelectionToWire = true
		i = i + 1
	end
	if not hasSelectionToWire then
		local message = "Please select an instance(s) with image property to continue."
		if self.props.piece.type == "mesh" then
			message = "Please select a MeshPart(s) to continue."
		end
		local emptyState = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 0, 40),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = i,
		}, {
			label = e("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = message,
				Font = Enum.Font.BuilderSans,
				TextSize = PluginEnum.FontSizeTextPrimary,
				TextColor3 = PluginEnum.ColorTextPrimary,
				BackgroundColor3 = PluginEnum.ColorBackground,
				BorderSizePixel = 0,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})
		selectionInstanceWirers["emptyState"] = emptyState
	end

	local dmWirersLabelIndex = i + 1
	local hasDMWires = false
	i = i + 2
	for _, wirerModel in state.dmWirersModel do
		local newInstanceWirer = self:buildInstanceWirerComponent(i, wirerModel, true)
		dmInstanceWirers["selectionInstanceWirer" .. i] = newInstanceWirer

		hasDMWires = true
		i = i + 1
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = self.props.index,
	}, {
		Cryo.Dictionary.join(
			{
				uiListLayout = e("UIListLayout", {
					Padding = UDim.new(0, 10),
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
				}),
				nameElement = e("TextLabel", {
					Size = UDim2.new(0, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.XY,
					Text = self.props.piece.name,
					Font = Enum.Font.BuilderSansBold,
					TextSize = PluginEnum.FontSizeTextPrimary,
					TextColor3 = PluginEnum.ColorTextPrimary,
					BackgroundColor3 = PluginEnum.ColorBackground,
					BorderSizePixel = 0,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = 1,
				}),
			},
			self:renderPreviewAndActions(2),
			{
				selectedHeader = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.XY,
					LayoutOrder = 3,
					Text = "Wireable Selected Instances:",
					Font = Enum.Font.BuilderSansBold,
					TextSize = PluginEnum.FontSizeTextPrimary,
					TextColor3 = PluginEnum.ColorTextPrimary,
					BackgroundColor3 = PluginEnum.ColorBackground,
					BorderSizePixel = 0,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			},
			selectionInstanceWirers,
			{
				dmWirerHeader = hasDMWires and e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.XY,
					LayoutOrder = dmWirersLabelIndex,
					Text = "Already Wired To:",
					Font = Enum.Font.BuilderSansBold,
					TextSize = PluginEnum.FontSizeTextPrimary,
					TextColor3 = PluginEnum.ColorTextPrimary,
					BackgroundColor3 = PluginEnum.ColorButtonNavigationBackground,
					BorderSizePixel = 0,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			},
			dmInstanceWirers
		),
	})
end

function PieceDetailsComponent:renderPreviewAndActions(order: number)
	-- print('render piece details component')

	local content = self.props.fetcher:fetch(self.props.piece)
	local hasAsset = self.props.fetcher:objectHasAsset(self.props.piece)
	local showSaveButton = content ~= nil and not hasAsset

	if self.props.piece.type ~= "image" then
		content = nil
	end

	local image = "http://www.roblox.com/asset/?id=92229743995007"
	if self.props.piece.type == "image" then
		image = nil
	end

	local previewAndActions = {
		e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = order,
		}, {
			uiListLayoutTop = e("UIListLayout", {
				Padding = UDim.new(0, PluginEnum.PaddingHorizontal),
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			texturePreviewTop = content ~= nil and e("ImageLabel", {
				Size = UDim2.new(0, PluginEnum.DetailsSize, 0, PluginEnum.DetailsSize),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = PluginEnum.ColorBackground,
				BorderSizePixel = 0,
				ImageContent = content,
				LayoutOrder = 1,
			}),
			imageStaticPreview = image ~= nil and e("ImageLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = PluginEnum.ColorBackground,
				BorderSizePixel = 0,
				Image = image,
				LayoutOrder = 2,
				Size = UDim2.fromOffset(PluginEnum.PreviewSize, PluginEnum.PreviewSize),
			}),

			saveAsset = false and self.props.piece.type == "mesh" and showSaveButton and React.createElement(
				"TextButton",
				{
					AnchorPoint = Vector2.new(0.8, 0.5),
					LayoutOrder = 4,
					Text = "Save",
					Size = UDim2.new(0, 30, 0, 30),
					BackgroundColor3 = PluginEnum.ColorBackgroundHighlight,
					BackgroundTransparency = 0,
					[React.Event.MouseButton1Click] = function()
						print("CreateAssetAsync start ")
						local AssetService = game:GetService("AssetService")

						local editableMesh = self.props.fetcher:fetch(self.props.piece)
						-- add vertices, faces, and uvs to the mesh

						local requestParameters = {
							CreatorId = game.Players.LocalPlayer.UserId,
							CreatorType = Enum.AssetCreatorType.User,
							Name = self.props.piece.name,
							Description = self.props.piece.name .. " saved by Freeway",
						}

						local ok, result, idOrUploadErr = pcall(function()
							return AssetService:CreateAssetAsync(editableMesh, Enum.AssetType.Mesh, requestParameters)
						end)

						if not ok then
							warn(`error calling CreateAssetAsync: {result}`)
						elseif result == Enum.CreateAssetResult.Success then
							print(`success, new asset id: {idOrUploadErr}`)
							local piece = self.props.piece

							local result = self.props.fetcher:updateAssetIdForPiece(piece.id, piece.hash, idOrUploadErr)
							if not result then
								print(`could not update the asset id for piece `, piece.id)
							else
								print(`updated the asset id for piece `, piece.id)
							end
						else
							warn(`upload error in CreateAssetAsync: {result}, {idOrUploadErr}`)
						end
					end,
				}
			),

			insertAndWire = e(StudioComponents.Button, {
				LayoutOrder = 5,
				Text = "Insert",
				Size = UDim2.new(0, 30, 0, 30),
				AutomaticSize = Enum.AutomaticSize.X,
				OnActivated = function()
					local camera = workspace.CurrentCamera

					local part = nil

					if self.props.piece.type == "mesh" then
						part = Instance.new("MeshPart")
						part.Name = "MeshPart"
						part.Size = Vector3.new(2, 2, 2)
						part.CanCollide = true
						part.Parent = workspace
						t_u:wire_instance(part, self.props.piece.id, "MeshId")
					elseif self.props.piece.type == "image" then
						part = Instance.new("Part")
						part.Parent = workspace
						part.Size = Vector3.new(2, 2, 0.5)
						part.Name = "Part"
						part.CanCollide = true
						local decal = Instance.new("Decal")
						decal.Parent = part
						t_u:wire_instance(decal, self.props.piece.id, "Texture")
					end

					-- Position 10 studs in front of camera
					local cameraPosition = camera.CFrame.Position
					local cameraLookVector = camera.CFrame.LookVector
					local partPosition = cameraPosition + (cameraLookVector * 10)
					part.Position = partPosition

					Selection:Set({ part })
					self.props.fetcher:update_instance_if_needed(part)
				end,
			}),
		}),
	}

	return previewAndActions
end
return PieceDetailsComponent
