-- In a player script
local storage  = require('openmw.storage')
local settings = require('openmw.interfaces').Settings
local async    = require('openmw.async')
local ui       = require('openmw.ui')
local Dt       = require('scripts.Skill_Uses_Scaled.data')

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

local function get(svar) -- s in svar means serializable | Recursions WILL stack overflow :D
    if type(svar)  ~= 'table' then return svar
    else
        local deepcopy = {}
        for _key, _value in pairs(svar) do deepcopy[_key] = get(_value) end
        return deepcopy
    end
end

local Mui = {}

Mui.presets = {default = {}, custom = {}, current = {}}

Mui.SKILLS_MAP = makeKeyEnum(Dt.SKILLS)
Mui.toggles = {
  toggle_physical   = {'axe', 'bluntweapon', 'longblade', 'shortblade', 'spear', 'marksman', 'handtohand'}, --1~7
  toggle_magic      = {'alteration', 'conjuration', 'destruction', 'illusion', 'mysticism', 'restoration'}, --8~13
  toggle_armor      = {'heavyarmor', 'lightarmor', 'mediumarmor', 'block'}, --14~17
	toggle_refund     = {'MP_Refund_Skill_Offset', 'MP_Refund_Armor_mult', 'MP_Refund_Max_Percent'}
}

Mui.settingsGroups = {}
function addSettingsGroup(name)
	local groupid = "Settings_SUS_"..name
	Mui[groupid] = {}
	table.insert(Mui.settingsGroups, groupid)
end

settings.registerPage {
  key         = 'susconfig',
  l10n        = 'Skill_Uses_Scaled',
  name        = 'Skill Uses Scaled',
  description = 'Configure and toggle XP scaling based on the gameplay value of each skill use.\n All skills are configurable and can be toggled individually.\n Skills with similar behaviour are grouped together, for clarity and convenience.',
}

addSettingsGroup('magic')
settings.registerGroup {
  key              = 'Settings_SUS_magic',
  name             = 'Magic Schools',
  description      = 'Successful spell casts will give XP proportional to the spell\'s cost.\n Optional, but recommended, are the provided refund/penalty mechanics.',
  page             = 'susconfig',
  order            = 1,
  l10n             = 'Skill_Uses_Scaled',
  permanentStorage = false,
  settings         = {
    {
      key         = 'Magicka_to_XP',
      name        = 'Magicka to XP',
      description = 'How much spell cost is equivalent to one vanilla skill use.',
      renderer    = 'select',
      argument    = {l10n = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30, 100, 5))},
      default     = 9,
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
      argument    = {l10n = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1)  , num_range(30,100,5)), disabled = true},
      default     = 15,
    }, {
      key         = 'MP_Refund_Armor_mult',
      name        = 'Armor Penalty Offset',
      description = 'Magic skill is further reduced by [This]x[Equipped Armor Weight].\n If after all offsets your skill is still positive, you\'ll get a portion of the spell refunded, reducing spell cost. If the resulting number is negative, the "refund" will take extra magicka away instead, increasing spell cost.',
      renderer    = 'select',
      argument    = {l10n = 'Skill_Uses_Scaled', items = array_concat(num_range(.1,.9,.1), num_range(1,3,0.1))  , disabled = true},
			default     = 0.5,
    }, {
      key         = 'MP_Refund_Max_Percent',
      name        = 'Maximum Refund Percentage',
      description = 'Refund will never surpass [This]% of original spell cost. Note that this also affects armor penalties, if any.',
      renderer    = 'select',
      argument    = {l10n = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1)  , num_range(30,100,5)), disabled = true},
      default     = 50,
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

