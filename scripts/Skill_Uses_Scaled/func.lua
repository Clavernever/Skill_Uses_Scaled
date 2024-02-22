local core  = require('openmw.core')
local self  = require('openmw.self')
local types = require('openmw.types')
local async = require('openmw.async')
local time  = require('openmw_aux.time')
local i_UI  = require('openmw.interfaces').UI
local input = require('openmw.input')

local Dt = require('scripts.Skill_Uses_Scaled.data')

-- SETTINGS -- They are all flat multipliers
-----------------------------------------------------------------------------------------------------------
local Magicka_to_XP          =  9 -- [This] much magicka is equivalent to one vanilla spellcast.

local MP_Refund_Skill_Offset = 15 -- [This] much magic skill is deducted on refund calculation.
                                  -- | The resulting skill value CAN BE NEGATIVE, and you'll get EXTRA COST instead of a refund.
local MP_Refund_Armor_Mult  = 0.5 -- [This] number times your Armor Weight is added to your Skill Offset.
local MP_Refund_Max_Percent = 50  -- Refund will never go above [this] Percentage of spell cost. I strongly advice you never set [this] above [100].
                                  -- | Due to how offsets work, this also affects penalties from heavy armor.

local Unarmored_Armor_Mult  = 0.5 -- [This] number times your Armor Weight is added to your Unarmored Skill when calculating XP.
                                  -- | Note that since skills level slower the higher they get, lighter / no armor will always result in better XP rates.
local Unarmored_Hits_To_XP  = 3   -- Unarmored XP is multiplied by [this]/[hits] from enemy PHYSICAL attacks in the last [Unarmored_Hit_Timer] seconds.
local Unarmored_Hit_Timer   = 60  -- [This] many seconds have to pass for a hit taken to stop reducing Unarmored XP gained from following hits.
local Unarmored_Beast_Races = 6   -- Unarmored levels [this] times faster when you're an armor-clad Argonian/Khajiit. It's for your head and feetsies.
                                  -- | Only applies if you've got 3 or less empty slots (counting shield). Bonus is divided among those empty slots.
                                  -- | It's meant to make the heavy handicap from not being able to equip head and feet armor less bad, if you're running an armored character.
                                  -- | It's NOT meant to help, and will NOT affect, fully unarmored characters. Unarmored beast characters level the same as all others.

local Armor_Damage_To_XP  = 6  -- [This] much pre-mitigation physical damage is equivalent to one vanilla armor hit. Roughly.
local Block_Damage_To_XP  = 15 -- [This] much pre-mitigation physical damage is equivalent to one vanilla block hit. Roughly.

local Weapon_Wear_Mult      = 2  -- Directly multiplies Vanilla durability loss. Only takes effect if you have enabled S_U_S_Weapon-XP-Precision.
                                 -- | You'll always lose at least 1 durability per hit, even if you set [this] to 0.
local Physical_Damage_to_XP = 15 -- [This] much physical damage is equivalent to one vanilla hit. Roughly.
                                 -- | All Melee and Ranged weapons, as well as Hand to Hand, use this setting.
local HandToHand_Strength = 1/40 -- Hand to Hand xp per hit is multiplied by STR * [this]. Set [this] to 1 if you want to disable it.
                                 -- The default 1/40 means at 40 STR you deal vanilla damage, at 80 2x as much, at 100 2.5x etc
                                 -- The default is what OpenMW's "Factor strength into hand-to-hand combat" setting uses.
local H2H_STR_Werewolves = false -- If this is true, HandToHand_Strength will affect your xp as a werewolf.

-----------------------------------------------------------------------------------------------------------

-- TOOLS
local eps = 0.001
function equal(a,b)          return (math.abs(b - a) < eps)                                  end

local function printify(num) return math.floor(num*100 + 0.5)/100 end
local function percentify(num)
    stringnum = 'nopercent?'
    if      num >= 10  then stringnum = tostring(math.floor(num*100 + 0.5)..'%')
    elseif  num >= -1  then stringnum = tostring(math.floor(num*10000 + 0.5)/100 ..'%') 
    else                    stringnum = tostring(math.floor(num*100 + 0.5)..'%') end
    return stringnum
