-- Egg ESP + Auto Steal extracted from the provided open-source file.
-- Only the requested systems and their required dependencies are included.

local iData = {}
local unpackValues = unpack or table.unpack
iData.value2 = game:GetService("Players")
iData.value3 = game:GetService("RunService")
iData.value4 = game:GetService("TweenService")
iData.value6 = game:GetService("ReplicatedStorage")
iData.value7 = game:GetService("Workspace")
iData.value9 = iData.value2.LocalPlayer
iData.value10 = {}
iData.value11 = {}
iData.value12 = {}
iData.value13 = {}
iData.value14 = {
    AutoSteal = false,
    FarmMethod = "Speed",
    AntiTrap = true,
    AreaFocus = {},
    RarityFilter = {},
    SecretPriority = true,
    EggESP = false,
    AntiCheat = false,
    HumReady = false,
    Unloaded = false,
}
iData.value15 = {}
iData.value16 = {}
function iData.value17() return not iData.value14.Unloaded end
function iData.value18(title, content, duration)
    pcall(function() warn("[Egg ESP + Auto Steal] " .. tostring(title) .. ": " .. tostring(content)) end)
end

-- The complete extracted dependency/function body from the supplied open-source file
-- is embedded below, including egg scanning, target selection, ground/path movement,
-- carrying, placement, delivery, and the original Egg ESP rendering/update loop.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local state = {
    EggESP = false,
    AutoSteal = false,
    travelToken = 0,
    travelling = false,
    carryingUid = nil,
    deliverAt = 0,
    deliverFails = 0,
    dryRuns = 0,
    triedUids = {},
    failUids = {},
    eggList = {},
    eggListAt = 0,
    espFolder = nil,
    espTags = {},
    cachedPlot = nil,
    cachedSlot = nil,
    penCache = nil,
    originCache = nil,
    originAt = 0,
    placeOK = nil,
    placeWhy = "",
    trapList = {},
    trapModels = {},
    trapAt = 0,
}

local cfg = {
    TRAP_RADIUS = 16,
    TRAP_WORDS = {"trap", "cage", "snare"},
    PROBE_LOW = 7,
    PROBE_HIGH = 160,
    PROBE_DOWN = 420,
    STEP_MAX = 6,
    TRAVEL_SPEED = 1000,
    ROUTE_SAMPLE = 14,
    ROUTE_DROP = 26,
    SIDE_OFFSETS = {30,-30,70,-70,140,-140,240,-240},
    STRAIGHT_MAX = 60,
    GRAB_TOLERANCE = 8,
    TP_STEP = 45,
    TP_WAIT = 0.08,
    RING8 = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}},
    PLACE_PITCH = 6,
    PLACE_HALF = 24,
    EGG_CLEAR = 7,
    ZONE_HALF = 20,
    GRID_STEP = 4,
}

local remotes = {
    EggSnapshot = "RF/EggWorld/AskFieldEggSnapshot",
    EggCarry = "RF/EggWorld/AskFieldEggCarry",
    EggPlace = "RF/EggWorld/AskPlaceEgg",
    EggLive = "RF/EggWorld/AskLiveSnapshot",
    PlotState = "RF/Homestead/AskState",
    WearTool = "RF/EggWorld/AskWearTool",
    DoffTool = "RF/EggWorld/AskDoffTool",
}

local Networking = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
local function getRemote(path)
    if not Networking then return nil end
    return Networking:FindFirstChild(path)
end
local function invoke(path, ...)
    local r = getRemote(path)
    if not r then return nil end
    if r:IsA("RemoteFunction") then
        local ok, result = pcall(r.InvokeServer, r, ...)
        return ok and result or nil
    end
    local ok = pcall(r.FireServer, r, ...)
    return ok or nil
end

local firePrompt = fireproximityprompt or (syn and syn.fireproximityprompt)
local function hrp()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function humanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildWhichIsA("Humanoid")
end
local function alive()
    local h = humanoid()
    return hrp() ~= nil and h ~= nil and h.Health > 0
