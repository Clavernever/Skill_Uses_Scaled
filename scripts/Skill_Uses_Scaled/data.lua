local types = require('openmw.types')
local core  = require('openmw.core')

-- TOOLS
local function makeKeyEnum(keys)
local result = {}
for _, key in ipairs(keys) do
  result[key] = key
end
return result
end

setpreviousval = function(key, val)
    local oldval = false
    return function(self, newval)
        oldval = val
        val = newval
        self[key] = oldval
    end
end

local Dt = {
-- Player Data
    pc_held_spell = 'spellid',
    pc_equipped_armor_condition = {set_prevframe = setpreviousval('prevframe', {}) },
    pc_held_weapon_condition    = {set_prevframe = setpreviousval('prevframe', 0) },
    pc_marksman_weapon          = {set_prevframe = setpreviousval('prevframe', {itemid = 'id Not Assigned', object = 'object Not Assigned', condition = 0}), },
    pc_marksman_projectile      = {count = 0 ,itemid = 'id Not Assigned', object = 'object Not Assigned'},
    pc_level = 0,
-- Engine Data
    --ARMOR_SLOTS = {'Cuirass', 'Greaves', 'Helmet', 'LeftGauntlet', 'LeftPauldron', 'RightGauntlet', 'RightPauldron'}
    ARMOR_SLOTS = {
        [types.Armor.TYPE.Boots    ] = core.getGMST('iBootsWeight'   ),
        [types.Armor.TYPE.Cuirass  ] = core.getGMST('iCuirassWeight' ),
        [types.Armor.TYPE.Greaves  ] = core.getGMST('iGreavesWeight' ),
        [types.Armor.TYPE.Helmet   ] = core.getGMST('iHelmWeight'    ),
        [types.Armor.TYPE.LGauntlet] = core.getGMST('iGauntletWeight'),
        [types.Armor.TYPE.LPauldron] = core.getGMST('iPauldronWeight'),
        [types.Armor.TYPE.LBracer  ] = core.getGMST('iGauntletWeight'),
        [types.Armor.TYPE.RBracer  ] = core.getGMST('iGauntletWeight'),
        [types.Armor.TYPE.RGauntlet] = core.getGMST('iGauntletWeight'),
        [types.Armor.TYPE.RPauldron] = core.getGMST('iPauldronWeight'),
        [types.Armor.TYPE.Shield   ] = core.getGMST('iShieldWeight'  ),
    },
    ARMOR_SLOT_NAMES = {
        [types.Armor.TYPE.Boots    ] = 'Boots',
        [types.Armor.TYPE.Cuirass  ] = 'Cuirass',
        [types.Armor.TYPE.Greaves  ] = 'Greaves',
        [types.Armor.TYPE.Helmet   ] = 'Helmet',
        [types.Armor.TYPE.LGauntlet] = 'LGauntlet',
        [types.Armor.TYPE.LPauldron] = 'LPauldron',
        [types.Armor.TYPE.LBracer  ] = 'LBracer',
        [types.Armor.TYPE.RBracer  ] = 'RBracer',
        [types.Armor.TYPE.RGauntlet] = 'RGauntlet',
        [types.Armor.TYPE.RPauldron] = 'RPauldron',
        [types.Armor.TYPE.Shield   ] = 'Shield',
    },
    ARMOR_RATING_WEIGHTS= {
        [types.Armor.TYPE.Cuirass  ] = 0.3 ,
        [types.Armor.TYPE.Shield   ] = 0.1 ,
        [types.Armor.TYPE.Helmet   ] = 0.1 ,
        [types.Armor.TYPE.Greaves  ] = 0.1 ,
        [types.Armor.TYPE.Boots    ] = 0.1 ,
        [types.Armor.TYPE.LPauldron] = 0.1 ,
        [types.Armor.TYPE.RPauldron] = 0.1 ,
        [types.Armor.TYPE.LGauntlet] = 0.05,
        [types.Armor.TYPE.RGauntlet] = 0.05,
        [types.Armor.TYPE.LBracer  ] = 0.05,
        [types.Armor.TYPE.RBracer  ] = 0.05,
    },
    GMST = {
        iBaseArmorSkill     = core.getGMST('iBaseArmorSkill'    ),
        fWeaponDamageMult   = core.getGMST('fWeaponDamageMult'  ),
        fDamageStrengthMult = core.getGMST('fDamageStrengthMult'),
        fDamageStrengthBase = core.getGMST('fDamageStrengthBase'),
        fLightMaxMod        = core.getGMST('fLightMaxMod'       ),
        fMedMaxMod          = core.getGMST('fMedMaxMod'         ),
        fUnarmoredBase1     = core.getGMST('fUnarmoredBase1'    ),
        fUnarmoredBase2     = core.getGMST('fUnarmoredBase2'    ),
        iBlockMaxChance     = core.getGMST('iBlockMaxChance'    ),
        iBlockMinChance     = core.getGMST('iBlockMinChance'    ),
        
    },
    ATTRIBUTES = {'strength', 'intelligence', 'willpower', 'agility', 'speed', 'endurance', 'personality', 'luck'},
    SKILLS = {
        'acrobatics' , 'alchemy'  , 'alteration' , 'armorer'   , 'athletics' , 'axe'       , 'block'    , 'bluntweapon', 'conjuration',
        'destruction', 'enchant'  , 'handtohand' , 'heavyarmor', 'illusion'  , 'lightarmor', 'longblade', 'marksman'   , 'mediumarmor',
        'mercantile' , 'mysticism', 'restoration', 'security'  , 'shortblade', 'sneak'     , 'spear'    , 'speechcraft', 'unarmored'
    },
    scaler_groups = {
        SPELL        = {'alteration', 'conjuration', 'destruction', 'illusion', 'mysticism', 'restoration'},
        MELEE_WEAPON = {'axe', 'bluntweapon', 'longblade', 'shortblade', 'spear'}, -- !! Weapon health gets reduced by *net* damage dealt.
        ARMOR        = {'heavyarmor', 'lightarmor', 'mediumarmor'}, -- !! Armor health gets reduced by the amount of incoming damage it *blocked*.
    },
    STANCES = {nothing = 0, magic = 1, physical  = 2},
    scalers = {
        default = {func = function(xp) return xp end},
        new = function(self, t) end-- t = {name = skillid, func = function(xp) dosomething return xp end}
    },
    -- SCRIPT LOGIC VARIABLES
    has_precision_addon = false,
    recent_activations = {},
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
