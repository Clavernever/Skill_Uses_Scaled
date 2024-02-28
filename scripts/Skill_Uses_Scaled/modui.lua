-- In a player script
local storage = require('openmw.storage')
local settings = require('openmw.interfaces').Settings
local async  = require('openmw.async')
local ui = require('openmw.ui')
local Cfg = require('scripts.Skill_Uses_Scaled.config')
local Dt = require('scripts.Skill_Uses_Scaled.data')

local function num_range(min, max, step) -- " Why have I done this "
    if math.abs(step) < 0.0001 then print('SUS: step must not be between -0.0001 and 0.0001') return nil end
    local num_range = {}
    digits = {tostring(step):find('%.(%d*)')}
    if not digits[3] then digits[3] = '' end
    digits = '%.'..#tostring(digits[3])..'f'
    for i=min, max, step do table.insert(num_range, 0 + string.format(digits, tostring(i))) end
    return num_range
end

local function array_concat(array, ...)
    for _, t in ipairs({...}) do
        for _, v in ipairs(t) do table.insert(array, v) end
    end
    return array
end

local function makeKeyEnum(keys) local result = {} for _, key in ipairs(keys) do result[key] = true end return result end

local function edit_args(base, changes) for k, v in pairs(changes) do base[k] = v end return base end


local Mui = {}

Mui.presets = {prebuilt = {standard = {}}, custom = {}}

Mui.SKILLS_MAP = makeKeyEnum(Dt.SKILLS)
Mui.group_toggles = {
    toggle_physical   = {'axe', 'bluntweapon', 'longblade', 'shortblade', 'spear', 'marksman', 'handtohand'}, --1~7
    toggle_magic      = {'alteration', 'conjuration', 'destruction', 'illusion', 'mysticism', 'restoration'}, --8~13
    toggle_armor      = {'heavyarmor', 'lightarmor', 'mediumarmor', 'block'}, --14~17
    toggle_other      = {'armorer', 'enchant', 'alchemy', 'sneak', 'speechcraft', 'mercantile'}, --18~27
}
Mui.custom_keys = {
    toggle_refund = true,
}
Mui.toggle = function(skillid, toggle)
    if toggle then Cfg.enabled[skillid] = true
    else Cfg.enabled[skillid] = false
    end
end


settings.registerPage {
    key = 'susconfig',
    l10n = 'Skill_Uses_Scaled',
    name = 'Skill Uses Scaled',
    description = 'Configure and toggle XP scaling based on the gameplay value of each skill use.\n All skills are configurable and can be toggled individually.\n Skills with similar behaviour are grouped together, for clarity and convenience.',
}