end

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
    local simseconds = function() return core.getSimulationTime() - (core.getSimulationTime() % 0.01 * time.second) end
    local start = simseconds() -- for debugging
    return function(mod)
        count = count + mod
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
    if     weight <= armorTypeWeight * lightMultiplier then -- print('SKILL: lightarmor')
        return 'lightarmor'
    elseif weight <= armorTypeWeight * medMultiplier   then -- print('SKILL: mediumarmor')
        return 'mediumarmor'
    else                                                    -- print('SKILL: heavyarmor')
        return 'heavyarmor'
    end
end

-- DEFINITIONS --
-----------------------------------------------------------------------------------------------------------

local Fn = {}

-----------------------------------------------------------------------------------------------------------
Fn.register_Use_Action_Handler = function()
    local useCallback = async:callback(function()
            if input.getBooleanActionValue("Use") then
                -- If in a menu or not in weapon stance, we're not attacking so we go back
                if i_UI.getMode() or not Dt.STANCE_WEAPON[types.Actor.getStance(self)] then return end
                local weapon = types.Actor.getEquipment(self, Dt.SLOTS.WEAPON)
                if not (weapon.type == types.Weapon) then return end
                if not weapon then
                    Dt.attackspeed:update()                                          -- Fn.recent_activations(1, 'h2h', 3.1)
                    -- We request global.lua to request core.lua to update data.lua with the current WerewolfClawMult.
                    -- We do it here cause it needs 2 frames to resolve due to event delay, and this handler happens ~10 frames before the hit registers and calls the skill handler.
                    -- Even if the skill handler got called by another mod completely outside this timeframe, the worst that could happen is that it uses an outdated WerewolfClawMult.
                    if types.NPC.isWerewolf(self) then core.sendGlobalEvent('SUS_updateGLOBvar', {source = self.obj, id = 'WerewolfClawMult'}) end
                elseif Dt.WEAPON_TYPES.MELEE[types.Weapon.record(weapon).type]    then
                    Dt.pc_held_weapon_condition = Fn.get_equipped('MELEE').condition --:set_prevframe(Fn.get_equipped('MELEE').condition)
                    Dt.attackspeed:update()
                elseif Dt.WEAPON_TYPES.BOW[types.Weapon.record(weapon).type]      then
                    Dt.pc_bow                   = Fn.get_equipped('BOW')             --:set_prevframe(Fn.get_equipped('BOW'))
                    if types.Actor.getEquipment(self, Dt.SLOTS.AMMO) then Dt.pc_ammo = Fn.get_equipped('AMMO') end
                    Dt.attackspeed:update()
                elseif Dt.WEAPON_TYPES.THROWING[types.Weapon.record(weapon).type] then
                    Dt.pc_thrown                = Fn.get_equipped('THROWING').object
                    Dt.attackspeed:update()                                          -- Fn.recent_activations(1, 'thrown', 3.1)
                end
            end
        end)
    input.registerActionHandler("Use", useCallback)
end

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
            if not Dt.equipment then Dt.equipment = {} end
            Dt.equipment.object = _object
            Dt.equipment.count  = _object.count
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

Fn.clean_slots = function(_slot) -- This is to guarantee we don't get ghost unarmored slots for gauntlets and bracers
    if     _slot == types.Armor.TYPE.LBracer or _slot == types.Armor.TYPE.LGauntlet then
        armor_types[types.Armor.TYPE.LBracer  ] = nil
        armor_types[types.Armor.TYPE.LGauntlet] = nil
    elseif _slot == types.Armor.TYPE.RBracer or _slot == types.Armor.TYPE.RGauntlet then
        armor_types[types.Armor.TYPE.RBracer  ] = nil
        armor_types[types.Armor.TYPE.RGauntlet] = nil
    else armor_types[_slot] = nil
    end
end

