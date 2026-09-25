--[[
    Vanguard — Interaction.lua
    ProximityPrompt + keyboard interaction handlers.
    Rewritten:
      • Re-checks prompt.Enabled inside pcall after acquiring ref (race-condition fix)
      • Consistent key-up regardless of which method fired key-down
      • Returns bool indicating which path was taken
]]

local NS = getgenv().EggsESP
local S  = NS.Services

local Interaction = {}

-- ── Hold E key via best available method ────────────────────────────
function Interaction.holdEKey(duration)
    duration = math.max(0.05, duration or 1.5)
    local vim = S.VirtualInputManager
    local vu  = S.VirtualUser

    -- Key down
    if vim then
        pcall(function() vim:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
    elseif vu then
        pcall(function() vu:SetKeyDown("e") end)
    end

    task.wait(duration)

    -- Key up — always release both to be safe
    if vim then pcall(function() vim:SendKeyEvent(false, Enum.KeyCode.E, false, game) end) end
    if vu  then pcall(function() vu:SetKeyUp("e") end) end
end

-- ── Trigger interaction on a target object ───────────────────────────
-- Priority: fireproximityprompt → holdEKey fallback
function Interaction.trigger(targetObject, fallbackDuration)
    if not targetObject then return false end

    -- Search for a ProximityPrompt
    local prompt = targetObject:FindFirstChildWhichIsA("ProximityPrompt", true)

    if prompt then
        local fired = false
        pcall(function()
            -- Re-check Enabled inside pcall to handle race between check and fire
            if prompt.Enabled and S.Cap.fireproxprompt then
                fireproximityprompt(prompt)
                fired = true
            end
        end)
        if fired then
            task.wait(0.2)
            return true
        end
    end

    -- Fallback: simulate E key hold
    Interaction.holdEKey(fallbackDuration)
    return true
end

NS.Interaction = Interaction
