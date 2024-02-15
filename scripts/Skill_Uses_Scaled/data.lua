local skp   = require('openmw.interfaces').SkillProgression

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
    SPELL = {'alteration', 'conjuration', 'destruction', 'illusion', 'mysticism', 'restoration'}
    WEAPON = {'axe', 'bluntweapon', 'longblade', 'marksman', 'shortblade', 'spear'} -- !! Weapon health gets reduced by *net* damage dealt.
    ARMOR = {'heavyarmor', 'lightarmor', 'mediumarmor'} -- !! Armor health gets reduced by the amount of incoming damage it *blocked*.
    
    },
    scalers = {
        new = function(self, t) end, -- t = {name = 'skillid', handler = function(skillid, source, options) ~dostuff end}
    },
    -- SCRIPT LOGIC VARIABLES
--     enteringLevelup = false
}

-- SCALER CONSTRUCTOR

Data.scaler.skills:new = function (t)
    self[t.name] = skp.addSkillUsedHandler(t.name, t.handler)
end




-- RETURN || NEED THIS SO FILE DO THING
return {Data = Data, Compat = Compat}
