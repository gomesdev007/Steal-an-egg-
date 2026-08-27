local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer

local POS2 = Vector3.new(514.74, 70.57, -365.25)

--==================================================
-- CONFIG
--==================================================

local TEMPO_ESPERA_DESTINO = 1.3
local PROMPT_COOLDOWN = 0.15

-- Proteção contra múltiplas recuperações
local INTERVALO_RECUPERACAO = 0.5
local TEMPO_MAXIMO_ESPERA_INTERRUPCAO = 3

--==================================================
-- POSIÇÕES
--==================================================

local Positions = {
    [1] = Vector3.new(586.69, 70.57, -323.43),
    [2] = Vector3.new(744.43, 70.57, -409.91),
    [3] = Vector3.new(953.64, 70.57, -320.68),
    [4] = Vector3.new(1189.46, 70.57, -408.11),
    [5] = Vector3.new(1497.20, 70.57, -311.09),
    [6] = Vector3.new(1879.72, 70.57, -396.42),
    [7] = Vector3.new(2284.08, 70.57, -329.22),
    [8] = Vector3.new(2813.06, 70.57, -397.42),
    [9] = Vector3.new(3392.44, 70.57, -323.93),
    [10] = Vector3.new(4032.04, 70.57, -400.21),
}

local selectedPosition = 2

--==================================================
-- ESTADOS
--==================================================

local ativo = false
local autoLeft = false

local autoDestino = nil
local autoEsperandoPrompt = false
local autoIndoPOS2 = false

local esperandoDestino = false

local movimentoToken = 0

local align = nil
local attachment = nil

local controles = nil
local controlsDisabled = false

-- Animações ficam desativadas depois da primeira ativação
local animacaoDesativada = false

-- Proteção da recuperação
local processandoInterrupcao = false
local ultimaInterrupcao = 0

--==================================================
-- CONEXÕES
--==================================================

local autoStealConnection = nil
local promptTriggeredConnection = nil

--==================================================
-- PROMPTS
--==================================================

local promptDelays = {}
local promptCooldown = {}

--==================================================
-- GET CHARACTER
--==================================================

local function pegar()

    local character = player.Character

    if not character then
        return nil
    end

    local humanoid =
        character:FindFirstChildOfClass("Humanoid")

    local root =
        character:FindFirstChild("HumanoidRootPart")

    if humanoid and root then
        return character, humanoid, root
    end

    return nil
end

--==================================================
-- ANIMAÇÕES
--==================================================

local function pararTodasAnimacoes()

    if not animacaoDesativada then
        return
    end

    local character = player.Character

    if not character then
        return
    end

    local humanoid =
        character:FindFirstChildOfClass("Humanoid")

    if not humanoid then
        return
    end

    local animator =
        humanoid:FindFirstChildOfClass("Animator")

    if not animator then
        return
    end

    for _, track in ipairs(
        animator:GetPlayingAnimationTracks()
    ) do

        pcall(function()
            track:Stop(0)
        end)

    end
end

--==================================================
-- MONITOR DE ANIMAÇÕES
--==================================================

task.spawn(function()

    while true do

        task.wait(0.08)

        if animacaoDesativada then
            pararTodasAnimacoes()
        end

    end

end)

--==================================================
-- CONFIGURAR PROMPT
--==================================================

local function configurarPrompt(prompt)

    if not prompt
        or not prompt:IsA("ProximityPrompt") then
        return
    end

    if promptDelays[prompt] == nil then
        promptDelays[prompt] =
            prompt.HoldDuration
    end

    if prompt.HoldDuration ~= 0 then
        prompt.HoldDuration = 0
    end

end

--==================================================
-- RESTAURAR PROMPTS
--==================================================

local function restaurarPrompts()

    for prompt, delay in pairs(promptDelays) do

        if prompt and prompt.Parent then

            pcall(function()
                prompt.HoldDuration = delay
            end)

        end

    end

    table.clear(promptDelays)
    table.clear(promptCooldown)

end

--==================================================
-- GET CONTROLS
--==================================================

local function obterControles()

    if controles then
        return controles
    end

    local success, result = pcall(function()

        local playerScripts =
            player:WaitForChild(
                "PlayerScripts",
                10
            )

        if not playerScripts then
            return nil
        end

        local playerModule =
            playerScripts:WaitForChild(
                "PlayerModule",
                10
            )

        if not playerModule then
            return nil
        end

        local module =
            require(playerModule)

        return module:GetControls()

    end)

    if success and result then

        controles = result

        return result

    end

    return nil
end

--==================================================
-- GUI
--==================================================

