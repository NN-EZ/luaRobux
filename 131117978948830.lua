--==== СЕРВИСЫ ====
local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local VirtualInputManager= game:GetService("VirtualInputManager")
local Debris             = game:GetService("Debris")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local RS = game:GetService("ReplicatedStorage")
local SetDeadRemote = RS:FindFirstChild("SetDead")
local KilledRemote   = RS:FindFirstChild("Killed")

local isRemoteEvent   = SetDeadRemote and SetDeadRemote:IsA("RemoteEvent")
local isRemoteFunction = SetDeadRemote and SetDeadRemote:IsA("RemoteFunction")

local LP     = Players.LocalPlayer
local Mouse  = LP:GetMouse()
local Camera = workspace.CurrentCamera

--==== UI LIB ====
local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/NN-EZ/ui-rob/refs/heads/main/Vibus.lua", false))()

--==== НАСТРОЙКИ ====
local aimRange           = 500
local wallcheckEnabled   = true
local autoShootEnabled   = false
local autoJumpEnabled    = false
local alwaysAimEnabled   = false
local LookOnShootEnabled = false
local visualAimEnabled   = false
local neonGunEnabled     = false
local aimMode            = "Body"
local reloadTime         = 0.5
local showTrajectory     = false
local predictionPing     = 0.08
local smoothingFactor    = 0.7
local espEnabled         = false
local cameraAssistEnabled = false
local cameraSmooth        = 0.15
local nightmodeEnabled = false
local nightmodeCache = {}   -- [Instance] = {Color = ..., Material = ..., Transparency = ...}
local antiAimToggleKey    = Enum.KeyCode.Q

local visualLocalBeamEnabled = false
local alwaysKillEnabled = true
local beamVisualDuration = 2
--- night/day
local Lighting = game:GetService("Lighting")

local timeMode = "Default"

local originalLighting = nil   -- сюда сохраним исходные значения
local originalSky = nil
local customSky = nil          -- текущий кастомный Sky

-- Galaxy Night
local galaxySkyIds = {
    Bk = "rbxassetid://10258334768",
    Dn = "rbxassetid://10258334768",
    Ft = "rbxassetid://10258334768",
    Lf = "rbxassetid://10258334768",
    Rt = "rbxassetid://10258334768",
    Up = "rbxassetid://10258334768",
}

--- over
local AntiAim = {
    Enabled        = false,
    Smooth         = 0.18,
    JitterEnabled  = true,
    JitterAngleDeg = 130,
    JitterSpeed    = 280,
}

local function GetCurrentTool()
    local char = LP.Character
    if char then
        for _, obj in pairs(char:GetChildren()) do
            if obj:IsA("Tool") then
                if obj:FindFirstChild("fire") or (obj:FindFirstChild("GunServer") and obj.GunServer:FindFirstChild("ShootStart")) then
                    return obj
                end
            end
        end
    end
    
    for _, obj in pairs(LP.Backpack:GetChildren()) do
        if obj:IsA("Tool") then
            if obj:FindFirstChild("fire") or (obj:FindFirstChild("GunServer") and obj.GunServer:FindFirstChild("ShootStart")) then
                return obj
            end
        end
    end
    
    return nil
end


local function GetToolEvents(tool)
    if not tool then return nil, nil, nil, nil end
    
    local fire = tool:FindFirstChild("fire")
    local showBeam = tool:FindFirstChild("showBeam")
    local kill = tool:FindFirstChild("kill")
    
    -- ShootStart часто лежит внутри папки GunServer
    local shootStart = tool:FindFirstChild("ShootStart")
    if not shootStart and tool:FindFirstChild("GunServer") then
        shootStart = tool.GunServer:FindFirstChild("ShootStart")
    end
    
    return fire, showBeam, kill, shootStart
end

local enemyCache = {}        -- Таблица: [Игрок] = {isEnemy: bool, lastCheck: number}
local CACHE_LIFETIME = 3     -- Время жизни кэша в секундах
local lastFullResetTime = tick()
--==== nightMODe ====
local function SaveOriginalLighting()
    if originalLighting then return end  -- уже сохранено

    originalLighting = {
        ClockTime = Lighting.ClockTime,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness,
        FogColor = Lighting.FogColor,
        FogStart = Lighting.FogStart,
        FogEnd = Lighting.FogEnd
    }

    originalSky = Lighting:FindFirstChildOfClass("Sky")  -- может быть nil [web:133]
end

local function ApplyDefault()
    if not originalLighting then return end

    Lighting.ClockTime      = originalLighting.ClockTime
    Lighting.Ambient        = originalLighting.Ambient
    Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
    Lighting.Brightness     = originalLighting.Brightness
    Lighting.FogColor       = originalLighting.FogColor
    Lighting.FogStart       = originalLighting.FogStart
    Lighting.FogEnd         = originalLighting.FogEnd

    -- возвращаем оригинальный sky
    if customSky then
        customSky:Destroy()
        customSky = nil
    end
    if originalSky and not originalSky.Parent then
        originalSky.Parent = Lighting
    end
end

local function ApplyDay()
    SaveOriginalLighting()

    Lighting.ClockTime      = 14        -- день
    Lighting.FogStart       = 200
    Lighting.FogEnd         = 2000

    -- для day можно оставить оригинальный sky
    if customSky then
        customSky:Destroy()
        customSky = nil
    end
    if originalSky and not originalSky.Parent then
        originalSky.Parent = Lighting
    end
end

local function ApplyNight()
    SaveOriginalLighting()

    Lighting.ClockTime      = 0         -- ночь
    Lighting.FogStart       = 100
    Lighting.FogEnd         = 1200

    -- тёмный обычный sky (оставляем дефолт / оригинальный)
    if customSky then
        customSky:Destroy()
        customSky = nil
    end
    if originalSky and not originalSky.Parent then
        originalSky.Parent = Lighting
    end
end

local function ApplyCustomNightSky()
    SaveOriginalLighting()

    Lighting.ClockTime      = 0
    Lighting.FogStart       = 50
    Lighting.FogEnd         = 1000

    -- убираем оригинальный Sky и создаём свой
    if originalSky then
        originalSky.Parent = nil
    end
    if customSky then
        customSky:Destroy()
    end

    customSky = Instance.new("Sky")
    customSky.Name = "CustomNightSky"
    -- сюда вставь свои айди скайбокса
    customSky.SkyboxBk = ids.Bk
    customSky.SkyboxDn = ids.Dn
    customSky.SkyboxFt = ids.Ft
    customSky.SkyboxLf = ids.Lf
    customSky.SkyboxRt = ids.Rt
    customSky.SkyboxUp = ids.Up
    customSky.StarCount = 3000
    customSky.Parent = Lighting  -- локальный skybox для этого клиента [web:133][web:137]
end

local function SetTimeMode(mode)
    timeMode = mode

    if mode == "Default" then
        ApplyDefault()
    elseif mode == "Day" then
        ApplyDay()
    elseif mode == "Night" then
        ApplyNight()
    elseif mode == "Custom Night" then
        ApplyCustomNightSky()
    end