Mui.Settings_SUS_magic = {}
Mui.Settings_SUS_magic.args = {
    MP_Refund_Skill_Offset = {l10n = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1)  , num_range(30,100,5)), disabled = true},
    MP_Refund_Armor_mult   = {l10n = 'Skill_Uses_Scaled', items = array_concat(num_range(.1,.9,.1), num_range(1,3,0.1))  , disabled = true},
    MP_Refund_Max_Percent  = {l10n = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1)  , num_range(30,100,5)), disabled = true},
}
settings.registerGroup {
    key         = 'Settings_SUS_magic',
    name        = 'Magic Schools',
    description = 'Successful spell casts will give XP proportional to the spell\'s cost.\n Optional, but recommended, are the provided refund/penalty mechanics.',
    page        = 'susconfig',
    order       = 1,
    l10n        = 'Skill_Uses_Scaled',
    permanentStorage = false,
    settings = {
        {
            key         = 'Magicka_to_XP',
            name        = 'Magicka to XP',
            description = 'How much spell cost is equivalent to one vanilla skill use.',
            renderer    = 'select',
            argument    = {l10n = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30, 100, 5))},
            default     = Cfg.Magicka_to_XP,
        }, {
            key         = 'toggle_refund',
            name        = 'Dynamic Spell Cost',
            description = 'Toggling this on will make your spell\'s cost change depending on your gear and skill level, akin to spellcasting in Oblivion and Skyrim. High skill and no armor will result in a refund, while heavy armor and low skill will incur a penalty. Only applies on successful spellcasts.',
            renderer    = 'checkbox',
            default     = false,
        }, {
            key         = 'MP_Refund_Skill_Offset',
            name        = 'Magic Refund Skill Offset',
            description = 'Magic skill is reduced by [This] for the calculation of Dynamic Spell Cost',
            renderer    = 'select',
            argument    = Mui.Settings_SUS_magic.args.MP_Refund_Skill_Offset,
            default     = Cfg.MP_Refund_Skill_Offset,
        }, {
            key         = 'MP_Refund_Armor_mult',
            name        = 'Armor Penalty Offset',
            description = 'Magic skill is further reduced by [This]x[Equipped Armor Weight].\n If after all offsets your skill is still positive, you\'ll get a portion of the spell refunded, reducing spell cost. If the resulting number is negative, the "refund" will take extra magicka away instead, increasing spell cost.',
            renderer    = 'select',
            argument    = Mui.Settings_SUS_magic.args.MP_Refund_Armor_mult,
            default     = Cfg.MP_Refund_Armor_Mult,
        }, {
            key         = 'MP_Refund_Max_Percent',
            name        = 'Maximum Refund Percentage',
            description = 'Refund will never surpass [This]% of original spell cost. Note that this also affects armor penalties, if any.',
            renderer    = 'select',
            argument    = Mui.Settings_SUS_magic.args.MP_Refund_Max_Percent,
            default     = Cfg.MP_Refund_Max_Percent,
        },
        {key = 'toggle_magic', name = 'Enable XP Scaling for this Skill Group:', renderer = 'checkbox', default = 'true' },
        {key = 'alteration'  , name = 'Alteration' , renderer = 'checkbox', default = 'true'},
        {key = 'conjuration' , name = 'Conjuration', renderer = 'checkbox', default = 'true'},
        {key = 'destruction' , name = 'Destruction', renderer = 'checkbox', default = 'true'},
        {key = 'illusion'    , name = 'Illusion'   , renderer = 'checkbox', default = 'true'},
        {key = 'mysticism'   , name = 'Mysticism'  , renderer = 'checkbox', default = 'true'}, 
        {key = 'restoration' , name = 'Restoration', renderer = 'checkbox', default = 'true'},
    },
}

Mui.Settings_SUS_physical = {}
settings.registerGroup {
    key         = 'Settings_SUS_physical',
    name        = 'Weapons and Hand To Hand',
    description = 'Successful attacks will give XP proportional to their damage.\nDamaging enchantments on weapons are NOT counted, only the weapon\'s own damage (modified by Strength and Condition).',
    page        = 'susconfig',
    order       = 1,
    l10n        = 'Skill_Uses_Scaled',
    permanentStorage = false,
    settings = {
        {
            key         = 'Physical_Damage_to_XP',
            name        = 'Damage to XP',
            description = 'How much outgoing damage is equivalent to one vanilla skill use.\n Not affected by enemy Armor Rating or by game difficulty.',
            renderer    = 'select',
            argument    = {l10n = 'Skill_Uses_Scaled',items = array_concat(num_range(1,25,1), num_range(30, 100, 5))},
            default     = Cfg.Physical_Damage_to_XP,
        }, {
            key         = 'HandToHand_Strength',
            name        = 'Factor Strength into Hand to Hand',
            description = 'H2H damage is multiplied by [STR]/[This] when calculating XP.\nDefault is same as OpenMW\'s.\nSet to 1 to disable.',
            renderer    = 'select',
            argument    = {l10n = 'Skill_Uses_Scaled', items = array_concat(num_range(1,9,1), num_range(10, 100, 5))},
            default     = Cfg.HandToHand_Strength,
        }, {
            key         = 'H2H_STR_Werewolves',
            name        = 'Factor Strength for Werewolf Claw Damage',
            description = 'Whether STR affects Werewolf bonus damage as well.',
            renderer    = 'checkbox',
            default     = Cfg.H2H_STR_Werewolves,
        }, 
        {key = 'toggle_physical', name = 'Enable XP Scaling for this Skill Group:', renderer = 'checkbox', default = 'true',}, 
        {key = 'axe'            , name = 'Axe'         , renderer = 'checkbox', default = 'true'},
        {key = 'bluntweapon'    , name = 'Blunt Weapon', renderer = 'checkbox', default = 'true'},
        {key = 'longblade'      , name = 'Long Blade'  , renderer = 'checkbox', default = 'true'},
        {key = 'shortblade'     , name = 'Short Blade' , renderer = 'checkbox', default = 'true'},
        {key = 'spear'          , name = 'Spear'       , renderer = 'checkbox', default = 'true'},
        {key = 'marksman'       , name = 'Marksman'    , renderer = 'checkbox', default = 'true'}, 
        {key = 'handtohand'     , name = 'Hand To Hand', renderer = 'checkbox', default = 'true'},
    },
}