local gui = Instance.new("ScreenGui")
gui.Name = "AutoStealGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior =
    Enum.ZIndexBehavior.Sibling

gui.Parent =
    player:WaitForChild("PlayerGui")

--==================================================
-- MAIN FRAME
--==================================================

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size =
    UDim2.fromOffset(210, 178)

frame.Position =
    UDim2.new(
        0.5,
        -105,
        0.5,
        -89
    )

frame.BackgroundColor3 =
    Color3.fromRGB(13, 13, 17)

frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

local frameCorner =
    Instance.new("UICorner")

frameCorner.CornerRadius =
    UDim.new(0, 15)

frameCorner.Parent = frame

local stroke =
    Instance.new("UIStroke")

stroke.Color =
    Color3.fromRGB(55, 55, 65)

stroke.Thickness = 1
stroke.Transparency = 0.1
stroke.Parent = frame

--==================================================
-- TITLE
--==================================================

local title =
    Instance.new("TextLabel")

title.Name = "Title"
title.Size =
    UDim2.new(1, -24, 0, 24)

title.Position =
    UDim2.fromOffset(12, 7)

title.BackgroundTransparency = 1
title.Text = "AUTO STEAL"

title.TextColor3 =
    Color3.fromRGB(
        248,
        248,
        250
    )

title.TextSize = 15
title.Font =
    Enum.Font.GothamBold

title.TextXAlignment =
    Enum.TextXAlignment.Left

title.TextYAlignment =
    Enum.TextYAlignment.Center

title.TextTruncate =
    Enum.TextTruncate.AtEnd

title.Parent = frame

local creator =
    Instance.new("TextLabel")

creator.Name = "Creator"

creator.Size =
    UDim2.new(1, -24, 0, 14)

creator.Position =
    UDim2.fromOffset(12, 28)

creator.BackgroundTransparency = 1
creator.Text = "BY GOMESFFXP7"

creator.TextColor3 =
    Color3.fromRGB(
        120,
        120,
        130
    )

creator.TextSize = 8

creator.Font =
    Enum.Font.GothamMedium

creator.TextXAlignment =
    Enum.TextXAlignment.Left

creator.Parent = frame

--==================================================
-- STATUS
--==================================================

local status =
    Instance.new("TextLabel")

status.Size =
    UDim2.new(1, -24, 0, 16)

status.Position =
    UDim2.fromOffset(12, 42)

status.BackgroundTransparency = 1
status.Text = "● INACTIVE"

status.TextColor3 =
    Color3.fromRGB(
        145,
        145,
        150
    )

status.TextSize = 9

status.Font =
    Enum.Font.GothamMedium

status.TextXAlignment =
    Enum.TextXAlignment.Left

status.Parent = frame

--==================================================
-- ENABLE BUTTON
--==================================================

local button =
    Instance.new("TextButton")

button.Name = "ManualButton"

button.Size =
    UDim2.new(1, -24, 0, 34)

button.Position =
    UDim2.fromOffset(12, 61)

button.BackgroundColor3 =
    Color3.fromRGB(
        29,
        29,
        35
    )

button.BorderSizePixel = 0
button.Text = "ENABLE"

button.TextColor3 =
    Color3.fromRGB(
        235,
        235,
        238
    )

button.TextSize = 11

button.Font =
    Enum.Font.GothamBold

button.AutoButtonColor = false
button.Parent = frame

local buttonCorner =
    Instance.new("UICorner")

buttonCorner.CornerRadius =
    UDim.new(0, 9)

buttonCorner.Parent = button

local buttonStroke =
    Instance.new("UIStroke")

buttonStroke.Color =
    Color3.fromRGB(
        55,
        55,
        65
    )

buttonStroke.Thickness = 1
buttonStroke.Transparency = 0.15
buttonStroke.Parent = button

--==================================================
-- AUTO STEAL BUTTON
--==================================================

local autoButton =
    Instance.new("TextButton")

autoButton.Name =
    "AutoButton"

autoButton.Size =
    UDim2.new(1, -24, 0, 34)

autoButton.Position =
    UDim2.fromOffset(12, 101)

autoButton.BackgroundColor3 =
    Color3.fromRGB(
        29,
        29,
        35
    )

autoButton.BorderSizePixel = 0
autoButton.Text =
    "AUTO STEAL: OFF"

autoButton.TextColor3 =
    Color3.fromRGB(
        235,
        235,
        238
    )

autoButton.TextSize = 10

autoButton.Font =
    Enum.Font.GothamBold

autoButton.AutoButtonColor = false
autoButton.Parent = frame

