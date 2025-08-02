-- ESP Module
local esp = {}

-- ========================================================
--                        PET ESP


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local petsPhysical = workspace:WaitForChild("PetsPhysical")

local GetPetCooldown = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("GetPetCooldown")
local activePetUI = player.PlayerGui:WaitForChild("ActivePetUI")
local scrollingFrame = activePetUI:WaitForChild("Frame"):WaitForChild("Main"):WaitForChild("ScrollingFrame")

-- ESP Variables
local petModelCache = {}
local petData = {}
local espEnabled = false
local heartbeatConnection
local childAddedConnection
local childRemovedConnection

local function updatePetData()
    petData = {}
    for _, frame in pairs(scrollingFrame:GetChildren()) do
        if frame:IsA("Frame") and frame.Name:match("^{.+}$") then
            local petTypeLabel = frame:FindFirstChild("PET_TYPE")
            if petTypeLabel and petTypeLabel:IsA("TextLabel") then
                local petName = petTypeLabel.Text
                if petName and petName ~= "" then
                    petData[frame.Name] = petName
                end
            end
        end
    end
end

local function secondsToMinSec(seconds)
    if not seconds or seconds <= 0 then
        return "Ready"
    end
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = math.floor(seconds % 60)
    return string.format("%dm %ds", minutes, remainingSeconds)
end

local function getPetIds()
    local petIds = {}
    local pattern = "{.-}"
    local children = scrollingFrame:GetChildren()
    for _, child in ipairs(children) do
        for match in string.gmatch(child.Name, pattern) do
            table.insert(petIds, match)
        end
    end
    return petIds
end

local function findPathByPetId(petId)
    if petModelCache[petId] then
        return petModelCache[petId]
    end

    local descendants = petsPhysical:GetDescendants()
    local matches = {}
    local pattern = "{.-}"

    for _, descendant in ipairs(descendants) do
        local name = descendant.Name
        local fullPath = descendant:GetFullName()
        for match in string.gmatch(name, pattern) do
            if match == petId then
                table.insert(matches, {path = fullPath, match = match, instance = descendant})
            end
        end
    end

    if #matches > 0 then
        petModelCache[petId] = matches
    end
    return matches
end