end

local function IsCharacterDescendant(inst)
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char and inst:IsDescendantOf(char) then
            return true
        end
    end
    return false
end
local function EnableNightmode()
    if nightmodeEnabled then return end
    nightmodeEnabled = true

    local all = workspace:GetDescendants()
    local batchSize = 200  -- сколько объектов обрабатываем за один тик

    for i, inst in ipairs(all) do
        if inst:IsA("BasePart") and not IsCharacterDescendant(inst) then
            -- кэшируем, только если ещё не кэшировали
            if not nightmodeCache[inst] then
                nightmodeCache[inst] = {
                    Color = inst.Color,
                    Material = inst.Material,
                    Transparency = inst.Transparency,
                }
            end

            inst.Color = Color3.fromRGB(80, 80, 80)
            inst.Material = Enum.Material.SmoothPlastic
            -- можно чуть притемнить
            -- inst.Transparency = math.clamp(inst.Transparency + 0.1, 0, 1)
        end

        if i % batchSize == 0 then
            task.wait()  -- уступаем кадр, чтобы не было фриза [web:43][web:56]
        end
    end
end

local function DisableNightmode()
    if not nightmodeEnabled then return end
    nightmodeEnabled = false

    local batchSize = 200

    local i = 0
    for inst, props in pairs(nightmodeCache) do
        if inst and inst.Parent then
            inst.Color = props.Color
            inst.Material = props.Material
            inst.Transparency = props.Transparency
        end

        i += 1
        if i % batchSize == 0 then
            task.wait()
        end
    end

    nightmodeCache = {}  -- очищаем кэш
end

local function ToggleNightmode(state)
    if state == nil then
        state = not nightmodeEnabled
    end

    if state then
        EnableNightmode()
    else
        DisableNightmode()
    end
end

--==== ВИЗУАЛИЗАЦИЯ ЛУЧА ====
local localBeamEvent = ReplicatedStorage:FindFirstChild("LocalBeam")

local function DrawLocalBeam(startPos, endPos, toolHandle)
    if not visualLocalBeamEnabled then return end
    
    local beamPart = Instance.new("Part")
    beamPart.Name = "VisualBeam"
    beamPart.Shape = Enum.PartType.Ball
    beamPart.Size = Vector3.new(0.3, 0.3, 0.3)
    beamPart.Position = endPos
    beamPart.Anchored = true
    beamPart.CanCollide = false
    beamPart.Transparency = 0.3
    beamPart.Color = Color3.fromRGB(255, 100, 0)
    beamPart.Material = Enum.Material.Neon
    beamPart.Parent = workspace
    
    Debris:AddItem(beamPart, beamVisualDuration)
    
    if toolHandle and localBeamEvent then
        localBeamEvent:Fire(toolHandle, endPos)
    end
end

--==== СИСТЕМА ====
local lastAutoRotate   = true
local lastScanTime     = 0
local scanCooldown     = 0.1
local cachedTarget     = nil
local lastShotTime     = 0
local shootDelay       = 0.1
local lastCameraCFrame = CFrame.new()
local recoilActive     = false
local recoilEndTime    = 0

local visParams = RaycastParams.new()
visParams.FilterType = Enum.RaycastFilterType.Blacklist
visParams.IgnoreWater = true

local TargetData = {}
local ShootStart = nil
local ignoreVisibilityEnabled = false
--==== ФУНКЦИИ ====
local function IsEnemy(plr)
    if plr == LP then return false end
    
    local now = tick()
    local cacheEntry = enemyCache[plr]
    
    -- Если есть свежий кэш, возвращаем сохраненное значение
    if cacheEntry and (now - cacheEntry.lastCheck < CACHE_LIFETIME) then
        return cacheEntry.isEnemy
    end

    -- ==== ЛОГИКА ПРОВЕРКИ (ТЯЖЕЛАЯ ЧАСТЬ) ====
    local isEnemyResult = false
    local char = plr.Character
    
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            -- 1. Проверка через Атрибуты (Game/Team)
            local myGame = LP:GetAttribute("Game")
            local theirGame = plr:GetAttribute("Game")
            
            if myGame and theirGame then
                if myGame ~= theirGame then
                    isEnemyResult = false -- Разные игры -> не враг (игнор)
                else
                    local myTeam = LP:GetAttribute("Team")
                    local theirTeam = plr:GetAttribute("Team")
                    -- Одна игра, разные команды -> ВРАГ
                    isEnemyResult = (myTeam ~= theirTeam)
                end
            else
                -- 2. Стандартная проверка (Team Color / Name)
                if plr.Team and LP.Team then
                    if plr.Team == LP.Team then
                        isEnemyResult = false
                    elseif plr.Team.Name == "Lobby" then
                        isEnemyResult = false
                    else
                        isEnemyResult = true
                    end
                else
                    -- FFA (каждый сам за себя, если нет команд)
                    isEnemyResult = true
                end
            end
        end
    else
        isEnemyResult = false -- Нет персонажа -> не враг
    end

    -- Сохраняем результат в кэш
    enemyCache[plr] = {
        isEnemy = isEnemyResult,
        lastCheck = now
    }
    
    return isEnemyResult
end

--==== BACKTRACK SYSTEM ====
local backtrackData = {}
local backtrackVisuals = {}
local BACKTRACK_RANGE2 = 250000  -- 500^2
local BACKTRACK_DURATION = 7.4
local MAX_BACKTRACK_POSITIONS = 32
local MOVEMENT_THRESHOLD = 0.5

