local Players              = game:GetService("Players")
local UserInputService     = game:GetService("UserInputService")
local RunService           = game:GetService("RunService")
local Workspace            = game:GetService("Workspace")
local VirtualInputManager  = game:GetService("VirtualInputManager")
local player  = Players.LocalPlayer
local camera  = Workspace.CurrentCamera
--local UI = loadstring(game:HttpGet("http://localhost:8000/Gui.lua", true))()
local UI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/NN-EZ/ui-rob/refs/heads/main/Vibus.lua",
    false
))()
local aimEnabled      = false
local isAiming        = false  
local autoShoot       = false  
local aimSmoothing    = 0.18
local fovRadius       = 350
local centerRadius    = 120    
local debugMode       = false
local randomPower     = 0.45
local shootDelay      = 0.08
local fovHysteresis   = 0.8
local currentTarget    = nil
local aimLocalOffset   = nil
local lastShootTime    = 0
local function dprint(...)
    if debugMode then print("[Vibus] - ", ...) end
end
local function getTargets()
    local targets = {}
    local maps = Workspace:FindFirstChild("Maps")
    if not maps then return targets end
    for _, mapFolder in ipairs(maps:GetChildren()) do
        local targetsFolder = mapFolder:FindFirstChild("Targets")
        if targetsFolder then
            for _, target in ipairs(targetsFolder:GetChildren()) do
                local hum     = target:FindFirstChildOfClass("Humanoid")
                local primary = target:FindFirstChild("Primary")
                if hum and primary and hum.Health > 0 then
                    table.insert(targets, target)
                end
            end
        end
    end
    return targets
end
local function getScreenDistanceFromMouse(target)
    local primary = target:FindFirstChild("Primary")
    if not primary then return math.huge end
    local screenPos, onScreen = camera:WorldToScreenPoint(primary.Position)
    if not onScreen then return math.huge end
    local mousePos = UserInputService:GetMouseLocation()
    return (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
end
local function getNearestTarget(targets)
    local nearest, minDist = nil, math.huge
    for _, target in ipairs(targets) do
        local dist = getScreenDistanceFromMouse(target)
        if dist < minDist then
            minDist = dist
            nearest = target
        end
    end
    return nearest, minDist
end
local function makeLocalOffset(primary: BasePart)
    local size  = primary.Size
    local power = math.clamp(randomPower, 0, 1)
    local ox = (math.random() - 0.5) * size.X * power
    local oy = (math.random() - 0.5) * size.Y * power
    local oz = (math.random() - 0.5) * size.Z * power
    return Vector3.new(ox, oy, oz)
end
local function getAimPoint(primary: BasePart)
    return primary.CFrame:PointToWorldSpace(aimLocalOffset)
end
local function aimAtTarget(target)
    local primary = target:FindFirstChild("Primary")
    if not primary or not aimLocalOffset then return end
    local aimPoint = getAimPoint(primary)
    local camPos   = camera.CFrame.Position
    local direction   = (aimPoint - camPos).Unit
    local currentLook = camera.CFrame.LookVector
    local newLook     = currentLook:Lerp(direction, aimSmoothing)
    camera.CFrame = CFrame.new(camPos, camPos + newLook)
end
local function shoot()
    if tick() - lastShootTime < shootDelay then return end
    local pos = UserInputService:GetMouseLocation()
    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
    task.wait(0.01)
    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
    lastShootTime = tick()
    --dprint("🔫 AUTO SHOT!")

    currentTarget  = nil
    aimLocalOffset = nil
end
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.C and aimEnabled then
        isAiming = true
        dprint("🔴 AIM ON")
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.C then
        isAiming = false
        dprint("⚪ AIM OFF")
    end
end)
RunService.RenderStepped:Connect(function()
    if not aimEnabled then return end
    local targets = getTargets()
    if #targets == 0 then
        currentTarget  = nil
        aimLocalOffset = nil
        return
    end
    local target, dist = getNearestTarget(targets)
    if not target or dist > fovRadius * fovHysteresis then
        currentTarget  = nil
        aimLocalOffset = nil
        return
    end
    
    if target ~= currentTarget then
        currentTarget  = target
        local primary  = target:FindFirstChild("Primary")
        if primary then
            aimLocalOffset = makeLocalOffset(primary)
            dprint("🎯 NEW TARGET:", target.Name)
        end
        return
    end
    
    if isAiming then
        aimAtTarget(currentTarget)
    end
    
    if isAiming and autoShoot and dist <= centerRadius then
        shoot()
    end
end)
Players.LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    currentTarget  = nil
    aimLocalOffset = nil
end)
local MainTab = UI.CreateTab("AutoMatic Tab", "⚙️")
-- ui
UI.AddToggle(MainTab.Page, "AimBot", false, function(state)
    aimEnabled = state
    if not state then
        currentTarget  = nil
        aimLocalOffset = nil
    end
    dprint(state and "on" or "off")
end)
UI.AddToggle(MainTab.Page, "AutoShoot", false, function(state)
    autoShoot = state
    dprint(state and "auto cum on" or "auto cum off")
end)
UI.AddToggle(MainTab.Page, "Debug", true, function(state)
    debugMode = state
end)
UI.AddSlider(MainTab.Page, "Smooth", 0.05, 0.5, aimSmoothing, function(value)
    aimSmoothing = value
end)
UI.AddSlider(MainTab.Page, "Random", 0.1, 0.8, randomPower, function(value)
    randomPower = value
end)
UI.AddSlider(MainTab.Page, "FOV", 200, 600, fovRadius, function(value)
    fovRadius = value
end)
UI.AddSlider(MainTab.Page, "Center Zone", 30, 150, centerRadius, function(value)
    centerRadius = value
end)
UI.AddSlider(MainTab.Page, "Shoot Delay", 0.03, 0.2, shootDelay, function(value)
    shootDelay = value
end)
-- global api
getgenv().SetAimbotEnabled = function(val)
    aimEnabled = val
end
print("AimBot loaded!")
print("Enjoi in good game)
print("Enjoi in good game)
