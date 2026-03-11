-- ╔══════════════════════════════════════════════════════╗
-- ║      Auto Lasso v7 × Avantrix GUI                   ║
-- ║  GUI: Avantrix style (dark green, tabs, sidebar)     ║
-- ║  Logic: Auto Lasso, Fruit, Food, Find Pets, TP Rarity║
-- ║  FIX: Boss detection player count + minigame check   ║
-- ╚══════════════════════════════════════════════════════╝

if not game:IsLoaded() then game.Loaded:Wait() end

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local CoreGui           = game:GetService("CoreGui")
local VirtualUser       = game:GetService("VirtualUser")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local isMobile  = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- ═══ Anti AFK ═══
player.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end)

-- ═══ Cleanup old instances ═══
local env = getgenv() or _G
for _, key in ipairs({"AutoLassoAvantrix_v7"}) do
    if env and env[key] then
        local old = CoreGui:FindFirstChild(env[key])
        if old then old:Destroy() end
        local old2 = playerGui:FindFirstChild(env[key])
        if old2 then old2:Destroy() end
    end
end

-- ═══════════════════════════════════════════
-- SETTINGS / STATE
-- ═══════════════════════════════════════════
local autoCompleteEnabled     = false
local autoCollectFruitEnabled = false
local autoBuyFoodEnabled      = false
local isProcessing            = false
local isCollecting            = false
local isBossActive            = false
local isWaiting               = false

local SAFE_ZONE_TARGET  = 28
local COMPLETION_TARGET = 100

-- ═══════════════════════════════════════════
-- REMOTES
-- ═══════════════════════════════════════════
local Remotes              = ReplicatedStorage:WaitForChild("Remotes")
local updateProgressRemote = Remotes:WaitForChild("UpdateProgress")

local FoodConfig = nil
task.spawn(function()
    local configs = ReplicatedStorage:WaitForChild("Configs", 10)
    if configs then
        local foodModule = configs:WaitForChild("Food", 10)
        if foodModule then FoodConfig = require(foodModule) end
    end
end)

local PetsConfig = nil
task.spawn(function()
    local ok, cfg = pcall(function() return require(ReplicatedStorage.Configs.Pets) end)
    if ok and cfg then PetsConfig = cfg end
end)

-- ═══════════════════════════════════════════
-- RARITY DATA
-- ═══════════════════════════════════════════
local RARITY_LIST = { "Boss", "Secret", "Exclusive", "Mythical", "Legendary", "Epic", "Rare", "Common" }
local RARITY_COLORS = {
    Boss      = Color3.fromRGB(255, 50,  50),
    Secret    = Color3.fromRGB(255, 0,   200),
    Exclusive = Color3.fromRGB(255, 120, 0),
    Mythical  = Color3.fromRGB(180, 0,   255),
    Legendary = Color3.fromRGB(255, 200, 0),
    Epic      = Color3.fromRGB(130, 60,  255),
    Rare      = Color3.fromRGB(50,  130, 255),
    Common    = Color3.fromRGB(150, 150, 150),
}
local selectedRarities = {}
local dropdownOpen = false

-- ═══════════════════════════════════════════
-- FRUIT DATA
-- ═══════════════════════════════════════════
local FRUIT_NAMES = { "CosmicFruit", "BloodmoonGrape", "VolcanicFruit" }
local FRUIT_SET = {}
for _, n in ipairs(FRUIT_NAMES) do FRUIT_SET[n] = true end
local fruitCollectedCount = 0
local detectedFruits = {}
local realtimeConns = {}

-- ═══════════════════════════════════════════
-- FOOD DATA
-- ═══════════════════════════════════════════
local foodBoughtCount = 0
local _foodStock      = {}
local _foodAllEmpty   = true

-- ═══════════════════════════════════════════
-- GUI LABELS (forward declare)
-- ═══════════════════════════════════════════
local statusLabel, progressLabel, phaseLabel
local fruitStatusLabel, fruitDetectLabel, foodStatusLabel
local teleportRarityStatus

-- ═══════════════════════════════════════════
-- NOTIFICATION
-- ═══════════════════════════════════════════
local function Notify(title, msg, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title=title, Text=msg, Duration=dur or 3})
    end)
end

-- ═══════════════════════════════════════════
-- GUI BUILD — Avantrix Style
-- ═══════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoLassoAvantrix_v7_"..math.random(100000,999999)
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui or playerGui
env.AutoLassoAvantrix_v7 = ScreenGui.Name

local MW = isMobile and 340 or 560
local MH = isMobile and 420 or 460

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, MW, 0, MH)
MainFrame.Position = UDim2.new(0.5, -MW/2, 0.5, -MH/2)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
MainFrame.BorderSizePixel = 0
MainFrame.BackgroundTransparency = 1
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(0, 180, 100)
MainStroke.Thickness = 2
MainStroke.Transparency = 1
MainStroke.Parent = MainFrame

local GlowFrame = Instance.new("ImageLabel")
GlowFrame.Size = UDim2.new(1, 50, 1, 50)
GlowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
GlowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
GlowFrame.BackgroundTransparency = 1
GlowFrame.Image = "rbxassetid://5028857084"
GlowFrame.ImageColor3 = Color3.fromRGB(0, 139, 70)
GlowFrame.ImageTransparency = 1
GlowFrame.ScaleType = Enum.ScaleType.Slice
GlowFrame.SliceCenter = Rect.new(24, 24, 276, 276)
GlowFrame.Parent = MainFrame

-- Header
local HH = isMobile and 42 or 50
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, HH)
Header.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 14)

local hFix = Instance.new("Frame")
hFix.Size = UDim2.new(1, 0, 0, 16)
hFix.Position = UDim2.new(0, 0, 1, -16)
hFix.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
hFix.BorderSizePixel = 0
hFix.Parent = Header

local hG = Instance.new("UIGradient")
hG.Rotation = 45
hG.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 180, 90)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 140, 70)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 80, 40))
}
hG.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.65, 0, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "⚡ AUTO LASSO v7 × AVANTRIX"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = isMobile and 9 or 12
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local function MakeHeaderBtn(xOff, txt, bg)
    local b = Instance.new("TextButton")
    local sz = isMobile and 26 or 30
    b.Size = UDim2.new(0, sz, 0, sz)
    b.Position = UDim2.new(1, xOff, 0.5, -(sz/2))
    b.BackgroundColor3 = bg
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = isMobile and 12 or 14
    b.Parent = Header
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local CloseBtn    = MakeHeaderBtn(isMobile and -32 or -38, "✕", Color3.fromRGB(200, 50, 50))
local MinimizeBtn = MakeHeaderBtn(isMobile and -62 or -72, "—", Color3.fromRGB(70, 70, 70))

-- Tab Bar
local TBH = isMobile and 32 or 38
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, TBH)
TabBar.Position = UDim2.new(0, 0, 0, HH)
TabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame

