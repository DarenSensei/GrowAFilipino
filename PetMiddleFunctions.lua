-- Pet Control Functions Module
-- This module contains all pet-related functionality

local PetFunctions = {}

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Pet Radius Control Configuration
local RADIUS = 0.1
local LOOP_DELAY = 1
local INITIAL_LOOP_TIME = 5
local ZONE_ABILITY_DELAY = 3
local ZONE_ABILITY_LOOP_TIME = 3
local AUTO_LOOP_INTERVAL = 240 -- 4 minutes in seconds

-- Pet Control Services
local ActivePetService = ReplicatedStorage.GameEvents.ActivePetService
local PetZoneAbility = ReplicatedStorage.GameEvents.PetZoneAbility
local Notification = ReplicatedStorage.GameEvents.Notification

-- Pet Control Variables
local activePetUI = nil
local scrollingFrame = nil
local selectedPets = {}
local excludedPets = {}
local excludedPetESPs = {}
local allPetsSelected = false
local autoMiddleEnabled = false
local autoMiddleConnection = nil
local zoneAbilityConnection = nil
local notificationConnection = nil
local loopTimer = nil
local delayTimer = nil
local isLooping = false
local petDropdown = nil
local currentPetsList = {}
local lastZoneAbilityTime = 0 -- Track last zone ability time

