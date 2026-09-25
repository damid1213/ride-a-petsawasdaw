--[[
    Vanguard — Services.lua
    Centralised Roblox service cache + executor capability detection.
    Rewritten: clean init, safe pcall wrapping, capability flags exposed.
]]

local NS = getgenv().EggsESP

local S = {}

-- ── Core Services ────────────────────────────────────────────────────
S.Players           = game:GetService("Players")
S.TweenService      = game:GetService("TweenService")
S.RunService        = game:GetService("RunService") 
S.UserInputService  = game:GetService("UserInputService")
S.TeleportService   = game:GetService("TeleportService")
S.GuiService        = game:GetService("GuiService")
S.CoreGui           = game:GetService("CoreGui")
S.Workspace         = game:GetService("Workspace")
S.ReplicatedStorage = game:GetService("ReplicatedStorage")
S.LocalPlayer       = S.Players.LocalPlayer

-- ── Optional / Executor-specific Services ───────────────────────────
local function tryService(name)
    local ok, svc = pcall(function() return game:GetService(name) end)
    return ok and svc or nil
end

S.VirtualInputManager = tryService("VirtualInputManager")
S.VirtualUser         = tryService("VirtualUser")
S.HttpService         = tryService("HttpService")

-- ── Executor Capability Flags ────────────────────────────────────────
S.Cap = {
    readfile        = type(readfile)          == "function",
    writefile       = type(writefile)         == "function",
    isfile          = type(isfile)            == "function",
    isfolder        = type(isfolder)          == "function",
    makefolder      = type(makefolder)        == "function",
    delfile         = type(delfile)           == "function",
    firesignal      = type(firesignal)        == "function",
    fireproxprompt  = type(fireproximityprompt) == "function",
    gethui          = type(gethui)            == "function",
    loadstring      = type(loadstring)        == "function",
}

-- ── GUI Parent (gethui > CoreGui > PlayerGui) ────────────────────────
local function resolveGuiParent()
    if S.Cap.gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg end
    -- Wait for LocalPlayer / PlayerGui safely
    local lp = S.LocalPlayer
    if not lp then
        lp = game:GetService("Players").LocalPlayer
    end
    if lp then
        local ok3, pgui = pcall(function() return lp:WaitForChild("PlayerGui", 10) end)
        if ok3 and pgui then return pgui end
    end
    -- Last-resort: CoreGui is always accessible
    return game:GetService("CoreGui")
end
S.GuiParent  = resolveGuiParent()
S.TargetParent = S.GuiParent  -- alias used by UI.lua

-- ── queue_on_teleport helper ─────────────────────────────────────────
S.QueueOnTeleport = (syn and syn.queue_on_teleport)
    or (type(queue_on_teleport) == "function" and queue_on_teleport)
    or (Fluxus and Fluxus.queue_on_teleport)
    or nil

-- ── RenderedEggs folder (wait up to 10s) ────────────────────────────
local eggsFolder = S.Workspace:FindFirstChild("RenderedEggs")
if not eggsFolder then
    task.spawn(function()
        eggsFolder = S.Workspace:WaitForChild("RenderedEggs", 10)
        S.RenderedEggsFolder = eggsFolder
    end)
else
    S.RenderedEggsFolder = eggsFolder
end

NS.Services = S
