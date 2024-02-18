
-- TOOLS
local function makeKeyEnum(keys)
local result = {}
for _, key in ipairs(keys) do
  result[key] = key
end
return result
end

local Dt = {
-- Player Data
    pc_held_spell = 'spellid',
    pc_held_weapon = {
        thisframe = {itemid = 'id Not Assigned', object = 'object Not Assigned', condition = 0},
        prevframe = {itemid = 'id Not Assigned', object = 'object Not Assigned', condition = 0},
    },
    pc_marksman_weapon = {
        thisframe = {itemid = 'id Not Assigned', object = 'object Not Assigned', condition = 0},
        prevframe = {itemid = 'id Not Assigned', object = 'object Not Assigned', condition = 0},
    },
    pc_marksman_projectile = {
        count = 0,
        {itemid = 'id Not Assigned', object = 'object Not Assigned'},
    },
    pc_level = 0,
-- Engine Data
    ATTRIBUTES = {'strength', 'intelligence', 'willpower', 'agility', 'speed', 'endurance', 'personality', 'luck'},
    SKILLS = {
        'acrobatics' , 'alchemy'  , 'alteration' , 'armorer'   , 'athletics' , 'axe'       , 'block'    , 'bluntweapon', 'conjuration',
        'destruction', 'enchant'  , 'handtohand' , 'heavyarmor', 'illusion'  , 'lightarmor', 'longblade', 'marksman'   , 'mediumarmor',
        'mercantile' , 'mysticism', 'restoration', 'security'  , 'shortblade', 'sneak'     , 'spear'    , 'speechcraft', 'unarmored'
    },
    scaler_groups = {
        SPELL = {'alteration', 'conjuration', 'destruction', 'illusion', 'mysticism', 'restoration'},
        MELEE_WEAPON = {'axe', 'bluntweapon', 'longblade', 'shortblade', 'spear'}, -- !! Weapon health gets reduced by *net* damage dealt.
        ARMOR = {'heavyarmor', 'lightarmor', 'mediumarmor'}, -- !! Armor health gets reduced by the amount of incoming damage it *blocked*.
    },
    STANCES = {nothing = 0, magic = 1, physical  = 2},
    scalers = {
        default = {func = function(xp) return xp end},
        new = function(self, t) end-- t = {name = skillid, func = function(xp) dosomething return xp end}
    },
    -- SCRIPT LOGIC VARIABLES
    has_precision_addon = false,
}

--[] Setup metatable inheritance for Dt.scalers || DOESNT WORK AND I DONT KNOW WHY

-- Dt.scalers.mt = {__index = Dt.scalers.default}
-- setmetatable(Dt.scalers, Dt.scalers.mt)

--[] Scaler creator: Scalers are simple functions that become the body of skp.addSkillUsedHandler(func) through a Dt.scalers[skillid]() call.

function Dt.scalers:new(t)
    if (t.name) then self[t.name] = {} else error('You can\'t create a nameless scaler!') end
    self[t.name].func = t.func
    -- set inheritance || DOESNT WORK AND I DONT KNOW WHY
--     self[t.name].mt = {__index = self.default}
--     setmetatable(self[t.name], self[t.name].mt)
end

-- RETURN || NEED THIS SO FILE DO THING
return Dt
