-- src/UI.lua
local NS = getgenv().EggsESP
local AppConfig  = NS.Config
local S          = NS.Services
local StateStore = NS.StateStore
local Utils      = NS.Utils
local ESP        = NS.ESP
local Farm       = NS.Farm
local Rebirth    = NS.Rebirth
local Movement   = NS.Movement
local Plot       = NS.Plot

local UI = {}

function UI.getStroke(frame)
    return frame and frame:FindFirstChildWhichIsA("UIStroke")
end

function UI.applyCard(frame, cornerRadius, bgColor, strokeColor, strokeTransparency)
    frame.BackgroundColor3 = bgColor or AppConfig.OuterCardBg
    frame.BackgroundTransparency = AppConfig.OuterCardTransparency
    frame.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, cornerRadius or AppConfig.Radius2XL)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = strokeColor or AppConfig.CardBorder
    stroke.Transparency = strokeTransparency or AppConfig.BorderTransparency
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = frame
    return corner, stroke
end

function UI.styleButton(button, customRadius, normalBg, hoverBg)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, customRadius or AppConfig.RadiusLG)
    corner.Parent = button
    local stroke = Instance.new("UIStroke")
    stroke.Color = AppConfig.BorderInner
    stroke.Transparency = 0.55
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = button
    button.AutoButtonColor = false
    button:SetAttribute("DefaultBg", normalBg or button.BackgroundColor3)
    local targetHoverBg = hoverBg or Color3.fromRGB(44, 44, 44)
    button.MouseEnter:Connect(function()
        Utils.tween(button, { BackgroundColor3 = targetHoverBg }, 0.12)
        Utils.tween(stroke, { Transparency = 0.25, Color = Color3.fromRGB(75, 75, 75) }, 0.12)
    end)
    button.MouseLeave:Connect(function()
        local bg = button:GetAttribute("DefaultBg") or AppConfig.NestedCardBg
        Utils.tween(button, { BackgroundColor3 = bg }, 0.12)
        Utils.tween(stroke, { Transparency = 0.55, Color = AppConfig.BorderInner }, 0.12)
    end)
end

function UI.setButtonDefault(button, color)
    if not button then return end
    button:SetAttribute("DefaultBg", color)
    button.BackgroundColor3 = color
end

function UI.styleInput(textBox, customRadius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, customRadius or AppConfig.RadiusLG)
    corner.Parent = textBox
    local stroke = Instance.new("UIStroke")
    stroke.Color = AppConfig.BorderInner
    stroke.Transparency = 0.55
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = textBox
    textBox.Focused:Connect(function()
        Utils.tween(stroke, { Color = AppConfig.AccentGreen, Transparency = 0.2 }, 0.15)
    end)
    textBox.FocusLost:Connect(function()
        Utils.tween(stroke, { Color = AppConfig.BorderInner, Transparency = 0.55 }, 0.15)
    end)
end

local activeSliders = {}
S.UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        for _, cb in pairs(activeSliders) do cb(input) end
    end
end)
S.UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        table.clear(activeSliders)
    end
end)

function UI.createToggle(parent, titleText, descText, initialValue, onToggle)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -4, 0, 52)
    frame.BackgroundColor3 = AppConfig.NestedCardBg
    frame.Parent = parent
    UI.applyCard(frame, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 0, 20)
    title.Position = UDim2.new(0, 14, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.TextColor3 = AppConfig.TextPrimary
    title.TextSize = AppConfig.TextBody
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -80, 0, 16)
    desc.Position = UDim2.new(0, 14, 0, 28)
    desc.BackgroundTransparency = 1
    desc.Text = descText or ""
    desc.TextColor3 = AppConfig.TextMuted
    desc.TextSize = AppConfig.TextMicro
    desc.Font = Enum.Font.GothamMedium
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = frame

    local toggleTrack = Instance.new("TextButton")
    toggleTrack.Size = UDim2.new(0, 44, 0, 24)
    toggleTrack.Position = UDim2.new(1, -58, 0.5, -12)
    toggleTrack.BackgroundColor3 = initialValue and AppConfig.AccentGreen or Color3.fromRGB(40, 40, 40)
    toggleTrack.Text = ""
    toggleTrack.AutoButtonColor = false
    toggleTrack.Parent = frame

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = toggleTrack

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = initialValue and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = toggleTrack

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local state = initialValue
    toggleTrack.MouseButton1Click:Connect(function()
        state = not state
        local targetTrackColor = state and AppConfig.AccentGreen or Color3.fromRGB(40, 40, 40)
        local targetKnobPos = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        Utils.tween(toggleTrack, { BackgroundColor3 = targetTrackColor }, 0.15)
        Utils.tween(knob, { Position = targetKnobPos }, 0.15)
        if onToggle then onToggle(state) end
    end)
    return frame
end

function UI.createSlider(parent, titleText, minVal, maxVal, defaultVal, unitStr, onChange)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -4, 0, 60)
    frame.BackgroundColor3 = AppConfig.NestedCardBg
    frame.Parent = parent
    UI.applyCard(frame, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.6, 0, 0, 20)
    title.Position = UDim2.new(0, 14, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.TextColor3 = AppConfig.TextPrimary
    title.TextSize = AppConfig.TextBody
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.35, -14, 0, 20)
    valLabel.Position = UDim2.new(0.65, 0, 0, 8)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = string.format("%s %s", tostring(defaultVal), unitStr or "")
    valLabel.TextColor3 = AppConfig.AccentBlue
    valLabel.TextSize = AppConfig.TextCaption
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = frame

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -28, 0, 6)
    track.Position = UDim2.new(0, 14, 0, 38)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = frame

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local pct = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = AppConfig.AccentBlue
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.Position = UDim2.new(1, -7, 0.5, -7)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.Parent = fill

    local thumbCorner = Instance.new("UICorner")
    thumbCorner.CornerRadius = UDim.new(1, 0)
    thumbCorner.Parent = thumb

    StateStore._sliderCounter = StateStore._sliderCounter + 1
    local sliderId = "slider_" .. tostring(StateStore._sliderCounter)

    local function updateFromInput(input)
        local inputPos = input.Position.X
        local trackPos = track.AbsolutePosition.X
        local trackWidth = track.AbsoluteSize.X
        if trackWidth <= 0 then return end
        local relX = math.clamp((inputPos - trackPos) / trackWidth, 0, 1)
        local val = math.floor(minVal + (maxVal - minVal) * relX + 0.5)
        fill.Size = UDim2.new(relX, 0, 1, 0)
        valLabel.Text = string.format("%s %s", tostring(val), unitStr or "")
        if onChange then onChange(val) end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activeSliders[sliderId] = updateFromInput
            updateFromInput(input)
        end
    end)
    S.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activeSliders[sliderId] = nil
        end
    end)

    return frame
end

