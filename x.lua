-- Fast Auto Complete Lasso + Auto Mount + Auto Collect Fruit
-- Fast safe zone lock tanpa delay lama

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Settings
local autoCompleteEnabled = false
local autoCollectFruitEnabled = false
local isProcessing = false
local isCollecting = false
local SAFE_ZONE_MIN = 23
local SAFE_ZONE_TARGET = 28
local COMPLETION_TARGET = 100

-- Get remotes
local updateProgressRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateProgress")
local requestMountRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("requestMount")

-- Create GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoLassoGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 320)
mainFrame.Position = UDim2.new(0.85, 0, 0.4, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.BackgroundTransparency = 1
shadow.Position = UDim2.new(0, -15, 0, -15)
shadow.Size = UDim2.new(1, 30, 1, 30)
shadow.ZIndex = -1
shadow.Image = "rbxassetid://5554236805"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.5
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(23, 23, 277, 277)
shadow.Parent = mainFrame

local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

local titleCover = Instance.new("Frame")
titleCover.Size = UDim2.new(1, 0, 0, 12)
titleCover.Position = UDim2.new(0, 0, 1, -12)
titleCover.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
titleCover.BorderSizePixel = 0
titleCover.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Name = "Title"
titleText.Size = UDim2.new(1, -50, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "⚡ Fast Auto Lasso"
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.TextSize = 16
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 20
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = titleBar

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 8)
closeBtnCorner.Parent = closeBtn

local contentFrame = Instance.new("Frame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -20, 1, -50)
contentFrame.Position = UDim2.new(0, 10, 0, 45)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local findBestPetsBtn = Instance.new("TextButton")
findBestPetsBtn.Name = "FindBestPetsButton"
findBestPetsBtn.Size = UDim2.new(1, 0, 0, 35)
findBestPetsBtn.Position = UDim2.new(0, 0, 0, 0)
findBestPetsBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
findBestPetsBtn.BorderSizePixel = 0
findBestPetsBtn.Text = "🔍 Find Best Pets"
findBestPetsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
findBestPetsBtn.TextSize = 14
findBestPetsBtn.Font = Enum.Font.GothamBold
findBestPetsBtn.Parent = contentFrame

local findBestPetsCorner = Instance.new("UICorner")
findBestPetsCorner.CornerRadius = UDim.new(0, 8)
findBestPetsCorner.Parent = findBestPetsBtn

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 40)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Disabled"
statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
statusLabel.TextSize = 13
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = contentFrame

local progressLabel = Instance.new("TextLabel")
progressLabel.Name = "Progress"
progressLabel.Size = UDim2.new(1, 0, 0, 18)
progressLabel.Position = UDim2.new(0, 0, 0, 63)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Waiting for minigame..."
progressLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
progressLabel.TextSize = 11
progressLabel.Font = Enum.Font.Gotham
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.Parent = contentFrame

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Name = "Phase"
phaseLabel.Size = UDim2.new(1, 0, 0, 18)
phaseLabel.Position = UDim2.new(0, 0, 0, 81)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Text = ""
phaseLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
phaseLabel.TextSize = 10
phaseLabel.Font = Enum.Font.GothamMedium
phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
phaseLabel.Parent = contentFrame

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleButton"
toggleBtn.Size = UDim2.new(1, 0, 0, 40)
toggleBtn.Position = UDim2.new(0, 0, 0, 103)
toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
toggleBtn.BorderSizePixel = 0
toggleBtn.Text = "Enable Auto Lasso"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize = 14
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.Parent = contentFrame

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleBtn

local toggleFruitBtn = Instance.new("TextButton")
toggleFruitBtn.Name = "ToggleFruitButton"
toggleFruitBtn.Size = UDim2.new(1, 0, 0, 40)
toggleFruitBtn.Position = UDim2.new(0, 0, 0, 148)
toggleFruitBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
toggleFruitBtn.BorderSizePixel = 0
toggleFruitBtn.Text = "Enable Auto Collect Fruit"
toggleFruitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleFruitBtn.TextSize = 14
toggleFruitBtn.Font = Enum.Font.GothamBold
toggleFruitBtn.Parent = contentFrame

local toggleFruitCorner = Instance.new("UICorner")
toggleFruitCorner.CornerRadius = UDim.new(0, 8)
toggleFruitCorner.Parent = toggleFruitBtn

local fruitStatusLabel = Instance.new("TextLabel")
fruitStatusLabel.Name = "FruitStatus"
fruitStatusLabel.Size = UDim2.new(1, 0, 0, 18)
fruitStatusLabel.Position = UDim2.new(0, 0, 0, 193)
fruitStatusLabel.BackgroundTransparency = 1
fruitStatusLabel.Text = "Fruit Collected: 0"
fruitStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
fruitStatusLabel.TextSize = 10
fruitStatusLabel.Font = Enum.Font.Gotham
fruitStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
fruitStatusLabel.Parent = contentFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "Info"
infoLabel.Size = UDim2.new(1, 0, 0, 50)
infoLabel.Position = UDim2.new(0, 0, 0, 211)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "⚡ Fast safe zone lock\n✓ Auto mount pet\n🍎 Auto collect cosmic fruit\nF1=Lasso | F2=Fruit"
infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
infoLabel.TextSize = 9
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextWrapped = true
infoLabel.Parent = contentFrame

screenGui.Parent = playerGui

-- Functions
local function updateUI()
    if autoCompleteEnabled then
        statusLabel.Text = "Status: Enabled ✓"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        toggleBtn.Text = "Disable Auto Lasso"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 255, 60)
    else
        statusLabel.Text = "Status: Disabled"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        toggleBtn.Text = "Enable Auto Lasso"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        progressLabel.Text = "Waiting for minigame..."
        phaseLabel.Text = ""
    end
    if autoCollectFruitEnabled then
        toggleFruitBtn.Text = "Disable Auto Collect Fruit"
        toggleFruitBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
    else
        toggleFruitBtn.Text = "Enable Auto Collect Fruit"
        toggleFruitBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    end
