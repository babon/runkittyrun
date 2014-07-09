local function loadModule(name)
    local status, err = pcall(function()
        -- Load the module
        require(name)
    end)

    if not status then
        -- Tell the user about it
        print('WARNING: '..name..' failed to load!')
        print(err)
    end
end

function thinkHack(name, func, delay, scope)
    local gameBase = Entities:FindAllByClassname('dota_base_game_mode')[1]
    local n = '2'
    local function thinkFix()
	
		-- Requeue this think
		gameBase:SetContextThink(name..n, thinkFix, delay)

		-- Cycle events
		if n == '' then
			n = '2'
		else
			n = ''
		end

		-- Run normal think
		func(scope)
	
    end
 
    gameBase:SetContextThink(name, thinkFix, delay)
    return gameBase
end

loadModule ('util')
loadModule ('physics')
loadModule ('addon')
print('MODULES LOADED!')