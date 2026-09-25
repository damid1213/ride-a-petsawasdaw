--[[
    Vanguard — Pull An Egg
    UI.lua — AAA Dark Dashboard  ·  Ribbon Tabs  ·  Nested Cards

    Fixes vs previous version:
    · Single consolidated colour palette (C) — no duplicate token tables
    · Toggle hover closure always reads live `state` (no stale-colour flash)
    · AutoRevive, AutoBuyGear toggles present on the Farm tab
    · Ctrl toggle shortcut uses the tracked Runtime connection for clean unload
    · destroy() disconnects the keyboard shortcut connection
]]

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local Players          = game:GetService("Players")
local LocalPlayer      = Players.LocalPlayer

-- ── Colour Palette ───────────────────────────────────────────────────

local C = {
    -- Backgrounds (darkest → lightest)
    bg0       = Color3.fromRGB( 17,  17,  17),  -- shell / title bar
    bg1       = Color3.fromRGB( 31,  31,  31),  -- inner surface
    bg2       = Color3.fromRGB( 36,  36,  36),  -- outer card
    bg3       = Color3.fromRGB( 26,  26,  26),  -- inner card
    -- Borders
    border0   = Color3.fromRGB( 50,  50,  50),
    border1   = Color3.fromRGB( 45,  45,  45),
    border2   = Color3.fromRGB( 38,  38,  38),
    -- Accent
    gold      = Color3.fromRGB(255, 185,  50),
    goldDim   = Color3.fromRGB( 60,  42,   8),
    goldGlow  = Color3.fromRGB(255, 200,  80),
    -- Status
    green     = Color3.fromRGB( 52, 211, 153),
    greenDim  = Color3.fromRGB( 15,  60,  40),
    red       = Color3.fromRGB(239,  68,  68),
    blue      = Color3.fromRGB( 59, 130, 246),
    -- Text
    textPri   = Color3.fromRGB(230, 230, 230),
    textSec   = Color3.fromRGB(130, 130, 130),
    textMuted = Color3.fromRGB( 70,  70,  70),
    white     = Color3.fromRGB(255, 255, 255),
}

-- ── Tween helper ─────────────────────────────────────────────────────

local function tw(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.14, Enum.EasingStyle.Quad), props):Play()
end

-- ── Small UI factories ───────────────────────────────────────────────

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = r or UDim.new(0, 12)
    c.Parent = parent
    return c
end

local function stroke(parent, col, th)
    local s = Instance.new("UIStroke")
    s.Color            = col or C.border1
    s.Thickness        = th  or 1
    s.ApplyStrokeMode  = Enum.ApplyStrokeMode.Border
    s.Parent           = parent
    return s
end

local function listLayout(parent, paddingPx, dir)
    local l = Instance.new("UIListLayout")
    l.Padding       = UDim.new(0, paddingPx or 8)
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.Parent        = parent
    return l
end

local function padding(parent, x, y)
    local p = Instance.new("UIPadding")
    p.PaddingLeft   = UDim.new(0, x or 12)
    p.PaddingRight  = UDim.new(0, x or 12)
    p.PaddingTop    = UDim.new(0, y or 10)
    p.PaddingBottom = UDim.new(0, y or 10)
    p.Parent        = parent
    return p
end

-- ── Module ───────────────────────────────────────────────────────────

local UI = {
    ScreenGui  = nil,
    ToggleGui  = nil,
    MainFrame  = nil,
    _conns     = {},
}

local Config, Farm, ESP, Remotes

local function getGuiParent()
    -- 1. gethui() — executor protected GUI container
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    -- 2. CoreGui — available in most executors
    local ok2, _ = pcall(function() return CoreGui:GetChildren() end)
    if ok2 then return CoreGui end
    -- 3. PlayerGui — wait up to 10s for LocalPlayer to be ready
    local player = Players.LocalPlayer
        or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    if player then
        local ok3, pgui = pcall(function()
            return player:WaitForChild("PlayerGui", 10)
        end)
        if ok3 and pgui then return pgui end
    end
    -- 4. Last-resort fallback — should never be reached
    return CoreGui