local autoCorner =
    Instance.new("UICorner")

autoCorner.CornerRadius =
    UDim.new(0, 9)

autoCorner.Parent = autoButton

local autoStroke =
    Instance.new("UIStroke")

autoStroke.Color =
    Color3.fromRGB(
        55,
        55,
        65
    )

autoStroke.Thickness = 1
autoStroke.Transparency = 0.15
autoStroke.Parent = autoButton

--==================================================
-- POSITION SELECTOR
--==================================================

local positionButton =
    Instance.new("TextButton")

positionButton.Name =
    "PositionSelector"

positionButton.Size =
    UDim2.new(1, -24, 0, 30)

positionButton.Position =
    UDim2.fromOffset(12, 141)

positionButton.BackgroundColor3 =
    Color3.fromRGB(
        23,
        23,
        29
    )

positionButton.BorderSizePixel = 0
positionButton.Text = ""

positionButton.AutoButtonColor = false
positionButton.Parent = frame

local positionCorner =
    Instance.new("UICorner")

positionCorner.CornerRadius =
    UDim.new(0, 9)

positionCorner.Parent = positionButton

local positionStroke =
    Instance.new("UIStroke")

positionStroke.Color =
    Color3.fromRGB(
        55,
        55,
        65
    )

positionStroke.Thickness = 1
positionStroke.Transparency = 0.1
positionStroke.Parent = positionButton

local positionText =
    Instance.new("TextLabel")

positionText.Size =
    UDim2.new(1, -42, 1, 0)

positionText.Position =
    UDim2.fromOffset(12, 0)

positionText.BackgroundTransparency = 1
positionText.Text =
    "POSITION 2"

positionText.TextColor3 =
    Color3.fromRGB(
        225,
        225,
        230
    )

positionText.TextSize = 10

positionText.Font =
    Enum.Font.GothamBold

positionText.TextXAlignment =
    Enum.TextXAlignment.Left

positionText.Parent =
    positionButton

local arrow =
    Instance.new("TextLabel")

arrow.Size =
    UDim2.fromOffset(25, 30)

arrow.Position =
    UDim2.new(
        1,
        -30,
        0,
        0
    )

arrow.BackgroundTransparency = 1
arrow.Text = "⌄"

arrow.TextColor3 =
    Color3.fromRGB(
        150,
        150,
        160
    )

arrow.TextSize = 15

arrow.Font =
    Enum.Font.GothamBold

arrow.Parent =
    positionButton

--==================================================
-- POSITION LIST
--==================================================

local positionList =
    Instance.new("ScrollingFrame")

positionList.Name =
    "PositionList"

positionList.Size =
    UDim2.new(
        1,
        -24,
        0,
        0
    )

positionList.Position =
    UDim2.fromOffset(
        12,
        174
    )

positionList.BackgroundColor3 =
    Color3.fromRGB(
        19,
        19,
        24
    )

positionList.BorderSizePixel = 0
positionList.Visible = false
positionList.ZIndex = 50
positionList.ClipsDescendants = true

positionList.CanvasSize =
    UDim2.fromOffset(
        0,
        0
    )

positionList.ScrollBarThickness = 3

positionList.ScrollBarImageColor3 =
    Color3.fromRGB(
        90,
        90,
        100
    )

positionList.ScrollingDirection =
    Enum.ScrollingDirection.Y

positionList.VerticalScrollBarInset =
    Enum.ScrollBarInset.ScrollBar

positionList.Parent = frame

local listCorner =
    Instance.new("UICorner")

listCorner.CornerRadius =
    UDim.new(0, 10)

listCorner.Parent =
    positionList

local listStroke =
    Instance.new("UIStroke")

listStroke.Color =
    Color3.fromRGB(
        55,
        55,
        65
    )

listStroke.Thickness = 1
listStroke.Parent =
    positionList

local listLayout =
    Instance.new("UIListLayout")

listLayout.Padding =
    UDim.new(0, 3)

listLayout.HorizontalAlignment =
    Enum.HorizontalAlignment.Center

listLayout.SortOrder =
    Enum.SortOrder.LayoutOrder

listLayout.Parent =
    positionList

local listPadding =
    Instance.new("UIPadding")

listPadding.PaddingTop =
    UDim.new(0, 6)

listPadding.PaddingBottom =
    UDim.new(0, 6)

listPadding.Parent =
    positionList

local positionOptions = {}

listLayout:GetPropertyChangedSignal(
    "AbsoluteContentSize"
):Connect(function()

    positionList.CanvasSize =
        UDim2.fromOffset(
            0,
            listLayout.AbsoluteContentSize.Y + 12
        )

end)

