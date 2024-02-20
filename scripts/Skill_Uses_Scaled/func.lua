local core  = require('openmw.core')
local self  = require('openmw.self')
local types = require('openmw.types')
local async = require('openmw.async')

local Dt = require('scripts.Skill_Uses_Scaled.data')

-- SETTINGS -- They are all flat multipliers
-----------------------------------------------------------------------------------------------------------
local Magicka_to_XP          =  9 -- This much magicka is equivalent to one vanilla spellcast.

local MP_Refund_Skill_Offset = 15 -- This much magic skill is deducted on refund calculation.
                                  -- | The resulting skill value CAN BE NEGATIVE, and you'll get EXTRA COST instead of a refund.
local MP_Refund_Armor_Mult  = 0.5 -- This number times your Armor Weight is added to your Skill Offset.
local MP_Refund_Max_Percent = 50  -- Refund will never go above this Percentage of spell cost. I strongly advice you never set this above 100.
                                  -- | Due to how offsets work, this also affects penalties from heavy armor.

local Unarmored_Armor_Mult  = 0.5 -- This number times your Armor Weight is added to your Unarmored Skill when calculating XP.
                                  -- | Note that since skills level slower the higher they get, lighter / no armor will always result in better XP rates.
local Unarmored_Hits_To_XP  = 3   -- Unarmored XP is multiplied by this number divied by how many times you got hit by physical attacks in the last [Unarmored_Hit_Timer] seconds.
local Unarmored_Hit_Timer   = 60  -- How much time has to pass for a hit to no longer affect Unarmored XP, in seconds.
local Unarmored_Beast_Races = 6   -- Unarmored levels this times faster when you're an armor-clad Argonian/Khajiit. It's for your head and feetsies.
                                  -- | Only applies if you've got 3 or less empty slots (counting shield). Bonus is divided among those empty slots.
                                  -- | It's meant to make the heavy handicap from not being able to equip head and feet armor less bad, if you're running an armored character.
                                  -- | It's NOT meant to help, and will NOT affect, fully unarmored characters. Unarmored beast characters level the same as all others.

local Armor_Damage_To_XP  = 6  -- This much pre-mitigation physical damage is equivalent to one vanilla armor hit. Roughly.
local Block_Damage_To_XP  = 15 -- This much pre-mitigation physical damage is equivalent to one vanilla block hit. Roughly.

local Weapon_Damage_to_XP = 10 -- This much physical damage is equivalent to one vanilla weapon hit. Roughly.
local Weapon_Wear_Mult    = 2  -- Directly multiplies Vanilla durability loss. Only takes effect if you have enabled S_U_S_Weapon-XP-Precision.
                              -- | You'll always lose at least 1 durability per hit, even if you set this to 0.

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

local function makecounter(val)
    local count = val
    return function(mod)
        count = count + mod
        print(count)
        return count
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
    local armorTypeWeight = math.floor(Dt.ARMOR_TYPES[armorType])
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

Fn.get_active_effect_mag = function(effectid)
    local modifier = 0
    for _id, _params in pairs(types.Actor.activeSpells(self)) do
        if core.magic.spells[_params.id] then
            for _, _effect in pairs(_params.effects) do if _effect.id == effectid then modifier = modifier + _effect.magnitudeThisFrame end end
        end
        if core.magic.enchantments[_params.id] then
            for _, _effect in pairs(_params.effects) do if _effect.id == effectid then modifier = modifier + _effect.magnitudeThisFrame end end
        end
    end
    return modifier
end

Fn.has_effect = function(effect)
    local haseffect = false
    for _id, _params in pairs(types.Actor.activeSpells(self)) do
        if core.magic.spells[_params.id] then
            for _, _effect in pairs(_params.effects) do if _effect.id == effect then haseffect = true end end
        end
        if core.magic.enchantments[_params.id] then
            for _, _effect in pairs(_params.effects) do if _effect.id == effect then haseffect = true end end
        end
    end
    return haseffect
end