end

-- ── Init ─────────────────────────────────────────────────────────────

function UI.init(cfg, farmRef, espRef, remsRef)
    Config  = cfg
    Farm    = farmRef
    ESP     = espRef
    Remotes = remsRef
    UI.build()
end

-- ────────────────────────────────────────────────────────────────────
--  BUILD
-- ────────────────────────────────────────────────────────────────────

function UI.build()
    local parent = getGuiParent()
    if not parent then
        warn("[Vanguard] UI: could not resolve a GUI parent — aborting build.")
        return
    end

    -- Destroy old GUIs if re-running
    for _, name in ipairs({"Vanguard_PullAnEgg", "Vanguard_FloatingBtn"}) do
        local old = parent:FindFirstChild(name)
        if old then old:Destroy() end
    end

    -- ── ScreenGuis ───────────────────────────────────────────────────
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name           = "Vanguard_PullAnEgg"
    screenGui.ResetOnSpawn   = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder   = 999

    local toggleGui = Instance.new("ScreenGui")
    toggleGui.Name           = "Vanguard_FloatingBtn"
    toggleGui.ResetOnSpawn   = false
    toggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    toggleGui.DisplayOrder   = 1000

    -- ── Floating Button ──────────────────────────────────────────────
    local fabFrame = Instance.new("Frame")
    fabFrame.Size             = UDim2.new(0, 52, 0, 52)
    fabFrame.Position         = UDim2.new(0, 16, 0.5, -26)
    fabFrame.BackgroundColor3 = C.bg1
    fabFrame.BorderSizePixel  = 0
    fabFrame.Parent           = toggleGui
    corner(fabFrame, UDim.new(0, 14))
    local fabStroke = stroke(fabFrame, C.gold, 1.5)

    local fabBtn = Instance.new("TextButton")
    fabBtn.Name               = "OpenButton"
    fabBtn.Size               = UDim2.new(1, 0, 1, 0)
    fabBtn.BackgroundTransparency = 1
    fabBtn.Text               = "🐾"
    fabBtn.TextSize           = 24
    fabBtn.Font               = Enum.Font.GothamBold
    fabBtn.Parent             = fabFrame

    -- FAB drag
    local fabDragging, fabDragInput, fabDragStart, fabDragPos
    fabFrame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            fabDragging = true
            fabDragStart = i.Position
            fabDragPos   = fabFrame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    fabDragging = false
                end
            end)
        end
    end)
    fabFrame.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            fabDragInput = i
        end
    end)

    -- ── Main Window Shell ────────────────────────────────────────────
    local shell = Instance.new("Frame")
    shell.Name             = "MainFrame"
    shell.Size             = UDim2.new(0, 660, 0, 460)
    shell.Position         = UDim2.new(0.5, -330, 0.5, -230)
    shell.BackgroundColor3 = C.bg0
    shell.BorderSizePixel  = 0
    shell.ClipsDescendants = true
    shell.Parent           = screenGui
    corner(shell, UDim.new(0, 16))
    stroke(shell, C.border0, 1)

    -- Gold top stripe
    local stripe = Instance.new("Frame")
    stripe.Size             = UDim2.new(1, 0, 0, 2)
    stripe.BackgroundColor3 = C.gold
    stripe.BorderSizePixel  = 0
    stripe.ZIndex           = 3
    stripe.Parent           = shell

    -- Inner surface
    local main = Instance.new("Frame")
    main.Size             = UDim2.new(1, -2, 1, -2)
    main.Position         = UDim2.new(0, 1, 0, 1)
    main.BackgroundColor3 = C.bg1
    main.BorderSizePixel  = 0
    main.ClipsDescendants = true
    main.Parent           = shell
    corner(main, UDim.new(0, 15))

    -- ── Title Bar ────────────────────────────────────────────────────
    local titleBar = Instance.new("Frame")
    titleBar.Name             = "TitleBar"
    titleBar.Size             = UDim2.new(1, 0, 0, 56)
    titleBar.BackgroundColor3 = C.bg0
    titleBar.BorderSizePixel  = 0
    titleBar.Parent           = main

    -- Logo box
    local logoBox = Instance.new("Frame")
    logoBox.Position         = UDim2.new(0, 14, 0.5, -16)
    logoBox.Size             = UDim2.new(0, 32, 0, 32)
    logoBox.BackgroundColor3 = C.goldDim
    logoBox.BorderSizePixel  = 0
    logoBox.Parent           = titleBar
    corner(logoBox, UDim.new(0, 8))

    local logoTxt = Instance.new("TextLabel")
    logoTxt.Size                 = UDim2.new(1, 0, 1, 0)
    logoTxt.BackgroundTransparency = 1
    logoTxt.Text                 = "🐾"
    logoTxt.TextSize             = 16
    logoTxt.Font                 = Enum.Font.GothamBold
    logoTxt.Parent               = logoBox

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Position           = UDim2.new(0, 54, 0, 10)
    titleLbl.Size               = UDim2.new(0, 200, 0, 20)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text               = "Vanguard"
    titleLbl.TextColor3         = C.goldGlow
    titleLbl.Font               = Enum.Font.GothamBold
    titleLbl.TextSize           = 16
    titleLbl.TextXAlignment     = Enum.TextXAlignment.Left
    titleLbl.Parent             = titleBar

    local subLbl = Instance.new("TextLabel")
    subLbl.Position           = UDim2.new(0, 54, 0, 32)
    subLbl.Size               = UDim2.new(0, 260, 0, 14)
    subLbl.BackgroundTransparency = 1
    subLbl.Text               = "Pull An Egg  ·  Automation Suite"
    subLbl.TextColor3         = C.textMuted
    subLbl.Font               = Enum.Font.Gotham
    subLbl.TextSize           = 10
    subLbl.TextXAlignment     = Enum.TextXAlignment.Left
    subLbl.Parent             = titleBar

    -- Window control buttons
    local function winBtn(col, sym, xOff)
        local b = Instance.new("TextButton")
        b.Position        = UDim2.new(1, xOff, 0.5, -13)
        b.Size            = UDim2.new(0, 26, 0, 26)
        b.BackgroundColor3 = col
        b.Text            = sym
        b.TextColor3      = C.white
        b.TextSize        = 11
        b.Font            = Enum.Font.GothamBold
        b.AutoButtonColor = false
        b.Parent          = titleBar
        corner(b, UDim.new(0, 6))
        b.MouseEnter:Connect(function() tw(b, {BackgroundTransparency = 0.3}) end)
        b.MouseLeave:Connect(function() tw(b, {BackgroundTransparency = 0.0}) end)
        return b
    end
    local closeBtn = winBtn(C.red,                      "✕", -38)
    local minBtn   = winBtn(Color3.fromRGB(55, 55, 55), "─", -72)

    -- Title bar rule
    local tbRule = Instance.new("Frame")
    tbRule.Position         = UDim2.new(0, 0, 1, -1)
    tbRule.Size             = UDim2.new(1, 0, 0, 1)
    tbRule.BackgroundColor3 = C.border0
    tbRule.BorderSizePixel  = 0
    tbRule.Parent           = titleBar

    -- Window drag
    local winDragging, winDragInput, winDragStart, winDragPos
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            winDragging  = true
            winDragStart = i.Position
            winDragPos   = shell.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    winDragging = false
                end
            end)
        end
    end)
    titleBar.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            winDragInput = i
        end
    end)

    -- Shared InputChanged for both drags
    local dragConn = UserInputService.InputChanged:Connect(function(i)
        if i == winDragInput and winDragging then
            local d = i.Position - winDragStart
            shell.Position = UDim2.new(
                winDragPos.X.Scale, winDragPos.X.Offset + d.X,
                winDragPos.Y.Scale, winDragPos.Y.Offset + d.Y)
        end
        if i == fabDragInput and fabDragging then
            local d = i.Position - fabDragStart
            fabFrame.Position = UDim2.new(
                fabDragPos.X.Scale, fabDragPos.X.Offset + d.X,
                fabDragPos.Y.Scale, fabDragPos.Y.Offset + d.Y)
        end
    end)
    table.insert(UI._conns, dragConn)

    -- Toggle visibility
    local function toggleShell()
        shell.Visible = not shell.Visible
        tw(fabStroke, {Color = shell.Visible and C.goldGlow or C.gold})
        tw(fabFrame,  {BackgroundColor3 = shell.Visible and C.goldDim or C.bg1})
    end
    fabBtn.MouseButton1Click:Connect(toggleShell)
    closeBtn.MouseButton1Click:Connect(function()
        shell.Visible = false
        tw(fabStroke, {Color = C.gold})
        tw(fabFrame,  {BackgroundColor3 = C.bg1})
    end)
    minBtn.MouseButton1Click:Connect(function()
        shell.Visible = false
        tw(fabStroke, {Color = C.gold})
        tw(fabFrame,  {BackgroundColor3 = C.bg1})
    end)

    -- Ctrl keyboard shortcut
    local kbConn = UserInputService.InputBegan:Connect(function(i, gpe)
        if not gpe and (i.KeyCode == Enum.KeyCode.LeftControl
                     or i.KeyCode == Enum.KeyCode.RightControl) then
            toggleShell()
        end
    end)
    table.insert(UI._conns, kbConn)

    -- ── Ribbon Tab Bar ───────────────────────────────────────────────
    local ribbon = Instance.new("Frame")
    ribbon.Name             = "Ribbon"
    ribbon.Position         = UDim2.new(0, 0, 0, 56)
    ribbon.Size             = UDim2.new(1, 0, 0, 46)
    ribbon.BackgroundColor3 = C.bg0
    ribbon.BorderSizePixel  = 0
    ribbon.Parent           = main

    local ribbonRow = Instance.new("Frame")
    ribbonRow.Position           = UDim2.new(0, 14, 0, 4)
    ribbonRow.Size               = UDim2.new(1, -14, 1, -4)
    ribbonRow.BackgroundTransparency = 1
    ribbonRow.Parent             = ribbon
    listLayout(ribbonRow, 4, Enum.FillDirection.Horizontal)

    local ribbonRule = Instance.new("Frame")
    ribbonRule.Position         = UDim2.new(0, 0, 1, -1)
    ribbonRule.Size             = UDim2.new(1, 0, 0, 1)
    ribbonRule.BackgroundColor3 = C.border0
    ribbonRule.BorderSizePixel  = 0
    ribbonRule.Parent           = ribbon

    -- ── Content Area ─────────────────────────────────────────────────
    local contentArea = Instance.new("Frame")
    contentArea.Position           = UDim2.new(0, 0, 0, 102)
    contentArea.Size               = UDim2.new(1, 0, 1, -102)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent             = main

    -- ────────────────────────────────────────────────────────────────
    --  COMPONENT BUILDERS
    -- ────────────────────────────────────────────────────────────────

    local function outerCard(parent, h)
        local o = Instance.new("Frame")
        o.Size             = UDim2.new(1, 0, 0, h or 66)
        o.BackgroundColor3 = C.bg2
        o.BorderSizePixel  = 0
        o.Parent           = parent
        corner(o, UDim.new(0, 12))
        stroke(o, C.border1, 1)
        return o
    end

    local function innerCard(outer, mx, my)
        mx = mx or 5 ; my = my or 5
        local i = Instance.new("Frame")
        i.Size             = UDim2.new(1, -mx*2, 1, -my*2)
        i.Position         = UDim2.new(0, mx, 0, my)
        i.BackgroundColor3 = C.bg3
        i.BorderSizePixel  = 0
        i.Parent           = outer
        corner(i, UDim.new(0, 8))
        stroke(i, C.border2, 1)
        return i
    end

    -- Section divider
    local function sectionLabel(page, text)
        local row = Instance.new("Frame")
        row.Size                 = UDim2.new(1, 0, 0, 26)
        row.BackgroundTransparency = 1
        row.Parent               = page

        local line = Instance.new("Frame")
        line.Position         = UDim2.new(0, 0, 0.5, 0)
        line.Size             = UDim2.new(1, 0, 0, 1)
        line.BackgroundColor3 = C.border1
        line.BorderSizePixel  = 0
        line.Parent           = row

        local bg = Instance.new("Frame")
        bg.BackgroundColor3 = C.bg1
        bg.BorderSizePixel  = 0
        bg.Position         = UDim2.new(0, 0, 0, 4)
        bg.Size             = UDim2.new(0, #text * 7 + 20, 0, 18)
        bg.Parent           = row

        local lbl = Instance.new("TextLabel")
        lbl.Size                 = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text                 = "  " .. text
        lbl.TextColor3           = C.textSec
        lbl.Font                 = Enum.Font.GothamBold
        lbl.TextSize             = 9
        lbl.TextXAlignment       = Enum.TextXAlignment.Left
        lbl.Parent               = bg
        return row
    end

    -- Toggle with animated slider knob
    local function createToggle(page, labelText, defaultState, onToggle)
        local o   = outerCard(page, 62)
        local inn = innerCard(o)

        local dot = Instance.new("Frame")
        dot.Position         = UDim2.new(0, 12, 0.5, -4)
        dot.Size             = UDim2.new(0, 8, 0, 8)
        dot.BackgroundColor3 = defaultState and C.green or C.textMuted
        dot.BorderSizePixel  = 0
        dot.Parent           = inn
        corner(dot, UDim.new(1, 0))

        local lbl = Instance.new("TextLabel")
        lbl.Position           = UDim2.new(0, 28, 0, 0)
        lbl.Size               = UDim2.new(1, -96, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text               = labelText
        lbl.TextColor3         = C.textPri
        lbl.Font               = Enum.Font.GothamMedium
        lbl.TextSize           = 13
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.TextTruncate       = Enum.TextTruncate.AtEnd
        lbl.Parent             = inn

        local track = Instance.new("Frame")
        track.Position         = UDim2.new(1, -60, 0.5, -12)
        track.Size             = UDim2.new(0, 48, 0, 24)
        track.BackgroundColor3 = defaultState and C.greenDim or C.bg0
        track.BorderSizePixel  = 0
        track.Parent           = inn
        corner(track, UDim.new(1, 0))
        local trackS = stroke(track, defaultState and C.green or C.border1, 1)

        local knob = Instance.new("Frame")
        knob.Size             = UDim2.new(0, 16, 0, 16)
        knob.Position         = defaultState
            and UDim2.new(1, -20, 0.5, -8)
            or  UDim2.new(0,   4, 0.5, -8)
        knob.BackgroundColor3 = defaultState and C.green or C.textMuted
        knob.BorderSizePixel  = 0
        knob.Parent           = track
        corner(knob, UDim.new(1, 0))

        local hit = Instance.new("TextButton")
        hit.Size                 = UDim2.new(1, 0, 1, 0)
        hit.BackgroundTransparency = 1
        hit.Text                 = ""
        hit.Parent               = inn

        local state = defaultState
        hit.MouseButton1Click:Connect(function()
            state = not state
            tw(knob,  {Position          = state and UDim2.new(1,-20,0.5,-8) or UDim2.new(0,4,0.5,-8),
                       BackgroundColor3   = state and C.green or C.textMuted})
            tw(track, {BackgroundColor3  = state and C.greenDim or C.bg0})
            tw(trackS,{Color             = state and C.green or C.border1})
            tw(dot,   {BackgroundColor3  = state and C.green or C.textMuted})
            if onToggle then onToggle(state) end
        end)

        -- Hover reads live state so the colour never flashes stale
        hit.MouseEnter:Connect(function()
            tw(o, {BackgroundColor3 = Color3.fromRGB(42, 42, 42)})
        end)
        hit.MouseLeave:Connect(function()
            tw(o, {BackgroundColor3 = C.bg2})
        end)

        return o
    end

    -- Action button with left accent bar
    local function createButton(page, labelText, accentCol, onClick)
        local o   = outerCard(page, 52)
        local inn = Instance.new("TextButton")
        inn.Size              = UDim2.new(1, -10, 1, -10)
        inn.Position          = UDim2.new(0, 5, 0, 5)
        inn.BackgroundColor3  = C.bg3
        inn.Text              = ""
        inn.AutoButtonColor   = false
        inn.BorderSizePixel   = 0
        inn.Parent            = o
        corner(inn, UDim.new(0, 8))
        stroke(inn, C.border2, 1)

        local bar = Instance.new("Frame")
        bar.Size             = UDim2.new(0, 3, 0.55, 0)
        bar.Position         = UDim2.new(0, 10, 0.225, 0)
        bar.BackgroundColor3 = accentCol or C.gold
        bar.BorderSizePixel  = 0
        bar.Parent           = inn
        corner(bar, UDim.new(1, 0))

        local lbl = Instance.new("TextLabel")
        lbl.Position           = UDim2.new(0, 22, 0, 0)
        lbl.Size               = UDim2.new(1, -40, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text               = labelText
        lbl.TextColor3         = C.textPri
        lbl.Font               = Enum.Font.GothamMedium
        lbl.TextSize           = 13
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.TextTruncate       = Enum.TextTruncate.AtEnd
        lbl.Parent             = inn

        local arr = Instance.new("TextLabel")
        arr.Position           = UDim2.new(1, -26, 0, 0)
        arr.Size               = UDim2.new(0, 18, 1, 0)
        arr.BackgroundTransparency = 1
        arr.Text               = "›"
        arr.TextColor3         = C.textMuted
        arr.Font               = Enum.Font.GothamBold
        arr.TextSize           = 18
        arr.Parent             = inn

        inn.MouseEnter:Connect(function()
            tw(inn, {BackgroundColor3 = Color3.fromRGB(38, 38, 38)})
            tw(lbl, {TextColor3 = accentCol or C.gold})
            tw(arr, {TextColor3 = accentCol or C.gold})
        end)
        inn.MouseLeave:Connect(function()
            tw(inn, {BackgroundColor3 = C.bg3})
            tw(lbl, {TextColor3 = C.textPri})
            tw(arr, {TextColor3 = C.textMuted})
        end)
        inn.MouseButton1Click:Connect(function()
            if onClick then onClick() end
        end)
        return o
    end

    -- ────────────────────────────────────────────────────────────────
    --  TAB SYSTEM
    -- ────────────────────────────────────────────────────────────────

    local tabs    = {}
    local tabBtns = {}

    local function createTab(name, icon, col)
        local tabCol  = col or C.gold
        local isFirst = (#tabBtns == 0)

        local btn = Instance.new("TextButton")
        btn.Size                 = UDim2.new(0, 0, 1, -8)
        btn.Position             = UDim2.new(0, 0, 0, 4)
        btn.AutomaticSize        = Enum.AutomaticSize.X
        btn.BackgroundColor3     = tabCol
        btn.BackgroundTransparency = isFirst and 0.88 or 1
        btn.Text                 = ""
        btn.AutoButtonColor      = false
        btn.Parent               = ribbonRow
        corner(btn, UDim.new(0, 8))

        local bpad = Instance.new("UIPadding")
        bpad.PaddingLeft   = UDim.new(0, 12)
        bpad.PaddingRight  = UDim.new(0, 12)
        bpad.PaddingTop    = UDim.new(0, 4)
        bpad.PaddingBottom = UDim.new(0, 4)
        bpad.Parent        = btn

        local brow = Instance.new("Frame")
        brow.Size                 = UDim2.new(1, 0, 1, 0)
        brow.BackgroundTransparency = 1
        brow.Parent               = btn
        listLayout(brow, 5, Enum.FillDirection.Horizontal)

        local ic = Instance.new("TextLabel")
        ic.Size                 = UDim2.new(0, 16, 1, 0)
        ic.BackgroundTransparency = 1
        ic.Text                 = icon
        ic.TextSize             = 13
        ic.Font                 = Enum.Font.GothamBold
        ic.TextColor3           = isFirst and tabCol or C.textSec
        ic.Parent               = brow

        local nm = Instance.new("TextLabel")
        nm.Size                 = UDim2.new(0, 0, 1, 0)
        nm.AutomaticSize        = Enum.AutomaticSize.X
        nm.BackgroundTransparency = 1
        nm.Text                 = name
        nm.Font                 = Enum.Font.GothamBold
        nm.TextSize             = 12
        nm.TextColor3           = isFirst and tabCol or C.textSec
        nm.Parent               = brow

        local ind = Instance.new("Frame")
        ind.Size             = UDim2.new(isFirst and 1 or 0, 0, 0, 2)
        ind.Position         = UDim2.new(0, 0, 1, -2)
        ind.BackgroundColor3 = tabCol
        ind.BorderSizePixel  = 0
        ind.Parent           = btn
        corner(ind, UDim.new(1, 0))

        local page = Instance.new("ScrollingFrame")
        page.Size                  = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel       = 0
        page.ScrollBarThickness    = 3
        page.ScrollBarImageColor3  = C.border1
        page.CanvasSize            = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize   = Enum.AutomaticSize.Y
        page.Visible               = isFirst
        page.Parent                = contentArea
        padding(page, 14, 12)
        listLayout(page, 8)

        local entry = {name=name, btn=btn, ic=ic, nm=nm, ind=ind, page=page, col=tabCol}
        tabs[#tabs+1]    = entry
        tabBtns[#tabBtns+1] = btn
        return page
    end

    local function selectTab(targetName)
        for _, t in ipairs(tabs) do
            local active = (t.name == targetName)
            t.page.Visible = active
            tw(t.btn, {BackgroundTransparency = active and 0.88 or 1})
            tw(t.ic,  {TextColor3 = active and t.col or C.textSec})
            tw(t.nm,  {TextColor3 = active and t.col or C.textSec})
            tw(t.ind, {Size = UDim2.new(active and 1 or 0, 0, 0, 2)})
        end
    end

    -- Wire tab buttons after all tabs are created (done below)
    local function wireTabButtons()
        for _, t in ipairs(tabs) do
            local name = t.name
            t.btn.MouseButton1Click:Connect(function() selectTab(name) end)
        end
    end

    -- ────────────────────────────────────────────────────────────────
    --  TAB 1 — Farm
    -- ────────────────────────────────────────────────────────────────
    local farmPage = createTab("Farm", "🌾")

    sectionLabel(farmPage, "AUTOMATION")

    createToggle(farmPage, "Auto Train", Config.AutoTrain, function(s)
        Config.AutoTrain = s
        if s then Farm.startAutoTrain() else Farm.stopAutoTrain() end
    end)

    createToggle(farmPage, "Auto Sell Friends", Config.AutoSell, function(s)
        Config.AutoSell = s
        if s then Farm.startAutoSell() else Farm.stopAutoSell() end
    end)

    createToggle(farmPage, "Auto Rebirth", Config.AutoRebirth, function(s)
        Config.AutoRebirth = s
        if s then Farm.startAutoRebirth() else Farm.stopAutoRebirth() end
    end)

    createToggle(farmPage, "Auto Buy Dumbbells", Config.AutoBuyDumbell, function(s)
        Config.AutoBuyDumbell = s
        if s then Farm.startAutoBuyDumbell() else Farm.stopAutoBuyDumbell() end
    end)

    createToggle(farmPage, "Auto Upgrade Carry Limit", Config.AutoUpgradeCarry, function(s)
        Config.AutoUpgradeCarry = s
        if s then Farm.startAutoUpgradeCarry() else Farm.stopAutoUpgradeCarry() end
    end)

    createToggle(farmPage, "Auto Buy Gear", Config.AutoBuyGear, function(s)
        Config.AutoBuyGear = s
        if s then Farm.startAutoBuyGear() else Farm.stopAutoBuyGear() end
    end)

    sectionLabel(farmPage, "EGG PULLING")

    createToggle(farmPage, "Auto Pull Egg (Target Tier)", Config.AutoPullEgg, function(s)
        Config.AutoPullEgg = s
        if s then Farm.startAutoPullEgg() else Farm.stopAutoPullEgg() end
    end)

    createToggle(farmPage, "Safe Fly / Boss Hover", Config.SafeHover, function(s)
        Config.SafeHover = s
        if not s then Farm.setFloat(false) ; Farm.setNoclip(false) end
    end)

    sectionLabel(farmPage, "SAFETY")

    createToggle(farmPage, "Auto Revive (Instant)", Config.AutoRevive, function(s)
        Config.AutoRevive = s
    end)

    -- ────────────────────────────────────────────────────────────────
    --  TAB 2 — ESP
    -- ────────────────────────────────────────────────────────────────
    local espPage = createTab("ESP", "🥚")

    sectionLabel(espPage, "VISUALS")

    createToggle(espPage, "Egg 3D Billboard ESP", Config.EggESP, function(s)
        Config.EggESP = s
        ESP.setEnabled(s)
    end)

    sectionLabel(espPage, "TELEPORT TO TIER")

    for _, tier in ipairs(Config.TIERS) do
        local col = Config.TIER_COLORS[tier] or C.textSec
        local btn = createButton(espPage, tier, col, function()
            Config.TargetEggTier = tier
            Farm.teleportToTier(tier)
        end)
        -- Tier colour swatch dot
        local dot = Instance.new("Frame")
        dot.Size             = UDim2.new(0, 8, 0, 8)
        dot.Position         = UDim2.new(1, -22, 0.5, -4)
        dot.BackgroundColor3 = col
        dot.BorderSizePixel  = 0
        dot.Parent           = btn
        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(0, 4)
        dc.Parent = dot
    end

    -- ────────────────────────────────────────────────────────────────
    --  TAB 3 — Misc
    -- ────────────────────────────────────────────────────────────────
    local miscPage = createTab("Misc", "⚙️")

    sectionLabel(miscPage, "REWARDS")

    createButton(miscPage, "Claim Daily & Group Rewards", C.green, function()
        Remotes.claimDailyReward()
        Remotes.claimGroupReward()
    end)

    createButton(miscPage, "Sell All Friends (Manual)", C.gold, function()
        Remotes.sellAll()
    end)

    sectionLabel(miscPage, "TELEPORT")

    createButton(miscPage, "Teleport to Spawn",         C.gold, function() Farm.teleportToSpawn() end)
    createButton(miscPage, "Teleport to Sell Shop",     C.gold, function() Farm.teleportToShop("Sell") end)
    createButton(miscPage, "Teleport to Strength Shop", C.gold, function() Farm.teleportToShop("ShopSpeed") end)
    createButton(miscPage, "Teleport to Carry Shop",    C.gold, function() Farm.teleportToShop("ShopCarry") end)

    -- ── Wire tabs & activate first ───────────────────────────────────
    wireTabButtons()
    if #tabs > 0 then selectTab(tabs[1].name) end

    -- ── Mount ─────────────────────────────────────────────────────────
    screenGui.Parent = parent
    toggleGui.Parent = parent

    UI.ScreenGui = screenGui
    UI.ToggleGui = toggleGui
    UI.MainFrame = shell
end

-- ── Destroy ───────────────────────────────────────────────────────────

function UI.destroy()
    for _, conn in ipairs(UI._conns) do
        pcall(function() conn:Disconnect() end)
    end
    UI._conns = {}
    if UI.ScreenGui then pcall(function() UI.ScreenGui:Destroy() end) end
    if UI.ToggleGui then pcall(function() UI.ToggleGui:Destroy() end) end
    UI.ScreenGui = nil
    UI.ToggleGui = nil
    UI.MainFrame = nil
end

return UI
