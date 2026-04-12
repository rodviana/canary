local LEVEL_GOLD_REWARDS = {
	[20] = 20000,
	[50] = 100000,
	[150] = 200000,
	[200] = 500000,
	[250] = 500000,
	[300] = 3000000,
	[400] = 4000000,
	[500] = 5000000,
	[600] = 6000000,
	[700] = 7000000,
	[800] = 8000000,
	[900] = 9000000,
	[1000] = 10000000,
}

local function grantLevelGoldRewards(player, oldLevel, newLevel)
	for level = oldLevel + 1, newLevel do
		local amount = LEVEL_GOLD_REWARDS[level]
		if amount and amount > 0 then
			local kvKey = "level-gold-reward." .. level
			local kv = player:kv()
			if not kv:get(kvKey) then
				player:setBankBalance(player:getBankBalance() + amount)
				kv:set(kvKey, true)
				player:sendTextMessage(
					MESSAGE_GAME_HIGHLIGHT,
					string.format(
						"Level %d reached! %s gold have been added to your bank account.",
						level,
						FormatNumber(amount)
					)
				)
			end
		end
	end
end

local updatePlayerOnAdvancedLevel = CreatureEvent("UpdatePlayerOnAdvancedLevel")

function updatePlayerOnAdvancedLevel.onAdvance(player, skill, oldLevel, newLevel)
	if skill ~= SKILL_LEVEL or newLevel <= oldLevel then
		return true
	end

	grantLevelGoldRewards(player, oldLevel, newLevel)

	player:addHealth(player:getMaxHealth())
	player:addMana(player:getMaxMana())
	player:getFinalLowLevelBonus()
	player:save()
	return true
end

updatePlayerOnAdvancedLevel:register()
