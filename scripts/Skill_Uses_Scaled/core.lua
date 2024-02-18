local core  = require('openmw.core')
local types = require('openmw.types')
local self  = require('openmw.self')
local skp   = require('openmw.interfaces').SkillProgression

local Dt = require('scripts.Skill_Uses_Scaled.data')
local Fn     = require('scripts.Skill_Uses_Scaled.func')

has_precision_addon = core.contentFiles.has("S_U_S_Weapon-XP-Precision.omwaddon") -- No need to check this at the moment, I accidentally made the formulas natively compatible lol

onActive = function()
    Fn.make_scalers()
    skp.addSkillUsedHandler(function(skillid, useType, options)
        if Dt.scalers[skillid] then
            print('Calling scaler: '..skillid)
            options.skillGain = Dt.scalers[skillid].func(options.skillGain)
        end
    end)
end

onUpdate = function(dt)
    if types.Actor.STANCE.Weapon == types.Actor.getStance(self) then
        Dt.pc_held_weapon.prevframe = Dt.pc_held_weapon.thisframe
        Dt.pc_held_weapon.thisframe = Fn.get_equipped_weapon()
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