--==================================================
-- ATUALIZAR POSIÇÕES
--==================================================

local function atualizarPosicoes()

    for i = 1, 10 do

        local option =
            positionOptions[i]

        if option then

            local label =
                option:FindFirstChild("Label")

            if i == selectedPosition then

                option.BackgroundColor3 =
                    Color3.fromRGB(
                        38,
                        65,
                        47
                    )

                if label then

                    label.TextColor3 =
                        Color3.fromRGB(
                            105,
                            235,
                            135
                        )

                end

            else

                option.BackgroundColor3 =
                    Color3.fromRGB(
                        27,
                        27,
                        33
                    )

                if label then

                    label.TextColor3 =
                        Color3.fromRGB(
                            205,
                            205,
                            212
                        )

                end

            end

        end

    end

end

--==================================================
-- CRIAR POSIÇÕES
--==================================================

for i = 1, 10 do

    local option =
        Instance.new("TextButton")

    option.Name =
        "Position" .. i

    option.LayoutOrder = i

    option.Size =
        UDim2.new(
            1,
            -12,
            0,
            27
        )

    option.BackgroundColor3 =
        Color3.fromRGB(
            27,
            27,
            33
        )

    option.BorderSizePixel = 0
    option.Text = ""
    option.AutoButtonColor = false
    option.ZIndex = 51

    option.Parent =
        positionList

    local corner =
        Instance.new("UICorner")

    corner.CornerRadius =
        UDim.new(0, 7)

    corner.Parent =
        option

    local label =
        Instance.new("TextLabel")

    label.Name = "Label"

    label.Size =
        UDim2.new(
            1,
            -20,
            1,
            0
        )

    label.Position =
        UDim2.fromOffset(
            10,
            0
        )

    label.BackgroundTransparency = 1

    label.Text =
        "POSITION " .. i

    label.TextColor3 =
        Color3.fromRGB(
            205,
            205,
            212
        )

    label.TextSize = 9

    label.Font =
        Enum.Font.GothamMedium

    label.TextXAlignment =
        Enum.TextXAlignment.Left

    label.ZIndex = 52

    label.Parent =
        option

    positionOptions[i] =
        option

    option.Activated:Connect(function()

        selectedPosition = i

        positionText.Text =
            "POSITION " .. i

        positionList.Visible =
            false

        positionList.Size =
            UDim2.new(
                1,
                -24,
                0,
                0
            )

        positionList.CanvasPosition =
            Vector2.new(
                0,
                0
            )

        arrow.Text = "⌄"

        atualizarPosicoes()

    end)

end

atualizarPosicoes()

--==================================================
-- ABRIR / FECHAR LISTA
--==================================================

local listaAberta = false

positionButton.Activated:Connect(function()

    listaAberta =
        not listaAberta

    positionList.Visible =
        listaAberta

    if listaAberta then

        positionList.Size =
            UDim2.new(
                1,
                -24,
                0,
                120
            )

        positionList.CanvasPosition =
            Vector2.new(
                0,
                0
            )

        arrow.Text = "⌃"

    else

        positionList.Size =
            UDim2.new(
                1,
                -24,
                0,
                0
            )

        arrow.Text = "⌄"

    end

end)

--==================================================
-- DRAG
--==================================================

local dragging = false
local dragInput = nil
local dragStart = nil
local startPosition = nil

local function atualizarDrag(input)

    local delta =
        input.Position -
        dragStart

    frame.Position =
        UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )

end

frame.InputBegan:Connect(function(input)

    if input.UserInputType ==
        Enum.UserInputType.MouseButton1

        or input.UserInputType ==
        Enum.UserInputType.Touch then

        dragging = true

        dragStart =
            input.Position

        startPosition =
            frame.Position

        input.Changed:Connect(function()

            if input.UserInputState ==
                Enum.UserInputState.End then

                dragging = false

            end

        end)

    end

end)

frame.InputChanged:Connect(function(input)

    if input.UserInputType ==
        Enum.UserInputType.MouseMovement

        or input.UserInputType ==
        Enum.UserInputType.Touch then

        dragInput = input

    end

end)

UserInputService.InputChanged:Connect(function(input)

    if input == dragInput
        and dragging then

        atualizarDrag(input)

    end

end)

--==================================================
-- REMOVER ORIENTAÇÃO
--==================================================

local function removerOrientacao()

    if align then

        align:Destroy()
        align = nil

    end

    if attachment then

        attachment:Destroy()
        attachment = nil

    end

    local _, humanoid =
        pegar()

    if humanoid then
        humanoid.AutoRotate = true
    end

