local Misc = {}

function Misc.toggleBlackScreen()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild("BlackScreenGui")

    if show and not existing then
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "BlackScreenGui"
        screenGui.ResetOnSpawn = false
        screenGui.IgnoreGuiInset = true
        screenGui.Parent = playerGui

        local blackFrame = Instance.new("Frame")
        blackFrame.Name = "BlackBackground"
        blackFrame.Size = UDim2.new(1, 0, 1, 0)
        blackFrame.Position = UDim2.new(0, 0, 0, 0)
        blackFrame.BackgroundColor3 = Color3.new(0, 0, 0)
        blackFrame.BackgroundTransparency = 0
        blackFrame.BorderSizePixel = 0
        blackFrame.Parent = screenGui

        local logoImage = Instance.new("ImageLabel")
        logoImage.Name = "Logo"
        logoImage.Size = UDim2.new(0, 200, 0, 200)
        logoImage.Position = UDim2.new(0.5, -100, 0.5, -100)
        logoImage.BackgroundTransparency = 1
        logoImage.ImageTransparency = 0.6
        logoImage.Image = "rbxassetid://124132063885927"
        logoImage.ScaleType = Enum.ScaleType.Fit
        logoImage.Parent = blackFrame

    elseif not show and existing then
        existing:Destroy()
    end
end

-- ✅ Don't forget this line!
return Misc
