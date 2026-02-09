--
local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    Lighting = game:GetService("Lighting"),
    CoreGui = game:GetService("CoreGui"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    HttpService = game:GetService("HttpService"),
    TeleportService = game:GetService("TeleportService"),
}

local CONFIG = {
    AllowedPlaces = { [16472538603] = true, [18642421777] = true },
    StaffGroupId = 15022380,
    StaffRankMin = 220,
    QuoteIntervals = { Min = 45, Max = 300 },
}

if not CONFIG.AllowedPlaces[game.PlaceId] then
    task.defer(function()
        Services.Players.LocalPlayer:Kick("Wrong game location.")
    end)
    while true do task.wait() end
end

local LocalPlayer = Services.Players.LocalPlayer
while not LocalPlayer do task.wait() end

local AnchorSystem = {}
AnchorSystem.__index = AnchorSystem

function AnchorSystem.new()
    local self = setmetatable({}, AnchorSystem)
    self.Connections = {}
    self.TargetRoot = nil
    self.Enabled = false
    return self
end

function AnchorSystem:Attach(root)
    self:Detach()
    if not root or not root.Parent then return end
    self.TargetRoot = root
    table.insert(self.Connections, Services.RunService.PreSimulation:Connect(function()
        if self.Enabled and self.TargetRoot and self.TargetRoot.Parent then
            self.TargetRoot.Anchored = false
        end
    end))
    table.insert(self.Connections, Services.RunService.PostSimulation:Connect(function()
        if self.Enabled and self.TargetRoot and self.TargetRoot.Parent then
            self.TargetRoot.Anchored = true
        end
    end))
    self.Enabled = true
end

function AnchorSystem:Detach()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    self.Connections = {}
    if self.TargetRoot and self.TargetRoot.Parent then
        self.TargetRoot.Anchored = false
    end
    self.TargetRoot = nil
    self.Enabled = false
end

local CharacterLifecycle = {}
CharacterLifecycle.__index = CharacterLifecycle

function CharacterLifecycle.new(anchorSystem)
    assert(anchorSystem, "CharacterLifecycle requires AnchorSystem")

    local self = setmetatable({}, CharacterLifecycle)
    self.Anchor = anchorSystem
    self.Connections = {}
    self.CurrentChar = nil
    return self
end

function CharacterLifecycle:Initialize()
    table.insert(self.Connections, LocalPlayer.CharacterAdded:Connect(function(char)
        task.delay(0.2, function()
            self:TryApplyToCharacter(char)
        end)
    end))
    table.insert(self.Connections, LocalPlayer.CharacterRemoving:Connect(function(char)
        if char == self.CurrentChar then
            self:Clear()
        end
    end))
    if LocalPlayer.Character then
        task.defer(function()
            self:TryApplyToCharacter(LocalPlayer.Character)
        end)
    end
end

function CharacterLifecycle:TryApplyToCharacter(char)
    if self.CurrentChar == char then return end
    self:Clear()
    local hum = char:WaitForChild("Humanoid", 8)
    local root = char:WaitForChild("HumanoidRootPart", 8)
    if not (hum and root) then return end
    local stable = 0
    local last = root.Position
    for _ = 1, 60 do
        if not root.Parent or hum.Health <= 0 then return end
        local pos = root.Position
        if (pos - last).Magnitude < 0.12 then stable += 1 else stable = 0 end
        if stable >= 4 then break end
        last = pos
        task.wait()
    end
    if not root.Parent or hum.Health <= 0 then return end
    self.CurrentChar = char
    self.Anchor:Attach(root)
    table.insert(self.Connections, hum.Died:Connect(function()
        self:Clear()
    end))
end

function CharacterLifecycle:Clear()
    if not self then
        warn("Clear called with no self")
        return
    end

    if not self.Anchor then
        warn("Clear called but Anchor is nil")
    else
        if self.Anchor.Detach then
            self.Anchor:Detach()
        else
            warn("Anchor.Detach is nil")
        end
    end

    self.CurrentChar = nil
end

function CharacterLifecycle:Destroy()
    for _, c in ipairs(self.Connections) do c:Disconnect() end
    self:Clear()
end

