local core   = require('openmw.core')
local self   = require('openmw.self')
local types  = require('openmw.types')
local async  = require('openmw.async')
local time   = require('openmw_aux.time')
local i_UI   = require('openmw.interfaces').UI
local input  = require('openmw.input')
local camera = require('openmw.camera')
local util   = require('openmw.util')
local nearby = require('openmw.nearby')
local skp    = require('openmw.interfaces').SkillProgression
local anim   = require('openmw.animation')

local Dt = require('scripts.Skill_Uses_Scaled.data')
local Cfg = require('scripts.Skill_Uses_Scaled.config')

-- TOOLS
local eps = 0.001
function equal(a,b)          return (math.abs(b - a) < eps)                                  end

local function printify(num) return math.floor(num*1000 + 0.5)/1000 end
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

-- Credit to Pharis for this one. I couldn't have made it, no chance in hell.
local function getFacedObject()
    local origin = camera.getPosition();
    local direction = camera.viewportToWorldVector(util.vector2(0.5, 0.5));

    local activationDistance = Dt.GMST.iMaxActivateDist + camera.getThirdPersonDistance();
        local telekinesis = types.Actor.activeEffects(self):getEffect(core.magic.EFFECT_TYPE.Telekinesis);
    if (telekinesis) then
        activationDistance = activationDistance + (telekinesis.magnitude * 22);
    end;

    local result = nearby.castRenderingRay(
        origin,
        origin + direction * activationDistance,
        { ignore = self }
    );

    if (result ~= nil and result.hit) then return result.hitObject; end;
end;

-- DEFINITIONS --
-----------------------------------------------------------------------------------------------------------

local Fn = {}

-----------------------------------------------------------------------------------------------------------

Fn.get_attack_damage = function(min, max, str_mod, health_mod, draw)
    local base = min + (max - min) * draw
    local damage = base * str_mod * health_mod
    return damage
end
Fn.get_H2H_damage = function(draw)
    local str_mod = types.Player.stats.attributes.strength(self).base * Cfg.HandToHand_Strength
    local claw = 0
    if types.NPC.isWerewolf(self) then
        claw = Dt.GLOB.WerewolfClawMult
        if Cfg.H2H_STR_Werewolves then claw = claw * str_mod end
    end
    local damage_per_skillpoint = Fn.get_attack_damage(Dt.GMST.fMinHandToHandMult, Dt.GMST.fMaxHandToHandMult, str_mod, 1, draw)
    local skill = types.Player.stats.skills.handtohand(self).base -- Note we don't count fortifies. This prevents sujama from murdering your XP rates.
    local damage = (damage_per_skillpoint * skill) + claw
    return damage
end
Fn.get_weapon_damage = function(weapon, draw, atktype)
    local wp_record = types.Weapon.record(weapon)
    local min = wp_record[atktype..'MinDamage']
    local max = wp_record[atktype..'MaxDamage']
    local str_mod = types.Player.stats.attributes.strength(self).base * Dt.GMST.fDamageStrengthMult / 10 + Dt.GMST.fDamageStrengthBase
    local dur_current = weapon.condition
    local dur_max = wp_record.health
    local health_mod = 1
    if dur_current then health_mod = weapon.condition/types.Weapon.record(wp_obj).health 
    elseif Dt.WEAPON_TYPES.BOW[wp_record.type] then 
        local ammo = types.Actor.getEquipment(self, Dt.SLOTS.AMMO)
        ammo_record = types.Weapon.record(ammo)
        min = min + ammo_record[atktype..'MinDamage']
        max = max + ammo_record[atktype..'MaxDamage']
    elseif Dt.WEAPON_TYPES.THROWN[wp_record.type] then
        health_mod = 2 --Thrown weapons count twice as they are both weapon and projectile.
    end
    local damage = Fn.get_attack_damage(min, max, str_mod, health_mod, draw)
    return damage
end