local TAB_NAMES = {"LASSO", "PETS", "FRUIT", "FOOD"}
local TAB_ICONS = {"⚡", "🔍", "🍎", "🍖"}
local TabButtons = {}
for i, tn in ipairs(TAB_NAMES) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1/#TAB_NAMES, -4, 1, -6)
    btn.Position = UDim2.new((i-1)/#TAB_NAMES, 2, 0, 3)
    btn.BackgroundColor3 = (i==1) and Color3.fromRGB(0, 120, 60) or Color3.fromRGB(35, 35, 35)
    btn.Text = TAB_ICONS[i].." "..tn
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = isMobile and 8 or 10
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    TabButtons[tn] = btn
end

local TOP = HH + TBH

-- Content Area (left)
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(0.58, -10, 1, -TOP-8)
ContentArea.Position = UDim2.new(0, 6, 0, TOP+4)
ContentArea.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ContentArea.BorderSizePixel = 0
ContentArea.Parent = MainFrame
Instance.new("UICorner", ContentArea).CornerRadius = UDim.new(0, 10)

-- Sidebar (right)
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0.42, -10, 1, -TOP-8)
Sidebar.Position = UDim2.new(0.58, 4, 0, TOP+4)
Sidebar.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 10)
local sS = Instance.new("UIStroke")
sS.Color = Color3.fromRGB(60, 60, 60)
sS.Thickness = 1
sS.Parent = Sidebar

-- Sidebar: Status Box
local StatusBox = Instance.new("Frame")
StatusBox.Size = UDim2.new(1, -10, 0, isMobile and 76 or 90)
StatusBox.Position = UDim2.new(0, 5, 0, 5)
StatusBox.BackgroundColor3 = Color3.fromRGB(0, 120, 60)
StatusBox.BorderSizePixel = 0
StatusBox.Parent = Sidebar
Instance.new("UICorner", StatusBox).CornerRadius = UDim.new(0, 8)
local sbG = Instance.new("UIGradient")
sbG.Rotation = 90
sbG.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 160, 80)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 100, 50))
}
sbG.Parent = StatusBox

local StatusTitle = Instance.new("TextLabel")
StatusTitle.Size = UDim2.new(1, -6, 0, isMobile and 16 or 20)
StatusTitle.Position = UDim2.new(0, 4, 0, 4)
StatusTitle.BackgroundTransparency = 1
StatusTitle.Text = "⚡ AUTO LASSO"
StatusTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
StatusTitle.Font = Enum.Font.GothamBlack
StatusTitle.TextSize = isMobile and 10 or 13
StatusTitle.TextXAlignment = Enum.TextXAlignment.Left
StatusTitle.Parent = StatusBox

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -6, 0, isMobile and 14 or 17)
statusLabel.Position = UDim2.new(0, 4, 0, isMobile and 22 or 26)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "🔴 Disabled"
statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = isMobile and 8 or 10
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = StatusBox

progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.new(1, -6, 0, isMobile and 13 or 16)
progressLabel.Position = UDim2.new(0, 4, 0, isMobile and 38 or 46)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Waiting for minigame..."
progressLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
progressLabel.Font = Enum.Font.Gotham
progressLabel.TextSize = isMobile and 7 or 9
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.Parent = StatusBox

phaseLabel = Instance.new("TextLabel")
phaseLabel.Size = UDim2.new(1, -6, 0, isMobile and 12 or 15)
phaseLabel.Position = UDim2.new(0, 4, 0, isMobile and 53 or 64)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Text = ""
phaseLabel.TextColor3 = Color3.fromRGB(100, 255, 200)
phaseLabel.Font = Enum.Font.GothamMedium
phaseLabel.TextSize = isMobile and 7 or 9
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
phaseLabel.Parent = StatusBox

-- Sidebar: Feature Status Badges
local function MakeBadge(yPos, text, bg, fg)
    local b = Instance.new("TextLabel")
    b.Size = UDim2.new(1, -10, 0, isMobile and 15 or 18)
    b.Position = UDim2.new(0, 5, 0, yPos)
    b.BackgroundColor3 = bg
    b.Text = text
    b.TextColor3 = fg
    b.Font = Enum.Font.GothamBold
    b.TextSize = isMobile and 7 or 9
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = Sidebar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    return b
end

local yOff = (isMobile and 76 or 90) + 10
fruitStatusLabel  = MakeBadge(yOff,       "🍎 Fruit: 0 collected",      Color3.fromRGB(35, 25, 10), Color3.fromRGB(255, 200, 100))
fruitDetectLabel  = MakeBadge(yOff+22,    "🔴 No fruit detected",        Color3.fromRGB(35, 15, 15), Color3.fromRGB(255, 120, 120))
foodStatusLabel   = MakeBadge(yOff+44,    "🍖 Food: menunggu stock...",  Color3.fromRGB(30, 15, 35), Color3.fromRGB(200, 130, 255))

-- Sidebar: Keybind info
local KeyInfo = Instance.new("TextLabel")
KeyInfo.Size = UDim2.new(1, -10, 0, isMobile and 36 or 44)
KeyInfo.Position = UDim2.new(0, 5, 0, yOff + 70)
KeyInfo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
KeyInfo.Text = "F1 = Auto Lasso\nF2 = Auto Fruit\nF3 = Auto Food"
KeyInfo.TextColor3 = Color3.fromRGB(150, 150, 150)
KeyInfo.Font = Enum.Font.Gotham
KeyInfo.TextSize = isMobile and 8 or 9
KeyInfo.TextXAlignment = Enum.TextXAlignment.Left
KeyInfo.Parent = Sidebar
local kip = Instance.new("UIPadding")
kip.PaddingLeft = UDim.new(0, 5)
kip.PaddingTop = UDim.new(0, 4)
kip.Parent = KeyInfo
Instance.new("UICorner", KeyInfo).CornerRadius = UDim.new(0, 6)

-- ═══ TAB CONTENT FRAMES ═══
local function MakeSF(name, visible)
    local sf = Instance.new("ScrollingFrame")
    sf.Name = name
    sf.Size = UDim2.new(1, -10, 1, -10)
    sf.Position = UDim2.new(0, 5, 0, 5)
    sf.BackgroundTransparency = 1
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 90)
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.Visible = visible
    sf.Parent = ContentArea
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = sf
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sf.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    return sf
end

local LassoTab = MakeSF("LassoTab", true)
local PetsTab  = MakeSF("PetsTab",  false)
local FruitTab = MakeSF("FruitTab", false)
local FoodTab  = MakeSF("FoodTab",  false)

-- Helper: Section label
local function SecLabel(parent, txt, col, ord)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, isMobile and 18 or 22)
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = col
    l.Font = Enum.Font.GothamBlack
    l.TextSize = isMobile and 10 or 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = ord
    l.Parent = parent
    return l
end

-- Helper: Button
local function MakeBtn(parent, txt, col, ord, h)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, h or (isMobile and 30 or 36))
    b.BackgroundColor3 = col
    b.BorderSizePixel = 0
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = isMobile and 10 or 12
    b.LayoutOrder = ord
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

-- Helper: Info label
local function InfoLbl(parent, txt, ord, wrap)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, isMobile and 28 or 34)
    l.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    l.BorderSizePixel = 0
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(180, 180, 180)
    l.Font = Enum.Font.Gotham
    l.TextSize = isMobile and 8 or 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = wrap or false
    l.LayoutOrder = ord
    l.Parent = parent
    Instance.new("UICorner", l).CornerRadius = UDim.new(0, 6)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 6)
    p.PaddingTop = UDim.new(0, 4)
    p.Parent = l
    return l
end

