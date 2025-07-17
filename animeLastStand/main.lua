local CONFIG = {
	UI = {
		NAME = "Soa Hub",
		THEME = "Amethyst",
		TOGGLE_KEY = "K",
		NOTIFICATION_DURATION = 3,
	},
	AUTOMATION = {
		MAX_SLOTS = 6,
		PLACEMENT_CHECK_RADIUS = 5,
		AUTO_UPGRADE_INTERVAL = 1,
		AUTO_PLACE_INTERVAL = 0.25,
	},
	SUMMON = {
		MAX_AMOUNT = 10,
		MIN_DELAY = 0.5,
		DEFAULT_DELAY = 0.5,
		BANNERS = { "1", "2", "3", "4" },
	},
	FILES = {
		FOLDER = "soaHub",
		CONFIG = "alsCFG",
		POSITIONS = "soaHub/unitPositions.json",
	},
}

local Services = {
	UserInputService = game:GetService("UserInputService"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	HttpService = game:GetService("HttpService"),
	Players = game:GetService("Players"),
	RunService = game:GetService("RunService"),
}

local localPlayer = Services.Players.LocalPlayer
local mouse = localPlayer:GetMouse()

local FileSystem = {
	readfile = readfile or function()
		return nil
	end,
	writefile = writefile or function()
		return false
	end,
	isfile = isfile or function()
		return false
	end,
	isfolder = isfolder or function()
		return false
	end,
	makefolder = makefolder or function()
		return false
	end,
	setclipboard = setclipboard or function()
		return false
	end,
}

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
	Name = CONFIG.UI.NAME,
	Icon = "eye",
	LoadingTitle = CONFIG.UI.NAME,
	LoadingSubtitle = "by Koda",
	ShowText = "Rayfield",
	Theme = CONFIG.UI.THEME,
	ToggleUIKeybind = CONFIG.UI.TOGGLE_KEY,
	ConfigurationSaving = {
		Enabled = true,
		FolderName = CONFIG.FILES.FOLDER,
		FileName = CONFIG.FILES.CONFIG,
	},
})

local State = {
	units = {},
	unitData = {},
	processedTowers = {},
	autoSummonEnabled = false,
	summonConfig = {
		selectedBanner = "1",
		amount = 1,
		delay = CONFIG.SUMMON.DEFAULT_DELAY,
	},
	connections = {},
	loops = {},
}

for i = 1, CONFIG.AUTOMATION.MAX_SLOTS do
	State.unitData[i] = {
		position = nil,
		isWaitingForClick = false,
		positionBtn = nil,
		positionLabel = nil,
		enableServerAutoUpgrade = false,
	}
end

local Utils = {}

function Utils.notify(title, message, image)
	if not Rayfield then
		return
	end
	Rayfield:Notify({
		Title = tostring(title or "Notification"),
		Content = tostring(message or ""),
		Duration = CONFIG.UI.NOTIFICATION_DURATION,
		Image = tostring(image or "info"),
	})
end

function Utils.validateNumber(value, min, max, default)
	local num = tonumber(value)
	if not num then
		return default
	end
	if min and num < min then
		return min
	end
	if max and num > max then
		return max
	end
	return num
end

function Utils.safeWaitForChild(parent, childName, timeout)
	if not parent then
		return nil
	end
	timeout = timeout or 5
	local startTime = os.clock()

	if parent == game and typeof(game.GetService) == "function" then
		local success, result = pcall(function()
			return game:GetService(childName)
		end)
		if success and result then
			return result
		end
	end

	local child = parent:FindFirstChild(childName)
	if child then
		return child
	end

	local success, result = pcall(function()
		return parent:WaitForChild(childName, timeout)
	end)
	return success and result or nil
end

function Utils.safeConnect(signal, callback)
	if not signal then
		return nil
	end

	local connection
	local success, err = pcall(function()
		connection = signal:Connect(callback)
	end)

	if success and connection then
		table.insert(State.connections, connection)
		return connection
	end
	return nil
end

function Utils.createTask(func)
	local taskThread = task.spawn(func)
	table.insert(State.loops, taskThread)
	return taskThread
end

local GameAPI = {}