function Fn.get_attack(groupname, key)
    if Dt.pc.attack.step == 0 then
        if Dt.ATTACK_ANIMATION_KEYS.MIN[key] then
            Dt.pc.attack.begin = anim.getCompletion(self, groupname)
            Dt.pc.attack.step = 1
        end
    elseif Dt.pc.attack.step == 1 or Dt.pc.attack.step == 2 then
        if Dt.pc.attack.step == 1 and Dt.ATTACK_ANIMATION_KEYS.MAX[key]then
            Dt.pc.attack.release = anim.getCompletion(self, groupname)
            Dt.pc.attack.step = 2
        elseif Dt.ATTACK_ANIMATION_KEYS.HIT_RELEASE[key] then
            -- Get Draw
            local begin = Dt.pc.attack.begin
            local release = Dt.pc.attack.release
            if Dt.pc.attack.step == 1 then release = begin end
            local draw = 1
            if begin ~= 1 then draw = (math.max(0, release - begin))/(1 - begin) end
            -- Get attack min and max damages
            local weapon = types.Actor.getEquipment(self, Dt.SLOTS.WEAPON)
            if weapon then
                Dt.pc.attack.damage = math.max(1, Fn.get_weapon_damage(weapon, draw, Dt.ATTACK_ANIMATION_KEYS.HIT_RELEASE[key]))
            else
                Dt.pc.attack.damage = math.max(1, Fn.get_H2H_damage(draw))
            end
            Dt.pc.attack.step = 0
--             print(groupname..' | Damage: '..printify(Dt.pc.attack.damage)..' | Draw: '..percentify(draw)..' | Key:'..key)
        end
    end
end

Fn.set_hit_release = function()
    if Dt.pc.attack.step == 1 then
        local groupname = anim.getActiveGroup(self, 2)
        Dt.pc.attack.release = anim.getCompletion(self, groupname)
        Dt.pc.attack.step = 2
    end
end
Fn.set_hit_release_callback = async:registerTimerCallback('set_hit_release_callback', function() if not input.getBooleanActionValue("Use") then Fn.set_hit_release() end end)

Fn.register_Use_Action_Handler = function()
    local useCallback = async:callback(
        function()
            if input.getBooleanActionValue("Use") then
                -- If in a menu or not in weapon stance, skip
                if i_UI.getMode() then return
                elseif Dt.STANCE.SPELL[types.Actor.getStance(self)] then
                    Dt.pc.spell = types.Actor.getSelectedSpell(self)
                elseif Dt.STANCE.WEAPON[types.Actor.getStance(self)] then
                    local weapon = types.Actor.getEquipment(self, Dt.SLOTS.WEAPON)
                    if not weapon then -- H2H
                        -- We request global.lua to request core.lua to update data.lua with the current WerewolfClawMult.
                        -- We do it here cause it needs 2 frames to resolve due to event delay, and this handler happens ~10 frames before the hit (and thus the skill handler).
                        if types.NPC.isWerewolf(self) then core.sendGlobalEvent('SUS_updateGLOBvar', {source = self.obj, id = 'WerewolfClawMult'}) end
                    elseif (weapon.type == types.Lockpick) or (weapon.type == types.Probe) then
                        Dt.pc.security_target = Fn.get_security_target()
                        Dt.securiting = true -- We make onFrame scan continuously in case the player starts without a valid target and moves their cursor to one while holding click down.
                    end
                end
            else
                if Dt.STANCE.WEAPON[types.Actor.getStance(self)] then
                    local weapon = types.Actor.getEquipment(self, Dt.SLOTS.WEAPON)
                    if not weapon or (weapon.type == types.Weapon) then -- H2H
                        if i_UI.getMode() then async:newSimulationTimer(0, Fn.set_hit_release_callback, nil)
                        else Fn.set_hit_release() end
                    elseif (weapon.type == types.Lockpick) or (weapon.type == types.Probe) then -- Security
                        Dt.securiting = false
                        Dt.pc.security_target = nil -- This will turn the scaler off in case another mod triggers security uses outside of this loop.
                    end
                end
            end
        end
    )
    input.registerActionHandler("Use", useCallback)
end

Fn.get_active_effect_mag = function(effectid) return types.Actor.activeEffects(self):getEffect(effectid).magnitude end

Fn.has_effect = function(effectid) return not (types.Actor.activeEffects(self):getEffect(effectid).magnitude == 0) end