local function GetBacktrackCFrame(player)
    local d = backtrackData[player]
    local data = d and d.positions
    if not data or #data < 2 then return nil end

    local targetTime = tick() - BACKTRACK_DURATION

    for i = 1, #data - 1 do
        local newer  = data[i]
        local older  = data[i + 1] 

        if newer.time >= targetTime and older.time <= targetTime then
            local span = newer.time - older.time
            if span <= 0 then
                return newer.cframe
            end

            local alpha = (targetTime - older.time) / span
            return older.cframe:Lerp(newer.cframe, alpha)
        end
    end

    return data[#data].cframe
end

local function IsPlayerMoving(player)
    local data = backtrackData[player]
    if not data or not data.positions or #data.positions < 2 then return false end

    local p1, p2 = data.positions[1], data.positions[2]
    local dt = p1.time - p2.time
    if dt <= 0.001 then return false end
    return (p1.pos - p2.pos).Magnitude / dt > MOVEMENT_THRESHOLD
end


local function ClearBacktrackVisual(player)
    local ghost = backtrackVisuals[player]
    if ghost then
        ghost:Destroy()
        backtrackVisuals[player] = nil
    end
end

local function EnsureGhost(player, startCFrame)
    local ghost = backtrackVisuals[player]
    if ghost and ghost.Parent then
        return ghost
    end

    ghost = Instance.new("Part")
    ghost.Name = "BacktrackGhost_" .. player.Name
    ghost.Size = Vector3.new(2, 5, 1.2)
    ghost.Anchored = true
    ghost.CanCollide = false
    ghost.CanQuery = false
    ghost.CanTouch = false
    ghost.Material = Enum.Material.ForceField
    ghost.Color = Color3.fromRGB(255, 255, 255)
    ghost.Transparency = 0.4
    ghost.CFrame = startCFrame
    ghost.Parent = workspace

    backtrackVisuals[player] = ghost
    return ghost
end

local function CreateBacktrackVisual(player, hrpCFrame)
    -- Очищаем старый ВСЕГДА
    ClearBacktrackVisual(player)
    
    local ghost = Instance.new("Part")
    ghost.Name = "BacktrackGhost_" .. player.Name
    ghost.Size = Vector3.new(2, 5, 1.2)
    ghost.CFrame = hrpCFrame
    ghost.Anchored = true
    ghost.CanCollide = false
    ghost.CanQuery = false
    ghost.CanTouch = false
    ghost.Material = Enum.Material.ForceField
    ghost.Color = Color3.fromRGB(255, 255, 255)
    ghost.Transparency = 0.3
    ghost.Parent = workspace
    
    backtrackVisuals[player] = {parts = {ghost}}
    
    -- УДАЛЯЕМ через 0.4 сек
    task.delay(BACKTRACK_DURATION, function()
        ClearBacktrackVisual(player)
    end)
end

local function UpdateBacktrack()
    local myChar = LP.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    local myPos = myHRP.Position
    local now = tick()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP and IsEnemy(player) then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")

            if hrp then
                local delta = hrp.Position - myPos
                local dist2 = delta:Dot(delta)

                -- Вне радиуса 500: чистим всё
                if dist2 > BACKTRACK_RANGE2 then
                    backtrackData[player] = nil
                    ClearBacktrackVisual(player)
                else
                    -- 1) обновляем историю
                    local data = backtrackData[player]
                    if not data then
                        data = {positions = {}}
                        backtrackData[player] = data
                    end

                    table.insert(data.positions, 1, {
                        pos = hrp.Position,
                        cframe = hrp.CFrame,
                        time = now
                    })
                    while #data.positions > MAX_BACKTRACK_POSITIONS do
                        table.remove(data.positions)
                    end

                    -- 2) получаем позицию 0.4 секунды назад
                    local btCFrame = GetBacktrackCFrame(player)

                    if btCFrame and IsPlayerMoving(player) then
                        -- создаём/берём ghost и плавно тянем к btCFrame
                        local ghost = EnsureGhost(player, btCFrame)
                        ghost.CFrame = ghost.CFrame:Lerp(btCFrame, 0.3)  -- сглаживание [web:76][web:83]
                        ghost.Transparency = 0.3
                    else
                        -- если стоит — убираем призрак
                        ClearBacktrackVisual(player)
                    end
                end
            else
                backtrackData[player] = nil
                ClearBacktrackVisual(player)
            end
        else
            backtrackData[player] = nil
            ClearBacktrackVisual(player)
        end
    end
end
--==== ESP BOXES ====
local espBoxes = {}
local espUpdateConnection = nil

local function CreateESPBox(player)
    if espBoxes[player] then return end
    
    local char = player.Character
    if not char then return end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Parent = char
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    
    espBoxes[player] = {
        highlight = highlight,
        char = char,
        deathConnection = nil
    }
    
    espBoxes[player].deathConnection = humanoid.Died:Connect(function()
        RemoveESPBox(player)
    end)
end

local function RemoveESPBox(player)
    if espBoxes[player] then
        if espBoxes[player].deathConnection then
            espBoxes[player].deathConnection:Disconnect()
        end
        if espBoxes[player].highlight and espBoxes[player].highlight.Parent then
            espBoxes[player].highlight:Destroy()
        end
        espBoxes[player] = nil
    end
end

local function UpdateESPBox(player)
    if not espEnabled then return end
    
    local char = player.Character
    if not char then 
        RemoveESPBox(player)
        return 
    end
    
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        RemoveESPBox(player)
        return
    end
    
    if not espBoxes[player] then
        CreateESPBox(player)
        if not espBoxes[player] then return end
    end
    
    local espData = espBoxes[player]
    if espData and espData.highlight and espData.highlight.Parent then
        local isEnemy = IsEnemy(player)
        local boxColor = isEnemy and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 100, 255)
        
        espData.highlight.OutlineColor = boxColor
        espData.highlight.OutlineTransparency = 0
        espData.highlight.FillTransparency = 1
    end
end

local function StartESPUpdate()
    if espUpdateConnection then espUpdateConnection:Disconnect() end
    
    espUpdateConnection = RunService.Heartbeat:Connect(function()
        if espEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LP then
                    UpdateESPBox(player)
                end
            end
        else
            for player, _ in pairs(espBoxes) do
                RemoveESPBox(player)
            end
        end
    end)
end

