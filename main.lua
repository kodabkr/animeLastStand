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
local units = {} -- Maps slot index (1-6) to the unit's real name (e.g., units[1] = "LuffyG5")
local unitData = {} -- Stores UI elements and position data for each slot
for i = 1, 6 do
	unitData[i] = {
		position = nil,
		isWaitingForClick = false,
		positionBtn = nil,
		positionLabel = nil,
	}
end

--// Core Functions

--// Gets the real unit names from the player's slots
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
	local minDistance = 7 -- Increased search radius slightly for safety

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
		for i = 1, upgradeAmount or 1 do
			local args = { closestTower }
			ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Upgrade"):InvokeServer(unpack(args))
			task.wait(0.1)
		end
	end
end

--// Position Save/Load Functions
local positionSaveFile = "soaHub/unitPositions.json"

function savePositions()
	if not isfolder("soaHub") then
		makefolder("soaHub")
	end
	local positionsToSave = {}
	for i = 1, #unitData do
		if unitData[i].position then
			positionsToSave["Slot" .. i] = {
				x = unitData[i].position.X,
				y = unitData[i].position.Y,
				z = unitData[i].position.Z,
			}
		end
	end
	writefile(positionSaveFile, HttpService:JSONEncode(positionsToSave))
end

function loadPositions()
	if isfile(positionSaveFile) then
		local success, data = pcall(function()
			return HttpService:JSONDecode(readfile(positionSaveFile))
		end)

		if success and data then
			for slotName, posData in pairs(data) do
				local slotIndex = tonumber(string.match(slotName, "%d+"))
				if slotIndex and unitData[slotIndex] and unitData[slotIndex].positionLabel then
					local loadedPos = Vector3.new(posData.x, posData.y, posData.z)
					unitData[slotIndex].position = loadedPos
					-- This is the key change: Set the label text after it has been created
					unitData[slotIndex].positionLabel:Set("Position: " .. tostring(loadedPos))
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
	local unitName = units[i] or "Empty Slot"
	local isSlotEmpty = not units[i]

	AutomationTab:CreateDivider()
	local sectionLabel = AutomationTab:CreateLabel(string.format("Slot %d: %s", i, unitName))
	if isSlotEmpty then
		sectionLabel:SetColor(Color3.fromRGB(180, 180, 180))
	end

	unitData[i].positionLabel = AutomationTab:CreateLabel(
		"Position: Not Set", -- Default text
		"arrow-down-to-dot"
	)

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
			while Value and task.wait(0.05) do
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
			while Value and task.wait(0.05) do
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

--// Load configurations AFTER UI has been created
loadPositions() -- Load and display saved positions
Rayfield:LoadConfiguration() -- Load Rayfield's data (toggles, etc.)