Fn.get_security_target = function()
    local target = getFacedObject()
    local lockable = nil -- scopeset
    if target and (target.type == types.Door or target.type == types.Container) then
        lockable = {}
        lockable.islocked = types.Lockable.isLocked(target)
        lockable.level    = types.Lockable.getLockLevel(target)
        lockable.trap     = types.Lockable.getTrapSpell(target)
    end
    return lockable
end

Fn.get_equipped_armor = function()
    local armor_list = {}
    for _, _object in pairs(types.Actor.getEquipment(self)) do
        if _object.type == types.Armor then table.insert(armor_list, _object) end
    end
    return armor_list
end

Fn.get_hit_armorpiece = function()
    for _, _obj in ipairs(Fn.get_equipped_armor()) do
        local slot = types.Armor.record(_obj).type
        if not equal(Dt.pc.armor_condition.prevframe[slot], types.Item.itemData(_obj).condition) then return _obj end
    end
end

Fn.clean_slots = function(_slot, _armor_types) -- This is to guarantee we don't get ghost unarmored slots for gauntlets and bracers
    if     _slot == types.Armor.TYPE.LBracer or _slot == types.Armor.TYPE.LGauntlet then
        _armor_types[types.Armor.TYPE.LBracer  ] = nil
        _armor_types[types.Armor.TYPE.LGauntlet] = nil
    elseif _slot == types.Armor.TYPE.RBracer or _slot == types.Armor.TYPE.RGauntlet then
        _armor_types[types.Armor.TYPE.RBracer  ] = nil
        _armor_types[types.Armor.TYPE.RGauntlet] = nil
    else _armor_types[_slot] = nil
    end
    return _armor_types
end

Fn.get_unarmored_slots = function()
    local armor_types = get(Dt.ARMOR_TYPES)
    local armor = Fn.get_equipped_armor()
    for _, _obj in ipairs(armor) do Fn.clean_slots(types.Armor.record(_obj).type, armor_types) end
    local unarmored_slots = {}
    for _slot, _ in pairs(armor_types) do table.insert(unarmored_slots, _slot) end
    return unarmored_slots --Note this is iterable and #ble. That's important.
end

Fn.get_AR = function()
    local skill       = 0
    local rating      = 0
    local armor = Fn.get_equipped_armor()
    for _, _obj in ipairs(armor) do
        skill  = types.Player.stats.skills[getArmorType(_obj)](self).modified
        local slot   = types.Armor.record(_obj).type
        local hp_mod = types.Item.itemData(_obj).condition / types.Armor.record(_obj).health
        rating = rating + types.Armor.record(_obj).baseArmor * hp_mod * Dt.ARMOR_RATING_WEIGHTS[slot] * skill / Dt.GMST.iBaseArmorSkill
    end
    local unarmored_slots = Fn.get_unarmored_slots()
    for _, _slot in ipairs(unarmored_slots) do
        skill = types.Player.stats.skills.unarmored(self).modified
        rating = rating + skill * Dt.GMST.fUnarmoredBase1 * skill * Dt.GMST.fUnarmoredBase2 * Dt.ARMOR_RATING_WEIGHTS[_slot]-- Why have 2 GMSTs for 1 number? Precision? Yeah precision I guess.
    end
    rating = rating + Fn.get_active_effect_mag('shield')
    return rating
end

Fn.recent_activations = function(amount, source, simtime)
    if not Dt.recent_activations[source] then
        Dt.recent_activations[source] = {callback = source, counter = makecounter(0)}
        Dt.recent_activations[source].callback = async:registerTimerCallback(Dt.recent_activations[source].callback, Dt.recent_activations[source].counter)
    end
    async:newSimulationTimer(simtime, Dt.recent_activations[source].callback, -amount)
    return Dt.recent_activations[source].counter(amount)
end


Fn.make_scalers = function()

    -- ARMOR Scaling