local function StopESPUpdate()
    if espUpdateConnection then
        espUpdateConnection:Disconnect()
        espUpdateConnection = nil
    end
    for player, _ in pairs(espBoxes) do
        RemoveESPBox(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        if espEnabled and player ~= LP then
            task.wait(0.1)
            CreateESPBox(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESPBox(player)
end)

--==== NEON GUN ====
local neonSpeed = 0.3
local currentNeonConnections = {}
local neonMonitorConnection = nil

local function UpdateGunMaterial()
    for _, conn in pairs(currentNeonConnections) do
        if conn then conn:Disconnect() end
    end
    currentNeonConnections = {}

    local tool = GetCurrentTool()
    if not tool then return end
    
    local handle = tool:FindFirstChild("Handle")
    if not handle then return end

    if neonGunEnabled then
        handle.Material = Enum.Material.ForceField
        handle.Transparency = 0.3

        if handle:FindFirstChild("MatrixGUI") then
            handle.MatrixGUI:Destroy()
        end
        if handle:FindFirstChild("MatrixTexture") then
            handle.MatrixTexture:Destroy()
        end

        local animConnection
        animConnection = RunService.Heartbeat:Connect(function()
            if neonGunEnabled and handle.Parent then
                handle.Color = Color3.fromHSV((tick() * neonSpeed) % 1, 1, 1)
            else
                if animConnection then animConnection:Disconnect() end
            end
        end)

        table.insert(currentNeonConnections, animConnection)
    else
        handle.Material = Enum.Material.Plastic
        handle.Transparency = 0

        if handle:FindFirstChild("MatrixGUI") then
            handle.MatrixGUI:Destroy()
        end
        if handle:FindFirstChild("MatrixTexture") then
            handle.MatrixTexture:Destroy()
        end
    end
end

local function StartNeonMonitor()
    if neonMonitorConnection then neonMonitorConnection:Disconnect() end

    neonMonitorConnection = RunService.Heartbeat:Connect(function()
        if neonGunEnabled then
            UpdateGunMaterial()
        end
    end)
end

--==== VISIBILITY ====
-- local function IsVisiblePart(part, targetChar)
--     if not wallcheckEnabled or not part or not part.Parent then return true end

--     local origin = Camera.CFrame.Position
--     local dir    = part.Position - origin

--     visParams.FilterDescendantsInstances = { LP.Character }

--     local hit = workspace:Raycast(origin, dir, visParams)
--     return (not hit) or hit.Instance:IsDescendantOf(targetChar)
-- end

local visibilityCache = {}  -- [player] = {isVisible = bool, lastCheck = number}
local VIS_CACHE_TIME = 0.2

local function IsVisiblePart(part, targetChar)
    if not wallcheckEnabled or not part then return true end
    
    local now = tick()
    local cache = visibilityCache[targetChar]
    if cache and (now - cache.lastCheck < VIS_CACHE_TIME) then
        return cache.isVisible
    end
    
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    visParams.FilterDescendantsInstances = {LP.Character}
    local hit = workspace:Raycast(origin, dir, visParams)
    
    local result = (not hit) or hit.Instance:IsDescendantOf(targetChar)
    visibilityCache[targetChar] = {isVisible = result, lastCheck = now}
    return result
end

local function IsPathClear(targetPart, predictedPos)
    if not wallcheckEnabled then return true end
    
    local myChar = LP.Character
    if not myChar then return false end
    
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end
    
    local origin = myHRP.Position
    local dir = (predictedPos - origin)
    local distance = dir.Magnitude
    
    if distance == 0 then return false end
    
    visParams.FilterDescendantsInstances = { LP.Character }
    local hit = workspace:Raycast(origin, dir.Unit * distance, visParams)
    
    if not hit then return true end
    
    local targetChar = targetPart.Parent
    if hit.Instance:IsDescendantOf(targetChar) then return true end
    
    return false
end

--==== TARGET SELECTION ====
local function GetPriorityPartIgnoreVisibility(char)
    if aimMode == "Head" then
        local parts = {"Head"}
        for _, name in ipairs(parts) do
            local part = char:FindFirstChild(name)
            if part then return part end
        end
    elseif aimMode == "Body" then
        local parts = {"UpperTorso", "Torso", "HumanoidRootPart"}
        for _, name in ipairs(parts) do
            local part = char:FindFirstChild(name)
            if part then return part end
        end
    elseif aimMode == "Any" then
        local allParts = {"Head","UpperTorso","LowerTorso","Torso","HumanoidRootPart","LeftUpperArm","RightUpperArm"}
        for _, name in ipairs(allParts) do
            local part = char:FindFirstChild(name)
            if part then return part end
        end
    end
    return nil
end

local function GetPriorityPart(char)
    if aimMode == "Head" then
        local parts = {"Head"}
        for _, name in ipairs(parts) do
            local part = char:FindFirstChild(name)
            if part and IsVisiblePart(part, char) then return part end
        end
    elseif aimMode == "Body" then
        local parts = {"UpperTorso", "Torso", "HumanoidRootPart"}
        for _, name in ipairs(parts) do
            local part = char:FindFirstChild(name)
            if part and IsVisiblePart(part, char) then return part end
        end
    elseif aimMode == "Any" then
        local allParts = {"Head","UpperTorso","LowerTorso","Torso","HumanoidRootPart","LeftUpperArm","RightUpperArm"}
        for _, name in ipairs(allParts) do
            local part = char:FindFirstChild(name)
            if part and IsVisiblePart(part, char) then return part end
        end
    end
    return nil
end

local function GetClosestEnemy()
    if tick() - lastScanTime < scanCooldown and cachedTarget then return cachedTarget end
    
    local myChar = LP.Character
    local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not hrp then cachedTarget = nil return nil end
    
    local myPos = hrp.Position
    local bestDist2 = math.huge
    local bestTarget = nil
    local aimRange2 = aimRange * aimRange  
    
    local getPart = ignoreVisibilityEnabled and GetPriorityPartIgnoreVisibility or GetPriorityPart
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if IsEnemy(plr) then
            local char = plr.Character
            if char then
                local part = getPart(char)
                if part then
                    local delta = part.Position - myPos
                    local dist2 = delta:Dot(delta)
                    if dist2 < aimRange2 and dist2 < bestDist2 then
                        bestDist2 = dist2
                        bestTarget = { player = plr, part = part, distance = math.sqrt(dist2) }
                    end
                end
            end
        end
    end
    
    cachedTarget = bestTarget
    lastScanTime = tick()
    return bestTarget
end


local function GetShootStart()
    local tool = GetCurrentTool()
    if not tool then return nil end
    
    local shootStart = tool:FindFirstChild("ShootStart")
    return shootStart
end

--==== PREDICTION ====
local function PredictPosition(targetPart)
    local char = targetPart.Parent
    if not TargetData[char] or #TargetData[char] < 5 then 
        return targetPart.Position
    end
    
    local p1 = TargetData[char][1]
    local p2 = TargetData[char][2]
    local p3 = TargetData[char][3]
    local p4 = TargetData[char][4]
    local p5 = TargetData[char][5]
    
    local timeDelta1 = p1.time - p2.time
    local timeDelta2 = p2.time - p3.time
    local timeDelta3 = p3.time - p4.time
    
    if timeDelta1 <= 0.001 or timeDelta2 <= 0.001 or timeDelta3 <= 0.001 then
        return targetPart.Position
    end
    
    local vel1 = (p1.pos - p2.pos) / timeDelta1
    local vel2 = (p2.pos - p3.pos) / timeDelta2
    local vel3 = (p3.pos - p4.pos) / timeDelta3
    local currentVelocity = (vel1 * 0.5 + vel2 * 0.3 + vel3 * 0.2)
    
    local basePart = targetPart
    if aimMode == "Head" then 
        basePart = char:FindFirstChild("Head") or targetPart
    elseif aimMode == "Body" then 
        basePart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or targetPart
    end
    
    local basePos = basePart.Position
    local speed = currentVelocity.Magnitude
    
    local isStanding = false
    local standingThreshold = 0.5
    
    local recentSpeeds = {}
    for i = 1, math.min(7, #TargetData[char]) do
        local prev = TargetData[char][i+1]
        if prev then
            local deltaTime = TargetData[char][i].time - prev.time
            if deltaTime > 0.001 then
                local recentSpeed = (TargetData[char][i].pos - prev.pos).Magnitude / deltaTime
                table.insert(recentSpeeds, recentSpeed)
            end
        end
    end
    
    local standingCount = 0
    for _, recentSpeed in ipairs(recentSpeeds) do
        if recentSpeed < standingThreshold then
            standingCount = standingCount + 1
        end
    end
    
    isStanding = (#recentSpeeds >= 3 and standingCount >= 3)
    
    if isStanding or speed < 3 then 
        return basePos 
    end
    
    local myChar = LP.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    
    if myHRP then
        local distance = (basePos - myHRP.Position).Magnitude
        local bulletSpeed = 3000
        
        local bulletTravelTime = distance / bulletSpeed
        
        local speedFactor = math.clamp(speed / 50, 0.6, 2.5)
        local predictTime = bulletTravelTime * speedFactor
        
        local predictedPos = basePos + currentVelocity * predictTime
        
        return predictedPos
    end
    
    return basePos
end

--==== TRAJECTORY ====
local trajectoryBeam = nil
local lastTrajectoryTime = 0

local function DrawTrajectory(startPos, targetPos)
    if not showTrajectory then return end
    
    if tick() - lastTrajectoryTime < 2.03 then return end
    lastTrajectoryTime = tick()
    
    if trajectoryBeam then
        trajectoryBeam:Destroy()
    end
    
    local direction = (targetPos - startPos)
    local distance = direction.Magnitude
    
    if distance == 0 then return end
    
    trajectoryBeam = Instance.new("Part")
    trajectoryBeam.Name = "TrajectoryBeam"
    trajectoryBeam.Size = Vector3.new(0.3, 0.3, distance)
    trajectoryBeam.CFrame = CFrame.lookAt(startPos, targetPos) * CFrame.new(0, 0, -distance/2)
    trajectoryBeam.Color = Color3.fromHSV((tick() * 0.003) % 1, 1, 1)
    trajectoryBeam.Material = Enum.Material.Neon
    trajectoryBeam.CanCollide = false
    trajectoryBeam.Anchored = true
    trajectoryBeam.Parent = workspace
    
    spawn(function()
        for i = 1, 30 do
            if trajectoryBeam and trajectoryBeam.Parent then
                trajectoryBeam.Color = Color3.fromHSV((tick() * 0.001 + i * 0.05) % 1, 1, 1)
                trajectoryBeam.Size = Vector3.new(
                    0.1 + math.sin(tick() * 12) * 0.2,
                    0.1 + math.sin(tick() * 12) * 0.2,
                    distance
                )
                trajectoryBeam.Transparency = math.sin(tick() * 3) * 0.2 + 0.1
            else
                break
            end
            task.wait(0.05)
        end
        if trajectoryBeam then trajectoryBeam:Destroy() end
    end)
end

local isReloading = false

--==== ИСПРАВЛЕННАЯ СТРЕЛЬБА ====
local function ClickOnTarget(targetPart)
    if not targetPart or not targetPart.Parent then return end
    if isReloading then return end

    local char = targetPart.Parent
    if wallcheckEnabled and not IsVisiblePart(targetPart, char) then
        return
    end

    local tool = GetCurrentTool()
    if not tool then return end
    
    -- Получаем все возможные события
    local fireEvent, showBeamEvent, killEvent, shootStart = GetToolEvents(tool)
    
    -- ВАЖНО: Если нет ни старой системы (ShootStart), ни новой (fire), выходим
    if not fireEvent and not shootStart then return end

    local predictedPos = PredictPosition(targetPart)
    local myChar = LP.Character
    if not myChar then return end
    
    local myHRP = myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    
    local handle = tool:FindFirstChild("Handle")
    local startPos = handle and handle.Position or myHRP.Position
    
    if wallcheckEnabled and not IsPathClear(targetPart, predictedPos) then
        return
    end
    
    -- === ЛОГИКА ДЛЯ СИСТЕМЫ С FIRE/KILL (Твой случай) ===
    if fireEvent then
        -- 1. Основное событие
        fireEvent:FireServer()
        
        -- 2. Визуализация для других
        if showBeamEvent then
             -- Аргументы из декомпиляции: (HitPos, StartPos, Handle)
            showBeamEvent:FireServer(predictedPos, startPos, handle)
        end
        
        -- 3. Убийство (100% попадание)
        if alwaysKillEnabled and killEvent then
            local targetPlayer = Players:GetPlayerFromCharacter(char)
            if targetPlayer and IsEnemy(targetPlayer) then
                local direction = (predictedPos - startPos).Unit
                -- Аргументы из декомпиляции: (Player, LookVector)
                killEvent:FireServer(targetPlayer, direction)
            end
        end
    end
    
    -- === ЛОГИКА ДЛЯ СИСТЕМЫ С SHOOTSTART (Старый скрипт) ===
    if shootStart then
        shootStart:FireServer(predictedPos)
    end

    -- Локальная визуализация
    DrawLocalBeam(startPos, predictedPos, handle)
    DrawTrajectory(startPos, predictedPos)
end


local function DoAutoJump()
    if not autoJumpEnabled then return end

    local myChar = LP.Character
    if not myChar then return end

    local humanoid = myChar:FindFirstChildOfClass("Humanoid")
    local rootPart = myChar:FindFirstChild("HumanoidRootPart")
    if not (humanoid and rootPart) then return end

    local rayOrigin = rootPart.Position - Vector3.new(0, 3, 0)
    local rayDirection = Vector3.new(0, -6, 0)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = { myChar }

    if workspace:Raycast(rayOrigin, rayDirection, params) then
        humanoid.Jump = true
    end
end

local function SetAntiAimEnabled(state)
    AntiAim.Enabled = state

    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if hum then
        if state then
            lastAutoRotate = hum.AutoRotate
            hum.AutoRotate = false
        else
            hum.AutoRotate = lastAutoRotate
        end
    end
end

local function GetTargetPositionAA()
    local t = GetClosestEnemy()
    if t and t.part and t.part.Parent then
        return t.part.Position
    end
    return nil
end

---rage
local rageKnifeEnabled = false
local rageGunEnabled   = false
local rageIgnoreWalk   = false
local rageWalkSpeed    = 16
local rageRange        = 10000

local function GetTeamFrames()
    local pg   = LP:FindFirstChild("PlayerGui")
    if not pg then return end

    local main = pg:FindFirstChild("Main")
    if not main then return end

    local mgf  = main:FindFirstChild("MainGameFrame")
    if not mgf then return end

    local pf   = mgf:FindFirstChild("PlayersFrame")
    if not pf then return end

    local blue = pf:FindFirstChild("TeamBlueFrame")
    local red  = pf:FindFirstChild("TeamRedFrame")

    return blue, red
end

local function IsRoundActive()
    local blue, red = GetTeamFrames()
    if not blue or not red then return false end

    -- если в обоих фреймах только UIListLayout / пусто → считаем, что раунда нет
    local function hasPlayers(frame)
        for _, child in ipairs(frame:GetChildren()) do
            if not child:IsA("UIListLayout") then
                return true
            end
        end
        return false
    end

    return hasPlayers(blue) or hasPlayers(red)
end

local function GetPlayerNameFromGui(child)
    if child:IsA("UIListLayout") then return nil end

    if (child:IsA("TextLabel") or child:IsA("TextButton")) and child.Text and child.Text ~= "" then
        return child.Text
    end

    return child.Name
end


local rageEnemies = {}      -- { {player=..., gui=..., lastSeen=tick()} }
local rageEnemyMap = {}     -- [player] = true для быстрого lookup
local rageWatcherStarted = false

local function FrameHasLocal(frame)
    if not frame then return false end
    for _, child in ipairs(frame:GetChildren()) do
        local name = GetPlayerNameFromGui(child)
        if name == LP.Name then
            return true
        end
    end
    return false
end

local function RebuildRageEnemies()
    table.clear(rageEnemies)
    table.clear(rageEnemyMap)

    local blue, red = GetTeamFrames()
    if not blue or not red then return end

    local myFrame, enemyFrame

    if FrameHasLocal(blue) then
        myFrame   = blue
        enemyFrame = red
    elseif FrameHasLocal(red) then
        myFrame   = red
        enemyFrame = blue
    else
        -- не нашли себя ни в одной команде
        return
    end

    for _, child in ipairs(enemyFrame:GetChildren()) do
        local name = GetPlayerNameFromGui(child)
        if name and name ~= "" then
            local plr = Players:FindFirstChild(name)
            if plr and plr ~= LP then
                rageEnemyMap[plr] = true
                table.insert(rageEnemies, {player = plr, gui = child, lastSeen = tick()})
            end
        end
    end
end

local function StartRageEnemyWatcher()
    if rageWatcherStarted then return end
    rageWatcherStarted = true

    local function hookFrame(frame)
        if not frame then return end

        frame.ChildAdded:Connect(function()
            RebuildRageEnemies()
        end)

        frame.ChildRemoved:Connect(function()
            RebuildRageEnemies()
        end)

        -- если меняют Visible/Active → пересобрать
        frame:GetPropertyChangedSignal("Visible"):Connect(function()
            RebuildRageEnemies()
        end)
        frame:GetPropertyChangedSignal("Active"):Connect(function()
            RebuildRageEnemies()
        end)
    end

    local blue, red = GetTeamFrames()
    if blue then hookFrame(blue) end
    if red  then hookFrame(red)  end

    -- первичная инициализация
    RebuildRageEnemies()
end

local function GetTeamsFromUI()
    local blue, red = GetTeamFrames()
    if not blue or not red then return nil, nil, nil end

    local myFrame, enemyFrame, myTeam

    if FrameHasLocal(blue) then
        myFrame   = blue
        enemyFrame = red
        myTeam    = "Blue"
    elseif FrameHasLocal(red) then
        myFrame   = red
        enemyFrame = blue
        myTeam    = "Red"
    end

    return myFrame, enemyFrame, myTeam
end

local function GetEnemiesFromUI()
    local _, enemyFrame = GetTeamsFromUI()
    local result = {}

    if not enemyFrame then
        return result
    end

    for _, child in ipairs(enemyFrame:GetChildren()) do
        if not child:IsA("UIListLayout") then
            -- достаём ник из Name/Text
            local name = child.Name
            if (child:IsA("TextLabel") or child:IsA("TextButton")) and child.Text and child.Text ~= "" then
                name = child.Text
            end

            local plr = Players:FindFirstChild(name)  -- поиск игрока по нику [web:215][web:220]
            if plr then
                local char = plr.Character
                local hrp  = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
                if hrp then
                    table.insert(result, {player = plr, hrp = hrp})
                end
            end
        end
    end

    return result
end

local function IsRageEnemy(plr)
    if plr == LP then return false end

    local myGame  = LP:GetAttribute("Game")  or "nothing"
    local myTeam  = LP:GetAttribute("Team")  or "nothing"
    local theirGame = plr:GetAttribute("Game") or "nothing"
    local theirTeam = plr:GetAttribute("Team") or "nothing"

    -- свои: одна и та же игра и та же команда
    if theirGame == myGame and theirTeam == myTeam then
        return false
    end

    return true
end

local function GetAllEnemies()
    local result = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and IsEnemy(plr) then
            local char = plr.Character
            local hrp  = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
            if hrp then
                table.insert(result, {player = plr, hrp = hrp})
            end
        end
    end

    return result
end

local function FireKillRemote(remote, targetPlayer)
    if not remote or not targetPlayer then return end

    if remote:IsA("RemoteEvent") then
        local ok = pcall(function()
            remote:FireServer(targetPlayer, 1)
        end)
        if not ok then
            pcall(function()
                remote:FireServer(1, targetPlayer)
            end)
        end

    elseif remote:IsA("RemoteFunction") then
        local ok = pcall(function()
            remote:InvokeServer(targetPlayer, 1)
        end)
        if not ok then
            pcall(function()
                remote:InvokeServer(1, targetPlayer)
            end)
        end
    end
end


local function KillWithSetDead(targetPlayer)
    if not targetPlayer then return end
    FireKillRemote(SetDeadRemote,  targetPlayer)
    FireKillRemote(KilledRemote,   targetPlayer)
end

local function RageGunLoop()
    StartRageEnemyWatcher()

    while rageGunEnabled do
        if IsRoundActive() then
        local tool = GetCurrentTool()
        if tool then
            local fireEvent, showBeamEvent, killEvent = GetToolEvents(tool)
            local handle = tool:FindFirstChild("Handle")
            local myChar = LP.Character
            local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")

            if killEvent and handle and myHRP then
                local startPos = handle.Position

                for i = #rageEnemies, 1, -1 do
                    local info = rageEnemies[i]
                    local plr  = info.player

                    -- Жив ли ещё игрок и есть ли у него HRP
                    if not plr or not rageEnemyMap[plr] then
                        table.remove(rageEnemies, i)
                    else
                        local char = plr.Character
                        local hrp  = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
                        if not hrp or not hrp.Parent then
                            table.remove(rageEnemies, i)
                        else
                            local targetPos = hrp.Position

                            -- ТП к врагу
                            myHRP.CFrame = CFrame.new(targetPos + Vector3.new(0, 0, 0), targetPos)

                            local dirVec = targetPos - startPos
                            if dirVec.Magnitude > 0.001 then
                                local direction = dirVec.Unit
                                if fireEvent then
                                    fireEvent:FireServer()
                                end
                                if showBeamEvent then
                                    showBeamEvent:FireServer(targetPos, startPos, handle)
                                end
                                killEvent:FireServer(plr, direction)
                                KillWithSetDead(plr)
                            end
                        end
                    end
                end
            end
        end
        end

        task.wait()
    end
end

local function RageKnifeLoop()
    StartRageEnemyWatcher()

    while rageKnifeEnabled do
        if IsRoundActive() then
        local tool = GetCurrentTool()
        if tool then
            local killEvent = tool:FindFirstChild("kill")
            local handle    = tool:FindFirstChild("Handle")
            local myChar    = LP.Character
            local myHRP     = myChar and myChar:FindFirstChild("HumanoidRootPart")

            if killEvent and handle and myHRP then
                local startPos = handle.Position

                for i = #rageEnemies, 1, -1 do
                    local info = rageEnemies[i]
                    local plr  = info.player

                    if not plr or not rageEnemyMap[plr] then
                        table.remove(rageEnemies, i)
                    else
                        local char = plr.Character
                        local hrp  = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
                        if not hrp or not hrp.Parent then
                            table.remove(rageEnemies, i)
                        else
                            local targetPos = hrp.Position

                            myHRP.CFrame = CFrame.new(targetPos + Vector3.new(0, 0, 0), targetPos)

                            local dirVec = targetPos - startPos
                            if dirVec.Magnitude > 0.001 then
                                local direction = dirVec.Unit
                                killEvent:FireServer(plr, direction)
                                KillWithSetDead(plr)
                            end
                        end
                    end
                end
            end
        end
        end

        task.wait()
    end
end

local function RageIgnoreWalkLoop()
    while rageIgnoreWalk do
        local char = LP.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = rageWalkSpeed
        end
        task.wait(0.05)
    end
end


--==== ИНИЦИАЛИЗАЦИЯ ====
ShootStart = GetShootStart()

LP.CharacterAdded:Connect(function()
    task.wait(2)
    ShootStart = GetShootStart()
    if neonGunEnabled then
        StartNeonMonitor()
    end
end)

LP.Character.ChildAdded:Connect(function(child)
    if child:IsA("Tool") and child:FindFirstChild("fire") then
        task.wait(0.1)
        ShootStart = GetShootStart()
    end
end)

LP.Backpack.ChildAdded:Connect(function(child)
    if child:IsA("Tool") and child:FindFirstChild("fire") then
        task.wait(0.1)
        ShootStart = GetShootStart()
    end
end)

-- Кэшируем части персонажа и список игроков
local charPartsCache = {}  -- [char] = {hrp, lastUpdate}
local playersCache = {}

-- Обновляем кэш игроков реже (0.5 сек) и по событиям
local lastPlayersUpdate = 0
local function UpdatePlayersCache()
    playersCache = Players:GetPlayers()
end

Players.PlayerAdded:Connect(UpdatePlayersCache)
Players.PlayerRemoving:Connect(UpdatePlayersCache)

-- Кольцевой буфер для истории позиций (избегаем table.insert/remove)
local function UpdateTargetData()
    -- Обновляем список игроков не каждый кадр
    if tick() - lastPlayersUpdate > 0.5 then
        UpdatePlayersCache()
        lastPlayersUpdate = tick()
    end
    
    for _, player in ipairs(playersCache) do
        if player ~= LP and player.Character then
            local char = player.Character
            local cache = charPartsCache[char]
            
            -- Кэшируем HRP, ищем только если нет в кэше
            if not cache then
                local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                if hrp then
                    cache = {hrp = hrp, index = 1, data = {}}
                    charPartsCache[char] = cache
                end
            end
            
            if cache and cache.hrp then
                local now = tick()
                local index = cache.index
                local data = cache.data
                
                -- Записываем в кольцевой буфер (перезаписываем старые данные)
                data[index] = {pos = cache.hrp.Position, time = now}
                
                -- Увеличиваем индекс, обнуляем при достижении лимита
                cache.index = index % 20 + 1  -- Кольцевой буфер на 20 элементов
                
                -- Удаляем старые данные, если они есть
                if data[cache.index] then
                    data[cache.index] = nil
                end
            end
        end
    end
    
    -- Очищаем кэш для удаленных персонажей
    for char, _ in pairs(charPartsCache) do
        if not char.Parent then
            charPartsCache[char] = nil
        end
    end
end

RunService.Heartbeat:Connect(UpdateTargetData)

--==== INPUT ====
local cHeld = false

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.C then
        cHeld = true
    elseif input.KeyCode == antiAimToggleKey then
        SetAntiAimEnabled(not AntiAim.Enabled)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.C then
        cHeld = false
        Camera.CameraType = Enum.CameraType.Custom
        recoilActive = false
    end
end)

--==== СИСТЕМА ====
local lastLookOnShootTime = 0  -- объяви рядом с другими таймерами

local function ApplyLookOnShoot(targetPart)
    if not LookOnShootEnabled or not targetPart then return end

    local now = tick()
    if now - lastLookOnShootTime < 1 then return end

    local myChar = LP.Character
    if not myChar then return end

    local hrp = myChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local myPos = hrp.Position
    local targetPos = targetPart.Position

    -- Проецируем цель на горизонтальную плоскость, чтобы не задирать голову
    local flatTarget = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)

    -- Вариант 1: смотреть прямо на цель
    hrp.CFrame = CFrame.lookAt(myPos, flatTarget)  -- ставит позицию и поворот сразу [web:96]

    -- Если нужно смотреть "спиной" к цели, раскомментируй:
    -- hrp.CFrame = CFrame.lookAt(myPos, flatTarget) * CFrame.Angles(0, math.pi, 0)

    lastLookOnShootTime = now
end

--==== ОСНОВНОЙ ЦИКЛ ====
RunService.RenderStepped:Connect(function()
    DoAutoJump()

    local shouldAim = cHeld or alwaysAimEnabled
    if not shouldAim then return end

    if visualAimEnabled and recoilActive and tick() > recoilEndTime then
        Camera.CFrame = lastCameraCFrame
        recoilActive = false
    end

    if visualAimEnabled and recoilActive then return end

    local target = GetClosestEnemy()
    if not target then return end

    if visualAimEnabled then
        lastCameraCFrame = Camera.CFrame
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, target.part.Position)
    end

    if autoShootEnabled and tick() - lastShotTime > shootDelay then
        ClickOnTarget(target.part)
        ApplyLookOnShoot(target.part)
        lastShotTime = tick()

        if visualAimEnabled then
            recoilActive = true
            recoilEndTime = tick() + reloadTime
        end
    end

    if cameraAssistEnabled then
        local screenPos, onScreen = Camera:WorldToViewportPoint(target.part.Position)
        local viewportSize = Camera.ViewportSize

        if not onScreen then
            local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, target.part.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, cameraSmooth * 2)
        else
            local centerX, centerY = viewportSize.X * 0.5, viewportSize.Y * 0.5
            local offsetX = (screenPos.X - centerX) / centerX
            local offsetY = (screenPos.Y - centerY) / centerY

            if math.abs(offsetX) > 0.1 or math.abs(offsetY) > 0.1 then
                local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, target.part.Position)
                Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, cameraSmooth)
            end
        end
    end
