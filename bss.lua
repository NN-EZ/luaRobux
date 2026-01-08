-- Vibus UI
local UI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/NN-EZ/ui-rob/refs/heads/main/Vibus.lua",
    false
))()

-- Anti-afk:
loadstring(game:HttpGet("https://raw.githubusercontent.com/NN-EZ/luaRobux/refs/heads/main/anti-afk.lua", false))()

local function Notify(text, level)
    level = level or "INFO"
    if UI and UI.Log then
        UI.Log(level, tostring(text))
    end
end

-- ===== СОСТОЯНИЯ =====
local autoFarmEnabled = false
local autoCollectEnabled = false
local autoReturnEnabled = false
local farmFlowerZone = false
local dodgeEnabled = false
local isReturning = false
local selectedField = "Sunflower Field"
local EDGE_MARGIN = 11
local collectSpeed = 1
local fields = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17}

local questTasks = {}
local maxTasks = 20
local questRunning = false
local lastPollenValue = nil
local pendingField = "Sunflower Field"
local pendingAmount = 100000

local cloudTimer = 0
local stateUnderCloud = true

local fieldList = {
    "Sunflower Field","Mushroom Field","Dandelion Field","Blue Flower Field",
    "Clover Field","Spider Field","Bamboo Field","Strawberry Field",
    "Pineapple Patch","Stump Field","Cactus Field","Pumpkin Patch",
    "Pine Tree Forest","Rose Field","Mountain Top Field", "Pepper Patch", "Coconut Field"
}

local bearList = {
    "Black Bear","Mother Bear","Brown Bear","Panda Bear","Science Bear","Polar Bear"
}