-----------------------------------------------------------------------------------------------------------
    for _, _skillid in ipairs(Dt.scaler_groups.ARMOR) do
        Dt.scalers:new{
            name = _skillid,
            func = function(_, xp)
                -- Disable scaling while under the effect of Disintegrate Armor, for you may get ridiculous amounts of XP if the stars line up wrong.
                -- For the sake of robustness and simplicity, it's a tradeoff I'm willing to accept. I will NOT attempt to fix it.
                if Fn.has_effect('disintegratearmor') then
                    if Cfg.SUS_DEBUG then print('SUS - Disintegrate Armor in effect, returning vanilla XP') end
                    return xp
                end
                local armor_obj = Fn.get_hit_armorpiece()
                if not armor_obj then return xp end -- If we didn't find a hit piece, we skip scaling and leave XP vanilla. It's an edge case not worth pursuing.

                -- Estimate incoming damage from AR and condition lost instead of directly using condition lost.
                -- This helps avoid low ARs becoming a pit of neverleveling.
                local condition_lost = Dt.pc.armor_condition.prevframe[types.Armor.record(armor_obj).type] - types.Item.itemData(armor_obj).condition
                local rating = Fn.get_AR()
                local damage = (condition_lost * rating)/(rating - condition_lost)
                -- Armor skill and AR GMSTs are combined to make leveling below base AR faster, and above slower.
                local skill = types.Player.stats.skills[_skillid](self).base
                local multiplier = damage/Cfg.Armor_Damage_To_XP * 2*Dt.GMST.iBaseArmorSkill / (Dt.GMST.iBaseArmorSkill + skill)
                xp = xp * multiplier

                if Cfg.SUS_DEBUG then print('SUS [Armor] Skill Uses: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | Damage Received: '.. printify(damage)) end

                -- Add a hit for Unarmored's timer, so that having a couple empty pieces doesn't result in massive unarmored bonuses.
                Fn.recent_activations(1, 'unarmored', Cfg.Unarmored_Hit_Timer)

                return xp
            end
        }
    end

    -- BLOCK Scaling
-----------------------------------------------------------------------------------------------------------
    Dt.scalers:new{ name = 'block',
        func = function(_, xp)
            -- Disable scaling while under the effect of Disintegrate Armor, for you may get ridiculous amounts of XP if the stars line up wrong.
            -- For the sake of robustness and simplicity, it's a tradeoff I'm willing to accept. I will NOT attempt to fix it.
            if Fn.has_effect('disintegratearmor') then
                if Cfg.SUS_DEBUG then print('SUS - Disintegrate Armor in effect, returning vanilla XP') end
                return xp
            end
            local armor_obj = types.Actor.getEquipment(self, Dt.SLOTS.SHIELD)
            local current_shield_condition = 0 -- if armor_obj is nill, because the shield was broken and unequipped, then we count condition as 0.
            -- With armor the likelyhood of breaking is low, so we're better off just returning xp, but here we should air on the side of scaling the edge case rather than ignoring it.
            if armor_obj then current_shield_condition = types.Item.itemData(armor_obj).condition end
            local condition_lost = Dt.pc.armor_condition.prevframe[types.Armor.record(armor_obj).type] - current_shield_condition
            local damage = condition_lost
            -- Armor skill and AR GMSTs are combined to make leveling below base AR faster, and above slower.
            local skill = types.Player.stats.skills.block(self).base

            local multiplier = damage/Cfg.Block_Damage_To_XP * (Dt.GMST.iBlockMaxChance+Dt.GMST.iBlockMinChance) / (2*Dt.GMST.iBlockMinChance + skill)
            xp = xp * multiplier

            if Cfg.SUS_DEBUG then print('SUS [Block] Skill Uses: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | Damage Received: '.. printify(damage)) end

            -- Note we DON'T add an unarmored hit down here. You fully blocked, took no damage and gained no armor skill xp, so it doesn't count as a hit in my books.

            return xp
        end
    }

    -- UNARMORED Scaling