end)

--==== ANTI-AIM ЦИКЛ ====
RunService.RenderStepped:Connect(function(dt)
    if not AntiAim.Enabled then return end

    local char = LP.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return end

    local targetPos3D = GetTargetPositionAA()
    if not targetPos3D then return end

    local flatTarget = Vector3.new(targetPos3D.X, hrp.Position.Y, targetPos3D.Z)

    local lookCF = CFrame.lookAt(hrp.Position, flatTarget)
    local backCF = lookCF * CFrame.Angles(0, math.pi, 0)

    if AntiAim.JitterEnabled then
        local amp   = math.rad(AntiAim.JitterAngleDeg or 6)
        local speed = AntiAim.JitterSpeed or 18
        local yawOffset = math.sin(tick() * speed) * amp
        backCF = backCF * CFrame.Angles(0, yawOffset, 0)
    end

    local alpha = math.clamp(AntiAim.Smooth, 0.01, 1)
    hrp.CFrame = hrp.CFrame:Lerp(backCF, alpha)
end)

--==== UI ====
local tab    = UI.CreateTab("Aim Assist", "🎯")
local page   = tab.Page

local camtab  = UI.CreateTab("Camera Helper", "🎯")
local campage = camtab.Page

local aaTab  = UI.CreateTab("Anti-Aim", "🌀")
local aaPage = aaTab.Page

