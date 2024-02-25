local core  = require('openmw.core')
local world = require('openmw.world')

local Dt = require('scripts.Skill_Uses_Scaled.data')

-- All we do here is:
-- Get global variables (GLOB) so core.lua can update the corresponding Dt values with them.

return {
    eventHandlers = {
        SUS_updateGLOBvar = function(t) t.source:sendEvent('SUS_updateGLOBvar', {id = t.id, val = world.mwscript.getGlobalVariables(t.source)[t.id]}) end, -- t = {id = 'id', source = _obj}
    }
}