-----------------------------------------------------------------------------------------------------------
    Dt.scalers:new{ name = 'unarmored', 
        func = function(_, xp)
            local armor_weight = 0
            local armor = Fn.get_equipped_armor()
            for _, _obj in ipairs(armor) do armor_weight = armor_weight + types.Armor.record(_obj).weight end
            local race         = get_val(types.Player.record(self).race)
            local beast_factor = 1 -- If you have more than 3 empty slots, this will stay a 1 and not affect your XP rates, even if you are Argonian/Khajiit
            if #Fn.get_unarmored_slots() <= 3 and (race == 'argonian' or race == 'khajiit') then beast_factor = Cfg.Unarmored_Beast_Races / #Fn.get_unarmored_slots() end
            local gank_factor  = Cfg.Unarmored_Hits_To_XP / Fn.recent_activations(1, 'unarmored', Cfg.Unarmored_Hit_Timer)
            local skill        = types.Player.stats.skills['unarmored'](self).base
            local rating       = skill * Dt.GMST.fUnarmoredBase1 * skill * Dt.GMST.fUnarmoredBase2
            local skill_factor = 100 / (35 + rating + skill + armor_weight * Cfg.Unarmored_Armor_Mult) -- Rating is added here alongside skill, because unarmored has exponential scaling baked in.

            local multiplier = skill_factor * beast_factor * gank_factor
            local xp = xp * multiplier

            if Cfg.SUS_DEBUG then print('SUS [Unarmored] Skill Uses: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | Hit Counter: '..Dt.recent_activations['unarmored'].counter(0)) end

            return xp
        end
    }

        -- SPELL Scaling
-----------------------------------------------------------------------------------------------------------
    for _, _skillid in ipairs(Dt.scaler_groups.SPELL) do
        Dt.scalers:new{ name = _skillid, 
            func = function(_, xp)

                local spell = Dt.pc.spell
                if not spell then 
                    if Cfg.SUS_DEBUG then print('SUS - Held Spell not found, returning vanilla XP') end
                    return xp
                end
                local mp_factor = 0.01*Fn.get_active_effect_mag('fortifymagicka') + 0.1*Fn.get_active_effect_mag('fortifymaximummagicka')
                local multiplier = spell.cost/Cfg.Magicka_to_XP * 4.8/(4 + mp_factor)
                xp = xp * multiplier

                if Cfg.SUS_DEBUG then print('SUS [Magic] Skill Uses: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | Spell Cost: '.. printify(spell.cost)) end

                -- MP Refund:
                local armor_weight = 0
                local armor = Fn.get_equipped_armor()
                for _, _obj in ipairs(armor) do armor_weight = armor_weight + types.Armor.record(_obj).weight end
                local armor_offset = armor_weight * Cfg.MP_Refund_Armor_Mult
                local cost_factor = Cfg.Magicka_to_XP / (Cfg.Magicka_to_XP + spell.cost/Cfg.Magicka_to_XP)
                local skill = types.Player.stats.skills[_skillid](self).base
                local skill_factor = (skill - Cfg.MP_Refund_Skill_Offset - armor_offset) / (40 + skill)

                local refund = spell.cost * cost_factor * skill_factor * 0.01*Cfg.MP_Refund_Max_Percent

                --Yes, this will apply even if current > max.
                --To keep vanilla compatibility, we have to consider current>max as a valid gameplay state, since Fortify Magicka doesn't increase Max MP.
                types.Player.stats.dynamic.magicka(self).current = types.Player.stats.dynamic.magicka(self).current + refund

                if Cfg.SUS_DEBUG then print('SUS - Refund: '.. printify(refund*10)..'% | '.. printify(refund) ..' MP') end

                return xp
            end
        }
    end

    -- MELEE Scaling
-----------------------------------------------------------------------------------------------------------
    for _, _skillid in ipairs(Dt.scaler_groups.WEAPON) do
        Dt.scalers:new{ name = _skillid, 
            func = function(_, xp)

                local skill = types.Player.stats.skills[_skillid](self).base
                local multiplier = Dt.pc.attack.damage/Cfg.Physical_Damage_to_XP * 80/(40 + skill)
                xp = xp * multiplier
                if Cfg.SUS_DEBUG then print('SUS [Weapon] Skill Uses: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | Damage Dealt: '.. printify(Dt.pc.attack.damage)) end
                return xp
            end
        }
    end

    -- HAND TO HAND Scaling