Fn.get_equipped_armor = function()
    local armor_list = {}
    for _, _object in pairs(types.Actor.getEquipment(self)) do
        if _object.type == types.Armor then table.insert(armor_list, _object) end
    end
    return armor_list
end

Fn.getters = {
    ARMOR = function(_object)
        if not _object then return end
        if _object.type == types.Armor then
            if not Dt.equipment then Dt.equipment = {} end
            table.insert(Dt.equipment, _object)
        end
    end,
    MELEE = function(_object)
        if not _object then return end
        if _object.type == types.Weapon and Dt.WEAPON_TYPES.MELEE[types.Weapon.record(_object).type]    then
            if not Dt.equipment then Dt.equipment = {} end
            Dt.equipment.itemid = types.Weapon.record(_object).id
            Dt.equipment.condition = types.Item.itemData(_object).condition
            Dt.equipment.object = _object
        end
    end,
    BOW = function(_object)
        if not _object then return end
        if _object.type == types.Weapon and Dt.WEAPON_TYPES.BOW[types.Weapon.record(_object).type]      then
            if not Dt.equipment then Dt.equipment = {} end
            Dt.equipment.itemid = types.Weapon.record(_object).id
            Dt.equipment.condition = types.Item.itemData(_object).condition
            Dt.equipment.object = _object
        end
    end,
    AMMO = function(_object)
        if not _object then return end
        if _object.type == types.Weapon and Dt.WEAPON_TYPES.AMMO[types.Weapon.record(_object).type]     then
            Dt.equipment = _object
        end
    end,
    THROWING = function(_object)
        if not _object then return end
        if _object.type == types.Weapon and Dt.WEAPON_TYPES.THROWING[types.Weapon.record(_object).type] then
            Dt.equipment = _object
        end
    end,
}

Fn.get_equipped = function(TYPEenum) --Returns a table with three values: the object, it's id and it's current condition
    Dt.equipment = nil
    local getter = Fn.getters[TYPEenum]
    if type(Dt.SLOTS[TYPEenum]) == 'table' then equipment_type = Dt.SLOTS[TYPEenum]
    else equipment_type = {Dt.SLOTS[TYPEenum]} end -- if not table, make table for ipairs
    for _, _slot in ipairs(equipment_type) do
        getter(types.Actor.getEquipment(self, _slot))
    end
    return Dt.equipment
end

Fn.get_weapon_data = function()
    local weapon = types.Actor.getEquipment(self, Dt.SLOTS.WEAPON)
    if not weapon then return
    elseif Dt.WEAPON_TYPES.MELEE[types.Weapon.record(weapon).type]    then
        Dt.pc_held_weapon_condition:set_prevframe(Fn.get_equipped('MELEE').condition)
    elseif Dt.WEAPON_TYPES.BOW[types.Weapon.record(weapon).type]      then
        Dt.pc_bow:set_prevframe(Fn.get_equipped('BOW'))
        if types.Actor.getEquipment(self, Dt.SLOTS.AMMO) then Dt.pc_ammo = Fn.get_equipped('AMMO') end
    elseif Dt.WEAPON_TYPES.THROWING[types.Weapon.record(weapon).type] then
        Dt.pc_thrown = Fn.get_equipped('THROWING')
    end
end

