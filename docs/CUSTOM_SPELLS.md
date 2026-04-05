# Novas magias (spells) no Canary

Guia alinhado ao estilo de [CUSTOM_ITEMS_AND_WEAPONS.md](./CUSTOM_ITEMS_AND_WEAPONS.md): onde colocar ficheiros, o que não pode duplicar e como encaixar **Combat**, condições e vocações.

## 1. Onde vivem as magias

- **`data/scripts/spells/`** — revscripts carregados automaticamente (subpastas por função: `attack`, `healing`, `support`, `conjuring`, `house`, `party`, etc.).
- **Modelo completo** (instant + conjurar runa + runa): `data/scripts/spells/#example.lua` (ficheiro de exemplo; não é carregado se o nome começar por `#` — renomeia se quiseres usar como base ativa).

Não é necessário registo manual num XML de spells: o **`spell:register()`** no fim do Lua entra no sistema em `g_spells()`.

## 2. Tipos de spell em Lua

| Criação | Uso típico |
|--------|------------|
| `Spell("instant")` | Magias instantâneas (palavras no chat, ex.: `utani hur`). |
| `Spell("rune")` ou `Spell(SPELL_RUNE)` | Efeito ao **usar o item runa** (item com charges). |
| `Spell("instant")` + `conjureItem` | Spell de **conjuração** que cria runas/itens (`data/scripts/spells/conjuring/*.lua`). |

O motor distingue instant vs rune em `SpellFunctions::luaSpellCreate` / `luaSpellRegister` (`src/lua/functions/creatures/combat/spell_functions.cpp`).

## 3. Esqueleto mínimo — instantânea

```lua
local spell = Spell("instant")

function spell.onCastSpell(creature, variant)
	-- lógica; muitas magias devolvem combat:execute(creature, variant)
	return true
end

spell:name("Nome Interno")
spell:words("exemplo words")
spell:group("support")           -- attack | healing | support | ...
spell:level(8)
spell:mana(40)
spell:vocation("knight;true", "elite knight;true")
spell:id(1234)                   -- recomendado: ID numérico único
spell:cooldown(2 * 1000)
spell:groupCooldown(2 * 1000)
spell:needLearn(false)
spell:register()
```

- **`spell:onCastSpell(...)`** — obrigatório registar o callback (padrão `function spell.onCastSpell` como nos scripts vanilla).
- **`spell:words(...)`** — deve ser **único** entre instantâneas (é o que o jogador escreve).
- **`spell:id(...)`** — deve ser **único** entre todas as magias que usam ID (instant + rune). Antes de escolher, procura no repositório: `spell:id(` ou conflitos no spellbook do cliente.
- **`spell:vocation("nome;true", ...)`** — nomes em minúsculas como em `data/XML/vocations.xml` (`"sorcerer;true"` permite não-promovido e promovido se ambos listados).

Referências rápidas:

- Só buff / `Combat` + condição: `data/scripts/spells/support/haste.lua`
- Dano + fórmula skill (estilo knight): `data/scripts/spells/attack/whirlwind_throw.lua`
- Dano + fórmula level/ml: `data/scripts/spells/attack/divine_caldera.lua`
- Conjurar item: `data/scripts/spells/conjuring/light_magic_missile_rune.lua`

## 4. Dano, área, cura e callbacks

Muitas magias reutilizam **`Combat()`**:

- `combat:setParameter(COMBAT_PARAM_TYPE, COMBAT_…)` — tipo de dano ou cura.
- `combat:setParameter(COMBAT_PARAM_EFFECT, CONST_ME_…)` — efeito visual.
- `combat:setArea(createCombatArea(...))` ou `createCombatArea(AREA_CIRCLE3X3)` — AOE.
- `combat:setCallback(CALLBACK_PARAM_SKILLVALUE, "onGetFormulaValues")` — dano baseado em skill + attack (arma).
- `combat:setCallback(CALLBACK_PARAM_LEVELMAGICVALUE, "onGetFormulaValues")` — baseado em level + magic level.

Depois: `return combat:execute(creature, variant)` dentro de `onCastSpell`.

**Sons:** `spell:castSound(...)`, `spell:impactSound(...)` ou parâmetros `COMBAT_PARAM_CASTSOUND` / `COMBAT_PARAM_IMPACTSOUND` no `Combat` — reutiliza constantes `SOUND_EFFECT_TYPE_*` de magias parecidas.

## 5. Runas (spell no item)

1. Cria **`Spell(SPELL_RUNE)`** (ou `Spell("rune")`).
2. Define **`spell:runeId(ID_DO_ITEM)`** — item da runa no `items.xml` (ex.: blank rune / runa específica).
3. **`spell:id(ID_DA_MAGIA)`** — ID da spell (diferente de outros).
4. **`spell:level` / `spell:magicLevel`** — requisitos mostrados na descrição da runa (o motor atualiza `ItemType` da runa quando estes valores são ≠ 0).
5. **`spell:charges(n)`**, **`spell:needTarget`**, **`spell:allowFarUse`**, **`spell:blockWalls`**, etc., conforme o caso.

Conjuração da runa = outra **`Spell("instant")`** com `creature:conjureItem(3147, runaId, quantidade)` (ver `#example.lua`).

## 6. Grupos, alvo e flags úteis

- **`spell:group("attack"|"healing"|"support"|…)`** — afeta cooldown de grupo e interações (ex.: *powerless* em grupo attack).
- **`spell:needTarget(true)`** / **`spell:isSelfTarget(true)`**
- **`spell:blockWalls(true)`**, **`spell:range(n)`**
- **`spell:needWeapon(true)`** — exige arma na mão.
- **`spell:isAggressive(false|true)`** — PZ / skull.
- **`spell:isPremium(true)`**, **`spell:soul(n)`**, **`spell:manaPercent(n)`**
- **`spell:secondaryGroup("…")`** — se existir no teu script base (algumas magias usam grupo secundário).

## 7. Checklist

- [ ] Ficheiro `.lua` em `data/scripts/spells/...` (subpasta lógica).
- [ ] `spell:words` único (instant) ou runa + conjuração coerentes.
- [ ] `spell:id` único (recomendado para todas as magias com ID).
- [ ] `spell:vocation(...)` com nomes que existem em `vocations.xml` (ou adiciona vocação nova — ver [CUSTOM_VOCATIONS.md](./CUSTOM_VOCATIONS.md)).
- [ ] `spell:register()` no fim.
- [ ] Reiniciar o servidor para carregar o script.
- [ ] (Cliente) ícones / animações de spell se o cliente for personalizado.

## Ver também

- [Itens e armas em Lua](./CUSTOM_ITEMS_AND_WEAPONS.md)
- [Vocações](./CUSTOM_VOCATIONS.md)
