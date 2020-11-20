--[[
    First Release By Storm Team (Martin) @ 20.Nov.2020    
]]

if Player.CharName ~= "Chogath" then return end

require("common.log")
module("Storm Chogath", package.seeall, log.setup)

local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs

local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell

---@type TargetSelector
local TS = _G.Libs.TargetSelector()
local Chogath = {}

local spells = {
    Q = Spell.Skillshot({
        Slot = Enums.SpellSlots.Q,
        Range = 950,
        Radius = 200,
        Delay = 0.7,
        Type = "Circular"
    }),
    W = Spell.Skillshot({
        Slot = Enums.SpellSlots.W,
        Range = 650,
        Radius = 100,
        Delay = 0.5,
        Type = "Circular",
        UseHitbox = true
    }),
    E = Spell.Active({
        Slot = Enums.SpellSlots.E,
        Delay = 0
    }),
    R = Spell.Targeted({
        Slot = Enums.SpellSlots.R,
        Delay = 0.25,
        Range = 175
    }),
}

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end


function Chogath.IsEnabledAndReady(spell, mode)
    return Menu.Get(mode .. ".Use"..spell) and spells[spell]:IsReady()
end
local lastTick = 0
function Chogath.OnTick()    
    if not GameIsAvailable() then return end 

    local gameTime = Game.GetTime()
    if gameTime < (lastTick + 0.25) then return end
    lastTick = gameTime    

    if Chogath.Auto() then return end
    if not Orbwalker.CanCast() then return end

    local ModeToExecute = Chogath[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end
function Chogath.OnDraw() 
    local playerPos = Player.Position
    local pRange = Orbwalker.GetTrueAutoAttackRange(Player)   
    

    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..k..".Enabled", true) then
            Renderer.DrawCircle3D(playerPos, v.Range, 30, 2, Menu.Get("Drawing."..k..".Color")) 
        end
    end
end

function Chogath.GetTargets(range)
    return {TS:GetTarget(range, true)}
end

function Chogath.ComboLogic(mode)
    if Chogath.IsEnabledAndReady("Q", mode) then
        local qChance = Menu.Get(mode .. ".ChanceQ")
        for k, qTarget in ipairs(Chogath.GetTargets(spells.Q.Range)) do
            if spells.Q:Cast(qTarget) then
                return
            end
        end
    end
    if Chogath.IsEnabledAndReady("W", mode) then
        local wChance = Menu.Get(mode .. ".ChanceW")
        for k, wTarget in ipairs(Chogath.GetTargets(spells.W.Range)) do
            if spells.W:CastOnHitChance(wTarget, wChance) then
                return
            end
        end
    end
    if Chogath.IsEnabledAndReady("R", mode) then
        for k, rTarget in ipairs(Chogath.GetTargets(spells.R.Range + Player.BoundingRadius)) do
            local RDmg = Chogath.Rdmg()
            local ksHealth = spells.R:GetKillstealHealth(rTarget)
            if RDmg > ksHealth and spells.R:Cast(rTarget) then
                return
            end
        end
    end
end
function Chogath.HarassLogic(mode)
    local PM = Player.Mana / Player.MaxMana * 100
    local SettedMana = Menu.Get("Harass.Mana")
    if SettedMana > PM then 
        return 
        end
        if Chogath.IsEnabledAndReady("Q", mode) then
            local qChance = Menu.Get(mode .. ".ChanceQ")
            for k, qTarget in ipairs(Chogath.GetTargets(spells.Q.Range)) do
                if spells.Q:Cast(qTarget) then
                    return
                end
            end
        end
        if Chogath.IsEnabledAndReady("W", mode) then
            local wChance = Menu.Get(mode .. ".ChanceW")
            for k, wTarget in ipairs(Chogath.GetTargets(spells.W.Range)) do
                if spells.W:CastOnHitChance(wTarget, wChance) then
                    return
                end
            end
        end
