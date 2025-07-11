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
local units = {} -- Maps slot index (1-6) to the unit's base name (e.g., units[1] = "LuffyG5")
local unitData = {} -- Stores UI elements and data for each slot
local processedTowers = {} -- Tracks towers that have had auto-upgrade enabled

for i = 1, 6 do
	unitData[i] = {
		position = nil,
		isWaitingForClick = false,
		positionBtn = nil,
		positionLabel = nil,
		enableServerAutoUpgrade = false, -- Flag for the new toggle
	}
end

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
	local args = {
		tostring(unitName),
		CFrame.new(position),
	}
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PlaceTower"):FireServer(unpack(args))
end

--// This function now handles enabling the server-side auto-upgrade for a tower
function setServerAutoUpgrade(towerInstance)
	if not towerInstance then
		return
	end
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UnitManager"):WaitForChild("SetAutoUpgrade")
	remote:FireServer(towerInstance, true)
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
					unitData[slotIndex].positionLabel:Set("Position: " .. tostring(loadedPos))
				end
			end
		end
	end
end

--// UI Declaration
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
		Name = "Enable Server Auto-Upgrade", -- Renamed Toggle
		CurrentValue = false,
		Flag = "AU" .. i,
		Enabled = not isSlotEmpty,
		Callback = function(Value)
			-- This toggle now just sets a flag. The main loop will handle the logic.
			unitData[i].enableServerAutoUpgrade = Value
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
				savePositions()
				break
			end
		end
	end
end)

--// Main background loop for handling server-side auto-upgrades
coroutine.wrap(function()
	local placementLimits = localPlayer:WaitForChild("PlacementLimits")
	local towersFolder = workspace:WaitForChild("Towers")

	while task.wait(1) do -- Loop every second
		-- Get a dictionary of currently placed units from PlacementLimits
		local placedUnits = {}
		for _, limitValue in ipairs(placementLimits:GetChildren()) do
			if limitValue:IsA("IntValue") then
				placedUnits[limitValue.Name] = true
			end
		end

		-- Check which towers need their auto-upgrade enabled
		for unitName, _ in pairs(placedUnits) do
			local towerInstance = towersFolder:FindFirstChild(unitName)

			-- If the tower exists and we haven't processed it yet
			if towerInstance and not processedTowers[towerInstance] then
				-- Now, figure out which slot this tower belongs to by checking positions
				for i = 1, 6 do
					-- Check if the toggle for this slot is on and if its position is close to the tower
					if unitData[i].enableServerAutoUpgrade and unitData[i].position then
						if (towerInstance.PrimaryPart.Position - unitData[i].position).Magnitude < 5 then
							-- We found the right slot! Enable auto-upgrade and mark as processed.
							setServerAutoUpgrade(towerInstance)
							processedTowers[towerInstance] = true
							break -- Stop checking other slots for this tower
						end
					end
				end
			end
		end

		-- Clean up the 'processedTowers' table to remove towers that no longer exist
		for tower, _ in pairs(processedTowers) do
			if not tower.Parent then
				processedTowers[tower] = nil
			end
		end
	end
end)()

--// Load configurations AFTER UI has been created
loadPositions()
Rayfield:LoadConfiguration()
