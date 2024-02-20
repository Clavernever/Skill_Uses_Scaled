local core  = require('openmw.core')
local types = require('openmw.types')
local self  = require('openmw.self')
local skp   = require('openmw.interfaces').SkillProgression

local Dt = require('scripts.Skill_Uses_Scaled.data')
local Fn = require('scripts.Skill_Uses_Scaled.func')

has_precision_addon = core.contentFiles.has("S_U_S_Weapon-XP-Precision.omwaddon") -- No need to check this at the moment, I accidentally made the formulas natively compatible lol

onActive = function()
    Fn.make_scalers()
    skp.addSkillUsedHandler(function(skillid, useType, options)
        if Dt.scalers[skillid] then
            options.skillGain = Dt.scalers[skillid].func(options.skillGain)
        end
    end)
end
local weapontype = nil
local onUpdate = function(dt)
    if Dt.STANCE_WEAPON[types.Actor.getStance(self)] then
        Fn.get_weapon_data()
    end
    local slot = 0
    local equipped_armor_thisframe = {}
    local armor = Fn.get_equipped('ARMOR')
    if armor then
        for _, _obj in ipairs(armor) do
            equipped_armor_thisframe[types.Armor.record(_obj).type] = types.Item.itemData(_obj).condition
        end
    end
    Dt.pc_equipped_armor_condition:set_prevframe(equipped_armor_thisframe)
end

return {
    engineHandlers = {
        onActive = onActive,
        onUpdate = onUpdate,
    },
    eventHandlers = {
    }
}
