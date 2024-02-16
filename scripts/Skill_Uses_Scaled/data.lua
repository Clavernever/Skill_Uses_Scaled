
-- TOOLS
local function makeIndexEnum(t)
    local RESULT = {}
    local i = 1
    for _k, _ in pairs(t) do
        RESULT[i] = _k
        i = i + 1
    end
    return RESULT
end

local Data = {
-- Player Data
    pc_held_spell = 'spellid',
    pc_level = 0,
-- Compatibility and Engine Data
    ATTRIBUTES = {'strength', 'intelligence', 'willpower', 'agility', 'speed', 'endurance', 'personality', 'luck'},
    SKILLS = {
        'acrobatics' , 'alchemy'  , 'alteration' , 'armorer'   , 'athletics' , 'axe'       , 'block'    , 'bluntweapon', 'conjuration',
        'destruction', 'enchant'  , 'handtohand' , 'heavyarmor', 'illusion'  , 'lightarmor', 'longblade', 'marksman'   , 'mediumarmor',
        'mercantile' , 'mysticism', 'restoration', 'security'  , 'shortblade', 'sneak'     , 'spear'    , 'speechcraft', 'unarmored'
    },
    scaler_groups = {
    SPELL = makeIndexEnum{'alteration', 'conjuration', 'destruction', 'illusion', 'mysticism', 'restoration'}
    WEAPON = makeIndexEnum{'axe', 'bluntweapon', 'longblade', 'marksman', 'shortblade', 'spear'} -- !! Weapon health gets reduced by *net* damage dealt.
    ARMOR = makeIndexEnum{'heavyarmor', 'lightarmor', 'mediumarmor'} -- !! Armor health gets reduced by the amount of incoming damage it *blocked*.
    },

    -- SCRIPT LOGIC VARIABLES
--     enteringLevelup = false
}

-- RETURN || NEED THIS SO FILE DO THING
return {Data = Data, Compat = Compat}
