local core  = require('openmw.core')
local types = require('openmw.types')
local world = require('openmw.world')

local Dt = require('scripts.Skill_Uses_Scaled.data')

-- All we do here is:
-- Dynamically attach weapon scripts.
-- | We have to do this because the WEAPON tag only applies to weapons on the overworld, not in inventories.
-- Get global variables (GLOB) so core.lua can update the corresponding Dt values with them.

return {
    eventHandlers = {
        SUS_updateGLOBvar = function(t) t.source:sendEvent('SUS_updateGLOBvar', {id = t.id, val = world.mwscript.getGlobalVariables(t.source)[t.id]}) end, -- t = {id = 'id', source = _obj}
        SUS_addScript     = function(t) if not t.obj:hasScript('scripts/Skill_Uses_Scaled/'..t.script) then t.obj:addScript('scripts/Skill_Uses_Scaled/'..t.script)  end end
    }
}
