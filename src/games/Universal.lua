--[[
    Vanguard -- Universal.lua
    Shared utilities usable across all game modules.

    Features:
      · Anti-AFK          -- Prevents idle kick by simulating input
      · Low Graphics Mode -- Disables shadows/rendering for better FPS
      · Rejoin            -- Reconnects to the same server (with script re-injection)
      · Server Hop        -- Connects to a different public server instance

    Usage:
        local Universal = require(path.to.Universal)
        Universal.setAntiAFK(true)
        Universal.setLowGraphics(true)
        Universal.rejoin()
        Universal.serverHop()
        Universal.destroy()   -- call in your Unload() to clean up
]]

local Players         = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService     = game:GetService("HttpService")
local RunService      = game:GetService("RunService")
local Lighting        = game:GetService("Lighting")
local LocalPlayer     = Players.LocalPlayer

local LOADER_URL = "https://raw.githubusercontent.com/LostInSyntaxx/RideAPet/main/loader.lua"

local Universal = {}

local _afkConn     = nil
local _origQuality = nil
local _origShadows = nil

-- ── Internal ────────────────────────────────────────────────────────

local function queueReload()
    pcall(function()
        local qot = (syn and syn.queue_on_teleport)
            or (typeof(queue_on_teleport) == "function" and queue_on_teleport)
            or (Fluxus and Fluxus.queue_on_teleport)
        if qot then
            qot(([[
                task.wait(3)
                pcall(function()
                    loadstring(game:HttpGet("%s"))()
                end)
            ]]):format(LOADER_URL))
        end
    end)
end

-- ── Anti-AFK ────────────────────────────────────────────────────────

function Universal.setAntiAFK(enable)
    if _afkConn then
        pcall(function() _afkConn:Disconnect() end)
        _afkConn = nil
    end
    if enable then
        _afkConn = LocalPlayer.Idled:Connect(function()
            pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
        end)
    end
    return _afkConn
end

function Universal.stopAntiAFK()
    Universal.setAntiAFK(false)
end

-- ── Low Graphics Mode ────────────────────────────────────────────────

function Universal.setLowGraphics(enable)
    if enable then
        _origShadows = Lighting.GlobalShadows
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd        = 9e4
            Lighting.FogStart      = 9e4
        end)
        pcall(function()
            _origQuality = UserSettings():GetService("UserGameSettings").SavedQualityLevel
            UserSettings():GetService("UserGameSettings").SavedQualityLevel =
                Enum.SavedQualitySetting.QualityLevel1
        end)
    else
        pcall(function()
            Lighting.GlobalShadows = (_origShadows ~= nil) and _origShadows or true
            Lighting.FogEnd        = 100000
            Lighting.FogStart      = 0
        end)
        pcall(function()
            if _origQuality then
                UserSettings():GetService("UserGameSettings").SavedQualityLevel = _origQuality
                _origQuality = nil
            end
        end)
    end
end

-- ── Rejoin (same server) ─────────────────────────────────────────────

function Universal.rejoin()
    queueReload()
    task.wait(0.5)
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end

-- ── Server Hop (different server) ───────────────────────────────────

function Universal.serverHop()
    queueReload()
    local placeId    = game.PlaceId
    local currentJob = game.JobId
    task.spawn(function()
        local ok, servers = pcall(function()
            local url = ("https://games.roblox.com/v1/games/%d/servers/Public?limit=100"):format(placeId)
            local raw = game:HttpGet(url)
            return HttpService:JSONDecode(raw)
        end)
        if ok and servers and servers.data then
            for _, srv in ipairs(servers.data) do
                if  srv.id ~= currentJob
                and srv.playing   ~= nil
                and srv.maxPlayers ~= nil
                and srv.playing    < srv.maxPlayers
                then
                    local tp_ok = pcall(function()
                        TeleportService:TeleportToPlaceInstance(placeId, srv.id, LocalPlayer)
                    end)
                    if tp_ok then return end
                end
            end
        end
        -- Fallback: brand-new server
        pcall(function()
            TeleportService:Teleport(placeId, LocalPlayer)
        end)
    end)
end

-- ── Cleanup (call from module Unload) ────────────────────────────────

function Universal.destroy()
    Universal.stopAntiAFK()
    Universal.setLowGraphics(false)
end

return Universal