local function createOrUpdateESP(petModel, petId, cooldownTime)
    if not petModel or not petModel:IsA("Model") then
        return
    end

    local primaryPart = petModel.PrimaryPart or petModel:FindFirstChildWhichIsA("BasePart")
    if not primaryPart then
        return
    end

    local billboard = primaryPart:FindFirstChild("CooldownESP")
    if not billboard then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "CooldownESP"
        billboard.Adornee = primaryPart
        billboard.Size = UDim2.new(0, 150, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.LightInfluence = 0
        billboard.Parent = primaryPart

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Parent = billboard

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
        nameLabel.Position = UDim2.new(0, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextStrokeTransparency = 0.5
        nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 16
        nameLabel.TextScaled = true
        nameLabel.Parent = frame

        local cooldownLabel = Instance.new("TextLabel")
        cooldownLabel.Name = "CooldownLabel"
        cooldownLabel.Size = UDim2.new(1, 0, 0.5, 0)
        cooldownLabel.Position = UDim2.new(0, 0, 0.5, 0)
        cooldownLabel.BackgroundTransparency = 1
        cooldownLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
        cooldownLabel.TextStrokeTransparency = 0.5
        cooldownLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        cooldownLabel.Font = Enum.Font.GothamBold
        cooldownLabel.TextSize = 16
        cooldownLabel.TextScaled = true
        cooldownLabel.Parent = frame
    end

    local frame = billboard:FindFirstChildWhichIsA("Frame")
    local nameLabel = frame and frame:FindFirstChild("NameLabel")
    local cooldownLabel = frame and frame:FindFirstChild("CooldownLabel")
    if nameLabel and cooldownLabel then
        local petName = petData[petId] or "Unknown"
        local displayText = "Cooldown: " .. secondsToMinSec(cooldownTime)
        if nameLabel.Text ~= petName then
            nameLabel.Text = petName
        end
        if cooldownLabel.Text ~= displayText then
            cooldownLabel.Text = displayText
        end
    end
end

local function cleanupESP(petIds)
    for cachedPetId, matches in pairs(petModelCache) do
        if not table.find(petIds, cachedPetId) then
            for _, match in ipairs(matches) do
                local petModel = match.instance
                if petModel then
                    local primaryPart = petModel.PrimaryPart or petModel:FindFirstChildWhichIsA("BasePart")
                    if primaryPart then
                        local billboard = primaryPart:FindFirstChild("CooldownESP")
                        if billboard then
                            billboard:Destroy()
                        end
                    end
                end
            end
            petModelCache[cachedPetId] = nil
        end
    end
end

local function removeAllESP()
    for cachedPetId, matches in pairs(petModelCache) do
        for _, match in ipairs(matches) do
            local petModel = match.instance
            if petModel then
                local primaryPart = petModel.PrimaryPart or petModel:FindFirstChildWhichIsA("BasePart")
                if primaryPart then
                    local billboard = primaryPart:FindFirstChild("CooldownESP")
                    if billboard then
                        billboard:Destroy()
                    end
                end
            end
        end
    end
    petModelCache = {}
end

local function updateCooldowns()
    if not espEnabled then return end
    
    updatePetData()
    local petIds = getPetIds()
    if #petIds == 0 then
        cleanupESP(petIds)
        return
    end

    cleanupESP(petIds)

    for _, petId in ipairs(petIds) do
        local matches = findPathByPetId(petId)
        if #matches == 0 then
            continue
        end

        for _, match in ipairs(matches) do
            local petModel = match.instance
            local success, result = pcall(function()
                return GetPetCooldown:InvokeServer(petId)
            end)

            if success and result and result[1] and result[1].Time then
                local cooldownTime = result[1].Time
                createOrUpdateESP(petModel, petId, cooldownTime)
            else
                createOrUpdateESP(petModel, petId, nil)
            end
        end
    end
end

-- MAIN ESP FUNCTION - This is what you call from outside
function Petesp(enabled)
    espEnabled = enabled
    
    if enabled then
        -- Start ESP
        updateCooldowns()
        
        local lastUpdate = 0
        heartbeatConnection = RunService.Heartbeat:Connect(function()
            local currentTime = tick()
            if currentTime - lastUpdate >= 2 then
                updateCooldowns()
                lastUpdate = currentTime
            end
        end)

        childAddedConnection = scrollingFrame.ChildAdded:Connect(function()
            updateCooldowns()
        end)
        
        childRemovedConnection = scrollingFrame.ChildRemoved:Connect(function()
            updateCooldowns()
        end)
    else
        -- Stop ESP
        if heartbeatConnection then
            heartbeatConnection:Disconnect()
            heartbeatConnection = nil
        end
        
        if childAddedConnection then
            childAddedConnection:Disconnect()
            childAddedConnection = nil
        end
        
        if childRemovedConnection then
            childRemovedConnection:Disconnect()
            childRemovedConnection = nil
        end
        
        removeAllESP()
    end
end

--=========================================================
--                        FRUIT ESP

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local ESPObjects = {}
local ESPConnection = nil
local selectedCrops = {} -- Store selected crops

-- Core Functions
local function getCurrentFarm()
    local playerName = player.Name
    local farmContainer = Workspace:FindFirstChild("Farm")
    
    if not farmContainer then
        return nil
    end
    
    -- Search through ALL children in Workspace.Farm for player's farm
    for _, child in pairs(farmContainer:GetChildren()) do
        if child.Name == playerName and child:FindFirstChild("Important") then
            return child
        end
    end
    
    -- Fallback: return first farm found
    for _, child in pairs(farmContainer:GetChildren()) do
        if child:FindFirstChild("Important") then
            return child
        end
    end
    
    return nil
end

-- Get crop types
function esp.getCropTypes()
    local farm = getCurrentFarm()
    if not farm or not farm:FindFirstChild("Important") or not farm.Important:FindFirstChild("Plants_Physical") then
        return {"All Plants"}
    end
    
    local cropTypes = {"All Plants"}
    local addedTypes = {}
    
    for _, plant in pairs(farm.Important.Plants_Physical:GetChildren()) do
        if not addedTypes[plant.Name] then
            table.insert(cropTypes, plant.Name)
            addedTypes[plant.Name] = true
        end
    end
    
    return cropTypes
end

-- Set selected crops
function esp.setSelectedCrops(crops)
    selectedCrops = crops or {}
end

-- Check if plant should be ESP'd
local function shouldESPPlant(plantName)
    -- If no crops selected or "All Plants" is effectively selected, ESP all
    if not selectedCrops or next(selectedCrops) == nil then
        return true
    end
    
    -- Check if this specific plant is selected
    return selectedCrops[plantName] == true
end

-- Get fruit weight from individual fruit object
local function getFruitWeight(fruit)
    if fruit:FindFirstChild("Weight") then
        return fruit.Weight.Value or 0
    end
    return 0
end

-- Get fruit base (either Base or PrimaryPart)
local function getFruitBase(fruit)
    return fruit:FindFirstChild("Base") or fruit.PrimaryPart
end

-- Create ESP Text Label
local function createESPLabel(part, plantName, weight)
    local billboardGui = Instance.new("BillboardGui")
    local textLabel = Instance.new("TextLabel")
    
    -- Billboard settings
    billboardGui.Name = "FruitESP"
    billboardGui.Parent = part
    billboardGui.Size = UDim2.new(0, 150, 0, 30)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    
    -- Text Label
    textLabel.Parent = billboardGui
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = plantName .. " [" .. string.format("%.2f", weight) .. " kg]"
    textLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    
    return billboardGui
end

-- Update ESP for all fruits
local function updateESP()
    -- Clear existing ESP
    for _, espObject in pairs(ESPObjects) do
        if espObject and espObject.Parent then
            espObject:Destroy()
        end
    end
    ESPObjects = {}
    
    local farm = getCurrentFarm()
    if not farm or not farm:FindFirstChild("Important") or not farm.Important:FindFirstChild("Plants_Physical") then
        return
    end
    
    -- Create ESP for each individual fruit (only selected plants)
    for _, plant in pairs(farm.Important.Plants_Physical:GetChildren()) do
        if plant:FindFirstChild("Fruits") and shouldESPPlant(plant.Name) then
            for _, fruit in pairs(plant.Fruits:GetChildren()) do
                local base = getFruitBase(fruit)
                local weight = getFruitWeight(fruit)
                
                if base then
                    local espLabel = createESPLabel(base, plant.Name, weight)
                    table.insert(ESPObjects, espLabel)
                end
            end
        end
    end
end

-- Toggle ESP function
function esp.toggle(value)
    if value then
        -- Start ESP
        ESPConnection = RunService.Heartbeat:Connect(updateESP)
    else
        -- Stop ESP
        if ESPConnection then
            ESPConnection:Disconnect()
            ESPConnection = nil
        end
        
        -- Clear all ESP objects
        for _, espObject in pairs(ESPObjects) do
            if espObject and espObject.Parent then
                espObject:Destroy()
            end
        end
        ESPObjects = {}
    end
end

return esp
