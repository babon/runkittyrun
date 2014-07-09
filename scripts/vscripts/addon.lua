--USE_LOBBY = false -- d2modd.in himself distributes players on teams, sooo if you testing addon at local dota - set this to false
PREFIX = '[RunKittyRun] ' -- prefix that shows in console messages, pls use >>print(PREFIX..text)<<

D2MODDIN = true

ROUNDS = 3
GameMode = nil -- dont touch :)

--///SOME MAIN STUFF, TOUCH VERY CAREFULLY\\\--

if Addon == nil then
	print ( PREFIX..'Creating Game Mode..' )
	Addon = {}
	Addon.szEntityClassName = "loadtester"
	Addon.szNativeClassName = "dota_base_game_mode"
	Addon.__index = Addon
end

function Addon:new( o )
	o = o or {}
	setmetatable( o, Addon )
	return o
end

function Addon:InitGameMode()
	print(PREFIX..'Initialization...')

	Addon:onEnable()

	-- Change random seed
	local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
	math.randomseed(tonumber(timeTxt))


	--Addon:FixPrecache()
	print(PREFIX..'Done precaching!') 
	print(PREFIX..'DONE INITIALIZATION!\n\n')
end


--///UTILS\\\--

function Addon:HandleEventError(name, event, err)
	-- This gets fired when an event throws an error

	-- Log to console
	print(PREFIX..err)

	-- Ensure we have data
	name = tostring(name or 'unknown')
	event = tostring(event or 'unknown')
	err = tostring(err or 'unknown')

	-- Tell everyone there was an error
	Say(nil, name .. ' threw an error on event '..event, false)
	Say(nil, err, false)

	-- Prevent loop arounds
	if not self.errorHandled then
		-- Store that we handled an error
		self.errorHandled = true
	end
end

function Addon:ShowCenterMessage(msg,dur)
	local msg = {
		message = msg,
		duration = dur
	}
	FireGameEvent("show_center_message",msg)
end

function GetNick(ply)
	return Addon.Nickname[ply]
end

function Addon:SpawnItemOnGround(name,loc)
	local Phys = CreateItemOnPosition(loc)
	local item = CreateItem(name,nil,nil)
	Phys:SetContainedItem(item)
end

function Addon:RemoveItem(hero,name)
	for i=0,5,1 do
		local item = hero:GetItemInSlot(i)
		if item ~= nil then
			if item:GetName() == name then
				item:Remove()
			end
		end
	end
end

function Addon:ClearInventory(hero)
	for i=0,5,1 do
		local item = hero:GetItemInSlot(i)
		if item ~= nil then
			item:Remove()
		end
	end
end

function Addon:GetItemByName( hero, name, lvl )
  --if not hero:HasItemInInventory ( name ) then
  --	return nil
  --end

  --print ( '[REFLEX] find item in inventory' )
  -- Find item by slot
  for i=0,11 do
    --print ( '\t[REFLEX] finding item ' .. i)
    local item = hero:GetItemInSlot( i )
    --print ( '\t[REFLEX] item: ' .. tostring(item) )
    if item ~= nil then
      --print ( '\t[REFLEX] getting ability name' .. i)
      local lname = item:GetAbilityName()
      --print ( string.format ('[REFLEX] item slot %d: %s', i, lname) )
      if lname == name then
		if (item:GetLevel() == lvl) or (lvl == 0) then
			return item
		end
      end
    end
  end

  return nil
end

function Addon:SpawnSomeEntities()
	local ents = Entities:FindAllByName('wolf')
	for k, v in pairs(ents) do
		local wolf = CreateUnitByName('npc_dota_lycan_wolf_kitty', v:GetAbsOrigin(), true, nil, nil, DOTA_TEAM_NOTEAM)
		wolf:AddNewModifier(ply,nil,'modifier_invulnerable',{})
		self.WolfHome[wolf] = v:GetAbsOrigin()
	end
end

function Addon:SpawnGoldBags()
	local ents = Entities:FindAllByName('goldbag')
	for k, v in pairs(ents) do
		if RandomInt(1,2) == 1 then
			Addon:SpawnItemOnGround("item_kittyrun_goldbag", v:GetAbsOrigin())
		end
	end
end

function Addon:DespawnGoldBags()
	local ents = Entities:FindAllByClassname('dota_item_drop')
	for k, v in pairs(ents) do
		v:Remove()
	end
end


 --///STANDART FUNCTIONS, DONT DELETE\\\---

