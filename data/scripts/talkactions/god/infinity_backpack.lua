local infinityBackpackCmd = TalkAction("!infinitybackpack", "!infinityBackpack")

function infinityBackpackCmd.onSay(player, words, param)
	logCommand(player, words, param)

	local backpackId = configManager.getNumber(configKeys.INFINITY_BACKPACK_ITEM_ID)
	if backpackId <= 0 then
		player:sendCancelMessage("Infinity backpack is disabled in config (infinityBackpackItemId).")
		return true
	end

	local itemType = ItemType(backpackId)
	if itemType:getId() ~= backpackId then
		player:sendCancelMessage("Invalid infinityBackpackItemId in config.")
		return true
	end

	local item = player:addItem(backpackId, 1)
	if not item then
		player:sendCancelMessage("Could not add the backpack (not enough capacity or space).")
		return true
	end

	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN)
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You received a " .. itemType:getName() .. ".")
	return true
end

infinityBackpackCmd:separator(" ")
infinityBackpackCmd:groupType("god")
infinityBackpackCmd:register()
