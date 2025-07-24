-- Local Player

-- NO-CLIP
local LocalPlayer = {}

local player = game.Players.LocalPlayer
local noClip = false

-- Function to apply No-Clip to the character
local function applyNoClip(character)
    if not character then return end
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = not noClip
        end
    end
    if character:FindFirstChild("HumanoidRootPart") then
        character.HumanoidRootPart.CanCollide = not noClip
    end
end

-- External function to enable/disable No-Clip mode
function LocalPlayer.setNoClip(enabled)
    noClip = enabled
    applyNoClip(player.Character)
end

-- Monitor player character for No-Clip application
player.CharacterAdded:Connect(function(character)
    character.DescendantAdded:Connect(function(descendant)
        if noClip and descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
            descendant.CanCollide = false
        end
    end)
    applyNoClip(character)
end)

return LocalPlayer