end

--==================================================
-- BLOQUEAR CONTROLES
--==================================================

local function bloquearControles()

    if controlsDisabled then
        return
    end

    local controls =
        obterControles()

    if controls then

        local success =
            pcall(function()

                controls:Disable()

            end)

        if success then
            controlsDisabled = true
        end

    end

end

--==================================================
-- LIBERAR CONTROLES
--==================================================

local function liberarControles()

    if not controlsDisabled then
        return
    end

    local controls =
        obterControles()

    if controls then

        pcall(function()

            controls:Enable()

        end)

    end

    controlsDisabled = false

end

--==================================================
-- BLOCK WASD
--==================================================

local function bloquearWASD()

    local function bloquearMovimento()

        return Enum.ContextActionResult.Sink

    end

    ContextActionService:BindAction(
        "AutoStealBlockMovement",
        bloquearMovimento,
        false,
        Enum.KeyCode.W,
        Enum.KeyCode.A,
        Enum.KeyCode.S,
        Enum.KeyCode.D
    )

end

--==================================================
-- UNBLOCK WASD
--==================================================

local function liberarWASD()

    ContextActionService:UnbindAction(
        "AutoStealBlockMovement"
    )

end

--==================================================
-- UPDATE UI
--==================================================

local function atualizarUI(inativo)

    if inativo then

        button.Text =
            "ENABLE"

        button.BackgroundColor3 =
            Color3.fromRGB(
                29,
                29,
                35
            )

        status.Text =
            "● INACTIVE"

        status.TextColor3 =
            Color3.fromRGB(
                145,
                145,
                150
            )

    else

        button.Text =
            "DISABLE"

        button.BackgroundColor3 =
            Color3.fromRGB(
                38,
                90,
                52
            )

        status.Text =
            "● ACTIVE"

        status.TextColor3 =
            Color3.fromRGB(
                90,
                220,
                115
            )

    end

end

--==================================================
-- DETECTAR INTERRUPÇÃO
--==================================================

local function movimentoInterrompido(humanoid)

    if not humanoid
        or not humanoid.Parent then

        return true

    end

    local state =
        humanoid:GetState()

    if state ==
        Enum.HumanoidStateType.Ragdoll

        or state ==
        Enum.HumanoidStateType.FallingDown

        or state ==
        Enum.HumanoidStateType.Physics

        or state ==
        Enum.HumanoidStateType.PlatformStanding

        or state ==
        Enum.HumanoidStateType.Seated

        or state ==
        Enum.HumanoidStateType.Jumping

        or state ==
        Enum.HumanoidStateType.Freefall

        or state ==
        Enum.HumanoidStateType.Dead then

        return true

    end

    return false

end

--==================================================
-- POSIÇÃO DO PROMPT
--==================================================

local function obterPosicaoPrompt(prompt)

    if not prompt
        or not prompt.Parent then

        return nil

    end

    local parent =
        prompt.Parent

    if parent:IsA("BasePart") then

        return parent.Position

    end

    if parent:IsA("Attachment") then

        return parent.WorldPosition

    end

    if parent:IsA("Model") then

        local part =
            parent.PrimaryPart

            or parent:FindFirstChildWhichIsA(
                "BasePart"
            )

        if part then
            return part.Position
        end

    end

    local part =
        parent:FindFirstChildWhichIsA(
            "BasePart",
            true
        )

    if part then
        return part.Position
    end

    return nil

end

--==================================================
-- PROMPT MAIS PRÓXIMO
--==================================================

local function encontrarPromptMaisProximo(posicao)

    local maisProximo = nil
    local menorDistancia = math.huge

    -- Uma única busca por recuperação.
    -- Não fica repetindo GetDescendants em loop.
    local objetos =
        workspace:GetDescendants()

    for _, obj in ipairs(objetos) do

        if obj:IsA("ProximityPrompt")
            and obj.Enabled then

            local promptPosition =
                obterPosicaoPrompt(obj)

            if promptPosition then

                local distancia =
                    (
                        promptPosition -
                        posicao
                    ).Magnitude

                if distancia <
                    menorDistancia then

                    menorDistancia =
                        distancia

                    maisProximo =
                        obj

                end

            end

        end

    end

    return maisProximo,
        menorDistancia

end

--==================================================
-- RECUPERAÇÃO
--==================================================

local recuperarInterrupcao