-- ══════════════════════════
-- LASSO TAB
-- ══════════════════════════
SecLabel(LassoTab, "⚡ AUTO LASSO", Color3.fromRGB(100, 255, 150), 1)
local toggleBtn = MakeBtn(LassoTab, "▶ Enable Auto Lasso", Color3.fromRGB(255, 60, 60), 2)
local lassoInfoLbl = InfoLbl(LassoTab,
    "⚡ Instant safe lock → fast complete\n👑 Boss: spam max speed + deteksi player",
    3, true)
lassoInfoLbl.Size = UDim2.new(1, 0, 0, isMobile and 36 or 44)

-- ══════════════════════════
-- PETS TAB
-- ══════════════════════════
SecLabel(PetsTab, "🔍 FIND BEST PETS", Color3.fromRGB(100, 200, 255), 1)
local findBestPetsBtn = MakeBtn(PetsTab, "🔍 Find Best Pet (Strength)", Color3.fromRGB(100, 150, 255), 2)
SecLabel(PetsTab, "📡 TELEPORT BY RARITY", Color3.fromRGB(200, 150, 255), 3)

local dropdownToggleBtn = MakeBtn(PetsTab, "▼  Pilih Rarity (0 dipilih)", Color3.fromRGB(60, 80, 120), 4, isMobile and 26 or 30)
dropdownToggleBtn.TextSize = isMobile and 9 or 11

local teleportRarityBtn = MakeBtn(PetsTab, "📡 Teleport ke Rarity", Color3.fromRGB(0, 170, 120), 5, isMobile and 28 or 32)
teleportRarityStatus = InfoLbl(PetsTab, "Pilih rarity lalu tekan teleport", 6)

-- Dropdown overlay
local dropdownFrame = Instance.new("Frame")
dropdownFrame.Size = UDim2.new(0, isMobile and 200 or 270, 0, 148)
dropdownFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
dropdownFrame.BorderSizePixel = 0
dropdownFrame.ClipsDescendants = false
dropdownFrame.Visible = false
dropdownFrame.ZIndex = 50
dropdownFrame.Parent = ScreenGui
Instance.new("UICorner", dropdownFrame).CornerRadius = UDim.new(0, 8)
local dropStroke = Instance.new("UIStroke")
dropStroke.Color = Color3.fromRGB(80, 80, 100)
dropStroke.Thickness = 1
dropStroke.Parent = dropdownFrame

local chipGrid = Instance.new("Frame")
chipGrid.Size = UDim2.new(1, -8, 1, -8)
chipGrid.Position = UDim2.new(0, 4, 0, 4)
chipGrid.BackgroundTransparency = 1
chipGrid.Parent = dropdownFrame

local uigrid = Instance.new("UIGridLayout")
uigrid.CellSize = UDim2.new(0.5, -6, 0, 28)
uigrid.CellPadding = UDim2.new(0, 4, 0, 4)
uigrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
uigrid.Parent = chipGrid

local rarityChipFrames = {}

local function updateDropdownLabel()
    local count, names = 0, {}
    for _, r in ipairs(RARITY_LIST) do
        if selectedRarities[r] then count = count + 1; table.insert(names, r) end
    end
    local arrow = dropdownOpen and "▲" or "▼"
    if count == 0 then
        dropdownToggleBtn.Text = arrow.."  Pilih Rarity (0 dipilih)"
    elseif count <= 2 then
        dropdownToggleBtn.Text = arrow.."  "..table.concat(names, ", ")
    else
        dropdownToggleBtn.Text = arrow.."  "..count.." rarity dipilih"
    end
end

local function buildRarityChips()
    for _, rarity in ipairs(RARITY_LIST) do
        local chip = Instance.new("TextButton")
        chip.Size = UDim2.new(0.5, -6, 0, 28)
        chip.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        chip.BorderSizePixel = 0
        chip.Text = rarity
        chip.TextColor3 = RARITY_COLORS[rarity] or Color3.fromRGB(200, 200, 200)
        chip.TextSize = 11
        chip.Font = Enum.Font.GothamBold
        chip.ZIndex = 51
        chip.Parent = chipGrid
        Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke")
        stroke.Color = RARITY_COLORS[rarity] or Color3.fromRGB(100, 100, 100)
        stroke.Thickness = 1.5
        stroke.Transparency = 0.5
        stroke.Parent = chip
        rarityChipFrames[rarity] = { btn = chip, stroke = stroke }
        chip.MouseButton1Click:Connect(function()
            if selectedRarities[rarity] then
                selectedRarities[rarity] = nil
                chip.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                stroke.Transparency = 0.5
            else
                selectedRarities[rarity] = true
                local c = RARITY_COLORS[rarity]
                chip.BackgroundColor3 = Color3.fromRGB(
                    math.floor(c.R * 255 * 0.3),
                    math.floor(c.G * 255 * 0.3),
                    math.floor(c.B * 255 * 0.3)
                )
                stroke.Transparency = 0
            end
            updateDropdownLabel()
        end)
    end
end
buildRarityChips()

local function updateDropdownPosition()
    local absPos = dropdownToggleBtn.AbsolutePosition
    local absSize = dropdownToggleBtn.AbsoluteSize
    dropdownFrame.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 2)
end

dropdownToggleBtn.MouseButton1Click:Connect(function()
    dropdownOpen = not dropdownOpen
    if dropdownOpen then
        updateDropdownPosition()
        dropdownFrame.Visible = true
    else
        dropdownFrame.Visible = false
    end
    updateDropdownLabel()
end)

UserInputService.InputBegan:Connect(function(input)
    if not dropdownOpen then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local mpos = UserInputService:GetMouseLocation()
    local fp, fs = dropdownFrame.AbsolutePosition, dropdownFrame.AbsoluteSize
    local tp, ts = dropdownToggleBtn.AbsolutePosition, dropdownToggleBtn.AbsoluteSize
    local inDrop = mpos.X>=fp.X and mpos.X<=fp.X+fs.X and mpos.Y>=fp.Y and mpos.Y<=fp.Y+fs.Y
    local inTog  = mpos.X>=tp.X and mpos.X<=tp.X+ts.X and mpos.Y>=tp.Y and mpos.Y<=tp.Y+ts.Y
    if not inDrop and not inTog then
        dropdownOpen = false
        dropdownFrame.Visible = false
        updateDropdownLabel()
    end
end)

-- ══════════════════════════
-- FRUIT TAB
-- ══════════════════════════
SecLabel(FruitTab, "🍎 AUTO COLLECT FRUIT", Color3.fromRGB(255, 200, 50), 1)
local toggleFruitBtn = MakeBtn(FruitTab, "▶ Enable Auto Collect Fruit", Color3.fromRGB(255, 140, 0), 2)
local fruitInfo = InfoLbl(FruitTab,
    "Deteksi realtime: CosmicFruit, BloodmoonGrape\nOtomatis teleport & collect saat ditemukan",
    3, true)
fruitInfo.Size = UDim2.new(1, 0, 0, isMobile and 36 or 44)
local fruitDetectDisplay = InfoLbl(FruitTab, "🔴 No fruit in area", 4)

-- ══════════════════════════
-- FOOD TAB
-- ══════════════════════════
SecLabel(FoodTab, "🍖 AUTO BUY FOOD", Color3.fromRGB(200, 130, 255), 1)
local toggleFoodBtn = MakeBtn(FoodTab, "▶ Enable Auto Buy Food", Color3.fromRGB(180, 80, 220), 2)
local foodInfo = InfoLbl(FoodTab,
    "Buy ALL food otomatis saat stock tersedia\nInstant react saat restock dari server",
    3, true)
