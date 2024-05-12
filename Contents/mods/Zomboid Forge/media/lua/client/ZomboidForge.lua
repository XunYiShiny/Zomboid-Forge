--[[ ================================================ ]]--
--[[  /~~\'      |~~\                  ~~|~    |      ]]--
--[[  '--.||/~\  |   |/~\/~~|/~~|\  /    | \  /|/~~|  ]]--
--[[  \__/||     |__/ \_/\__|\__| \/   \_|  \/ |\__|  ]]--
--[[                     \__|\__|_/                   ]]--
--[[ ================================================ ]]--
--[[

This file defines the core of the mod Zomboid Forge

]]--
--[[ ================================================ ]]--

--- Import functions localy for performances reasons
local table = table -- Lua's table module
local ipairs = ipairs -- ipairs function
local pairs = pairs -- pairs function
local ZombRand = ZombRand -- java function
local print = print -- print function
local tostring = tostring --tostring function

--- import module from ZomboidForge
local ZomboidForge = require "ZomboidForge_module"
local ZFModData = ModData.getOrCreate("ZomboidForge")

ZomboidForge.initModData_ZomboidForge = function()
    ZFModData = ModData.getOrCreate("ZomboidForge")
end

--- OnLoad function to initialize the mod
ZomboidForge.OnLoad = function()
    -- initialize ModData
    if not ZFModData.PersistentZData then
        ZFModData.PersistentZData = {}
    end

    -- reset non persistent data
    ZomboidForge.nonPersistentZData = {}

    -- calculate total chance
    ZomboidForge.TotalChance = 0
    for _,ZombieTable in pairs(ZomboidForge.ZTypes) do
        ZomboidForge.TotalChance = ZomboidForge.TotalChance + ZombieTable.chance
    end
end

--- OnLoad function to initialize the mod
ZomboidForge.OnGameStart = function()
    -- Zomboid (base game zombies)
	if SandboxVars.ZomboidForge.ZomboidSpawn then
		ZomboidForge.ZTypes.ZF_Zomboid = {
            -- base informations
            name = "IGUI_ZF_Zomboid",
            chance = SandboxVars.ZomboidForge.ZomboidChance,
            --outfit = {},
            --reanimatedPlayer = false,
            --skeleton = false,
			-- hair = {
			-- 	male = {
			-- 		"",
			-- 	},
			-- 	female = {
			-- 		"",
			-- 	},
			-- },
			-- hairColor = {
			-- 	ImmutableColor.new(Color.new(0.70, 0.70, 0.70, 1)),
			-- },
			-- beard = {
			-- 	"",
			-- },
            --animationVariable = nil,

            -- stats
            walktype = SandboxVars.ZomboidForge.ZomboidWalktype,
            strength = SandboxVars.ZomboidForge.ZomboidStrength,
            toughness = SandboxVars.ZomboidForge.ZomboidToughness,
            cognition = SandboxVars.ZomboidForge.ZomboidCognition,
            memory = SandboxVars.ZomboidForge.ZomboidMemory,
            sight = SandboxVars.ZomboidForge.ZomboidVision,
            hearing = SandboxVars.ZomboidForge.ZomboidHearing,

            --noteeth = false,

            -- UI
            color = {255, 255, 255,},
            outline = {0, 0, 0,},

			-- attack functions
			-- zombieAgro = {},
			-- zombieOnHit = {},

			-- custom behavior
			-- zombieDeath = {},
			-- customBehavior = {},

			-- customData = {},
        }
	end
end

--- Initialize a zombie. `fullResetZ` will completely wipe the zombie data while
-- `rollZType` rolls a new ZType.
---@param zombie        IsoZombie
---@param fullResetZ    boolean
---@param rollZType     boolean
ZomboidForge.ZombieInitiliaze = function(zombie,fullResetZ,rollZType)
    -- get zombie trueID
    local trueID = ZomboidForge.pID(zombie)

    -- fully reset the stats of the zombie
    if fullResetZ then
        ZomboidForge.ResetZombieData(trueID)
    end

    -- get zombie data
    local nonPersistentZData = ZomboidForge.GetNonPersistentZData(trueID)

    -- attribute zombie type if not set by weighted random
    if rollZType then
        local ZType = nonPersistentZData.ZType
        if not ZType or not ZomboidForge.ZTypes[ZType] then
            nonPersistentZData.ZType = ZomboidForge.RollZType(trueID)
        end
    end

    -- set zombie age
    if zombie:getAge() ~= -1 then
		zombie:setAge(-1)
	end
end

--- Main function:
-- 
-- Handles everything about the Zombies.
-- Steps of Zombie update:
--
--      `Initialize zombie type`
--      `Update zombie data and stats`
--      `Run custom behavior`
--      `Run zombie attack function`
---@param zombie        IsoZombie
ZomboidForge.ZombieUpdate = function(zombie)
    -- get zombie data
    local trueID = ZomboidForge.pID(zombie)
    local nonPersistentZData = ZomboidForge.GetNonPersistentZData(trueID)

    local ZType = nonPersistentZData.ZType
    -- initialize zombie if needed
    if not ZType then
        ZomboidForge.ZombieInitiliaze(zombie,true,true)
        return
    end

    local ZombieTable = ZomboidForge.ZTypes[ZType]

    -- run custom behavior functions for this zombie
    if ZombieTable.customBehavior then
        for i = 1,#ZombieTable.customBehavior do
            ZomboidForge[ZombieTable.customBehavior[i]](zombie,ZType)
        end
    end

    -- run zombie attack functions
    if zombie:isAttacking() then
        ZomboidForge.ZombieAgro(zombie,ZType)
    end
end

local zombieList
local zeroTick = 0
-- Handles the updating of the stats of every zombies as well as initializing them. zombieList is initialized
-- for the client and doesn't need to be changed after. The code goes through every zombie index and updates
-- the stats of each zombies at a rate of 1/tick. A higher update rate for zombies shouldn't be needed as you
-- update 60 zombies for every ticks and you will rarely play x16 population with this mod.
--
-- The part updating one zombie per tick was made by `Albion`.
--
-- Added to `OnTick`.
---@param tick          int
ZomboidForge.OnTick = function(tick)
    -- initialize zombieList
    if not zombieList then
        zombieList = getPlayer():getCell():getZombieList()
    end

    -- Update zombie stats
    local zombieIndex = tick - zeroTick
    if zombieList:size() > zombieIndex then
        local zombie = zombieList:get(zombieIndex)
        ZomboidForge.SetZombieData(zombie,nil)
    else
        zeroTick = tick + 1
    end

    -- if players are allowed to use nametags
    if SandboxVars.ZomboidForge.Nametags then
        ZomboidForge.UpdateNametag()
    end
end

--- `Zombie` has agro on an `IsoGameCharacter`. 
-- 
-- Trigger `zombieAgro` of `Zombie` depending on `ZType`.
---@param zombie        IsoZombie
---@param ZType         string
ZomboidForge.ZombieAgro = function(zombie,ZType)
    local target = zombie:getTarget()
    if target and target:isCharacter() then
        local ZombieTable = ZomboidForge.ZTypes[ZType]
        if instanceof(target, "IsoPlayer") then
            ---@cast target IsoPlayer
            ZomboidForge.ShowZombieName(target, zombie)
        end
        if ZombieTable.zombieAgro then
            for i=1,#ZombieTable.zombieAgro do
                ZomboidForge[ZombieTable.zombieAgro[i]](target,zombie,ZType)
            end
        end
    end
end

--- `Player` attacking `Zombie`. 
-- 
-- Trigger `funconhit` of `Zombie` depending on `ZType`.
--
-- Handles the custom HP of zombies and apply custom damage depending on the customDamage function.
---@param attacker      IsoPlayer
---@param zombie        IsoZombie
ZomboidForge.OnHit = function(attacker, zombie, handWeapon, damage)
    if zombie:isZombie() then
        local trueID = ZomboidForge.pID(zombie)
        local nonPersistentZData = ZomboidForge.GetNonPersistentZData(trueID)

        local ZType = nonPersistentZData.ZType
        local ZombieTable = ZomboidForge.ZTypes[ZType]

        if ZType then
            if ZombieTable and ZombieTable.zombieOnHit then
                for i=1,#ZombieTable.zombieOnHit do
                    ZomboidForge[ZombieTable.zombieOnHit[i]](attacker, zombie, handWeapon, damage)
                end
            end
            ZomboidForge.ShowZombieName(attacker, zombie)
        end

        -- only calculates damage if it's the player hitting the zombie
        if attacker == getPlayer() then
            -- skip if no HP stat or HP is 1
            local HP = ZombieTable.HP
            if HP and HP ~= 1 and handWeapon:getFullType() ~= "Base.BareHands" then
                -- use custom damage function if exists
                if ZombieTable.customDamage then
                    damage = ZomboidForge[ZombieTable.customDamage](attacker, zombie, handWeapon, damage)
                end

                -- set zombie health or kill zombie
                if isClient() then
                    zombie:addLineChatElement("damage = "..damage)
                    local args = {
                        damage = damage,
                        trueID = trueID,
                        zombie = zombie:getOnlineID(),
                        defaultHP = HP,
                        shouldNotStagger = ZombieTable.shouldNotStagger,
                    }

                    sendClientCommand('ZombieHandler', 'DamageZombie', args)
                else
                    -- get zombie persistent data
                    local PersistentZData = ZomboidForge.GetPersistentZData(trueID)

                    HP = PersistentZData.HP or HP
                    HP = HP - damage

                    if HP <= 0 then
                        -- reset emitters
                        zombie:getEmitter():stopAll()
                        zombie:Kill(attacker)
                    else
                        -- Makes sure the Zombie doesn't get oneshoted by whatever bullshit weapon
                        -- someone might use.
                        -- Updates the HP counter of PersistentZData
                        zombie:setHealth(ZomboidForge.InfiniteHP)
                        zombie:setAttackedBy(getCell():getFakeZombieForHit())
                        PersistentZData.HP = HP
                    end
                end
            end
        end
    end
end

--- OnDeath functions
---@param zombie        IsoZombie
ZomboidForge.OnDeath = function(zombie)
    local trueID = ZomboidForge.pID(zombie)

    local nonPersistentZData = ZomboidForge.GetNonPersistentZData(trueID)

    local ZType = nonPersistentZData.ZType
    -- initialize zombie type
    -- only a security for mods that insta-kill zombies on spawn
    if not ZType then
        ZomboidForge.ZombieInitiliaze(zombie,true,true)
    end

    local ZombieTable = ZomboidForge.ZTypes[ZType]
    if ZombieTable.zombieDeath then
        -- run custom behavior functions for this zombie
        for i = 1,#ZombieTable.zombieDeath do
            ZomboidForge[ZombieTable.zombieDeath[i]](zombie,ZType)
        end
    end

    -- reset emitters
    zombie:getEmitter():stopAll()

    -- delete zombie data
    ZomboidForge.DeleteZombieData(trueID)
end