-----------------------------------------------------------------------------------------------------------
    Dt.scalers:new{ name = 'handtohand', 
        func = function(_, xp)

            -- Now we average your fatigue damage and your health damage.
            -- It's the best method I could think of to balance the fact that H2H goes through 2 different healthbars at 2 different rates
            -- ..while also keeping compatibility with mods that change H2H GMSTs.
            local skill = types.Player.stats.skills.handtohand(self).base
            local damage = Dt.pc.attack.damage
            local damage = (damage + damage * Dt.GMST.fHandtoHandHealthPer)/2
            local multiplier = damage/Cfg.Physical_Damage_to_XP * 80/(40 + skill)
            xp = xp * multiplier
            if Cfg.SUS_DEBUG then print('SUS [Hand-To-Hand] Skill Uses: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | Damage Dealt: '.. printify(damage)) end
            return xp
        end
    }
    Dt.scalers:new{ name = 'acrobatics', 
        func = function(_, xp)

            local fatigued_mult   = Cfg.Acrobatics_FP_Min + (Cfg.Acrobatics_FP_Max - Cfg.Acrobatics_FP_Min)
                                    * types.Actor.stats.dynamic.fatigue(self).current / types.Actor.stats.dynamic.fatigue(self).base
            local encumbered_mult = Cfg.Acrobatics_Encumbrance_Min + (Cfg.Acrobatics_Encumbrance_Max - Cfg.Acrobatics_Encumbrance_Min)
                                    * types.Actor.getEncumbrance(self) / (Dt.GMST.fEncumbranceStrMult * types.Player.stats.attributes.strength(self).base)

            local multiplier = fatigued_mult * encumbered_mult -- No fatigue% => no XP, and more weight% == less XP
            xp = xp * multiplier
            if Cfg.SUS_DEBUG then print('SUS [Acrobatics] Skill Uses: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | FP: '.. percentify(types.Actor.stats.dynamic.fatigue(self).current / types.Actor.stats.dynamic.fatigue(self).base)) end
            return xp
        end
    }
    Dt.scalers:new{ name = 'athletics', 
        func = function(_, xp)

            local fatigued_mult   = Cfg.Athletics_FP_Min + (Cfg.Athletics_FP_Max - Cfg.Athletics_FP_Min)
                                    * types.Actor.stats.dynamic.fatigue(self).current / types.Actor.stats.dynamic.fatigue(self).base
            local encumbered_mult = Cfg.Athletics_Encumbrance_Min + (Cfg.Athletics_Encumbrance_Max - Cfg.Athletics_Encumbrance_Min)
                                    * types.Actor.getEncumbrance(self) / (Dt.GMST.fEncumbranceStrMult * types.Player.stats.attributes.strength(self).base)

            local multiplier = fatigued_mult * encumbered_mult -- No fatigue% => no XP, and more weight% == more XP
            xp = xp * multiplier
            local printcounter = Dt.counters.athletics(1)
            if Cfg.SUS_DEBUG then 
                if printcounter > 9.01 then
                    print('SUS [Athletics] Skill Uses: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp * printcounter)..' | FP: '.. percentify(types.Actor.stats.dynamic.fatigue(self).current / types.Actor.stats.dynamic.fatigue(self).base))
                    Dt.counters.athletics(-printcounter)
                end
            end
            return xp
        end
    }
    Dt.scalers:new{ name = 'security', 
        func = function(useType, xp)

            local target = Dt.pc.security_target
            if not target then
                print('SUS - Targeted Door/Container not found, returning vanilla xp')
                return xp
            end
            local security_print = ''
            local multiplier = 1
            if (useType == skp.SKILL_USE_TYPES.Security_PickLock) and Dt.pc.security_target.islocked then
                multiplier = target.level/Cfg.Security_Lock_Points_To_XP
                security_print = 'Lock Level: '..target.level
            elseif (useType == skp.SKILL_USE_TYPES.Security_DisarmTrap) and Dt.pc.security_target.trap then
                multiplier = target.trap.cost/Cfg.Security_Trap_Points_To_XP
                security_print = 'Trap Level: '..target.trap.cost
            end

            xp = xp * multiplier
            if Cfg.SUS_DEBUG then print('SUS [Security] Skill Uses: '.. printify(multiplier)..' | Skill Progress: '..percentify(xp)..' | '..security_print) end
            return xp
        end
    }

    if Cfg.SUS_DEBUG then print('SUS: Scalering Commenced') end
end

-----------------------------------------------------------------------------------------------------------

-- RETURN || NEED THIS SO FILE DO THING
return Fn
