local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ALLOWED_PLACE_IDS = {
    [16472538603] = true,
    [18642421777] = true
}

if not ALLOWED_PLACE_IDS[game.PlaceId] then
    task.defer(function()
        game.Players.LocalPlayer:Kick("Wyd Retard Wrong Game")
    end)
    while true do task.wait() end
end

task.wait()

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
	Players.PlayerAdded:Wait()
	LocalPlayer = Players.LocalPlayer
end

local PreSimConn
local PostSimConn
local CharacterAddedConn
local CharacterRemovingConn
local HumanoidDiedConn

local ActiveCharacter = nil
local ActiveRoot = nil
local ActiveHumanoid = nil

local function CleanupCharacter()
	if PreSimConn then PreSimConn:Disconnect() PreSimConn = nil end
	if PostSimConn then PostSimConn:Disconnect() PostSimConn = nil end
	if HumanoidDiedConn then HumanoidDiedConn:Disconnect() HumanoidDiedConn = nil end

	ActiveCharacter = nil
	ActiveRoot = nil
	ActiveHumanoid = nil
end

local function WaitForRealCharacter(Character)
	local Humanoid = Character:WaitForChild("Humanoid", 5)
	local Root = Character:WaitForChild("HumanoidRootPart", 5)
	if not Humanoid or not Root then return nil end

	local lastCF
	local stableFrames = 0

	for _ = 1, 120 do
		if not Root.Parent or Humanoid.Health <= 0 then
			return nil
		end

		local cf = Root.CFrame
		if lastCF and (cf.Position - lastCF.Position).Magnitude < 0.05 then
			stableFrames += 1
		else
			stableFrames = 0
		end

		if stableFrames >= 5 then
			return Humanoid, Root
		end

		lastCF = cf
		RunService.Heartbeat:Wait()
	end

	return nil
end

local function ApplyToCharacter(Character)
	if ActiveCharacter == Character then return end

	CleanupCharacter()

	local Humanoid, Root = WaitForRealCharacter(Character)
	if not Humanoid or not Root then return end

	ActiveCharacter = Character
	ActiveHumanoid = Humanoid
	ActiveRoot = Root

	HumanoidDiedConn = Humanoid.Died:Connect(function()
		CleanupCharacter()
	end)

	PreSimConn = RunService.PreSimulation:Connect(function()
		if ActiveRoot and ActiveRoot.Parent and ActiveHumanoid and ActiveHumanoid.Health > 0 then
			ActiveRoot.Anchored = false
		end
	end)

	PostSimConn = RunService.PostSimulation:Connect(function()
		if ActiveRoot and ActiveRoot.Parent and ActiveHumanoid and ActiveHumanoid.Health > 0 then
			ActiveRoot.Anchored = true
		end
	end)
end

local function SetupCharacterWatch()
	if CharacterAddedConn then CharacterAddedConn:Disconnect() end
	if CharacterRemovingConn then CharacterRemovingConn:Disconnect() end

	CharacterAddedConn = LocalPlayer.CharacterAdded:Connect(function(Character)
		task.delay(0.2, function()
			ApplyToCharacter(Character)
		end)
	end)

	CharacterRemovingConn = LocalPlayer.CharacterRemoving:Connect(function(Character)
		if Character == ActiveCharacter then
			CleanupCharacter()
		end
	end)

	if LocalPlayer.Character then
		task.defer(function()
			ApplyToCharacter(LocalPlayer.Character)
		end)
	end
end

SetupCharacterWatch()
task.wait(1)

local GROUP_ID = 15022380 
local RANK_THRESHOLD = 220

local blur = Instance.new("BlurEffect", Lighting)
blur.Size = 0
blur.Enabled = false

local screenGui = Instance.new("ScreenGui", CoreGui)
screenGui.Name = "FoundationOverlay"

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 300, 0, 180)
frame.Position = UDim2.new(0.5, -150, 0.5, -90)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.Visible = false
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -20, 0, 60)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextWrapped = true
title.Text = ""

local buttonStay = Instance.new("TextButton", frame)
buttonStay.Size = UDim2.new(0.45, 0, 0, 40)
buttonStay.Position = UDim2.new(0.05, 0, 1, -50)
buttonStay.Text = "Stay"
buttonStay.Font = Enum.Font.Gotham
buttonStay.TextSize = 14
buttonStay.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
buttonStay.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", buttonStay).CornerRadius = UDim.new(0, 6)