foodInfo.Size = UDim2.new(1, 0, 0, isMobile and 36 or 44)
local foodDetailLbl = InfoLbl(FoodTab, "🔍 Mencari FoodService...", 4)

-- ═══════════════════════════════════════════
-- TAB SWITCHING
-- ═══════════════════════════════════════════
local CurrentTab = "LASSO"
local TabFrames = { LASSO=LassoTab, PETS=PetsTab, FRUIT=FruitTab, FOOD=FoodTab }

local function SwitchTab(n)
    CurrentTab = n
    for k, sf in pairs(TabFrames) do sf.Visible = (k==n) end
    for k, btn in pairs(TabButtons) do
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = (k==n) and Color3.fromRGB(0, 120, 60) or Color3.fromRGB(35, 35, 35)
        }):Play()
    end
end

for _, tn in ipairs(TAB_NAMES) do
    TabButtons[tn].MouseButton1Click:Connect(function() SwitchTab(tn) end)
end

-- ═══════════════════════════════════════════
-- ANIMATE IN
-- ═══════════════════════════════════════════
local function AnimateIn()
    TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency=0}):Play()
    TweenService:Create(MainStroke, TweenInfo.new(0.25), {Transparency=0}):Play()
    TweenService:Create(GlowFrame, TweenInfo.new(0.5), {ImageTransparency=0.75}):Play()
    task.spawn(function()
        while ScreenGui and ScreenGui.Parent do
            TweenService:Create(GlowFrame, TweenInfo.new(1), {ImageTransparency=0.85}):Play(); task.wait(1)
            TweenService:Create(GlowFrame, TweenInfo.new(1), {ImageTransparency=0.65}):Play(); task.wait(1)
        end
    end)
end
AnimateIn()

-- ═══════════════════════════════════════════
-- DRAG
-- ═══════════════════════════════════════════
local dragging, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = inp.Position; startPos = MainFrame.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
Header.InputChanged:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
        dragInput = inp
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if inp == dragInput and dragging then
        local d = inp.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- ═══════════════════════════════════════════
-- MINIMIZE / CLOSE
-- ═══════════════════════════════════════════
local IsMinimized = false
local origSize = MainFrame.Size

CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(MainFrame, TweenInfo.new(0.25), {BackgroundTransparency=1}):Play()
    task.wait(0.25); ScreenGui:Destroy()
end)

MinimizeBtn.MouseButton1Click:Connect(function()
    IsMinimized = not IsMinimized
    MinimizeBtn.Text = IsMinimized and "+" or "—"
    if IsMinimized then
        ContentArea.Visible = false; Sidebar.Visible = false; TabBar.Visible = false
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size=UDim2.new(0, MW, 0, HH)}):Play()
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size=origSize}):Play()
        task.wait(0.15)
        ContentArea.Visible = true; Sidebar.Visible = true; TabBar.Visible = true
    end
end)

-- ═══════════════════════════════════════════
-- UPDATE UI HELPER
-- ═══════════════════════════════════════════
local function updateUI()
    if autoCompleteEnabled then
        statusLabel.Text = "🟢 Auto Lasso: ON"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        toggleBtn.Text = "⏹ Disable Auto Lasso"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
    else
        statusLabel.Text = "🔴 Auto Lasso: OFF"
        statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
        toggleBtn.Text = "▶ Enable Auto Lasso"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        progressLabel.Text = "Waiting for minigame..."
        phaseLabel.Text = ""
    end
    if autoCollectFruitEnabled then
        toggleFruitBtn.Text = "⏹ Disable Auto Collect Fruit"
        toggleFruitBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
    else
        toggleFruitBtn.Text = "▶ Enable Auto Collect Fruit"
        toggleFruitBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    end
    if autoBuyFoodEnabled then
        toggleFoodBtn.Text = "⏹ Disable Auto Buy Food"
        toggleFoodBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 200)
    else
        toggleFoodBtn.Text = "▶ Enable Auto Buy Food"
        toggleFoodBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 220)
    end
end

-- ═══════════════════════════════════════════
-- SERVER EVENT LISTENER (Auto Lasso)
-- ═══════════════════════════════════════════
updateProgressRemote.OnClientEvent:Connect(function(eventType)
    if typeof(eventType) ~= "string" then return end
    if eventType == "cancel" then
        isProcessing = false; isBossActive = false; isWaiting = false
        if autoCompleteEnabled then progressLabel.Text = "Cancelled by server."; phaseLabel.Text = "" end
    elseif eventType == "waiting" then
        isWaiting = true; isBossActive = false
        if autoCompleteEnabled then phaseLabel.Text = "⏳ Waiting boss turn..." end
    elseif eventType == "bossSync" then
        isWaiting = false; isBossActive = true
        if autoCompleteEnabled then phaseLabel.Text = "👑 Boss turn - clicking!" end
    elseif eventType == "win" then
        isProcessing = false; isBossActive = false; isWaiting = false
        if autoCompleteEnabled then progressLabel.Text = "✅ WIN!"; phaseLabel.Text = "✅ COMPLETED!" end
    end
end)

-- ═══════════════════════════════════════════
-- MINIGAME HELPERS
-- ═══════════════════════════════════════════
local function getMinigameGui()
    for _, gui in pairs(playerGui:GetChildren()) do
        if gui.Name == "LassoMinigame" and gui:FindFirstChild("Holder") then
            return gui, gui.Holder
        end
    end
    return nil, nil
end

local function detectIsBoss(holder)
    if not holder then return false end
    local bossBars = holder:FindFirstChild("BossBars")
    if bossBars then
        local bossBar = bossBars:FindFirstChild("Boss")
        if bossBar and bossBar.Visible then return true end
        -- Cek semua anak BossBars yang visible (selain Lucky)
        for _, bar in pairs(bossBars:GetChildren()) do
            if bar.Name ~= "Lucky" and bar.Visible then return true end
        end
    end
    return false
end

-- ═══════════════════════════════════════════
-- [NEW] CEK JUMLAH PLAYER DI BOSS BATTLE
-- Hitung semua player yang punya LassoMinigame GUI aktif
-- ═══════════════════════════════════════════
local function getPlayerCountInBoss()
    local count = 0
    for _, p in pairs(Players:GetPlayers()) do
        -- LocalPlayer pasti ikut kalau minigamenya ada
        if p == player then
            if getMinigameGui() then count = count + 1 end
        else
            -- Player lain: cek PlayerGui mereka
            local pGui = p:FindFirstChild("PlayerGui")
            if pGui then
                local lassoGui = pGui:FindFirstChild("LassoMinigame")
                if lassoGui then count = count + 1 end
            end
        end
    end
    return math.max(count, 1)
end

-- ═══════════════════════════════════════════
-- [NEW] CEK APAKAH PET SUDAH DI-CAPTURED
-- Scan workspace untuk pet dengan Captured = true
-- ═══════════════════════════════════════════
local function checkPetCaptured()
    local function scan(parent, depth)
        if depth > 6 then return false end
        for _, obj in pairs(parent:GetChildren()) do
            if obj.Name ~= "PlayerPens" then
                if obj:GetAttribute("Captured") == true then
                    return true
                end
                if #obj:GetChildren() > 0 then
                    if scan(obj, depth + 1) then return true end
                end
            end
        end
        return false
    end
    return scan(workspace, 0)