function GameAPI.getUnits()
	table.clear(State.units)
	local slotsPath = Utils.safeWaitForChild(localPlayer, "Slots")
	if not slotsPath then
		Utils.notify("Error", "Failed to access player slots", "x")
		return
	end

	local slotChildren = slotsPath:GetChildren()
	table.sort(slotChildren, function(a, b)
		return a.Name < b.Name
	end)

	for _, slotInstance in ipairs(slotChildren) do
		if slotInstance:IsA("StringValue") then
			local slotIndex = tonumber(string.match(slotInstance.Name, "%d+"))
			if slotIndex and slotIndex <= CONFIG.AUTOMATION.MAX_SLOTS then
				State.units[slotIndex] = slotInstance.Value
			end
		end
	end
end

function GameAPI.getMousePosition()
	local hit = mouse.Hit
	return hit and hit.Position or Vector3.new(0, 0, 0)
end

function GameAPI.placeUnit(unitName, position)
	if not unitName or not position then
		return false
	end

	local success, err = pcall(function()
		local remotes = Utils.safeWaitForChild(Services.ReplicatedStorage, "Remotes")
		local placeTower = remotes and Utils.safeWaitForChild(remotes, "PlaceTower")

		if placeTower then
			placeTower:FireServer(tostring(unitName), CFrame.new(position))
			return true
		end
		return false
	end)

	if not success then
		Utils.notify("Error", "Failed to place unit: " .. tostring(err), "x")
		return false
	end
	return true
end

function GameAPI.setServerAutoUpgrade(towerInstance)
	if not towerInstance then
		return false
	end

	local success, err = pcall(function()
		local remotes = Utils.safeWaitForChild(Services.ReplicatedStorage, "Remotes")
		local unitManager = remotes and Utils.safeWaitForChild(remotes, "UnitManager")
		local autoUpgrade = unitManager and Utils.safeWaitForChild(unitManager, "SetAutoUpgrade")

		if autoUpgrade then
			autoUpgrade:FireServer(towerInstance, true)
			return true
		end
		return false
	end)

	if not success then
		Utils.notify("Error", "Failed to enable auto-upgrade: " .. tostring(err), "x")
		return false
	end
	return true
end

function GameAPI.summonUnits(amount, banner)
	if not amount or not banner then
		return false
	end

	local success, err = pcall(function()
		local remotes = Utils.safeWaitForChild(Services.ReplicatedStorage, "Remotes")
		local summon = remotes and Utils.safeWaitForChild(remotes, "Summon")

		if summon then
			summon:InvokeServer(tonumber(amount), tostring(banner))
			return true
		end
		return false
	end)

	if not success then
		Utils.notify("Error", "Failed to summon: " .. tostring(err), "x")
		return false
	end
	return true
end

local PositionManager = {}

function PositionManager.save()
	if not FileSystem.isfolder(CONFIG.FILES.FOLDER) then
		FileSystem.makefolder(CONFIG.FILES.FOLDER)
	end

	local positionsToSave = {}
	for i = 1, CONFIG.AUTOMATION.MAX_SLOTS do
		if State.unitData[i].position then
			positionsToSave["Slot" .. i] = {
				x = State.unitData[i].position.X,
				y = State.unitData[i].position.Y,
				z = State.unitData[i].position.Z,
			}
		end
	end

	local success, err = pcall(function()
		FileSystem.writefile(CONFIG.FILES.POSITIONS, Services.HttpService:JSONEncode(positionsToSave))
	end)

	if not success then
		Utils.notify("Error", "Failed to save positions: " .. tostring(err), "x")
	end
end

function PositionManager.load()
	if not FileSystem.isfile(CONFIG.FILES.POSITIONS) then
		return
	end

	local success, data = pcall(function()
		return Services.HttpService:JSONDecode(FileSystem.readfile(CONFIG.FILES.POSITIONS))
	end)

	if success and data then
		for slotName, posData in pairs(data) do
			local slotIndex = tonumber(string.match(slotName, "%d+"))
			if slotIndex and State.unitData[slotIndex] and State.unitData[slotIndex].positionLabel then
				local loadedPos = Vector3.new(posData.x, posData.y, posData.z)
				State.unitData[slotIndex].position = loadedPos
				State.unitData[slotIndex].positionLabel:Set("Position: " .. tostring(loadedPos))
			end
		end
	else
		Utils.notify("Warning", "Failed to load saved positions", "warning")
	end
end

local AutomationManager = {}

function AutomationManager.init()
	GameAPI.getUnits()

	local automationTab = Window:CreateTab("Automation", "rotate-ccw")

	for i = 1, CONFIG.AUTOMATION.MAX_SLOTS do
		AutomationManager.createSlotUI(automationTab, i)
	end

	AutomationManager.setupInputHandler()
	AutomationManager.startAutoUpgradeLoop()