addSettingsGroup('physical')
settings.registerGroup {
  key              = 'Settings_SUS_physical',
  name             = 'Weapons and Hand To Hand',
  description      = 'Successful attacks will give XP proportional to their damage.\nDamaging enchantments on weapons are NOT counted, only the weapon\'s own damage (modified by Strength and Condition).',
  page             = 'susconfig',
  order            = 1,
  l10n             = 'Skill_Uses_Scaled',
  permanentStorage = false,
  settings         = {
    {
      key         = 'Physical_Damage_to_XP',
      name        = 'Damage to XP',
      description = 'How much outgoing damage is equivalent to one vanilla skill use.\n Not affected by enemy Armor Rating or by game difficulty.',
      renderer    = 'select',
      argument    = {l10n = 'Skill_Uses_Scaled',items = array_concat(num_range(1,25,1), num_range(30, 100, 5))},
      default     = 15,
    }, {
      key         = 'HandToHand_Strength',
      name        = 'Factor Strength into Hand to Hand',
      description = 'H2H damage is multiplied by [STR]/[This] when calculating XP.\n Default is same as OpenMW\'s.\n Set to 1 to disable.\n Does not affect Werewolves, since (due to how the game works) you don\'t get XP from attacking while in Werewolf form.',
      renderer    = 'select',
      argument    = {l10n = 'Skill_Uses_Scaled', items = array_concat(num_range(1,9,1), num_range(10, 100, 5))},
      default     = 40,
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

addSettingsGroup('armor')
settings.registerGroup {
  key              = 'Settings_SUS_armor',
  name             = 'Armor',
  description      = 'Hits taken will provide XP proportional to incoming damage.\n Like vanilla, this does NOT include damage from spells or magic effects.',
  page             = 'susconfig',
  order            = 2,
  l10n             = 'Skill_Uses_Scaled',
  permanentStorage = false,
  settings         = {
    {
      key         = 'Armor_Damage_To_XP',
      name        = 'Damage to XP',
      description = 'How much incoming damage is equivalent to one vanilla skill use.\n Not affected by your Armor Rating or by game difficulty.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30, 100, 5))},
      default     = 9,
    }, {
      key         = 'Block_Damage_To_XP',
      name        = 'Block - Damage to XP',
      description = 'How much blocked damage is equivalent to one vanilla skill use.\n Remember that blocked hits are prevented completely.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30, 100, 5))},
      default     = 9,
    }, 
    {key = 'toggle_armor', name = 'Enable Scaling for this Skill Group:', renderer = 'checkbox', default = 'true'}, 
    {key = 'heavyarmor'  , name = 'Heavy Armor'  , renderer = 'checkbox', default = 'true',}, 
    {key = 'mediumarmor' , name = 'Medium Armor' , renderer = 'checkbox', default = 'true',}, 
    {key = 'lightarmor'  , name = 'Light Armor'  , renderer = 'checkbox', default = 'true'}, 
    {key = 'block'       , name = 'Block'        , renderer = 'checkbox', default = 'true'},
  },
}

addSettingsGroup('unarmored ')
settings.registerGroup {
  key              = 'Settings_SUS_unarmored',
  name             = 'Unarmored',
  description      = 'Unarmored XP uses hit count instead of incoming damage, and rewards avoiding attacks instead of taking them.\n It was made this way for technical reasons, but the result is a good and viable defensive option for characters that can\'t take enough hits to justify an Armor skill, but would still like to enjoy a modicum of protection from weaker enemies.',
  page             = 'susconfig',
  order            = 3,
  l10n             = 'Skill_Uses_Scaled',
  permanentStorage = false,
  settings         = {
    {
      key         = 'Unarmored_Start',
      name        = 'Starting Multiplier',
      description = 'The first hit you take is equivalent to [This] many vanilla skill uses.\n This multiplier is drastically reduced on each consecutive hit.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.5,5,.25), num_range(6,15,1))},
      default     = 3,
    }, {
      key         = 'Unarmored_Decay_Time',
      name        = 'Penalty Timer',
      description = 'The Starting Multiplier is restored in [This] many seconds.\n The higher this is, the harder it is to keep XP rates high in long battles',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30,100,5), num_range(120,600,20))},
      default     = 30,
    }, {
      key         = 'Unarmored_Min',
      name        = 'Minimum Multiplier',
      description = 'The more you get hit, the closer the XP multiplier gets to [This] many vanilla skill uses.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(-1,1,.1), num_range(1.25,5,.25))},
      default     = 0.1,
    }, {
      key         = 'Unarmored_Armor_Mult',
      name        = 'Armor Weight Penalty Multiplier',
      description = 'Weight of equipped armor will slow down unarmored XP gain. Weight is multiplied by [This] before being added to the XP formula.\n This mechanic further encourages using Unarmored either by itself or along light armor.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(-1,1,.1), num_range(1.25,5,.25))},
      default     = 0.5,
--     }, {
--       key         = 'Unarmored_Beast_Races',
--       name        = 'Armored Beast Bonus',
--       description = 'When playing an Argonian or Khajiit, XP from hits to Head and Feet (if they are unarmored) will be multiplied by [This].\n This bonus is meant to mitigate the Armor Rating penalty for beast characters that run full armor sets, and has no effect on beast characters that don\'t use armor.',
--       renderer    = 'select',
--       argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(-1,1,.1), num_range(1.25,5,.25))},
--       default     = 6,
    }, 
    {key = 'unarmored', name = 'Enable scaling for Unarmored XP:', renderer = 'checkbox', default = 'true'},
  },
}

