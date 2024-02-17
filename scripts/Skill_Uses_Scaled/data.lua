
-- TOOLS
local function makeKeyEnum(keys)
local result = {}
for _, key in ipairs(keys) do
  result[key] = key
end
return result
end

local Data = {
-- Player Data
    pc_held_spell = 'spellid',
    pc_held_weapon = {itemid = 'id Not Assigned', object = 'object Not Assigned', condition = 0},
    pc_level = 0,
-- Compatibility and Engine Data
    ATTRIBUTES = {'strength', 'intelligence', 'willpower', 'agility', 'speed', 'endurance', 'personality', 'luck'},
    SKILLS = {
        'acrobatics' , 'alchemy'  , 'alteration' , 'armorer'   , 'athletics' , 'axe'       , 'block'    , 'bluntweapon', 'conjuration',
        'destruction', 'enchant'  , 'handtohand' , 'heavyarmor', 'illusion'  , 'lightarmor', 'longblade', 'marksman'   , 'mediumarmor',
        'mercantile' , 'mysticism', 'restoration', 'security'  , 'shortblade', 'sneak'     , 'spear'    , 'speechcraft', 'unarmored'
    },
    scaler_groups = {
    SPELL = makeKeyEnum{'alteration', 'conjuration', 'destruction', 'illusion', 'mysticism', 'restoration'},
    MELEE_WEAPON = makeKeyEnum{'axe', 'bluntweapon', 'longblade', 'shortblade', 'spear'}, -- !! Weapon health gets reduced by *net* damage dealt.
    ARMOR = makeKeyEnum{'heavyarmor', 'lightarmor', 'mediumarmor'}, -- !! Armor health gets reduced by the amount of incoming damage it *blocked*.
    },
    STANCES = {nothing = 0, magic = 1, physical  = 2},
    
    -- SCRIPT LOGIC VARIABLES
--     enteringLevelup = false
}

-- RETURN || NEED THIS SO FILE DO THING
return Data
