local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Rayfield Example Window",
	Icon = 0, -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
	LoadingTitle = "Rayfield Interface Suite",
	LoadingSubtitle = "by Sirius",
	ShowText = "Rayfield", -- for mobile users to unhide rayfield, change if you'd like
	Theme = "Default", -- Check https://docs.sirius.menu/rayfield/configuration/themes

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

function notifyPlayer(title, content, duration, image)
	Rayfield:Notify({
		Title = title,
		Content = content,
		Duration = duration,
		Image = tostring(image),
	})
end

function getMousePosition()
	local mousePos = UserInputService:GetMouseLocation()
	return mousePos
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

local unit1Position = nil
local Unit1Position = AutomationTab:CreateLabel(
	"Unit 1 Position: " .. tostring(unit1Position),
	"arrow-down-to-dot",
	Color3.fromRGB(123, 123, 123),
	false
)

local unit1PositionBtn = AutomationTab:CreateButton({
	Name = "Set Unit 1 Position",
	Callback = function()
		unit1Position = getMousePosition()
		Unit1Position:Set("Unit 1 Position: " .. tostring(unit1Position))
	end,
})

local autoPlace1 = AutomationTab:CreateToggle({
	Name = "Auto Place: Unit 1",
	CurrentValue = false,
	Flag = "APU1",
	Callback = function(Value) end,
})

--// DONT TOUCH.
Rayfield:LoadConfiguration()