end

local function showNotification(text, duration)
    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(0, 300, 0, 65)
    notif.Position = UDim2.new(0.5, -150, 0, -75)
    notif.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    notif.BorderSizePixel = 0
    notif.Parent = screenGui
    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = UDim.new(0, 10)
    notifCorner.Parent = notif
    local notifText = Instance.new("TextLabel")
    notifText.Size = UDim2.new(1, -20, 1, 0)
    notifText.Position = UDim2.new(0, 10, 0, 0)
    notifText.BackgroundTransparency = 1
    notifText.Text = text
    notifText.TextColor3 = Color3.fromRGB(255, 255, 255)
    notifText.TextSize = 13
    notifText.Font = Enum.Font.Gotham
    notifText.TextWrapped = true
    notifText.Parent = notif
    TweenService:Create(notif, TweenInfo.new(0.3), {
        Position = UDim2.new(0.5, -150, 0, 10)
    }):Play()
    task.delay(duration or 3, function()
        TweenService:Create(notif, TweenInfo.new(0.3), {
            Position = UDim2.new(0.5, -150, 0, -75)
        }):Play()
        task.wait(0.3)
        notif:Destroy()
    end)
end

local function getCurrentMinigame()
    for _, gui in pairs(playerGui:GetChildren()) do
        if gui.Name == "LassoMinigame" and gui:FindFirstChild("Holder") then
            return gui
        end
    end
    return nil
end

-- Auto Collect Fruit
local fruitCollectedCount = 0

local function collectFruit(proximityPrompt)
    if not autoCollectFruitEnabled then return end
    if isCollecting then return end
    isCollecting = true
    pcall(function()
        local originalDuration = proximityPrompt.HoldDuration
        proximityPrompt.HoldDuration = 0
        fireproximityprompt(proximityPrompt)
        task.wait(0.1)
        proximityPrompt.HoldDuration = originalDuration
        fruitCollectedCount = fruitCollectedCount + 1
        fruitStatusLabel.Text = string.format("Fruit Collected: %d 🍎", fruitCollectedCount)
    end)
    task.wait(0.5)
    isCollecting = false
end