Mui.Settings_SUS_armor = {}
settings.registerGroup {
    key         = 'Settings_SUS_armor',
    name        = 'Armor',
    description = 'Hits taken will provide XP proportional to incoming damage.\n Like vanilla, this does NOT include damage from spells or magic effects.',
    page        = 'susconfig',
    order       = 2,
    l10n        = 'Skill_Uses_Scaled',
    permanentStorage = false,
    settings = {
        {
            key         = 'Armor_Damage_To_XP',
            name        = 'Damage to XP',
            description = 'How much incoming damage is equivalent to one vanilla skill use.\n Not affected by your Armor Rating or by game difficulty.',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30, 100, 5))},
            default     = Cfg.Armor_Damage_To_XP,
        }, {
            key         = 'Block_Damage_To_XP',
            name        = 'Block - Damage to XP',
            description = 'How much blocked damage is equivalent to one vanilla skill use.\n Remember that blocked hits are prevented completely.',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30, 100, 5))},
            default     = Cfg.Block_Damage_To_XP,
        }, 
        {key = 'toggle_armor', name = 'Enable Scaling for this Skill Group:', renderer = 'checkbox', default = 'true'}, 
        {key = 'heavyarmor'  , name = 'Heavy Armor'  , renderer = 'checkbox', default = 'true',}, 
        {key = 'mediumarmor' , name = 'Medium Armor' , renderer = 'checkbox', default = 'true',}, 
        {key = 'lightarmor'  , name = 'Light Armor'  , renderer = 'checkbox', default = 'true'}, 
        {key = 'block'       , name = 'Block'        , renderer = 'checkbox', default = 'true'},
    },
}

Mui.Settings_SUS_unarmored = {}
settings.registerGroup {
    key         = 'Settings_SUS_unarmored',
    name        = 'Unarmored',
    description = 'Unarmored XP uses hit count instead of incoming damage, and rewards avoiding attacks instead of taking them.\n It was made this way for technical reasons, but the result is a good and viable defensive option for characters that can\'t take enough hits to justify an Armor skill, but would still like to enjoy a modicum of protection from weaker enemies.',
    page        = 'susconfig',
    order       = 3,
    l10n        = 'Skill_Uses_Scaled',
    permanentStorage = false,
    settings = {
        {
            key         = 'Unarmored_Start',
            name        = 'Starting Multiplier',
            description = 'The first hit you take is equivalent to [This] many vanilla skill uses.\n This multiplier is drastically reduced on each consecutive hit.',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.5,5,.25), num_range(6,15,1))},
            default     = Cfg.Unarmored_Start,
        }, {
            key         = 'Unarmored_Decay_Time',
            name        = 'Penalty Timer',
            description = 'The Starting Multiplier is restored in [This] many seconds.\n The higher this is, the harder it is to keep XP rates high in long battles',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30,100,5), num_range(120,600,20))},
            default     = Cfg.Unarmored_Decay_Time,
        }, {
            key         = 'Unarmored_Min',
            name        = 'Minimum Multiplier',
            description = 'The more you get hit, the closer the XP multiplier gets to [This] many vanilla skill uses.',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(-1,1,.1), num_range(1.25,5,.25))},
            default     = Cfg.Unarmored_Min,
