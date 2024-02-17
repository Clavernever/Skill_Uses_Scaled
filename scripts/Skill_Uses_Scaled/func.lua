local core  = require('openmw.core')
local self  = require('openmw.self')
local types = require('openmw.types')
local skp   = require('openmw.interfaces').SkillProgression

local Dt = require('scripts.Skill_Uses_Scaled.data')

-- SETTINGS -- They are all flat multipliers
-----------------------------------------------------------------------------------------------------------
local Magicka_to_XP = 9 -- This much magicka is equivalent to one vanilla spellcast.
-----------------------------------------------------------------------------------------------------------

-- TOOLS
local eps = 0.001
function equal(a,b)                         return (math.abs(b - a) < eps)                                  end
local function get_val(not_table_or_func)   return not_table_or_func                                        end
local function table_has_key(table, thing)
    if type(thing) == 'number' then  for k, v in pairs(table) do  if equal(v, thing) then return thing end  end
    else  for k, v in pairs(table) do  if v == thing then return thing end  end
    end
end

-- DEFINITIONS --
-----------------------------------------------------------------------------------------------------------

local Func = {}

-----------------------------------------------------------------------------------------------------------
Func.get_magic_modifier = function()
    local API_Spelltype_Ability = get_val(core.magic.SPELL_TYPE.Ability)
    local modifier = 0
    for _id, _params in pairs(types.Actor.activeSpells(self)) do
        if core.magic.spells[_params.id] then -- we only wanna check SPELL types, since abilities never come from enchantments
            for _, _effect in pairs(_params.effects) do
                if _effect.id      == 'fortifymaximummagicka' then modifier = modifier + _effect.magnitudeThisFrame / 10
                elseif _effect.id == 'fortifymagicka'        then modifier = modifier + _effect.magnitudeThisFrame / 100
                end
            end
        end
    end
    return modifier
end
Func.get_disintegrate_weapon = function()
    local API_Spelltype_Ability = get_val(core.magic.SPELL_TYPE.Ability)
    local modifier = 0
    for _id, _params in pairs(types.Actor.activeSpells(self)) do
        if core.magic.spells[_params.id] then -- we only wanna check SPELL types, since abilities never come from enchantments
            for _, _effect in pairs(_params.effects) do
                if _effect.id      == 'disintegrateweapon' then modifier = modifier + _effect.magnitudeThisFrame end
            end
        end
    end
    return modifier
end


Func.get_equipped_weapon = function() --Returns a table with three values: the object, it's id and it's current condition
    local weapon = {itemid = 'id Not Assigned', object = 'object Not Assigned', condition = 0}
    if Dt.STANCES[physical] == (Actor.getStance(self)) then
        for _, _object in ipairs(types.Actor.inventory(self):getAll(types.Weapon)) do
            if types.Actor.hasEquipped(self, _object) then
                weapon.itemid = types.Weapon.record(_object).id
                weapon.condition = types.Item.itemData(_object).condition
                weapon.object = _object
            end
        end
    end
    return weapon
end



Func.scale_skills = function()
    skp.addSkillUsedHandler(
        function(skillid, useType, options)
            -- Magic School Scaling
            if Dt.scaler_groups.SPELL[skillid] then
                local xp = options.skillGain
                local mp_factor = Func.get_magic_modifier()
                local spell_cost = types.Actor.getSelectedSpell(self).cost
                options.skillGain = xp * spell_cost/Magicka_to_XP * 4.8/(4 + mp_factor)
            end
            -- Weapon Scaling
            -- types.Actor.hasEquipped(self, types.Actor.inventory(self):getAll()[5])
            if Dt.scaler_groups.MELEE_WEAPON[skillid] then
                local xp = options.skillGain
                local condition_damage = math.max(Func.get_equipped_weapon().condition - Dt.pc_held_weapon.condition - Func.get_disintegrate_weapon(), 0)
                local skill = types.Player.stats.skills[skillid](self).base
                options.skillGain = xp * condition_damage/25 * 80/(40 + skill)
            end
        end
    )
end

-----------------------------------------------------------------------------------------------------------

-- RETURN || NEED THIS SO FILE DO THING
return Func