end
function Chogath.Rdmg()
    return (300 + (spells.R:GetLevel() - 1) * 175) + (0.5 * Player.TotalAP) + (0.10 * Player.BonusHealth)
end
function Chogath.Qdmg()
    return (80 + (spells.R:GetLevel() - 1) * 55) + (1 * Player.TotalAP)
end
function Chogath.Wdmg()
    return (75 + (spells.R:GetLevel() - 1) * 50) + (0.7 * Player.TotalAP)
end
---@param source AIBaseClient
---@param dash DashInstance
function Chogath.OnGapclose(source, dash)
    if not source.IsEnemy  then return end
 
    local paths = dash:GetPaths()
    local endPos = paths[#paths].EndPos
    if spells.Q:IsReady() and  spells.Q:IsInRange(endPos) and Menu.Get("Misc.GapQ") then
        if spells.Q:Cast(endPos) then return end
    end
    if spells.W:IsReady() and spells.W:IsInRange(endPos) and Menu.Get("Misc.GapW") then
        if spells.W:Cast(endPos) then return end
    end
end
---@param source AIBaseClient
---@param spell SpellCast
function Chogath.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy  and danger > 2) then return end
        if spells.W:IsReady() and spells.W:IsInRange(source) and Menu.Get("Misc.IntW") then
        spells.W:CastOnHitChance(source, Enums.HitChance.High)
        end 
        if spells.Q:IsReady() and spells.Q:IsInRange(source) and Menu.Get("Misc.IntQ") then
        spells.Q:CastOnHitChance(source, Enums.HitChance.High)
        end
end
---@param _target AttackableUnit
function Chogath.OnPostAttack(_target)
    local useEJungle = Menu.Get("Clear.UseEJ")
    local UseEfarm = Menu.Get("Clear.UseE")
    local UseEcombo  = Menu.Get("Combo.UseE")
    local UseEHarass  = Menu.Get("Harass.UseE")
    local target = _target.AsAI
    
    local mode = Orbwalker.GetMode()
    if target.IsMonster and mode == "Waveclear" and useEJungle then
        if spells.E:IsReady() then spells.E:Cast()
        end
    end
    if target.IsMinion and mode == "Waveclear" and UseEfarm then
        local PM = Player.Mana / Player.MaxMana * 100
        local SettedMana = Menu.Get("Clear.Mana")
        if SettedMana > PM then return end
        if spells.E:IsReady() then spells.E:Cast()
        end
    end
    if target.IsHero and UseEcombo then
        if mode == "Combo" and spells.E:IsReady() then
            spells.E:Cast()
                return
            end
        end
    if target.IsHero and UseEHarass then
        local PM = Player.Mana / Player.MaxMana * 100
        local SettedMana = Menu.Get("Harass.Mana")
        if SettedMana > PM then return end
        if mode == "Harass" and spells.E:IsReady() then
             spells.E:Cast()
                 return
         end
    end    
    if target.IsStructure and Menu.Get("Clear.UseET") then 
        if mode == "Waveclear" and spells.E:IsReady() then
            spells.E:Cast()
                return
        end
    end
