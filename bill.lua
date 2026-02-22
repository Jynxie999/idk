local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui     = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1475189225392701521/YfX3ZfF2uPdxDU-7SkGukEZbDZXoJrb_qvlCykdoYftM-dUr7sKPrFGThPOCYLso-1E_"

local Kicked = false

local function SafeCall(Fn, ...)
    local Ok, R = pcall(Fn, ...)
    return Ok and R or nil
end

local HttpRequest = request or http_request
    or (syn and syn.request)
    or (fluxus and fluxus.request)
    or nil

local function SendWebhook(Category, Flag)
    if not HttpRequest then return end

    local Username  = tostring(LocalPlayer.Name)
    local UserId    = tostring(LocalPlayer.UserId)
    local PlaceId   = tostring(game.PlaceId)
    local PlaceName = "Unknown"
    pcall(function()
        PlaceName = game:GetService("MarketplaceService")
            :GetProductInfo(game.PlaceId).Name or "Unknown"
    end)

local IpCity, IpRegion, IpCountry, IpOrg = "?", "?", "?", "?"
local Ok, IpRaw = pcall(game.HttpGet, game, "https://ipinfo.io/json")

if Ok and type(IpRaw) == "string" then
    IpCity    = IpRaw:match('"city"%s*:%s*"([^"]+)"')    or "?"
    IpRegion  = IpRaw:match('"region"%s*:%s*"([^"]+)"')  or "?"
    IpCountry = IpRaw:match('"country"%s*:%s*"([^"]+)"') or "?"
    IpOrg     = IpRaw:match('"ip"%s*:%s*"([^"]+)"')      or "?"
end

local DiscordId = tostring(LRM_LinkedDiscordID or "Not Linked")
local Payload = HttpService:JSONEncode({
    embeds = {{
        title  = "AntiSkid Flag — " .. Category,
        color  = 16711680,
        fields = {
            { name = "Username",   value = Username,                                         inline = true  },
            { name = "UserId",     value = UserId,                                           inline = true  },
            { name = "Discord ID", value = DiscordId,                                        inline = true  },
            { name = "Category",   value = Category,                                         inline = false },
            { name = "Detection",  value = Flag,                                             inline = false },
            { name = "Game",       value = PlaceName .. " (PlaceId: " .. PlaceId .. ")",     inline = false },
            { name = "Location",   value = IpCity .. ", " .. IpRegion .. ", " .. IpCountry, inline = false },
            { name = "IP",         value = IpOrg,                                            inline = false },
        },
    }},
})

    pcall(HttpRequest, {
        Url     = WEBHOOK_URL,
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = Payload,
    })
end

local function ForceKick(Category, Reason)
    task.spawn(function()
        SendWebhook(Category, Reason)
        pcall(function() LocalPlayer:Kick("[" .. Category .. "] " .. Reason) end)
        task.defer(function()
            task.wait(2)
            while true do end
        end)
    end)
end

local function KickClient(Category, Reason)
    if Kicked then return end
    Kicked = true
    ForceKick(Category, Reason)
end

local InstanceMeta    = SafeCall(getrawmetatable, game)
local RealNamecall    = InstanceMeta and rawget(InstanceMeta, "__namecall") or nil
local RealNewIndex    = InstanceMeta and rawget(InstanceMeta, "__newindex") or nil

local _SP             = Instance.new("Part")
local SignalMeta      = SafeCall(getrawmetatable, _SP.Touched)
local RealSignalIndex = SignalMeta and rawget(SignalMeta, "__index") or nil
_SP:Destroy()

local _SRE           = Instance.new("RemoteEvent")
local _SRF           = Instance.new("RemoteFunction")
local RealFireServer = _SRE.FireServer
_SRE:Destroy()
_SRF:Destroy()