--         }, {
--             key         = 'Unarmored_Beast_Races',
--             name        = 'Armored Beast Bonus',
--             description = 'When playing an Argonian or Khajiit, XP from hits to Head and Feet (if they are unarmored) will be multiplied by [This].\n This bonus is meant to mitigate the Armor Rating penalty for beast characters that run full armor sets, and has no effect on beast characters that don\'t use armor.',
--             renderer    = 'select',
--             argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(-1,1,.1), num_range(1.25,5,.25))},
--             default     = Cfg.Unarmored_Beast_Races,
        }, 
        {key = 'unarmored', name = 'Enable scaling for Unarmored XP:', renderer = 'checkbox', default = 'true'},
    },
}

Mui.Settings_SUS_acrobatics = {}
settings.registerGroup {
    key         = 'Settings_SUS_acrobatics',
    name        = 'Acrobatics',
    description = 'Gain more XP for making larger, slower jumps, and progress faster while carrying little weight.\n Jumping up slopes will still result in significant (albeit reduced) skill progress, while fall damage and calculated jumps will no longer lag massively behind.',
    page        = 'susconfig',
    order       = 4,
    l10n        = 'Skill_Uses_Scaled',
    permanentStorage = false,
    settings = {
        {
            key         = 'Acrobatics_Start',
            name        = 'Starting Multiplier',
            description = 'The first jump you make is equivalent to [This] many vanilla skill uses.\n This multiplier is reduced on each consecutive jump.',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
            default     = Cfg.Acrobatics_Start,
        }, {
            key         = 'Acrobatics_Decay_Time',
            name        = 'Penalty Timer',
            description = 'The Starting Multiplier is restored in [This] many seconds. Increasing this number makes spam jumping even less valuable.',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30,100,5), num_range(120,600,20))},
            default     = Cfg.Acrobatics_Decay_Time,
        }, {
            key         = 'Acrobatics_Encumbrance_Min',
            name        = 'Low Encumbrance Bonus',
            description = 'At 0% carry weight, your skill progress will be multiplied by [this].',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
            default     = Cfg.Acrobatics_Encumbrance_Min,
        }, {
            key         = 'Acrobatics_Encumbrance_Max',
            name        = 'High Encumbrance Penalty',
            description = 'At 100% carry weight, your skill progress will be multiplied by [this].',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
            default     = Cfg.Acrobatics_Encumbrance_Max,
        }, 
        {key = 'acrobatics', name = 'Enable scaling for Acrobatics XP:', renderer = 'checkbox', default = 'true'},
    },
}