local vistab  = UI.CreateTab("Visuals", "⭐")
local vispage = vistab.Page

local funtab  = UI.CreateTab("Fun", "🤔")
local funpage = funtab.Page

local settab  = UI.CreateTab("Settings", "⚙️")
local setpage = settab.Page

-- Settings
UI.AddToggle(setpage, "🛡️ Wallcheck", true,  function(state) wallcheckEnabled = state end)
UI.AddSlider(setpage, "⏱️ Shoot Delay", 0.05, 0.5, 0.1, function(v) shootDelay = v end)
UI.AddSlider(setpage, "🔄 Reload Time", 0.1, 2.0, 0.5, function(v) reloadTime  = v end)
UI.AddSlider(setpage, "🌐 Prediction Ping", 0.03, 0.15, predictionPing, function(v) predictionPing = v end)
UI.AddSlider(setpage, "🎯 Smoothing", 0.4, 1.0, smoothingFactor, function(v) smoothingFactor = v end)
UI.AddToggle(setpage, "👁️ Ignore Visibility", false, function(state) ignoreVisibilityEnabled = state end)
UI.AddToggle(setpage, "💀 Always Kill (100%)", true, function(state) alwaysKillEnabled = state end)

-- Aim
UI.AddToggle(page, "🎯 Always Aim", false,function(state) alwaysAimEnabled = state end)
UI.AddToggle(page, "🔫 Auto Shoot", false,function(state) autoShootEnabled = state end)
UI.AddDropdown(page, "Aim Mode", {"Body","Any","Head"}, "Body", function(v) aimMode = v end)
UI.AddSlider(page, "📏 Range", 50, 2000, 500, function(v) aimRange = v end)