-- ═══════════════════════════════════════════════════════════════════
-- UI.mount() — Full window with Vanguard logo
-- ═══════════════════════════════════════════════════════════════════
function UI.mount()
    local LOGO_URL = "https://yourimageshare.com/ib/K3HDoXCNox.png"

    -- Resolve GUI parent defensively (S.TargetParent set by Services.lua)
    local guiParent = S.TargetParent or S.GuiParent
    if not guiParent then
        warn("[Vanguard] UI.mount: GUI parent is nil, aborting mount.")
        return
    end

    local old = guiParent:FindFirstChild("RenderedEggsESP_Menu")
    if old then pcall(function() old:Destroy() end) end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RenderedEggsESP_Menu"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = guiParent
    StateStore.screenGui = ScreenGui

    ScreenGui.Destroying:Connect(function()
        StateStore.onHistoryUpdated = nil
        StateStore.onTimeUpdated = nil
        StateStore.screenGui = nil
    end)

    -- Alert Stack
    local AlertStack = Instance.new("Frame")
    AlertStack.Name = "AlertStack"
    AlertStack.Size = UDim2.new(0, 320, 0, 260)
    AlertStack.Position = UDim2.new(1, -335, 0, 20)
    AlertStack.BackgroundTransparency = 1
    AlertStack.Parent = ScreenGui

    local AlertLayout = Instance.new("UIListLayout")
    AlertLayout.SortOrder = Enum.SortOrder.LayoutOrder
    AlertLayout.Padding = UDim.new(0, 8)
    AlertLayout.Parent = AlertStack

    -- ══════════════════════════════════════════════════════════════
    -- MAIN WINDOW
    -- ══════════════════════════════════════════════════════════════
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, AppConfig.PCWidth, 0, AppConfig.PCHeight)
    MainFrame.Position = UDim2.new(0.5, -AppConfig.PCWidth / 2, 0.5, -AppConfig.PCHeight / 2)
    MainFrame.BackgroundColor3 = AppConfig.BgColor
    MainFrame.BackgroundTransparency = AppConfig.BgTransparency
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Visible = true
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    UI.applyCard(MainFrame, AppConfig.Radius2XL, AppConfig.BgColor, AppConfig.CardBorder)

    -- ══════════════════════════════════════════════════════════════
    -- TOPBAR
    -- ══════════════════════════════════════════════════════════════
    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 46)
    TopBar.BackgroundColor3 = AppConfig.BgColor
    TopBar.BackgroundTransparency = 1
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    local TopDivider = Instance.new("Frame")
    TopDivider.Size = UDim2.new(1, -24, 0, 1)
    TopDivider.Position = UDim2.new(0, 12, 1, -1)
    TopDivider.BackgroundColor3 = AppConfig.BorderInner
    TopDivider.BackgroundTransparency = 0.4
    TopDivider.BorderSizePixel = 0
    TopDivider.Parent = TopBar

    -- ⭐ LOGO in TopBar
    local LogoImage = Instance.new("ImageLabel")
    LogoImage.Name = "LogoImage"
    LogoImage.Size = UDim2.new(0, 36, 0, 36)
    LogoImage.Position = UDim2.new(0, 10, 0.5, -18)
    LogoImage.BackgroundTransparency = 1
    LogoImage.Image = LOGO_URL
    LogoImage.ScaleType = Enum.ScaleType.Fit
    LogoImage.Parent = TopBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(0, 320, 0, 20)
    TitleLabel.Position = UDim2.new(0, 54, 0, 6)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "Luxury<font color='#00e676'>X</font>HUB"
    TitleLabel.RichText = true
    TitleLabel.TextColor3 = AppConfig.TextPrimary
    TitleLabel.TextSize = AppConfig.TextTitle
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TopBar

    local SubLabel = Instance.new("TextLabel")
    SubLabel.Size = UDim2.new(0, 320, 0, 14)
    SubLabel.Position = UDim2.new(0, 54, 0, 27)
    SubLabel.BackgroundTransparency = 1
    SubLabel.Text = "v" .. AppConfig.Version
    SubLabel.TextColor3 = AppConfig.TextMuted
    SubLabel.TextSize = AppConfig.TextMicro
    SubLabel.Font = Enum.Font.GothamMedium
    SubLabel.TextXAlignment = Enum.TextXAlignment.Left
    SubLabel.Parent = TopBar

    local QuickStatusPill = Instance.new("Frame")
    QuickStatusPill.Size = UDim2.new(0, 160, 0, 26)
    QuickStatusPill.Position = UDim2.new(1, -300, 0.5, -13)
    QuickStatusPill.BackgroundColor3 = AppConfig.OuterCardBg
    QuickStatusPill.Parent = TopBar
    UI.applyCard(QuickStatusPill, AppConfig.RadiusMD, AppConfig.OuterCardBg, AppConfig.BorderInner)

    local StatusDot = Instance.new("Frame")
    StatusDot.Size = UDim2.new(0, 6, 0, 6)
    StatusDot.Position = UDim2.new(0, 10, 0.5, -3)
    StatusDot.BackgroundColor3 = AppConfig.AccentGreen
    StatusDot.BorderSizePixel = 0
    StatusDot.Parent = QuickStatusPill

    local DotCorner = Instance.new("UICorner")
    DotCorner.CornerRadius = UDim.new(1, 0)
    DotCorner.Parent = StatusDot

    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, -26, 1, 0)
    StatusLabel.Position = UDim2.new(0, 22, 0, 0)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "System Ready"
    StatusLabel.TextColor3 = AppConfig.AccentGreen
    StatusLabel.TextSize = AppConfig.TextCaption
    StatusLabel.Font = Enum.Font.GothamMedium
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
    StatusLabel.Parent = QuickStatusPill

    local function updateStatus(text, color)
        StatusLabel.Text = text
        StatusLabel.TextColor3 = color or AppConfig.TextPrimary
        StatusDot.BackgroundColor3 = color or AppConfig.AccentGreen
    end

    local ClockPill = Instance.new("Frame")
    ClockPill.Name = "ClockPill"
    ClockPill.Size = UDim2.new(0, 86, 0, 26)
    ClockPill.Position = UDim2.new(1, -132, 0.5, -13)
    ClockPill.BackgroundColor3 = AppConfig.NestedCardBg
    ClockPill.Parent = TopBar
    UI.applyCard(ClockPill, AppConfig.RadiusMD, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local ClockIcon = Instance.new("TextLabel")
    ClockIcon.Size = UDim2.new(0, 18, 1, 0)
    ClockIcon.Position = UDim2.new(0, 6, 0, 0)
    ClockIcon.BackgroundTransparency = 1
    ClockIcon.Text = "⏱"
    ClockIcon.TextSize = 12
    ClockIcon.Font = Enum.Font.GothamBold
    ClockIcon.Parent = ClockPill

    local ClockLabel = Instance.new("TextLabel")
    ClockLabel.Name = "ClockLabel"
    ClockLabel.Size = UDim2.new(1, -24, 1, 0)
    ClockLabel.Position = UDim2.new(0, 22, 0, 0)
    ClockLabel.BackgroundTransparency = 1
    ClockLabel.Text = os.date("%H:%M:%S")
    ClockLabel.TextColor3 = AppConfig.AccentBlue
    ClockLabel.TextSize = AppConfig.TextCaption
    ClockLabel.Font = Enum.Font.GothamBold
    ClockLabel.TextXAlignment = Enum.TextXAlignment.Left
    ClockLabel.Parent = ClockPill

    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
    MinimizeBtn.Position = UDim2.new(1, -40, 0.5, -14)
    MinimizeBtn.BackgroundColor3 = AppConfig.OuterCardBg
    MinimizeBtn.Text = "—"
    MinimizeBtn.TextColor3 = AppConfig.TextSecondary
    MinimizeBtn.TextSize = 11
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.Parent = TopBar
    UI.styleButton(MinimizeBtn, AppConfig.RadiusMD, AppConfig.OuterCardBg)

    -- ══════════════════════════════════════════════════════════════
    -- SIDEBAR
    -- ══════════════════════════════════════════════════════════════
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, AppConfig.SidebarWidth, 1, -58)
    Sidebar.Position = UDim2.new(0, 8, 0, 50)
    Sidebar.BackgroundColor3 = AppConfig.OuterCardBg
    Sidebar.Parent = MainFrame
    UI.applyCard(Sidebar, AppConfig.RadiusXL, AppConfig.OuterCardBg, AppConfig.CardBorder)

    local SidebarLayout = Instance.new("UIListLayout")
    SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SidebarLayout.Padding = UDim.new(0, 3)
    SidebarLayout.Parent = Sidebar

    local SidebarPadding = Instance.new("UIPadding")
    SidebarPadding.PaddingTop = UDim.new(0, 8)
    SidebarPadding.PaddingBottom = UDim.new(0, 56)
    SidebarPadding.PaddingLeft = UDim.new(0, 6)
    SidebarPadding.PaddingRight = UDim.new(0, 6)
    SidebarPadding.Parent = Sidebar

    local SidebarFooter = Instance.new("Frame")
    SidebarFooter.Name = "SidebarFooter"
    SidebarFooter.Size = UDim2.new(1, -12, 0, 40)
    SidebarFooter.Position = UDim2.new(0, 6, 1, -48)
    SidebarFooter.BackgroundColor3 = AppConfig.NestedCardBg
    SidebarFooter.Parent = Sidebar
    UI.applyCard(SidebarFooter, AppConfig.RadiusMD, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local FootPC = Instance.new("TextButton")
    FootPC.Size = UDim2.new(0.5, -3, 1, -6)
    FootPC.Position = UDim2.new(0, 3, 0, 3)
    FootPC.BackgroundColor3 = AppConfig.OuterCardBg
    FootPC.Text = "💻"
    FootPC.TextColor3 = AppConfig.TextSecondary
    FootPC.TextSize = 12
    FootPC.Font = Enum.Font.GothamBold
    FootPC.Parent = SidebarFooter
    UI.styleButton(FootPC, AppConfig.RadiusSM, AppConfig.OuterCardBg)

    local FootMobile = Instance.new("TextButton")
    FootMobile.Size = UDim2.new(0.5, -3, 1, -6)
    FootMobile.Position = UDim2.new(0.5, 0, 0, 3)
    FootMobile.BackgroundColor3 = AppConfig.OuterCardBg
    FootMobile.Text = "📱"
    FootMobile.TextColor3 = AppConfig.TextSecondary
    FootMobile.TextSize = 12
    FootMobile.Font = Enum.Font.GothamBold
    FootMobile.Parent = SidebarFooter
    UI.styleButton(FootMobile, AppConfig.RadiusSM, AppConfig.OuterCardBg)

    -- ══════════════════════════════════════════════════════════════
    -- CONTENT AREA
    -- ══════════════════════════════════════════════════════════════
    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "ContentArea"
    ContentArea.Size = UDim2.new(1, -(AppConfig.SidebarWidth + 20), 1, -58)
    ContentArea.Position = UDim2.new(0, AppConfig.SidebarWidth + 12, 0, 50)
    ContentArea.BackgroundTransparency = 1
    ContentArea.ClipsDescendants = true
    ContentArea.Parent = MainFrame

    local Tabs = {
        { id = "Eggs",     label = "Eggs",       icon = "🥚" },
        { id = "Farm",     label = "Automation", icon = "⚡" },
        { id = "Time",     label = "Time",       icon = "⏱️" },
        { id = "History",  label = "History",    icon = "📜" },
        { id = "Settings", label = "Settings",   icon = "⚙️" },
    }

    local tabButtons = {}
    local tabPanels = {}
    local currentActiveTab = "Eggs"

    local function currentSize()
        if StateStore.windowMode == "PC" then
            return AppConfig.PCWidth, AppConfig.PCHeight
        else
            return AppConfig.MobileWidth, AppConfig.MobileHeight
        end
    end

    local function toggleMinimize()
        StateStore.isMinimized = not StateStore.isMinimized
        local w, h = currentSize()
        if StateStore.isMinimized then
            Sidebar.Visible = false
            ContentArea.Visible = false
            Utils.tween(MainFrame, { Size = UDim2.new(0, w, 0, 46) }, 0.20)
            MinimizeBtn.Text = "+"
        else
            Utils.tween(MainFrame, { Size = UDim2.new(0, w, 0, h) }, 0.20)
            task.delay(0.12, function()
                if not StateStore.isMinimized then
                    Sidebar.Visible = true
                    ContentArea.Visible = true
                end
            end)
            MinimizeBtn.Text = "—"
        end
    end

    MinimizeBtn.MouseButton1Click:Connect(toggleMinimize)

    local function switchTab(targetId)
        currentActiveTab = targetId
        for _, tab in ipairs(Tabs) do
            local isCurrent = (tab.id == targetId)
            local btn = tabButtons[tab.id]
            local panel = tabPanels[tab.id]
            if btn then
                local indicator = btn:FindFirstChild("ActiveBar")
                local icon = btn:FindFirstChild("Icon")
                local label = btn:FindFirstChild("Label")
                local bStroke = btn:FindFirstChildWhichIsA("UIStroke")
                if isCurrent then
                    Utils.tween(btn, { BackgroundColor3 = AppConfig.NestedCardBg }, 0.15)
                    if indicator then Utils.tween(indicator, { BackgroundTransparency = 0 }, 0.15) end
                    if icon then Utils.tween(icon, { TextColor3 = AppConfig.TextPrimary }, 0.15) end
                    if label then Utils.tween(label, { TextColor3 = AppConfig.TextPrimary }, 0.15) end
                    if bStroke then Utils.tween(bStroke, { Color = AppConfig.AccentGreen, Transparency = 0.15 }, 0.15) end
                else
                    Utils.tween(btn, { BackgroundColor3 = Color3.fromRGB(25, 25, 25) }, 0.15)
                    if indicator then Utils.tween(indicator, { BackgroundTransparency = 1 }, 0.15) end
                    if icon then Utils.tween(icon, { TextColor3 = AppConfig.TextMuted }, 0.15) end
                    if label then Utils.tween(label, { TextColor3 = AppConfig.TextSecondary }, 0.15) end
                    if bStroke then Utils.tween(bStroke, { Color = AppConfig.BorderInner, Transparency = 0.7 }, 0.15) end
                end
            end
            if panel then panel.Visible = isCurrent end
        end
    end

    for idx, tab in ipairs(Tabs) do
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "Tab_" .. tab.id
        tabBtn.Size = UDim2.new(1, 0, 0, AppConfig.SidebarItemHeight)
        tabBtn.BackgroundColor3 = (tab.id == "Eggs") and AppConfig.NestedCardBg or Color3.fromRGB(25, 25, 25)
        tabBtn.Text = ""
        tabBtn.AutoButtonColor = false
        tabBtn.LayoutOrder = idx
        tabBtn.Parent = Sidebar

        local tc = Instance.new("UICorner")
        tc.CornerRadius = UDim.new(0, AppConfig.RadiusLG)
        tc.Parent = tabBtn

        local ts = Instance.new("UIStroke")
        ts.Color = (tab.id == "Eggs") and AppConfig.AccentGreen or AppConfig.BorderInner
        ts.Transparency = (tab.id == "Eggs") and 0.15 or 0.7
        ts.Thickness = 1
        ts.Parent = tabBtn

        local activeBar = Instance.new("Frame")
        activeBar.Name = "ActiveBar"
        activeBar.Size = UDim2.new(0, 3, 0, 20)
        activeBar.Position = UDim2.new(0, 0, 0.5, -10)
        activeBar.BackgroundColor3 = AppConfig.AccentGreen
        activeBar.BackgroundTransparency = (tab.id == "Eggs") and 0 or 1
        activeBar.BorderSizePixel = 0
        activeBar.Parent = tabBtn

        local abCorner = Instance.new("UICorner")
        abCorner.CornerRadius = UDim.new(1, 0)
        abCorner.Parent = activeBar

        local iconLbl = Instance.new("TextLabel")
        iconLbl.Name = "Icon"
        iconLbl.Size = UDim2.new(0, 24, 1, 0)
        iconLbl.Position = UDim2.new(0, 12, 0, 0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text = tab.icon
        iconLbl.TextColor3 = (tab.id == "Eggs") and AppConfig.TextPrimary or AppConfig.TextMuted
        iconLbl.TextSize = 14
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.Parent = tabBtn

        local labelLbl = Instance.new("TextLabel")
        labelLbl.Name = "Label"
        labelLbl.Size = UDim2.new(1, -44, 1, 0)
        labelLbl.Position = UDim2.new(0, 40, 0, 0)
        labelLbl.BackgroundTransparency = 1
        labelLbl.Text = tab.label
        labelLbl.TextColor3 = (tab.id == "Eggs") and AppConfig.TextPrimary or AppConfig.TextSecondary
        labelLbl.TextSize = AppConfig.TextBody
        labelLbl.Font = Enum.Font.GothamBold
        labelLbl.TextXAlignment = Enum.TextXAlignment.Left
        labelLbl.Parent = tabBtn

        tabBtn.MouseEnter:Connect(function()
            if currentActiveTab ~= tab.id then
                Utils.tween(tabBtn, { BackgroundColor3 = Color3.fromRGB(34, 34, 34) }, 0.12)
                Utils.tween(iconLbl, { TextColor3 = AppConfig.TextSecondary }, 0.12)
            end
        end)
        tabBtn.MouseLeave:Connect(function()
            if currentActiveTab ~= tab.id then
                Utils.tween(tabBtn, { BackgroundColor3 = Color3.fromRGB(25, 25, 25) }, 0.12)
                Utils.tween(iconLbl, { TextColor3 = AppConfig.TextMuted }, 0.12)
            end
        end)
        tabBtn.MouseButton1Click:Connect(function() switchTab(tab.id) end)

        tabButtons[tab.id] = tabBtn

        local panelFrame = Instance.new("Frame")
        panelFrame.Name = "Panel_" .. tab.id
        panelFrame.Size = UDim2.new(1, 0, 1, 0)
        panelFrame.BackgroundColor3 = AppConfig.OuterCardBg
        panelFrame.Visible = (tab.id == "Eggs")
        panelFrame.Parent = ContentArea
        UI.applyCard(panelFrame, AppConfig.Radius2XL, AppConfig.OuterCardBg, AppConfig.CardBorder)

        local panelPadding = Instance.new("UIPadding")
        panelPadding.PaddingTop = UDim.new(0, 10)
        panelPadding.PaddingBottom = UDim.new(0, 10)
        panelPadding.PaddingLeft = UDim.new(0, 10)
        panelPadding.PaddingRight = UDim.new(0, 10)
        panelPadding.Parent = panelFrame

        tabPanels[tab.id] = panelFrame
    end

    local populateList
    local updateLiveEggsSummary
    local updateHistoryUI

    -- ══════════════════════════════════════════════════════════════
    -- [TAB 1] EGGS
    -- ══════════════════════════════════════════════════════════════
    local EggsPanel = tabPanels["Eggs"]

    local LiveChipsCard = Instance.new("Frame")
    LiveChipsCard.Size = UDim2.new(1, 0, 0, 56)
    LiveChipsCard.BackgroundColor3 = AppConfig.NestedCardBg
    LiveChipsCard.Parent = EggsPanel
    UI.applyCard(LiveChipsCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local LiveTitle = Instance.new("TextLabel")
    LiveTitle.Size = UDim2.new(0.5, 0, 0, 18)
    LiveTitle.Position = UDim2.new(0, 12, 0, 8)
    LiveTitle.BackgroundTransparency = 1
    LiveTitle.Text = "🥚  Live Eggs Realtime"
    LiveTitle.TextColor3 = AppConfig.AccentGold
    LiveTitle.TextSize = AppConfig.TextHeader
    LiveTitle.Font = Enum.Font.GothamBold
    LiveTitle.TextXAlignment = Enum.TextXAlignment.Left
    LiveTitle.Parent = LiveChipsCard

    local LiveSummaryCountLabel = Instance.new("TextLabel")
    LiveSummaryCountLabel.Size = UDim2.new(0.5, -12, 0, 18)
    LiveSummaryCountLabel.Position = UDim2.new(0.5, 0, 0, 8)
    LiveSummaryCountLabel.BackgroundTransparency = 1
    LiveSummaryCountLabel.Text = "Total Live: 0"
    LiveSummaryCountLabel.TextColor3 = AppConfig.TextMuted
    LiveSummaryCountLabel.TextSize = AppConfig.TextCaption
    LiveSummaryCountLabel.Font = Enum.Font.GothamMedium
    LiveSummaryCountLabel.TextXAlignment = Enum.TextXAlignment.Right
    LiveSummaryCountLabel.Parent = LiveChipsCard

    local LiveSummaryContainer = Instance.new("ScrollingFrame")
    LiveSummaryContainer.Size = UDim2.new(1, -20, 0, 26)
    LiveSummaryContainer.Position = UDim2.new(0, 10, 0, 28)
    LiveSummaryContainer.BackgroundTransparency = 1
    LiveSummaryContainer.BorderSizePixel = 0
    LiveSummaryContainer.ScrollBarThickness = 2
    LiveSummaryContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    LiveSummaryContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    LiveSummaryContainer.Parent = LiveChipsCard

    local LiveSummaryLayout = Instance.new("UIListLayout")
    LiveSummaryLayout.SortOrder = Enum.SortOrder.LayoutOrder
    LiveSummaryLayout.FillDirection = Enum.FillDirection.Horizontal
    LiveSummaryLayout.Padding = UDim.new(0, 4)
    LiveSummaryLayout.Parent = LiveSummaryContainer

    LiveSummaryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        LiveSummaryContainer.CanvasSize = UDim2.new(0, LiveSummaryLayout.AbsoluteContentSize.X + 6, 0, 0)
    end)

    local ToolbarCard = Instance.new("Frame")
    ToolbarCard.Size = UDim2.new(1, 0, 0, 42)
    ToolbarCard.Position = UDim2.new(0, 0, 0, 64)
    ToolbarCard.BackgroundColor3 = AppConfig.NestedCardBg
    ToolbarCard.Parent = EggsPanel
    UI.applyCard(ToolbarCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local SearchBoxContainer = Instance.new("Frame")
    SearchBoxContainer.Size = UDim2.new(0.36, 0, 0, 28)
    SearchBoxContainer.Position = UDim2.new(0, 8, 0.5, -14)
    SearchBoxContainer.BackgroundColor3 = AppConfig.RecessedBg
    SearchBoxContainer.Parent = ToolbarCard
    UI.applyCard(SearchBoxContainer, AppConfig.RadiusMD, AppConfig.RecessedBg, AppConfig.BorderInner)

    local SearchBox = Instance.new("TextBox")
    SearchBox.Size = UDim2.new(1, -28, 1, 0)
    SearchBox.Position = UDim2.new(0, 10, 0, 0)
    SearchBox.BackgroundTransparency = 1
    SearchBox.PlaceholderText = "🔍 Search egg..."
    SearchBox.PlaceholderColor3 = AppConfig.TextMuted
    SearchBox.Text = ""
    SearchBox.TextColor3 = AppConfig.TextPrimary
    SearchBox.TextSize = AppConfig.TextCaption
    SearchBox.Font = Enum.Font.GothamMedium
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    SearchBox.ClearTextOnFocus = false
    SearchBox.Parent = SearchBoxContainer

    local ClearSearchBtn = Instance.new("TextButton")
    ClearSearchBtn.Size = UDim2.new(0, 22, 0, 22)
    ClearSearchBtn.Position = UDim2.new(1, -24, 0.5, -11)
    ClearSearchBtn.BackgroundTransparency = 1
    ClearSearchBtn.Text = "✕"
    ClearSearchBtn.TextColor3 = AppConfig.TextMuted
    ClearSearchBtn.TextSize = 10
    ClearSearchBtn.Font = Enum.Font.GothamBold
    ClearSearchBtn.Visible = false
    ClearSearchBtn.Parent = SearchBoxContainer

    local FarmAllBtn = Instance.new("TextButton")
    FarmAllBtn.Size = UDim2.new(0.19, -4, 0, 28)
    FarmAllBtn.Position = UDim2.new(0.37, 2, 0.5, -14)
    FarmAllBtn.BackgroundColor3 = AppConfig.RecessedBg
    FarmAllBtn.Text = "⚡ Farm All"
    FarmAllBtn.TextColor3 = AppConfig.AccentGreen
    FarmAllBtn.TextSize = AppConfig.TextCaption
    FarmAllBtn.Font = Enum.Font.GothamBold
    FarmAllBtn.Parent = ToolbarCard
    UI.styleButton(FarmAllBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    local ClearFarmBtn = Instance.new("TextButton")
    ClearFarmBtn.Size = UDim2.new(0.16, -4, 0, 28)
    ClearFarmBtn.Position = UDim2.new(0.56, 2, 0.5, -14)
    ClearFarmBtn.BackgroundColor3 = AppConfig.RecessedBg
    ClearFarmBtn.Text = "✕ Clear"
    ClearFarmBtn.TextColor3 = AppConfig.AccentRed
    ClearFarmBtn.TextSize = AppConfig.TextCaption
    ClearFarmBtn.Font = Enum.Font.GothamBold
    ClearFarmBtn.Parent = ToolbarCard
    UI.styleButton(ClearFarmBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    local SortBtn = Instance.new("TextButton")
    SortBtn.Size = UDim2.new(0.16, -4, 0, 28)
    SortBtn.Position = UDim2.new(0.72, 2, 0.5, -14)
    SortBtn.BackgroundColor3 = AppConfig.RecessedBg
    SortBtn.Text = "Sort: Name"
    SortBtn.TextColor3 = AppConfig.TextPrimary
    SortBtn.TextSize = AppConfig.TextCaption
    SortBtn.Font = Enum.Font.GothamBold
    SortBtn.Parent = ToolbarCard
    UI.styleButton(SortBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    local EggCountLabel = Instance.new("TextLabel")
    EggCountLabel.Size = UDim2.new(0.11, -4, 0, 28)
    EggCountLabel.Position = UDim2.new(0.88, 0, 0.5, -14)
    EggCountLabel.BackgroundTransparency = 1
    EggCountLabel.Text = "0/0"
    EggCountLabel.TextColor3 = AppConfig.TextMuted
    EggCountLabel.TextSize = AppConfig.TextCaption
    EggCountLabel.Font = Enum.Font.GothamMedium
    EggCountLabel.TextXAlignment = Enum.TextXAlignment.Center
    EggCountLabel.Parent = ToolbarCard

    local ListCard = Instance.new("Frame")
    ListCard.Size = UDim2.new(1, 0, 1, -114)
    ListCard.Position = UDim2.new(0, 0, 0, 114)
    ListCard.BackgroundColor3 = AppConfig.NestedCardBg
    ListCard.Parent = EggsPanel
    UI.applyCard(ListCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local ScrollList = Instance.new("ScrollingFrame")
    ScrollList.Size = UDim2.new(1, -16, 1, -16)
    ScrollList.Position = UDim2.new(0, 8, 0, 8)
    ScrollList.BackgroundTransparency = 1
    ScrollList.BorderSizePixel = 0
    ScrollList.ScrollBarThickness = 3
    ScrollList.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    ScrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollList.Parent = ListCard

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 4)
    UIListLayout.Parent = ScrollList

    UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ScrollList.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 6)
    end)

    local renderedEggRows = {}

    local function createEggItem(egg)
        local itemHeight = 38
        local ItemFrame = Instance.new("Frame")
        ItemFrame.Size = UDim2.new(1, -4, 0, itemHeight)
        ItemFrame.BackgroundColor3 = AppConfig.RecessedBg
        ItemFrame.BorderSizePixel = 0
        ItemFrame.Parent = ScrollList
        UI.applyCard(ItemFrame, AppConfig.RadiusLG, AppConfig.RecessedBg, AppConfig.BorderInner)

        local eggIcon = Instance.new("ImageLabel")
        eggIcon.Size = UDim2.new(0, itemHeight - 10, 0, itemHeight - 10)
        eggIcon.Position = UDim2.new(0, 8, 0.5, -(itemHeight - 10) / 2)
        eggIcon.BackgroundTransparency = 1
        eggIcon.Image = Utils.getEggImage(egg.Name)
        eggIcon.ScaleType = Enum.ScaleType.Fit
        eggIcon.Parent = ItemFrame

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -240, 1, 0)
        nameLabel.Position = UDim2.new(0, itemHeight + 8, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = egg.Name
        nameLabel.TextColor3 = Utils.isRareEgg(egg.Name) and AppConfig.AccentGold or AppConfig.TextPrimary
        nameLabel.TextSize = AppConfig.TextBody
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = ItemFrame

        local distBadge = Instance.new("Frame")
        distBadge.Size = UDim2.new(0, 50, 0, 20)
        distBadge.Position = UDim2.new(1, -220, 0.5, -10)
        distBadge.BackgroundColor3 = AppConfig.NestedCardBg
        distBadge.Parent = ItemFrame
        UI.applyCard(distBadge, AppConfig.RadiusSM, AppConfig.NestedCardBg, AppConfig.BorderInner)

        local distLabel = Instance.new("TextLabel")
        distLabel.Size = UDim2.new(1, 0, 1, 0)
        distLabel.BackgroundTransparency = 1
        distLabel.TextColor3 = AppConfig.TextMuted
        distLabel.TextSize = AppConfig.TextCaption
        distLabel.Font = Enum.Font.Gotham
        local dist = Utils.getDistanceToTarget(egg)
        distLabel.Text = (dist ~= math.huge) and string.format("%dst", math.floor(dist + 0.5)) or "--"
        distLabel.Parent = distBadge

        local TPBtn = Instance.new("TextButton")
        TPBtn.Size = UDim2.new(0, 38, 0, 24)
        TPBtn.Position = UDim2.new(1, -164, 0.5, -12)
        TPBtn.BackgroundColor3 = AppConfig.NestedCardBg
        TPBtn.Text = "TP"
        TPBtn.TextColor3 = AppConfig.TextPrimary
        TPBtn.TextSize = AppConfig.TextCaption
        TPBtn.Font = Enum.Font.GothamBold
        TPBtn.Parent = ItemFrame
        UI.styleButton(TPBtn, AppConfig.RadiusSM, AppConfig.NestedCardBg)

        TPBtn.MouseButton1Click:Connect(function()
            if not egg or not egg.Parent then updateStatus("Egg despawned!", AppConfig.AccentRed); return end
            local ok = Movement.teleportTo(egg)
            if ok then updateStatus("Teleported to " .. egg.Name, AppConfig.AccentGreen) end
        end)

        local AutoFarmBtn = Instance.new("TextButton")
        AutoFarmBtn.Size = UDim2.new(0, 56, 0, 24)
        AutoFarmBtn.Position = UDim2.new(1, -122, 0.5, -12)
        local isFarming = StateStore.autoFarmEggs[egg.Name]
        local farmBg = isFarming and AppConfig.AccentGreen or AppConfig.NestedCardBg
        AutoFarmBtn.BackgroundColor3 = farmBg
        AutoFarmBtn.Text = isFarming and "Farm ON" or "Farm"
        AutoFarmBtn.TextColor3 = isFarming and Color3.fromRGB(10, 20, 15) or AppConfig.TextSecondary
        AutoFarmBtn.TextSize = AppConfig.TextCaption
        AutoFarmBtn.Font = Enum.Font.GothamBold
        AutoFarmBtn.Parent = ItemFrame
        UI.styleButton(AutoFarmBtn, AppConfig.RadiusSM, farmBg)

        AutoFarmBtn.MouseButton1Click:Connect(function()
            if not egg or not egg.Parent then return end
            local name = egg.Name
            if StateStore.autoFarmEggs[name] then
                StateStore.autoFarmEggs[name] = nil
                UI.setButtonDefault(AutoFarmBtn, AppConfig.NestedCardBg)
                AutoFarmBtn.Text = "Farm"
                AutoFarmBtn.TextColor3 = AppConfig.TextSecondary
                updateStatus("Removed from Farm: " .. name, AppConfig.TextSecondary)
                local any = false
                for _, v in pairs(StateStore.autoFarmEggs) do if v then any = true; break end end
                if not any then Farm.stopAutoFarm() end
            else
                StateStore.autoFarmEggs[name] = true
                UI.setButtonDefault(AutoFarmBtn, AppConfig.AccentGreen)
                AutoFarmBtn.Text = "Farm ON"
                AutoFarmBtn.TextColor3 = Color3.fromRGB(10, 20, 15)
                updateStatus("AutoFarm target: " .. name, AppConfig.AccentGreen)
                if not StateStore.autoFarmActive then
                    Farm.startAutoFarm(updateStatus, nil)
                end
            end
            for pe in pairs(StateStore.autoFarmProcessed) do
                if pe and pe.Name == name then StateStore.autoFarmProcessed[pe] = nil end
            end
        end)

        local ESPBtn = Instance.new("TextButton")
        ESPBtn.Size = UDim2.new(0, 46, 0, 24)
        ESPBtn.Position = UDim2.new(1, -62, 0.5, -12)
        ESPBtn.BackgroundColor3 = AppConfig.NestedCardBg
        ESPBtn.TextColor3 = AppConfig.TextSecondary
        ESPBtn.TextSize = AppConfig.TextCaption
        ESPBtn.Font = Enum.Font.GothamBold
        ESPBtn.Parent = ItemFrame
        UI.styleButton(ESPBtn, AppConfig.RadiusSM, AppConfig.NestedCardBg)

        local eggColor = ESP.getColor(egg.Name)
        local ed = StateStore.eggData[egg]
        if ed and ed.CustomActive then
            UI.setButtonDefault(ESPBtn, eggColor)
            ESPBtn.Text = "ON"
            ESPBtn.TextColor3 = Color3.fromRGB(10, 10, 10)
        else
            ESPBtn.Text = "ESP"
        end

        ESPBtn.MouseButton1Click:Connect(function()
            if not StateStore.eggData[egg] then
                StateStore.eggData[egg] = {
                    Highlight = nil, NameBillboard = nil,
                    CustomColor = eggColor, CustomActive = false
                }
            end
            local info = StateStore.eggData[egg]
            info.CustomActive = not info.CustomActive
            info.CustomColor = eggColor
            if info.CustomActive then
                UI.setButtonDefault(ESPBtn, eggColor)
                ESPBtn.Text = "ON"
                ESPBtn.TextColor3 = Color3.fromRGB(10, 10, 10)
                updateStatus("Target ESP: " .. egg.Name, eggColor)
            else
                UI.setButtonDefault(ESPBtn, AppConfig.NestedCardBg)
                ESPBtn.Text = "ESP"
                ESPBtn.TextColor3 = AppConfig.TextSecondary
                updateStatus("Target ESP: OFF", AppConfig.TextSecondary)
            end
            ESP.updateEgg(egg)
        end)

        return ItemFrame
    end

    populateList = function()
        local savedPos = ScrollList.CanvasPosition
        local folder = S.RenderedEggsFolder

        if not folder then
            EggCountLabel.Text = "0/0"
            for egg, row in pairs(renderedEggRows) do
                row:Destroy()
                renderedEggRows[egg] = nil
            end
            return
        end

        local found = {}
        for _, egg in ipairs(folder:GetChildren()) do
            if Utils.isValidEgg(egg) then table.insert(found, egg) end
        end

        if StateStore.sortMode == "Distance" then
            table.sort(found, function(a, b) return Utils.getDistanceToTarget(a) < Utils.getDistanceToTarget(b) end)
        else
            table.sort(found, function(a, b) return a.Name:lower() < b.Name:lower() end)
        end

        local query = StateStore.currentSearchQuery:lower()
        local visible = {}
        for _, egg in ipairs(found) do
            if query == "" or string.find(egg.Name:lower(), query, 1, true) then
                table.insert(visible, egg)
            end
        end

        local visibleSet = {}
        for _, egg in ipairs(visible) do visibleSet[egg] = true end

        for egg, row in pairs(renderedEggRows) do
            if not visibleSet[egg] or not egg.Parent then
                row:Destroy()
                renderedEggRows[egg] = nil
            end
        end

        for i, egg in ipairs(visible) do
            local row = renderedEggRows[egg]
            if not row or not row.Parent then
                row = createEggItem(egg)
                renderedEggRows[egg] = row
            end
            row.LayoutOrder = i
        end

        EggCountLabel.Text = string.format("%d/%d", #visible, #found)

        if #visible == 0 then
            if not ScrollList:FindFirstChild("EmptyLabel") then
                local emptyLabel = Instance.new("TextLabel")
                emptyLabel.Name = "EmptyLabel"
                emptyLabel.Size = UDim2.new(1, -10, 0, 40)
                emptyLabel.BackgroundTransparency = 1
                emptyLabel.Text = "No Eggs Found"
                emptyLabel.TextColor3 = AppConfig.TextMuted
                emptyLabel.TextSize = AppConfig.TextBody
                emptyLabel.Font = Enum.Font.GothamMedium
                emptyLabel.Parent = ScrollList
            end
        else
            local el = ScrollList:FindFirstChild("EmptyLabel")
            if el then el:Destroy() end
        end

        task.defer(function()
            if ScrollList and ScrollList.Parent then ScrollList.CanvasPosition = savedPos end
        end)
    end

    local renderedChips = {}

    updateLiveEggsSummary = function()
        local folder = S.RenderedEggsFolder
        if not folder then return end

        local counts = {}
        local total = 0
        for _, egg in ipairs(folder:GetChildren()) do
            if Utils.isValidEgg(egg) then
                counts[egg.Name] = (counts[egg.Name] or 0) + 1
                total += 1
            end
        end

        LiveSummaryCountLabel.Text = "Total Live: " .. tostring(total)

        for name, chip in pairs(renderedChips) do
            if not counts[name] then
                chip:Destroy()
                renderedChips[name] = nil
            end
        end

        for name, count in pairs(counts) do
            local chip = renderedChips[name]
            if chip and chip.Parent then
                local badge = chip:FindFirstChild("CountBadge")
                if badge then badge.Text = "x" .. tostring(count) end
            else
                local isRare = Utils.isRareEgg(name)
                chip = Instance.new("TextButton")
                chip.Size = UDim2.new(0, 138, 0, 24)
                chip.BackgroundColor3 = isRare and Color3.fromRGB(36, 30, 20) or AppConfig.RecessedBg
                chip.Text = ""
                chip.Parent = LiveSummaryContainer
                UI.applyCard(chip, AppConfig.RadiusSM, chip.BackgroundColor3, isRare and AppConfig.AccentGold or AppConfig.BorderInner)

                local icon = Instance.new("ImageLabel")
                icon.Size = UDim2.new(0, 16, 0, 16)
                icon.Position = UDim2.new(0, 5, 0.5, -8)
                icon.BackgroundTransparency = 1
                icon.Image = Utils.getEggImage(name)
                icon.ScaleType = Enum.ScaleType.Fit
                icon.Parent = chip

                local title = Instance.new("TextLabel")
                title.Size = UDim2.new(1, -50, 1, 0)
                title.Position = UDim2.new(0, 25, 0, 0)
                title.BackgroundTransparency = 1
                title.Text = name
                title.TextColor3 = isRare and AppConfig.AccentGold or AppConfig.TextPrimary
                title.TextSize = AppConfig.TextCaption
                title.Font = Enum.Font.GothamMedium
                title.TextXAlignment = Enum.TextXAlignment.Left
                title.TextTruncate = Enum.TextTruncate.AtEnd
                title.Parent = chip

                local badge = Instance.new("TextLabel")
                badge.Name = "CountBadge"
                badge.Size = UDim2.new(0, 22, 0, 16)
                badge.Position = UDim2.new(1, -26, 0.5, -8)
                badge.BackgroundColor3 = isRare and AppConfig.AccentGold or AppConfig.NestedCardBg
                badge.Text = "x" .. tostring(count)
                badge.TextColor3 = isRare and Color3.fromRGB(15, 15, 20) or AppConfig.TextSecondary
                badge.TextSize = AppConfig.TextMicro
                badge.Font = Enum.Font.GothamBold
                badge.Parent = chip

                local bc = Instance.new("UICorner")
                bc.CornerRadius = UDim.new(0, 4)
                bc.Parent = badge

                chip.MouseButton1Click:Connect(function()
                    if SearchBox.Text == name then
                        SearchBox.Text = ""
                        StateStore.currentSearchQuery = ""
                        ClearSearchBtn.Visible = false
                        updateStatus("Filter cleared", AppConfig.TextSecondary)
                    else
                        SearchBox.Text = name
                        StateStore.currentSearchQuery = name
                        ClearSearchBtn.Visible = true
                        updateStatus("Filtered: " .. name, AppConfig.AccentGreen)
                    end
                    populateList()
                end)

                renderedChips[name] = chip
            end
        end
    end

    FarmAllBtn.MouseButton1Click:Connect(function()
        local folder = S.RenderedEggsFolder
        if not folder then return end
        for _, egg in ipairs(folder:GetChildren()) do
            if Utils.isValidEgg(egg) then StateStore.autoFarmEggs[egg.Name] = true end
        end
        populateList()
        updateStatus("All Eggs Selected for AutoFarm", AppConfig.AccentGreen)
        if not StateStore.autoFarmActive then Farm.startAutoFarm(updateStatus, nil) end
    end)

    ClearFarmBtn.MouseButton1Click:Connect(function()
        table.clear(StateStore.autoFarmEggs)
        table.clear(StateStore.autoFarmProcessed)
        Farm.stopAutoFarm()
        populateList()
        updateStatus("Cleared AutoFarm targets", AppConfig.AccentRed)
    end)

    SortBtn.MouseButton1Click:Connect(function()
        if StateStore.sortMode == "Name" then
            StateStore.sortMode = "Distance"
            SortBtn.Text = "Sort: Dist"
        else
            StateStore.sortMode = "Name"
            SortBtn.Text = "Sort: Name"
        end
        populateList()
    end)

    local searchDebounce = nil
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local newQuery = SearchBox.Text:match("^%s*(.-)%s*$") or ""
        ClearSearchBtn.Visible = (#newQuery > 0)
        if newQuery == StateStore.currentSearchQuery then return end
        StateStore.currentSearchQuery = newQuery
        if searchDebounce then task.cancel(searchDebounce) end
        searchDebounce = task.delay(0.12, populateList)
    end)

    ClearSearchBtn.MouseButton1Click:Connect(function()
        SearchBox.Text = ""
        StateStore.currentSearchQuery = ""
        ClearSearchBtn.Visible = false
        populateList()
    end)

    -- ══════════════════════════════════════════════════════════════
    -- [TAB 2] AUTOMATION
    -- ══════════════════════════════════════════════════════════════
    local FarmPanel = tabPanels["Farm"]

    local FarmScroll = Instance.new("ScrollingFrame")
    FarmScroll.Size = UDim2.new(1, 0, 1, 0)
    FarmScroll.BackgroundTransparency = 1
    FarmScroll.BorderSizePixel = 0
    FarmScroll.ScrollBarThickness = 3
    FarmScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    FarmScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    FarmScroll.Parent = FarmPanel

    local FarmScrollLayout = Instance.new("UIListLayout")
    FarmScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    FarmScrollLayout.Padding = UDim.new(0, 8)
    FarmScrollLayout.Parent = FarmScroll

    FarmScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        FarmScroll.CanvasSize = UDim2.new(0, 0, 0, FarmScrollLayout.AbsoluteContentSize.Y + 12)
    end)

    local FarmStatusCard = Instance.new("Frame")
    FarmStatusCard.Size = UDim2.new(1, -4, 0, 56)
    FarmStatusCard.LayoutOrder = 1
    FarmStatusCard.BackgroundColor3 = AppConfig.NestedCardBg
    FarmStatusCard.Parent = FarmScroll
    UI.applyCard(FarmStatusCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local FsTitle = Instance.new("TextLabel")
    FsTitle.Size = UDim2.new(1, -120, 0, 20)
    FsTitle.Position = UDim2.new(0, 14, 0, 8)
    FsTitle.BackgroundTransparency = 1
    FsTitle.Text = "⚡  Farm Engine Status"
    FsTitle.TextColor3 = AppConfig.TextPrimary
    FsTitle.TextSize = AppConfig.TextHeader
    FsTitle.Font = Enum.Font.GothamBold
    FsTitle.TextXAlignment = Enum.TextXAlignment.Left
    FsTitle.Parent = FarmStatusCard

    local FsSub = Instance.new("TextLabel")
    FsSub.Size = UDim2.new(1, -120, 0, 16)
    FsSub.Position = UDim2.new(0, 14, 0, 30)
    FsSub.BackgroundTransparency = 1
    FsSub.Text = "Master control & quick halt"
    FsSub.TextColor3 = AppConfig.TextMuted
    FsSub.TextSize = AppConfig.TextCaption
    FsSub.Font = Enum.Font.GothamMedium
    FsSub.TextXAlignment = Enum.TextXAlignment.Left
    FsSub.Parent = FarmStatusCard

    local StopFarmBtn = Instance.new("TextButton")
    StopFarmBtn.Size = UDim2.new(0, 96, 0, 30)
    StopFarmBtn.Position = UDim2.new(1, -110, 0.5, -15)
    StopFarmBtn.BackgroundColor3 = AppConfig.AccentRed
    StopFarmBtn.Text = "■ Stop All"
    StopFarmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    StopFarmBtn.TextSize = AppConfig.TextCaption
    StopFarmBtn.Font = Enum.Font.GothamBold
    StopFarmBtn.Parent = FarmStatusCard
    UI.styleButton(StopFarmBtn, AppConfig.RadiusMD, AppConfig.AccentRed)

    StopFarmBtn.MouseButton1Click:Connect(function()
        Farm.stopAutoFarm()
        Farm.stopAutoBestEgg()
        Rebirth.stopAutoRebirth()
        updateStatus("Engine Halted", AppConfig.AccentRed)
    end)

    UI.createToggle(FarmScroll, "Auto Selected Eggs Farm", "Farm only selected eggs", StateStore.autoFarmActive, function(enabled)
        if enabled then Farm.startAutoFarm(updateStatus, nil)
        else Farm.stopAutoFarm(); updateStatus("AutoFarm Stopped", AppConfig.TextSecondary) end
    end)

    UI.createToggle(FarmScroll, "Auto Best Egg Target", "Auto-find best egg", StateStore.autoBestEggActive, function(enabled)
        if enabled then Farm.startAutoBestEgg(updateStatus)
        else Farm.stopAutoBestEgg(); updateStatus("Best Egg Farm Stopped", AppConfig.TextSecondary) end
    end)

    UI.createToggle(FarmScroll, "Auto Rebirth & Collect", "Auto rebirth + collect", StateStore.autoRebirthActive, function(enabled)
        if enabled then Rebirth.startAutoRebirth(updateStatus, nil)
        else Rebirth.stopAutoRebirth(); updateStatus("Auto Rebirth Stopped", AppConfig.TextSecondary) end
    end)

    UI.createSlider(FarmScroll, "Movement Speed", 200, 1000, AppConfig.MovementSpeed, "studs/s", function(val)
        AppConfig.MovementSpeed = val
    end)

    UI.createSlider(FarmScroll, "Auto Collect Hold", 0.5, 5, AppConfig.AutoFarmHoldTime, "sec", function(val)
        AppConfig.AutoFarmHoldTime = val
        AppConfig.AutoEggHoldTime = val
    end)

    UI.createSlider(FarmScroll, "Egg Cooldown", 5, 30, AppConfig.EggCooldownSeconds, "sec", function(val)
        AppConfig.EggCooldownSeconds = val
    end)

    local MovementCard = Instance.new("Frame")
    MovementCard.Size = UDim2.new(1, -4, 0, 76)
    MovementCard.LayoutOrder = 5
    MovementCard.BackgroundColor3 = AppConfig.NestedCardBg
    MovementCard.Parent = FarmScroll
    UI.applyCard(MovementCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local MvTitle = Instance.new("TextLabel")
    MvTitle.Size = UDim2.new(1, -20, 0, 20)
    MvTitle.Position = UDim2.new(0, 14, 0, 8)
    MvTitle.BackgroundTransparency = 1
    MvTitle.Text = "Movement Mode"
    MvTitle.TextColor3 = AppConfig.TextPrimary
    MvTitle.TextSize = AppConfig.TextHeader
    MvTitle.Font = Enum.Font.GothamBold
    MvTitle.TextXAlignment = Enum.TextXAlignment.Left
    MvTitle.Parent = MovementCard

    local ModeAutoFarmBtn = Instance.new("TextButton")
    ModeAutoFarmBtn.Size = UDim2.new(0.5, -18, 0, 30)
    ModeAutoFarmBtn.Position = UDim2.new(0, 10, 0, 36)
    ModeAutoFarmBtn.BackgroundColor3 = AppConfig.AccentGreen
    ModeAutoFarmBtn.Text = "⚡ Glide + Noclip"
    ModeAutoFarmBtn.TextColor3 = Color3.fromRGB(10, 20, 15)
    ModeAutoFarmBtn.TextSize = AppConfig.TextCaption
    ModeAutoFarmBtn.Font = Enum.Font.GothamBold
    ModeAutoFarmBtn.Parent = MovementCard
    UI.styleButton(ModeAutoFarmBtn, AppConfig.RadiusMD, AppConfig.AccentGreen)

    local ModeTeleportBtn = Instance.new("TextButton")
    ModeTeleportBtn.Size = UDim2.new(0.5, -18, 0, 30)
    ModeTeleportBtn.Position = UDim2.new(0.5, 8, 0, 36)
    ModeTeleportBtn.BackgroundColor3 = AppConfig.RecessedBg
    ModeTeleportBtn.Text = "🌀 Instant TP"
    ModeTeleportBtn.TextColor3 = AppConfig.TextSecondary
    ModeTeleportBtn.TextSize = AppConfig.TextCaption
    ModeTeleportBtn.Font = Enum.Font.GothamBold
    ModeTeleportBtn.Parent = MovementCard
    UI.styleButton(ModeTeleportBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    local function updateMovementModeUI()
        if StateStore.movementMode == "AutoFarm" then
            UI.setButtonDefault(ModeAutoFarmBtn, AppConfig.AccentGreen)
            ModeAutoFarmBtn.TextColor3 = Color3.fromRGB(10, 20, 15)
            UI.setButtonDefault(ModeTeleportBtn, AppConfig.RecessedBg)
            ModeTeleportBtn.TextColor3 = AppConfig.TextSecondary
        else
            UI.setButtonDefault(ModeAutoFarmBtn, AppConfig.RecessedBg)
            ModeAutoFarmBtn.TextColor3 = AppConfig.TextSecondary
            UI.setButtonDefault(ModeTeleportBtn, AppConfig.AccentBlue)
            ModeTeleportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end

    ModeAutoFarmBtn.MouseButton1Click:Connect(function()
        Movement.stop()
        StateStore.movementMode = "AutoFarm"
        updateMovementModeUI()
        updateStatus("Movement: Glide + Noclip", AppConfig.AccentGreen)
    end)

    ModeTeleportBtn.MouseButton1Click:Connect(function()
        Movement.stop()
        StateStore.movementMode = "Teleport"
        updateMovementModeUI()
        updateStatus("Movement: Instant TP", AppConfig.AccentBlue)
    end)

    local UtilCard = Instance.new("Frame")
    UtilCard.Size = UDim2.new(1, -4, 0, 76)
    UtilCard.LayoutOrder = 6
    UtilCard.BackgroundColor3 = AppConfig.NestedCardBg
    UtilCard.Parent = FarmScroll
    UI.applyCard(UtilCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local UtTitle = Instance.new("TextLabel")
    UtTitle.Size = UDim2.new(1, -20, 0, 20)
    UtTitle.Position = UDim2.new(0, 14, 0, 8)
    UtTitle.BackgroundTransparency = 1
    UtTitle.Text = "Quick Teleport & Global ESP"
    UtTitle.TextColor3 = AppConfig.TextPrimary
    UtTitle.TextSize = AppConfig.TextHeader
    UtTitle.Font = Enum.Font.GothamBold
    UtTitle.TextXAlignment = Enum.TextXAlignment.Left
    UtTitle.Parent = UtilCard

    local GlobalESPToggleBtn = Instance.new("TextButton")
    GlobalESPToggleBtn.Size = UDim2.new(0.33, -10, 0, 30)
    GlobalESPToggleBtn.Position = UDim2.new(0, 10, 0, 36)
    GlobalESPToggleBtn.BackgroundColor3 = AppConfig.RecessedBg
    GlobalESPToggleBtn.Text = "👁️ ESP All: OFF"
    GlobalESPToggleBtn.TextColor3 = AppConfig.TextSecondary
    GlobalESPToggleBtn.TextSize = AppConfig.TextCaption
    GlobalESPToggleBtn.Font = Enum.Font.GothamBold
    GlobalESPToggleBtn.Parent = UtilCard
    UI.styleButton(GlobalESPToggleBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    local TPHomeBtn = Instance.new("TextButton")
    TPHomeBtn.Size = UDim2.new(0.33, -10, 0, 30)
    TPHomeBtn.Position = UDim2.new(0.33, 6, 0, 36)
    TPHomeBtn.BackgroundColor3 = AppConfig.RecessedBg
    TPHomeBtn.Text = "🏠 TP Home"
    TPHomeBtn.TextColor3 = AppConfig.TextPrimary
    TPHomeBtn.TextSize = AppConfig.TextCaption
    TPHomeBtn.Font = Enum.Font.GothamBold
    TPHomeBtn.Parent = UtilCard
    UI.styleButton(TPHomeBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    local AntiAFKToggleBtn = Instance.new("TextButton")
    AntiAFKToggleBtn.Size = UDim2.new(0.34, -10, 0, 30)
    AntiAFKToggleBtn.Position = UDim2.new(0.66, 6, 0, 36)
    AntiAFKToggleBtn.BackgroundColor3 = AppConfig.RecessedBg
    AntiAFKToggleBtn.Text = "🛡️ Anti-AFK: ON"
    AntiAFKToggleBtn.TextColor3 = AppConfig.AccentGreen
    AntiAFKToggleBtn.TextSize = AppConfig.TextCaption
    AntiAFKToggleBtn.Font = Enum.Font.GothamBold
    AntiAFKToggleBtn.Parent = UtilCard
    UI.styleButton(AntiAFKToggleBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    GlobalESPToggleBtn.MouseButton1Click:Connect(function()
        StateStore.mainESPActive = not StateStore.mainESPActive
        if StateStore.mainESPActive then
            GlobalESPToggleBtn.Text = "👁️ ESP All: ON"
            GlobalESPToggleBtn.TextColor3 = AppConfig.AccentGreen
            updateStatus("Global ESP: ON", AppConfig.AccentGreen)
        else
            GlobalESPToggleBtn.Text = "👁️ ESP All: OFF"
            GlobalESPToggleBtn.TextColor3 = AppConfig.TextSecondary
            updateStatus("Global ESP: OFF", AppConfig.TextSecondary)
        end
        ESP.updateAll()
    end)

    TPHomeBtn.MouseButton1Click:Connect(function()
        local ok = Plot.teleportAndDeposit()
        if ok then updateStatus("At Home Plot", AppConfig.AccentGreen)
        else updateStatus("Home Plot Not Found", AppConfig.AccentRed) end
    end)

    AntiAFKToggleBtn.MouseButton1Click:Connect(function()
        StateStore.antiAFKActive = not StateStore.antiAFKActive
        if NS.Stability then NS.Stability.setupAntiAFK(StateStore.antiAFKActive) end
        if StateStore.antiAFKActive then
            AntiAFKToggleBtn.Text = "🛡️ Anti-AFK: ON"
            AntiAFKToggleBtn.TextColor3 = AppConfig.AccentGreen
        else
            AntiAFKToggleBtn.Text = "🛡️ Anti-AFK: OFF"
            AntiAFKToggleBtn.TextColor3 = AppConfig.TextMuted
        end
    end)


    
    -- ══════════════════════════════════════════════════════════════
    -- [TAB 3] TIME
    -- ══════════════════════════════════════════════════════════════
    local TimePanel = tabPanels["Time"]

    local TimeScroll = Instance.new("ScrollingFrame")
    TimeScroll.Size = UDim2.new(1, 0, 1, 0)
    TimeScroll.BackgroundTransparency = 1
    TimeScroll.BorderSizePixel = 0
    TimeScroll.ScrollBarThickness = 3
    TimeScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    TimeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    TimeScroll.Parent = TimePanel

    local TimeScrollLayout = Instance.new("UIListLayout")
    TimeScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TimeScrollLayout.Padding = UDim.new(0, 8)
    TimeScrollLayout.Parent = TimeScroll

    TimeScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TimeScroll.CanvasSize = UDim2.new(0, 0, 0, TimeScrollLayout.AbsoluteContentSize.Y + 12)
    end)

    local BigClockCard = Instance.new("Frame")
    BigClockCard.Size = UDim2.new(1, -4, 0, 92)
    BigClockCard.LayoutOrder = 2
    BigClockCard.BackgroundColor3 = AppConfig.RecessedBg
    BigClockCard.Parent = TimeScroll
    UI.applyCard(BigClockCard, AppConfig.RadiusXL, AppConfig.RecessedBg, AppConfig.BorderInner)

    local BigClockLabel = Instance.new("TextLabel")
    BigClockLabel.Name = "BigClockLabel"
    BigClockLabel.Size = UDim2.new(1, -20, 0, 44)
    BigClockLabel.Position = UDim2.new(0, 10, 0, 12)
    BigClockLabel.BackgroundTransparency = 1
    BigClockLabel.Text = os.date("%H:%M:%S")
    BigClockLabel.TextColor3 = AppConfig.AccentBlue
    BigClockLabel.TextSize = 34
    BigClockLabel.Font = Enum.Font.GothamBold
    BigClockLabel.TextXAlignment = Enum.TextXAlignment.Center
    BigClockLabel.Parent = BigClockCard

    local BigDateLabel = Instance.new("TextLabel")
    BigDateLabel.Name = "BigDateLabel"
    BigDateLabel.Size = UDim2.new(1, -20, 0, 20)
    BigDateLabel.Position = UDim2.new(0, 10, 0, 60)
    BigDateLabel.BackgroundTransparency = 1
    BigDateLabel.Text = os.date("%A, %B %d, %Y")
    BigDateLabel.TextColor3 = AppConfig.TextSecondary
    BigDateLabel.TextSize = AppConfig.TextBody
    BigDateLabel.Font = Enum.Font.GothamMedium
    BigDateLabel.TextXAlignment = Enum.TextXAlignment.Center
    BigDateLabel.Parent = BigClockCard

    local SessionStatsCard = Instance.new("Frame")
    SessionStatsCard.Size = UDim2.new(1, -4, 0, 150)
    SessionStatsCard.LayoutOrder = 3
    SessionStatsCard.BackgroundColor3 = AppConfig.NestedCardBg
    SessionStatsCard.Parent = TimeScroll
    UI.applyCard(SessionStatsCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local SsTitle = Instance.new("TextLabel")
    SsTitle.Size = UDim2.new(1, -20, 0, 20)
    SsTitle.Position = UDim2.new(0, 14, 0, 8)
    SsTitle.BackgroundTransparency = 1
    SsTitle.Text = "📊  Session Statistics"
    SsTitle.TextColor3 = AppConfig.TextPrimary
    SsTitle.TextSize = AppConfig.TextHeader
    SsTitle.Font = Enum.Font.GothamBold
    SsTitle.TextXAlignment = Enum.TextXAlignment.Left
    SsTitle.Parent = SessionStatsCard

    local SsInner = Instance.new("Frame")
    SsInner.Size = UDim2.new(1, -20, 0, 106)
    SsInner.Position = UDim2.new(0, 10, 0, 34)
    SsInner.BackgroundColor3 = AppConfig.RecessedBg
    SsInner.Parent = SessionStatsCard
    UI.applyCard(SsInner, AppConfig.RadiusLG, AppConfig.RecessedBg, AppConfig.BorderInner)

    local function makeStatRow(parent, yPos, icon, title, valueColor)
        local rowFrame = Instance.new("Frame")
        rowFrame.Size = UDim2.new(1, 0, 0, 26)
        rowFrame.Position = UDim2.new(0, 0, 0, yPos)
        rowFrame.BackgroundTransparency = 1
        rowFrame.Parent = parent

        local iconLbl = Instance.new("TextLabel")
        iconLbl.Size = UDim2.new(0, 24, 1, 0)
        iconLbl.Position = UDim2.new(0, 10, 0, 0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text = icon
        iconLbl.TextSize = 12
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.Parent = rowFrame

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(0.5, 0, 1, 0)
        titleLbl.Position = UDim2.new(0, 34, 0, 0)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = title
        titleLbl.TextColor3 = AppConfig.TextSecondary
        titleLbl.TextSize = AppConfig.TextCaption
        titleLbl.Font = Enum.Font.GothamMedium
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = rowFrame

        local valueLbl = Instance.new("TextLabel")
        valueLbl.Size = UDim2.new(0.5, -10, 1, 0)
        valueLbl.Position = UDim2.new(0.5, 0, 0, 0)
        valueLbl.BackgroundTransparency = 1
        valueLbl.Text = "--"
        valueLbl.TextColor3 = valueColor or AppConfig.TextPrimary
        valueLbl.TextSize = AppConfig.TextBody
        valueLbl.Font = Enum.Font.GothamBold
        valueLbl.TextXAlignment = Enum.TextXAlignment.Right
        valueLbl.Parent = rowFrame

        return valueLbl
    end

    local TmCurrentTimeValue = makeStatRow(SsInner, 6,  "🕐", "Current Time",    AppConfig.AccentBlue)
    local TmSessionTimeValue = makeStatRow(SsInner, 32, "⏳", "Session Uptime",  AppConfig.AccentGreen)
    local TmStartTimeValue   = makeStatRow(SsInner, 58, "📅", "Session Started", AppConfig.TextSecondary)
    local TmEggsPerMinValue  = makeStatRow(SsInner, 84, "🥚", "Eggs / Minute",   AppConfig.AccentGold)

    TmStartTimeValue.Text = os.date("%H:%M:%S", StateStore.sessionStartTime)

    local TotalsCard = Instance.new("Frame")
    TotalsCard.Size = UDim2.new(1, -4, 0, 96)
    TotalsCard.LayoutOrder = 4
    TotalsCard.BackgroundColor3 = AppConfig.NestedCardBg
    TotalsCard.Parent = TimeScroll
    UI.applyCard(TotalsCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local TcTitle = Instance.new("TextLabel")
    TcTitle.Size = UDim2.new(1, -20, 0, 20)
    TcTitle.Position = UDim2.new(0, 14, 0, 8)
    TcTitle.BackgroundTransparency = 1
    TcTitle.Text = "🥚  Total Collected"
    TcTitle.TextColor3 = AppConfig.TextPrimary
    TcTitle.TextSize = AppConfig.TextHeader
    TcTitle.Font = Enum.Font.GothamBold
    TcTitle.TextXAlignment = Enum.TextXAlignment.Left
    TcTitle.Parent = TotalsCard

    local TotalCountLabel = Instance.new("TextLabel")
    TotalCountLabel.Name = "TotalCountLabel"
    TotalCountLabel.Size = UDim2.new(0.5, -20, 0, 46)
    TotalCountLabel.Position = UDim2.new(0, 10, 0, 36)
    TotalCountLabel.BackgroundTransparency = 1
    TotalCountLabel.Text = "0"
    TotalCountLabel.TextColor3 = AppConfig.AccentGold
    TotalCountLabel.TextSize = 34
    TotalCountLabel.Font = Enum.Font.GothamBold
    TotalCountLabel.TextXAlignment = Enum.TextXAlignment.Center
    TotalCountLabel.Parent = TotalsCard

    local TotalCaptionLabel = Instance.new("TextLabel")
    TotalCaptionLabel.Size = UDim2.new(0.5, -20, 0, 46)
    TotalCaptionLabel.Position = UDim2.new(0.5, 10, 0, 36)
    TotalCaptionLabel.BackgroundTransparency = 1
    TotalCaptionLabel.Text = "0 rare collected"
    TotalCaptionLabel.TextColor3 = AppConfig.TextSecondary
    TotalCaptionLabel.TextSize = AppConfig.TextBody
    TotalCaptionLabel.Font = Enum.Font.GothamMedium
    TotalCaptionLabel.TextXAlignment = Enum.TextXAlignment.Center
    TotalCaptionLabel.Parent = TotalsCard

    local function refreshTimeLabels()
        local now = os.time()
        local elapsed = now - StateStore.sessionStartTime
        local h = math.floor(elapsed / 3600)
        local m = math.floor((elapsed % 3600) / 60)
        local s = elapsed % 60

        TmCurrentTimeValue.Text = os.date("%H:%M:%S")
        TmSessionTimeValue.Text = string.format("%02d:%02d:%02d", h, m, s)

        local epm = (elapsed > 0) and string.format("%.1f", StateStore.totalEggsCollected / (elapsed / 60)) or "0.0"
        TmEggsPerMinValue.Text = epm .. " eggs/min"

        if BigClockLabel and BigClockLabel.Parent then
            BigClockLabel.Text = os.date("%H:%M:%S")
        end
        if BigDateLabel and BigDateLabel.Parent then
            BigDateLabel.Text = os.date("%A, %B %d, %Y")
        end
        if TotalCountLabel and TotalCountLabel.Parent then
            TotalCountLabel.Text = tostring(StateStore.totalEggsCollected)
        end
        if TotalCaptionLabel and TotalCaptionLabel.Parent then
            local rareCount = 0
            for _, rec in ipairs(StateStore.farmHistory) do
                if rec.isRare then rareCount = rareCount + 1 end
            end
            TotalCaptionLabel.Text = rareCount .. " rare collected"
        end
        if ClockLabel and ClockLabel.Parent then
            ClockLabel.Text = os.date("%H:%M:%S")
        end
    end
    StateStore.onTimeUpdated = refreshTimeLabels
    refreshTimeLabels()

    -- ══════════════════════════════════════════════════════════════
    -- [TAB 4] HISTORY
    -- ══════════════════════════════════════════════════════════════
    local HistoryPanel = tabPanels["History"]

    local HistToolbarCard = Instance.new("Frame")
    HistToolbarCard.Size = UDim2.new(1, 0, 0, 46)
    HistToolbarCard.BackgroundColor3 = AppConfig.NestedCardBg
    HistToolbarCard.Parent = HistoryPanel
    UI.applyCard(HistToolbarCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local HistTitle = Instance.new("TextLabel")
    HistTitle.Size = UDim2.new(1, -100, 1, 0)
    HistTitle.Position = UDim2.new(0, 14, 0, 0)
    HistTitle.BackgroundTransparency = 1
    HistTitle.Text = "📜  Collection Timeline"
    HistTitle.TextColor3 = AppConfig.AccentGold
    HistTitle.TextSize = AppConfig.TextHeader
    HistTitle.Font = Enum.Font.GothamBold
    HistTitle.TextXAlignment = Enum.TextXAlignment.Left
    HistTitle.Parent = HistToolbarCard

    local ClearHistoryBtn = Instance.new("TextButton")
    ClearHistoryBtn.Size = UDim2.new(0, 76, 0, 28)
    ClearHistoryBtn.Position = UDim2.new(1, -86, 0.5, -14)
    ClearHistoryBtn.BackgroundColor3 = AppConfig.RecessedBg
    ClearHistoryBtn.Text = "Clear All"
    ClearHistoryBtn.TextColor3 = AppConfig.AccentRed
    ClearHistoryBtn.TextSize = AppConfig.TextCaption
    ClearHistoryBtn.Font = Enum.Font.GothamBold
    ClearHistoryBtn.Parent = HistToolbarCard
    UI.styleButton(ClearHistoryBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    local HistListCard = Instance.new("Frame")
    HistListCard.Size = UDim2.new(1, 0, 1, -54)
    HistListCard.Position = UDim2.new(0, 0, 0, 54)
    HistListCard.BackgroundColor3 = AppConfig.NestedCardBg
    HistListCard.Parent = HistoryPanel
    UI.applyCard(HistListCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local HistoryScroll = Instance.new("ScrollingFrame")
    HistoryScroll.Size = UDim2.new(1, -16, 1, -16)
    HistoryScroll.Position = UDim2.new(0, 8, 0, 8)
    HistoryScroll.BackgroundTransparency = 1
    HistoryScroll.BorderSizePixel = 0
    HistoryScroll.ScrollBarThickness = 3
    HistoryScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    HistoryScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    HistoryScroll.Parent = HistListCard

    local HistoryLayout = Instance.new("UIListLayout")
    HistoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
    HistoryLayout.Padding = UDim.new(0, 4)
    HistoryLayout.Parent = HistoryScroll

    HistoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        HistoryScroll.CanvasSize = UDim2.new(0, 0, 0, HistoryLayout.AbsoluteContentSize.Y + 6)
    end)

    updateHistoryUI = function()
        for _, child in ipairs(HistoryScroll:GetChildren()) do
            if child ~= HistoryLayout then child:Destroy() end
        end

        if #StateStore.farmHistory == 0 then
            local emptyLabel = Instance.new("TextLabel")
            emptyLabel.Size = UDim2.new(1, 0, 0, 40)
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.Text = "No farm history yet"
            emptyLabel.TextColor3 = AppConfig.TextMuted
            emptyLabel.TextSize = AppConfig.TextBody
            emptyLabel.Font = Enum.Font.GothamMedium
            emptyLabel.Parent = HistoryScroll
            return
        end

        for _, item in ipairs(StateStore.farmHistory) do
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -4, 0, 34)
            card.BackgroundColor3 = item.isRare and Color3.fromRGB(36, 30, 20) or AppConfig.RecessedBg
            card.Parent = HistoryScroll
            UI.applyCard(card, AppConfig.RadiusMD, card.BackgroundColor3, item.isRare and AppConfig.AccentGold or AppConfig.BorderInner)

            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.new(0, 20, 0, 20)
            icon.Position = UDim2.new(0, 8, 0.5, -10)
            icon.BackgroundTransparency = 1
            icon.Image = Utils.getEggImage(item.name)
            icon.ScaleType = Enum.ScaleType.Fit
            icon.Parent = card

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -120, 1, 0)
            nameLabel.Position = UDim2.new(0, 34, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = item.name
            nameLabel.TextColor3 = item.isRare and AppConfig.AccentGold or AppConfig.TextPrimary
            nameLabel.TextSize = AppConfig.TextBody
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.Parent = card

            local timeLabel = Instance.new("TextLabel")
            timeLabel.Size = UDim2.new(0, 72, 1, 0)
            timeLabel.Position = UDim2.new(1, -80, 0, 0)
            timeLabel.BackgroundTransparency = 1
            timeLabel.Text = item.time
            timeLabel.TextColor3 = AppConfig.TextMuted
            timeLabel.TextSize = AppConfig.TextCaption
            timeLabel.Font = Enum.Font.Gotham
            timeLabel.TextXAlignment = Enum.TextXAlignment.Right
            timeLabel.Parent = card
        end
    end

    StateStore.onHistoryUpdated = updateHistoryUI

    ClearHistoryBtn.MouseButton1Click:Connect(function()
        table.clear(StateStore.farmHistory)
        updateHistoryUI()
        updateStatus("History cleared", AppConfig.AccentRed)
    end)

    -- ══════════════════════════════════════════════════════════════
    -- [TAB 5] SETTINGS
    -- ══════════════════════════════════════════════════════════════
    local SettingsPanel = tabPanels["Settings"]

    local SettingsScroll = Instance.new("ScrollingFrame")
    SettingsScroll.Size = UDim2.new(1, 0, 1, 0)
    SettingsScroll.BackgroundTransparency = 1
    SettingsScroll.BorderSizePixel = 0
    SettingsScroll.ScrollBarThickness = 3
    SettingsScroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    SettingsScroll.Parent = SettingsPanel

    local SettingsLayout = Instance.new("UIListLayout")
    SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SettingsLayout.Padding = UDim.new(0, 8)
    SettingsLayout.Parent = SettingsScroll

    SettingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 8)
    end)

    local DevSetCard = Instance.new("Frame")
    DevSetCard.Size = UDim2.new(1, -4, 0, 76)
    DevSetCard.LayoutOrder = 1
    DevSetCard.BackgroundColor3 = AppConfig.NestedCardBg
    DevSetCard.Parent = SettingsScroll
    UI.applyCard(DevSetCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local DstTitle = Instance.new("TextLabel")
    DstTitle.Size = UDim2.new(1, -20, 0, 20)
    DstTitle.Position = UDim2.new(0, 14, 0, 8)
    DstTitle.BackgroundTransparency = 1
    DstTitle.Text = "Display Mode"
    DstTitle.TextColor3 = AppConfig.TextPrimary
    DstTitle.TextSize = AppConfig.TextHeader
    DstTitle.Font = Enum.Font.GothamBold
    DstTitle.TextXAlignment = Enum.TextXAlignment.Left
    DstTitle.Parent = DevSetCard

    local SetPCBtn = Instance.new("TextButton")
    SetPCBtn.Size = UDim2.new(0.5, -18, 0, 30)
    SetPCBtn.Position = UDim2.new(0, 10, 0, 36)
    SetPCBtn.BackgroundColor3 = AppConfig.RecessedBg
    SetPCBtn.Text = "💻 PC Layout"
    SetPCBtn.TextColor3 = AppConfig.TextPrimary
    SetPCBtn.TextSize = AppConfig.TextCaption
    SetPCBtn.Font = Enum.Font.GothamBold
    SetPCBtn.Parent = DevSetCard
    UI.styleButton(SetPCBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    local SetMobileBtn = Instance.new("TextButton")
    SetMobileBtn.Size = UDim2.new(0.5, -18, 0, 30)
    SetMobileBtn.Position = UDim2.new(0.5, 8, 0, 36)
    SetMobileBtn.BackgroundColor3 = AppConfig.RecessedBg
    SetMobileBtn.Text = "📱 Mobile Layout"
    SetMobileBtn.TextColor3 = AppConfig.TextPrimary
    SetMobileBtn.TextSize = AppConfig.TextCaption
    SetMobileBtn.Font = Enum.Font.GothamBold
    SetMobileBtn.Parent = DevSetCard
    UI.styleButton(SetMobileBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    local KeybindCard = Instance.new("Frame")
    KeybindCard.Size = UDim2.new(1, -4, 0, 76)
    KeybindCard.LayoutOrder = 2
    KeybindCard.BackgroundColor3 = AppConfig.NestedCardBg
    KeybindCard.Parent = SettingsScroll
    UI.applyCard(KeybindCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local KbTitle = Instance.new("TextLabel")
    KbTitle.Size = UDim2.new(1, -20, 0, 20)
    KbTitle.Position = UDim2.new(0, 14, 0, 8)
    KbTitle.BackgroundTransparency = 1
    KbTitle.Text = "Teleport Home Keybind"
    KbTitle.TextColor3 = AppConfig.TextPrimary
    KbTitle.TextSize = AppConfig.TextHeader
    KbTitle.Font = Enum.Font.GothamBold
    KbTitle.TextXAlignment = Enum.TextXAlignment.Left
    KbTitle.Parent = KeybindCard

    local KeybindBtn = Instance.new("TextButton")
    KeybindBtn.Size = UDim2.new(1, -20, 0, 30)
    KeybindBtn.Position = UDim2.new(0, 10, 0, 36)
    KeybindBtn.BackgroundColor3 = AppConfig.RecessedBg
    KeybindBtn.Text = "⌨️  Keybind: [" .. StateStore.tpKeybind.Name .. "]"
    KeybindBtn.TextColor3 = AppConfig.AccentGold
    KeybindBtn.TextSize = AppConfig.TextCaption
    KeybindBtn.Font = Enum.Font.GothamBold
    KeybindBtn.Parent = KeybindCard
    UI.styleButton(KeybindBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    KeybindBtn.MouseButton1Click:Connect(function()
        StateStore.listeningForKey = true
        KeybindBtn.Text = "⌨️  Press any key..."
        KeybindBtn.TextColor3 = AppConfig.AccentGreen
    end)

    local PlotCard = Instance.new("Frame")
    PlotCard.Size = UDim2.new(1, -4, 0, 76)
    PlotCard.LayoutOrder = 3
    PlotCard.BackgroundColor3 = AppConfig.NestedCardBg
    PlotCard.Parent = SettingsScroll
    UI.applyCard(PlotCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    local PltTitle = Instance.new("TextLabel")
    PltTitle.Size = UDim2.new(1, -20, 0, 20)
    PltTitle.Position = UDim2.new(0, 14, 0, 8)
    PltTitle.BackgroundTransparency = 1
    PltTitle.Text = "Home Plot Diagnostic"
    PltTitle.TextColor3 = AppConfig.TextPrimary
    PltTitle.TextSize = AppConfig.TextHeader
    PltTitle.Font = Enum.Font.GothamBold
    PltTitle.TextXAlignment = Enum.TextXAlignment.Left
    PltTitle.Parent = PlotCard

    local CheckPlotBtn = Instance.new("TextButton")
    CheckPlotBtn.Size = UDim2.new(1, -20, 0, 30)
    CheckPlotBtn.Position = UDim2.new(0, 10, 0, 36)
    CheckPlotBtn.BackgroundColor3 = AppConfig.RecessedBg
    CheckPlotBtn.Text = "🔍 Check Home Plot"
    CheckPlotBtn.TextColor3 = AppConfig.TextPrimary
    CheckPlotBtn.TextSize = AppConfig.TextCaption
    CheckPlotBtn.Font = Enum.Font.GothamBold
    CheckPlotBtn.Parent = PlotCard
    UI.styleButton(CheckPlotBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    CheckPlotBtn.MouseButton1Click:Connect(function()
        local plot = Plot.findHomePlot()
        if plot then
            updateStatus("Plot: " .. plot.Name, AppConfig.AccentGreen)
            CheckPlotBtn.Text = "✅ " .. plot.Name
        else
            updateStatus("No Plot Detected", AppConfig.AccentRed)
            CheckPlotBtn.Text = "❌ No Home Plot"
        end
    end)



    

    -- ══════════════════════════════════════════════════════════════
    -- RARE EGG ALERTS
    -- ══════════════════════════════════════════════════════════════
    local function showRareAlert(egg)
        if not StateStore.shouldAlert(egg.Name) then return end

        local alerts = AlertStack:GetChildren()
        local count = 0
        for _, child in ipairs(alerts) do
            if child:IsA("Frame") then
                count += 1
                if count >= AppConfig.MaxAlerts then child:Destroy() end
            end
        end

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 70)
        card.BackgroundColor3 = AppConfig.OuterCardBg
        card.Position = UDim2.new(1, 60, 0, 0)
        card.Parent = AlertStack
        UI.applyCard(card, AppConfig.Radius2XL, AppConfig.OuterCardBg, AppConfig.AccentGold, 0.2)

        local innerCard = Instance.new("Frame")
        innerCard.Size = UDim2.new(1, -12, 1, -12)
        innerCard.Position = UDim2.new(0, 6, 0, 6)
        innerCard.BackgroundColor3 = AppConfig.NestedCardBg
        innerCard.Parent = card
        UI.applyCard(innerCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

        local eggIcon = Instance.new("ImageLabel")
        eggIcon.Size = UDim2.new(0, 40, 0, 40)
        eggIcon.Position = UDim2.new(0, 10, 0.5, -20)
        eggIcon.BackgroundTransparency = 1
        eggIcon.Image = Utils.getEggImage(egg.Name)
        eggIcon.ScaleType = Enum.ScaleType.Fit
        eggIcon.Parent = innerCard

        local badge = Instance.new("TextLabel")
        badge.Size = UDim2.new(1, -120, 0, 14)
        badge.Position = UDim2.new(0, 56, 0, 8)
        badge.BackgroundTransparency = 1
        badge.Text = "✨ RARE EGG!"
        badge.TextColor3 = AppConfig.AccentGold
        badge.TextSize = AppConfig.TextCaption
        badge.Font = Enum.Font.GothamBold
        badge.TextXAlignment = Enum.TextXAlignment.Left
        badge.Parent = innerCard

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -120, 0, 18)
        nameLabel.Position = UDim2.new(0, 56, 0, 22)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = egg.Name
        nameLabel.TextColor3 = AppConfig.TextPrimary
        nameLabel.TextSize = AppConfig.TextTitle
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = innerCard

        local distLabel = Instance.new("TextLabel")
        distLabel.Size = UDim2.new(1, -120, 0, 14)
        distLabel.Position = UDim2.new(0, 56, 0, 40)
        distLabel.BackgroundTransparency = 1
        local d = Utils.getDistanceToTarget(egg)
        distLabel.Text = (d ~= math.huge) and string.format("📍 %dst", math.floor(d + 0.5)) or "📍 ?"
        distLabel.TextColor3 = AppConfig.TextSecondary
        distLabel.TextSize = AppConfig.TextCaption
        distLabel.Font = Enum.Font.GothamMedium
        distLabel.TextXAlignment = Enum.TextXAlignment.Left
        distLabel.Parent = innerCard

        local tpBtn = Instance.new("TextButton")
        tpBtn.Size = UDim2.new(0, 56, 0, 28)
        tpBtn.Position = UDim2.new(1, -62, 0.5, -14)
        tpBtn.BackgroundColor3 = AppConfig.AccentGold
        tpBtn.Text = "⚡ TP"
        tpBtn.TextColor3 = Color3.fromRGB(15, 15, 20)
        tpBtn.TextSize = AppConfig.TextBody
        tpBtn.Font = Enum.Font.GothamBold
        tpBtn.Parent = innerCard
        UI.styleButton(tpBtn, AppConfig.RadiusMD, AppConfig.AccentGold)

        tpBtn.MouseButton1Click:Connect(function()
            if egg and egg.Parent then
                Movement.teleportTo(egg)
                updateStatus("TP to " .. egg.Name, AppConfig.AccentGold)
            end
            pcall(function() card:Destroy() end)
        end)

        Utils.tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.25, Enum.EasingStyle.Back)

        task.delay(AppConfig.AlertDuration, function()
            if card and card.Parent then
                Utils.tween(card, { BackgroundTransparency = 1 }, 0.3)
                task.wait(0.32)
                pcall(function() card:Destroy() end)
            end
        end)
    end

         -- ══════════════════════════════════════════════════════════════
    -- WEBHOOK SETTINGS (FIXED — กดได้แน่นอน)
    -- ══════════════════════════════════════════════════════════════
    local WebhookCard = Instance.new("Frame")
    WebhookCard.Name = "WebhookCard"
    WebhookCard.Size = UDim2.new(1, -4, 0, 220)
    WebhookCard.LayoutOrder = 4
    WebhookCard.BackgroundColor3 = AppConfig.NestedCardBg
    WebhookCard.Active = true
    WebhookCard.ClipsDescendants = false
    WebhookCard.Parent = SettingsScroll
    UI.applyCard(WebhookCard, AppConfig.RadiusXL, AppConfig.NestedCardBg, AppConfig.BorderInner)

    -- Title
    local WbTitle = Instance.new("TextLabel")
    WbTitle.Size = UDim2.new(1, -20, 0, 20)
    WbTitle.Position = UDim2.new(0, 14, 0, 8)
    WbTitle.BackgroundTransparency = 1
    WbTitle.Text = "📨  Discord Webhook"
    WbTitle.TextColor3 = AppConfig.AccentBlue
    WbTitle.TextSize = AppConfig.TextHeader
    WbTitle.Font = Enum.Font.GothamBold
    WbTitle.TextXAlignment = Enum.TextXAlignment.Left
    WbTitle.Parent = WebhookCard

    -- URL TextBox
    local WbUrlBox = Instance.new("TextBox")
    WbUrlBox.Name = "WbUrlBox"
    WbUrlBox.Size = UDim2.new(1, -20, 0, 32)
    WbUrlBox.Position = UDim2.new(0, 10, 0, 34)
    WbUrlBox.BackgroundColor3 = AppConfig.RecessedBg
    WbUrlBox.PlaceholderText = "Paste webhook URL..."
    WbUrlBox.PlaceholderColor3 = AppConfig.TextMuted
    WbUrlBox.Text = (NS.Webhook and NS.Webhook.Config.Url) or ""
    WbUrlBox.TextColor3 = AppConfig.TextPrimary
    WbUrlBox.TextSize = AppConfig.TextCaption
    WbUrlBox.Font = Enum.Font.GothamMedium
    WbUrlBox.TextXAlignment = Enum.TextXAlignment.Left
    WbUrlBox.ClearTextOnFocus = false
    WbUrlBox.ZIndex = 5
    WbUrlBox.Parent = WebhookCard
    UI.styleInput(WbUrlBox, AppConfig.RadiusMD)

    local function saveWebhookUrl()
        if NS.Webhook then
            local text = (WbUrlBox.Text or ""):match("^%s*(.-)%s*$") or ""
            NS.Webhook.Config.Url = text
            print("[Webhook] URL saved:", text)
            updateStatus("Webhook URL saved", AppConfig.AccentBlue)
        end
    end
    WbUrlBox.FocusLost:Connect(saveWebhookUrl)
    WbUrlBox.ReturnPressedFromOnScreenKeyboard:Connect(saveWebhookUrl)

    -- ══════════════════════════════════════════════════════════════
    -- ปุ่มทั้ง 3 — ใช้ Handler เดียว + ผูก 3 event (ชัวร์ 100%)
    -- ══════════════════════════════════════════════════════════════

    -- ─── ปุ่ม Enable ───
    local WbEnableBtn = Instance.new("TextButton")
    WbEnableBtn.Name = "WbEnableBtn"
    WbEnableBtn.Size = UDim2.new(0.33, -10, 0, 32)
    WbEnableBtn.Position = UDim2.new(0, 10, 0, 74)
    WbEnableBtn.BackgroundColor3 = (NS.Webhook and NS.Webhook.Config.Enabled) and AppConfig.AccentGreen or AppConfig.RecessedBg
    WbEnableBtn.Text = (NS.Webhook and NS.Webhook.Config.Enabled) and "🔔 ON" or "🔕 OFF"
    WbEnableBtn.TextColor3 = (NS.Webhook and NS.Webhook.Config.Enabled) and Color3.fromRGB(10, 20, 15) or AppConfig.TextMuted
    WbEnableBtn.TextSize = AppConfig.TextCaption
    WbEnableBtn.Font = Enum.Font.GothamBold
    WbEnableBtn.AutoButtonColor = true
    WbEnableBtn.ZIndex = 10
    WbEnableBtn.Active = true
    WbEnableBtn.Selectable = true
    WbEnableBtn.Parent = WebhookCard
    UI.styleButton(WbEnableBtn, AppConfig.RadiusMD, WbEnableBtn.BackgroundColor3)

    local function onEnableClick()
        print("[Webhook] Enable clicked")
        if not NS.Webhook then 
            warn("[Webhook] NS.Webhook is nil!")
            return 
        end
        local currentText = (WbUrlBox.Text or ""):match("^%s*(.-)%s*$") or ""
        if currentText ~= "" then
            NS.Webhook.Config.Url = currentText
        end
        NS.Webhook.Config.Enabled = not NS.Webhook.Config.Enabled
        print("[Webhook] Enabled:", NS.Webhook.Config.Enabled)
        if NS.Webhook.Config.Enabled then
            UI.setButtonDefault(WbEnableBtn, AppConfig.AccentGreen)
            WbEnableBtn.Text = "🔔 ON"
            WbEnableBtn.TextColor3 = Color3.fromRGB(10, 20, 15)
            updateStatus("Webhook: ON", AppConfig.AccentGreen)
        else
            UI.setButtonDefault(WbEnableBtn, AppConfig.RecessedBg)
            WbEnableBtn.Text = "🔕 OFF"
            WbEnableBtn.TextColor3 = AppConfig.TextMuted
            updateStatus("Webhook: OFF", AppConfig.TextSecondary)
        end
    end
    WbEnableBtn.MouseButton1Click:Connect(onEnableClick)
    WbEnableBtn.Activated:Connect(onEnableClick)

    -- ─── ปุ่ม Test ───
    local WbTestBtn = Instance.new("TextButton")
    WbTestBtn.Name = "WbTestBtn"
    WbTestBtn.Size = UDim2.new(0.33, -10, 0, 32)
    WbTestBtn.Position = UDim2.new(0.33, 0, 0, 74)
    WbTestBtn.BackgroundColor3 = AppConfig.RecessedBg
    WbTestBtn.Text = "🧪 Test"
    WbTestBtn.TextColor3 = AppConfig.AccentBlue
    WbTestBtn.TextSize = AppConfig.TextCaption
    WbTestBtn.Font = Enum.Font.GothamBold
    WbTestBtn.AutoButtonColor = true
    WbTestBtn.ZIndex = 10
    WbTestBtn.Active = true
    WbTestBtn.Selectable = true
    WbTestBtn.Parent = WebhookCard
    UI.styleButton(WbTestBtn, AppConfig.RadiusMD, AppConfig.RecessedBg)

    local function onTestClick()
        print("[Webhook] Test clicked")
        if not NS.Webhook then 
            warn("[Webhook] NS.Webhook is nil!")
            return 
        end
        local currentText = (WbUrlBox.Text or ""):match("^%s*(.-)%s*$") or ""
        if currentText ~= "" then
            NS.Webhook.Config.Url = currentText
        end
        print("[Webhook] URL:", NS.Webhook.Config.Url)
        
        if not NS.Webhook.Config.Url or NS.Webhook.Config.Url == "" then
            updateStatus("Enter URL first", AppConfig.AccentRed)
            return
        end
        
        -- บังคับเปิดก่อน test
        NS.Webhook.Config.Enabled = true
        UI.setButtonDefault(WbEnableBtn, AppConfig.AccentGreen)
        WbEnableBtn.Text = "🔔 ON"
        WbEnableBtn.TextColor3 = Color3.fromRGB(10, 20, 15)
        
        WbTestBtn.Text = "⏳ Sending..."
        local ok, res, detail = pcall(function()
            return NS.Webhook.Test()
        end)
        task.wait(0.5)
        WbTestBtn.Text = "🧪 Test"
        print("[Webhook] Test result:", ok, res, detail)
        
        if ok and res == true then
            updateStatus("Test sent! Check Discord", AppConfig.AccentGreen)
        else
            local errStr = not ok and tostring(res) or tostring(detail or res or "Failed")
            updateStatus("Failed: " .. errStr:sub(1, 24), AppConfig.AccentRed)
        end
    end
    WbTestBtn.MouseButton1Click:Connect(onTestClick)
    WbTestBtn.Activated:Connect(onTestClick)

    -- ─── ปุ่ม Rare Only ───
    local WbRareOnlyBtn = Instance.new("TextButton")
    WbRareOnlyBtn.Name = "WbRareOnlyBtn"
    WbRareOnlyBtn.Size = UDim2.new(0.33, -10, 0, 32)
    WbRareOnlyBtn.Position = UDim2.new(0.66, 0, 0, 74)
    WbRareOnlyBtn.BackgroundColor3 = (NS.Webhook and NS.Webhook.Config.NotifyRareOnly) and AppConfig.AccentGold or AppConfig.RecessedBg
    WbRareOnlyBtn.Text = (NS.Webhook and NS.Webhook.Config.NotifyRareOnly) and "🌟 Rare Only" or "🌟 Rare: OFF"
    WbRareOnlyBtn.TextColor3 = (NS.Webhook and NS.Webhook.Config.NotifyRareOnly) and Color3.fromRGB(15, 15, 20) or AppConfig.TextMuted
    WbRareOnlyBtn.TextSize = AppConfig.TextCaption
    WbRareOnlyBtn.Font = Enum.Font.GothamBold
    WbRareOnlyBtn.AutoButtonColor = true
    WbRareOnlyBtn.ZIndex = 10
    WbRareOnlyBtn.Active = true
    WbRareOnlyBtn.Selectable = true
    WbRareOnlyBtn.Parent = WebhookCard
    UI.styleButton(WbRareOnlyBtn, AppConfig.RadiusMD, WbRareOnlyBtn.BackgroundColor3)

    local function onRareClick()
        print("[Webhook] Rare Only clicked")
        if not NS.Webhook then return end
        NS.Webhook.Config.NotifyRareOnly = not NS.Webhook.Config.NotifyRareOnly
        print("[Webhook] RareOnly:", NS.Webhook.Config.NotifyRareOnly)
        if NS.Webhook.Config.NotifyRareOnly then
            UI.setButtonDefault(WbRareOnlyBtn, AppConfig.AccentGold)
            WbRareOnlyBtn.Text = "🌟 Rare Only"
            WbRareOnlyBtn.TextColor3 = Color3.fromRGB(15, 15, 20)
        else
            UI.setButtonDefault(WbRareOnlyBtn, AppConfig.RecessedBg)
            WbRareOnlyBtn.Text = "🌟 Rare: OFF"
            WbRareOnlyBtn.TextColor3 = AppConfig.TextMuted
        end
    end
    WbRareOnlyBtn.MouseButton1Click:Connect(onRareClick)
    WbRareOnlyBtn.Activated:Connect(onRareClick)

    -- ══════════════════════════════════════════════════════════════
    -- Info + Stats
    -- ══════════════════════════════════════════════════════════════
    local WbInfoLabel = Instance.new("TextLabel")
    WbInfoLabel.Size = UDim2.new(1, -20, 0, 34)
    WbInfoLabel.Position = UDim2.new(0, 14, 0, 116)
    WbInfoLabel.BackgroundTransparency = 1
    WbInfoLabel.Text = "📌 Notify only when eggs are collected (after home deposit)"
    WbInfoLabel.TextColor3 = AppConfig.TextSecondary
    WbInfoLabel.TextSize = AppConfig.TextCaption
    WbInfoLabel.Font = Enum.Font.GothamMedium
    WbInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    WbInfoLabel.TextWrapped = true
    WbInfoLabel.Parent = WebhookCard

    local WbStatsLabel = Instance.new("TextLabel")
    WbStatsLabel.Name = "WbStatsLabel"
    WbStatsLabel.Size = UDim2.new(1, -20, 0, 18)
    WbStatsLabel.Position = UDim2.new(0, 14, 0, 158)
    WbStatsLabel.BackgroundTransparency = 1
    WbStatsLabel.Text = "📊 Sent: 0 | Errors: 0"
    WbStatsLabel.TextColor3 = AppConfig.TextMuted
    WbStatsLabel.TextSize = AppConfig.TextMicro
    WbStatsLabel.Font = Enum.Font.Gotham
    WbStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
    WbStatsLabel.Parent = WebhookCard

    task.spawn(function()
        while WebhookCard and WebhookCard.Parent do
            if NS.Webhook then
                local stats = NS.Webhook.GetStats()
                WbStatsLabel.Text = string.format("📊 Sent: %d | Errors: %d", stats.sent, stats.errors)
            end
            task.wait(2)
        end
    end)

    -- ══════════════════════════════════════════════════════════════
    -- DRAGGABLE
    -- ══════════════════════════════════════════════════════════════
    local dragging = false
    local dragStart = nil
    local startPos = nil

    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)

    StateStore.track(S.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    StateStore.track(S.UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local cam = S.Workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
            local fw = MainFrame.AbsoluteSize.X
            local fh = MainFrame.AbsoluteSize.Y
            local tx = math.clamp(startPos.X.Offset + delta.X, 0, math.max(0, vp.X - fw))
            local ty = math.clamp(startPos.Y.Offset + delta.Y, 0, math.max(0, vp.Y - fh))
            MainFrame.Position = UDim2.new(0, tx, 0, ty)
        end
    end))

    StateStore.track(S.UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if StateStore.listeningForKey then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                StateStore.tpKeybind = input.KeyCode
                StateStore.listeningForKey = false
                KeybindBtn.Text = "⌨️  Keybind: [" .. StateStore.tpKeybind.Name .. "]"
                KeybindBtn.TextColor3 = AppConfig.AccentGold
                updateStatus("Keybind: " .. StateStore.tpKeybind.Name, AppConfig.AccentGreen)
            end
            return
        end
        if gameProcessed then return end

        if input.KeyCode == Enum.KeyCode.Escape then
            if not StateStore.isMinimized then toggleMinimize() end
            return
        end

        if input.KeyCode == Enum.KeyCode.Period then
            local ids = {}
            for _, t in ipairs(Tabs) do table.insert(ids, t.id) end
            local idx = table.find(ids, currentActiveTab) or 1
            switchTab(ids[(idx % #ids) + 1])
            return
        end
        if input.KeyCode == Enum.KeyCode.Comma then
            local ids = {}
            for _, t in ipairs(Tabs) do table.insert(ids, t.id) end
            local idx = table.find(ids, currentActiveTab) or 1
            switchTab(ids[((idx - 2) % #ids) + 1])
            return
        end

        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == StateStore.tpKeybind then
            Plot.teleportAndDeposit()
        end
    end))

    local function applyMode(mode)
        StateStore.windowMode = mode
        StateStore.isMobileMode = (mode == "Mobile")
        local w, h = currentSize()
        MainFrame.Size = UDim2.new(0, w, 0, h)
        MainFrame.Position = UDim2.new(0.5, -w / 2, 0.5, -h / 2)
        MainFrame.Visible = true
        Sidebar.Visible = not StateStore.isMinimized
        ContentArea.Visible = not StateStore.isMinimized
        updateMovementModeUI()
        populateList()
        updateLiveEggsSummary()
    end

    SetPCBtn.MouseButton1Click:Connect(function() applyMode("PC") end)
    SetMobileBtn.MouseButton1Click:Connect(function() applyMode("Mobile") end)
    FootPC.MouseButton1Click:Connect(function() applyMode("PC") end)
    FootMobile.MouseButton1Click:Connect(function() applyMode("Mobile") end)

    local initialMode = (S.UserInputService.TouchEnabled and not S.UserInputService.KeyboardEnabled) and "Mobile" or "PC"
    applyMode(initialMode)

    local timeTick = 0
    StateStore.track(S.RunService.Heartbeat:Connect(function(dt)
        if not (ScreenGui and ScreenGui.Parent) then return end
        timeTick = timeTick + dt
        if timeTick >= 1 then
            timeTick = timeTick - 1
            if ClockLabel and ClockLabel.Parent then
                ClockLabel.Text = os.date("%H:%M:%S")
            end
            if StateStore.onTimeUpdated then
                StateStore.onTimeUpdated()
            end
        end
    end))

    task.defer(function()
        populateList()
        updateLiveEggsSummary()
        updateHistoryUI()
    end)

    return {
        populateList = populateList,
        updateLiveEggsSummary = updateLiveEggsSummary,
        showRareAlert = showRareAlert,
        ScreenGui = ScreenGui,
    }
end

NS.UI = UI