Mui.Settings_SUS_athletics = {}
settings.registerGroup {
    key         = 'Settings_SUS_athletics',
    name        = 'Athletics',
    description = 'Gain more XP for running long periods of time, and progress faster while carrying heavy weights.\n Additionally, bad vanilla behaviour was fixed and you no longer gain athletics XP while jumping or flying. \n Bunnyhopping long distances is still a good training method, just not for raising Athletics.',
    page        = 'susconfig',
    order       = 5,
    l10n        = 'Skill_Uses_Scaled',
    permanentStorage = false,
    settings = {
        {
            key         = 'Athletics_Start',
            name        = 'Starting Multiplier',
            description = 'Athletics XP is multiplied by a [Marathon Bonus]. This is the lowest it can get. \n Note that by default this is 0.5, meaning it cuts your XP in half when moving short distances and making long stops.',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
            default     = Cfg.Athletics_Start,
        }, {
            key         = 'Athletics_Decay_Time',
            name        = 'Marathon Timer',
            description = 'It takes [This] many seconds of continuous running or swimming to reach the Maximum Multiplier.\n It\'s increase and decrease are gradual, so you can stop for a few seconds and you won\'t lose your entire progress.',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(30,100,5), num_range(120,600,20), num_range(660,1200,60))},
            default     = Cfg.Athletics_Decay_Time,
        }, {
            key         = 'Athletics_Marathon',
            name        = 'Maximum Multiplier',
            description = 'Athletics XP is multiplied by a [Marathon Bonus]. This is the highest it can get.',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
            default     = Cfg.Athletics_Marathon,
        }, {
            key         = 'Athletics_No_Move_Penalty',
            name        = 'No Movement Penalty',
            description = 'While not significantly moving (i.e, running or swimming into a wall), XP will be multiplied by [This].\n By default, it\'s low enough to make maxing the skill this way take very long, but still allows \'training\' AFK.',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(-1,-0.1,0.1), num_range(-0.09,0.09,0.01), num_range(0.1,1,0.1))},
            default     = Cfg.Athletics_No_Move_Penalty,
        }, {
            key         = 'Athletics_Encumbrance_Max',
            name        = 'High Encumbrance Bonus',
            description = 'At 100% carry weight, your skill progress will be multiplied by [this].',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
            default     = Cfg.Athletics_Encumbrance_Max,
        }, {
            key         = 'Athletics_Encumbrance_Min',
            name        = 'Low Encumbrance Penalty',
            description = 'At 0% carry weight, your skill progress will be multiplied by [this].',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
            default     = Cfg.Athletics_Encumbrance_Min,
        }, 
        {key = 'athletics', name = 'Enable scaling for Athletics XP:', renderer = 'checkbox', default = 'true'},
    },
}

Mui.Settings_SUS_security = {}
settings.registerGroup {
    key         = 'Settings_SUS_security',
    name        = 'Security',
    description = 'Successful lockpicking will grant XP based on the difficulty of the lock opened.\n Successful probing will grant XP based on the difficulty of the trap disarmed.',
    page        = 'susconfig',
    order       = 6,
    l10n        = 'Skill_Uses_Scaled',
    permanentStorage = false,
    settings = {
        {
            key         = 'Security_Lock_Points_To_XP',
            name        = 'Lock Difficulty to XP',
            description = 'How many lock points are equivalent to one vanilla skill use.\n Not affected by tool quality.',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30, 100, 5))},
            default     = Cfg.Security_Lock_Points_To_XP,
        },        {
            key         = 'Security_Trap_Points_To_XP',
            name        = 'Trap Difficulty to XP',
            description = 'How many trap points are equivalent to one vanilla skill use.\n Not affected by tool quality.\n Note that trap difficulty is independent from lock difficulty, and directly based on the trap spell\'s magic cost. Hard traps are generally dangerous, and easy ones mostly harmless.',
            renderer    = 'select',
            argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30, 100, 5))},
            default     = Cfg.Security_Trap_Points_To_XP,
        },
        {key = 'security', name = 'Enable scaling for Security XP:', renderer = 'checkbox', default = 'true'},
    },
}

Mui.Settings_SUS_presets = {}
settings.registerGroup {
    key         = 'Settings_SUS_presets',
    name        = 'Settings Presets',
    description = 'Pick from available config presets, or save your current settings as a new preset for later use.',
    page        = 'susconfig',
    order       = 0,
    l10n        = 'Skill_Uses_Scaled',
    permanentStorage = true,
    settings = {
    },
}

