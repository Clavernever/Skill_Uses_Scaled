local core  = require('openmw.core')
local self  = require('openmw.self')
local types = require('openmw.types')

local Dt = require('scripts.Skill_Uses_Scaled.data')

-- SETTINGS -- They are all flat multipliers
-----------------------------------------------------------------------------------------------------------
local Magicka_to_XP = 9 -- This much magicka is equivalent to one vanilla spellcast.
local Melee_Damage_to_XP = 10 -- This much physical damage is equivalent to one vanilla weapon hit. Roughly.
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

local Fn = {}

-----------------------------------------------------------------------------------------------------------
Fn.get_magic_modifier = function()
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
Fn.has_disintegrate_weapon = function()
    local API_Spelltype_Ability = get_val(core.magic.SPELL_TYPE.Ability)
    local haseffect = false
    for _id, _params in pairs(types.Actor.activeSpells(self)) do
        if core.magic.spells[_params.id] then -- we only wanna check SPELL types, since abilities never come from enchantments
            for _, _effect in pairs(_params.effects) do
--                 if _effect.id      == 'disintegrateweapon' then modifier = modifier + _effect.magnitudeThisFrame end
                if _effect.id      == 'disintegrateweapon' then haseffect = true end
            end
        end
    end
    return haseffect
end

Fn.get_equipped_weapon = function() --Returns a table with three values: the object, it's id and it's current condition
    local weapon = {itemid = 'id Not Assigned', object = 'object Not Assigned', condition = 0}
    for _, _object in ipairs(types.Actor.inventory(self):getAll(types.Weapon)) do
        if types.Actor.hasEquipped(self, _object) then
            weapon.itemid = types.Weapon.record(_object).id
            weapon.condition = types.Item.itemData(_object).condition
            weapon.object = _object
        end
    end
    return weapon
end

-- Fn.get_marksman_weapon = function() --Returns a table with three values: the object, it's id and it's current condition
--     local weapon = {itemid = 'id Not Assigned', object = 'object Not Assigned', condition = 0}
--     for _, _object in ipairs(types.Actor.inventory(self):getAll(types.Weapon)) do
--         if types.Actor.hasEquipped(self, _object) then
--             if (types.Weapon.record(_object).type == types.Weapon.TYPE.Arrow) or (types.Weapon.record(_object).type == types.Weapon.TYPE.Bolt) then
--                 Dt.pc_marksman_projectile.itemid = types.Weapon.record(_object).id
--                 Dt.pc_marksman_projectile.object = _object
--             elseif (types.Weapon.record(_object).type == types.Weapon.TYPE.MarksmanCrossbow) or (types.Weapon.record(_object).type == types.Weapon.TYPE.MarksmanBow) then
--                 weapon.itemid = types.Weapon.record(_object).id
--                 weapon.condition = types.Item.itemData(_object).condition
--                 weapon.object = _object
--             elseif types.Weapon.record(_object).type == types.Weapon.TYPE.MarksmanThrown then
--             end
--         end
--     end
--     return weapon
-- end


Fn.make_scalers = function()
    -- Magic School Scaling
    for _, _skillid in ipairs(Dt.scaler_groups.SPELL) do
        Dt.scalers:new{ 
            name = _skillid, 
            func = function(xp)
                local mp_factor = Fn.get_magic_modifier()
                local spell_cost = types.Actor.getSelectedSpell(self).cost
                xp = xp * spell_cost/Magicka_to_XP * 4.8/(4 + mp_factor)
                return xp
            end
        }
    end
    -- Melee Weapon Scaling
    for _, _skillid in ipairs(Dt.scaler_groups.MELEE_WEAPON) do
        Dt.scalers:new{ 
            name = _skillid, 
            func = function(xp)
                -- NOTE: We disable scaling while under the effect of Disintegrate Weapon, for you'd get ridiculous amounts of XP otherwise.
                -- For the sake of robustness and simplicity, it's a tradeoff I'm willing to accept. I will NOT attempt to fix it.
                if Fn.get_disintegrate_weapon then return xp end
                local wp_obj = Fn.get_equipped_weapon().object
                local condition_mult = core.getGMST('fWeaponDamageMult')
                local condition_lost = Dt.pc_held_weapon.prevframe.condition - Fn.get_equipped_weapon().condition
                local damage = condition_lost/condition_mult
                -- NOTE: due to durability being an integer, you only lose more than 1 when dealing over 20 damage (unless you have changed your Durability GMST).
                -- To deal with this, we use a different formula when your weapon deals under 20 damage.
                -- If you have the Weapon-XP-Precision addon, this only gets used under 5 damage instead.
                local min_cond_dmg = 2 / condition_mult
                local wp = types.Weapon.record(wp_obj)
                -- If you have the Weapon-XP-Precision addon, we add weapon.lua to your weapon.
                if has_precision_addon then 
                    core.sendGlobalEvent('SUS_addScript', {script = 'weapon.lua',obj = wp_obj})
                -- From there we restore half the condition lost, turning GMST 4X loss into the advertised 2X loss.
                    wp_obj:sendEvent('restoreCondition', condition_lost * 0.5)
                end
                if damage < (min_cond_dmg - 0.001) then
                    local wp = types.Weapon.record(wp_obj)
                    local str_mod = types.Player.stats.attributes.strength(self).base * core.getGMST('fDamageStrengthMult') / 10 + core.getGMST('fDamageStrengthBase')
                    local function getMinDamage(val) return math.min(min_cond_dmg, val * str_mod) end
                    damage = ( getMinDamage(wp.chopMaxDamage  ) + getMinDamage(wp.chopMinDamage  )
                             + getMinDamage(wp.slashMaxDamage ) + getMinDamage(wp.slashMinDamage )
                             + getMinDamage(wp.thrustMaxDamage) + getMinDamage(wp.thrustMinDamage)
                             ) / 6
                end
                local skill = types.Player.stats.skills[_skillid](self).base
                --NOTE: due to durability being an integer, this will only change in steps of 10 damage (unless you have changed your Durability GMST).
                -- If you have the Weapon-XP-Precision addon, this increases in steps of 2.5 damage instead.
                xp = xp * damage/wp.speed/Melee_Damage_to_XP * 80/(40 + skill)
                print(damage)
                print(damage/wp.speed/Melee_Damage_to_XP)
                return xp
            end
        }
    end
    print('Scalers constructed')
    -- Marksman Scaling
--     Dt.scalers:new{
--         name = 'marksman',
--         func = function(xp)
--             if 
--             return xp
--         end
--     }
end

-----------------------------------------------------------------------------------------------------------

-- RETURN || NEED THIS SO FILE DO THING
return Fn
