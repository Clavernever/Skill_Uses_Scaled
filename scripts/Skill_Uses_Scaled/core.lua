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
--             print('Calling scaler: '..skillid)
            options.skillGain = Dt.scalers[skillid].func(options.skillGain)
        end
    end)
end
onUpdate = function(dt)
    if types.Actor.STANCE.Weapon == types.Actor.getStance(self) then
        Dt.pc_held_weapon_condition.prevframe = Dt.pc_held_weapon_condition.thisframe
        Dt.pc_held_weapon_condition.thisframe = Fn.get_equipped_weapon().condition
    end
    local slot = 0
    for _, _obj in ipairs(Fn.get_equipped_armor()) do
        local slot = types.Armor.record(_obj).type
        if Dt.ARMOR_SLOTS[slot] then
            Dt.pc_equipped_armor_condition.prevframe[slot] = Dt.pc_equipped_armor_condition.thisframe[slot]
            Dt.pc_equipped_armor_condition.thisframe[slot] = types.Item.itemData(_obj).condition
--             print(types.Armor.record(_obj).id ..': '.. Dt.pc_equipped_armor_condition.thisframe[slot])
        end
    end
end

return {
    engineHandlers = {
        onActive = onActive,
        onUpdate = onUpdate,
    },
    eventHandlers = {
    }
}