Fn.get_hit_armorpiece = function()
    for _, _obj in ipairs(Fn.get_equipped('ARMOR')) do
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
    local armor_types = get(Dt.ARMOR_TYPES) -- We copy this table. We could have copied ARMOR_RATING_WEIGHTS too, all that matters is that it includes all slots.
    local clean_slots = function(_slot) -- This is to guarantee we don't get ghost unarmored slots for gauntlets and bracers
        if     _slot == types.Armor.TYPE.LBracer or _slot == types.Armor.TYPE.LGauntlet then
            armor_types[types.Armor.TYPE.LBracer  ] = nil
            armor_types[types.Armor.TYPE.LGauntlet] = nil
        elseif _slot == types.Armor.TYPE.RBracer or _slot == types.Armor.TYPE.RGauntlet then
            armor_types[types.Armor.TYPE.RBracer  ] = nil
            armor_types[types.Armor.TYPE.RGauntlet] = nil
        else armor_types[_slot] = nil
        end
    end
    -- Add AR from all slots with armor
    for _, _obj in ipairs(Fn.get_equipped('ARMOR')) do
        skill  = types.Player.stats.skills[getArmorType(_obj)](self).modified
        local slot   = types.Armor.record(_obj).type
        local hp_mod = types.Item.itemData(_obj).condition / types.Armor.record(_obj).health
        rating = rating + types.Armor.record(_obj).baseArmor * hp_mod * Dt.ARMOR_RATING_WEIGHTS[slot] * skill / Dt.GMST.iBaseArmorSkill
        clean_slots(slot)
    end
    -- Add AR for slots that didn't have armor
    for _slot, _ in pairs(armor_types) do
        skill = types.Player.stats.skills.unarmored(self).modified
        rating = rating + skill * Dt.GMST.fUnarmoredBase1 * skill * Dt.GMST.fUnarmoredBase2 * Dt.ARMOR_RATING_WEIGHTS[_slot]-- Why have 2 GMSTs for 1 number? Precision? Yeah precision I guess.
        clean_slots(_slot)
    end
    rating = rating + Fn.get_magic_shield()
    return rating
end

Fn.get_unarmored_slots = function()
    local armor_types = get(Dt.ARMOR_TYPES) -- We copy this table. We could have copied ARMOR_RATING_WEIGHTS too, all that matters is that it includes all slots.
    local clean_slots = function(_slot) -- This is to guarantee we don't get ghost unarmored slots for gauntlets and bracers
        if     _slot == types.Armor.TYPE.LBracer or _slot == types.Armor.TYPE.LGauntlet then
            armor_types[types.Armor.TYPE.LBracer  ] = nil
            armor_types[types.Armor.TYPE.LGauntlet] = nil
        elseif _slot == types.Armor.TYPE.RBracer or _slot == types.Armor.TYPE.RGauntlet then
            armor_types[types.Armor.TYPE.RBracer  ] = nil
            armor_types[types.Armor.TYPE.RGauntlet] = nil
        else armor_types[_slot] = nil
        end
    end
    -- Remove all slots with armor from the list
    for _, _obj in ipairs(Fn.get_equipped('ARMOR')) do
        clean_slots(types.Armor.record(_obj).type)
    end
    local unarmored_slots = {}
    -- Add slots that didn't have armor to this new iterable, #ble table
    for _slot, _ in pairs(armor_types) do
        table.insert(unarmored_slots, _slot)
    end
    return unarmored_slots
end

Fn.recent_activations = function(source, simtime)
    if not Dt.recent_activations[source] then
        Dt.recent_activations[source] = {callback = source, counter = makecounter(0)}
        Dt.recent_activations[source].callback = async:registerTimerCallback(Dt.recent_activations[source].callback, Dt.recent_activations[source].counter)
    end
    async:newSimulationTimer(simtime, Dt.recent_activations[source].callback, -1)
    return Dt.recent_activations[source].counter(1)
end

Fn.make_scalers = function()

    -- ARMOR Scaling
-----------------------------------------------------------------------------------------------------------
    for _, _skillid in ipairs(Dt.scaler_groups.ARMOR) do
        Dt.scalers:new{
            name = _skillid,
            func = function(xp)
                -- NOTE: We disable scaling while under the effect of Disintegrate Armor, for you'd get ridiculous amounts of XP otherwise.
                -- For the sake of robustness and simplicity, it's a tradeoff I'm willing to accept. I will NOT attempt to fix it.
                if Fn.has_effect('disintegratearmor') then return xp end
                local armor_obj = Fn.get_hit_armorpiece()
                if not armor_obj then return xp end -- If we didn't find a hit piece, we skip scaling and leave XP vanilla. It's an edge case not worth pursuing.

                -- We estimate incoming damage from AR and condition lost instead of directly using condition lost.
                -- This helps avoid low ARs becoming a pit of neverleveling.
                local condition_lost = Dt.pc_equipped_armor_condition.prevframe[types.Armor.record(armor_obj).type] - types.Item.itemData(armor_obj).condition
                local rating = Fn.get_AR()
                local damage = (condition_lost * rating)/(rating - condition_lost)
                -- Armor skill and AR GMSTs are combined to make leveling below base AR faster, and above slower.
                local skill = types.Player.stats.skills[_skillid](self).base
                xp = xp * damage/Armor_Damage_To_XP * 2*Dt.GMST.iBaseArmorSkill / (Dt.GMST.iBaseArmorSkill + skill)

                print("SUS - Armor XP Mult: ".. printify(damage/Armor_Damage_To_XP * 2*Dt.GMST.iBaseArmorSkill / (Dt.GMST.iBaseArmorSkill + skill))..' | Damage Received: '.. printify(damage))

                return xp
            end
        }
    end

    -- BLOCK Scaling