end

-- ═══════════════════════════════════════════
-- AUTO COMPLETE MINIGAME (UPDATED WITH FIX)
-- ═══════════════════════════════════════════
local bossClickThread = nil

local function stopBossThread()
    if bossClickThread then task.cancel(bossClickThread); bossClickThread = nil end
end

local function startBossClickLoop()
    stopBossThread()
    bossClickThread = task.spawn(function()
        local clickCount = 0
        local tickCounter = 0

        while true do
            -- CEK 1: Apakah minigame GUI masih ada?
            local gui, holder = getMinigameGui()
            if not gui then
                -- GUI hilang = pet didapat atau dibatalkan
                progressLabel.Text = "✅ Boss selesai!"
                phaseLabel.Text = ""
                break
            end

            -- CEK 2: Apakah pet sudah di-captured?
            if checkPetCaptured() then
                progressLabel.Text = "✅ Pet berhasil didapat!"
                phaseLabel.Text = "✅ CAPTURED!"
                task.wait(1)
                break
            end

            if not autoCompleteEnabled then break end

            -- CEK 3: Update jumlah player tiap ~60 tick (~1 detik)
            tickCounter = tickCounter + 1
            if tickCounter >= 60 then
                tickCounter = 0
                local playerCount = getPlayerCountInBoss()
                local playerInfo = playerCount >= 2
                    and string.format("👥 %d players", playerCount)
                    or "👤 Solo"

                if isBossActive and not isWaiting then
                    phaseLabel.Text = string.format("👑 Boss %s — Clicking!", playerInfo)
                elseif isWaiting then
                    phaseLabel.Text = string.format("⏳ Waiting... %s", playerInfo)
                else
                    phaseLabel.Text = string.format("👑 Boss %s", playerInfo)
                end
            end

            -- Klik boss jika giliran aktif
            if isBossActive and not isWaiting then
                pcall(function() updateProgressRemote:FireServer(1) end)
                clickCount = clickCount + 1
                progressLabel.Text = string.format("👑 Boss clicks: %d", clickCount)
            elseif isWaiting then
                progressLabel.Text = "⏳ Waiting boss turn..."
            end

            task.wait()
        end

        isBossActive = false
        isWaiting = false
    end)
end

local function autoCompleteMinigame()
    if isProcessing then return end
    if not autoCompleteEnabled then return end

    local gui, holder = getMinigameGui()
    if not gui then return end

    isProcessing = true
    local isBoss = detectIsBoss(holder) or isBossActive

    if isBoss then
        -- === BOSS MODE ===
        local playerCount = getPlayerCountInBoss()
        local playerInfo  = playerCount >= 2
            and string.format("👥 %d players", playerCount)
            or "👤 Solo"

        phaseLabel.Text   = string.format("👑 BOSS | %s", playerInfo)
        progressLabel.Text = "⚡ Spamming boss clicks..."
        Notify("👑 Boss Battle!", string.format("%s — Spam max speed!", playerInfo), 3)

        if not isBossActive then isBossActive = true end
        startBossClickLoop()

        -- Loop utama: tunggu sampai minigame benar-benar selesai
        local statusTimer = 0
        while autoCompleteEnabled do
            local currentGui, currentHolder = getMinigameGui()

            -- GUI hilang = selesai
            if not currentGui then
                progressLabel.Text = "Waiting for next minigame..."
                phaseLabel.Text    = ""
                break
            end

            -- Pet sudah di-captured = selesai
            if checkPetCaptured() then
                progressLabel.Text = "✅ Pet berhasil didapat!"
                phaseLabel.Text    = "✅ DONE"
                task.wait(1.5)
                break
            end

            -- Update status player count tiap 1 detik
            statusTimer = statusTimer + 0.2
            if statusTimer >= 1 then
                statusTimer = 0
                local pc = getPlayerCountInBoss()
                local pInfo = pc >= 2 and string.format("👥 %d players", pc) or "👤 Solo"
                if isWaiting then
                    phaseLabel.Text = string.format("⏳ Waiting... | %s", pInfo)
                elseif isBossActive then
                    phaseLabel.Text = string.format("👑 Clicking! | %s", pInfo)
                else
                    phaseLabel.Text = string.format("👑 Boss | %s", pInfo)
                end
            end

            task.wait(0.2)
        end

        stopBossThread()
        isBossActive   = false
        isWaiting      = false
        isProcessing   = false

        if not getMinigameGui() then
            progressLabel.Text = "Waiting for next minigame..."
            phaseLabel.Text    = ""
        end

    else
        -- === NORMAL MODE (non-boss) ===
        task.spawn(function()
            local currentProgress = 0
            progressLabel.Text = "⚡ Fast locking safe zone..."
            phaseLabel.Text    = "⚡ LOCKING..."

            currentProgress = SAFE_ZONE_TARGET
            for _ = 1, 3 do
                if not getMinigameGui() or not autoCompleteEnabled then isProcessing = false; return end
                pcall(function() updateProgressRemote:FireServer(currentProgress) end)
                task.wait(0.05)
            end

            phaseLabel.Text    = "✓ LOCKED! Completing..."
            progressLabel.Text = string.format("Safe Zone: %d%% ✓", currentProgress)

            for _ = 1, 3 do
                if not getMinigameGui() then break end
                pcall(function() updateProgressRemote:FireServer(currentProgress) end)
                task.wait(0.08)
            end

            task.wait(0.2)
            phaseLabel.Text = "⚡ Completing..."

            while currentProgress < COMPLETION_TARGET and getMinigameGui() and autoCompleteEnabled do
                local increment = math.random(2, 8)
                currentProgress = math.min(currentProgress + increment, COMPLETION_TARGET)
                progressLabel.Text = string.format("⚡ Completing: %d%%", currentProgress)
                pcall(function() updateProgressRemote:FireServer(currentProgress) end)

                if currentProgress >= COMPLETION_TARGET then
                    progressLabel.Text = "100% ✓ DONE!"
                    phaseLabel.Text    = "✅ COMPLETED!"
                    for _ = 1, 3 do
                        if not getMinigameGui() then break end
                        pcall(function() updateProgressRemote:FireServer(100) end)
                        task.wait(0.05)
                    end
                    Notify("✓ Selesai!", "Minigame completed!", 2)
                    break
                end
                task.wait(0.04)
            end

            task.wait(0.5)
            isProcessing = false
            if not getMinigameGui() then
                progressLabel.Text = "Waiting for next minigame..."
                phaseLabel.Text    = ""
            end
        end)
    end
end

