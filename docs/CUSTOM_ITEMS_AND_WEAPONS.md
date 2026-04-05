# Itens customizados e armas com mecânica em Lua

Este guia descreve como **criar itens** no Canary e como **ligar mecânicas** (por exemplo dano em área, elemento sagrado, efeitos e sons), no mesmo espírito do exemplo **“A Espada Sagrada de Rodrigo”**.

## 1. O que o servidor usa para definir um item

1. **Aparências (protobuf / assets do cliente)** — carregadas primeiro (`Items::loadFromProtobuf`). Definem grande parte dos metadados visuais e de objeto vindos do catálogo do cliente.
2. **`data/items/items.xml`** — sobrepõe e completa: nome, peso, ataque, slots, `script` de move/weapon, imbuements, etc.
3. **Scripts em Lua (revscripts)** — por exemplo `data/scripts/weapons/scripts/*.lua` para armas com `onUseWeapon` personalizado.

Sem um ID reconhecido pelo fluxo acima, comandos como **`/i`** falham com *“There is no item with that id or name.”*

### 1.1 Itens só no `items.xml` (ID ainda não no cliente)

Neste fork foi ajustado o carregamento em `src/items/items.cpp`: se o ID **não** veio das aparências (slot “vazio” / reservado), o XML **ainda é aplicado** desde que o nó do item tenha o atributo **`name` preenchido**. Assim podes registar um item no servidor **antes** de existir no `appearances.pb` / editor do cliente — útil para testar com GOD; no cliente convém depois criar o mesmo ID para o sprite correto.

Requisito: **sempre** define `name="..."` no `<item>` para esses IDs “só servidor”.

## 2. Adicionar um item em `items.xml`

- Escolhe um **`id`** numérico único (evita colidir com itens do datapack).
- Inclui **`article`** e **`name`** (obrigatório para o bypass acima em IDs sem aparência).
- Para arma de mão:

```xml
<item id="51309" article="a" name="Nome do Item">
	<attribute key="primarytype" value="sword weapons"/>
	<attribute key="weaponType" value="sword"/>
	<attribute key="attack" value="42"/>
	<attribute key="defense" value="35"/>
	<attribute key="weight" value="3500"/>
	<attribute key="script" value="moveevent;weapon">
		<attribute key="weaponType" value="sword"/>
		<attribute key="slot" value="hand"/>
	</attribute>
</item>
```

Ajusta `attack`, `defense`, `imbuementslot`, `description`, etc., como nos itens vanilla próximos no ficheiro.

## 3. Arma com mecânica custom: script em `data/scripts/weapons/scripts/`

Os ficheiros nesta pasta são carregados como **revscripts**. Usa `Weapon(tipo)` e `:register()`.

Tipos comuns (C++/Lua):

- `WEAPON_SWORD`, `WEAPON_AXE`, `WEAPON_CLUB` — corpo a corpo (`WeaponMelee`).
- `WEAPON_AMMO` — munição (ex.: burst arrow).
- `WEAPON_MISSILE` / `WEAPON_DISTANCE` — à distância.

### 3.1 O mesmo ID no XML e no Lua

No script:

- `minhaArma:id(51309)` tem de coincidir com o `id` no `items.xml`.
- `minhaArma:attack(...)` / `:defense(...)` alinham com o que queres na fórmula e no tooltip.

O registo Lua **substitui** o weapon gerado só pelo XML para esse ID, mantendo o `moveevent;weapon` do XML para equipar na mão.

### 3.2 `onUseWeapon` + `Combat`

Quando defines `function minhaArma.onUseWeapon(player, variant) ... end`, o motor chama o Lua em vez do hit melee padrão. O `variant` traz o **alvo** (corpo a corpo).

Padrão útil:

1. Cria uma **área** com `createCombatArea({ ... })` — `3` marca o centro (tile do alvo), como na burst arrow.
2. `Combat()` com `setParameter` para tipo de dano, efeito no chão, projétil, sons, `BLOCKARMOR`, etc.
3. `combat:setArea(area)` se for AOE.
4. `combat:setCallback(CALLBACK_PARAM_SKILLVALUE, "onGetFormulaValues")` para dano baseado em level/skill/attack (igual a muitos spells e à Whirlwind Throw).
5. `return combat:execute(player, variant)`.

Referências no repositório:

- Área + físico: `data/scripts/weapons/scripts/burst_arrow.lua`
- Fórmula estilo **exori hur**: `data/scripts/spells/attack/whirlwind_throw.lua`
- Exemplo holy + espada + AOE: `data/scripts/weapons/scripts/espada_sagrada_rodrigo.lua`

### 3.3 Efeitos e animações (ideias)

- `COMBAT_PARAM_TYPE` — ex.: `COMBAT_HOLYDAMAGE`, `COMBAT_PHYSICALDAMAGE`, …
- `COMBAT_PARAM_EFFECT` — ex.: `CONST_ME_HITAREA` (Whirlwind Throw), `CONST_ME_EXPLOSIONAREA` (burst), `CONST_ME_HOLYAREA`, …
- `COMBAT_PARAM_DISTANCEEFFECT` — ex.: `CONST_ANI_WEAPONTYPE` (no cliente, espada vira projétil tipo whirlwind sword se o jogador usa sword)
- `COMBAT_PARAM_CASTSOUND` / `COMBAT_PARAM_IMPACTSOUND` — enums `SOUND_EFFECT_TYPE_*` (espelhar spells existentes)

## 4. Exemplo já implementado: A Espada Sagrada de Rodrigo

| Peça | Local |
|------|--------|
| Definição do item | `data/items/items.xml` — item `51309` |
| Mecânica | `data/scripts/weapons/scripts/espada_sagrada_rodrigo.lua` |

Comportamento resumido: ataque melee no alvo; o `Combat` aplica **área 3×3** centrada no alvo, dano **sagrado**, efeito **`CONST_ME_HITAREA`**, projétil **`CONST_ANI_WEAPONTYPE`**, sons no estilo Whirlwind Throw.

## 5. Testar e colocar no ar

1. **Recompilar** o executável do Canary se alteraste C++ (`items.cpp`).
2. **Reiniciar** o servidor (garante `items.xml` e revscripts atualizados).
3. Com conta **GOD**: `/i 51309` ou `/i 51309,1`.

## 6. Cliente e sprite

Mesmo com o item válido no servidor, o **cliente** precisa de uma entrada de aparência para esse **server ID** se quiseres ícone/chão corretos. Até lá, podes usar GOD no servidor; no editor do cliente, cria/duplica o sprite (ex.: copiar da sword `3264`) para o ID escolhido.

## 7. Checklist rápido

- [ ] `id` único no `items.xml` com **`name`** definido.
- [ ] Atributos de arma + `moveevent;weapon` coerentes com o tipo (sword/ammo/…).
- [ ] Ficheiro Lua em `data/scripts/weapons/scripts/`, `:id()` igual ao XML, `:register()` no fim.
- [ ] Servidor recompilado/reiniciado após mudanças em C++ ou dados.
- [ ] (Opcional) ID igual no cliente para o visual final.