Fn.get_AR = function()
    local skill       = 0
    local rating      = 0
    local armor_types = get(Dt.ARMOR_TYPES) -- We copy this table. We could have copied ARMOR_RATING_WEIGHTS too, all that matters is that it includes all slots.
    -- Add AR from all slots with armor. OnLY iF we hAvE ArMOr!!
    local armor = Fn.get_equipped('ARMOR')
    if armor then
        for _, _obj in ipairs(armor) do
            skill  = types.Player.stats.skills[getArmorType(_obj)](self).modified
            local slot   = types.Armor.record(_obj).type
            local hp_mod = types.Item.itemData(_obj).condition / types.Armor.record(_obj).health
            rating = rating + types.Armor.record(_obj).baseArmor * hp_mod * Dt.ARMOR_RATING_WEIGHTS[slot] * skill / Dt.GMST.iBaseArmorSkill
            Fn.clean_slots(slot)
        end
    end
    -- Add AR for slots that didn't have armor
    for _slot, _ in pairs(armor_types) do
        skill = types.Player.stats.skills.unarmored(self).modified
        rating = rating + skill * Dt.GMST.fUnarmoredBase1 * skill * Dt.GMST.fUnarmoredBase2 * Dt.ARMOR_RATING_WEIGHTS[_slot]-- Why have 2 GMSTs for 1 number? Precision? Yeah precision I guess.
        Fn.clean_slots(_slot)
    end
    rating = rating + Fn.get_magic_shield()
    return rating
end

Fn.get_unarmored_slots = function()
    local armor_types = get(Dt.ARMOR_TYPES) -- We copy this table. We could have copied ARMOR_RATING_WEIGHTS too, all that matters is that it includes all slots.
    -- Remove all slots with armor from the list. OnLY iF we hAvE ArMOr!!
    local armor = Fn.get_equipped('ARMOR')
    if armor then for _, _obj in ipairs(armor) do Fn.clean_slots(types.Armor.record(_obj).type) end end
    local unarmored_slots = {}
    -- Add slots that didn't have armor to this new iterable, #ble table
    for _slot, _ in pairs(armor_types) do table.insert(unarmored_slots, _slot) end
    return unarmored_slots
end

-- Fn.recent_activations = function(amount, source, simtime) -- unused
--     if not Dt.recent_activations[source] then
--         Dt.recent_activations[source] = {callback = source, counter = makecounter(0)}
--         Dt.recent_activations[source].callback = async:registerTimerCallback(Dt.recent_activations[source].callback, Dt.recent_activations[source].counter)
--     end
--     async:newSimulationTimer(simtime, Dt.recent_activations[source].callback, -amount)
--     return Dt.recent_activations[source].counter(amount)
-- end

Fn.estimate_base_damage = function(t) --{full = 0, spam = 0, speed = 0, min = 0, max = 0}
    if t.speed < t.full/5 then t.speed = (t.full + t.spam) / 1.66 end -- If 1st attack, then we set speed to a little less than average, since you're very likely to have fully drawn it.
    local draw = math.min(1, math.max(0, (t.spam - t.speed)/(t.spam - t.full))) -- Now we get draw% (normalised from 0 to 1)
    local damage = t.min + (t.max - t.min) * draw
--     print(printify(t.speed)..' | '..printify(draw))
    return damage
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
                local multiplier = damage/Armor_Damage_To_XP * 2*Dt.GMST.iBaseArmorSkill / (Dt.GMST.iBaseArmorSkill + skill)
                xp = xp * multiplier

                print('SUS [Armor] XP Mult: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | Damage Received: '.. printify(damage))

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

            -- Scale XP:

            local multiplier = damage/Block_Damage_To_XP * (Dt.GMST.iBlockMaxChance+Dt.GMST.iBlockMinChance) / (2*Dt.GMST.iBlockMinChance + skill)
            xp = xp * multiplier

            print('SUS [Block] XP Mult: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | Damage Received: '.. printify(damage))

            return xp
        end
    }

    -- UNARMORED Scaling
