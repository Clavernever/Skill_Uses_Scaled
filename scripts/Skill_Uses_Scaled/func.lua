local core  = require('openmw.core')
local self  = require('openmw.self')
local types = require('openmw.types')

local Dt = require('scripts.Skill_Uses_Scaled.data')

-- SETTINGS -- They are all flat multipliers
-----------------------------------------------------------------------------------------------------------
local Magicka_to_XP          =  9 -- This much magicka is equivalent to one vanilla spellcast.

local MP_Refund_Skill_Offset = 15 -- This much magic skill is deducted on refund calculation.
                                  -- | The resulting skill value CAN BE NEGATIVE, and you'll get EXTRA COST instead of a refund.
local MP_Refund_Armor_Mult  = 0.5 -- This number times your Armor Weight is added to your Skill Offset.
local MP_Refund_Max_Percent  = 50 -- Refund will never go above this Percentage of spell cost. I strongly advice you never set this above 100.
                                  -- | Due to how offsets work, this also affects penalties from heavy armor.

local Melee_Damage_to_XP     = 10 -- This much physical damage is equivalent to one vanilla weapon hit. Roughly.
local Weapon_Wear_Mult       =  2 -- Directly multiplies Vanilla durability loss. Only takes effect if you have enabled S_U_S_Weapon-XP-Precision.
                                  -- | You'll always lose at least 1 durability per hit, even if you set this to 0.
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

Fn.get_equipped_armor = function()
    local armor_list = {}
    for _, _object in pairs(types.Actor.getEquipment(self)) do
        if _object.type == types.Armor then table.insert(armor_list, _object) end
    end
    return armor_list
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
                -- XP Scaling:
                local mp_factor = Fn.get_magic_modifier()
                local spell_cost = types.Actor.getSelectedSpell(self).cost
                xp = xp * spell_cost/Magicka_to_XP * 4.8/(4 + mp_factor)

                -- MP Refund:
                                            -- Calculate factors
                local armor_weight = 0
                for _, _object in ipairs(Fn.get_equipped_armor()) do 
                    armor_weight = armor_weight + types.Armor.record(_object).weight
                end
                local armor_offset = armor_weight * MP_Refund_Armor_Mult
                print('armor_weight: '.. math.floor(armor_weight*100)/100 .. ' | armor_offset: '.. math.floor(armor_offset*100)/100 )
                local skill = types.Player.stats.skills[_skillid](self).base
                local cost_factor = Magicka_to_XP / (Magicka_to_XP + spell_cost/Magicka_to_XP)
                local skill_factor = (skill - MP_Refund_Skill_Offset - armor_offset) / (40 + skill)
                print('cost_factor: '.. math.floor(cost_factor*100)/100 .. ' | skill_factor: '.. math.floor(skill_factor*100)/100 )
                                            -- Calculate refund
                local refund = spell_cost * cost_factor * skill_factor * MP_Refund_Max_Percent /100
                print("SUS - Refund: ".. math.floor(refund/spell_cost*100)..'% | '.. math.floor(refund*100)/100 ..' MP')
                                            -- Apply refund
                --Yes, this will apply even if current > max.
                --To keep vanilla compatibility, we have to consider current>max as a valid gameplay state, since Fortify Magicka doesn't increase Max MP.
                types.Player.stats.dynamic.magicka(self).current = types.Player.stats.dynamic.magicka(self).current + refund

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
                local condition_mult = core.getGMST('fWeaponDamageMult')
                local condition_lost = Dt.pc_held_weapon.prevframe.condition - Fn.get_equipped_weapon().condition
                local damage = condition_lost/condition_mult

                -- If you have the Weapon-XP-Precision addon, we add weapon.lua to your weapon.
                local wp_obj = Fn.get_equipped_weapon().object
                if has_precision_addon then 
                    core.sendGlobalEvent('SUS_addScript', {script = 'weapon.lua',obj = wp_obj})
                -- From there we reduce/increase condition lost by the difference between the actual amount lost and what you would have lost with Vanilla * Weapon_Wear_Mult
                -- This MAGICALLY turns your GMST loss into the advertised 2X vanilla loss (or whatever Weapon_Wear_Mult is set to). WHY WAS IT SO HARD TO GET THIS FORMULA RIGHT. !!AAAAAA.
                    local codition_delta = - condition_lost * (Weapon_Wear_Mult/10/condition_mult - 1)
                    wp_obj:sendEvent('modifyCondition', codition_delta)
                end

                -- NOTE: due to durability being an integer, you only lose more than 1 when dealing over 20 damage (unless you have changed your Durability GMST).
                -- To deal with this, we use a different formula when your weapon deals under 20 damage.
                -- If you have the Weapon-XP-Precision addon, this only gets used under 5 damage instead.
                local wp = types.Weapon.record(wp_obj)
                local min_cond_dmg = 2 / condition_mult
                if damage < (min_cond_dmg - 0.001) then
                    local wp = types.Weapon.record(wp_obj)
                    local str_mod = types.Player.stats.attributes.strength(self).base * core.getGMST('fDamageStrengthMult') / 10 + core.getGMST('fDamageStrengthBase')
                    local function getMinDamage(val) return math.min(min_cond_dmg, val * str_mod) end
                    damage = ( getMinDamage(wp.chopMaxDamage  ) + getMinDamage(wp.chopMinDamage  )
                             + getMinDamage(wp.slashMaxDamage ) + getMinDamage(wp.slashMinDamage )
                             + getMinDamage(wp.thrustMaxDamage) + getMinDamage(wp.thrustMinDamage)
                             ) / 6
                end

                -- Now we finally do the actual scaling
                local skill = types.Player.stats.skills[_skillid](self).base
                --NOTE: due to durability being an integer, this will only change in steps of 10 damage (unless you have changed your Durability GMST).
                -- If you have the Weapon-XP-Precision addon, this increases in steps of 2.5 damage instead.
                xp = xp * damage/wp.speed/Melee_Damage_to_XP * 80/40 + math.min(skill, 100) -- We use math.min here because hit rate can't go above 100, so we shouldn't scale past it.

                -- For playtesting
                print("SUS - Weapon XP Multiplier: x".. math.floor(100*damage/wp.speed/Melee_Damage_to_XP * 80/(40 + math.min(skill, 100)))/100)

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
