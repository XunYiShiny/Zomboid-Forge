--[[ ================================================ ]]--
--[[  /~~\'      |~~\                  ~~|~    |      ]]--
--[[  '--.||/~\  |   |/~\/~~|/~~|\  /    | \  /|/~~|  ]]--
--[[  \__/||     |__/ \_/\__|\__| \/   \_|  \/ |\__|  ]]--
--[[                     \__|\__|_/                   ]]--
--[[ ================================================ ]]--
--[[

This file defines the server side lua of ZomboidForge.

]]--
--[[ ================================================ ]]--

if not isServer() then return end

--- Import functions localy for performances reasons
local table = table -- Lua's table module
local ipairs = ipairs -- ipairs function
local pairs = pairs -- pairs function
local ZombRand = ZombRand -- java function
local tostring = tostring --tostring function

--- import module
local ZomboidForge_server = require "ZomboidForgeServer_module"
local ZFModData = ModData.getOrCreate("ZomboidForge")

ZomboidForge_server.initModData_ZomboidForgeServer_commands = function()
    ZFModData = ModData.getOrCreate("ZomboidForge")
end

--#region Server side commands
-- ZomboidForge.Commands.module.command

-- Updates animation variables of zombies for every single clients.
ZomboidForge_server.Commands.ZombieHandler.SetAnimationVariable = function(player, args)
	sendServerCommand('ZombieHandler', 'SetAnimationVariable', {id = player:getOnlineID(), animationVariable = args.animationVariable, zombie =  args.zombie, state = args.state})
end

-- Updates animation variables of zombies for every single clients.
ZomboidForge_server.Commands.ZombieHandler.RemoveEmitters = function(player, args)
	sendServerCommand('ZombieHandler', 'RemoveEmitters', {id = player:getOnlineID(),zombie = args.zombie})
end

ZomboidForge_server.Commands.ZombieHandler.KillZombie = function(player,args)
	sendServerCommand(
		"ZombieHandler",
		"KillZombie",
		{
			attacker = player:getOnlineID(),
			kill = true,
			zombie = args.zombieOnlineID,
		}
	)
end

ZomboidForge_server.Commands.ZombieHandler.UpdateHealth = function(player,args)
	-- only update if call from attacker
	local attacker = getPlayerByOnlineID(args.attackerOnlineID)
	if player ~= attacker then return end

	-- get zombie
	local zombieID = args.zombieOnlineID
	local zombie = ZomboidForge_server.getZombieByOnlineID(attacker,zombieID)
	if not zombie then return end

	-- set zombie health
	zombie:setHealth(args.defaultHP)

	-- kill zombie if zombie should die
	if args.defaultHP <= 0 then
		ZomboidForge_server.Commands.ZombieHandler.KillZombie(attacker,{zombieOnlineID = zombieID})
	end
end

--#endregion