local area = createCombatArea({
	{ 1, 1, 1 },
	{ 1, 3, 1 },
	{ 1, 1, 1 },
})

local combat = Combat()
combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_HOLYDAMAGE)
combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_HOLYAREA)
combat:setParameter(COMBAT_PARAM_DISTANCEEFFECT, CONST_ANI_WEAPONTYPE)
combat:setParameter(COMBAT_PARAM_BLOCKARMOR, true)
combat:setParameter(COMBAT_PARAM_CASTSOUND, SOUND_EFFECT_TYPE_SPELL_OR_RUNE)
combat:setParameter(COMBAT_PARAM_IMPACTSOUND, SOUND_EFFECT_TYPE_SPELL_WHIRLWIND_THROW)
combat:setArea(area)

function onGetFormulaValues(player, skill, attack, factor)
	local level = player:getLevel()
	local min = (level / 5) + (skill + attack) / 3
	local max = (level / 5) + skill + attack
	return -min * 1.28, -max * 1.28
end

combat:setCallback(CALLBACK_PARAM_SKILLVALUE, "onGetFormulaValues")

local sword = Weapon(WEAPON_SWORD)

function sword.onUseWeapon(player, variant)
	return combat:execute(player, variant)
end

sword:id(3264)
sword:attack(14)
sword:defense(12)
sword:register()
