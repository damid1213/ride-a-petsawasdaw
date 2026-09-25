--[[
    Vanguard — Webhook.lua
    Discord webhook integration supporting Embeds and Components V2.

    Features:
      • Cached HTTP request executor detection
      • Non-blocking fire-and-forget queue with rate-limit protection
      • Traditional Embeds & Discord Components V2 layout support
      • User-Agent spoofing to bypass Cloudflare / Discord blocks
]]

-- ── Environment & Namespace Setup ────────────────────────────────────
local NS         = getgenv().EggsESP or {}
getgenv().EggsESP    = NS
getgenv().Vanguard = NS

local AppConfig  = NS.Config     or { Version = "1.0.0" }
local S          = NS.Services   or {}
local StateStore = NS.StateStore or NS.State or {}
local Utils      = NS.Utils      or {}

-- ── Module Initialization ───────────────────────────────────────────
local Webhook = {}

Webhook.Config = {
    Enabled            = false,
    Url                = "",
    Username           = "Vanguard",
    AvatarUrl          = "",
    NotifyRareOnly     = false,
    IncludeStats       = true,
    MinIntervalSeconds = 2,
    UseComponentsV2    = false, -- ตั้งเป็น true เพื่อเปลี่ยนไปใช้ Components V2
}

-- Private state trackers
local _stats       = { sent = 0, errors = 0 }
local _lastSentAt  = 0
local _httpRequest = nil

-- ── Internal Helpers ──────────────────────────────────────────────────
local function sanitizeUrl(url)
    if type(url) ~= "string" then return "" end
    return url:match("^%s*(.-)%s*$") or ""
end

local function getTimeString()
    return os.date("%H:%M:%S")
end

local function getPlayerInfo()
    local lp = (S and S.LocalPlayer) or game:GetService("Players").LocalPlayer
    if not lp then return "Unknown" end

    return string.format(
        "%s (@%s)\nID: `%s`",
        lp.DisplayName or "?",
        lp.Name or "?",
        tostring(lp.UserId or 0)
    )
end

-- Resolve & cache available HTTP request executor
local function getHttpRequest()
    if _httpRequest then return _httpRequest end

    local candidates = {
        function() return syn and type(syn.request) == "function" and syn.request end,
        function() return http and type(http.request) == "function" and http.request end,
        function() return fluxus and type(fluxus.request) == "function" and fluxus.request end,
        function()
            local g = getgenv and getgenv() or _G
            return g and type(g.request) == "function" and g.request
        end,
        function()
            local g = getgenv and getgenv() or _G
            return g and type(g.http_request) == "function" and g.http_request
        end,
        function()
            local ok, r = pcall(function() return request end)
            return ok and type(r) == "function" and r
        end,
        function()
            local ok, r = pcall(function() return http_request end)
            return ok and type(r) == "function" and r
        end,
    }

    for _, fn in ipairs(candidates) do
        local ok, result = pcall(fn)
        if ok and result then
            _httpRequest = result
            return _httpRequest
        end
    end

    return nil
end

-- ── Core HTTP Dispatch ────────────────────────────────────────────────
local function sendNow(payload)
    local url = sanitizeUrl(Webhook.Config.Url)
    if url == "" then return false, "No URL" end
    if not url:match("^https?://") then return false, "Invalid URL" end

    local httpRequest = getHttpRequest()
    if not httpRequest then return false, "No HTTP executor support" end

    -- รองรับ Query Parameter สำหรับ Components V2
    if payload.flags == 32768 and not url:match("with_components=true") then
        local sep = url:match("%?") and "&" or "?"
        url = url .. sep .. "with_components=true"
    end

    payload.username = payload.username or Webhook.Config.Username
    if Webhook.Config.AvatarUrl ~= "" and not payload.avatar_url then
        payload.avatar_url = Webhook.Config.AvatarUrl
    end

    local hs      = S.HttpService or game:GetService("HttpService")
    local body    = hs:JSONEncode(payload)
    local headers = {
        ["Content-Type"] = "application/json",
        ["User-Agent"]   = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                        .. "AppleWebKit/537.36 (KHTML, like Gecko) "
                        .. "Chrome/120.0.0.0 Safari/537.36",
        ["Accept"]       = "application/json",
    }

    local req = {
        Url     = url,
        url     = url,
        Method  = "POST",
        method  = "POST",
        Headers = headers,
        headers = headers,
        Body    = body,
        body    = body,
    }

    local ok, err = pcall(function()
        local resp = httpRequest(req)
        if not resp then error("No response") end

        local code = nil
        if type(resp) == "table" then
            code = resp.StatusCode or resp.status_code or resp.statusCode or resp.Status
        end

        if type(code) == "string" then
            code = tonumber(code:match("^(%d+)")) or code
        end

        if type(code) == "number" and (code < 200 or code >= 300) then
            local rbody = tostring((resp and (resp.Body or resp.body)) or "")
            error("HTTP " .. tostring(code) .. (rbody ~= "" and (": " .. rbody) or ""))
        end
    end)

    if ok then
        _stats.sent += 1
        return true
    else
        _stats.errors += 1
        warn("[Webhook] " .. tostring(err))
        return false, tostring(err)
    end
end

-- ── Public API Methods ────────────────────────────────────────────────

--- Send a raw payload asynchronously (non-blocking)
function Webhook.Send(payload, _legacy_isDirect)
    if not Webhook.Config.Enabled then return false, "Disabled" end

    local url = sanitizeUrl(Webhook.Config.Url)
    if url == "" then return false, "No URL" end

    -- Queue with rate limiting
    task.spawn(function()
        local now     = os.clock()
        local elapsed = now - _lastSentAt

        if elapsed < Webhook.Config.MinIntervalSeconds then
            task.wait(Webhook.Config.MinIntervalSeconds - elapsed)
        end

        _lastSentAt = os.clock()
        sendNow(payload)
    end)

    return true