recuperarInterrupcao = function(posicaoInicial)

    if not ativo
        or not autoLeft then

        return

    end

    -- Se já existe uma recuperação,
    -- não inicia outra.
    if processandoInterrupcao then
        return
    end

    local agora =
        os.clock()

    if agora - ultimaInterrupcao <
        INTERVALO_RECUPERACAO then

        return

    end

    processandoInterrupcao = true
    ultimaInterrupcao = agora

    -- Cancela o movimento anterior.
    movimentoToken += 1

    autoDestino = nil

    removerOrientacao()
    liberarControles()

    --==============================================
    -- ESPERAR O RAGDOLL / PHYSICS TERMINAR
    --==============================================

    local inicio =
        os.clock()

    local pronto = false

    while ativo
        and autoLeft
        and os.clock() - inicio <
            TEMPO_MAXIMO_ESPERA_INTERRUPCAO do

        local _, humanoid, root =
            pegar()

        if not humanoid
            or not root then

            break

        end

        pararTodasAnimacoes()

        if not movimentoInterrompido(
            humanoid
        ) then

            pronto = true
            break

        end

        humanoid:Move(
            Vector3.zero,
            true
        )

        humanoid.Jump = false

        task.wait(0.1)

    end

    if not pronto then

        processandoInterrupcao = false
        return

    end

    if not ativo
        or not autoLeft then

        processandoInterrupcao = false
        return

    end

    local _, humanoid, root =
        pegar()

    if not humanoid
        or not root then

        processandoInterrupcao = false
        return

    end

    pararTodasAnimacoes()

    -- Usa a posição atual do personagem.
    -- Isso evita procurar em uma posição antiga
    -- caso o ragdoll tenha deslocado o personagem.
    local pontoFinal =
        root.Position

    --==============================================
    -- UMA ÚNICA BUSCA PELO PROMPT MAIS PRÓXIMO
    --==============================================

    local prompt =
        encontrarPromptMaisProximo(
            pontoFinal
        )

    if not prompt then

        processandoInterrupcao = false
        return

    end

    local destinoPrompt =
        obterPosicaoPrompt(prompt)

    if not destinoPrompt then

        processandoInterrupcao = false
        return

    end

    autoDestino =
        destinoPrompt

    autoEsperandoPrompt = true
    autoIndoPOS2 = false

    processandoInterrupcao = false

    iniciarMovimento(
        destinoPrompt
    )

end

--==================================================
-- MOVIMENTO
--==================================================

local function iniciarMovimento(destino)

    local character,
        humanoid,
        root = pegar()

    if not character
        or not humanoid
        or not root then

        return false

    end

    -- Cancela qualquer orientação anterior.
    removerOrientacao()

    bloquearControles()

    humanoid.AutoRotate = false
    humanoid.Jump = false

    attachment =
        Instance.new("Attachment")

    attachment.Name =
        "AutoStealDirectionAttachment"

    attachment.Parent =
        root

    align =
        Instance.new("AlignOrientation")

    align.Name =
        "ForceAutoStealDirection"

    align.Mode =
        Enum.OrientationAlignmentMode.OneAttachment

    align.Attachment0 =
        attachment

    align.RigidityEnabled = true
    align.Responsiveness = 200
    align.MaxTorque = math.huge

    align.Parent = root

    local forward =
        root.CFrame.LookVector

    local left =
        Vector3.new(
            forward.Z,
            0,
            -forward.X
        )

    if left.Magnitude > 0 then

        left = left.Unit

        align.CFrame =
            CFrame.lookAt(
                Vector3.zero,
                left
            )

    end

    movimentoToken += 1

    local meuToken =
        movimentoToken

    task.spawn(function()

        while ativo
            and meuToken ==
                movimentoToken do

            if not humanoid.Parent
                or not root.Parent then

                break

            end

            pararTodasAnimacoes()

            --==========================================
            -- INTERRUPÇÃO
            --==========================================

            if movimentoInterrompido(
                humanoid
            ) then

                local pontoInterrupcao =
                    root.Position

                humanoid:Move(
                    Vector3.zero,
                    true
                )

                humanoid.Jump = false

                movimentoToken += 1

                removerOrientacao()
                liberarControles()

                -- Apenas uma thread de recuperação.
                if autoLeft
                    and ativo
                    and not processandoInterrupcao then

                    task.spawn(function()

                        recuperarInterrupcao(
                            pontoInterrupcao
                        )

                    end)

                end

                break

            end

            humanoid.Jump = false

            local distancia =
                (
                    root.Position -
                    destino
                ).Magnitude

            if distancia <= 3 then

                humanoid:Move(
                    Vector3.zero,
                    true
                )

                humanoid.Jump = false

                pararTodasAnimacoes()

                removerOrientacao()
                liberarControles()

                break

            end

            if not controlsDisabled then
                bloquearControles()
            end

            humanoid:MoveTo(
                destino
            )

            task.wait(0.08)

        end

    end)

    return true

