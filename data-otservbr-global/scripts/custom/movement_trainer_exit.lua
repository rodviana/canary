local EXIT_POSITION = Position(32348, 32212, 7)

local function teleportToExit(creature)
	if not creature:isPlayer() then
		return true
	end

	creature:teleportTo(EXIT_POSITION)
	creature:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
	return true
end

local trainerExit = MoveEvent()
function trainerExit.onStepIn(creature, item, position, fromPosition)
	teleportToExit(creature)
	return true
end

local positions = {
	{ x = 991, y = 1031, z = 7 },
	{ x = 1057, y = 1023, z = 7 },
	{ x = 1058, y = 1023, z = 7 },
}
for index, position in pairs(positions) do
	trainerExit:position(position)
end

trainerExit:aid(40015)
trainerExit:aid(4255)
trainerExit:register()
