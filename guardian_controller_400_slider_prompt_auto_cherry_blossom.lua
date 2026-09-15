local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

local SPEED = 420
local MIN_SPEED = 50
local MAX_SPEED = 500
local PAUSE_POSITION = Vector3.new(594, 71, -373)
local DESTINATION = Vector3.new(497, 71, -354)

-- movement method from uploaded file
local PROBE_LOW = 7
local PROBE_HIGH = 160
local PROBE_DOWN = 420
local STEP_MAX = 6

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true

local function getMovingPart(clone)
    if not clone or not clone.Parent then return nil end
    local part = clone:FindFirstChild("HumanoidRootPart", true)
    if part and part:IsA("BasePart") then return part end
    if clone.PrimaryPart and clone.PrimaryPart:IsA("BasePart") then return clone.PrimaryPart end
    return clone:FindFirstChildWhichIsA("BasePart", true)
end

local function moveGuardian(clone, target, speed)
    local part = getMovingPart(clone)
    if not part then return false end

    speed = math.max(60, speed or 420)
    local current = clone:GetPivot().Position
    local offset = Vector3.new(target.X - current.X, 0, target.Z - current.Z)
    local magnitude = offset.Magnitude
    if magnitude <= 0.5 then return true end

    local unit = offset.Unit
    local rotation = CFrame.lookAt(Vector3.zero, unit).Rotation
    local number = 0
    local startY = current.Y
    local timeout = os.clock() + magnitude / math.max(speed, 1) + 15

    while clone and clone.Parent and os.clock() < timeout do
        local dt = RunService.Heartbeat:Wait()
        part = getMovingPart(clone)
        if not part then return false end

        local quotientNumber = math.min(speed * math.min(dt, 0.1), magnitude - number)
        local steps = math.max(1, math.ceil(quotientNumber / STEP_MAX))
        local quotient = quotientNumber / steps

        for _ = 1, steps do
            number = math.min(magnitude, number + quotient)
            if number >= magnitude then break end
        end

        local nextPosition = Vector3.new(
            current.X + unit.X * number,
            startY,
            current.Z + unit.Z * number
        )

        pcall(function()
            clone:PivotTo(CFrame.new(nextPosition) * rotation)
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end)

        if number >= magnitude - 0.01 then
            return true
        end
    end

    return false
end

print("Guardian movement updated - destinations preserved:", PAUSE_POSITION, DESTINATION)