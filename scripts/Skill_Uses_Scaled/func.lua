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

local Damage_To_XP  =  6          -- This much pre-mitigation physical damage is equivalent to one vanilla armor hit. Roughly.

-----------------------------------------------------------------------------------------------------------

-- TOOLS
local eps = 0.001
function equal(a,b)          return (math.abs(b - a) < eps)                                  end

local function printify(num) return math.floor(num*100)/100                                    end

local function get_val(not_table_or_func)   return not_table_or_func                                        end

local function get(var) -- var must be serializable, recursions WILL stack overflow :D
    if type(var)  ~= 'table' then return var
    else
        local deepcopy = {}
        for _key, _value in pairs(var) do deepcopy[_key] = get(_value) end
        return deepcopy
    end
end

local function table_has_key(table, thing)
    if type(thing) == 'number' then  for k, v in pairs(table) do  if equal(v, thing) then return thing end  end
    else  for k, v in pairs(table) do  if v == thing then return thing end  end
    end
end

-- Credit to zackhasacat for this one
-- I shortened it by removing checks I don't need (due to where it's used)
-- Also made it use and return SUS Dt values
function getArmorType(armor_obj)
    local lightMultiplier = Dt.GMST.fLightMaxMod + 0.0005
    local medMultiplier   = Dt.GMST.fMedMaxMod   + 0.0005
    local armorType       = types.Armor.record(armor_obj).type
    local weight          = types.Armor.record(armor_obj).weight
    local armorTypeWeight = math.floor(Dt.ARMOR_SLOTS[armorType])
    if     weight <= armorTypeWeight * lightMultiplier then -- print("SKILL: lightarmor")
        return 'lightarmor'
    elseif weight <= armorTypeWeight * medMultiplier   then -- print("SKILL: mediumarmor")
        return 'mediumarmor'
    else                                                    -- print("SKILL: heavyarmor")
        return 'heavyarmor'
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
                if _effect.id     == 'fortifymaximummagicka' then modifier = modifier + _effect.magnitudeThisFrame / 10
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

Fn.has_effect = function(effect)
    local haseffect = false
    for _id, _params in pairs(types.Actor.activeSpells(self)) do
        if core.magic.spells[_params.id] then
            for _, _effect in pairs(_params.effects) do
                if _effect.id == effect then haseffect = true end
            end
        end
        if core.magic.enchantments[_params.id] then
            for _, _effect in pairs(_params.effects) do
                if _effect.id == effect then haseffect = true end
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

Fn.get_hit_armorpiece = function()
    for _, _obj in ipairs(Fn.get_equipped_armor()) do
        local slot = types.Armor.record(_obj).type
        if not equal(Dt.pc_equipped_armor_condition.prevframe[slot], types.Item.itemData(_obj).condition) then return _obj end
    end
end

Fn.get_magic_shield = function()
    local API_Spelltype_Ability = get_val(core.magic.SPELL_TYPE.Ability)
    local modifier = 0
    for _id, _params in pairs(types.Actor.activeSpells(self)) do
        if core.magic.spells[_params.id] then -- we only wanna check SPELL types, since abilities never come from enchantments
            for _, _effect in pairs(_params.effects) do
                if _effect.id     == 'shield' then modifier = modifier + _effect.magnitudeThisFrame end
            end
        end
    end
    return modifier
end