-- ═══════════════════════════════════════════
-- FIND BEST PETS
-- ═══════════════════════════════════════════
local function findBestPets()
    local bestPet, highestStrength, totalScanned = nil, -math.huge, 0
    local function scan(parent)
        for _, obj in pairs(parent:GetChildren()) do
            if obj.Name ~= "PlayerPens" then
                local str = obj:GetAttribute("Strength")
                if str then
                    local inPen, anc = false, obj.Parent
                    while anc and anc ~= workspace do
                        if anc.Name == "PlayerPens" then inPen = true; break end
                        anc = anc.Parent
                    end
                    if not inPen and not obj:GetAttribute("OwnerId") then
                        totalScanned = totalScanned + 1
                        if str > highestStrength then highestStrength = str; bestPet = obj end
                    end
                end
                if #obj:GetChildren() > 0 then scan(obj) end
            end
        end
    end
    scan(workspace)
    if bestPet then
        if bestPet:GetAttribute("OwnerId") then Notify("❌ Skip", "Pet punya OwnerId", 2); return end
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local tp = (bestPet:IsA("Model") and (bestPet.PrimaryPart or bestPet:FindFirstChild("HumanoidRootPart")))
                or (bestPet:IsA("BasePart") and bestPet)
        if hrp and tp then
            hrp.CFrame = tp.CFrame * CFrame.new(0, 0, 5)
            Notify("🔍 Best Pet!", string.format("💪 Str: %d | %s", highestStrength, bestPet.Name), 5)
        else
            Notify("🔍 Best Pet!", string.format("Str: %d | No part to TP", highestStrength), 3)
        end
    else
        Notify("❌ Not Found", string.format("Scanned %d objects", totalScanned), 3)
    end
end

-- ═══════════════════════════════════════════
-- TELEPORT BY RARITY
-- ═══════════════════════════════════════════
local function getPetRarity(pet)
    local r = pet:GetAttribute("Rarity")
    if r and r ~= "" then return r end
    if PetsConfig then
        local cfg = PetsConfig[pet.Name]
        if cfg and cfg.Rarity then return cfg.Rarity end
    end
    return nil
end

local function teleportByRarity()
    local count = 0
    for _ in pairs(selectedRarities) do count = count + 1 end
    if count == 0 then
        teleportRarityStatus.Text = "⚠️ Pilih minimal 1 rarity dulu!"
        teleportRarityStatus.TextColor3 = Color3.fromRGB(255, 200, 50)
        return
    end
    teleportRarityStatus.Text = "🔍 Scanning pets..."
    teleportRarityStatus.TextColor3 = Color3.fromRGB(255, 200, 50)

    -- Prioritas sesuai game: Exclusive > Secret > Boss > Mythical > Legendary > Epic > Rare = Common
    local RARITY_ORDER = { Exclusive=7, Secret=6, Boss=5, Mythical=4, Legendary=3, Epic=2, Rare=1, Common=1 }
    local bestPet, bestRarityScore, bestStr, totalFound = nil, -1, -math.huge, 0

    local function scan(parent)
        for _, obj in pairs(parent:GetChildren()) do
            if obj.Name ~= "PlayerPens" then
                local rarity = getPetRarity(obj)
                if rarity and selectedRarities[rarity] then
                    local inPen, anc = false, obj.Parent
                    while anc and anc ~= workspace do
                        if anc.Name == "PlayerPens" then inPen = true; break end
                        anc = anc.Parent
                    end
                    if not inPen and not obj:GetAttribute("OwnerId") then
                        totalFound = totalFound + 1
                        local score = RARITY_ORDER[rarity] or 0
                        local str = obj:GetAttribute("Strength") or 0
                        if score > bestRarityScore or (score == bestRarityScore and str > bestStr) then
                            bestRarityScore = score; bestStr = str; bestPet = obj
                        end
                    end
                end
                if #obj:GetChildren() > 0 then scan(obj) end
            end
        end
    end
    scan(workspace)

    if bestPet then
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local tp = (bestPet:IsA("Model") and (bestPet.PrimaryPart or bestPet:FindFirstChild("HumanoidRootPart")))
                or (bestPet:IsA("BasePart") and bestPet)
        local petRarity = getPetRarity(bestPet) or "?"
        local petName   = bestPet.Name or "Unknown"
        local petStr    = bestPet:GetAttribute("Strength") or 0
        if hrp and tp then
            hrp.CFrame = tp.CFrame * CFrame.new(0, 0, 5)
            teleportRarityStatus.Text = string.format("✅ %s [%s] Str:%d", petName, petRarity, petStr)
            teleportRarityStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
            Notify("📡 TP!", string.format("%s [%s] Str:%d Found:%d", petName, petRarity, petStr, totalFound), 4)
        else
            teleportRarityStatus.Text = string.format("Found %s but no part", petName)
            teleportRarityStatus.TextColor3 = Color3.fromRGB(255, 200, 50)
        end
    else
        teleportRarityStatus.Text = string.format("❌ Tidak ada pet ditemukan (%d scan)", totalFound)
        teleportRarityStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
        Notify("❌", "Tidak ada pet dengan rarity tersebut!", 3)
    end
end

-- ═══════════════════════════════════════════
-- FRUIT DETECTION & COLLECTION
-- ═══════════════════════════════════════════
local function getActivePrompt(model)
    for _, d in pairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then return d end
    end
    return nil
end

local function updateDetectLabel()
    local n = 0
    for _ in pairs(detectedFruits) do n = n + 1 end
    local txt, col
    if n > 0 then
        txt = string.format("🟢 Fruit detected: %d", n)
        col = Color3.fromRGB(100, 255, 100)
    else
        txt = "🔴 No fruit detected"
        col = Color3.fromRGB(255, 100, 100)
    end
    fruitDetectLabel.Text = txt; fruitDetectLabel.TextColor3 = col
    fruitDetectDisplay.Text = txt; fruitDetectDisplay.TextColor3 = col
end

local function registerFruit(fruitModel)
    if detectedFruits[fruitModel] then return end
    local prompt = getActivePrompt(fruitModel)
    if not prompt then return end
    detectedFruits[fruitModel] = prompt
    updateDetectLabel()
    fruitModel.AncestryChanged:Connect(function()
        if not fruitModel:IsDescendantOf(workspace) then
            detectedFruits[fruitModel] = nil; updateDetectLabel()
        end
    end)
end

local function watchUID(uid)
    if realtimeConns[uid] then return end
    for _, child in pairs(uid:GetChildren()) do
        if FRUIT_SET[child.Name] then registerFruit(child) end
    end
    realtimeConns[uid] = uid.ChildAdded:Connect(function(child)
        if FRUIT_SET[child.Name] then task.wait(0.1); registerFruit(child) end
    end)
end

local function startRealtimeDetection()
    local wv = workspace:FindFirstChild("WeatherVisuals")
    if not wv then
        workspace.ChildAdded:Connect(function(child)
            if child.Name == "WeatherVisuals" then task.wait(0.2); startRealtimeDetection() end
        end)
        return
    end
    for _, uid in pairs(wv:GetChildren()) do watchUID(uid) end
    wv.ChildAdded:Connect(function(uid) task.wait(0.1); watchUID(uid) end)
    wv.ChildRemoved:Connect(function(uid)
        if realtimeConns[uid] then realtimeConns[uid]:Disconnect(); realtimeConns[uid] = nil end
    end)
end
startRealtimeDetection()

