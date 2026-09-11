-- GUI Dark Arrastável para Steal an Egg com Toggle Total
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Estados das funções
local states = {
	instantPickup = false,
	antiRagdoll = false
}

-- ===== UTILITY INSTANT PICKUP =====
local instantPickupUtility = {
	ProximityPromptService = game:GetService("ProximityPromptService"),
	Players = game:GetService("Players"),
	conns = {},
}

function instantPickupUtility:bind(connection, callback)
	local s, r = pcall(function(...)
		local conn = connection:Connect(callback)
		self.conns[conn] = conn
		return self.conns[conn]
	end)
	if s and r then
		return r
	end
	return warn('failed to bind connection error: '..tostring(r))
end

function instantPickupUtility:unbind(connection)
	local s, r = pcall(function(...)
		local conn = self.conns[connection]
		if conn then
			conn:Disconnect()
			self.conns[connection] = nil
			return true
		end
		return false
	end)
	if s and r then
		return true
	end
	return warn("failed to unbind")
end

function instantPickupUtility:init()
	self.LocalPlayer = self.Players.LocalPlayer
	if not self.LocalPlayer then
		warn('failed to get localplayer')
		return false
	end

	local connection = self:bind(self.ProximityPromptService.PromptButtonHoldBegan, function(ProximityPrompt, Player)
		if Player == self.LocalPlayer and tostring(ProximityPrompt) == "CarryAreaEgg" then
			ProximityPrompt.HoldDuration = 0
		end
	end)

	if not connection then
		warn("failed to create connection")
		return false
	end

	print("✅ Instant Pickup init success")
	return true
end

function instantPickupUtility:activate()
	if states.instantPickup then
		print("Instant Pickup já está ativo")
		return true
	end
	
	local result = self:init()
	return result
end

function instantPickupUtility:deactivate()
	if not states.instantPickup then
		print("Instant Pickup já está desativo")
		return true
	end
	
	-- Desconectar todas as conexões
	for conn, _ in pairs(self.conns) do
		self:unbind(conn)
	end
	
	print("❌ Instant Pickup desativado!")
	return true
end

-- ===== UTILITY ANTI RAGDOLL =====
local antiRagdollUtility = {
	Players = game:GetService("Players"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	conns = {},
	active = false
}

antiRagdollUtility.GetConnections = function(obj, signal)
	local s, r = pcall(function(...)
		return getconnections(obj[signal])
	end)
	if s and r then
		return r    
	end

	warn("failed to getconnections error: "..tostring(r))
	return nil
end

antiRagdollUtility.Disconnect = function(conns)
	local s, r = pcall(function(...)
		local patched = 0

		for _, conn in next, conns do   
			conn:Disconnect()
			patched +=1
		end

		return patched
	end)
	if s and r ~= 0 then
		return "patched: "..tostring(r).. " connections"  
	end
	return "patched nothing: "..tostring(r)
end

function antiRagdollUtility:init()
	self.LocalPlayer = self.Players.LocalPlayer
	if not self.LocalPlayer then
		warn('failed to get localplayer')
		return false
	end

	if not getconnections then
		warn("Unsupported executor missing getconnections")
		return false
	end

	self.Packages = self.ReplicatedStorage:FindFirstChild("Packages")
	if not self.Packages then
		warn('failed to get Packages')
		return false
	end

	self.Networking = self.Packages:FindFirstChild("Networking")
	if not self.Networking then
		warn('failed to get Networking')
		return false
	end

	self["RE/RigSync/Refresh"] = self.Networking:FindFirstChild("RE/RigSync/Refresh")
	if not self["RE/RigSync/Refresh"] then
		warn('failed to get RE/RigSync/Refresh')
		return false
	end

	self.connections = self.GetConnections(self["RE/RigSync/Refresh"], "OnClientEvent")
	if not self.connections then
		warn('failed to get connections')
		return false
	end

	print(self.Disconnect(self.connections))
	return true
end

function antiRagdollUtility:activate()
	if self.active then
		print("Anti Ragdoll já está ativo")
		return true
	end
	
	local result = self:init()
	if result then
		self.active = true
		print("✅ Anti Ragdoll ativado!")
		return true
	else
		print("❌ Erro ao ativar Anti Ragdoll")
		return false
	end
end

function antiRagdollUtility:deactivate()
	if not self.active then
		print("Anti Ragdoll já está desativo")
		return true
	end
	
	-- Reinicializar estado
	self.active = false
	self.connections = nil
	print("❌ Anti Ragdoll desativado!")
	return true
end

-- ===== GUI SETUP =====
-- Criar ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StealEggGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Criar Frame principal (Totalmente Preto)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 180)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -90)
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Adicionar UICorner para bordas arredondadas
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Titulo
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
titleLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "🥚 Steal an Egg"
titleLabel.BorderSizePixel = 0
titleLabel.Parent = mainFrame

