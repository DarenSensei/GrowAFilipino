Misc = {}

function Misc.toggleBlackScreen(show)
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local existing = playerGui:FindFirstChild("BlackScreenGui")

    if show and not existing then
        -- Create ScreenGui
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "BlackScreenGui"
        screenGui.ResetOnSpawn = false
        screenGui.IgnoreGuiInset = true
        screenGui.Parent = playerGui

        -- Black Frame
        local blackFrame = Instance.new("Frame")
        blackFrame.Name = "BlackBackground"
        blackFrame.Size = UDim2.new(1, 0, 1, 0)
        blackFrame.Position = UDim2.new(0, 0, 0, 0)
        blackFrame.BackgroundColor3 = Color3.new(0, 0, 0)
        blackFrame.BackgroundTransparency = 0
        blackFrame.BorderSizePixel = 0
        blackFrame.Parent = screenGui

        -- Logo Image
        local logoImage = Instance.new("ImageLabel")
        logoImage.Name = "Logo"
        logoImage.Size = UDim2.new(0, 200, 0, 200)
        logoImage.Position = UDim2.new(0.5, -100, 0.5, -100)
        logoImage.BackgroundTransparency = 1
        logoImage.ImageTransparency = 0.6
        logoImage.Image = "rbxassetid://124132063885927"
        logoImage.ScaleType = Enum.ScaleType.Fit
        logoImage.Parent = blackFrame

        -- Close Button
        local closeButton = Instance.new("TextButton")
        closeButton.Name = "CloseButton"
        closeButton.Size = UDim2.new(0, 100, 0, 40)
        closeButton.Position = UDim2.new(1, -120, 0, 20)
        closeButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
        closeButton.BackgroundTransparency = 0.3
        closeButton.BorderSizePixel = 1
        closeButton.BorderColor3 = Color3.new(1, 1, 1)
        closeButton.Text = "Close"
        closeButton.TextColor3 = Color3.new(1, 1, 1)
        closeButton.TextScaled = true
        closeButton.Font = Enum.Font.SourceSans
        closeButton.Parent = blackFrame

        closeButton.MouseButton1Click:Connect(function()
            screenGui:Destroy()
        end)

    elseif not show and existing then
        existing:Destroy()
    end
end