end
function Chogath.Auto() 
    local farmR = Menu.Get("Misc.AutoDrake")
    if farmR then
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
            local minion = v.AsAI
            if minion:Distance(Player) < spells.R.Range + Player.BoundingRadius and minion.IsDragon or minion.IsBaron then
                if spells.R:IsReady() and (1000 + Player.TotalAP * 0.5 ) + ( Player.BonusHealth * 0.10 ) > minion.Health then 
                    spells.R:Cast(minion) return
                end
            end                       
        end
    end
    local Qks   = Menu.Get("KillSteal.Q")
    local Rks   = Menu.Get("KillSteal.R")
    local dash  = Menu.Get("Misc.DashQ")
    local ImmoQ = Menu.Get("Misc.ImmoQ")
    if dash then 
        for k, qTarget in ipairs(Chogath.GetTargets(spells.Q.Range/1.4)) do
            if qTarget.CharName == "Yasuo" or qTarget.CharName == "Kalista" then return end
            if spells.Q:CastOnHitChance(qTarget, Enums.HitChance.Dashing) then
                return
            end
        end
    end
    if ImmoQ then 
        for k, qTarget in ipairs(Chogath.GetTargets(spells.Q.Range)) do
            if spells.Q:CastOnHitChance(qTarget, Enums.HitChance.Immobile) then
                return
            end
        end
    end
    if Qks then 
        for k, qTarget in ipairs(Chogath.GetTargets(spells.Q.Range)) do
            local QDmg = DmgLib.CalculateMagicalDamage(Player, qTarget, Chogath.Qdmg())
            local ksHealth = spells.Q:GetKillstealHealth(qTarget)
            if  QDmg > ksHealth and  spells.Q:CastOnHitChance(qTarget, Enums.HitChance.High) then
                return
            end
        end
    end
    if Rks then 
        for k, rTarget in ipairs(Chogath.GetTargets(spells.R.Range + Player.BoundingRadius)) do
            local RDmg = Chogath.Rdmg()
            local ksHealth = spells.R:GetKillstealHealth(rTarget)
            if  RDmg > ksHealth and  spells.R:Cast(rTarget) then
                return
            end
        end
    end
end   


function Chogath.Combo()  Chogath.ComboLogic("Combo")  end
function Chogath.Harass() Chogath.HarassLogic("Harass") end
    
function Chogath.Waveclear()
    local usejQ = Menu.Get("Clear.UseQJ")
    local usejW = Menu.Get("Clear.UseWJ")
    local farmQ = Menu.Get("Clear.UseQ")
    local farmW = Menu.Get("Clear.UseW")
    local hitCountQ = Menu.Get("Clear.Q")
    local hitCountW = Menu.Get("Clear.W")
    if usejQ then
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
            local minion = v.AsAI
            local minionInRange = spells.Q:IsInRange(minion)
            if minionInRange and minion.IsMonster  and minion.IsTargetable then
                if spells.Q:IsReady() then spells.Q:CastOnHitChance(minion,Enums.HitChance.Low)
                    return
                end     
            end                  
        end
    end
    if usejW then
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
            local minion = v.AsAI
            local minionInRange = spells.W:IsInRange(minion)
            if minionInRange and minion.IsMonster  and minion.IsTargetable then
                if spells.W:IsReady() then spells.W:CastOnHitChance(minion,Enums.HitChance.Low)
                    return
                end     
            end                  
        end
    end
    local PM = Player.Mana / Player.MaxMana * 100
    local SettedMana = Menu.Get("Clear.Mana")
    if SettedMana > PM then return end
        local pPos, pointsQ = Player.Position, {}
        local pPos2, pointsW = Player.Position, {}

        for k, v in pairs(ObjManager.Get("enemy", "minions")) do
            local minion = v.AsAI
            if minion then
                local pos = minion:FastPrediction(spells.Q.Delay)
                local pos2 = minion:FastPrediction(spells.W.Delay)
                if pos:Distance(pPos) < spells.Q.Range and minion.IsTargetable then
                    insert(pointsQ, pos)
                end 
                if pos2:Distance(pPos2) < spells.W.Range and minion.IsTargetable then
                    insert(pointsW, pos)
                end 
            end                       
        end

        if farmQ then
            local bestPos, hitCount = Geometry.BestCoveringCircle(pointsQ, spells.Q.Radius * 3)
            if bestPos and hitCount >= hitCountQ and Input.Cast(spells.Q.Slot, bestPos) then
                return
            end
        end    
        if farmW then
            local bestPos, hitCount = Geometry.BestCoveringCircle(pointsW, spells.W.Radius * 2)
            if bestPos and hitCount >= hitCountW and Input.Cast(spells.W.Slot, bestPos) then
                return
            end
        end    
end