end

--==================================================
-- POSIÇÃO SELECIONADA
--==================================================

local function irParaPosicaoSelecionada()

    if not autoLeft then
        return
    end

    local destino =
        Positions[selectedPosition]

    autoDestino =
        destino

    autoEsperandoPrompt = true
    autoIndoPOS2 = false

    iniciarMovimento(
        destino
    )

end

--==================================================
-- POS2
--==================================================

local function irParaPOS2Auto()

    if not autoLeft then
        return
    end

    autoDestino =
        POS2

    autoEsperandoPrompt = false
    autoIndoPOS2 = true

    iniciarMovimento(
        POS2
    )

end

--==================================================
-- DETECTAR CHEGADA
--==================================================

task.spawn(function()

    while true do

        task.wait(0.12)

        if not autoLeft
            or not ativo then

            continue

        end

        -- Se já existe recuperação,
        -- não interfere nela.
        if processandoInterrupcao then
            continue
        end

        local _, humanoid, root =
            pegar()

        if not humanoid
            or not root then

            continue

        end

        pararTodasAnimacoes()

        --==============================================
        -- INTERRUPÇÃO
        --==============================================

        if movimentoInterrompido(
            humanoid
        ) then

            if not processandoInterrupcao then

                task.spawn(function()

                    recuperarInterrupcao(
                        root.Position
                    )

                end)

            end

            continue

        end

        if not autoDestino then
            continue
        end

        if esperandoDestino then
            continue
        end

        local distancia =
            (
                root.Position -
                autoDestino
            ).Magnitude

        if distancia <= 3 then

            local eraPosicao =
                autoEsperandoPrompt

            local eraPOS2 =
                autoIndoPOS2

            -- Cancela o movimento atual.
            movimentoToken += 1

            autoDestino = nil

            humanoid:Move(
                Vector3.zero,
                true
            )

            humanoid.Jump = false

            pararTodasAnimacoes()

            removerOrientacao()
            liberarControles()

            --==========================================
            -- ESPERA 1,3 SEGUNDOS
            --==========================================

            esperandoDestino = true

            local inicioEspera =
                os.clock()

            local interrupcaoDuranteEspera =
                false

            while os.clock() -
                inicioEspera <
                TEMPO_ESPERA_DESTINO do

                task.wait(0.05)

                local _, h, r =
                    pegar()

                if not h or not r then
                    break
                end

                pararTodasAnimacoes()

                if movimentoInterrompido(h) then

                    interrupcaoDuranteEspera =
                        true

                    break

                end

                h:Move(
                    Vector3.zero,
                    true
                )

                h.Jump = false

            end

            esperandoDestino = false

            if not ativo
                or not autoLeft then

                continue

            end

            local _, novoHumanoid,
                novoRoot = pegar()

            if not novoHumanoid
                or not novoRoot then

                continue

            end

            pararTodasAnimacoes()

            --==========================================
            -- INTERRUPÇÃO DURANTE OS 1,3 SEGUNDOS
            --==========================================

            if interrupcaoDuranteEspera
                or movimentoInterrompido(
                    novoHumanoid
                ) then

                recuperarInterrupcao(
                    novoRoot.Position
                )

                continue

            end

            --==========================================
            -- POSIÇÃO SELECIONADA -> POS2
            --==========================================

            if eraPosicao then

                autoEsperandoPrompt = false
                autoIndoPOS2 = true

                irParaPOS2Auto()

            --==========================================
            -- POS2 -> POSIÇÃO SELECIONADA
            --==========================================

            elseif eraPOS2 then

                autoIndoPOS2 = false
                autoEsperandoPrompt = true

                irParaPosicaoSelecionada()

            end

        end

    end

end)

--==================================================
-- ENABLE NORMAL
--==================================================

local function ativarEnable()

    if ativo then
        return
    end

    -- A partir da primeira ativação,
    -- as animações permanecem desativadas.
    animacaoDesativada = true

    ativo = true

    autoDestino = nil
    autoEsperandoPrompt = false
    autoIndoPOS2 = false

    processandoInterrupcao = false

    bloquearWASD()

    atualizarUI(false)

    pararTodasAnimacoes()

    iniciarMovimento(
        POS2
    )

end

--==================================================
-- PARAR AUTO STEAL
--==================================================