local UncSnapshot = {}
local UncNames = {
    "hookfunction","hookmetamethod","newcclosure","clonefunction",
    "getupvalues","getconstants","getprotos","getinfo",
    "iscclosure","islclosure","isexecutorclosure","getfunctionhash",
    "getcallbackvalue","getscriptthread","getallthreads","setstackhidden",
    "getfenv","setfenv","getconnections","getrawmetatable","setrawmetatable",
    "getrenv","getsenv","checkcaller","getcallingscript","isfunctionhooked",
    "restorefunction","getnilinstances","identifyexecutor","cloneref",
    "compareinstances","setreadonly","getthreadidentity","setthreadidentity",
}
for _, N in ipairs(UncNames) do UncSnapshot[N] = _G[N] end

local function IsExecClosure(Fn)
    if type(Fn) ~= "function" then return false end
    if isexecutorclosure and isexecutorclosure(Fn) then return true end
    if iscclosure and islclosure and not iscclosure(Fn) and not islclosure(Fn) then return true end
    return false
end

local function IsFnHooked(Fn)
    if type(Fn) ~= "function" then return false end
    if IsExecClosure(Fn) then return true end
    if isfunctionhooked and isfunctionhooked(Fn) then return true end
    if getupvalues then
        local Ok, Ups = pcall(getupvalues, Fn)
        if Ok then
            for _, V in pairs(Ups) do
                if type(V) == "function" and IsExecClosure(V) then return true end
            end
        end
    end
    return false
end

local function HashMismatch(A, B)
    if not getfunctionhash or not A or not B then return false end
    local H1, H2 = SafeCall(getfunctionhash, A), SafeCall(getfunctionhash, B)
    return H1 and H2 and H1 ~= H2
end

local LegitPrefixes = {
    "^GetFFlag","^GetFInt","^GetFString","^GetFVariable",
    "^GetFastFlag","^GetFastInt","^GetFastString",
}

local function IsLikelyRobloxFlag(Name)
    for _, P in ipairs(LegitPrefixes) do
        if Name:match(P) then return true end
    end
    return false
end

local DexSigs = {
    "dex","appsframe","appscontainer","coverframe",
    "explorerframe","propertiesframe","scriptviewer",
    "instancetree","saveinstance","consolegui","outputgui","notebook",
}

local SpySigs = {
    "cobalt","hydroxide","hydroconnections",
    "remotespy","remotelogger","remotepanel",
    "remotelogs","remoteviewer","spygui",
    "httpspy","arglogger","remotecapture","rspy",
}

local DexWholeWord = { dex = true }