local function collectFruit(fruitModel, proximityPrompt)
    if not autoCollectFruitEnabled then return end
    if isCollecting then return end
    if not FRUIT_SET[fruitModel.Name] then return end
    if not detectedFruits[fruitModel] then return end
    isCollecting = true
    pcall(function()
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local targetPart = fruitModel:FindFirstChild("Handle")
            or (fruitModel:IsA("Model") and fruitModel.PrimaryPart)
        if not targetPart then
            for _, v in pairs(fruitModel:GetDescendants()) do
                if v:IsA("BasePart") then targetPart = v; break end
            end
        end
        if not targetPart then return end
        if not proximityPrompt or not proximityPrompt.Enabled or not proximityPrompt.Parent then
            detectedFruits[fruitModel] = nil; updateDetectLabel(); return
        end
        local activeDist = proximityPrompt.MaxActivationDistance
        local tpDist = math.max(activeDist - 2, 1)
        local dir = (hrp.Position - targetPart.Position)
        dir = dir.Magnitude < 0.01 and Vector3.new(0, 0, 1) or dir.Unit
        hrp.CFrame = CFrame.new(targetPart.Position + dir * tpDist)
        task.wait(0.2)
        if (hrp.Position - targetPart.Position).Magnitude > activeDist then
            hrp.CFrame = targetPart.CFrame * CFrame.new(0, 0, tpDist); task.wait(0.15)
        end
        if not proximityPrompt.Enabled or not proximityPrompt.Parent then
            detectedFruits[fruitModel] = nil; updateDetectLabel(); return
        end
        local origHold = proximityPrompt.HoldDuration
        proximityPrompt.HoldDuration = 0
        local fired = false
        if fireproximityprompt then
            local ok = pcall(function() fireproximityprompt(proximityPrompt) end)
            if ok then fired = true end
        end
        if not fired then
            proximityPrompt:InputHoldBegin()
            task.wait(0.05)
            proximityPrompt:InputHoldEnd()
        end
        task.delay(0.2, function()
            pcall(function() proximityPrompt.HoldDuration = origHold end)
        end)
        fruitCollectedCount = fruitCollectedCount + 1
        fruitStatusLabel.Text = string.format("🍎 Fruit: %d collected", fruitCollectedCount)
    end)
    task.wait(0.4); isCollecting = false
end

task.spawn(function()
    while task.wait(0.5) do
        if autoCollectFruitEnabled then
            for fruitModel, prompt in pairs(detectedFruits) do
                if not autoCollectFruitEnabled then break end
                if not prompt or not prompt.Parent or not prompt.Enabled then
                    local np = getActivePrompt(fruitModel)
                    if np then detectedFruits[fruitModel] = np; collectFruit(fruitModel, np)
                    else detectedFruits[fruitModel] = nil; updateDetectLabel() end
                else
                    collectFruit(fruitModel, prompt)
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════
-- AUTO BUY FOOD
-- ═══════════════════════════════════════════
local function findRemoteInService(serviceName, remoteName)
    local function search(parent)
        if not parent then return nil end
        for _, v in pairs(parent:GetChildren()) do
            if v.Name == remoteName then return v end
            local found = search(v)
            if found then return found end
        end
        return nil
    end
    local servicesFolder = ReplicatedStorage:FindFirstChild("Services")
    if servicesFolder then
        local svc = servicesFolder:FindFirstChild(serviceName)
        if svc then
            local r = search(svc)
            if r then return r end
        end
    end
    return search(ReplicatedStorage)
end

local _foodConfigCache = nil
local function getFoodConfig()
    if _foodConfigCache then return _foodConfigCache end
    if FoodConfig then _foodConfigCache = FoodConfig; return _foodConfigCache end
    local ok, cfg = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Configs", 5):WaitForChild("Food", 5))
    end)
    if ok and cfg then _foodConfigCache = cfg end
    return _foodConfigCache
end

local function isValidFoodItem(itemName)
    local cfg = getFoodConfig()
    if cfg then
        local entry = cfg[itemName]
        if entry == nil then return false end
        if entry.Stock == nil then return false end
        return true
    end
    warn("[AutoFood] FoodConfig belum tersedia, semua item diizinkan sementara")
    return true
end

local function doBuyAllFood(buyFoodRemote, stock)
    local totalBought, bought, skipped = 0, {}, {}
    for foodName, qty in pairs(stock) do
        if not autoBuyFoodEnabled then break end
        if qty > 0 then
            if isValidFoodItem(foodName) then
                local ok = pcall(function() buyFoodRemote:FireServer(foodName, qty) end)
                if ok then
                    totalBought = totalBought + qty
                    foodBoughtCount = foodBoughtCount + qty
                    table.insert(bought, foodName.." x"..qty)
                end
                task.wait(0.05)
            else
                table.insert(skipped, foodName)
            end
        end
    end
    if #skipped > 0 then
        warn("[AutoFood] Skip (bukan food): "..table.concat(skipped, ", "))
    end
    return totalBought, bought
end