local anchor = AnchorSystem.new()
local lifecycle = CharacterLifecycle.new(anchor)
lifecycle:Initialize()

local StaffAlertSystem = {}
StaffAlertSystem.__index = StaffAlertSystem

function StaffAlertSystem.new()
    local self = setmetatable({}, StaffAlertSystem)
    self.Blur = nil
    self.Gui = nil
    self.Frame = nil
    self.Title = nil
    self.Connections = {}
    return self
end

function StaffAlertSystem:BuildUI()
    self.Blur = Instance.new("BlurEffect")
    self.Blur.Size = 0
    self.Blur.Enabled = false
    self.Blur.Parent = Services.Lighting
    self.Gui = Instance.new("ScreenGui")
    self.Gui.Name = "FoundationOverlay"
    self.Gui.ResetOnSpawn = false
    self.Gui.Parent = Services.CoreGui
    self.Frame = Instance.new("Frame")
    self.Frame.Size = UDim2.new(0, 340, 0, 210)
    self.Frame.Position = UDim2.new(0.5, -170, 0.5, -105)
    self.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    self.Frame.BackgroundColor3 = Color3.fromRGB(18,18,22)
    self.Frame.BackgroundTransparency = 0.25
    self.Frame.BorderSizePixel = 0
    self.Frame.Visible = false
    self.Frame.Parent = self.Gui
    Instance.new("UICorner", self.Frame).CornerRadius = UDim.new(0, 12)
    self.Title = Instance.new("TextLabel")
    self.Title.Size = UDim2.new(1, -24, 0, 90)
    self.Title.Position = UDim2.new(0,12,0,12)
    self.Title.BackgroundTransparency = 1
    self.Title.TextColor3 = Color3.new(1,1,1)
    self.Title.Font = Enum.Font.GothamBold
    self.Title.TextSize = 18
    self.Title.TextWrapped = true
    self.Title.Text = ""
    self.Title.Parent = self.Frame
    local stay = Instance.new("TextButton")
    stay.Size = UDim2.new(0.42,0,0,50)
    stay.Position = UDim2.new(0.06,0,1,-62)
    stay.BackgroundColor3 = Color3.fromRGB(40,180,60)
    stay.TextColor3 = Color3.new(1,1,1)
    stay.Font = Enum.Font.GothamSemibold
    stay.TextSize = 16
    stay.Text = "Stay"
    stay.Parent = self.Frame
    Instance.new("UICorner", stay).CornerRadius = UDim.new(0,8)
    local hop = stay:Clone()
    hop.Text = "Server Hop"
    hop.Position = UDim2.new(0.52,0,1,-62)
    hop.BackgroundColor3 = Color3.fromRGB(220,60,60)
    hop.Parent = self.Frame
    stay.MouseButton1Click:Connect(function()
        self:Hide()
    end)
    hop.MouseButton1Click:Connect(function()
        self:ServerHop()
    end)
end

function StaffAlertSystem:Show(message)
    if not self.Frame then self:BuildUI() end
    self.Title.Text = message
    self.Blur.Size = 24
    self.Blur.Enabled = true
    self.Frame.Visible = true
end

function StaffAlertSystem:Hide()
    if self.Blur then
        self.Blur.Enabled = false
        self.Blur.Size = 0
    end
    if self.Frame then
        self.Frame.Visible = false
    end
end

function StaffAlertSystem:ServerHop()
    task.spawn(function()
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
        local ok, resp = pcall(request, {Url = url, Method = "GET"})
        if not ok or not resp or not resp.Body then return end
        local data = Services.HttpService:JSONDecode(resp.Body)
        for _, s in ipairs(data.data or {}) do
            if s.playing < s.maxPlayers then
                Services.TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id)
                return
            end
        end
    end)
end

function StaffAlertSystem:CheckPlayer(player)
    task.spawn(function()
        local ok, res = pcall(request, {
            Url = "https://groups.roblox.com/v1/users/"..player.UserId.."/groups/roles",
            Method = "GET"
        })
        if not ok or not res or not res.Body then return end
        local groups = Services.HttpService:JSONDecode(res.Body)
        for _, g in ipairs(groups.data or {}) do
            if g.group and g.group.id == CONFIG.StaffGroupId and g.role and g.role.rank >= CONFIG.StaffRankMin then
                local msg = ("%s\n%s (Rank %d)\nLeave server?"):format(
                    player.Name, g.role.name or "?", g.role.rank)
                self:Show(msg)
                warn("[STAFF] " .. msg:gsub("\n"," "))
                return
            end
        end
    end)