addSettingsGroup('acrobatics')
settings.registerGroup {
  key              = 'Settings_SUS_acrobatics',
  name             = 'Acrobatics',
  description      = 'Gain more XP for making larger, slower jumps, and progress faster while carrying little weight.\n Jumping up slopes will still result in significant (albeit reduced) skill progress, while fall damage and calculated jumps will no longer lag massively behind.',
  page             = 'susconfig',
  order            = 4,
  l10n             = 'Skill_Uses_Scaled',
  permanentStorage = false,
  settings         = {
    {
      key         = 'Acrobatics_Start',
      name        = 'Starting Multiplier',
      description = 'The first jump you make is equivalent to [This] many vanilla skill uses.\n This multiplier is reduced on each consecutive jump.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
      default     = 2,
    }, {
      key         = 'Acrobatics_Decay_Time',
      name        = 'Penalty Timer',
      description = 'The Starting Multiplier is restored in [This] many seconds. Increasing this number makes spam jumping even less valuable.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30,100,5), num_range(120,600,20))},
      default     = 5,
    }, {
      key         = 'Acrobatics_Encumbrance_Min',
      name        = 'Low Encumbrance Bonus',
      description = 'At 0% carry weight, your skill progress will be multiplied by [this].',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
      default     = 0.5,
    }, {
      key         = 'Acrobatics_Encumbrance_Max',
      name        = 'High Encumbrance Penalty',
      description = 'At 100% carry weight, your skill progress will be multiplied by [this].',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
      default     = 1.5,
    }, 
    {key = 'acrobatics', name = 'Enable scaling for Acrobatics XP:', renderer = 'checkbox', default = 'true'},
  },
}