-- Function to check if string is UUID format
function PetFunctions.isValidUUID(str)
    if not str or type(str) ~= "string" then return false end
    str = string.gsub(str, "[{}]", "")
    return string.match(str, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

-- Function to initialize ActivePetUI references
function PetFunctions.initializeActivePetUI()
    local player = Players.LocalPlayer
    if not player then return false end

    local playerGui = player:WaitForChild("PlayerGui", 5)
    if not playerGui then return false end

    activePetUI = playerGui:WaitForChild("ActivePetUI", 5)
    if not activePetUI then return false end

    local frame = activePetUI:WaitForChild("Frame", 2)
    if not frame then return false end

    local main = frame:WaitForChild("Main", 2)
    if not main then return false end

    scrollingFrame = main:WaitForChild("ScrollingFrame", 2)
    if not scrollingFrame then return false end

    return true
end

-- Function to find pet mover in workspace by UUID
function PetFunctions.findPetMoverByUUID(uuid)
    -- Remove curly braces for comparison
    local cleanUUID = string.gsub(uuid, "[{}]", "")

    -- Search through workspace for pet movers
    local function searchInFolder(folder)
        for _, child in pairs(folder:GetChildren()) do
            if child:IsA("Part") and child.Name == "PetMover" then
                local petId = PetFunctions.getPetIdFromPetMover(child)
                if petId then
                    local cleanPetId = string.gsub(tostring(petId), "[{}]", "")
                    if cleanPetId == cleanUUID then
                        return child
                    end
                end
            elseif child:IsA("Model") or child:IsA("Folder") then
                local result = searchInFolder(child)
                if result then return result end
            end
        end
        return nil
    end

    return searchInFolder(Workspace)
end

-- Function to get pet ID from PetMover
function PetFunctions.getPetIdFromPetMover(petMover)
    if not petMover then return nil end

    local petId = petMover:GetAttribute("PetId") or 
                 petMover:GetAttribute("Id") or 
                 petMover:GetAttribute("UUID") or
                 petMover:GetAttribute("petId")

    if petId then return petId end

    if petMover.Parent and PetFunctions.isValidUUID(petMover.Parent.Name) then
        return petMover.Parent.Name
    end

    if PetFunctions.isValidUUID(petMover.Name) then
        return petMover.Name
    end

    return petMover:GetFullName()
end

-- Function to create ESP "X" marker
function PetFunctions.createESPMarker(pet)
    if excludedPetESPs[pet.id] then
        return -- ESP already exists
    end

    if not pet.mover then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ExcludedPetESP"
    billboard.Adornee = pet.mover
    billboard.Size = UDim2.new(0, 50, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.LightInfluence = 0
    billboard.AlwaysOnTop = true

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = billboard

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "X"
    textLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextStrokeTransparency = 0
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.Parent = frame

    billboard.Parent = pet.mover
    excludedPetESPs[pet.id] = billboard
end

-- Function to remove ESP marker
function PetFunctions.removeESPMarker(petId)
    if excludedPetESPs[petId] then
        excludedPetESPs[petId]:Destroy()
        excludedPetESPs[petId] = nil
    end
end

-- Function to get all pets from ActivePetUI
function PetFunctions.getAllPets()
    local pets = {}

    if not scrollingFrame then
        if not PetFunctions.initializeActivePetUI() then
            return pets
        end
    end

    -- Iterate through children of ScrollingFrame
    for _, child in pairs(scrollingFrame:GetChildren()) do
        if child:IsA("Frame") and PetFunctions.isValidUUID(child.Name) then
            local uuid = child.Name
            local petType = "Pet" -- Default type

            -- Try to get pet type from PET_TYPE child
            local petTypeChild = child:FindFirstChild("PET_TYPE")
            if petTypeChild and petTypeChild:IsA("TextLabel") then
                petType = petTypeChild.Text or "Pet"
            end

            -- Find the corresponding PetMover in workspace
            local petMover = PetFunctions.findPetMoverByUUID(uuid)

            -- Create pet entry
            local petEntry = {
                id = uuid,
                name = petType,
                model = child, -- UI element
                mover = petMover, -- Physical part in workspace
                position = petMover and petMover.Position or Vector3.new(0, 0, 0)
            }

            table.insert(pets, petEntry)
        end
    end

    return pets
end

-- Function to get farm center point
function PetFunctions.getFarmCenterPoint()
    local player = Players.LocalPlayer
    if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    local playerPosition = player.Character.HumanoidRootPart.Position
    local farmFolder = Workspace:FindFirstChild("Farm")

    if farmFolder then
        local closestFarm = nil
        local closestDistance = math.huge

        for _, farm in pairs(farmFolder:GetChildren()) do
            local centerPoint = farm:FindFirstChild("Center_Point")
            if centerPoint then
                local distance = (playerPosition - centerPoint.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestFarm = centerPoint.Position
                end
            end
        end

        return closestFarm
    end

    return playerPosition
end

-- Function to format pet ID to UUID format
function PetFunctions.formatPetIdToUUID(petId)
    if string.match(petId, "^{%x+%-%x+%-%x+%-%x+%-%x+}$") then
        return petId
    end

    petId = string.gsub(petId, "[{}]", "")
    return "{" .. petId .. "}"
end

-- Function to set pet state
function PetFunctions.setPetState(petId, state)
    local formattedPetId = PetFunctions.formatPetIdToUUID(petId)
    pcall(function()
        ActivePetService:FireServer("SetPetState", formattedPetId, state)
    end)
end

-- Function to run the auto middle loop
function PetFunctions.runAutoMiddleLoop()
    if not autoMiddleEnabled then return end

    local pets = PetFunctions.getAllPets()
    local farmCenterPoint = PetFunctions.getFarmCenterPoint()

    if not farmCenterPoint then return end

    for _, pet in pairs(pets) do
        -- Check if pet is excluded FIRST
        if PetFunctions.isPetExcluded(pet.id) then
            -- Skip excluded pets completely
            continue
        end
        
        -- Only process pets that are selected (either individually or through "all pets")
        if allPetsSelected or selectedPets[pet.id] then
            -- Only process if we have a physical mover
            if pet.mover then
                local distance = (pet.mover.Position - farmCenterPoint).Magnitude
                if distance > RADIUS then
                    PetFunctions.setPetState(pet.id, "Idle")
                end
            end
        end
    end
end

-- Function to start the heartbeat loop
function PetFunctions.startLoop()
    if autoMiddleConnection then
        autoMiddleConnection:Disconnect()
    end

    isLooping = true
    autoMiddleConnection = RunService.Heartbeat:Connect(function()
        if not isLooping then return end
        PetFunctions.runAutoMiddleLoop()
        task.wait(LOOP_DELAY)
    end)
end

-- Function to stop the heartbeat loop
function PetFunctions.stopLoop()
    isLooping = false
    if autoMiddleConnection then
        autoMiddleConnection:Disconnect()
        autoMiddleConnection = nil
    end
end

-- Function to start initial loop
function PetFunctions.startInitialLoop()
    if not autoMiddleEnabled then return end

    PetFunctions.startLoop()

    if loopTimer then
        task.cancel(loopTimer)
    end

    loopTimer = task.spawn(function()
        task.wait(INITIAL_LOOP_TIME)
        if autoMiddleEnabled then
            PetFunctions.stopLoop()
        end
    end)
end

-- Function to handle PetZoneAbility detection
function PetFunctions.onPetZoneAbility()
    if not autoMiddleEnabled then return end

    -- Update the last zone ability time
    lastZoneAbilityTime = tick()

    if delayTimer then
        task.cancel(delayTimer)
    end

    delayTimer = task.spawn(function()
        task.wait(ZONE_ABILITY_DELAY)
        if autoMiddleEnabled then
            PetFunctions.startLoop()
            task.wait(ZONE_ABILITY_LOOP_TIME)
            if autoMiddleEnabled then
                PetFunctions.stopLoop()
            end
        end
    end)
end

-- Function to handle Notification signal detection
function PetFunctions.onNotificationSignal()
    if not autoMiddleEnabled then return end

    -- Run the loop when notification signal is detected
    PetFunctions.startLoop()
    task.wait(INITIAL_LOOP_TIME)
    if autoMiddleEnabled then
        PetFunctions.stopLoop()
    end
end

-- Function to setup PetZoneAbility listener
function PetFunctions.setupZoneAbilityListener()
    if zoneAbilityConnection then
        zoneAbilityConnection:Disconnect()
    end
    zoneAbilityConnection = PetZoneAbility.OnClientEvent:Connect(PetFunctions.onPetZoneAbility)
end

-- Function to setup Notification listener
function PetFunctions.setupNotificationListener()
    if notificationConnection then
        notificationConnection:Disconnect()
    end
    notificationConnection = Notification.OnClientEvent:Connect(PetFunctions.onNotificationSignal)
end

-- Function to cleanup all timers and connections
function PetFunctions.cleanup()
    PetFunctions.stopLoop()

    if zoneAbilityConnection then
        zoneAbilityConnection:Disconnect()
        zoneAbilityConnection = nil
    end

    if notificationConnection then
        notificationConnection:Disconnect()
        notificationConnection = nil
    end

    if loopTimer then
        task.cancel(loopTimer)
        loopTimer = nil
    end
    if delayTimer then
        task.cancel(delayTimer)
        delayTimer = nil
    end

    -- Clean up ESP markers
    for petId, esp in pairs(excludedPetESPs) do
        if esp then
            esp:Destroy()
        end
    end
    excludedPetESPs = {}
end

-- Function to select all pets
function PetFunctions.selectAllPets()
    selectedPets = {}
    allPetsSelected = true
    local pets = PetFunctions.getAllPets()
    for _, pet in pairs(pets) do
        -- Don't select excluded pets
        if not PetFunctions.isPetExcluded(pet.id) then
            selectedPets[pet.id] = true
        end
    end
end

-- Function to update dropdown options
function PetFunctions.updateDropdownOptions()
    local pets = PetFunctions.getAllPets()
    currentPetsList = {}
    local dropdownOptions = {"None"}
    local petTypeGroups = {}

    -- Group pets by their type
    for i, pet in pairs(pets) do
        local petType = pet.name
        if not petTypeGroups[petType] then
            petTypeGroups[petType] = {}
        end
        table.insert(petTypeGroups[petType], pet)
    end

    -- Create dropdown options with grouped pets
    for petType, petGroup in pairs(petTypeGroups) do
        table.insert(dropdownOptions, petType)
        currentPetsList[petType] = petGroup -- Store the entire group
    end

    -- Update the dropdown options
    if petDropdown and petDropdown.Refresh then
        petDropdown:Refresh(dropdownOptions, true)
    end
end

-- Function to refresh pets and update ESP markers
function PetFunctions.refreshPets()
    selectedPets = {}
    allPetsSelected = false
    -- Re-initialize ActivePetUI references
    PetFunctions.initializeActivePetUI()
    local pets = PetFunctions.getAllPets()
    
    -- Update ESP markers for excluded pets
    PetFunctions.updateExcludedPetESPs()
    
    PetFunctions.updateDropdownOptions()
    return pets
end

-- Function to update ESP markers for all excluded pets
function PetFunctions.updateExcludedPetESPs()
    local pets = PetFunctions.getAllPets()
    
    -- Remove old ESP markers that no longer have corresponding pets
    for petId, esp in pairs(excludedPetESPs) do
        local petExists = false
        for _, pet in pairs(pets) do
            if pet.id == petId then
                petExists = true
                break
            end
        end
        if not petExists then
            PetFunctions.removeESPMarker(petId)
        end
    end
    
    -- Add ESP markers for excluded pets
    for _, pet in pairs(pets) do
        if PetFunctions.isPetExcluded(pet.id) then
            PetFunctions.createESPMarker(pet)
        end
    end
end

-- Helper functions for managing pet selection state
function PetFunctions.getSelectedPets()
    return selectedPets or {}
end

function PetFunctions.getExcludedPets()
    return excludedPets or {}
end

function PetFunctions.getAllPetsSelected()
    return allPetsSelected or false
end

function PetFunctions.setSelectedPets(pets)
    selectedPets = pets
end

function PetFunctions.setExcludedPets(pets)
    excludedPets = pets
    -- Update ESP markers when excluded pets change
    PetFunctions.updateExcludedPetESPs()
end

function PetFunctions.setAllPetsSelected(value)
    allPetsSelected = value
end

-- Function to select individual pets
function PetFunctions.selectPet(petId)
    if not selectedPets then
        selectedPets = {}
    end
    
    -- Don't select excluded pets
    if not PetFunctions.isPetExcluded(petId) then
        selectedPets[petId] = true
        allPetsSelected = false -- Individual selection means not all are selected
    end
end

-- Function to deselect individual pets
function PetFunctions.deselectPet(petId)
    if selectedPets then
        selectedPets[petId] = nil
    end
    allPetsSelected = false
end

-- Function to exclude pets
function PetFunctions.excludePet(petId)
    if not excludedPets then
        excludedPets = {}
    end
    
    excludedPets[petId] = true
    
    -- Remove from selected if it was selected
    if selectedPets then
        selectedPets[petId] = nil
    end
    
    -- Create ESP marker for this excluded pet
    local pets = PetFunctions.getAllPets()
    for _, pet in pairs(pets) do
        if pet.id == petId then
            PetFunctions.createESPMarker(pet)
            break
        end
    end
    
    -- If all pets were selected, we need to update the selection
    if allPetsSelected then
        PetFunctions.selectAllPets() -- This will re-select all non-excluded pets
    end
end

-- Function to unexclude pets
function PetFunctions.unexcludePet(petId)
    if excludedPets then
        excludedPets[petId] = nil
    end
    
    -- Remove ESP marker
    PetFunctions.removeESPMarker(petId)
    
    -- If all pets mode is on, select this pet too
    if allPetsSelected then
        selectedPets[petId] = true
    end
end

-- Helper functions for managing pet exclusions
function PetFunctions.isPetExcluded(petId)
    local mainExcludedPets = excludedPets or {}
    return mainExcludedPets[petId] == true
end

function PetFunctions.getExcludedPetCount()
    local mainExcludedPets = excludedPets or {}
    local count = 0
    for _ in pairs(mainExcludedPets) do
        count = count + 1
    end
    return count
end

function PetFunctions.getExcludedPetIds()
    local mainExcludedPets = excludedPets or {}
    local ids = {}
    for petId, _ in pairs(mainExcludedPets) do
        table.insert(ids, petId)
    end
    return ids
end

-- Getters and Setters
function PetFunctions.setAutoMiddleEnabled(enabled)
    autoMiddleEnabled = enabled
    if enabled then
        lastZoneAbilityTime = tick() -- Reset timer when enabling
        PetFunctions.setupNotificationListener()
    else
        if notificationConnection then
            notificationConnection:Disconnect()
            notificationConnection = nil
        end
    end
end

function PetFunctions.getAutoMiddleEnabled()
    return autoMiddleEnabled
end

function PetFunctions.setPetDropdown(dropdown)
    petDropdown = dropdown
end

function PetFunctions.getCurrentPetsList()
    return currentPetsList
end

-- Initialize the system with auto refresh
task.spawn(function()
    task.wait(1) -- Wait a moment for everything to load
    PetFunctions.initializeActivePetUI()
    PetFunctions.refreshPets()
end)

PetFunctions.updateDropdownOptions()

-- Make functions available globally if needed
_G.updateDropdownOptions = PetFunctions.updateDropdownOptions
_G.refreshPets = PetFunctions.refreshPets
_G.isPetExcluded = PetFunctions.isPetExcluded
_G.getExcludedPetCount = PetFunctions.getExcludedPetCount
_G.getExcludedPetIds = PetFunctions.getExcludedPetIds
_G.excludePet = PetFunctions.excludePet
_G.unexcludePet = PetFunctions.unexcludePet

return PetFunctions