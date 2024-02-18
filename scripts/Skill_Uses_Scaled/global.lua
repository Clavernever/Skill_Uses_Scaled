local core  = require('openmw.core')
local types = require('openmw.types')

-- All we do here is dynamically attach weapon scripts.
-- We have to do this because the WEAPON tag only applies to weapons on the overworld, not in inventories.

return {
    eventHandlers = {
        SUS_addScript = function(t)
            if not t.obj:hasScript('scripts/Skill_Uses_Scaled/'..t.script) then
                t.obj:addScript('scripts/Skill_Uses_Scaled/'..t.script) 
            end
        end
    }
}