function Chogath.LoadMenu()

    Menu.RegisterMenu("StormChogath", "Storm Chogath", function()
        Menu.ColumnLayout("cols", "cols", 2, true, function()
            Menu.ColoredText("Combo", 0xFFD700FF, true)
            Menu.Checkbox("Combo.UseQ",   "Use [Q]", true) 
            Menu.Slider("Combo.ChanceQ", "HitChance [Q]", 0.7, 0, 1, 0.05)   
            Menu.Checkbox("Combo.UseW",   "Use [W]", true)
            Menu.Slider("Combo.ChanceW", "HitChance [W]", 0.7, 0, 1, 0.05)   
            Menu.Checkbox("Combo.UseE",   "Use [E]", true)
            Menu.Checkbox("Combo.UseR",   "Use [R] when killable", true)
            Menu.NextColumn()
            Menu.ColoredText("Harass", 0xFFD700FF, true)
            Menu.Slider("Harass.Mana", "Mana Percent ", 50,0, 100)
            Menu.Checkbox("Harass.UseQ",   "Use [Q]", true)   
            Menu.Slider("Harass.ChanceQ", "HitChance [Q]", 0.85, 0, 1, 0.05)
            Menu.Checkbox("Harass.UseW",   "Use [W]", true)
            Menu.Slider("Harass.ChanceW", "HitChance [W]", 0.85, 0, 1, 0.05)
            Menu.Checkbox("Harass.UseE",   "Use [E]", false)   
             
        end)
        Menu.Separator()
        Menu.ColoredText("Jungle", 0xFFD700FF, true)
        Menu.Checkbox("Clear.UseQJ",   "Use [Q] Jungle", true) 
        Menu.Checkbox("Clear.UseWJ",   "Use [W] Jungle", true) 
        Menu.Checkbox("Clear.UseEJ",   "Use [E] Jungle", true) 
        Menu.ColoredText("Lane", 0xFFD700FF, true)
        Menu.Slider("Clear.Mana", "Mana Percent ", 50,0, 100)
        Menu.Checkbox("Clear.UseQ",   "Use [Q] Lane", true) 
        Menu.Slider("Clear.Q", "Q Hitcount ", 2, 1, 5)
        Menu.Checkbox("Clear.UseW",   "Use [W] Lane", false) 
        Menu.Slider("Clear.W", "W Hitcount ", 2, 1, 5)
        Menu.Checkbox("Clear.UseE",   "Use [E] Lane", false) 
        Menu.Checkbox("Clear.UseET",   "Use [E] On Structures", true) 
        Menu.Separator()

        Menu.ColoredText("KillSteal Options", 0xFFD700FF, true)
        Menu.Checkbox("KillSteal.R", "Use [R] to KS", true)     
        Menu.Checkbox("KillSteal.Q", "Use [Q] to KS", true)    
        Menu.Separator()

        Menu.ColoredText("Misc Options", 0xFFD700FF, true)   
        Menu.Checkbox("Misc.AutoDrake", "Auto Eat Drake", true)
        Menu.Checkbox("Misc.IntW", "Use [W] Interrupt", true)
        Menu.Checkbox("Misc.IntQ", "Use [Q] Interrupt", true)      
        Menu.Checkbox("Misc.DashQ", "Auto [Q] on Dasher", true)  
        Menu.Checkbox("Misc.ImmoQ", "Auto [Q] on Immobile", true)  
        Menu.Checkbox("Misc.GapQ", "Use [Q] On Gapcloser", true)
        Menu.Checkbox("Misc.GapW", "Use [W] On Gapcloser", true)    
        Menu.Separator()

        Menu.ColoredText("Draw Options", 0xFFD700FF, true)
        Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range")
        Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)    
        Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range")
        Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)  
    end)     
end

function OnLoad()
    Chogath.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Chogath[eventName] then
            EventManager.RegisterCallback(eventId, Chogath[eventName])
        end
    end    
    return true
end