local function scanForFruits()
    if not autoCollectFruitEnabled then return end
    local weatherVisuals = workspace:FindFirstChild("WeatherVisuals")
    if not weatherVisuals then return end
    for _, uid in pairs(weatherVisuals:GetChildren()) do
        if not autoCollectFruitEnabled then break end
        local cosmicFruit = uid:FindFirstChild("CosmicFruit")
        if cosmicFruit then
            local proximityPrompt = cosmicFruit:FindFirstChild("ProximityPrompt")
            if proximityPrompt and proximityPrompt.Enabled then
                local character = player.Character
                if character then
                    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                    if humanoidRootPart and cosmicFruit:FindFirstChild("Part") then
                        local distance = (humanoidRootPart.Position - cosmicFruit.Part.Position).Magnitude
                        if distance <= proximityPrompt.MaxActivationDistance then
                            collectFruit(proximityPrompt)
                        end
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while task.wait(0.5) do
        if autoCollectFruitEnabled then
            pcall(scanForFruits)
        end
    end
end)

-- Find Best Pets — SKIP PlayerPens saat scan DAN saat teleport
local function findBestPets()
    local bestPet = nil
    local highestStrength = -math.huge
    local totalScanned = 0

    local function scanInstance(parent)
        for _, obj in pairs(parent:GetChildren()) do
            -- Skip PlayerPens sepenuhnya
            if obj.Name == "PlayerPens" then continue end

            local strength = obj:GetAttribute("Strength")
            if strength ~= nil then
                -- Pastikan obj bukan bagian dari PlayerPens
                local isInPlayerPens = false
                local ancestor = obj.Parent
                while ancestor and ancestor ~= workspace do
                    if ancestor.Name == "PlayerPens" then
                        isInPlayerPens = true
                        break
                    end
                    ancestor = ancestor.Parent
                end

                -- Skip jika ada attribute OwnerId
                local ownerId = obj:GetAttribute("OwnerId")
                if not isInPlayerPens and ownerId == nil then
                    totalScanned = totalScanned + 1
                    if strength > highestStrength then
                        highestStrength = strength
                        bestPet = obj
                    end
                end
            end

            if #obj:GetChildren() > 0 then
                scanInstance(obj)
            end
        end
    end

    scanInstance(workspace)

    if bestPet then
        local petName = bestPet.Name or "Unknown"

        -- Pastikan target teleport bukan di dalam PlayerPens
        local isInPlayerPens = false
        local ancestor = bestPet.Parent
        while ancestor and ancestor ~= workspace do
            if ancestor.Name == "PlayerPens" then
                isInPlayerPens = true
                break
            end
            ancestor = ancestor.Parent
        end

        if isInPlayerPens then
            showNotification("❌ Best pet ada di PlayerPens, skip teleport!", 3)
            return
        end

        -- Skip jika punya OwnerId
        if bestPet:GetAttribute("OwnerId") ~= nil then
            showNotification("❌ Best pet punya OwnerId, skip teleport!", 3)
            return
        end

        local character = player.Character
        if character then
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            local targetPart = (bestPet:IsA("Model") and (bestPet.PrimaryPart or bestPet:FindFirstChild("HumanoidRootPart")))
                               or (bestPet:IsA("BasePart") and bestPet)
                               or nil

            if humanoidRootPart and targetPart then
                humanoidRootPart.CFrame = targetPart.CFrame * CFrame.new(0, 0, 5)
                showNotification(string.format(
                    "🔍 Best Pet Found! (scanned %d)\n💪 Strength: %d\n📌 %s\n✓ Teleported!",
                    totalScanned, highestStrength, petName
                ), 5)
            else
                showNotification(string.format(
                    "🔍 Best Pet Found! (scanned %d)\n💪 Strength: %d\n📌 %s\n❌ No part to teleport",
                    totalScanned, highestStrength, petName
                ), 4)
            end
        end
    else
        showNotification(string.format("❌ No Strength attribute found!\n(Scanned %d objects)", totalScanned), 3)
    end
end

