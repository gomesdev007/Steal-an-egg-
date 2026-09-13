-- Egg ESP + Auto Steal + Go To My Plot
-- Preserves the original stable version from commit 8086666efb5415867b274177b76259c389cceef0

local ORIGINAL_URL = "https://raw.githubusercontent.com/gomesdev007/Steal-an-egg-/8086666efb5415867b274177b76259c389cceef0/egg_esp_auto_steal_extracted.lua"

local ok, err = pcall(function()
    loadstring(game:HttpGet(ORIGINAL_URL))()
end)

if not ok then
    warn("Failed to load original script:", err)
    return
end

task.spawn(function()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = Players.LocalPlayer

    local function getMyPlot()
        local plots = workspace:FindFirstChild("Plots")
        if not plots then
            return nil
        end

        -- Try the game's state remote first.
        local okState, state = pcall(function()
            local rf = ReplicatedStorage:FindFirstChild("RF")
            local homestead = rf and rf:FindFirstChild("Homestead")
            local askState = homestead and homestead:FindFirstChild("AskState")
            if askState and askState:IsA("RemoteFunction") then
                return askState:InvokeServer()
            end
        end)

        if okState and type(state) == "table" then
            local ownerTables = {
                state.OwnersBySlot,
                state.SlotOwners,
                state.Owners,
                state.Slots
            }

            for _, owners in ipairs(ownerTables) do
                if type(owners) == "table" then
                    for slot, owner in pairs(owners) do
                        local matches = false
                        if type(owner) == "number" then
                            matches = owner == LocalPlayer.UserId
                        elseif type(owner) == "string" then
                            matches = owner == tostring(LocalPlayer.UserId) or owner == LocalPlayer.Name
                        elseif type(owner) == "table" then
                            matches = owner.UserId == LocalPlayer.UserId or owner.Name == LocalPlayer.Name
                        end

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

        -- Fallback: locate the plot whose visible text contains the player's name.
        for _, plot in ipairs(plots:GetChildren()) do
            for _, obj in ipairs(plot:GetDescendants()) do
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    local text = string.lower(obj.Text or "")
                    if text:find(string.lower(LocalPlayer.Name), 1, true) or
                       (LocalPlayer.DisplayName ~= LocalPlayer.Name and text:find(string.lower(LocalPlayer.DisplayName), 1, true)) then
                        return plot
                    end
                end
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

    local button = Instance.new("TextButton")
    button.Name = "GoToMyPlot"
    button.Size = UDim2.fromOffset(150, 38)
    button.Position = UDim2.new(0, 12, 0.5, 0)
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.TextColor3 = Color3.fromRGB(235, 235, 235)
    button.Text = "go to my plot"
    button.TextSize = 14
    button.Font = Enum.Font.Gotham
    button.AutoButtonColor = true
    button.BorderSizePixel = 0
    button.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    button.Activated:Connect(goToMyPlot)
end)