local function CheckObj(Obj)
    if Kicked then return end
    local Name = Obj.Name
    if IsLikelyRobloxFlag(Name) then return end
    local L = Name:lower()
    for _, S in ipairs(DexSigs) do
        local Found = L:find(S, 1, true)
        if Found then
            if DexWholeWord[S] then
                local Before = Found > 1 and L:sub(Found - 1, Found - 1) or ""
                local After  = L:sub(Found + #S, Found + #S)
                if Before:match("%a") or After:match("%a") then continue end
            end
            KickClient("Dex", "gui signature matched")
            return
        end
    end
    for _, S in ipairs(SpySigs) do
        if L:find(S, 1, true) then
            KickClient("RemoteSpy", "gui signature matched")
            return
        end
    end
end

local ObfPatterns = {
    "^[A-Za-z0-9+/=]{28,}$",
    "^[0-9a-fA-F]{32,}$",
    "[\0-\8\14-\31]",
    "^[^%w%s]{8,}$",
}

local function IsObfuscated(Name)
    local C = Name:gsub("_%d+$", "")
    if IsLikelyRobloxFlag(C) then return false end
    if #C > 140 then return true end
    for _, P in ipairs(ObfPatterns) do
        if C:match(P) then return true end
    end
    if #C >= 12 then
        local Lower = C:lower()
        local NonAlpha = 0
        for i = 1, #Lower do
            if not Lower:sub(i,i):match("%a") then NonAlpha += 1 end
        end
        if NonAlpha / #Lower > 0.65 then return true end
        if Lower:match("(..)%1%1%1") then return true end
    end
    return false
end

local Scanned = {}

local function CheckObjFull(Obj)
    if Scanned[Obj] then return end
    Scanned[Obj] = true
    CheckObj(Obj)
    if not Kicked and IsObfuscated(Obj.Name) then
        KickClient("Dex gui", "Dex gui name detected")
    end
end

local function ScanRoot(Root)
    for _, Obj in ipairs(Root:GetDescendants()) do
        if Kicked then return end
        CheckObjFull(Obj)
    end
end

LocalPlayer.PlayerGui.DescendantAdded:Connect(function(Obj)
    if not Kicked then CheckObjFull(Obj) end
end)
pcall(function()
    CoreGui.DescendantAdded:Connect(function(Obj)
        if not Kicked then CheckObjFull(Obj) end
    end)
end)

local function CheckDexNodeTable()
    if not getgc then return false end
    local Total  = #game:GetDescendants()
    local Thresh = math.floor(Total * 0.80)
    for _, V in ipairs(getgc(true)) do
        if type(V) == "table" then
            local N = 0
            for K in pairs(V) do
                if typeof(K) == "Instance" then
                    N += 1
                    if N >= Thresh then
                        KickClient("Dex", "table found")
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function CheckDexConnections()
    if not getconnections then return false end
    local Ok, C = pcall(getconnections, game.DescendantAdded)
    if Ok and #C > 4 then
        KickClient("Dex", "Detection 15")
        return true
    end
    return false
end

local CobaltGlobalKeys = {
    "CobaltInitialized","Cobalt","CobaltAutoExecuted","COBALT_LATEST_URL"
}

local function CheckCobaltGlobals()
    if not getgenv then return false end
    local G = SafeCall(getgenv)
    if not G then return false end
    for _, K in ipairs(CobaltGlobalKeys) do
        if rawget(G, K) ~= nil then
            KickClient("RemoteSpy", "Cobalt global found")
            return true
        end
    end
    return false
end

local function CheckCobaltSharedTable()
    if not getgc then return false end
    local Items = SafeCall(getgc, true)
    if not Items then return false end
    for _, V in ipairs(Items) do
        if type(V) == "table" then
            local S = (rawget(V,"Communicator")            ~= nil and 1 or 0)
                    + (rawget(V,"Logs")                    ~= nil and 1 or 0)
                    + (rawget(V,"Hooks")                   ~= nil and 1 or 0)
                    + (rawget(V,"CobaltVerificationToken") ~= nil and 1 or 0)
                    + (rawget(V,"Unloaded")                ~= nil and 1 or 0)
                    + (rawget(V,"NamecallHook")            ~= nil and 1 or 0)
                    + (rawget(V,"NewIndexHook")            ~= nil and 1 or 0)
                    + (rawget(V,"AlternativeEnabled")      ~= nil and 1 or 0)
            if S >= 4 then
                KickClient("RemoteSpy", "Cobalt table found")
                return true
            end
        end
    end
    return false
end

local SpyGlobalKeys = {
    "CobaltInitialized","Cobalt","CobaltAutoExecuted",
    "HydroxideRunning","HydroxideConnections","Hydroxide",
    "RemoteSpy","remoteSpy","remote_spy",
    "HttpSpy","logRemote","logRemotes","interceptRemote","spy","rspy",
}

local function CheckSpyGlobalsInGC()
    if not getgc then return false end
    local Items = SafeCall(getgc, true)
    if not Items then return false end
    for _, V in ipairs(Items) do
        if type(V) == "table" then
            for _, K in ipairs(SpyGlobalKeys) do
                if rawget(V, K) ~= nil then
                    KickClient("RemoteSpy", "Spy global found")
                    return true
                end
            end
        end
    end
    return false
end

local function CheckMetamethodHooks()
    if not getrawmetatable then return false end
    local M = SafeCall(getrawmetatable, game)
    if not M then return false end
    local NC, NI = rawget(M, "__namecall"), rawget(M, "__newindex")
    if NC and IsExecClosure(NC)       then KickClient("RemoteSpy", "__namecall replaced with executor closure") return true end
    if NI and IsExecClosure(NI)       then KickClient("RemoteSpy", "__newindex replaced with executor closure") return true end
    if HashMismatch(RealNamecall, NC) then KickClient("RemoteSpy", "__namecall hash mismatch — hook detected") return true end
    if HashMismatch(RealNewIndex, NI) then KickClient("RemoteSpy", "__newindex hash mismatch — hook detected") return true end
    return false
end

local function CheckSignalHook()
    if not SignalMeta then return false end
    local C = rawget(SignalMeta, "__index")
    if not C then return false end
    if IsExecClosure(C)                 then KickClient("RemoteSpy", "Signal.__index replaced with executor closure") return true end
    if HashMismatch(RealSignalIndex, C) then KickClient("RemoteSpy", "Signal.__index hash mismatch — Connect() spy active") return true end
    return false
end

local function CheckRemoteHooks()
    local RE, RF = Instance.new("RemoteEvent"), Instance.new("RemoteFunction")
    local FH, IH = IsFnHooked(RE.FireServer), IsFnHooked(RF.InvokeServer)
    RE:Destroy() RF:Destroy()
    if FH then KickClient("RemoteSpy", "FireServer is hooked") return true end
    if IH then KickClient("RemoteSpy", "InvokeServer is hooked") return true end
    local RE2 = Instance.new("RemoteEvent")
    local MM  = HashMismatch(RealFireServer, RE2.FireServer)
    RE2:Destroy()
    if MM then KickClient("RemoteSpy", "FireServer hash mismatch — hook detected") return true end
    return false
end

local function SignalHasSpy(Signal)
    if not getconnections then 
        return false 
    end

    local Ok, Connections = pcall(getconnections, Signal)
    if not Ok or not Connections then 
        return false 
    end

    for _, Conn in ipairs(Connections) do
        local isForeign = SafeCall(function()
            return Conn.ForeignState ~= nil
        end)

        local Fn = SafeCall(function()
            return Conn.Function
        end)

        local isExecutorClosure = Fn and IsExecClosure(Fn)

        if isForeign and isExecutorClosure then
            return true, "Suspicious foreign executor connection"
        end
    end

    return false
end

local function ScanRemotes(Instances)
    for _, Obj in ipairs(Instances) do
        if Kicked then return true end
        local CN = Obj.ClassName
        if CN == "RemoteEvent" or CN == "UnreliableRemoteEvent" then
            local S, R = SignalHasSpy(Obj.OnClientEvent)
            if S then KickClient("RemoteSpy", R .. " on OnClientEvent: " .. Obj:GetFullName()) return true end
        elseif CN == "RemoteFunction" then
            if getcallbackvalue then
                local CB = SafeCall(getcallbackvalue, Obj, "OnClientInvoke")
                if CB and IsExecClosure(CB) then
                    KickClient("RemoteSpy", "OnClientInvoke set to executor closure: " .. Obj:GetFullName())
                    return true
                end
            end
        elseif CN == "BindableEvent" then
            local S, R = SignalHasSpy(Obj.Event)
            if S then KickClient("RemoteSpy", R .. " on BindableEvent: " .. Obj:GetFullName()) return true end
        end
    end
    return false
end

local function CheckRemoteSpyConns()
    for _, Svc in ipairs({ game:GetService("ReplicatedStorage"), game:GetService("Players"), workspace }) do
        local Ok, D = pcall(function() return Svc:GetDescendants() end)
        if Ok and ScanRemotes(D) then return true end
    end
    return false
end

local function CheckNilRemotes()
    if not getnilinstances or not getconnections then return false end
    local Nils = SafeCall(getnilinstances)
    if not Nils then return false end
    return ScanRemotes(Nils)
end

local function CheckFenvSpoof()
    if not getfenv then return false end
    local Env = SafeCall(getfenv, 1)
    if not Env then return false end
    local Miss = 0
    for _, N in ipairs(UncNames) do
        if UncSnapshot[N] ~= nil and Env[N] == nil then Miss += 1 end
    end
    if Miss > 5 then
        KickClient("RemoteSpy", "getfenv spoof — " .. Miss .. " UNC functions hidden from environment")
        return true
    end
    return false
end

local function CheckStack()
    if not debug or not debug.traceback then return false end
    local T = SafeCall(function() return debug.traceback() end)
    if not T then return false end
    local F = 0
    for _ in T:gmatch("\n") do F += 1 end
    if F < 2 then
        KickClient("RemoteSpy", "Stack frame deficit — setstackhidden active on hook in thread")
        return true
    end
    return false
end

local function CheckHookOverhead()
    local RE = Instance.new("RemoteEvent")
    RE.Parent = nil
    local T0 = os.clock()
    for _ = 1, 20 do pcall(function() RE:FireServer() end) end
    local E = os.clock() - T0
    RE:Destroy()
    if E > 0.015 then
        KickClient("RemoteSpy", string.format("FireServer hook overhead: %.4fs over 20 calls", E))
        return true
    end
    return false
end

local function CheckThreads()
    if not getallthreads then return false end
    local T = SafeCall(getallthreads)
    if not T then return false end
    local N = 0
    for _, Th in ipairs(T) do
        local Ok, S = pcall(debug.info, Th, "s")
        if Ok and (S == "" or S == "[C]") then N += 1 end
    end
    if N > 8 then
        KickClient("RemoteSpy", "Excessive anonymous executor threads active: " .. N)
        return true
    end
    return false
end

local CallWindow = 1
local CallCounts = {}

local CallThresholds = {
    getgc = 2, getupvalues = 2, getconstants = 2,
    getprotos = 2, getconnections = 2, getsenv = 2, getrenv = 2,
    hookfunction = 8, hookmetamethod = 8, newcclosure = 8,
    clonefunction = 8, getcallbackvalue = 8, setstackhidden = 8,
}

local CallCategories = {
    getgc = "Dex", getupvalues = "Dex", getconstants = "Dex",
    getprotos = "Dex", getconnections = "Dex", getsenv = "Dex", getrenv = "Dex",
    hookfunction = "RemoteSpy", hookmetamethod = "RemoteSpy", newcclosure = "RemoteSpy",
    clonefunction = "RemoteSpy", getcallbackvalue = "RemoteSpy", setstackhidden = "RemoteSpy",
}

local function MonitorFn(Name)
    if not hookfunction or not newcclosure then return end
    local Orig = _G[Name]
    if type(Orig) ~= "function" then return end
    CallCounts[Name] = { N = 0, W = tick() }
    pcall(function()
        hookfunction(Orig, newcclosure(function(...)
            if Kicked then return Orig(...) end
            local D, Now = CallCounts[Name], tick()
            if Now - D.W >= CallWindow then D.N = 0 D.W = Now end
            D.N += 1
            if D.N >= (CallThresholds[Name] or 8) then
                KickClient(CallCategories[Name] or "Unknown", Name .. " called " .. D.N .. "x in 1s (spam detected)")
            end
            return Orig(...)
        end))
    end)
end

for Name in pairs(CallThresholds) do MonitorFn(Name) end

local function RunAllChecks(PGui)
    if Kicked then return end
    ScanRoot(PGui)
    if not Kicked then ScanRoot(CoreGui) end
    if not Kicked then CheckDexNodeTable()      end
    if not Kicked then CheckDexConnections()    end
    if not Kicked then CheckCobaltGlobals()     end
    if not Kicked then CheckCobaltSharedTable() end
    if not Kicked then CheckMetamethodHooks()   end
    if not Kicked then CheckSignalHook()        end
    if not Kicked then CheckRemoteHooks()       end
    if not Kicked then CheckRemoteSpyConns()    end
    if not Kicked then CheckNilRemotes()        end
    if not Kicked then CheckSpyGlobalsInGC()    end
    if not Kicked then CheckFenvSpoof()         end
    if not Kicked then CheckStack()             end
    if not Kicked then CheckHookOverhead()      end
    if not Kicked then CheckThreads()           end
end

task.spawn(function()
    task.wait(2)
    local PGui = LocalPlayer:WaitForChild("PlayerGui")
    RunAllChecks(PGui)
    while not Kicked do
        task.wait(2)
        RunAllChecks(PGui)
    end
end)