task.spawn(function()
    foodDetailLbl.Text = "🔍 Mencari FoodService..."
    local buyFoodRemote, replicateStockRemote

    for _ = 1, 30 do
        buyFoodRemote = findRemoteInService("FoodService", "BuyFood")
        replicateStockRemote = findRemoteInService("FoodService", "ReplicateStock")
        if buyFoodRemote and replicateStockRemote then break end
        task.wait(1)
    end

    if not buyFoodRemote then
        foodDetailLbl.Text = "❌ FoodService tidak ditemukan"
        foodDetailLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
        foodStatusLabel.Text = "❌ FoodService tidak ditemukan"
        return
    end

    foodDetailLbl.Text = "⏳ Menunggu stock info..."
    foodStatusLabel.Text = "⏳ Menunggu stock..."

    -- ═══ Realtime restock countdown ═══
    -- Sama persis seperti game: pakai os.clock() + nextRestockSec
    -- Dari decompile: NextRestock = os.clock() + p80
    local _nextRestock   = os.clock() + 8  -- default sama seperti game
    local _restockThread = nil

    local function startRestockCountdown(seconds)
        -- Set target waktu restock pakai os.clock() seperti aslinya
        _nextRestock = os.clock() + math.max(seconds or 0, 0)
        if _restockThread then task.cancel(_restockThread) end
        _restockThread = task.spawn(function()
            while true do
                local remaining = _nextRestock - os.clock()
                if remaining <= 0 then
                    foodStatusLabel.Text = "⏳ Restock dalam 0s..."
                    foodDetailLbl.Text   = "⏳ Restock dalam 0s..."
                    break
                end
                local mins = math.floor(remaining / 60)
                local secs = math.floor(remaining % 60)
                local txt
                if mins > 0 then
                    txt = string.format("⏳ Restock dalam %dm %02ds...", mins, secs)
                else
                    txt = string.format("⏳ Restock dalam %ds...", secs)
                end
                foodStatusLabel.Text = txt
                foodDetailLbl.Text   = txt
                task.wait(1)
            end
        end)
    end

    if replicateStockRemote then
        replicateStockRemote.OnClientEvent:Connect(function(stockTable, nextRestockSec, isRestock)
            -- Dari decompile: p79=stockTable, p80=nextRestockSec, p81=isRestock
            local anyStock = false
            for foodName, qty in pairs(stockTable) do
                _foodStock[foodName] = qty
                if qty > 0 then anyStock = true end
            end
            _foodAllEmpty = not anyStock

            if _foodAllEmpty then
                -- Stock kosong → mulai countdown realtime
                if _restockThread then task.cancel(_restockThread); _restockThread = nil end
                startRestockCountdown(nextRestockSec)
            else
                -- Ada stock → stop countdown
                if _restockThread then task.cancel(_restockThread); _restockThread = nil end
            end

            if autoBuyFoodEnabled and anyStock then
                task.spawn(function()
                    local totalBought, boughtList = doBuyAllFood(buyFoodRemote, _foodStock)
                    if totalBought > 0 then
                        local txt = string.format("🍖 Total: %d | +%d%s", foodBoughtCount, totalBought, isRestock and " 🆕" or "")
                        foodStatusLabel.Text = txt
                        foodDetailLbl.Text = txt
                        local listStr = #boughtList <= 2 and table.concat(boughtList, ", ")
                            or table.concat(boughtList, ", ", 1, 2)..".."
                        Notify(isRestock and "🆕 RESTOCK!" or "🍖 Buy All!", "+"..totalBought.." item | "..listStr, 3)
                    end
                end)
            end
        end)
    end

    if not replicateStockRemote then
        foodDetailLbl.Text = "⚠️ Fallback poll mode"
        while true do
            task.wait(0.5)
            if autoBuyFoodEnabled then
                local stock, anyStock = {}, false
                local gui = playerGui:FindFirstChild("FoodShop")
                local scrolling = gui and gui:FindFirstChild("Holder") and gui.Holder:FindFirstChild("ScrollingFrame")
                if scrolling then
                    for _, item in pairs(scrolling:GetChildren()) do
                        if item:IsA("Frame") then
                            local st = item:FindFirstChild("Holder")
                                and item.Holder:FindFirstChild("ItemInfo")
                                and item.Holder.ItemInfo:FindFirstChild("Stock")
                                and item.Holder.ItemInfo.Stock:FindFirstChild("StockText")
                            if st then
                                local txt2 = st.Text or ""
                                local n = txt2 == "Out of stock!" and 0 or (tonumber(txt2:match("%d+")) or 0)
                                stock[item.Name] = n
                                if n > 0 then anyStock = true end
                            end
                        end
                    end
                end
                _foodAllEmpty = not anyStock
                if anyStock then
                    local totalBought, _ = doBuyAllFood(buyFoodRemote, stock)
                    if totalBought > 0 then
                        local txt = string.format("🍖 Total: %d | +%d", foodBoughtCount, totalBought)
                        foodStatusLabel.Text = txt; foodDetailLbl.Text = txt
                    end
                else
                    foodStatusLabel.Text = "⏳ Menunggu restock..."
                    foodDetailLbl.Text = "⏳ Menunggu restock..."
                end
            end
        end
    end

    while true do
        task.wait(0.3)
        if autoBuyFoodEnabled and not _foodAllEmpty then
            local anyStock = false
            for _, qty in pairs(_foodStock) do if qty > 0 then anyStock = true; break end end
            if not anyStock then _foodAllEmpty = true
            else
                local totalBought, _ = doBuyAllFood(buyFoodRemote, _foodStock)
                if totalBought > 0 then
                    for k in pairs(_foodStock) do _foodStock[k] = 0 end
                    _foodAllEmpty = true
                    local txt = string.format("🍖 Total: %d | +%d", foodBoughtCount, totalBought)
                    foodStatusLabel.Text = txt; foodDetailLbl.Text = txt
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════
-- TOGGLE FUNCTIONS
-- ═══════════════════════════════════════════
local function playToggleSound()
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://6895079853"
    s.Volume = 0.5
    s.Parent = ScreenGui
    s:Play()
    task.delay(1, function() s:Destroy() end)
end

local function toggleAutoComplete()
    autoCompleteEnabled = not autoCompleteEnabled
    if not autoCompleteEnabled then
        isProcessing = false; stopBossThread(); isBossActive = false; isWaiting = false
    end
    updateUI()
    Notify("⚡ Auto Lasso", autoCompleteEnabled and "ON — Instant lock aktif!" or "OFF", 2)
    playToggleSound()
end

local function toggleAutoCollectFruit()
    autoCollectFruitEnabled = not autoCollectFruitEnabled
    updateUI()
    Notify("🍎 Auto Fruit", autoCollectFruitEnabled and "ON — Realtime detection!" or "OFF", 2)
    playToggleSound()
end

local function toggleAutoBuyFood()
    autoBuyFoodEnabled = not autoBuyFoodEnabled
    updateUI()
    Notify("🍖 Auto Food", autoBuyFoodEnabled and "ON — Buy All + Restock!" or "OFF", 2)
    playToggleSound()
end

-- ═══════════════════════════════════════════
-- BUTTON EVENTS
-- ═══════════════════════════════════════════
local function animateButton(btn)
    local os2 = btn.Size
    TweenService:Create(btn, TweenInfo.new(0.08), {Size=UDim2.new(os2.X.Scale*0.95, os2.X.Offset*0.95, os2.Y.Scale, os2.Y.Offset*0.95)}):Play()
    task.wait(0.08)
    TweenService:Create(btn, TweenInfo.new(0.08), {Size=os2}):Play()
end

toggleBtn.MouseButton1Click:Connect(function()       animateButton(toggleBtn);       toggleAutoComplete() end)
toggleFruitBtn.MouseButton1Click:Connect(function()  animateButton(toggleFruitBtn);  toggleAutoCollectFruit() end)
toggleFoodBtn.MouseButton1Click:Connect(function()   animateButton(toggleFoodBtn);   toggleAutoBuyFood() end)
findBestPetsBtn.MouseButton1Click:Connect(function() animateButton(findBestPetsBtn); findBestPets() end)
teleportRarityBtn.MouseButton1Click:Connect(function() animateButton(teleportRarityBtn); teleportByRarity() end)

local function Hover(btn, onCol, offCol)
    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3=onCol}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3=offCol}):Play() end)
end
Hover(findBestPetsBtn,  Color3.fromRGB(130, 170, 255), Color3.fromRGB(100, 150, 255))
Hover(teleportRarityBtn, Color3.fromRGB(0, 210, 150),  Color3.fromRGB(0, 170, 120))
Hover(CloseBtn,          Color3.fromRGB(255, 100, 100), Color3.fromRGB(200, 50, 50))

-- Keybinds
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F1 then toggleAutoComplete()
    elseif input.KeyCode == Enum.KeyCode.F2 then toggleAutoCollectFruit()
    elseif input.KeyCode == Enum.KeyCode.F3 then toggleAutoBuyFood() end
end)

-- ═══════════════════════════════════════════
-- MINIGAME LISTENER
-- ═══════════════════════════════════════════
playerGui.ChildAdded:Connect(function(child)
    if child.Name == "LassoMinigame" and autoCompleteEnabled then
        task.wait(0.3)
        local _, holder = getMinigameGui()
        local isBoss = detectIsBoss(holder)
        -- Hitung player di boss saat awal
        local playerCount = isBoss and getPlayerCountInBoss() or 1
        local playerInfo  = playerCount >= 2 and string.format("👥 %d players", playerCount) or "👤 Solo"
        Notify(
            (isBoss or isBossActive) and "👑 Boss Battle!" or "⚡ Minigame!",
            (isBoss or isBossActive) and ("Spam max speed | "..playerInfo) or "Fast locking...",
            2)
        autoCompleteMinigame()
    end
end)

playerGui.ChildRemoved:Connect(function(child)
    if child.Name == "LassoMinigame" then
        isProcessing = false; stopBossThread(); isBossActive = false; isWaiting = false
        if autoCompleteEnabled then
            progressLabel.Text = "Waiting for next minigame..."
            phaseLabel.Text    = ""
        end
    end
end)

-- ═══════════════════════════════════════════
-- STARTUP
-- ═══════════════════════════════════════════
updateUI()
task.wait(0.5)
Notify("⚡ Auto Lasso v7 × Avantrix", "F1=Lasso | F2=Fruit | F3=Food", 5)