addSettingsGroup('athletics')
settings.registerGroup {
  key              = 'Settings_SUS_athletics',
  name             = 'Athletics',
  description      = 'Gain more XP for running long periods of time, and progress faster while carrying heavy weights.\n Additionally, bad vanilla behaviour was fixed and you no longer gain athletics XP while jumping or flying. \n Bunnyhopping long distances is still a good training method, just not for raising Athletics.',
  page             = 'susconfig',
  order            = 5,
  l10n             = 'Skill_Uses_Scaled',
  permanentStorage = false,
  settings         = {
    {
      key         = 'Athletics_Start',
      name        = 'Starting Multiplier',
      description = 'Athletics XP is multiplied by a [Marathon Bonus]. This is the lowest it can get. \n Note that by default this is 0.5, meaning it cuts your XP in half when moving short distances and making long stops.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
      default     = 0.5,
    }, {
      key         = 'Athletics_Decay_Time',
      name        = 'Marathon Timer',
      description = 'It takes [This] many seconds of continuous running or swimming to reach the Maximum Multiplier.\n It\'s increase and decrease are gradual, so you can stop for a few seconds and you won\'t lose your entire progress.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(30,100,5), num_range(120,600,20), num_range(660,1200,60))},
      default     = 300,
    }, {
      key         = 'Athletics_Marathon',
      name        = 'Maximum Multiplier',
      description = 'Athletics XP is multiplied by a [Marathon Bonus]. This is the highest it can get.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
      default     = 2,
    }, {
      key         = 'Athletics_No_Move_Penalty',
      name        = 'No Movement Penalty',
      description = 'While not significantly moving (i.e, running or swimming into a wall), XP will be multiplied by [This].\n By default, it\'s low enough to make maxing the skill this way take very long, but still allows \'training\' AFK.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(-1,-0.1,0.1), num_range(-0.09,0.09,0.01), num_range(0.1,1,0.1))},
      default     = 0.01,
    }, {
      key         = 'Athletics_Encumbrance_Max',
      name        = 'High Encumbrance Bonus',
      description = 'At 100% carry weight, your skill progress will be multiplied by [this].',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
      default     = 1.5,
    }, {
      key         = 'Athletics_Encumbrance_Min',
      name        = 'Low Encumbrance Penalty',
      description = 'At 0% carry weight, your skill progress will be multiplied by [this].',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(.25,5,.25), num_range(6,15,1))},
      default     = 0.5,
    }, 
    {key = 'athletics', name = 'Enable scaling for Athletics XP:', renderer = 'checkbox', default = 'true'},
  },
}

addSettingsGroup('security')
settings.registerGroup {
  key              = 'Settings_SUS_security',
  name             = 'Security',
  description      = 'Successful lockpicking will grant XP based on the difficulty of the lock opened.\n Successful probing will grant XP based on the difficulty of the trap disarmed.',
  page             = 'susconfig',
  order            = 6,
  l10n             = 'Skill_Uses_Scaled',
  permanentStorage = false,
  settings         = {
    {
      key         = 'Security_Lock_Points_To_XP',
      name        = 'Lock Difficulty to XP',
      description = 'How many lock points are equivalent to one vanilla skill use.\n Not affected by tool quality.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30, 100, 5))},
      default     = 20,
    },    {
      key         = 'Security_Trap_Points_To_XP',
      name        = 'Trap Difficulty to XP',
      description = 'How many trap points are equivalent to one vanilla skill use.\n Not affected by tool quality.\n Note that trap difficulty is independent from lock difficulty, and directly based on the trap spell\'s magic cost. Hard traps are generally dangerous, and easy ones mostly harmless.',
      renderer    = 'select',
      argument    = {l10n  = 'Skill_Uses_Scaled', items = array_concat(num_range(1,25,1), num_range(30, 100, 5))},
      default     = 20,
    },
    {key = 'security', name = 'Enable scaling for Security XP:', renderer = 'checkbox', default = 'true'},
  },
}

addSettingsGroup('presets')
settings.registerGroup {
  key              = 'Settings_SUS_presets',
  name             = 'Settings Presets',
  description      = 'Pick from available config presets, or save your current settings as a new preset for later use.',
  page             = 'susconfig',
  order            = 0,
  l10n             = 'Skill_Uses_Scaled',
  permanentStorage = true,
  settings         = {
  },
}