end

function StaffAlertSystem:WatchPlayers()
    for _, p in Services.Players:GetPlayers() do
        if p ~= LocalPlayer then self:CheckPlayer(p) end
    end
    table.insert(self.Connections, Services.Players.PlayerAdded:Connect(function(p)
        if p ~= LocalPlayer then task.delay(1.3, function() self:CheckPlayer(p) end) end
    end))
end

function StaffAlertSystem:Destroy()
    for _, c in self.Connections do c:Disconnect() end
    if self.Blur then self.Blur:Destroy() end
    if self.Gui then self.Gui:Destroy() end
end

local QuoteSystem = {}
QuoteSystem.__index = QuoteSystem

function QuoteSystem.new()
    local self = setmetatable({}, QuoteSystem)
    self.Running = false
    self.Task = nil
    self.SessionStart = os.clock()
    self.Event = Services.ReplicatedStorage:WaitForChild("server", 8)
    return self
end

function QuoteSystem:GetPlaytime()
    return math.floor((os.clock() - self.SessionStart) / 60)
end

local BaseQuotes = {
    "Cobra.gg Is #1",
    "RIP BypassHub...",
    "Did You Know Im Looking Through Your Webcam 😛",
    "Cobra.gg - Your Final Destination For Exploits!",
    "Did You Know I Wrote 205 Of These",
    "1370+ Loyal Buyers",
    "Why You So Broke?",
    "Did You Know This Script Has Over 120 Features",
    "80k+ Monthly Executions",
    "Cobra.gg",
    "200k+ Monthly Executions At Peak",
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
}

local TimeQuotes = {
    "{user} has been in-game for {time} minutes… still broke?",
    "{user} really sat here for {time} minutes just to lose 😭",
    "Imagine playing {time} minutes and still being a pooron, @{user}",
    "{user}, {time} minutes of gameplay and still no motion",
    "Cobra.gg been running for {time} minutes straight 😈",
    "{user} think about those {time} minutes you'll never get back",
    "{user} loading excuses after {time} minutes",
    "{user} really clocked {time} minutes for THIS outcome",
    "{user} really sat here for {time} minutes playing WOW",
}