Mui.Settings_SUS_SUS_DEBUG = {}
settings.registerGroup {
    key         = 'Settings_SUS_SUS_DEBUG',
    name        = 'Info & Debug',
    description = '',
    page        = 'susconfig',
    order       = 7,
    l10n        = 'Skill_Uses_Scaled',
    permanentStorage = false,
    settings = {
        {
        key = 'SUS_DEBUG', name = 'Enable Debug Messages', renderer = 'checkbox', default = false,
        description = 'Print information on every skill use about XP gained (and about this mod\'s multipliers) to the in-game F10 console.\n Useful for anyone wishing to hone in their configuration, or to get a general idea of this mod\'s (and vanilla morrowind\'s) XP mechanics.'
--         }, {
--         key = 'id', name = 'Use Verbose Messaging', renderer = 'checkbox', default = true,
--         description = 'Show fancy messageboxes directly to your screen instead of to the F10 console.\n Enabled by Default.\n Whether this is more or less intrusive than the F10 window is a matter of opinion.. disable it if you prefer the console.'
        },
    },
}



Mui.custom = function(group, key)
    if key == 'toggle_refund' then
        local args = Mui.Settings_SUS_magic.args
        local offset = 'MP_Refund_Skill_Offset'
        local mult = 'MP_Refund_Armor_mult'
        local max = 'MP_Refund_Max_Percent'
        if Mui[group].section:get(key) then
            Mui.toggle('toggle_refund', true)
            settings.updateRendererArgument(group, offset , edit_args(args[offset], {disabled = false}))
            settings.updateRendererArgument(group, mult   , edit_args(args[mult  ], {disabled = false}))
            settings.updateRendererArgument(group, max    , edit_args(args[max   ], {disabled = false}))
        else
            Mui.toggle('toggle_refund', nil)
            settings.updateRendererArgument(group, offset, edit_args(args[offset], {disabled = true}))
            settings.updateRendererArgument(group, mult  , edit_args(args[mult  ], {disabled = true}))
            settings.updateRendererArgument(group, max   , edit_args(args[max   ], {disabled = true}))
        end
    end
end

Mui.update = async:callback(function(group,key)
    if (not group) or (not key) then return
    elseif Mui.group_toggles[key] then
        for _, _skill in ipairs(Mui.group_toggles[key]) do
            if Mui[group].section:get(key) then
                Mui.toggle(_skill, Mui[group].section:get(_skill))
                settings.updateRendererArgument(group, _skill, {disabled = false})
            else
                Mui.toggle(_skill, nil)
                settings.updateRendererArgument(group, _skill, {disabled = true})
            end
            print(_skill..': '..tostring(Cfg.enabled[_skill]))
        end
    elseif Mui.custom_keys[key] then
        Mui.custom(group, key)
        print(key..'| Cfg.enabled? '..tostring(Cfg.enabled[key])..' | Cfg? '..tostring(Cfg[key]))
    elseif Mui.SKILLS_MAP[key] then
        Mui.toggle(key, Mui[group].section:get(key))
        print(key..': '..tostring(Cfg.enabled[key]))
    else
        Cfg[key] = Mui[group].section:get(key)
        if type(Cfg[key]) == 'number' then print(key..': '.. string.format('%.1f', Cfg[key]))
        else print(key..'| Cfg.enabled? '..tostring(Cfg.enabled[key])..' | Cfg? '..tostring(Cfg[key]))
        end
    end
end)

for _, name in ipairs{'physical', 'magic', 'armor', 'unarmored', 'acrobatics', 'athletics', 'security', 'SUS_DEBUG'} do --, 'presets'
    local id = 'Settings_SUS_'..name
    if Mui[id] then
        Mui[id].section = storage.playerSection(id)
        Mui[id].section:subscribe(Mui.update)
    else print(id..' section is in the storage register list but not in the script tables.')
    end
end

-- for k in pairs(initCfg) do
--     if k ~= 'enabled' then
--         if Cfg[k] == nil then Cfg[k] = initCfg[k] end
--     else
--         for k in pairs(initCfg.enabled) do
--             if Cfg.enabled[k] == nil then Cfg.enabled[k] = initCfg.enabled[k] end
--         end
--     end
-- end
