-- Egg ESP + Auto Steal + Go To My Plot
-- Original stable version loaded from commit 8086666efb5415867b274177b76259c389cceef0.
-- The plot navigation button is added after the original systems load.

local ORIGINAL_URL = "https://raw.githubusercontent.com/gomesdev007/Steal-an-egg-/8086666efb5415867b274177b76259c389cceef0/egg_esp_auto_steal_extracted.lua"

local ok, err = pcall(function()
    local source = game:HttpGet(ORIGINAL_URL)
    local fn = loadstring(source)
    if not fn then
        error("failed to load original script")
    end
    fn()
end)

if not ok then
    warn("Original Egg ESP + Auto Steal failed: " .. tostring(err))
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local function getMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end

    -- First try the same server state information used by the open-source system.
    local rf = ReplicatedStorage:FindFirstChild("RF")
    local homestead = rf and rf:FindFirstChild("Homestead")
    local askState = homestead and homestead:FindFirstChild("AskState")

    if askState then
        local success, state = pcall(function()
            return askState:InvokeServer()
        end)

        if success and type(state) == "table" then
            local ownerTables = {
                state.OwnersBySlot,
                state.SlotOwners,
                state.Owners,
                state.Slots,
            }

            for _, owners in ipairs(ownerTables) do
                if type(owners) == "table" then
                    for slot, owner in pairs(owners) do
                        local matches = owner == LocalPlayer.UserId
                            or tostring(owner) == tostring(LocalPlayer.UserId)
                            or owner == LocalPlayer.Name

                        if matches then
                            local candidate = plots:FindFirstChild(tostring(slot))
                            if candidate then
                                return candidate
                            end
                        end
                    end
                end
            end
        end
    end

    -- Fallback: look for the player's name/display name in the plot.
    for _, plot in ipairs(plots:GetChildren()) do
        local foundName = false
        for _, obj in ipairs(plot:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("StringValue") then
                local text = tostring(obj.Text or obj.Value or "")
                if text == LocalPlayer.Name or text == LocalPlayer.DisplayName
                    or text:find(LocalPlayer.Name, 1, true)
                    or text:find(LocalPlayer.DisplayName, 1, true) then
                    foundName = true
                    break
                end
            end
        end
        if foundName then
            return plot
        end
    end

    return nil
end

local function getPlotPosition(plot)
    if not plot then
        return nil
    end

    if plot:IsA("BasePart") then
        return plot.Position
    end

    if plot:IsA("Model") then
        if plot.PrimaryPart then
            return plot.PrimaryPart.Position
        end

        local okPivot, pivot = pcall(function()
            return plot:GetPivot()
        end)
        if okPivot and pivot then
            return pivot.Position
        end
    end

    for _, obj in ipairs(plot:GetDescendants()) do
        if obj:IsA("BasePart") then
            return obj.Position
        end
    end

    return nil
end

local function goToMyPlot()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local plot = getMyPlot()
    if not plot then
        warn("MY PLOT NOT FOUND")
        return
    end

    local position = getPlotPosition(plot)
    if not position then
        warn("MY PLOT POSITION NOT FOUND")
        return
    end

    humanoid:MoveTo(position)
end

local gui = Instance.new("ScreenGui")
gui.Name = "GoToMyPlotGui"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(150, 48)
frame.Position = UDim2.new(0, 12, 0.5, -24)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local button = Instance.new("TextButton")
button.Size = UDim2.new(1, -8, 1, -8)
button.Position = UDim2.fromOffset(4, 4)
button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
button.BorderSizePixel = 0
button.Text = "go to my plot"
button.TextColor3 = Color3.fromRGB(235, 235, 235)
button.TextSize = 14
button.Font = Enum.Font.GothamMedium
button.Parent = frame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = button

button.MouseButton1Click:Connect(goToMyPlot)

local dragging = false
local dragStart
local startPos

local function updateDrag(input)
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        updateDrag(input)
    end
end)
