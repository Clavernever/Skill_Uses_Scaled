local types = require('openmw.types')
local time  = require('openmw_aux.time')
local core  = require('openmw.core')

-- TOOLS
local makecounter = function(val)
    local count = val
    return function(mod)
        count = count + mod
        return count
    end
end

local function makeKeyEnum(keys)
local result = {}
for _, key in ipairs(keys) do
  result[key] = key
end
return result
end

local function setpreviousval(key, val)
    local oldval = val
    return function(self, newval)
        self[key] = oldval
        oldval = newval
    end
end

local function printify(num) return math.floor(num*100 + 0.5)/100 end

local function make_atkspeed_meter()
    local simseconds = function() return core.getSimulationTime() - (core.getSimulationTime() % 0.01 * time.second) end
    local last    = simseconds()
    local current = simseconds()
    local atkspd  = 0
    return function()
        current = simseconds()
--         print('Attackspeed: '.. printify(1/(current - last))) --- core.getGameTime() % time.second - start)
        atkspd = 1/(current - last)
        last = current
        return atkspd
    end
end

local function get(var) -- var must be serializable, recursions WILL stack overflow :D
    if type(var)  ~= 'table' then return var
    else
        local deepcopy = {}
        for _key, _value in pairs(var) do deepcopy[_key] = get(_value) end
        return deepcopy
    end
end

local Dt = {
-- Player Data
    pc_held_spell = 'spellid',
    pc_equipped_armor_condition = {set_prevframe = setpreviousval('prevframe', {}) },
    pc_held_weapon_condition    = 0,  --{set_prevframe = setpreviousval('prevframe', 0) },
    pc_bow    = {itemid = '_id', object = '_obj', condition = 0}, --{set_prevframe = setpreviousval('prevframe', {itemid = '_id', object = '_obj', condition = 0}), },
    pc_ammo   = '_obj', --Always points directly at an object. -- Currently unused, since bow/crossbow durability loss includes ammo damage.
    pc_thrown = '_obj', --Same as ammo, but we keep track separately because they can be simultaneously equipped (even though thrown weapons are always their own ammo)
    pc_level = 0,
-- Engine Data
    WEAPON_TYPES = {
        MELEE = {
            [types.Weapon.TYPE.AxeOneHand       ] = 'axe'        ,
            [types.Weapon.TYPE.AxeTwoHand       ] = 'axe'        ,
            [types.Weapon.TYPE.BluntOneHand     ] = 'bluntweapon',
            [types.Weapon.TYPE.BluntTwoClose    ] = 'bluntweapon',
            [types.Weapon.TYPE.BluntTwoWide     ] = 'bluntweapon',
            [types.Weapon.TYPE.LongBladeOneHand ] = 'longblade'  ,
            [types.Weapon.TYPE.LongBladeTwoHand ] = 'longblade'  ,
            [types.Weapon.TYPE.ShortBladeOneHand] = 'shortblade' ,
            [types.Weapon.TYPE.SpearTwoWide     ] = 'spear'      ,
        },
        BOW = {
            [types.Weapon.TYPE.MarksmanBow      ] = 'marksman'   ,
            [types.Weapon.TYPE.MarksmanCrossbow ] = 'marksman'   ,
        },
        AMMO = {
            [types.Weapon.TYPE.Bolt             ] = 'marksman'   ,
            [types.Weapon.TYPE.Arrow            ] = 'marksman'   ,
        },
        THROWING = {
            [types.Weapon.TYPE.MarksmanThrown   ] = 'marksman'   ,
        },
    },
    -- CHECK TYPE WHEN USING THESE, THEY CAN HAVE THINGS OF OTHER TYPES
    SLOTS = {
        WEAPON   = get(types.Actor.EQUIPMENT_SLOT.CarriedRight),
        MELEE    = get(types.Actor.EQUIPMENT_SLOT.CarriedRight),
        BOW      = get(types.Actor.EQUIPMENT_SLOT.CarriedRight),
        THROWING = get(types.Actor.EQUIPMENT_SLOT.CarriedRight),
        AMMO     = get(types.Actor.EQUIPMENT_SLOT.Ammunition  ),
        SHIELD   = get(types.Actor.EQUIPMENT_SLOT.CarriedLeft ),
        ARMOR    = { 
            get(types.Actor.EQUIPMENT_SLOT.Boots        ),
            get(types.Actor.EQUIPMENT_SLOT.CarriedLeft  ),
            get(types.Actor.EQUIPMENT_SLOT.Cuirass      ),
            get(types.Actor.EQUIPMENT_SLOT.Greaves      ),
            get(types.Actor.EQUIPMENT_SLOT.Helmet       ),
            get(types.Actor.EQUIPMENT_SLOT.LeftGauntlet ),
            get(types.Actor.EQUIPMENT_SLOT.LeftPauldron ),
            get(types.Actor.EQUIPMENT_SLOT.RightGauntlet),
            get(types.Actor.EQUIPMENT_SLOT.RightPauldron),
        },
    },
    ARMOR_TYPES = {
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
    ARMOR_TYPE_NAMES = { -- unused at the moment
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
        iBaseArmorSkill      = core.getGMST('iBaseArmorSkill'     ),
        fWeaponDamageMult    = core.getGMST('fWeaponDamageMult'   ),
        fDamageStrengthMult  = core.getGMST('fDamageStrengthMult' ),
        fDamageStrengthBase  = core.getGMST('fDamageStrengthBase' ),
        fLightMaxMod         = core.getGMST('fLightMaxMod'        ),
        fMedMaxMod           = core.getGMST('fMedMaxMod'          ),
        fUnarmoredBase1      = core.getGMST('fUnarmoredBase1'     ),
        fUnarmoredBase2      = core.getGMST('fUnarmoredBase2'     ),
        iBlockMaxChance      = core.getGMST('iBlockMaxChance'     ),
        iBlockMinChance      = core.getGMST('iBlockMinChance'     ),
        fMaxHandToHandMult   = core.getGMST('fMaxHandToHandMult'  ),
        fMinHandToHandMult   = core.getGMST('fMinHandToHandMult'  ),
        fHandtoHandHealthPer = core.getGMST('fHandtoHandHealthPer'),
        fMinWalkSpeed        = core.getGMST('fMinWalkSpeed'       ), -- Currently unused, could be made to affect athletics formula but it seemed too convoluted.
        fMaxWalkSpeed        = core.getGMST('fMaxWalkSpeed'       ), -- Same as previous, I aired on using a flat speed multiplier instead.
        fEncumbranceStrMult  = core.getGMST('fEncumbranceStrMult' ),
    },
    GLOB = {
    WerewolfClawMult = 0
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
    STANCE_WEAPON  = {[types.Actor.STANCE.Weapon ] = true},
    STANCE_SPELL   = {[types.Actor.STANCE.Spell  ] = true},
    STANCE_NOTHING = {[types.Actor.STANCE.Nothing] = true},
    scalers = {
        default = {func = function(xp) return xp end},
        new = function(self, t) end-- t = {name = skillid, func = function(xp) dosomething return xp end}
    },
    -- SCRIPT LOGIC VARIABLES
    has_precision_addon = false,
    recent_activations = {},
    attackspeed = {current = 0, update = function(self) self.current = self.meter() end, meter = make_atkspeed_meter()},
    equipment = nil,
    counters = {athletics = makecounter(0), acrobatics = makecounter(0)}
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