function Addon:onEnable() -- This function called when mod is initializing

		-- Variables
	self.Players = {}
	self.NicknameUserId = {}
	self.Nickname = {}
	self.UntouchTime = {}
	self.WolfHome = {}
	self.isRootedFirstTime = false
	self.MusicTime = 0
	self.Countdown = 0
	self.isEntSpawned = false
	self.StopThink = false
	
		-- Setup rules
	GameRules:SetUseUniversalShopMode( true )
	GameRules:SetPreGameTime( 3.0 )
	GameRules:SetPostGameTime( 10.0 )
	GameRules:SetGoldPerTick(0)
	print(PREFIX..'Rules set!')
	
		-- Register hooks
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(Addon, 'onPlayerLoaded'), self)
	ListenToGameEvent('player_connect', Dynamic_Wrap(Addon, 'onPlayerConnect'), self)
	ListenToGameEvent('dota_item_picked_up', Dynamic_Wrap(Addon, 'onItemPicked'), self)
	ListenToGameEvent('dota_item_purchased', Dynamic_Wrap(Addon, 'onItemPurchased'), self)
	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(Addon, 'onGameStateChanged'), self)
	print(PREFIX..'Hooks registered!')
	
		-- Register commands
	-- Convars:RegisterCommand( "x2", Dynamic_Wrap(Addon, 'SpawnSomeEntities'), "Spawn another lane on wolfs", 0 )
	print(PREFIX..'Commands registered!')

	thinkHack( "Addon", Dynamic_Wrap( Addon, "Loop" ), 0.1, self)
	
	PrecacheUnitByName('npc_precache_everything')
	print(PREFIX..'Everything precached!')

end

function Addon:Loop()
	if GameRules:State_Get() <= DOTA_GAMERULES_STATE_PRE_GAME then
		return
	end
	if self.StopThink == true then return end

	self.Countdown = self.Countdown+1

	local PeopleStunned = 0
	for k, ply in pairs(self.Players) do -- Every 0.1 second check collisions
		if not ply:HasModifier('modifier_stunned') then
			if self.UntouchTime[ply:GetPlayerID()] > 0 then
				self.UntouchTime[ply:GetPlayerID()] = self.UntouchTime[ply:GetPlayerID()]-1
			else
				local ents = Entities:FindAllInSphere(ply:GetAbsOrigin(),100)
				for k, v in pairs(ents) do
				
					if v:GetClassname() == 'npc_dota_creep_neutral' then
						-- Игрок напоролся на кошку
						GameRules:SendCustomMessage(COLOR_GOLD..GetNick(ply)..COLOR_NONE..' get stunned!',0,0)
						ply:AddNewModifier(ply,nil,'modifier_stunned',{})
						PlayerResource:IncrementDeaths(ply:GetPlayerID())
					end
					
					if v:GetName() == 'win' then
						-- Игрок дошел до конца карты
						GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
						local winnerNick = PlayerResource:GetPlayerName(ply:GetOwner():GetPlayerID())
						Addon:ShowCenterMessage(GetNick(ply)..' WINNER WINNER CHICKEN DINNER! :D',4)
						self.StopThink = true
					end
					
				end
			end
		else
			PeopleStunned = PeopleStunned+1
		end
	end
	if PeopleStunned == #self.Players then
		ROUNDS = ROUNDS - 1
		if ROUNDS == 0 then -- Game is fully losed
			Say(nil,COLOR_RED..'All kitties are dead, kitties lose the game!',false)
			Addon:ShowCenterMessage('All kitties are dead, kitties lose the game! :(',4)
			GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)
			self.StopThink = true
		else -- Round loosed
			for k, ply in pairs(self.Players) do
				ply:RemoveModifierByName('modifier_stunned')
				--ply:SetAbsOrigin(Vector(3376,-640,512))
				FindClearSpaceForUnit(ply, Vector(3650,-500,512), true)
				ply:AddNewModifier(ply,nil,'modifier_rooted',{ duration = 5 })
				ply:SetGold(0,true)
				Addon:ClearInventory(ply)
			end
			Say(nil,COLOR_RED..'All kitties are dead...! '..ROUNDS..' rounds left!',false)
			Addon:ShowCenterMessage('All kitties are dead...! '..ROUNDS..' rounds left!',4)
			Addon:DespawnGoldBags()
			Addon:SpawnGoldBags()
		end
	end


	if self.Countdown == 10 then -- Every second | Random moving
		local ents = Entities:FindAllByClassname('npc_dota_creep_neutral')
		--local testUnit = CreateUnitByName('npc_dota_lycan_wolf_kitty', Vector(999999,999999,999999), false, nil, nil, DOTA_TEAM_GOODGUYS)
		for k, v in pairs(ents) do
			if RandomInt(1,3) == 2 then
				local vec = v:GetAbsOrigin()
				vec.x = vec.x + RandomInt(-300,300)
				vec.y = vec.y + RandomInt(-300,300)
				
				local height = GetGroundPosition(Vector(vec.x,vec.y,0), nil)
				if height.z == v:GetAbsOrigin().z then
				
					local homeX = self.WolfHome[v].x
					local homeY = self.WolfHome[v].y
					local dist = math.sqrt( (homeX-vec.x)^2 + (homeY-vec.y)^2 )
					if dist>300 then
						v:MoveToPosition(self.WolfHome[v])
					end
					
					local isSafeZone = Entities:FindAllInSphere(vec,500) -- Проверка на сейв-зону
					local isNotAllowed = false
					for k, ent in pairs(isSafeZone) do
						if ent:GetName() == 'safe' then
							isNotAllowed = true
						end
					end
					if isNotAllowed == false then
						v:MoveToPosition(vec)
					end
				
				end
			end
		end
		--testUnit:Remove()
		self.Countdown = 0
		
		-- Music
		--[[if self.MusicTime == 0 then
			local number = RandomInt(1,5)
			EmitGlobalSound( "Music_kittyrun."..tostring(number) )
			if number == 1 then self.MusicTime = 130 end
			if number == 2 then self.MusicTime = 78 end
			if number == 3 then self.MusicTime = 154 end
			if number == 4 then self.MusicTime = 136 end
			if number == 5 then self.MusicTime = 140 end
		else
			self.MusicTime = self.MusicTime-1
		end--]]
		
	end