addSettingsGroup('DEBUG')
settings.registerGroup {
  key              = 'Settings_SUS_SUS_DEBUG',
  name             = 'Info & Debug',
  description      = '',
  page             = 'susconfig',
  order            = 7,
  l10n             = 'Skill_Uses_Scaled',
  permanentStorage = false,
  settings         = {
    {
    key         = 'SUS_DEBUG', name = 'Enable Debug Messages', renderer = 'checkbox', default = false,
    description = 'Print information on every skill use about XP gained (and about this mod\'s multipliers) to the in-game F10 console.\n Useful for anyone wishing to hone in their configuration, or to get a general idea of this mod\'s (and vanilla morrowind\'s) XP mechanics.'
--     }, {
--     key = 'id', name = 'Use Verbose Messaging', renderer = 'checkbox', default = true,
--     description = 'Show fancy messageboxes directly to your screen instead of to the F10 console.\n Enabled by Default.\n Whether this is more or less intrusive than the F10 window is a matter of opinion.. disable it if you prefer the console.'
    },
  },
}

Mui.custom = function(group, key)
  if key == 'toggle_refund' then
    local args   = Mui.Settings_SUS_magic.args
    local offset = 'MP_Refund_Skill_Offset'
    local mult   = 'MP_Refund_Armor_mult'
    local max    = 'MP_Refund_Max_Percent'
    if Mui[group].section:get(key) then
      settings.updateRendererArgument(group, offset , edit_args(args[offset], {disabled = false}))
      settings.updateRendererArgument(group, mult   , edit_args(args[mult  ], {disabled = false}))
      settings.updateRendererArgument(group, max    , edit_args(args[max   ], {disabled = false}))
    else
      settings.updateRendererArgument(group, offset, edit_args(args[offset], {disabled = true}))
      settings.updateRendererArgument(group, mult  , edit_args(args[mult  ], {disabled = true}))
      settings.updateRendererArgument(group, max   , edit_args(args[max   ], {disabled = true}))
    end
  end
end

Mui.update = async:callback(function(group,key)
  if (not group) or (not key) then return
  elseif Mui.toggles[key] then
		local toggle = Mui[group].section:get(key)
    for _, setting in ipairs(Mui.toggles[key]) do
      settings.updateRendererArgument(group, setting, {disabled = toggle})
      print(setting..': '..tostring(Mui[group].section:get(setting)))
    end
  elseif Mui.SKILLS_MAP[key] then
    print(key..': '..tostring(Mui[group].section:get(key)))
  else
    Cfg[key] = Mui[group].section:get(key)
    if type(Cfg[key]) == 'number' then print(key..': '.. string.format('%.1f', Cfg[key]))
    else print(key..'| Cfg.enabled? '..tostring(Mui[group].section:get(key))..' | Cfg? '..tostring(Cfg[key]))
    end
  end
end)

Mui.GROUPS_MAP = {}
for _, groupid in ipairs(Mui.settingsGroups) do 
  Mui[groupid].section = storage.playerSection(groupid)
  Mui[groupid].section:subscribe(Mui.update)
	for key in pairs(Mui[groupid].section:asTable) do 
		Mui.GROUPS_MAP[key] = Mui[groupid].section
	end
end

-- • Settings loading:
function loadSettings(current, target)
  for k in pairs(target) do
    if k ~= 'enabled' then
      current[k] = get(target[k])
    else
      for k2 in pairs(target.enabled) do
        current.enabled[k2] = get(target.enabled[k2])
      end
    end
  end  
end
function loadMissingSettings(current, target)
  for k in pairs(target) do
    if k ~= 'enabled' then
      if current[k] == nil then current[k] = get(target[k]) end
    else
      for k2 in pairs(target.enabled) do
        if current.enabled[k2] == nil then current.enabled[k2] = get(target.enabled[k2]) end
      end
    end
  end  
end     
      
function savePreset(name)
  local preset = {}
  for _, groupid in ipairs (Mui.settingsGroups) do
    local preset[groupid] = get(Mui[groupid])
  end
  --[[save section as "SUS_CustomPresets_"..name]]
end     
--  Saving:
-- • Default "standard" preset = initCfg
-- • onLoad, Cfg = Mui.Storage[Settings_SUS_Current].section:getAll
-- • onLoad, loadMissingSettings(Cfg, initCfg)
-- • onSave, Settings_SUS_Current].section = Cfg
-- Custom presets
-- • on preset save:
      
      
      
      