local function pararAutoSteal()

    if autoStealConnection then

        autoStealConnection:Disconnect()
        autoStealConnection = nil

    end

    restaurarPrompts()

end

--==================================================
-- DESATIVAR
--==================================================

local function desativar()

    ativo = false

    autoDestino = nil
    autoEsperandoPrompt = false
    autoIndoPOS2 = false

    esperandoDestino = false
    processandoInterrupcao = false

    movimentoToken += 1

    liberarWASD()
    liberarControles()

    removerOrientacao()

    -- Não restaura as animações.
    pararTodasAnimacoes()

    atualizarUI(true)

end

--==================================================
-- PROMPT TRIGGERED
--==================================================

promptTriggeredConnection =
    ProximityPromptService.PromptTriggered:
    Connect(function(
        prompt,
        triggeringPlayer
    )

        if triggeringPlayer
            and triggeringPlayer ~= player then

            return

        end

        if not prompt
            or not prompt:IsA(
                "ProximityPrompt"
            ) then

            return

        end

        if autoLeft then

            if ativo
                and autoEsperandoPrompt
                and not processandoInterrupcao then

                irParaPOS2Auto()

            end

            return

        end

        ativarEnable()

    end)

--==================================================
-- ENABLE BUTTON
--==================================================

button.Activated:Connect(function()

    if ativo then

        desativar()

    else

        ativarEnable()

    end

end)

--==================================================
-- R = DESATIVAR
--==================================================

UserInputService.InputBegan:Connect(
    function(
        input,
        gameProcessed
    )

        if gameProcessed then
            return
        end

        if input.KeyCode ==
            Enum.KeyCode.R then

            if ativo then

                autoLeft = false

                pararAutoSteal()
                desativar()

                autoButton.Text =
                    "AUTO STEAL: OFF"

                autoButton.BackgroundColor3 =
                    Color3.fromRGB(
                        29,
                        29,
                        35
                    )

            end

        end

    end
)

--==================================================
-- AUTO STEAL BUTTON
--==================================================

autoButton.Activated:Connect(function()

    autoLeft =
        not autoLeft

    if autoLeft then

        animacaoDesativada = true

        autoButton.Text =
            "AUTO STEAL: ON"

        autoButton.BackgroundColor3 =
            Color3.fromRGB(
                38,
                90,
                52
            )

        autoStealConnection =
            ProximityPromptService.PromptShown:
            Connect(function(prompt)

                if not autoLeft then
                    return
                end

                if not prompt
                    or not prompt:IsA(
                        "ProximityPrompt"
                    ) then

                    return

                end

                if not prompt.Enabled then
                    return
                end

                configurarPrompt(prompt)

                local agora =
                    os.clock()

                local ultimo =
                    promptCooldown[prompt]

                if ultimo
                    and agora - ultimo <
                        PROMPT_COOLDOWN then

                    return

                end

                promptCooldown[prompt] =
                    agora

                task.defer(function()

                    if not autoLeft then
                        return
                    end

                    if not prompt.Parent then
                        return
                    end

                    if not prompt.Enabled then
                        return
                    end

                    if typeof(
                        fireproximityprompt
                    ) == "function" then

                        pcall(function()

                            fireproximityprompt(
                                prompt,
                                1,
                                true
                            )

                        end)

                    end

                end)

            end)

        if not ativo then

            ativo = true

            bloquearWASD()

            atualizarUI(false)

            pararTodasAnimacoes()

            irParaPosicaoSelecionada()

        end

    else

        autoButton.Text =
            "AUTO STEAL: OFF"

        autoButton.BackgroundColor3 =
            Color3.fromRGB(
                29,
                29,
                35
            )

        pararAutoSteal()

        if ativo then
            desativar()
        end

    end

end)

--==================================================
-- RESPAWN
--==================================================

player.CharacterAdded:Connect(
    function(character)

        movimentoToken += 1

        liberarWASD()
        liberarControles()
        removerOrientacao()

        ativo = false

        autoDestino = nil
        autoEsperandoPrompt = false
        autoIndoPOS2 = false

        esperandoDestino = false
        processandoInterrupcao = false

        atualizarUI(true)

        task.wait(1)

        if not character.Parent then
            return
        end

        if animacaoDesativada then
            pararTodasAnimacoes()
        end

    end
)

--==================================================
-- CHARACTER REMOVING
--==================================================

player.CharacterRemoving:Connect(
    function()

        movimentoToken += 1

        processandoInterrupcao = false

        liberarWASD()
        liberarControles()
        removerOrientacao()

    end
)