end
local function hasTool()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildWhichIsA("Tool") ~= nil
end
local function promptNear(p)
    local root = hrp()
    local parent = p and p.Parent
    if not root or not parent then return false end
    local pos
    if parent:IsA("BasePart") then pos = parent.Position
    elseif parent:IsA("Model") then local ok,r=pcall(parent.GetPivot,parent); pos=ok and r.Position or nil
    elseif parent:IsA("Attachment") then pos=parent.WorldPosition end
    if not pos then return false end
    local d = p.MaxActivationDistance > 0 and p.MaxActivationDistance or 12
    return (root.Position-pos).Magnitude <= d+4
end
local function prompts(root, words)
    local out={}
    if not root then return out end
    for _,p in ipairs(root:GetDescendants()) do
        if p:IsA("ProximityPrompt") and p.Enabled then
            local text=(p.Name.." "..p.ActionText.." "..p.ObjectText):lower()
            if p.Parent then text=text.." "..p.Parent.Name:lower() end
            for _,w in ipairs(words) do if text:find(w,1,true) then out[#out+1]=p; break end end
        end
    end
    return out
end
local function firePromptSafe(p)
    if not firePrompt or not p or not p.Enabled then return false end
    pcall(function() p.HoldDuration=0 end)
    return pcall(firePrompt,p)
end

local slots = Workspace:FindFirstChild("AreaEggSlotsClient")
local function eggModel(uid)
    slots = Workspace:FindFirstChild("AreaEggSlotsClient") or slots
    return slots and slots:FindFirstChild(uid) or nil
end
local function eggPart(uid)
    local m=eggModel(uid)
    if not m then return nil end
    return m.PrimaryPart or m:FindFirstChild("Hitbox") or m:FindFirstChildWhichIsA("BasePart")
end
local rarities={"Common","Uncommon","Rare","Epic","Legendary","Mythic","Cosmic","Secret","Divine","Eternal"}
local rarityRank={}
for i,v in ipairs(rarities) do rarityRank[v]=i end
local function rank(v) return type(v)=="string" and (rarityRank[v] or 0) or 0 end
local function mutated(v) return v.BaseMutation or (type(v.Mutations)=="table" and next(v.Mutations)~=nil) end

local areaLabel, areaRarity, areaTierName, areaByLabel, areaOrder = {},{},{},{},{}
local areaWanted, rarityWanted = {},{}
local areaWantedCount, rarityWantedCount = 0,0
local Data=ReplicatedStorage:FindFirstChild("Data")
local Areas=Data and Data:FindFirstChild("Areas")
local ok,dir=pcall(function() return Areas and require(Areas) end)
dir=ok and (type(dir)=="table" and (dir.Directory or dir)) or nil
if type(dir)=="table" then
    for k,v in pairs(dir) do
        if type(k)=="string" and type(v)=="table" then
            local n=0; local r
            if type(v.Rarity)=="table" then n=tonumber(v.Rarity.RarityNumber) or 0; r=v.Rarity.DisplayName or v.Rarity._id end
            areaLabel[k]=v.DisplayName or v.Name or k; areaRarity[k]=n; areaTierName[k]=r; areaByLabel[areaLabel[k]]=k; areaOrder[#areaOrder+1]=k
        end
    end
end
local function refreshFilters()
    areaWanted={}; areaWantedCount=0
    for _,v in ipairs(iData.value14.AreaFocus or {}) do areaWanted[areaByLabel[v] or v]=true; areaWantedCount+=1 end
    rarityWanted={}; rarityWantedCount=0
    for _,v in ipairs(iData.value14.RarityFilter or {}) do rarityWanted[v]=true; rarityWantedCount+=1 end
end
refreshFilters()

local function scanEggs(force)
    if not force and tick()-state.eggListAt<1.5 then return state.eggList end
    local snap=invoke(remotes.EggSnapshot)
    local records=snap and snap.Records
    if type(records)~="table" then return state.eggList end
    local list={}
    for _,e in pairs(records) do
        if type(e)=="table" and e.State=="Slot" and e.Uid then
            local p=eggPart(e.Uid)
            local pos=p and p.Position or ((e.BoundsCFrame or e.BottomCFrame) and (e.BoundsCFrame or e.BottomCFrame).Position)
            if pos then
                local rarity=e.Rarity or e.RarityName or e.Tier or e.RarityId
                if type(rarity)=="table" then rarity=rarity.DisplayName or rarity._id or rarity.Name or rarity.Id end
                if type(rarity)~="string" then rarity=nil end
                local area=e.AreaId
                local rrank=rank(rarity)
                list[#list+1]={uid=e.Uid,area=area,label=area and areaLabel[area] or "Unknown",pos=pos,tier=area and (areaRarity[area] or 0) or 0,rarity=rarity,rank=rrank,mutated=mutated(e),size=e.BoundsSize and e.BoundsSize.Magnitude or 3}
            end
        end
    end
    state.eggList=list; state.eggListAt=tick(); return list
end
local function allowed(e)
    local tried=state.triedUids[e.uid]
    if tried then
        local fails=state.failUids[e.uid] or 0
        local cd=({[1]=18,[2]=45,[3]=120,[4]=600})[fails] or 6
        if cd>tick()-tried then return false end
    end
    if areaWantedCount>0 then return areaWanted[e.area] == true end
    if e.rank >= (rarityRank.Secret or 8) then return true end
    if rarityWantedCount>0 and not rarityWanted[e.rarity] then return false end
    return true
end
local function selectEgg()
    local root=hrp(); if not root then return nil end
    local list=scanEggs(false); local best,bscore
    for _,e in ipairs(list) do
        if allowed(e) then
            local d=(e.pos-root.Position).Magnitude
            local tier=e.tier>0 and e.tier or e.rank
            local score=e.rank*1000000000000+tier*100000000+(e.mutated and 1000000 or 0)-math.min(d,100000)
            if not bscore or score>bscore then bscore=score; best=e end
        end
    end
    return best
end

-- Ground/path helpers used by the original Speed movement.
local groundParams=RaycastParams.new(); groundParams.FilterType=Enum.RaycastFilterType.Exclude; groundParams.IgnoreWater=true
local function groundFilter()
    local out={}; if LocalPlayer.Character then out[#out+1]=LocalPlayer.Character end
    for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer and p.Character then out[#out+1]=p.Character end end
    local plot=state.cachedPlot; if plot then out[#out+1]=plot end
    for _,m in ipairs(state.trapModels) do if m.Parent then out[#out+1]=m end end
    return out
end
local function groundAt(x,z,y)
    local function probe(startY,down)
        local d=startY
        for _=1,4 do
            local r=Workspace:Raycast(Vector3.new(x,d,z),Vector3.new(0,-down,0),groundParams)
            if not r then return nil end
            local par=r.Instance
            local skip=false
            for _=1,6 do
                if not par or par==Workspace then break end
                if (par:IsA("Model") and par:FindFirstChildWhichIsA("Humanoid")) or par:FindFirstChildWhichIsA("AnimationController") then skip=true; break end
                par=par.Parent
            end
            if not skip then return r.Position.Y end
            d=r.Position.Y-0.6
            if d<=startY-down then return nil end
        end
    end
    return probe(y+cfg.PROBE_LOW,cfg.PROBE_LOW+cfg.PROBE_DOWN) or probe(y+cfg.PROBE_HIGH,cfg.PROBE_HIGH+cfg.PROBE_DOWN)
end
local function standOffset()
    local r=hrp(); local h=humanoid(); local n=r and r.Size.Y*0.5 or 1; local hip=2
    if h then pcall(function() if h.HipHeight>0 then hip=h.HipHeight end end) end
    return n+hip
end
local function directPath(a,b)
    local v=Vector3.new(b.X-a.X,0,b.Z-a.Z); local mag=v.Magnitude
    if mag<1 then return true end
    local u=v.Unit; local count=math.ceil(mag/cfg.ROUTE_SAMPLE)
    local y=a.Y
    for i=1,count do
        local p=a+u*math.min(mag,i*cfg.ROUTE_SAMPLE); local gy=groundAt(p.X,p.Z,y)
        if not gy or math.abs(gy-y)>cfg.ROUTE_DROP then return false end; y=gy
    end
    return true
end
local PathfindingService=game:GetService("PathfindingService")
local function simplify(points)
    local out={}
    for _,p in ipairs(points) do if not out[#out] or Vector3.new(p.X-out[#out].X,0,p.Z-out[#out].Z).Magnitude>3 then out[#out+1]=p end end
    if #out<3 then return out end
    local r={}
    for i=2,#out-1 do
        local a=Vector3.new(out[i].X-out[i-1].X,0,out[i].Z-out[i-1].Z); local b=Vector3.new(out[i+1].X-out[i].X,0,out[i+1].Z-out[i].Z)
        if a.Magnitude>0.1 and b.Magnitude>0.1 and a.Unit:Dot(b.Unit)<0.995 then r[#r+1]=out[i] end
    end
    r[#r+1]=out[#out]; return r
end
local function pathfind(a,b)
    local p=PathfindingService:CreatePath({AgentRadius=3,AgentHeight=6,AgentCanJump=true,AgentCanClimb=false,WaypointSpacing=24})
    local ok=pcall(function() p:ComputeAsync(a,b) end); if not ok or p.Status~=Enum.PathStatus.Success then p:Destroy(); return nil end
    local w=p:GetWaypoints(); p:Destroy(); if #w<2 then return nil end
    local out={}; for i=2,#w do out[#out+1]=w[i].Position end; out[#out]=b; return simplify(out)
end
local function route(a,b)
    if Vector3.new(b.X-a.X,0,b.Z-a.Z).Magnitude<=cfg.STRAIGHT_MAX and directPath(a,b) then return {b} end
    local h=state.cachedPlot
    if h then
        local ok,p=pcall(h.GetPivot,h)
        if ok and p then
            local center=Vector3.new(p.Position.X,a.Y,p.Position.Z)
            if directPath(a,center) and directPath(center,b) then return {center,b} end
        end
    end
    local pts=pathfind(a,b); if pts then return pts end
    return {b}
end

local function moveTo(target,tolerance,callback)
    local root=hrp(); if not root then return false end
    local start=root.Position; local v=Vector3.new(target.X-start.X,0,target.Z-start.Z); local mag=v.Magnitude
    if mag<=0.5 then return true end
    local unit=v.Unit; local rotation=CFrame.lookAt(Vector3.zero,unit).Rotation; local traveled=0; local deadline=tick()+mag/cfg.TRAVEL_SPEED+10
    while alive() and state.AutoSteal and tick()<deadline and (not callback or callback()) do
        local dt=RunService.Heartbeat:Wait(); root=hrp(); if not root then break end
        local step=math.min(cfg.TRAVEL_SPEED*math.min(dt,0.1),mag-traveled); local parts=math.max(1,math.ceil(step/cfg.STEP_MAX)); step/=parts
        for _=1,parts do traveled=math.min(mag,traveled+step); local p=start+unit*traveled; local y=groundAt(p.X,p.Z,start.Y-standOffset()) or p.Y; p=Vector3.new(p.X,y+standOffset(),p.Z); pcall(function() root.CFrame=CFrame.new(p)*rotation; root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero end); if traveled>=mag then break end end
        if traveled>=mag-0.01 then break end
    end
    return Vector3.new(target.X-root.Position.X,0,target.Z-root.Position.Z).Magnitude <= (tolerance or 8)
end

local function findPlot()
    if state.cachedPlot and state.cachedPlot.Parent then return state.cachedPlot end
    local plots=Workspace:FindFirstChild("Plots"); if not plots then return nil end
    local snap=invoke(remotes.PlotState); local owners=snap and (snap.OwnersBySlot or snap.SlotOwners or snap.Owners or snap.Slots)
    if type(owners)=="table" then
        for k,v in pairs(owners) do
            local id=type(v)=="table" and (v.UserId or v.OwnerUserId or v.Id or v.Name) or v
            if id==LocalPlayer.UserId or id==tostring(LocalPlayer.UserId) or id==LocalPlayer.Name then state.cachedSlot=k; break end
        end
    end
    if state.cachedSlot then state.cachedPlot=plots:FindFirstChild(tostring(state.cachedSlot)); if state.cachedPlot then return state.cachedPlot end end
    for _,plot in ipairs(plots:GetChildren()) do
        for _,d in ipairs(plot:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t=d.Text; if type(t)=="string" and t:find(LocalPlayer.Name,1,true) then state.cachedPlot=plot; return plot end
            end
        end
    end
end
local function penCFrame()
    if state.penCache then return state.penCache end
    local plot=findPlot(); if plot then for _,d in ipairs(plot:GetDescendants()) do if d.Name:lower():find("pen",1,true) then if d:IsA("BasePart") then state.penCache=d.CFrame; return state.penCache elseif d:IsA("Model") then local ok,p=pcall(d.GetPivot,d); if ok then state.penCache=p; return p end end end end end
    local p=findPlot(); if p then local ok,pv=pcall(p.GetPivot,p); if ok then state.penCache=pv*CFrame.new(0,0,15); return state.penCache end end
end
local function liveEggs()
    local out={}; local seen={}; local rec=invoke(remotes.EggLive); if type(rec)~="table" then return out end
    local function add(tbl)
        for k,v in pairs(tbl) do if type(v)=="table" then local uid=v.Uid or (type(k)=="string" and k or nil); if uid and not seen[uid] then seen[uid]=true; if not v.Uid then v.Uid=uid end; out[#out+1]=v end end end
    end
    for _,v in pairs(rec) do if type(v)=="table" and type(v.Records)=="table" then add(v.Records) end end
    if #out==0 and type(rec.Records)=="table" then add(rec.Records) end
    return out
end
local function placedPositions()
    local out={l={},w={}}
    for _,e in ipairs(liveEggs()) do local p=e.Placement; local c=p and (p.LocalCFrame or p.CFrame or p.WorldCFrame); if typeof(c)=="CFrame" then out.l[#out.l+1]=c.Position elseif typeof(c)=="Vector3" then out.l[#out.l+1]=c end end
    for _,child in ipairs(Workspace:GetChildren()) do if child.Name=="PlacedEggRenders" then for _,e in ipairs(child:GetChildren()) do local ok,p=pcall(function() if e:IsA("BasePart") then return e.Position elseif e:IsA("Model") then return e:GetPivot().Position end end); if ok and p then out.w[#out.w+1]=p end end end end
    return out
end
local function origins()
    if state.originCache and tick()-state.originAt<15 then return state.originCache end
    local out={}; local plot=findPlot()
    if plot then local ok,p=pcall(function() return plot.PrimaryPart and plot.PrimaryPart.CFrame end); if ok and p then out[#out+1]=p end; local best,area; for _,d in ipairs(plot:GetChildren()) do if d:IsA("BasePart") then local n=d.Name:lower(); if n:find("base") or n:find("plate") or n:find("pad") or n:find("floor") or n:find("ground") or n:find("origin") then local a=d.Size.X*d.Size.Z; if not area or a>area then best=d; area=a end end end end; if best then out[#out+1]=best.CFrame end; local ok2,p2=pcall(plot.GetPivot,plot); if ok2 and p2 then out[#out+1]=p2 end end
    if #out==0 then out[1]=CFrame.new() end
    local uniq={}; for _,c in ipairs(out) do local good=true; for _,u in ipairs(uniq) do if (u.Position-c.Position).Magnitude<0.5 then good=false; break end end; if good then uniq[#uniq+1]=c end end
    state.originCache=uniq; state.originAt=tick(); return uniq
end
local function placeEgg(uid,world)
    if not hasTool() then return false end
    for i,base in ipairs(origins()) do
        local localC=(base:Inverse()*CFrame.new(world)).Position
        local r=getRemote(remotes.EggPlace); if r and r:IsA("RemoteFunction") then local ok,res=pcall(r.InvokeServer,r,{Uid=uid,LocalCFrame=CFrame.new(localC)}); if ok then for _=1,16 do if not hasTool() then state.placeOK={origin=i}; return true end; RunService.Heartbeat:Wait() end end end
    end
    return false
end
local function wearTool(uid)
    if hasTool() then return true end
    for _=1,8 do
        invoke(remotes.WearTool,{Uid=uid})
        for _=1,4 do RunService.Heartbeat:Wait(); if hasTool() then return true end end
    end
    return false
end
local function carry(uid)
    if invoke(remotes.EggCarry,{Uid=uid})~=true then return false end
    task.spawn(function() for _=1,3 do if hasTool() then return end; invoke(remotes.WearTool,uid); task.wait(0.15) end end)
    return true
end
local function existsEgg(uid)
    local s=Workspace:FindFirstChild("AreaEggSlotsClient"); return not s or s:FindFirstChild(uid)~=nil
end
local function currentEggPos(e)
    local p=eggPart(e.uid); if p then e.pos=p.Position end; return e.pos
end
local function deliver(uid)
    local plot=findPlot(); if plot then local ok,p=pcall(plot.GetPivot,plot); if ok and p then moveTo(p.Position,14,function() return state.AutoSteal and existsEgg(uid) end) end end
    local pen=penCFrame(); if pen then moveTo(pen.Position,8,function() return state.AutoSteal end) end
    return placeEgg(uid,hrp().Position)
end

local function startAutoSteal()
    if state.AutoSteal then return end
    state.AutoSteal=true
    task.spawn(function()
        while state.AutoSteal and alive() do
            local waitTime=0.1
            local ok,err=pcall(function()
                if state.carryingUid then
                    if not hasTool() and not existsEgg(state.carryingUid) then state.carryingUid=nil; state.deliverFails=0; return end
                    if tick()-state.deliverAt<1 then return end
                    state.deliverAt=tick()
                    if deliver(state.carryingUid) then state.carryingUid=nil; state.deliverFails=0; return end
                    state.deliverFails+=1
                    if state.deliverFails>=4 then invoke(remotes.DoffTool,state.carryingUid); state.carryingUid=nil; state.deliverFails=0 end
                    return
                end
                local e=selectEgg()
                if not e then state.dryRuns+=1; scanEggs(true); waitTime=math.min(0.6+state.dryRuns*0.4,3); return end
                state.dryRuns=0; state.triedUids[e.uid]=tick()
                local tol=math.max(9,e.size*0.6+7)
                local pos=currentEggPos(e)
                for _,point in ipairs(route(hrp().Position,pos)) do
                    if not moveTo(point,tol,function() return state.AutoSteal and existsEgg(e.uid) end) then return end
                end
                if not existsEgg(e.uid) then return end
                if carry(e.uid) then
                    state.failUids[e.uid]=nil; state.carryingUid=e.uid; state.deliverAt=tick(); state.deliverFails=0
                    if deliver(e.uid) then state.carryingUid=nil end
                    waitTime=0
                else state.failUids[e.uid]=(state.failUids[e.uid] or 0)+1 end
            end)
            if not ok then warn("[Egg Auto Steal] "..tostring(err)); task.wait(0.5) end
            if waitTime>0 then task.wait(waitTime) else RunService.Heartbeat:Wait() end
        end
        if state.carryingUid then pcall(function() invoke(remotes.DoffTool,state.carryingUid) end); state.carryingUid=nil end
        state.travelToken+=1; state.travelling=false
    end)
end
local function stopAutoSteal()
    state.AutoSteal=false; state.travelToken+=1; state.travelling=false
    if state.carryingUid then pcall(function() invoke(remotes.DoffTool,state.carryingUid) end); state.carryingUid=nil end
end

-- Original Egg ESP construction/update logic.
local rarityColor={
    Common=Color3.fromRGB(190,190,190),Uncommon=Color3.fromRGB(120,220,120),Rare=Color3.fromRGB(90,160,255),Epic=Color3.fromRGB(180,110,255),Legendary=Color3.fromRGB(255,200,70),Mythic=Color3.fromRGB(255,110,190),Cosmic=Color3.fromRGB(130,240,255),Secret=Color3.fromRGB(60,60,70),Divine=Color3.fromRGB(255,250,200),Eternal=Color3.fromRGB(255,90,90),
}
local function espFolder()
    if state.espFolder and state.espFolder.Parent then return state.espFolder end
    state.espFolder=Instance.new("Folder"); state.espFolder.Name="EggESP"; state.espFolder.Parent=(type(gethui)=="function" and gethui()) or game:GetService("CoreGui"); return state.espFolder
end
local function clearESP()
    for k,v in pairs(state.espTags) do pcall(function() v:Destroy() end); state.espTags[k]=nil end
    if state.espFolder then pcall(function() state.espFolder:Destroy() end); state.espFolder=nil end
end
local function makeESP(e)
    local model=eggModel(e.uid); local part=eggPart(e.uid); if not model or not part then return nil end
    local color=rarityColor[e.rarity] or Color3.fromRGB(255,255,255)
    local f=Instance.new("Folder"); f.Name=e.uid
    local h=Instance.new("Highlight"); h.Adornee=model; h.FillColor=color; h.OutlineColor=e.mutated and Color3.fromRGB(255,150,60) or color; h.FillTransparency=0.62; h.OutlineTransparency=0; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; h.Parent=f
    local b=Instance.new("BillboardGui"); b.Adornee=part; b.Size=UDim2.fromOffset(190,26); b.StudsOffsetWorldSpace=Vector3.new(0,3.2,0); b.AlwaysOnTop=true; b.MaxDistance=100000; b.Parent=f
    local t=Instance.new("TextLabel"); t.Size=UDim2.fromScale(1,1); t.BackgroundTransparency=1; t.Font=Enum.Font.GothamBold; t.TextSize=13; t.TextColor3=color; t.TextStrokeTransparency=0.35; t.Text=(e.rarity or e.label or "Egg")..(e.mutated and "  MUT" or ""); t.Parent=b
    f.Parent=espFolder(); return f
end
task.spawn(function()
    while not iData.value14.Unloaded do
        if state.EggESP then
            pcall(function()
                local list=scanEggs(false); local present={}
                for _,e in ipairs(list) do
                    present[e.uid]=true
                    local tag=state.espTags[e.uid]
                    if not tag or not tag.Parent or not eggModel(e.uid) then if tag then pcall(function() tag:Destroy() end) end; state.espTags[e.uid]=makeESP(e) end
                end
                for uid,tag in pairs(state.espTags) do if not present[uid] then pcall(function() tag:Destroy() end); state.espTags[uid]=nil end end
            end)
        elseif next(state.espTags) then clearESP() end
        task.wait(1.2)
    end
end)

-- Compact mobile/PC UI: exactly two requested toggles.
local CoreGui=(type(gethui)=="function" and gethui()) or game:GetService("CoreGui")
local old=CoreGui:FindFirstChild("EggESP_AutoSteal_Extracted"); if old then old:Destroy() end
local gui=Instance.new("ScreenGui"); gui.Name="EggESP_AutoSteal_Extracted"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.Parent=CoreGui
local frame=Instance.new("Frame"); frame.Size=UDim2.fromOffset(220,132); frame.Position=UDim2.new(0,18,0.5,-66); frame.BackgroundColor3=Color3.fromRGB(20,20,24); frame.BorderSizePixel=0; frame.Parent=gui; Instance.new("UICorner",frame).CornerRadius=UDim.new(0,10)
local stroke=Instance.new("UIStroke",frame); stroke.Thickness=1; stroke.Color=Color3.fromRGB(55,55,62)
local title=Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(12,8); title.Size=UDim2.new(1,-24,0,22); title.Font=Enum.Font.GothamBold; title.TextSize=14; title.TextXAlignment=Enum.TextXAlignment.Left; title.TextColor3=Color3.fromRGB(240,240,244); title.Text="egg tools"; title.Parent=frame
local function toggle(y,text,get,set)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-20,0,38); b.Position=UDim2.fromOffset(10,y); b.BackgroundColor3=Color3.fromRGB(38,38,44); b.BorderSizePixel=0; b.AutoButtonColor=false; b.Font=Enum.Font.GothamSemibold; b.TextSize=12; b.TextXAlignment=Enum.TextXAlignment.Left; b.TextColor3=Color3.fromRGB(220,220,226); b.Parent=frame; Instance.new("UICorner",b).CornerRadius=UDim.new(0,8); local p=Instance.new("UIPadding",b); p.PaddingLeft=UDim.new(0,12); p.PaddingRight=UDim.new(0,12)
    local function refresh() local on=get(); b.Text=text.."    "..(on and "on" or "off"); b.BackgroundColor3=on and Color3.fromRGB(48,82,60) or Color3.fromRGB(38,38,44) end
    b.MouseButton1Click:Connect(function() set(not get()); refresh() end); refresh()
end
toggle(36,"egg esp",function() return state.EggESP end,function(v) state.EggESP=v end)
toggle(80,"auto steal",function() return state.AutoSteal end,function(v) if v then startAutoSteal() else stopAutoSteal() end end)
local dragging=false; local dragStart; local startPos; local dragInput
frame.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true; dragStart=input.Position; startPos=frame.Position; dragInput=input; input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end) end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input==dragInput then local d=input.Position-dragStart; frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)

print("Egg ESP + Auto Steal extracted loaded")
