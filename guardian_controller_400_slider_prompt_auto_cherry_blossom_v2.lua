-- Updated Cherry Blossom Guardian controller
-- Walk animation: rbxassetid://75608548920054
-- Animation speed: 2x

local sourceUrl = "https://raw.githubusercontent.com/gomesdev007/Steal-an-egg-/refs/heads/main/guardian_controller_400_slider_prompt_auto_cherry_blossom.lua"

local ok, source = pcall(function()
    return game:HttpGet(sourceUrl)
end)

if not ok or not source then
    warn("Nao foi possivel carregar o Guardian Controller original.")
    return
end

source = source:gsub(
    'local WALK_ANIMATION_ID = "rbxassetid://131533059911792"',
    'local WALK_ANIMATION_ID = "rbxassetid://75608548920054"'
)

source = source:gsub(
    'local WALK_ANIMATION_SPEED = 8%.196428',
    'local WALK_ANIMATION_SPEED = 2'
)

local run, err = loadstring(source)

if not run then
    warn("Erro ao atualizar o Guardian Controller:", err)
    return
end

run()