-- Adicionar corner ao título
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleLabel

-- Botão Instant Pickup (Preto)
local instantPickupButton = Instance.new("TextButton")
instantPickupButton.Name = "InstantPickup"
instantPickupButton.Size = UDim2.new(0.5, -5, 0, 45)
instantPickupButton.Position = UDim2.new(0, 5, 0, 45)
instantPickupButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
instantPickupButton.TextColor3 = Color3.fromRGB(255, 255, 255)
instantPickupButton.TextSize = 13
instantPickupButton.Font = Enum.Font.GothamSemibold
instantPickupButton.Text = "⚡ Instant Pickup"
instantPickupButton.BorderSizePixel = 0
instantPickupButton.Parent = mainFrame

local buttonCorner1 = Instance.new("UICorner")
buttonCorner1.CornerRadius = UDim.new(0, 6)
buttonCorner1.Parent = instantPickupButton

-- Stroke para o botão Instant Pickup
local stroke1 = Instance.new("UIStroke")
stroke1.Color = Color3.fromRGB(100, 150, 200)
stroke1.Thickness = 2
stroke1.Parent = instantPickupButton

-- Botão Anti Ragdoll (Preto)
local antiRagdollButton = Instance.new("TextButton")
antiRagdollButton.Name = "AntiRagdoll"
antiRagdollButton.Size = UDim2.new(0.5, -5, 0, 45)
antiRagdollButton.Position = UDim2.new(0.5, 5, 0, 45)
antiRagdollButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
antiRagdollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
antiRagdollButton.TextSize = 13
antiRagdollButton.Font = Enum.Font.GothamSemibold
antiRagdollButton.Text = "🛡️ Anti Ragdoll"
antiRagdollButton.BorderSizePixel = 0
antiRagdollButton.Parent = mainFrame

local buttonCorner2 = Instance.new("UICorner")
buttonCorner2.CornerRadius = UDim.new(0, 6)
buttonCorner2.Parent = antiRagdollButton

-- Stroke para o botão Anti Ragdoll
local stroke2 = Instance.new("UIStroke")
stroke2.Color = Color3.fromRGB(220, 150, 100)
stroke2.Thickness = 2
stroke2.Parent = antiRagdollButton

-- Botão fechar/minimizar (Preto)
local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 16
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "×"
closeButton.BorderSizePixel = 0
closeButton.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

-- Stroke para o botão Fechar
local strokeClose = Instance.new("UIStroke")
strokeClose.Color = Color3.fromRGB(255, 100, 100)
strokeClose.Thickness = 2
strokeClose.Parent = closeButton

-- ===== DRAG FUNCTIONALITY =====
local dragging = false
local dragInput
local dragStart
local startPos

local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mouse = player:GetMouse()
		local mousePos = Vector2.new(mouse.X, mouse.Y)
		
		if mousePos.Y >= mainFrame.AbsolutePosition.Y and 
		   mousePos.Y <= mainFrame.AbsolutePosition.Y + titleLabel.AbsoluteSize.Y and
		   mousePos.X >= mainFrame.AbsolutePosition.X and
		   mousePos.X <= mainFrame.AbsolutePosition.X + mainFrame.AbsoluteSize.X then
			dragging = true
			dragStart = mousePos
			startPos = mainFrame.Position
		end
	end
end

local function onInputChanged(input, gameProcessed)
	if not dragging then return end
	
	local mouse = player:GetMouse()
	local mousePos = Vector2.new(mouse.X, mouse.Y)
	local delta = mousePos - dragStart
	
	mainFrame.Position = UDim2.new(
		startPos.X.Scale,
		startPos.X.Offset + delta.X,
		startPos.Y.Scale,
		startPos.Y.Offset + delta.Y
	)