-----------------------------------------------------------------------------------------------------------
    Dt.scalers:new{ name = 'block',
        func = function(xp)
            -- NOTE: We disable scaling while under the effect of Disintegrate Armor, for you'd get ridiculous amounts of XP otherwise.
            -- For the sake of robustness and simplicity, it's a tradeoff I'm willing to accept. I will NOT attempt to fix it.
            if Fn.has_effect('disintegratearmor') then return xp end
            local armor_obj = types.Actor.getEquipment(self, Dt.SLOTS.SHIELD)
            local current_shield_condition = 0 -- if armor_obj is nill, because the shield was broken and unequipped, then we count condition as 0.
            -- With armor the likelyhood of breaking is low, so we're better off just returning xp, but here we should air on the side of scaling the edge case rather than ignoring it.
            if armor_obj then current_shield_condition = types.Item.itemData(armor_obj).condition end
            local condition_lost = Dt.pc_equipped_armor_condition.prevframe[types.Armor.record(armor_obj).type] - current_shield_condition
            local damage = condition_lost
            -- Armor skill and AR GMSTs are combined to make leveling below base AR faster, and above slower.
            local skill = types.Player.stats.skills.block(self).base
            xp = xp * damage/Block_Damage_To_XP * (Dt.GMST.iBlockMaxChance+Dt.GMST.iBlockMinChance) / (2*Dt.GMST.iBlockMinChance + skill)

            print("SUS - Block XP: ".. printify(2.5 * damage/Block_Damage_To_XP * (Dt.GMST.iBlockMaxChance+Dt.GMST.iBlockMinChance) / (2*Dt.GMST.iBlockMinChance + skill))..' | Damage Received: '.. printify(damage))

            return xp
        end
    }

    -- UNARMORED Scaling
-----------------------------------------------------------------------------------------------------------
    Dt.scalers:new{ name = 'unarmored', 
        func = function(xp)

            -- Calculate factors:

            local dodge_factor  = 1 + 0.01 * (Fn.get_active_effect_mag('sanctuary') + 0.2*types.Player.stats.attributes.agility(self).modified + 0.1*types.Player.stats.attributes.luck(self).modified)
            local armor_weight = 0
            for _, _obj in ipairs(Fn.get_equipped('ARMOR')) do armor_weight = armor_weight + types.Armor.record(_obj).weight end
            local race         = get_val(types.Player.record(self).race)
            local beast_factor = 1 -- If you have more than 3 empty slots, this will stay a 1 and not affect your XP rates, even if you are Argonian/Khajiit
            if #Fn.get_unarmored_slots() <= 3 and (race == 'argonian' or race == 'khajiit') then beast_factor = Unarmored_Beast_Races / #Fn.get_unarmored_slots() end
            local gank_factor  = Unarmored_Hits_To_XP / Fn.recent_activations('unarmored', Unarmored_Hit_Timer)
            local skill        = types.Player.stats.skills['unarmored'](self).base
            local rating       = skill * Dt.GMST.fUnarmoredBase1 * skill * Dt.GMST.fUnarmoredBase2
            local skill_factor = 100 / (35 + rating + skill + armor_weight * Unarmored_Armor_Mult)

            -- Scale XP:

            local xp = xp * skill_factor * beast_factor * dodge_factor * gank_factor

            print("SUS - Unarmored XP Mult: ".. printify(skill_factor * beast_factor * dodge_factor * gank_factor))

            return xp
        end
    }

        -- SPELL Scaling
