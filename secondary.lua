local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Soa Hub",
	Icon = "eye",
	LoadingTitle = "Soa Hub",
	LoadingSubtitle = "by Koda",
	ShowText = "Rayfield",
	Theme = "Amethyst",
	ToggleUIKeybind = "K",

	ConfigurationSaving = {
		Enabled = true,
		FolderName = "soaHub",
		FileName = "alsCFG",
	},
})

--// Services & Local Player
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

--// Module Data
local configFolderName = "soaHub"
local currentConfigFile = "default.json" -- The config that is currently loaded

local units = {} -- Maps slot index (1-6) to the unit's base name
local unitData = {} -- Stores UI elements and data for each slot
local processedTowers = {} -- Tracks towers that have had auto-upgrade enabled

for i = 1, 6 do
	unitData[i] = {
		position = nil,
		isWaitingForClick = false,
		positionBtn = nil,
		positionLabel = nil,
		enableServerAutoUpgrade = false,
	}
end

--// Forward declaration for UI elements
local ConfigDropdown

--// Core Functions

function getUnits()
	table.clear(units)
	local slotsPath = localPlayer:WaitForChild("Slots")
	local slotChildren = slotsPath:GetChildren()
	table.sort(slotChildren, function(a, b)
		return a.Name < b.Name
	end)

	for _, slotInstance in ipairs(slotChildren) do
		if slotInstance:IsA("StringValue") then
			local slotIndex = tonumber(string.match(slotInstance.Name, "%d+"))
			if slotIndex then
				units[slotIndex] = slotInstance.Value
			end
		end
	end
end

function getMousePosition()
	return mouse.Hit.p
end

function placeUnit(unitName, position)
	if not unitName or not position then
		return
	end
	ReplicatedStorage:WaitForChild("Remotes")
		:WaitForChild("PlaceTower")
		:FireServer(tostring(unitName), CFrame.new(position))
end

function setServerAutoUpgrade(towerInstance)
	if not towerInstance then
		return
	end
	ReplicatedStorage:WaitForChild("Remotes")
		:WaitForChild("UnitManager")
		:WaitForChild("SetAutoUpgrade")
		:FireServer(towerInstance, true)
end

--// -- Position & Config Management Functions --

--// Refreshes the dropdown list with all .json files in the config folder
function refreshConfigDropdown()
	if not ConfigDropdown then
		return
	end
	local configs = {}
	if isfolder(configFolderName) then
		for _, file in ipairs(listfiles(configFolderName)) do
			if file:match("%.json$") then
				table.insert(configs, file:gsub(configFolderName .. "/", "")) -- Add just the filename
			end
		end
	end
	ConfigDropdown:SetValues(configs)
end

--// Saves the current positions to a specified file
function savePositions(filename)
	if not filename then
		return
	end
	if not isfolder(configFolderName) then
		makefolder(configFolderName)
	end

	local positionsToSave = {}
	for i = 1, #unitData do
		if unitData[i].position then
			positionsToSave["Slot" .. i] =
				{ x = unitData[i].position.X, y = unitData[i].position.Y, z = unitData[i].position.Z }
		end
	end
	writefile(configFolderName .. "/" .. filename, HttpService:JSONEncode(positionsToSave))
end

--// Loads positions from a specified file and updates the UI
function loadPositions(filename)
	local filePath = configFolderName .. "/" .. filename
	if isfile(filePath) then
		local success, data = pcall(function()
			return HttpService:JSONDecode(readfile(filePath))
		end)

		if success and data then
			-- Clear old positions first
			for i = 1, #unitData do
				unitData[i].position = nil
				unitData[i].positionLabel:Set("Position: Not Set")
			end
			-- Load new positions
			for slotName, posData in pairs(data) do
				local slotIndex = tonumber(string.match(slotName, "%d+"))
				if slotIndex and unitData[slotIndex] and unitData[slotIndex].positionLabel then
					local loadedPos = Vector3.new(posData.x, posData.y, posData.z)
					unitData[slotIndex].position = loadedPos
					unitData[slotIndex].positionLabel:Set("Position: " .. tostring(loadedPos))
				end
			end
			currentConfigFile = filename -- Set the loaded file as the active one
			Rayfield:Notify({ Title = "Config Loaded", Content = "Successfully loaded " .. filename, Duration = 5 })
		else
			Rayfield:Notify({ Title = "Load Error", Content = "Failed to load or parse " .. filename, Duration = 5 })
		end
	end
end

--// -- UI Declaration --

getUnits()
local AutomationTab = Window:CreateTab("Automation", "rotate-ccw")