end

 --///YOUR HOOKS\\\--

function Addon:onPlayerLoaded(keys)

	if GameMode == nil then
		GameMode = GameRules:GetGameMode()
		GameMode:SetFogOfWarDisabled(true)
	end
	
	local ply = EntIndexToHScript(keys.index+1)
	local playerID = ply:GetPlayerID()

	if PlayerResource:IsBroadcaster(playerID) then -- Spectating suck, play yourself
		return
	end
	
	-- If player connecting at first time
	if playerID == -1 then
		ply:SetTeam(DOTA_TEAM_GOODGUYS)
		ply = CreateHeroForPlayer('npc_dota_hero_mirana', ply)
		table.insert(self.Players,ply)
		--Physics:Unit(ply)
		--ply:Slide(true) -- Эффект скольжения
		--ply:SetSlideMultiplier(5)
	elseif D2MODDIN then
		local found = false
		for i=1,#self.Players do
			if self.Players[i] == ply then
				found = true
				break
			end
		end
		if not found then
			ply = CreateHeroForPlayer('npc_dota_hero_mirana', ply)
			table.insert(self.Players,ply)
		end
	end
	
	if self.isEntSpawned == false then
		Addon:SpawnSomeEntities()
		Addon:SpawnGoldBags()
		self.isEntSpawned = true
	end
	
	ply:SetGold(0,false)
	self.UntouchTime[ply:GetPlayerID()] = 0
	self.Nickname[ply] = self.NicknameUserId[keys.userid]
	ply:SetAbilityPoints(0)
	local ab = ply:FindAbilityByName('retreive_kittyrun')
	ab:SetLevel(1)
end

function Addon:onPlayerConnect(keys)
	self.NicknameUserId[keys.userid] = keys.name -- PlayerResource:GetPlayerName dont work, this hack stolen from BMD
end

function retrieveKittySpell(keys)
	local target = keys.target
	local caster = keys.caster
	if target:HasModifier('modifier_stunned') then
		Addon.UntouchTime[target:GetPlayerID()] = 20
		target:RemoveModifierByName('modifier_stunned')
		PlayerResource:IncrementAssists(caster:GetPlayerID())
		--local CasterNick = Addon.NicknameUserId[caster:GetPlayerID()] or 'FAKE'
		--local TargetNick = Addon.NicknameUserId[target:GetPlayerID()] or 'FAKE'
		--Say(nil,COLOR_GOLD..CasterNick..COLOR_NONE..' retrieved '..COLOR_GOLD..TargetNick,false)
	else
		-- Full of nothing
	end
end

function Addon:onItemPicked(keys)
	if keys.itemname == 'item_kittyrun_goldbag' then
		local ply = PlayerResource:GetPlayer(keys.PlayerID)
		EmitSoundOnClient('General.CoinsBig',ply)
		ply = ply:GetAssignedHero()
		ply:ModifyGold(100,true,0)
		Addon:RemoveItem(ply,'item_kittyrun_goldbag')
	end
end

function Addon:onItemPurchased(keys)

	local itemname = keys.itemname
	local player = PlayerResource:GetPlayer(keys.PlayerID):GetAssignedHero()
	
	local item = Addon:GetItemByName(player,itemname,1)
	item:Remove()
	if player:HasItemInInventory(itemname) then
		local upitem = Addon:GetItemByName(player,itemname,0)
		if upitem:GetLevel() < 4 then
			upitem:SetLevel(upitem:GetLevel()+1) -- Up item level
		else
			player:ModifyGold(keys.itemcost,true,0) -- Return money if item at the max level
		end
	else
		local newitem = CreateItem(keys.itemname,player,nil)
		player:AddItem(newitem)
	end
	
end

function Addon:onGameStateChanged()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then
		for k, ply in pairs(self.Players) do
			ply:AddNewModifier(ply,nil,'modifier_rooted',{ duration = 5 })
		end
	end
end