-- Auto Mount Pet
local function autoMountPet()
    task.wait(1.5)
    local success, result = pcall(function()
        local walkingPets = workspace:FindFirstChild("WalkingPets")
        if walkingPets then
            for _, pet in pairs(walkingPets:GetChildren()) do
                if pet:IsA("Model") then
                    local owner = pet:GetAttribute("Owner")
                    local ownerValue = pet:FindFirstChild("Owner")
                    local isMyPet = false
                    if owner == player.UserId or owner == player.Name then
                        isMyPet = true
                    elseif ownerValue and ownerValue.Value then
                        if ownerValue.Value == player.UserId or ownerValue.Value == player.Name or ownerValue.Value == player then
                            isMyPet = true
                        end
                    end
                    if isMyPet then
                        return pet.Name
                    end
                end
            end
        end
        local playerPens = workspace:FindFirstChild("PlayerPens")
        if playerPens then
            local myPen = playerPens:FindFirstChild(tostring(player.UserId)) or playerPens:FindFirstChild(player.Name)
            if myPen then
                local petsFolder = myPen:FindFirstChild("Pets")
                if petsFolder then
                    local pets = petsFolder:GetChildren()
                    if #pets > 0 then
                        local lastPet = pets[#pets]
                        if lastPet and lastPet:IsA("Model") then
                            local guid = lastPet.Name
                            local requestWalkPet = ReplicatedStorage:FindFirstChild("Remotes")
                            if requestWalkPet then
                                requestWalkPet = requestWalkPet:FindFirstChild("RequestWalkPet")
                                if requestWalkPet then
                                    requestWalkPet:FireServer(guid, true)
                                    task.wait(0.8)
                                    return guid
                                end
                            end
                        end
                    end
                end
            end
        end
        return nil
    end)

    if success and result then
        task.wait(0.5)
        local mountSuccess, mountResult = pcall(function()
            return requestMountRemote:InvokeServer(result)
        end)
        if mountSuccess and mountResult then
            showNotification("✓ Pet mounted!\n🐎 Riding active!", 3)
        else
            task.spawn(function()
                task.wait(0.3)
                local placeInPen = playerGui:FindFirstChild("PlaceInPen")
                if placeInPen then
                    local holder = placeInPen:FindFirstChild("Holder")
                    if holder then
                        local rideButton = holder:FindFirstChild("RideButton")
                        if rideButton then
                            local button = rideButton:FindFirstChild("Button")
                            if button and button.Visible then
                                for _, conn in pairs(getconnections(button.Activated)) do
                                    conn:Fire()
                                end
                                showNotification("✓ Ride button clicked!", 2)
                            end
                        end
                    end
                end
            end)
        end
    else
        warn("[Auto Mount] No pet found")
    end
end

-- Auto Complete
local function autoCompleteMinigame()
    if isProcessing then return end
    if not autoCompleteEnabled then return end
    local minigameGui = getCurrentMinigame()
    if not minigameGui then return end
    isProcessing = true
    progressLabel.Text = "⚡ Fast locking..."
    phaseLabel.Text = "⚡ FAST MODE ACTIVE"
    task.spawn(function()
        local currentProgress = 0
        for i = 1, 3 do
            if not getCurrentMinigame() or not autoCompleteEnabled then
                isProcessing = false; return
            end
            currentProgress = SAFE_ZONE_TARGET
            progressLabel.Text = string.format("⚡ Locking: %d%%", currentProgress)
            pcall(function() updateProgressRemote:FireServer(currentProgress) end)
            task.wait(0.05)
        end
        phaseLabel.Text = "✓ LOCKED! Completing..."
        progressLabel.Text = string.format("Safe Zone: %d%% ✓", currentProgress)
        for i = 1, 3 do
            if not getCurrentMinigame() then break end
            pcall(function() updateProgressRemote:FireServer(currentProgress) end)
            task.wait(0.08)
        end
        task.wait(0.2)
        while currentProgress < COMPLETION_TARGET and getCurrentMinigame() and autoCompleteEnabled do
            local increment = math.random(2, 8)
            currentProgress = math.min(currentProgress + increment, COMPLETION_TARGET)
            progressLabel.Text = string.format("⚡ Completing: %d%%", currentProgress)
            pcall(function() updateProgressRemote:FireServer(currentProgress) end)
            if currentProgress >= COMPLETION_TARGET then
                progressLabel.Text = "100% ✓ DONE!"
                phaseLabel.Text = "✅ COMPLETED!"
                for i = 1, 3 do
                    if not getCurrentMinigame() then break end
                    pcall(function() updateProgressRemote:FireServer(100) end)
                    task.wait(0.05)
                end
                showNotification("✓ Minigame completed!\n✓ Auto mounting pet...", 2)
                task.spawn(autoMountPet)
                break
            end
            task.wait(0.04)
        end
        task.wait(0.5)
        isProcessing = false
        if not getCurrentMinigame() then
            progressLabel.Text = "Waiting for next minigame..."
            phaseLabel.Text = ""
        end
    end)
end

local function toggleAutoComplete()
    autoCompleteEnabled = not autoCompleteEnabled
    updateUI()
    if autoCompleteEnabled then
        showNotification("⚡ Fast Auto-Complete enabled!\n✓ Instant safe lock\n✓ Auto mount", 3)
    else
        showNotification("Auto-complete disabled.", 2)
    end
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://6895079853"
    sound.Volume = 0.5
    sound.Parent = screenGui
    sound:Play()
    task.delay(1, function() sound:Destroy() end)
end

local function toggleAutoCollectFruit()
    autoCollectFruitEnabled = not autoCollectFruitEnabled
    updateUI()
    if autoCollectFruitEnabled then
        showNotification("🍎 Auto Collect Fruit enabled!\n✓ Collecting cosmic fruits...", 3)
    else
        showNotification("🍎 Auto Collect Fruit disabled.", 2)
    end
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://6895079853"
    sound.Volume = 0.5
    sound.Parent = screenGui
    sound:Play()
    task.delay(1, function() sound:Destroy() end)
end

local function animateButton(button)
    local originalSize = button.Size
    TweenService:Create(button, TweenInfo.new(0.1), {
        Size = UDim2.new(originalSize.X.Scale * 0.95, 0, originalSize.Y.Scale * 0.95, 0)
    }):Play()
    task.wait(0.1)
    TweenService:Create(button, TweenInfo.new(0.1), {Size = originalSize}):Play()
end

-- Events
findBestPetsBtn.MouseButton1Click:Connect(function() animateButton(findBestPetsBtn); findBestPets() end)
toggleBtn.MouseButton1Click:Connect(function() animateButton(toggleBtn); toggleAutoComplete() end)
toggleFruitBtn.MouseButton1Click:Connect(function() animateButton(toggleFruitBtn); toggleAutoCollectFruit() end)
closeBtn.MouseButton1Click:Connect(function() animateButton(closeBtn); task.wait(0.1); screenGui:Destroy() end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F1 then toggleAutoComplete()
    elseif input.KeyCode == Enum.KeyCode.F2 then toggleAutoCollectFruit() end
end)

-- Hover effects
findBestPetsBtn.MouseEnter:Connect(function() TweenService:Create(findBestPetsBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(120, 170, 255)}):Play() end)
findBestPetsBtn.MouseLeave:Connect(function() TweenService:Create(findBestPetsBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 150, 255)}):Play() end)
toggleBtn.MouseEnter:Connect(function() TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = autoCompleteEnabled and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)}):Play() end)
toggleBtn.MouseLeave:Connect(function() TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = autoCompleteEnabled and Color3.fromRGB(60, 255, 60) or Color3.fromRGB(255, 60, 60)}):Play() end)
toggleFruitBtn.MouseEnter:Connect(function() TweenService:Create(toggleFruitBtn, TweenInfo.new(0.2), {BackgroundColor3 = autoCollectFruitEnabled and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(255, 160, 20)}):Play() end)
toggleFruitBtn.MouseLeave:Connect(function() TweenService:Create(toggleFruitBtn, TweenInfo.new(0.2), {BackgroundColor3 = autoCollectFruitEnabled and Color3.fromRGB(60, 200, 60) or Color3.fromRGB(255, 140, 0)}):Play() end)
closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 100, 100)}):Play() end)
closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 60, 60)}):Play() end)

playerGui.ChildAdded:Connect(function(child)
    if child.Name == "LassoMinigame" and autoCompleteEnabled then
        task.wait(0.3)
        showNotification("⚡ Minigame detected!\n⚡ FAST LOCKING...", 2)
        autoCompleteMinigame()
    end
end)

playerGui.ChildRemoved:Connect(function(child)
    if child.Name == "LassoMinigame" then
        isProcessing = false
        if autoCompleteEnabled then
            progressLabel.Text = "Waiting for next minigame..."
            phaseLabel.Text = ""
        end
    end
end)

showNotification("⚡ Fast Auto Lasso loaded!\n✓ F1=Lasso | F2=Fruit\n✓ Instant safe lock + auto mount!", 5)
