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
local units = {} -- This will map a slot index (1-6) to the unit's real name (e.g., units[1] = "LuffyG5")
local unitData = {} -- This will store UI elements and position data for each slot
for i = 1, 6 do
	unitData[i] = {
		position = nil,
		isWaitingForClick = false,
		positionBtn = nil,
		positionLabel = nil,
	}
end

--// Core Functions

function notifyPlayer(title, content, duration, image)
	Rayfield:Notify({
		Title = title,
		Content = content,
		Duration = duration,
		Image = tostring(image),
	})
end

--// Gets the real unit names from the player's slots
function getUnits()
	-- Reset the current unit list
	table.clear(units)
	local slotsPath = localPlayer:WaitForChild("Slots")
	local slotChildren = slotsPath:GetChildren()

	-- Sort children by name to ensure Slot1, Slot2, etc., are in order
	table.sort(slotChildren, function(a, b)
		return a.Name < b.Name
	end)

	for _, slotInstance in ipairs(slotChildren) do
		if slotInstance:IsA("StringValue") then
			-- Extract the number from the slot name (e.g., "Slot1" -> 1)
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

--// Places a unit using its real name and a CFrame position
function placeUnit(unitName, position)
	if not unitName or not position then
		return
	end
	local args = {
		tostring(unitName),
		CFrame.new(position),
	}
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlaceTower"):FireServer(unpack(args))
end

--// Finds the deployed tower nearest to the set position and upgrades it
function upgradeUnit(unitIndex, upgradeAmount)
	local targetPosition = unitData[unitIndex].position
	if not targetPosition then
		return
	end

	local towersFolder = workspace:WaitForChild("Towers")
	local closestTower = nil
	local minDistance = 5 -- Search radius in studs

	-- Find the tower in the workspace closest to our saved position
	for _, tower in ipairs(towersFolder:GetChildren()) do
		if tower:IsA("Model") and tower.PrimaryPart then
			local distance = (tower.PrimaryPart.Position - targetPosition).Magnitude
			if distance < minDistance then
				minDistance = distance
				closestTower = tower
			end
		end
	end

	if closestTower then
		-- Perform the requested number of upgrades
		for i = 1, upgradeAmount or 1 do
			local args = { closestTower }
			ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Upgrade"):InvokeServer(unpack(args))
			task.wait(0.1) -- Small delay to prevent server overload
		end
	end
end

--// Position Save/Load Functions
local positionSaveFile = "soaHub/unitPositions.json"

function savePositions()
	local positionsToSave = {}
	for i = 1, #unitData do
		if unitData[i].position then
			positionsToSave["Unit" .. i] = {
				x = unitData[i].position.X,
				y = unitData[i].position.Y,
				z = unitData[i].position.Z,
			}
		end
	end
	writefile(positionSaveFile, HttpService:JSONEncode(positionsToSave))
end

function loadPositions()
	if not isfolder("soaHub") then
		makefolder("soaHub")
	end
	if isfile(positionSaveFile) then
		local success, data = pcall(function()
			return HttpService:JSONDecode(readfile(positionSaveFile))
		end)

		if success and data then
			for unitName, posData in pairs(data) do
				local unitIndex = tonumber(string.gsub(unitName, "Unit", ""))
				if unitData[unitIndex] and unitData[unitIndex].positionLabel then
					unitData[unitIndex].position = Vector3.new(posData.x, posData.y, posData.z)
					unitData[unitIndex].positionLabel:Set("Position: " .. tostring(unitData[unitIndex].position))
				end
			end
		end
	end
end

--// UI Declaration
getUnits() -- Load unit names before creating the UI
local AutomationTab = Window:CreateTab("Automation", "rotate-ccw")

--// Dynamically create UI for all 6 unit slots
for i = 1, 6 do
	-- Use the real unit name for the UI, or a default if the slot is empty
	local unitName = units[i] or "Empty Slot " .. i
	local isSlotEmpty = not units[i]

	AutomationTab:CreateDivider()
	local sectionLabel = AutomationTab:CreateLabel(string.format("Configuration for: %s", unitName))
	if isSlotEmpty then
		sectionLabel:SetColor(Color3.fromRGB(180, 180, 180)) -- Grey out text for empty slots
	end

	unitData[i].positionLabel = AutomationTab:CreateLabel("Position: Not Set", "arrow-down-to-dot")

	unitData[i].positionBtn = AutomationTab:CreateButton({
		Name = "Set Position",
		Callback = function()
			unitData[i].isWaitingForClick = not unitData[i].isWaitingForClick
			if unitData[i].isWaitingForClick then
				unitData[i].positionBtn:Set("Waiting for click...")
			else
				unitData[i].positionBtn:Set("Set Position")
			end
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
		Name = "Auto Upgrade Unit",
		CurrentValue = false,
		Flag = "AU" .. i,
		Enabled = not isSlotEmpty,
		Callback = function(Value)
			while Value and task.wait(0.25) do
				upgradeUnit(i, 1)
			end
		end,
	})
end

--// Global Input Handler
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessedEvent then
		for i = 1, #unitData do
			if unitData[i].isWaitingForClick then
				unitData[i].position = getMousePosition()
				unitData[i].positionLabel:Set("Position: " .. tostring(unitData[i].position))
				unitData[i].isWaitingForClick = false
				if unitData[i].positionBtn then
					unitData[i].positionBtn:Set("Set Position")
				end
				savePositions() -- Save after setting a new position
				break
			end
		end
	end
end)

--// Load configurations
loadPositions() -- Load custom position data first
Rayfield:LoadConfiguration() -- Then load Rayfield's toggle data