Fn.get_AR = function()
    local skill       = 0
    local rating      = 0
    local armor_slots = get(Dt.ARMOR_SLOTS) -- We copy this table. We could have copied ARMOR_RATING_WEIGHTS too, all that matters is that it includes all slots.
    local clean_slots = function(_slot) -- This is to guarantee we don't get ghost unarmored slots for gauntlets and bracers
        if     _slot == types.Armor.TYPE.LBracer or _slot == types.Armor.TYPE.LGauntlet then
            armor_slots[types.Armor.TYPE.LBracer  ] = nil
            armor_slots[types.Armor.TYPE.LGauntlet] = nil
        elseif _slot == types.Armor.TYPE.RBracer or _slot == types.Armor.TYPE.RGauntlet then
            armor_slots[types.Armor.TYPE.RBracer  ] = nil
            armor_slots[types.Armor.TYPE.RGauntlet] = nil
        else armor_slots[_slot] = nil
        end
    end
    -- Add AR from all slots with armor
    for _, _obj in ipairs(Fn.get_equipped_armor()) do
        skill  = types.Player.stats.skills[getArmorType(_obj)](self).modified
        local slot   = types.Armor.record(_obj).type
        local hp_mod = types.Item.itemData(_obj).condition / types.Armor.record(_obj).health
        rating = rating + types.Armor.record(_obj).baseArmor * hp_mod * Dt.ARMOR_RATING_WEIGHTS[slot] * skill / Dt.GMST.iBaseArmorSkill
        clean_slots(slot)
    end
    -- Add AR for slots that didn't have armor
    for _slot, _ in pairs(armor_slots) do
        skill = types.Player.stats.skills.unarmored(self).modified
        rating = rating + skill * Dt.GMST.fUnarmoredBase1 * skill * Dt.GMST.fUnarmoredBase2 * Dt.ARMOR_RATING_WEIGHTS[slot]-- Why have 2 GMSTs for 1 number? Precision? Yeah precision I guess.
        clean_slots(slot)
    end
    rating = rating + Fn.get_magic_shield()
    return rating
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
    -- ARMOR Scaling
    for _, _skillid in ipairs(Dt.scaler_groups.ARMOR) do
        Dt.scalers:new{
            name = _skillid,
            func = function(xp)
                -- NOTE: We disable scaling while under the effect of Disintegrate Armor, for you'd get ridiculous amounts of XP otherwise.
                -- For the sake of robustness and simplicity, it's a tradeoff I'm willing to accept. I will NOT attempt to fix it.
                if Fn.has_effect('disintegratearmor') then return xp end

                local armor_obj = Fn.get_hit_armorpiece()
                -- We estimate incoming damage from AR and condition lost instead of directly using condition lost.
                -- This helps avoid low ARs becoming a pit of neverleveling.
                local condition_lost = Dt.pc_equipped_armor_condition.prevframe[types.Armor.record(armor_obj).type] - types.Item.itemData(armor_obj).condition
                local rating = Fn.get_AR()
                local damage = (condition_lost * rating)/(rating - condition_lost)
                -- Armor skill and AR GMSTs are combined to make leveling below base AR faster, and above slower.
                local skill = types.Player.stats.skills[_skillid](self).base
                xp = xp * damage/Damage_To_XP * 2*Dt.GMST.iBaseArmorSkill / (Dt.GMST.iBaseArmorSkill + skill)

                print("SUS - Armor XP Mult: ".. printify(damage/Damage_To_XP * 2*Dt.GMST.iBaseArmorSkill / (Dt.GMST.iBaseArmorSkill + skill))..' | Damage Received: '.. printify(damage))

                return xp
            end
        }
    end
    -- SPELL Scaling
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
                for _, _obj in ipairs(Fn.get_equipped_armor()) do armor_weight = armor_weight + types.Armor.record(_obj).weight end
                local armor_offset = armor_weight * MP_Refund_Armor_Mult
                local cost_factor = Magicka_to_XP / (Magicka_to_XP + spell_cost/Magicka_to_XP)
                local skill = types.Player.stats.skills[_skillid](self).base
                local skill_factor = (skill - MP_Refund_Skill_Offset - armor_offset) / (40 + skill)

                                            -- Calculate refund
                local refund = spell_cost * cost_factor * skill_factor * MP_Refund_Max_Percent /100

                                            -- Apply refund
                --Yes, this will apply even if current > max.
                --To keep vanilla compatibility, we have to consider current>max as a valid gameplay state, since Fortify Magicka doesn't increase Max MP.
                types.Player.stats.dynamic.magicka(self).current = types.Player.stats.dynamic.magicka(self).current + refund

                print("SUS - Refund: ".. math.floor(refund/spell_cost*100)..'% | '.. math.floor(refund*100)/100 ..' MP')

                return xp
            end
        }
    end
    -- MELEE Scaling
    for _, _skillid in ipairs(Dt.scaler_groups.MELEE_WEAPON) do
        Dt.scalers:new{ 
            name = _skillid, 
            func = function(xp)

                -- NOTE: We disable scaling while under the effect of Disintegrate Weapon, for you'd get ridiculous amounts of XP otherwise.
                -- For the sake of robustness and simplicity, it's a tradeoff I'm willing to accept. I will NOT attempt to fix it.
                if Fn.has_effect('disintegrateweapon') then return xp end
                local condition_lost = Dt.pc_held_weapon_condition.prevframe - Fn.get_equipped_weapon().condition
                local damage = condition_lost/Dt.GMST.fWeaponDamageMult

                -- If you have the Weapon-XP-Precision addon, we add weapon.lua to your weapon.
                local wp_obj = Fn.get_equipped_weapon().object
                if has_precision_addon then 
                    core.sendGlobalEvent('SUS_addScript', {script = 'weapon.lua',obj = wp_obj})
                -- From there we reduce/increase condition lost by the difference between the actual amount lost and what you would have lost with Vanilla * Weapon_Wear_Mult
                -- This MAGICALLY turns your GMST loss into the advertised 2X vanilla loss (or whatever Weapon_Wear_Mult is set to). WHY WAS IT SO HARD TO GET THIS FORMULA RIGHT. !!AAAAAA.
                    local codition_delta = - condition_lost * (Weapon_Wear_Mult/10/Dt.GMST.fWeaponDamageMult - 1)
                    wp_obj:sendEvent('modifyCondition', codition_delta)
                end

                -- NOTE: due to durability being an integer, you only lose more than 1 when dealing over 20 damage (unless you have changed your Durability GMST).
                -- To deal with this, we use a different formula when your weapon deals under 20 damage.
                -- If you have the Weapon-XP-Precision addon, this only gets used under 5 damage instead.
                local wp = types.Weapon.record(wp_obj)
                local min_cond_dmg = 2 / Dt.GMST.fWeaponDamageMult
                if damage < (min_cond_dmg - 0.001) then
                    local wp = types.Weapon.record(wp_obj)
                    local str_mod = types.Player.stats.attributes.strength(self).base * Dt.GMST.fDamageStrengthMult / 10 + Dt.GMST.fDamageStrengthBase
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
                xp = xp * damage/wp.speed/Melee_Damage_to_XP * 80/(40 + math.min(skill, 100)) -- We use math.min here because hit rate can't go above 100, so we shouldn't scale past it.

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
