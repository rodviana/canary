local infiniteExerciseChargeKey = "exerciseInfiniteCharges"

local config = {
	charges = 1800,
	items = {
		50294, -- durable exercise wraps
		35279, -- durable exercise sword
		35280, -- durable exercise axe
		35281, -- durable exercise club
		35282, -- durable exercise bow
		35283, -- durable exercise rod
		35284, -- durable exercise wand
		44066, -- durable exercise shield
	},
}

local exercise = TalkAction("!exercise")

function exercise.onSay(player, words, param)
	local inbox = player:getStoreInbox()
	if not inbox then
		player:sendCancelMessage("Could not access your store inbox.")
		return true
	end

	local added = 0
	for _, itemId in ipairs(config.items) do
		local item = inbox:addItem(itemId, config.charges)
		if not item then
			player:sendCancelMessage("Not enough room in your store inbox to receive all exercise weapons.")
			return true
		end

		item:setCustomAttribute(infiniteExerciseChargeKey, 1)
		added = added + 1
	end

	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("%d exercise weapons were added to your store inbox with charge bypass enabled.", added))
	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN)
	return true
end

exercise:separator(" ")
exercise:groupType("normal")
exercise:register()
