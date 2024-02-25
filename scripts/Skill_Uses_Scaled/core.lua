local core  = require('openmw.core')
local types = require('openmw.types')
local self  = require('openmw.self')
local skp   = require('openmw.interfaces').SkillProgression
local anim = require('openmw.animation')
local i_AnimControl = require('openmw.interfaces').AnimationController

local Dt = require('scripts.Skill_Uses_Scaled.data')
local Fn = require('scripts.Skill_Uses_Scaled.func')
local Cfg = require('scripts.Skill_Uses_Scaled.config')

for _, _groupname in ipairs(Dt.ATTACK_ANIMATION_GROUPS) do
    i_AnimControl.addTextKeyHandler(_groupname, function(groupname, key) Fn.get_attack(groupname, key) end)
end

Fn.register_Use_Action_Handler()

onActive = function()
    Fn.make_scalers()
    skp.addSkillUsedHandler(function(skillid, useType, options)
        if Dt.scalers[skillid] then
            options.skillGain = Dt.scalers[skillid].func(useType, options.skillGain)
        end
    end)
end
local armor = nil                   -- create here instead of every frame
local equipped_armor_thisframe = {} -- create here instead of every frame
local onUpdate = function(dt)
    armor_thisframe = {}
    armor = Fn.get_equipped_armor()
    for _, _obj in ipairs(armor) do
        armor_thisframe[types.Armor.record(_obj).type] = types.Item.itemData(_obj).condition
    end
    Dt.pc.armor_condition:set_prevframe(armor_thisframe)
end
local onFrame = function(dt)
    if Dt.securiting then
        local target = Fn.get_security_target()
        if target then Dt.pc.security_target = target end
        if SUS_DEBUG then -- I'd love to not have this here, but it's better to have it.
            local printcounter = Dt.counters.security(1)
            if printcounter > 150.01 then
                print('Scanning lockables...')
                Dt.counters.security(-printcounter)
            end
        end
    end
end

-- TEST

-- Add a text key handler that will react to all keys





--I.AnimationController.addTextKeyHandler('', function(groupname, key) Fn.get_weapon_draw(groupname, key) end)
    
--END


return {
    engineHandlers = {
        onActive = onActive,
        onUpdate = onUpdate,
        onFrame  = onFrame ,
    },
    eventHandlers = {
        SUS_updateGLOBvar = function(t) Dt.GLOB[t.id] = t.val end
    }
}