-- Fun
UI.AddToggle(funpage, "📍 Show Trajectory", false, function(state) showTrajectory = state end)
UI.AddToggle(funpage, "🔄 Look On Shoot", false, function(state) LookOnShootEnabled = state end)
UI.AddToggle(funpage, "🦘 Auto Jump",  false,function(state) autoJumpEnabled  = state end)
UI.AddToggle(funpage, "🌙 Nightmode", false, function(state)
    ToggleNightmode(state)
end)
UI.AddDropdown(funpage, "⏱️Time Mode", {"Default","Day","Night","Custom Night"}, "Default", function(v)
    SetTimeMode(v)
end)

-- Camera
UI.AddToggle(campage, "🎥 Visual Aim", false,function(state) visualAimEnabled = state end)
UI.AddToggle(campage, "📷 Camera Assist", false, function(state) cameraAssistEnabled = state end)
UI.AddSlider(campage, "🔄 Camera Smooth", 0.05, 0.5, cameraSmooth, function(v) cameraSmooth = v end)

-- Visuals
UI.AddToggle(vispage, "🌈 Neon Gun", false, function(state) 
    neonGunEnabled = state 
    if state then
        StartNeonMonitor()
    else
        if neonMonitorConnection then
            neonMonitorConnection:Disconnect()
            neonMonitorConnection = nil
        end
    end
    UpdateGunMaterial() 
end)