end

--- Notification layout router (Embed vs Components V2)
function Webhook.NotifyEggCollected(eggName, isRare)
    if not Webhook.Config.Enabled then return false, "Disabled" end
    if Webhook.Config.NotifyRareOnly and not isRare then return false, "Not rare" end

    if Webhook.Config.UseComponentsV2 then
        return Webhook.NotifyEggCollectedV2(eggName, isRare)
    end

    local name  = (eggName and tostring(eggName) ~= "") and tostring(eggName) or "Egg"
    local color = isRare and 0xFFD700 or 0x00E676
    local title = isRare and "🌟 Rare Egg Collected!" or "🥚 Egg Collected!"

    local fields = {
        { name = "🥚 Egg",    value = "**" .. name .. "**", inline = true },
        { name = "⏰ Time",   value = getTimeString(),      inline = true },
        { name = "👤 Player", value = getPlayerInfo(),      inline = false },
    }

    if Webhook.Config.IncludeStats then
        local st      = NS.StateStore or StateStore
        local start   = (st and st.sessionStartTime) or os.time()
        local total   = (st and st.totalEggsCollected) or 0
        local elapsed = math.max(0, os.time() - start)

        table.insert(fields, {
            name   = "📊 Total",
            value  = tostring(total) .. " eggs",
            inline = true,
        })
        table.insert(fields, {
            name   = "⏱️ Runtime",
            value  = string.format("%02d:%02d", math.floor(elapsed / 60), elapsed % 60),
            inline = true,
        })
    end

    local version = (NS.Config and NS.Config.Version) or AppConfig.Version or "1.0.0"

    return Webhook.Send({
        embeds = {
            {
                title     = title,
                color     = color,
                fields    = fields,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                footer    = { text = "Vanguard v" .. tostring(version) },
            },
        },
    })
end

--- Egg collected notification using Discord Components V2
function Webhook.NotifyEggCollectedV2(eggName, isRare)
    local name  = (eggName and tostring(eggName) ~= "") and tostring(eggName) or "Egg"
    local title = isRare and "🌟 **Rare Egg Collected!**" or "🥚 **Egg Collected!**"
    local version = (NS.Config and NS.Config.Version) or AppConfig.Version or "1.0.0"

    local statsText = ""
    if Webhook.Config.IncludeStats then
        local st      = NS.StateStore or StateStore
        local start   = (st and st.sessionStartTime) or os.time()
        local total   = (st and st.totalEggsCollected) or 0
        local elapsed = math.max(0, os.time() - start)

        statsText = string.format(
            "\n📊 **Total:** %d eggs\n⏱️ **Runtime:** %02d:%02d",
            total,
            math.floor(elapsed / 60),
            elapsed % 60
        )
    end

    local payload = {
        flags = 32768, -- IS_COMPONENTS_V2
        components = {
            {
                type = 17, -- Container
                accent_color = isRare and 0xFFD700 or 0x00E676,
                components = {
                    {
                        type = 10, -- TextDisplay
                        content = string.format("# %s\nCollected item: **%s**", title, name)
                    },
                    {
                        type = 14, -- Separator
                        divider = true,
                        spacing = 1
                    },
                    {
                        type = 10, -- TextDisplay
                        content = string.format("👤 **Player:**\n%s\n\n⏰ **Time:** `%s`%s", getPlayerInfo(), getTimeString(), statsText)
                    },
                    {
                        type = 14, -- Separator
                        divider = false,
                        spacing = 1
                    },
                    {
                        type = 10, -- TextDisplay (Subtext Footer)
                        content = "-# Vanguard v" .. tostring(version)
                    }
                }
            }
        }
    }

    return Webhook.Send(payload)
end

--- Test Webhook connection
function Webhook.Test()
    local saved = Webhook.Config.Enabled
    Webhook.Config.Enabled = true
    _lastSentAt = 0

    local version = (NS.Config and NS.Config.Version) or AppConfig.Version or "1.0.0"
    local ok, err

    if Webhook.Config.UseComponentsV2 then
        ok, err = sendNow({
            flags = 32768,
            components = {
                {
                    type = 17,
                    accent_color = 0x00E676,
                    components = {
                        { type = 10, content = "## ✅ Webhook Connected\nNotifications are active with **Components V2**." },
                        { type = 14, divider = true, spacing = 1 },
                        { type = 10, content = string.format("👤 **Player:** %s\n⏰ **Time:** `%s`", getPlayerInfo(), getTimeString()) },
                        { type = 10, content = "-# Vanguard v" .. tostring(version) }
                    }
                }
            },
            username = Webhook.Config.Username,
        })
    else
        ok, err = sendNow({
            embeds = {
                {
                    title       = "✅ Webhook Connected",
                    description = "Notifications are active.",
                    color       = 0x00E676,
                    fields      = {
                        { name = "👤 Player", value = getPlayerInfo(), inline = false },
                        { name = "⏰ Time",   value = getTimeString(), inline = true },
                    },
                    timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    footer      = { text = "Vanguard v" .. tostring(version) },
                },
            },
            username = Webhook.Config.Username,
        })
    end

    Webhook.Config.Enabled = saved
    return ok, err
end

--- Get error/success statistics
function Webhook.GetStats()
    return { sent = _stats.sent, errors = _stats.errors }
end

-- ── Export Module ─────────────────────────────────────────────────────
NS.Webhook = Webhook
return Webhook