function QuoteSystem:GetRandom()
    if self:GetPlaytime() >= 30 and math.random() < 0.5 then
        return TimeQuotes[math.random(1, #TimeQuotes)]
    end
    return BaseQuotes[math.random(1, #BaseQuotes)]
end

function QuoteSystem:Format(str)
    return str
        :gsub("{user}", LocalPlayer.Name or "Player")
        :gsub("{time}", tostring(self:GetPlaytime()))
end

function QuoteSystem:Fire(msg)
    if self.Event and self.Running then
        firesignal(self.Event.OnClientEvent, "money", msg)
    end
end

function QuoteSystem:Start()
    if self.Running then return end
    self.Running = true
    self.Task = task.spawn(function()
        self:Fire("Welcome • Final Destination For Exploits")
        while self.Running do
            local q = self:GetRandom()
            self:Fire(self:Format(q))
            task.wait(math.random(CONFIG.QuoteIntervals.Min, CONFIG.QuoteIntervals.Max))
        end
    end)
end

function QuoteSystem:Stop()
    self.Running = false
    if self.Task then task.cancel(self.Task) self.Task = nil end
end

local function UnloadAll(systems)
    for _, sys in pairs(systems) do
        if sys.Stop then sys:Stop() end
        if sys.Destroy then sys:Destroy() end
        if sys.Detach then sys:Detach() end
    end
    getgenv().CobraUnload = nil
end

local Anchor = AnchorSystem.new()
local CharLife = CharacterLifecycle.new(Anchor)
local Alerts = StaffAlertSystem.new()
local Quotes = QuoteSystem.new()

CharLife:Initialize()
Alerts:WatchPlayers()
Quotes:Start()

getgenv().CobraUnload = function()
    UnloadAll({
        Anchor = Anchor,
        CharLife = CharLife,
        Alerts = Alerts,
        Quotes = Quotes,
    })
end

getgenv().DetectedPlayers = getgenv().DetectedPlayers or {}
getgenv().GodmodeNotified = getgenv().GodmodeNotified or {}

getgenv().isSeat = function(part)
	return part and (part:IsA("Seat") or part:IsA("VehicleSeat"))
end

getgenv().notify = function(player, message)
	if Library and Library.Notify then
		Library:Notify(player.Name .. " " .. message, 3)
	else
		warn( .. player.Name .. " " .. message)
	end
end

getgenv().alert = function(player, reason)
	if not DetectedPlayers[player] then
		DetectedPlayers[player] = {
			TeleportFlagged = false,
			StateFlagged = false,
		}

		if Toggles and Toggles.EnableExploitNotify and Toggles.EnableExploitNotify.Value then
			notify(player, "Has Set Off An Exploit Detection. THEY ARE MOST LIKELY CHEATING")
		end
	end

	if reason == "Teleport" then
		if not DetectedPlayers[player].TeleportFlagged then
			DetectedPlayers[player].TeleportFlagged = true
			if Toggles and Toggles.EnableTeleportNotify and Toggles.EnableTeleportNotify.Value then
				notify(player, "Has Teleported")
			end
		end
	end

	if reason == "MovementState" and not DetectedPlayers[player].StateFlagged then
		DetectedPlayers[player].StateFlagged = true
	end
end

getgenv().monitorPlayer = function(player)
	local function setupCharacter(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root then return end

		task.spawn(function()
			while humanoid.Parent and player.Parent do
				if typeof(humanoid.Health) == "number" and humanoid.Health ~= humanoid.Health then
					if not GodmodeNotified[player]
						and Toggles
						and Toggles.EnableGodmodeNotify
						and Toggles.EnableGodmodeNotify.Value then

						GodmodeNotified[player] = true
						notify(player, "Is In Godmode (Probably Not A Cheater)")
					end
				end
				task.wait(1)
			end
		end)

		local STATE_GRACE = 2
		local activeState = nil
		local stateStart = 0
		local stateThread = nil

		local function clearState()
			activeState = nil
			stateStart = 0
			if stateThread then
				task.cancel(stateThread)
				stateThread = nil
			end
		end

		local function watchState(state)
			clearState()
			activeState = state
			stateStart = os.clock()

			stateThread = task.spawn(function()
				while humanoid.Parent and player.Parent do
					task.wait(0.1)

					if humanoid.Health <= 0 then
						return
					end

					if humanoid:GetState() ~= state then
						return
					end

					if os.clock() - stateStart >= STATE_GRACE then
						if state == Enum.HumanoidStateType.Freefall
						or state == Enum.HumanoidStateType.FallingDown then
							if humanoid.FloorMaterial == Enum.Material.Air then
								return
							end
						end

						alert(player, "MovementState")
						return
					end
				end
			end)
		end

		humanoid.StateChanged:Connect(function(_, newState)
			if humanoid.Health <= 0 then
				clearState()
				return
			end

			if newState == Enum.HumanoidStateType.Seated then
				task.delay(0.1, function()
					if humanoid:GetState() == Enum.HumanoidStateType.Seated then
						if not isSeat(humanoid.SeatPart) then
							alert(player, "FakeSeat")
						end
					end
				end)
				return
			end

			if newState == Enum.HumanoidStateType.Physics
			or newState == Enum.HumanoidStateType.Freefall
			or newState == Enum.HumanoidStateType.FallingDown
			or newState == Enum.HumanoidStateType.None then
				watchState(newState)
			else
				clearState()
			end
		end)
	end

	player:GetAttributeChangedSignal("LastACPos"):Connect(function()
		if player:GetAttribute("LastACPos") == nil then
			alert(player, "Teleport")
		end
	end)

	if player.Character then
		setupCharacter(player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)
end

for _, player in ipairs(Services.Players:GetPlayers()) do
	if player ~= LocalPlayer then
		monitorPlayer(player)
	end
end

Services.Players.PlayerAdded:Connect(function(player)
	if player ~= LocalPlayer then
		monitorPlayer(player)
	end
end)

return "success"