end

function AutomationManager.createSlotUI(tab, slotIndex)
	local unitName = State.units[slotIndex] or "Empty Slot"
	local isSlotEmpty = not State.units[slotIndex]

	tab:CreateDivider()
	local sectionLabel = tab:CreateLabel(string.format("Slot %d: %s", slotIndex, unitName))
	if isSlotEmpty then
		sectionLabel:SetColor(Color3.fromRGB(180, 180, 180))
	end

	State.unitData[slotIndex].positionLabel = tab:CreateLabel("Position: Not Set", "arrow-down-to-dot")

	State.unitData[slotIndex].positionBtn = tab:CreateButton({
		Name = "Set Position",
		Callback = function()
			State.unitData[slotIndex].isWaitingForClick = not State.unitData[slotIndex].isWaitingForClick
			if State.unitData[slotIndex].isWaitingForClick then
				State.unitData[slotIndex].positionBtn:Set("Waiting for click...")
			else
				State.unitData[slotIndex].positionBtn:Set("Set Position")
			end
		end,
	})

	tab:CreateToggle({
		Name = "Auto Place Unit",
		CurrentValue = false,
		Flag = "APU" .. slotIndex,
		Enabled = not isSlotEmpty,
		Callback = function(Value)
			if Value then
				local loopTask = Utils.createTask(function()
					while Value and Rayfield do
						if State.units[slotIndex] and State.unitData[slotIndex].position then
							GameAPI.placeUnit(State.units[slotIndex], State.unitData[slotIndex].position)
						end
						task.wait(CONFIG.AUTOMATION.AUTO_PLACE_INTERVAL)
					end
				end)
			end
		end,
	})

	tab:CreateToggle({
		Name = "Enable Auto-Upgrade",
		CurrentValue = false,
		Flag = "AU" .. slotIndex,
		Enabled = not isSlotEmpty,
		Callback = function(Value)
			State.unitData[slotIndex].enableServerAutoUpgrade = Value
		end,
	})
end

function AutomationManager.setupInputHandler()
	Utils.safeConnect(Services.UserInputService.InputBegan, function(input, gameProcessedEvent)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessedEvent then
			for i = 1, CONFIG.AUTOMATION.MAX_SLOTS do
				if State.unitData[i].isWaitingForClick then
					State.unitData[i].position = GameAPI.getMousePosition()
					State.unitData[i].positionLabel:Set("Position: " .. tostring(State.unitData[i].position))
					State.unitData[i].isWaitingForClick = false
					if State.unitData[i].positionBtn then
						State.unitData[i].positionBtn:Set("Set Position")
					end
					PositionManager.save()
					break
				end
			end
		end
	end)
end

function AutomationManager.startAutoUpgradeLoop()
	Utils.createTask(function()
		local placementLimits = Utils.safeWaitForChild(localPlayer, "PlacementLimits")
		local towersFolder = Utils.safeWaitForChild(workspace, "Towers")

		if not placementLimits or not towersFolder then
			Utils.notify("Error", "Failed to initialize auto-upgrade system", "x")
			return
		end

		while task.wait(CONFIG.AUTOMATION.AUTO_UPGRADE_INTERVAL) do
			if not Rayfield then
				break
			end

			local placedUnits = {}
			for _, limitValue in ipairs(placementLimits:GetChildren()) do
				if limitValue:IsA("IntValue") then
					placedUnits[limitValue.Name] = true
				end
			end

			for unitName, _ in pairs(placedUnits) do
				local towerInstance = towersFolder:FindFirstChild(unitName)

				if towerInstance and not State.processedTowers[towerInstance] then
					for i = 1, CONFIG.AUTOMATION.MAX_SLOTS do
						if State.unitData[i].enableServerAutoUpgrade and State.unitData[i].position then
							local distance = (towerInstance.PrimaryPart.Position - State.unitData[i].position).Magnitude
							if distance < CONFIG.AUTOMATION.PLACEMENT_CHECK_RADIUS then
								GameAPI.setServerAutoUpgrade(towerInstance)
								State.processedTowers[towerInstance] = true
								break
							end
						end
					end
				end
			end

			for tower, _ in pairs(State.processedTowers) do
				if not tower.Parent then
					State.processedTowers[tower] = nil
				end
			end
		end
	end)
end

local SummonManager = {}