-- ===== СЕРВИСЫ =====
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RS = game:GetService("ReplicatedStorage")
local Events = RS:WaitForChild("Events")
local ToolCollect = Events:WaitForChild("ToolCollect")
local HiveCommand = Events:WaitForChild("PlayerHiveCommand")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- ===== ФУНКЦИИ ТЕЛЕПОРТА =====
local function smoothTeleport(targetCFrame)
    local char = Players.LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    local dist = (root.Position - targetCFrame.Position).Magnitude
    local info = TweenInfo.new(dist/120, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(root, info, {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait()
end

-- ===== ОСНОВНАЯ ВКЛАДКА (ВСЕ В ОДНОЙ) =====
local MainTab = UI.CreateTab("AutoMatic Tab", "⚙️")
local botTab = UI.CreateTab("Bot Tab", "⚙️")
local tpTab = UI.CreateTab("Teleport Tab", "⚙️")
local questTab = UI.CreateTab("Quest Tab", "⚙️")

-- ===== СЕКЦИЯ: AUTO FUNCTIONS =====
UI.AddHeader(MainTab.Page, "🔧 Auto Functions")

UI.AddToggle(MainTab.Page, "Auto Dig", false, function(v)
    autoFarmEnabled = v
    Notify("Auto Dig: " .. (v and "ON" or "OFF"), "INFO")
end)

UI.AddToggle(MainTab.Page, "Auto Return", false, function(v)
    autoReturnEnabled = v
    Notify("Auto Return: " .. (v and "ON" or "OFF"), "INFO")
end)

UI.AddToggle(MainTab.Page, "Auto Collect", false, function(v)
    autoCollectEnabled = v
    Notify("Auto Collect: " .. (v and "ON" or "OFF"), "INFO")
end)

UI.AddToggle(MainTab.Page, "Dodge Hazards", false, function(v)
    dodgeEnabled = v
    Notify("Dodge Hazards: " .. (v and "ON" or "OFF"), "INFO")
end)

UI.AddToggle(MainTab.Page, "Bot Enable & Zone Protect", false, function(v)
    farmFlowerZone = v
    Notify("Zone Protect: " .. (v and "ON" or "OFF"), "INFO")
end)

-- ===== СЕКЦИЯ: BOT SETTINGS =====
UI.AddHeader(botTab.Page, "🎯 Bot Settings")

UI.AddDropdown(botTab.Page, "Select Field", fieldList, selectedField, function(v)
    selectedField = v
    Notify("Field changed: " .. v, "INFO")
end)

UI.AddSlider(botTab.Page, "Collect Speed", 0.01, 2, 1, function(v)
    collectSpeed = v
end)

-- ===== СЕКЦИЯ: TELEPORT =====
UI.AddHeader(tpTab.Page, "📍 Teleport to Field")

UI.AddDropdown(tpTab.Page, "Select Field for TP", fieldList, fieldList[1], function(v)
    local zone = Workspace.FlowerZones:FindFirstChild(v)
    if zone then
        smoothTeleport(CFrame.new(zone.Position + Vector3.new(0, 5, 0)))
        Notify("Teleported to: " .. v, "INFO")
    else
        Notify("Field not found!", "WARN")
    end
end)

UI.AddHeader(tpTab.Page, "🐻 Teleport to Bear")

UI.AddDropdown(tpTab.Page, "Select Bear for TP", bearList, bearList[1], function(v)
    local bear = Workspace.NPCs:FindFirstChild(v)
    if bear and bear:FindFirstChild("Circle") then
        local circlePos = bear.Circle.Position + Vector3.new(0, 5, 0)
        smoothTeleport(CFrame.new(circlePos, circlePos + Vector3.new(0,0,-10)))
        Notify("Teleported to: " .. v, "INFO")
    else
        Notify("Bear not found!", "WARN")
    end
end)

-- ===== СЕКЦИЯ: QUEST MANAGER =====
UI.AddHeader(questTab.Page, "📋 Quest Manager")

UI.AddDropdown(questTab.Page, "Quest Field", fieldList, pendingField, function(v)
    pendingField = v
end)

UI.AddSlider(questTab.Page, "Pollen Amount (x1000)", 1, 10000, 100, function(v)
    pendingAmount = math.floor(v) * 1000
end)

UI.AddButton(questTab.Page, "Add Quest", function()
    if #questTasks < maxTasks then
        table.insert(questTasks, {field = pendingField, target = pendingAmount, progress = 0})
        Notify(("Quest added: %s / %d"):format(pendingField, pendingAmount), "INFO")
    else
        Notify("Quest list is full!", "WARN")
    end
end)

UI.AddButton(questTab.Page, "Clear All Quests", function()
    table.clear(questTasks)
    Notify("All quests cleared", "INFO")
end)

UI.AddToggle(questTab.Page, "Auto Farm (Quests)", false, function(v)
    questRunning = v
    if v then
        farmFlowerZone = true
        autoFarmEnabled = true
        Notify("Quest farming started!", "INFO")
    else
        Notify("Quest farming stopped", "INFO")
    end
end)

-- ===== ОСНОВНЫЕ ЦИКЛЫ =====

-- Zone Protection (защита от выхода из зоны)
spawn(function()
    while true do
        if farmFlowerZone and not isReturning then
            local char = Players.LocalPlayer.Character
            local zone = Workspace.FlowerZones:FindFirstChild(selectedField)
            if char and zone then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    local rootPos, zonePos, zoneSize = root.Position, zone.Position, zone.Size
                    local halfX, halfZ = zoneSize.X / 2, zoneSize.Z / 2
                    local dx, dz = rootPos.X - zonePos.X, rootPos.Z - zonePos.Z

                    if math.abs(dx) > (halfX - EDGE_MARGIN) or math.abs(dz) > (halfZ - EDGE_MARGIN) then
                        smoothTeleport(CFrame.new(zonePos.X, zonePos.Y + 5, zonePos.Z))
                    end
                end
            end
        end
        task.wait(0.3)
    end
end)

-- Dodge Hazards
spawn(function()
    while true do
        if dodgeEnabled and not isReturning then
            local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                for _, disk in pairs(Workspace.Particles:GetChildren()) do
                    if (disk.Name == "WarningDisk" or disk.Name == "Thorn") and disk:IsA("BasePart") then
                        if (root.Position - disk.Position).Magnitude < 7 then
                            local char = Players.LocalPlayer.Character
                            if char and char:FindFirstChild("Humanoid") then
                                local targetPos = root.Position + ((root.Position - disk.Position).Unit * 7)
                                char.Humanoid:MoveTo(targetPos)
                            end
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
        task.wait(0.05)
    end
end)

-- Auto Return (возврат домой при полной сумке)
spawn(function()
    while true do
        if autoReturnEnabled then
            local stats = Players.LocalPlayer:FindFirstChild("CoreStats")
            if stats and stats.Pollen.Value >= stats.Capacity.Value and not isReturning then
                isReturning = true
                local char = Players.LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local farmPos = char.HumanoidRootPart.CFrame
                    local spawnPosV = Players.LocalPlayer.SpawnPos.Value
                    local spawnPos = (typeof(spawnPosV) == "CFrame" and spawnPosV.Position or spawnPosV)

                    local function ensure() 
                        local r = char:FindFirstChild("HumanoidRootPart")
                        return r and (r.Position - spawnPos).Magnitude < 8 
                    end

                    repeat smoothTeleport(CFrame.new(spawnPos + Vector3.new(0,5,0))) task.wait(1) until ensure()

                    task.wait(1.5)
                    while stats.Pollen.Value > 0 and autoReturnEnabled do
                        if char:FindFirstChild("Humanoid") then char.Humanoid.Jump = true end
                        task.wait(0.7)
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        local startP = stats.Pollen.Value
                        for _=1,10 do task.wait(1) if stats.Pollen.Value < startP then repeat task.wait(1) until stats.Pollen.Value <= 0 or not autoReturnEnabled break end end
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    end
                    smoothTeleport(farmPos)
                end
                isReturning = false
            end
        end
        task.wait(2)
    end
end)

-- Auto Dig
spawn(function()
    while true do
        if autoFarmEnabled and not isReturning then  -- ← ДОБАВЬ ЭТО
            for _, id in pairs(fields) do 
                pcall(function() ToolCollect:FireServer(id) end) 
                task.wait(0.05) 
            end
        end
        task.wait(0.1)
    end
end)


-- Auto Collect (ускоренный цикл сбора)
spawn(function()
    local lastTarget = nil
    local touchThreshold = 1  
    
    while true do
        if autoCollectEnabled and not isReturning then
            local char = Players.LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local zone = farmFlowerZone and Workspace.FlowerZones:FindFirstChild(selectedField) or nil
            
            if root then
                -- РЕЖИМ СБОРА (всегда)
                local target, minDist = nil, 40
                local now = tick()

                local function isSafe(pos)
                    if not zone then return true end
                    local dx, dz = pos.X - zone.Position.X, pos.Z - zone.Position.Z
                    return math.abs(dx) < (zone.Size.X/2 - EDGE_MARGIN) and math.abs(dz) < (zone.Size.Z/2 - EDGE_MARGIN)
                end

                -- Облако
                local cloudsFolder = Workspace:FindFirstChild("Clouds")
                local cloudInstance = cloudsFolder and cloudsFolder:FindFirstChild("CloudInstance")
                local cloudPlane = cloudInstance and cloudInstance:FindFirstChild("Plane")
                local hasCloud = cloudPlane and cloudPlane:IsA("BasePart")

                if hasCloud then
                    if now - cloudTimer >= 7 then
                        stateUnderCloud = not stateUnderCloud
                        cloudTimer = now
                    end
                else
                    stateUnderCloud = false
                end

                if stateUnderCloud and hasCloud and isSafe(cloudPlane.Position) then
                    target = Vector3.new(cloudPlane.Position.X, root.Position.Y, cloudPlane.Position.Z)
                    minDist = 0
                end

                -- Collectibles
                if not target then
                    local collectibles = Workspace:FindFirstChild("Collectibles")
                    if collectibles then
                        for _, obj in pairs(collectibles:GetChildren()) do
                            if obj:IsA("BasePart") and obj.Transparency < 1 and isSafe(obj.Position) then
                                local d = (obj.Position - root.Position).Magnitude
                                if d < minDist then 
                                    minDist = d
                                    target = obj.Position
                                end
                            end
                        end
                    end
                end

                -- Goo
                if not target then
                    local gooFolder = Workspace:FindFirstChild("Goo")
                    if gooFolder then
                        for _, obj in pairs(gooFolder:GetChildren()) do
                            if obj:IsA("BasePart") and isSafe(obj.Position) then
                                local gooDist = (obj.Position - root.Position).Magnitude
                                if gooDist < minDist then
                                    minDist = gooDist
                                    target = obj.Position
                                end
                            end
                        end
                    end
                end

                -- Bubbles
                if not target then
                    local particles = Workspace:FindFirstChild("Particles")
                    if particles then
                        for _, obj in pairs(particles:GetChildren()) do
                            if obj.Name == "Bubble" and obj:IsA("BasePart") and isSafe(obj.Position) then
                                local d = (obj.Position - root.Position).Magnitude
                                if d < minDist then 
                                    minDist = d
                                    target = obj.Position
                                end
                            end
                        end
                    end
                end

                -- Crosshairs
                if not target then
                    local particles = Workspace:FindFirstChild("Particles")
                    if particles then
                        for _, obj in pairs(particles:GetChildren()) do
                            if obj.Name == "Crosshair" and obj:IsA("BasePart") and isSafe(obj.Position) then
                                local d = (obj.Position - root.Position).Magnitude
                                if d < minDist then 
                                    minDist = d
                                    target = obj.Position
                                end
                            end
                        end
                    end
                end
                
                -- Если нашли позицию - идём туда
                if target then
                    if not lastTarget or (target - lastTarget).Magnitude > 1 then
                        lastTarget = target
                        if char:FindFirstChild("Humanoid") then
                            char.Humanoid:MoveTo(target)
                        end
                    elseif (root.Position - target).Magnitude < touchThreshold then
                        lastTarget = nil
                    end
                else
                    -- Fallback: если ничего нет, ждём
                    if lastTarget and char:FindFirstChild("Humanoid") then
                        char.Humanoid:MoveTo(lastTarget)
                    end
                end
            end
        end
        task.wait(0.01)
    end
end)

-- Quest Manager
local function startQuestFarm()
    spawn(function()
        local stats = Players.LocalPlayer:WaitForChild("CoreStats")
        lastPollenValue = stats.Pollen.Value
        while questRunning do
            if #questTasks > 0 then
                local taskData = questTasks[1]
                selectedField = taskData.field
                local cp = stats.Pollen.Value
                if lastPollenValue then
                    taskData.progress = math.min(taskData.progress + math.max(cp - lastPollenValue, 0), taskData.target)
                end
                lastPollenValue = cp
                if taskData.progress >= taskData.target then 
                    table.remove(questTasks, 1)
                    Notify("Quest completed!", "INFO")
                end
            else
                questRunning = false
            end
            task.wait(1)
        end
    end)
end

Notify("BSS Hub loaded!", "INFO")
MainTab.Select()
