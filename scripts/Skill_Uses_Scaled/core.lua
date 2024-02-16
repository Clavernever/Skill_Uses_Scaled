
local Fn     = require('scripts.Skill_Uses_Scaled.func')

return {
    engineHandlers = {
        onActive = function()
            Fn.scale_skills()
        end
    },
    eventHandlers = {
    }
}