-----------------------------------------------------------------------------------------------------------
    Dt.scalers:new{ name = 'unarmored', 
        func = function(xp)


            -- Calculate factors:

            local armor_weight = 0
            local armor = Fn.get_equipped('ARMOR')
            -- Only calculate armor if there is armor, oR eLSE. >:|
            if armor then for _, _obj in ipairs(armor) do armor_weight = armor_weight + types.Armor.record(_obj).weight end end
            local race         = get_val(types.Player.record(self).race)
            local beast_factor = 1 -- If you have more than 3 empty slots, this will stay a 1 and not affect your XP rates, even if you are Argonian/Khajiit
            if #Fn.get_unarmored_slots() <= 3 and (race == 'argonian' or race == 'khajiit') then beast_factor = Unarmored_Beast_Races / #Fn.get_unarmored_slots() end
            local gank_factor  = Unarmored_Hits_To_XP / Fn.recent_activations(1, 'unarmored', Unarmored_Hit_Timer)
            local skill        = types.Player.stats.skills['unarmored'](self).base
            local rating       = skill * Dt.GMST.fUnarmoredBase1 * skill * Dt.GMST.fUnarmoredBase2
            local skill_factor = 100 / (35 + rating + skill + armor_weight * Unarmored_Armor_Mult) -- Rating is added here alongside skill, because unarmored has exponential scaling baked in.

            -- Scale XP:

            local multiplier = skill_factor * beast_factor * gank_factor
            local xp = xp * multiplier

            print('SUS [Unarmored] XP Mult: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp))

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
                local multiplier = spell_cost/Magicka_to_XP * 4.8/(4 + mp_factor)
                xp = xp * multiplier

                print('SUS [Magic] XP Mult: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | Spell Cost: '.. printify(spell_cost))

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

                print('SUS - Refund: '.. printify(refund*100)..'% | '.. printify(refund) ..' MP')

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

                local condition_lost = Dt.pc_held_weapon_condition - weapon.condition
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
                local speed_factor = 0.5 + wp.speed/2 -- Attackspeed, approximated to it's effect on animation speed
                local min_cond_dmg = 2 / Dt.GMST.fWeaponDamageMult
                if damage < (min_cond_dmg - 0.001) then
                    local str_mod = types.Player.stats.attributes.strength(self).base * Dt.GMST.fDamageStrengthMult / 10 + Dt.GMST.fDamageStrengthBase
                    local condition_mod = weapon.condition/types.Weapon.record(wp_obj).health
                    local function getMinDamage(val) return math.max(1, math.min(min_cond_dmg, val * str_mod * condition_mod)) end
                    local function getBestAttack(_obj)
                        local best = wp.chopMaxDamage
                        local atk  = 'chop'
                        if     best < wp.slashMaxDamage  then best = wp.slashMaxDamage  atk = 'slash'
                        elseif best < wp.thrustMaxDamage then best = wp.thrustMaxDamage atk = 'thrust' end
                        return wp[atk..'MinDamage'], wp[atk..'MaxDamage']
                    end
                    local mindamage, maxdamage = getBestAttack(weapon.object)
                    damage = Fn.estimate_base_damage{speed = Dt.attackspeed.current, full = 0.85*speed_factor, spam = 1.45*speed_factor,
                                                     min = getMinDamage(mindamage), max = getMinDamage(maxdamage)}
                end
                -- Scale XP:

                local skill = types.Player.stats.skills[_skillid](self).base
                --NOTE: due to durability being an integer, this will only change in steps of 10 damage (unless you have changed your Durability GMST).
                -- If you have the Weapon-XP-Precision addon, this increases in steps of 2.5 damage instead.
                local multiplier = damage/speed_factor/Physical_Damage_to_XP * 80/(40 + skill)
                xp = xp * multiplier

                print('SUS [Melee] XP Mult: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | Damage Dealt: '.. printify(damage))

                return xp
            end
        }
    end
    -- MARKSMAN Scaling
-----------------------------------------------------------------------------------------------------------        Dt.scalers:new{ name = 'marksman', 
    Dt.scalers:new{ name = 'marksman', 
        func = function(xp)
            -- Mostly the same as MELEE, but we an abridged alternate formula for throwables and different Dt values for bows & crossbows
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
                
                local condition_lost = Dt.pc_bow.condition - bow.condition
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
                    local condition_mod = bow.condition/types.Weapon.record(bow.object).health
                    local function getMinDamage(val) return math.max(1, math.min(min_cond_dmg, val * str_mod * condition_mod)) end
                    damage = Fn.estimate_base_damage{speed = Dt.attackspeed.current, full = 0.5, spam = 0.75, min = getMinDamage(wp.chopMinDamage), max = getMinDamage(wp.chopMaxDamage)}
                end
                
            -- Thrown Weapon Scaler
            elseif thrown then 
                wp = types.Weapon.record(thrown)
                local str_mod = types.Player.stats.attributes.strength(self).base * Dt.GMST.fDamageStrengthMult / 10 + Dt.GMST.fDamageStrengthBase
                -- Now we use our handy attack draw estimation along with min and max damage to (hopefully) get your real damage (mostly) right.
                -- full = 0.9 -- config point. Less than this is  a full draw or 1st click.
                -- spam = 1.45 -- config point. More than this is spam clicking.
                damage = Fn.estimate_base_damage{speed = Dt.attackspeed.current, full = 0.9, spam = 1.45, min = wp.chopMinDamage, max = wp.chopMaxDamage}
                damage = damage * str_mod * 2 -- Gotta account for chonk stronk & for thrown weaponns being both weapon and ammo
            -- If we don't have a bow but somehow don't remember last throwable either, also skip.
            else print('SUS - No Ammo in Dt.pc_ammo') return xp
            -- If we got here, we have a valid weapon and damage number, and should apply scaling.
            end

            -- Scale XP:

            local speed_factor = 0.5 + wp.speed/2
            local skill = types.Player.stats.skills['marksman'](self).base
            --NOTE: due to durability being an integer, this will only change in steps of 10 damage (unless you have changed your Durability GMST).
            -- If you have the Weapon-XP-Precision addon, this increases in steps of 2.5 damage instead.
            local multiplier = damage/speed_factor/Physical_Damage_to_XP * 80/(40 + skill)
            xp = xp * multiplier

            print('SUS [Marksman] XP Mult: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | Damage Dealt: '.. printify(damage))

            return xp
        end
    }
    -- HAND TO HAND Scaling
-----------------------------------------------------------------------------------------------------------
    Dt.scalers:new{ name = 'handtohand', 
        func = function(xp)
            local str_mod = types.Player.stats.attributes.strength(self).base * HandToHand_Strength
            local speed = Dt.attackspeed.current
            local full = 0.9 -- config point. Less than this is  a full draw or 1st click.
            local spam = 2.0 -- config point. More than this is spam clicking.
            local claw = 0
            if types.NPC.isWerewolf(self) then
                claw = Dt.GLOB.WerewolfClawMult
                if H2H_STR_Werewolves then claw = claw * str_mod end
            end
            local damage_per_skillpoint = Fn.estimate_base_damage{speed = Dt.attackspeed.current, full = 0.9, spam = 1.9, min = Dt.GMST.fMinHandToHandMult, max = Dt.GMST.fMaxHandToHandMult}
            local skill = types.Player.stats.skills['handtohand'](self).base -- Note we don't count fortifies. This prevents sujama from murdering your XP rates.
            local damage = (damage_per_skillpoint * skill) * str_mod + claw
            -- Now we average your fatigue damage and your health damage.
            -- It's the best method I could think of to balance the fact that H2H goes through 2 different healthbars at 2 different rates
            -- ..while also keeping compatibility with mods that change H2H GMSTs.
            local damage = (damage + damage * Dt.GMST.fHandtoHandHealthPer)/2
            -- Scale XP:

            local multiplier = damage/Physical_Damage_to_XP * 80/(40 + skill)
            xp = xp * multiplier

            print('SUS [Hand-To-Hand] XP Mult: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | Damage Dealt: '.. printify(damage))

            return xp
        end
    }
    Dt.scalers:new{ name = 'acrobatics', 
        func = function(xp)
            
            local multiplier = 1
            xp = xp * multiplier

            print('SUS [Acrobatics] XP Mult: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | : '.. printify(0))
            return xp
        end
    }
    Dt.scalers:new{ name = 'athletics', 
        func = function(xp)
            
            local multiplier = 1
            xp = xp * multiplier

            print('SUS [Athletics] XP Mult: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | : '.. printify(0))
            return xp
        end
    }
    Dt.scalers:new{ name = 'security', 
        func = function(xp)

            local multiplier = 1
            xp = xp * multiplier

            print('SUS [Security] XP Mult: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | : '.. printify(0))
            return xp
        end
    }

    print('SUS: Scalering Commenced')
end

-----------------------------------------------------------------------------------------------------------

-- RETURN || NEED THIS SO FILE DO THING
return Fn