for i = 1, 6 do
	local unitName = units[i] or "Empty Slot"
	local isSlotEmpty = not units[i]

	AutomationTab:CreateDivider()
	local sectionLabel = AutomationTab:CreateLabel(string.format("Slot %d: %s", i, unitName))
	if isSlotEmpty then
		sectionLabel:SetColor(Color3.fromRGB(180, 180, 180))
	end

	unitData[i].positionLabel = AutomationTab:CreateLabel("Position: Not Set", "arrow-down-to-dot")
	unitData[i].positionBtn = AutomationTab:CreateButton({
		Name = "Set Position",
		Callback = function()
			unitData[i].isWaitingForClick = not unitData[i].isWaitingForClick
			unitData[i].positionBtn:Set(unitData[i].isWaitingForClick and "Waiting for click..." or "Set Position")
		end,
	})
	AutomationTab:CreateToggle({
		Name = "Auto Place Unit",
		CurrentValue = false,
		Flag = "APU" .. i,
		Enabled = not isSlotEmpty,
		Callback = function(Value)
			while Value and task.wait(0.25) do
				placeUnit(units[i], unitData[i].position)
			end
		end,
	})
	AutomationTab:CreateToggle({
		Name = "Enable Server Auto-Upgrade",
		CurrentValue = false,
		Flag = "AU" .. i,
		Enabled = not isSlotEmpty,
		Callback = function(Value)
			unitData[i].enableServerAutoUpgrade = Value
		end,
	})
end

--// Configs Tab UI
local ConfigsTab = Window:CreateTab("Configs", "file-cog")
ConfigsTab:CreateLabel("Manage your position configurations.")

ConfigDropdown =
	ConfigsTab:CreateDropdown({ Name = "Saved Configs", Values = {}, AllowSet = false, Callback = function(value) end })
local ConfigNameInput = ConfigsTab:CreateInput({
	Name = "Config Name",
	PlaceholderText = "E.g., Story Mode",
	Default = "",
	Callback = function(text) end,
})

ConfigsTab:CreateButton({
	Name = "Load Selected Config",
	Callback = function()
		local selected = ConfigDropdown:Get()
		if selected then
			loadPositions(selected)
		end
	end,
})

ConfigsTab:CreateButton({
	Name = "Save Current Positions",
	Callback = function()
		local name = ConfigNameInput:Get()
		if name and name ~= "" then
			local filename = name .. ".json"
			savePositions(filename)
			currentConfigFile = filename -- The new saved file is now the active one
			Rayfield:Notify({ Title = "Config Saved", Content = "Saved positions to " .. filename, Duration = 5 })
			refreshConfigDropdown()
		else
			Rayfield:Notify({ Title = "Save Error", Content = "Please enter a name for the config.", Duration = 5 })
		end
	end,
})

ConfigsTab:CreateButton({
	Name = "Rename Selected Config",
	Callback = function()
		local selected = ConfigDropdown:Get()
		local newName = ConfigNameInput:Get()
		if selected and newName and newName ~= "" then
			renamefile(configFolderName .. "/" .. selected, configFolderName .. "/" .. newName .. ".json")
			Rayfield:Notify({
				Title = "Config Renamed",
				Content = selected .. " is now " .. newName .. ".json",
				Duration = 5,
			})
			refreshConfigDropdown()
		else
			Rayfield:Notify({ Title = "Rename Error", Content = "Select a config and enter a new name.", Duration = 5 })
		end
	end,
})

ConfigsTab:CreateButton({
	Name = "Delete Selected Config",
	Callback = function()
		local selected = ConfigDropdown:Get()
		if selected then
			delfile(configFolderName .. "/" .. selected)
			Rayfield:Notify({ Title = "Config Deleted", Content = "Successfully deleted " .. selected, Duration = 5 })
			refreshConfigDropdown()
		end
	end,
})

ConfigsTab:CreateButton({
	Name = "Refresh List",
	Callback = function()
		refreshConfigDropdown()
		Rayfield:Notify({ Title = "Refreshed", Content = "Configuration list has been updated.", Duration = 3 })
	end,
})

--// -- Final Setup and Loops --

--// Global Input Handler
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessedEvent then
		for i = 1, #unitData do
			if unitData[i].isWaitingForClick then
				unitData[i].position = getMousePosition()
				unitData[i].positionLabel:Set("Position: " .. tostring(unitData[i].position))
				unitData[i].isWaitingForClick = false
				unitData[i].positionBtn:Set("Set Position")
				savePositions(currentConfigFile) -- Auto-save to the currently loaded config file
				break
			end
		end
	end
end)

--// Main background loop for handling server-side auto-upgrades
coroutine.wrap(function()
	local placementLimits = localPlayer:WaitForChild("PlacementLimits")
	local towersFolder = workspace:WaitForChild("Towers")
	while task.wait(1) do
		local placedUnits = {}
		for _, limitValue in ipairs(placementLimits:GetChildren()) do
			if limitValue:IsA("IntValue") then
				placedUnits[limitValue.Name] = true
			end
		end

		for unitName, _ in pairs(placedUnits) do
			local towerInstance = towersFolder:FindFirstChild(unitName)
			if towerInstance and not processedTowers[towerInstance] then
				for i = 1, 6 do
					if unitData[i].enableServerAutoUpgrade and unitData[i].position then
						if (towerInstance.PrimaryPart.Position - unitData[i].position).Magnitude < 5 then
							setServerAutoUpgrade(towerInstance)
							processedTowers[towerInstance] = true
							break
						end
					end
				end
			end
		end

		for tower, _ in pairs(processedTowers) do
			if not tower.Parent then
				processedTowers[tower] = nil
			end
		end
	end
end)()

--// Load configurations and initialize UI
loadPositions(currentConfigFile) -- Load the default config on start
refreshConfigDropdown() -- Populate the dropdown with all available configs
Rayfield:LoadConfiguration() -- Load Rayfield's data (toggles, etc.)