end

local function onInputEnded(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end

UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputChanged:Connect(onInputChanged)
UserInputService.InputEnded:Connect(onInputEnded)

-- ===== HOVER EFFECTS =====
local function createHoverEffect(button, strokeColor)
	local originalStroke = button:FindFirstChild("UIStroke")
	if not originalStroke then return end
	
	local originalThickness = originalStroke.Thickness
	
	button.MouseEnter:Connect(function()
		if originalStroke then
			originalStroke.Thickness = 3
		end
	end)
	
	button.MouseLeave:Connect(function()
		if originalStroke then
			originalStroke.Thickness = originalThickness
		end
	end)
end

createHoverEffect(instantPickupButton)
createHoverEffect(antiRagdollButton)
createHoverEffect(closeButton)

-- ===== BUTTON CALLBACKS =====

-- Função Instant Pickup (Toggle)
instantPickupButton.MouseButton1Click:Connect(function()
	if states.instantPickup then
		-- Desativar
		states.instantPickup = false
		instantPickupUtility:deactivate()
		instantPickupButton.Text = "⚡ Instant Pickup"
		instantPickupButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		local stroke = instantPickupButton:FindFirstChild("UIStroke")
		if stroke then stroke.Color = Color3.fromRGB(100, 150, 200) end
	else
		-- Ativar
		instantPickupButton.Text = "⏳ Carregando..."
		instantPickupButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		
		if instantPickupUtility:activate() then
			states.instantPickup = true
			instantPickupButton.Text = "✅ Instant Pickup"
			instantPickupButton.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
			local stroke = instantPickupButton:FindFirstChild("UIStroke")
			if stroke then stroke.Color = Color3.fromRGB(100, 255, 100) end
			wait(1.5)
			instantPickupButton.Text = "⚡ Instant Pickup (Ativo)"
			instantPickupButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		else
			instantPickupButton.Text = "❌ Erro!"
			instantPickupButton.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
			local stroke = instantPickupButton:FindFirstChild("UIStroke")
			if stroke then stroke.Color = Color3.fromRGB(255, 100, 100) end
			wait(2)
			instantPickupButton.Text = "⚡ Instant Pickup"
			instantPickupButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
			stroke.Color = Color3.fromRGB(100, 150, 200)
		end
	end
end)

-- Função Anti Ragdoll (Toggle)
antiRagdollButton.MouseButton1Click:Connect(function()
	if states.antiRagdoll then
		-- Desativar
		states.antiRagdoll = false
		antiRagdollUtility:deactivate()
		antiRagdollButton.Text = "🛡️ Anti Ragdoll"
		antiRagdollButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		local stroke = antiRagdollButton:FindFirstChild("UIStroke")
		if stroke then stroke.Color = Color3.fromRGB(220, 150, 100) end
	else
		-- Ativar
		antiRagdollButton.Text = "⏳ Carregando..."
		antiRagdollButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		
		if antiRagdollUtility:activate() then
			states.antiRagdoll = true
			antiRagdollButton.Text = "✅ Anti Ragdoll"
			antiRagdollButton.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
			local stroke = antiRagdollButton:FindFirstChild("UIStroke")
			if stroke then stroke.Color = Color3.fromRGB(100, 255, 100) end
			wait(1.5)
			antiRagdollButton.Text = "🛡️ Anti Ragdoll (Ativo)"
			antiRagdollButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		else
			antiRagdollButton.Text = "❌ Erro!"
			antiRagdollButton.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
			local stroke = antiRagdollButton:FindFirstChild("UIStroke")
			if stroke then stroke.Color = Color3.fromRGB(255, 100, 100) end
			wait(2)
			antiRagdollButton.Text = "🛡️ Anti Ragdoll"
			antiRagdollButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
			stroke.Color = Color3.fromRGB(220, 150, 100)
		end
	end
end)

-- Botão fechar
closeButton.MouseButton1Click:Connect(function()
	screenGui:Destroy()
	print("GUI fechada!")
end)

print("✅ GUI Steal an Egg carregada com sucesso!")
print("💡 Clique nos botões para ativar/desativar as funções")
print("🖱️ Arraste pelo título para mover a janela")