local buttonHop = buttonStay:Clone()
buttonHop.Text = "Server Hop"
buttonHop.Position = UDim2.new(0.5, 0, 1, -50)
buttonHop.Parent = frame

buttonHop.MouseButton1Click:Connect(function()
	local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
	local response = request({Url = url, Method = "GET"})
    local HttpService = game:GetService("HttpService")
	local data = HttpService:JSONDecode(response.Body)
    local TeleportService = game:GetService("TeleportService")
	for _, server in ipairs(data.data) do
		if server.playing < server.maxPlayers then
			TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
			break
		end
	end
end)

buttonStay.MouseButton1Click:Connect(function()
	blur.Enabled = false
	blur.Size = 0
	frame.Visible = false
end)

local function checkPlayer(userId, playerName)
local HttpService = game:GetService("HttpService")
	local success, result = pcall(function()
		local res = request({
			Url = "https://groups.roblox.com/v1/users/" .. userId .. "/groups/roles",
			Method = "GET"
		})
		return HttpService:JSONDecode(res.Body)
	end)

	if not success then return end

	for _, group in ipairs(result) do
		if group.group.id == GROUP_ID then
			local rank = group.role.rank
			local roleName = group.role.name
			if rank >= RANK_THRESHOLD then
				warn(playerName .. " is rank " .. rank .. " (" .. roleName .. ")")
				Library:Notify(playerName .. " is " .. roleName .. " (Rank " .. rank .. ")", 3)
				blur.Enabled = true
				blur.Size = 24
				title.Text = playerName .. " is " .. roleName .. "\n(Rank " .. rank .. ")\nDo you want to leave?"
				frame.Visible = true
			end
		end
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then
		task.spawn(function()
			checkPlayer(player.UserId, player.Name)
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.wait(1)
	checkPlayer(player.UserId, player.Name)
end)
task.wait()

local function SafeRef(obj)
	return (cloneref and cloneref(obj)) or obj
end

local Event = SafeRef(ReplicatedStorage:WaitForChild("server"))
local running = true
local quoteTask = nil

local sessionStart = os.clock()

local function GetPlaytimeMinutes()
	return math.floor((os.clock() - sessionStart) / 60)
end

local quotes = {
	"Cobra.gg Is #1",
	"RIP BypassHub...",
	"Did You Know Im Looking Through Your Webcam 😛",
	"Cobra.gg - Your Final Destination For Exploits!",
	"Did You Know I Wrote 205 Of These",
	"1300+ Loyal Buyers",
	"Why You So Broke?",
	"Did You Know This Script Has Over 120 Features",
	"50k+ Monthly Executions",
	"Cobra.gg",
	"100k+ Monthly Executions At Peak",
	"#1 TB3 Script",
	"I Love You ❤️",
	"Leave That Vouch Monkey",
	"Stop Dickriding 🍆🚴",
	"Highest Quality TB3 Script",
	"Best Combat Features",
	"#1 Skid Tickler",
	"You're Executor Is Shitty",
	"Yes, Cobra.gg Is The Best",
	"...!: I hate skids!",

	"{user} has been in-game for {time} minutes… still broke?",
	"{user} really sat here for {time} minutes just to lose 😭",
	"Imagine playing {time} minutes and still being a pooron, @{user}",
	"{user}, {time} minutes of gameplay and still no motion",
	"Cobra.gg been running for {time} minutes straight 😈",
	"{user} think about those {time} minutes you’ll never get back",
	"{user} loading excuses after {time} minutes",
	"{user} really clocked {time} minutes for THIS outcome",
	"{user} really sat here for {time} minutes playing WOW",
}

local minInterval = 2
local maxInterval = 10

local function FormatQuote(raw)
	return raw
		:gsub("{user}", LocalPlayer.Name)
		:gsub("{time}", tostring(GetPlaytimeMinutes()))
end

local function FireMessage(message)
	if not running then return end
	firesignal(Event.OnClientEvent, "money", message)
end

local function StartQuotes()
	if quoteTask then return end

	quoteTask = task.spawn(function()
		while running do
			local raw = quotes[math.random(1, #quotes)]
			FireMessage(FormatQuote(raw))
			task.wait(math.random(minInterval, maxInterval))
		end
	end)
end

local function StopQuotes()
	running = false
	if quoteTask then
		task.cancel(quoteTask)
		quoteTask = nil
	end
end

FireMessage("Welcome To Your Final Destination For Exploits")
StartQuotes()

getgenv().StopCobraQuotes = StopQuotes
return "success"
