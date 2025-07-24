-- ESP Module
local esp = {}

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