function SummonManager.init()
	local summonTab = Window:CreateTab("Summon", "user")

	local summonAmountInput = summonTab:CreateInput({
		Name = "Summon Amount",
		CurrentValue = "1",
		PlaceholderText = "Enter amount (max 10)",
		RemoveTextAfterFocusLost = false,
		Flag = "SummonAmount",
		Callback = function(Text)
			local amount = Utils.validateNumber(Text, 1, CONFIG.SUMMON.MAX_AMOUNT, 1)
			if amount ~= tonumber(Text) then
				Utils.notify("Error", string.format("Amount must be between 1 and %d", CONFIG.SUMMON.MAX_AMOUNT), "x")
				summonAmountInput:Set(tostring(amount))
			end
			State.summonConfig.amount = amount
		end,
	})

	summonTab:CreateDropdown({
		Name = "Select Banner",
		Options = CONFIG.SUMMON.BANNERS,
		CurrentOption = { State.summonConfig.selectedBanner },
		MultipleOptions = false,
		Flag = "BannerSelection",
		Callback = function(Options)
			State.summonConfig.selectedBanner = Options[1]
		end,
	})

	local delayInput = summonTab:CreateInput({
		Name = "Summon Delay (Seconds)",
		CurrentValue = tostring(CONFIG.SUMMON.DEFAULT_DELAY),
		PlaceholderText = tostring(CONFIG.SUMMON.MIN_DELAY),
		RemoveTextAfterFocusLost = false,
		Flag = "SummonDelay",
		Callback = function(Text)
			local delay = Utils.validateNumber(Text, CONFIG.SUMMON.MIN_DELAY, nil, CONFIG.SUMMON.DEFAULT_DELAY)
			if delay < CONFIG.SUMMON.MIN_DELAY then
				Utils.notify("Error", string.format("Delay must be at least %s seconds", CONFIG.SUMMON.MIN_DELAY), "x")
				delayInput:Set(tostring(CONFIG.SUMMON.MIN_DELAY))
				delay = CONFIG.SUMMON.MIN_DELAY
			end
			State.summonConfig.delay = delay
		end,
	})

	local autoSummonToggle = summonTab:CreateToggle({
		Name = "Auto Summon",
		CurrentValue = false,
		Flag = "AutoSummon",
		Callback = function(Value)
			State.autoSummonEnabled = Value
			if State.autoSummonEnabled then
				SummonManager.startAutoSummon(autoSummonToggle)
			end
		end,
	})
end

function SummonManager.startAutoSummon(toggleRef)
	Utils.createTask(function()
		while State.autoSummonEnabled and Rayfield do
			if not (State.summonConfig.selectedBanner and State.summonConfig.amount > 0) then
				Utils.notify("Error", "Please select a valid banner and amount.", "x")
				if toggleRef then
					toggleRef:Set(false)
				end
				State.autoSummonEnabled = false
				break
			end

			GameAPI.summonUnits(State.summonConfig.amount, State.summonConfig.selectedBanner)
			task.wait(State.summonConfig.delay)
		end
	end)
end

local MiscManager = {}

function MiscManager.init()
	local miscTab = Window:CreateTab("Misc", "settings")

	miscTab:CreateButton({
		Name = "Join Discord",
		Callback = function()
			if FileSystem.setclipboard then
				FileSystem.setclipboard("discord.gg/soaHub")
				Utils.notify("Success", "Discord link copied to clipboard!", "check")
			else
				Utils.notify("Info", "Discord: discord.gg/soaHub", "info")
			end
		end,
	})

	miscTab:CreateButton({
		Name = "Destroy UI",
		Callback = function()
			cleanupApplication()
			Rayfield:Destroy()
		end,
	})
end

function cleanupApplication()
	for _, connection in ipairs(State.connections) do
		if typeof(connection) == "RBXScriptConnection" and connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(State.connections)

	for _, loopTask in ipairs(State.loops) do
		task.cancel(loopTask)
	end
	table.clear(State.loops)

	table.clear(State.processedTowers)
	State.autoSummonEnabled = false
end

local function initializeApplication()
	AutomationManager.init()
	SummonManager.init()
	MiscManager.init()

	PositionManager.load()
	Rayfield:LoadConfiguration()

	Utils.notify("Success", "Soa Hub loaded successfully!", "check")

	Utils.safeConnect(game:GetService("CoreGui").ChildRemoved, function(child)
		if child.Name == "Rayfield" then
			cleanupApplication()
		end
	end)
end

initializeApplication()
