local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Soa Hub",
	Icon = "eye", -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
	LoadingTitle = "Soa Hub",
	LoadingSubtitle = "by Koda",
	ShowText = "Rayfield", -- for mobile users to unhide rayfield, change if you'd like
	Theme = "Amethyst", -- Check https://docs.sirius.menu/rayfield/configuration/themes

	ToggleUIKeybind = "K", -- The keybind to toggle the UI visibility (string like "K" or Enum.KeyCode)

	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false, -- Prevents Rayfield from warning when the script has a version mismatch with the interface

	ConfigurationSaving = {
		Enabled = true,
		FolderName = "soaHub", -- Create a custom folder for your hub/game
		FileName = "alsCFG",
	},

	Discord = {
		Enabled = false, -- Prompt the user to join your Discord server if their executor supports it
		Invite = "noinvitelink", -- The Discord invite code, do not include discord.gg/. E.g. discord.gg/ ABCD would be ABCD
		RememberJoins = true, -- Set this to false to make them join the discord every time they load it up
	},

	KeySystem = false,

	KeySettings = {
		Title = "Untitled",
		Subtitle = "Key System",
		Note = "No method of obtaining the key is provided", -- Use this to tell the user how to get a key
		FileName = "Key", -- It is recommended to use something unique as other scripts using Rayfield may overwrite your key file
		SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
		GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
		Key = { "Hello" }, -- List of keys that will be accepted by the system, can be RAW file links (pastebin, github etc) or simple strings ("hello","key22")
	},
})

--// Functionality

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()
local units = {}

function notifyPlayer(title, content, duration, image)
	Rayfield:Notify({
		Title = title,
		Content = content,
		Duration = duration,
		Image = tostring(image),
	})
end

function getUnits()
	local unitsPath = game:GetService("Players").LocalPlayer.Slots

	for _, unit in ipairs(unitsPath:GetChildren()) do
		if unit:IsA("StringValue") then
			table.insert(units, unit.Value)
		end
	end
end

getUnits()

function getMousePosition()
	return mouse.Hit.p
end

function placeUnit(unit, position)
	local args = {
		tostring(unit),
		CFrame.new(position),
	}
	game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("PlaceTower"):FireServer(unpack(args))
end

function upgradeUnit(unit, upgradeAmount)
	upgradeAmount = tonumber(upgradeAmount) or 1

	for i = 1, upgradeAmount do
		local args = {
			workspace:WaitForChild("Towers"):WaitForChild(tostring(unit)),
		}
		game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Upgrade"):InvokeServer(unpack(args))
	end
end

--// UI Declaration
local AutomationTab = Window:CreateTab("Automation", "rotate-ccw")

--// UNIT 1
local Unit1Divider = AutomationTab:CreateDivider()
local unit1Position = nil
local isWaitingForUnit1Click = false
local unit1PositionBtn

local Unit1Position = AutomationTab:CreateLabel(
	"Unit 1 Position: " .. tostring(unit1Position),
	"arrow-down-to-dot",
	Color3.fromRGB(255, 255, 255),
	false
)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if isWaitingForUnit1Click and input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessedEvent then
		unit1Position = getMousePosition()
		Unit1Position:Set("Unit 1 Position: " .. tostring(unit1Position))

		isWaitingForUnit1Click = false
		if unit1PositionBtn then
			unit1PositionBtn:Set("Set Unit 1 Position")
		end
	end
end)

unit1PositionBtn = AutomationTab:CreateButton({
	Name = "Set Unit 1 Position",
	Callback = function()
		isWaitingForUnit1Click = not isWaitingForUnit1Click

		if isWaitingForUnit1Click then
			unit1PositionBtn:Set("Waiting for click...")
		else
			unit1PositionBtn:Set("Set Unit 1 Position")
		end
	end,
})

local autoPlace1 = AutomationTab:CreateToggle({
	Name = "Auto Place: Unit 1",
	CurrentValue = false,
	Flag = "APU1",
	Callback = function(Value)
		while Value do
			placeUnit("Unit1", unit1Position)
			task.wait(0.25)
		end
	end,
})

local autoUpgrade1 = AutomationTab:CreateToggle({
	Name = "Auto Upgrade: Unit 1",
	CurrentValue = false,
	Flag = "AU1",
	Callback = function(Value)
		while Value do
			if unit1Position then
				upgradeUnit("Unit1", 1)
			end
			task.wait(0.25)
		end
	end,
})

--// UNIT 2
local Unit2Divider = AutomationTab:CreateDivider()
local unit2Position = nil
local isWaitingForUnit2Click = false
local unit2PositionBtn

local Unit2Position = AutomationTab:CreateLabel(
	"Unit 2 Position: " .. tostring(unit2Position),
	"arrow-down-to-dot",
	Color3.fromRGB(255, 255, 255),
	false
)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if isWaitingForUnit2Click and input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessedEvent then
		unit2Position = getMousePosition()
		Unit2Position:Set("Unit 2 Position: " .. tostring(unit2Position))

		isWaitingForUnit2Click = false
		if unit2PositionBtn then
			unit2PositionBtn:Set("Set Unit 2 Position")
		end
	end
end)

unit2PositionBtn = AutomationTab:CreateButton({
	Name = "Set Unit 2 Position",
	Callback = function()
		isWaitingForUnit2Click = not isWaitingForUnit2Click

		if isWaitingForUnit2Click then
			unit2PositionBtn:Set("Waiting for click...")
		else
			unit2PositionBtn:Set("Set Unit 2 Position")
		end
	end,
})

local autoPlace2 = AutomationTab:CreateToggle({
	Name = "Auto Place: Unit 2",
	CurrentValue = false,
	Flag = "APU2",
	Callback = function(Value)
		while Value do
			if unit2Position then
				placeUnit("Unit2", unit2Position)
			end
			task.wait(0.25)
		end
	end,
})

local autoUpgrade2 = AutomationTab:CreateToggle({
	Name = "Auto Upgrade: Unit 2",
	CurrentValue = false,
	Flag = "AU2",
	Callback = function(Value)
		while Value do
			if unit2Position then
				upgradeUnit("Unit2", 1)
			end
			task.wait(0.25)
		end
	end,
})

--// DONT TOUCH.
Rayfield:LoadConfiguration()