-----------------------------------------------------------------------------------------------------------
    for _, _skillid in ipairs(Dt.scaler_groups.SPELL) do
        Dt.scalers:new{ name = _skillid, 
            func = function(xp)

                -- Scale XP:

                local mp_factor = 0.01*Fn.get_active_effect_mag('fortifymagicka') + 0.1*Fn.get_active_effect_mag('fortifymaximummagicka')
                local spell_cost = types.Actor.getSelectedSpell(self).cost
                xp = xp * spell_cost/Magicka_to_XP * 4.8/(4 + mp_factor)

                -- MP Refund:
                                            -- Calculate factors
                local armor_weight = 0
                for _, _obj in ipairs(Fn.get_equipped('ARMOR')) do armor_weight = armor_weight + types.Armor.record(_obj).weight end
                local armor_offset = armor_weight * MP_Refund_Armor_Mult
                local cost_factor = Magicka_to_XP / (Magicka_to_XP + spell_cost/Magicka_to_XP)
                local skill = types.Player.stats.skills[_skillid](self).base
                local skill_factor = (skill - MP_Refund_Skill_Offset - armor_offset) / (40 + skill)

                                            -- Calculate refund
                local refund = spell_cost * cost_factor * skill_factor * 0.01*MP_Refund_Max_Percent

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
-----------------------------------------------------------------------------------------------------------
    for _, _skillid in ipairs(Dt.scaler_groups.MELEE_WEAPON) do
        Dt.scalers:new{ name = _skillid, 
            func = function(xp)
                
                local weapon = Fn.get_equipped('MELEE')
                -- NOTE: We disable scaling while under the effect of Disintegrate Weapon, for you'd get ridiculous amounts of XP otherwise.
                -- For the sake of robustness and simplicity, it's a tradeoff I'm willing to accept. I will NOT attempt to fix it.
                if     Fn.has_effect('disintegrateweapon') then return xp
                -- We also disable scaling if you're not holding a melee weapon when this is called.
                -- Will never happen under normal gameplay, but some mod in the future may use such a thing, so better safe than sorry
                elseif not weapon then return xp 
                end
                
                local condition_lost = Dt.pc_held_weapon_condition.prevframe - weapon.condition
                local damage = condition_lost/Dt.GMST.fWeaponDamageMult
                
                local wp_obj = weapon.object
                -- If you have the Weapon-XP-Precision addon, we add weapon.lua to your weapon.
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
                    local str_mod = types.Player.stats.attributes.strength(self).base * Dt.GMST.fDamageStrengthMult / 10 + Dt.GMST.fDamageStrengthBase
                    local function getMinDamage(val) return math.min(min_cond_dmg, val * str_mod) end
                    damage = ( getMinDamage(wp.chopMaxDamage  ) + getMinDamage(wp.chopMinDamage  )
                             + getMinDamage(wp.slashMaxDamage ) + getMinDamage(wp.slashMinDamage )
                             + getMinDamage(wp.thrustMaxDamage) + getMinDamage(wp.thrustMinDamage)
                             ) / 6
                end

                -- Scale XP:
                
                local skill = types.Player.stats.skills[_skillid](self).base
                --NOTE: due to durability being an integer, this will only change in steps of 10 damage (unless you have changed your Durability GMST).
                -- If you have the Weapon-XP-Precision addon, this increases in steps of 2.5 damage instead.
                xp = xp * damage/wp.speed/Weapon_Damage_to_XP * 80/(40 + math.min(skill, 100)) -- We use math.min here because hit rate can't go above 100, so we shouldn't scale past it.

                print("SUS - Melee XP Mult: ".. math.floor(100*damage/wp.speed/Weapon_Damage_to_XP * 80/(40 + math.min(skill, 100)))/100)

                return xp
            end
        }
    end
    -- MARKSMAN Scaling
-----------------------------------------------------------------------------------------------------------        Dt.scalers:new{ name = 'marksman', 
    Dt.scalers:new{ name = 'marksman', 
        func = function(xp)
            -- Mostly the same as MELEE, but we an abridged the alternate formula for throwables and different Dt values for bows & crossbows
            local bow    = Fn.get_equipped('BOW')
            local ammo   = Dt.pc_ammo
            local thrown = Dt.pc_thrown
            local wp     = nil -- This is to set scope only.
            local damage = nil -- This is to set scope only.
            
            -- Bow / Crossbow Scaler
            if bow then
                -- If we have a bow but don't remember the last used ammo for whatever reason, skip scaling.
                if not ammo then print('SUS - No Ammo in Dt.pc_ammo') return xp end
                -- If bow and disintegrate we skip. Note we DON'T skip throwables, only bows/crossbows.
                -- Throwables don't care about durability, nor disintegrate whatever.
                if Fn.has_effect('disintegrateweapon') then return xp end 
                
                local condition_lost = Dt.pc_bow.prevframe.condition - bow.condition
                damage = condition_lost/Dt.GMST.fWeaponDamageMult
                
                local wp_obj = bow.object
                wp = types.Weapon.record(wp_obj)
                -- If you have the Weapon-XP-Precision addon, we add weapon.lua to your weapon.
                if has_precision_addon then 
                    core.sendGlobalEvent('SUS_addScript', {script = 'weapon.lua',obj = wp_obj})
                    local codition_delta = - condition_lost * (Weapon_Wear_Mult/10/Dt.GMST.fWeaponDamageMult - 1)
                    wp_obj:sendEvent('modifyCondition', codition_delta)
                end
                -- Alternate fromula for low damage
                local min_cond_dmg = 2 / Dt.GMST.fWeaponDamageMult
                if damage < (min_cond_dmg - 0.001) then
                    local str_mod = types.Player.stats.attributes.strength(self).base * Dt.GMST.fDamageStrengthMult / 10 + Dt.GMST.fDamageStrengthBase
                    local function getMinDamage(val) return math.min(min_cond_dmg, val * str_mod) end
                    damage = (getMinDamage(wp.chopMaxDamage) + getMinDamage(wp.chopMinDamage)) / 6
                end
                
            -- Thrown Weapon Scaler
            elseif thrown then 
                wp = types.Weapon.record(thrown)
                local str_mod = types.Player.stats.attributes.strength(self).base * Dt.GMST.fDamageStrengthMult / 10 + Dt.GMST.fDamageStrengthBase
                barrage_factor = 0.5 + 2 / (Fn.recent_activations('thrown', 5) /wp.speed)
                print('Barrage Factor: '..printify(barrage_factor))
                damage = (wp.chopMaxDamage + wp.chopMinDamage) / 3 * barrage_factor * str_mod -- /3 instead of /6 cause throwns count twice.
            -- If we don't have a bow but somehow don't remember last throwable either, also skip.
            else print('SUS - No Ammo in Dt.pc_ammo') return xp
            -- If we got here, we have a valid weapon and damage number, and should apply scaling.
            end

            -- Scale XP:
            
            local skill = types.Player.stats.skills['marksman'](self).base
            --NOTE: due to durability being an integer, this will only change in steps of 10 damage (unless you have changed your Durability GMST).
            -- If you have the Weapon-XP-Precision addon, this increases in steps of 2.5 damage instead.
            xp = xp * damage/wp.speed/Weapon_Damage_to_XP * 80/(40 + math.min(skill, 100)) -- We use math.min here because hit rate can't go above 100, so we shouldn't scale past it.

            print("SUS - Marksman XP Mult: ".. math.floor(100*damage/wp.speed/Weapon_Damage_to_XP * 80/(40 + math.min(skill, 100)))/100)

            return xp
        end
    }
    print('Scalers constructed')

    -- Marksman Scaling
-----------------------------------------------------------------------------------------------------------
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
