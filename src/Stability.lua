--[[
    Vanguard — Stability.lua
    Anti-AFK + auto-rejoin resilience.
    Rewritten: added warn() when both rejoin paths fail, cleaner separation.
]]

local NS         = getgenv().EggsESP
local S          = NS.Services
local StateStore = NS.StateStore

local LOADER_URL = "https://raw.githubusercontent.com/LostInSyntaxx/RideAPet/main/loader.lua"

local Stability = {}

-- ── Anti-AFK ──────────────────────────────────────────────────────────
function Stability.setupAntiAFK(enable)
    StateStore.antiAFKActive = enable

    if StateStore.antiAFKConnection then
        pcall(function() StateStore.antiAFKConnection:Disconnect() end)
        StateStore.antiAFKConnection = nil
    end

    if not enable then return end

    StateStore.antiAFKConnection = S.LocalPlayer.Idled:Connect(function()
        if not StateStore.antiAFKActive then return end
        pcall(function()
            if S.VirtualUser then
                S.VirtualUser:CaptureController()
                S.VirtualUser:ClickButton2(Vector2.zero)
            elseif S.VirtualInputManager then
                S.VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.Unknown, false, game)
                task.wait(0.05)
                S.VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Unknown, false, game)
            end
        end)
    end)
end

-- ── Auto-rejoin ───────────────────────────────────────────────────────
local function queueReload()
    if not S.QueueOnTeleport then return false end
    local ok = pcall(function()
        S.QueueOnTeleport(([[
            task.wait(3)
            pcall(function()
                loadstring(game:HttpGet("%s"))()
            end)
        ]]):format(LOADER_URL))
    end)
    return ok
end

local function doRejoin()
    pcall(function()
        if #S.Players:GetPlayers() <= 1 then
            S.TeleportService:Teleport(game.PlaceId, S.LocalPlayer)
        else
            S.TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, S.LocalPlayer)
        end
    end)
end

function Stability.setupAutoRejoin()
    -- Path 1: ErrorMessageChanged (deprecated on some executors but still common)
    local ok1 = pcall(function()
        StateStore.track(S.GuiService.ErrorMessageChanged:Connect(function(msg)
            if msg and #msg > 0 then
                queueReload()
                task.wait(2.5)
                doRejoin()
            end
        end))
    end)
    if not ok1 then
        warn("[Stability] GuiService.ErrorMessageChanged unavailable — using ErrorPrompt fallback only")
    end

    -- Path 2: CoreGui ErrorPrompt overlay
    task.spawn(function()
        local ok2 = pcall(function()
            local promptOverlay = S.CoreGui:WaitForChild("RobloxPromptGui", 8)
            if promptOverlay then
                promptOverlay = promptOverlay:WaitForChild("promptOverlay", 8)
            end
            if not promptOverlay then
                warn("[Stability] ErrorPrompt overlay not found — auto-rejoin may be limited")
                return
            end
            StateStore.track(promptOverlay.ChildAdded:Connect(function(child)
                if child.Name == "ErrorPrompt" then
                    queueReload()
                    task.wait(2)
                    doRejoin()
                end
            end))
        end)
        if not ok2 then
            warn("[Stability] ErrorPrompt fallback failed — auto-rejoin disabled")
        end
    end)
end

NS.Stability = Stability
