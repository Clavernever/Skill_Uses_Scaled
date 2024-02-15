local core  = require('openmw.core')
local self  = require('openmw.self')
local types = require('openmw.types')
local skp   = require('openmw.interfaces').SkillProgression

local Dt = require('scripts.gentler_racemenu.data').Data

-- TOOLS
local eps = 0.001
function equal(a,b)                         return (math.abs(b - a) < eps)                                  end
local function get_val(not_table_or_func)   return not_table_or_func                                        end
local function table_find(table, thing)
    if type(thing) == 'number' then  for k, v in pairs(table) do  if equal(v, thing) then return thing end  end
    else  for k, v in pairs(table) do  if v == thing then return thing end  end
    end
end

-- DEFINITIONS --
-----------------------------------------------------------------------------------------------------------

local Func = {}

-----------------------------------------------------------------------------------------------------------

Func.scale_skills = function()
    -- Loop through all skills and call Dt.uncapper.skills:new(name = 'skillid', handler = handler(skillid, source, options)) on each skill.
    for _, _skillid in ipairs(Dt.) do
    Dt.scaler.skills:new{name = 'skillid', 
        handler = function(skillid, source, options)
            
        end
    }
end

-----------------------------------------------------------------------------------------------------------

-- RETURN || NEED THIS SO FILE DO THING
return Func