UI.AddSlider(vispage, "🎨 Neon Speed", 0.003, 5.0, neonSpeed, function(v) 
    neonSpeed = v 
end)

UI.AddToggle(vispage, "👁️ ESP", false, function(state)
    espEnabled = state
    if state then
        StartESPUpdate()
    else
        StopESPUpdate()
    end
end)

UI.AddToggle(vispage, "🎥 Visual LocalBeam", false, function(state) 
    visualLocalBeamEnabled = state 
end)

-- Anti-Aim
UI.AddToggle(aaPage, "Enable Anti-Aim", false, function(state) SetAntiAimEnabled(state) end)
UI.AddSlider(aaPage, "Smooth", 0.05, 1.0, AntiAim.Smooth, function(v) AntiAim.Smooth = v end)

-- Rage
local rageTab  = UI.CreateTab("Rage", "💀")
local ragePage = rageTab.Page

UI.AddHeader(ragePage, "🖤 Game Settings")

UI.AddToggle(ragePage, "⭐ Kill all - Knife", false, function(state)
    rageKnifeEnabled = state
    if state then
        task.spawn(RageKnifeLoop)
    end
end)

UI.AddToggle(ragePage, "⭐ Kill all - Gun", false, function(state)
    rageGunEnabled = state
    if state then
        task.spawn(RageGunLoop)
    end
end)

UI.AddToggle(ragePage, "⭐ Ignore Anti-Walk", false, function(state)
    rageIgnoreWalk = state
    if state then
        task.spawn(RageIgnoreWalkLoop)
    end
end)

UI.AddHeader(ragePage, "🖤 Player Settings")

UI.AddSlider(ragePage, "🏃‍♂️‍➡️ WalkSpeed", 16, 60, 16, function(v)
    rageWalkSpeed = v
end)

-- =========UI OVER==========
--hitbox all 1 0
local function ResetAimbotCache()
    -- 1. Сбрасываем кэши врагов и целей
    enemyCache = {}
    cachedTarget = nil
    
    -- 2. Очищаем историю позиций
    TargetData = {}
    
    -- 3. Очищаем ESP (удаляем хайлайты)
    for player, data in pairs(espBoxes) do
        if data.highlight and data.highlight.Parent then
            data.highlight:Destroy()
        end
        if data.deathConnection then
            data.deathConnection:Disconnect()
        end
    end
    espBoxes = {}
    
    -- 4. Сбрасываем состояние стрельбы
    lastScanTime = 0
    lastShotTime = 0
    recoilActive = false
    recoilEndTime = 0
    isReloading = false
    
    -- 5. Удаляем визуальные элементы
    if trajectoryBeam then
        trajectoryBeam:Destroy()
        trajectoryBeam = nil
    end
    
    -- 6. Очищаем соединения неоновой пушки
    for _, conn in pairs(currentNeonConnections) do
        if conn then conn:Disconnect() end
    end
    currentNeonConnections = {}
    
    -- 7. Сбрасываем кэш позиции камеры
    lastCameraCFrame = CFrame.new()
    
    -- 8. Обновляем время последнего сброса
    lastFullResetTime = tick()
    
    -- Можно добавить отладочный вывод
    -- print("Aimbot cache fully reset")
end

-- Таймер для автоматического сброса каждые 10 секунд
task.spawn(function()
    while true do
        task.wait(10)
        ResetAimbotCache()
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    if plr.Character then
        TargetData[plr.Character] = nil
        charPartsCache[plr.Character] = nil
        visibilityCache[plr.Character] = nil
    end
    RemoveESPBox(plr)
    enemyCache[plr] = nil
end)

Players.PlayerRemoving:Connect(function(plr)
    enemyCache[plr] = nil
end)

-- Запускаем обновление в Heartbeat
RunService.Heartbeat:Connect(UpdateBacktrack)

-- Очищаем при выходе игрока
Players.PlayerRemoving:Connect(function(player)
    backtrackData[player] = nil
    ClearBacktrackVisual(player)
end)
