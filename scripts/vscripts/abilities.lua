function itemGemOfInvul(keys)
	local caster = keys.caster
	Addon.UntouchTime[caster:GetPlayerID()] = tonumber(keys.Duration)*10
	caster:AddNewModifier(caster,nil,'modifier_invulnerable',{ duration = tonumber(keys.Duration) })
end
