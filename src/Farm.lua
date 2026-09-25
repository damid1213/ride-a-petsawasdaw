--[[
    Vanguard — Farm.lua
    Auto-farm and best-egg collection loops.
    Rewritten:
      • Removed redundant inner cooldown/processed re-check (getReadyEggs handles it)
      • Consistent status update helper to reduce repetition
      • Cleaner break/return guards
]]

local NS          = getgenv().EggsESP
local AppConfig   = NS.Config
local S           = NS.Services
local StateStore  = NS.StateStore
local Utils       = NS.Utils
local Movement    = NS.Movement
local Interaction = NS.Interaction
local Plot        = NS.Plot

local Farm = {}

-- ── Helpers ───────────────────────────────────────────────────────────
local function status(updater, text, color)
    if updater then updater(text, color) end
end

local function cancelThread(key)
    if StateStore[key] then
        pcall(function() task.cancel(StateStore[key]) end)
        StateStore[key] = nil
    end
end

-- ── Ready egg list (pre-filtered) ────────────────────────────────────
function Farm.getReadyEggs()
    local found   = {}
    local folder  = S.RenderedEggsFolder
    if not folder then return found end
    local now = os.clock()

    for _, egg in ipairs(folder:GetChildren()) do
        if Utils.isValidEgg(egg) and StateStore.autoFarmEggs[egg.Name] then
            local cd = StateStore.eggCooldowns[egg]
            if not (cd and now <= cd) and not StateStore.autoFarmProcessed[egg] then
                table.insert(found, egg)
            end
        end
    end

    table.sort(found, function(a, b) return a.Name:lower() < b.Name:lower() end)
    return found
end

-- ── Find best egg by keyword ─────────────────────────────────────────
function Farm.findBestEgg()
    local folder = S.RenderedEggsFolder
    if not folder then return nil end
    local now   = os.clock()
    local query = AppConfig.BestEggName:lower()

    -- Pass 1: prefer off-cooldown eggs
    for _, egg in ipairs(folder:GetChildren()) do
        local cd = StateStore.eggCooldowns[egg]
        if not (cd and now <= cd) and Utils.isValidEgg(egg) then
            if egg.Name:lower():find(query, 1, true) then return egg end
        end
    end
    -- Pass 2: fallback — accept any match even on cooldown
    for _, egg in ipairs(folder:GetChildren()) do
        if Utils.isValidEgg(egg) and egg.Name:lower():find(query, 1, true) then
            return egg
        end
    end
    return nil
end

-- ── Stop Auto-Farm ────────────────────────────────────────────────────
function Farm.stopAutoFarm()
    StateStore.autoFarmActive = false
    Movement.stop()
    cancelThread("autoFarmThread")
    pcall(function()
        if S.VirtualInputManager then
            S.VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
    end)
end

-- ── Start Auto-Farm ───────────────────────────────────────────────────
function Farm.startAutoFarm(statusUpdater, stopButtonUpdater)
    Farm.stopAutoFarm()
    StateStore.autoFarmActive = true
    if stopButtonUpdater then stopButtonUpdater(true) end

    StateStore.autoFarmThread = task.spawn(function()
        while StateStore.autoFarmActive do
            -- Check at least one egg type is selected
            local hasAny = false
            for _, v in pairs(StateStore.autoFarmEggs) do
                if v then hasAny = true; break end
            end
            if not hasAny then
                status(statusUpdater, "No eggs selected", AppConfig.TextSecondary)
                break
            end

            local readyEggs = Farm.getReadyEggs()

            if #readyEggs == 0 then
                status(statusUpdater, "Waiting for eggs...", AppConfig.TextSecondary)
                task.wait(1.0)
            else
                for _, egg in ipairs(readyEggs) do
                    if not StateStore.autoFarmActive then break end

                    -- Only need to verify egg is still live; cooldown/processed
                    -- were already filtered by getReadyEggs()
                    if not Utils.isValidEgg(egg) then continue end

                    local eggName = egg.Name
                    status(statusUpdater, "Farming: " .. eggName, AppConfig.AccentGreen)

                    local arrived = Movement.moveTo(egg)
                    if arrived and StateStore.autoFarmActive then
                        task.wait(0.2)
                        if StateStore.autoFarmActive and Utils.isValidEgg(egg) then
                            status(statusUpdater, "Collecting " .. eggName .. "...", AppConfig.AccentGold)
                            Interaction.trigger(egg, AppConfig.AutoFarmHoldTime)
                        end
                        StateStore.eggCooldowns[egg] = os.clock() + AppConfig.EggCooldownSeconds
                        task.wait(0.3)

                        if StateStore.autoFarmActive then
                            status(statusUpdater, "Returning Home...", AppConfig.AccentBlue)
                            Movement.stop()
                            local ok = Plot.teleportAndDeposit()
                            if ok then
                                StateStore.autoFarmProcessed[egg] = true
                                StateStore.addHistoryRecord(eggName)
                                status(statusUpdater, "Egg Deposited!", AppConfig.AccentGreen)
                            else
                                status(statusUpdater, "Home Unreachable", AppConfig.AccentRed)
                            end
                        end
                        task.wait(AppConfig.AutoEggDelay)
                    end
                end
            end

            task.wait(0.25)
        end

        StateStore.autoFarmThread = nil
        StateStore.autoFarmActive = false
        if stopButtonUpdater then stopButtonUpdater(false) end
        status(statusUpdater, "AutoFarm Idle", AppConfig.TextSecondary)
    end)
end

-- ── Stop Best Egg ─────────────────────────────────────────────────────
function Farm.stopAutoBestEgg()
    StateStore.autoBestEggActive = false
    Movement.stop()
    cancelThread("autoBestEggThread")
    pcall(function()
        if S.VirtualInputManager then
            S.VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
    end)
end

-- ── Start Best Egg ────────────────────────────────────────────────────
function Farm.startAutoBestEgg(statusUpdater)
    Farm.stopAutoBestEgg()
    StateStore.autoBestEggActive = true

    StateStore.autoBestEggThread = task.spawn(function()
        while StateStore.autoBestEggActive do
            local egg = Farm.findBestEgg()

            if egg and egg.Parent then
                local eggName = egg.Name
                status(statusUpdater, "Moving to " .. eggName, AppConfig.AccentGreen)

                local arrived = Movement.moveTo(egg)
                if arrived and StateStore.autoBestEggActive then
                    task.wait(0.2)
                    if StateStore.autoBestEggActive and egg.Parent then
                        status(statusUpdater, "Collecting...", AppConfig.AccentGold)
                        Interaction.trigger(egg, AppConfig.AutoEggHoldTime)
                    end
                    StateStore.eggCooldowns[egg] = os.clock() + AppConfig.EggCooldownSeconds
                    task.wait(0.3)

                    if StateStore.autoBestEggActive then
                        status(statusUpdater, "Returning Home...", AppConfig.AccentBlue)
                        Movement.stop()
                        local ok = Plot.teleportAndDeposit()
                        if ok then
                            StateStore.addHistoryRecord(eggName)
                            status(statusUpdater, "Best Egg Deposited!", AppConfig.AccentGreen)
                        end
                    end
                    task.wait(AppConfig.AutoEggDelay)
                else
                    task.wait(0.5)
                end
            else
                status(statusUpdater, "Searching: [" .. AppConfig.BestEggName .. "]...",
                    AppConfig.TextSecondary)
                task.wait(1.0)
            end
        end

        StateStore.autoBestEggThread = nil
        StateStore.autoBestEggActive = false
    end)
end

NS.Farm = Farm
