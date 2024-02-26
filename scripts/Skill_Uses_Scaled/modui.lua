-- In a player script
local storage = require('openmw.storage')
local settings = require('openmw.interfaces').Settings
local async  = require('openmw.async')
local ui = require('openmw.ui')
local Cfg = require('scripts.Skill_Uses_Scaled.config')
local Dt = require('scripts.Skill_Uses_Scaled.data')

local function num_range(min, max, step)
    local num_range = {}
    for i=min, max, step do table.insert(num_range, i) end
    return num_range
end
local function deep_insert(t1, t2, pos)
    if pos then for i, v in ipairs(t1) do table.insert(t1, (pos - 1) + i, t2[i]) end
    else for i, v in ipairs(t1) do table.insert(t1, t2[i]) end
    end
    return t1
end
local function multi_deep_insert(t)
    for i=1, #t - 1, 1 do deep_insert(t[1], t[i+1]) end
    return t[1]
end
local function edit_args(base, changes) for k, v in pairs(changes) do base[k] = v end return base end
settings.registerPage {
    key = 'susconfig',
    l10n = 'Skill_Uses_Scaled',
    name = 'Skill Uses Scaled',
    description = 'Configure and toggle XP scaling based on the gameplay value of each skill use.\n All skills are configurable and can be toggled individually.\n Skills with similar behaviour are grouped together, for clarity and convenience.',
}



Mui = {}
Mui.settings = {
    new = function(self, t)
        self[t.name] = t.name
        return self[t.name]
    end
}

local pc_cfg = {}


pc_cfg.Settings_SUS_magic = {}
pc_cfg.Settings_SUS_magic.args = {
    MP_Refund_Skill_Offset = {
                l10n = 'Skill_Uses_Scaled',
                items = deep_insert(num_range(1,25,1), num_range(30, 100, 5)),
                disabled = true,
                },
    MP_Refund_Armor_mult = {
                l10n = 'Skill_Uses_Scaled',
                items = deep_insert(num_range(0.1, 0.9, 0.1), num_range(1, 3, 0.1)),
                disabled = true,
                },
    MP_Refund_Max_Percent = {
                l10n = 'Skill_Uses_Scaled',
                items = deep_insert(num_range(1,25,1), num_range(30, 100, 5)),
                disabled = true,
                },
}

settings.registerGroup {
    key = 'Settings_SUS_magic',
    name = 'Magic Schools',
    description = 'Successful spell casts will give XP proportional to the spell\'s cost.\n Optional, but recommended, are the provided refund/penalty mechanics.',
    page = 'susconfig',
    order = 1,
    l10n = 'Skill_Uses_Scaled',
    permanentStorage = false,
    settings = {
        {
            key = 'Magicka_to_XP',
            name = 'Magicka to XP',
            description = 'How much spell cost is equivalent to one vanilla skill use.',
            renderer = 'select',
            argument = {
                l10n = 'Skill_Uses_Scaled',
                items = deep_insert(num_range(1,25,1), num_range(30, 100, 5))
                },
            default = Cfg.Magicka_to_XP,
        }, {
            key = 'toggle_refund',
            name = 'Dynamic Spell Cost',
            description = 'Toggling this on will make your spell\'s cost change depending on your gear and skill level, akin to spellcasting in Oblivion and Skyrim. High skill and no armor will result in a refund, while heavy armor and low skill will incur a penalty. Only applies on successful spellcasts.',
            renderer = 'checkbox',
            default = false,
        }, {
            key = 'MP_Refund_Skill_Offset',
            name = 'Magic Refund Skill Offset',
            description = 'Magic skill is reduced by [This] for the calculation of Dynamic Spell Cost',
            renderer = 'select',
            argument = pc_cfg.Settings_SUS_magic.args.MP_Refund_Skill_Offset,
            default = Cfg.MP_Refund_Skill_Offset,
        }, {
            key = 'MP_Refund_Armor_mult',
            name = 'Armor Penalty Offset',
            description = 'Magic skill is further reduced by [This]x[Equipped Armor Weight].\n If after all offsets your skill is still positive, you\'ll get a portion of the spell refunded, reducing spell cost. If the resulting number is negative, the "refund" will take extra magicka away instead, increasing spell cost.',
            renderer = 'select',
            argument = pc_cfg.Settings_SUS_magic.args.MP_Refund_Armor_mult,
            default = Cfg.MP_Refund_Armor_Mult,
        }, {
            key = 'MP_Refund_Max_Percent',
            name = 'Maximum Refund Percentage',
            description = 'Refund will never surpass [This]% of original spell cost. Note that this also affects armor penalties, if any.',
            renderer = 'select',
            argument = pc_cfg.Settings_SUS_magic.args.MP_Refund_Max_Percent,
            default = Cfg.MP_Refund_Max_Percent,
        }, {
            key = 'toggle_magic',
            name = 'Enable Scaling for this Skill Group:',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'alteration',
            name = 'Alteration',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'conjuration',
            name = 'Conjuration',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'destruction',
            name = 'Destruction',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'illusion',
            name = 'Illusion',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'mysticism',
            name = 'Mysticism',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'restoration',
            name = 'Restoration',
            renderer = 'checkbox',
            default = 'true',
        },
    },
}

pc_cfg.Settings_SUS_physical = {}

settings.registerGroup {
    key  = 'Settings_SUS_physical',
    name = 'Weapons and Hand To Hand',
    description = 'Successful attacks will give XP proportional to their damage.\nDamaging enchantments on weapons are NOT counted, only the weapon\'s own damage (modified by Strength and Condition).',
    page = 'susconfig',
    order = 1,
    l10n = 'Skill_Uses_Scaled',
    permanentStorage = false,
    settings = {
        {
            key = 'Physical_Damage_to_XP',
            name = 'Damage to XP',
            description = 'How much outgoing damage is equivalent to one vanilla skill use.\n Not affected by enemy Armor Rating or by game difficulty.',
            renderer = 'select',
            argument = {
                l10n = 'Skill_Uses_Scaled',
                items = deep_insert(num_range(1,25,1), num_range(30, 100, 5)),
                },
            default = Cfg.Physical_Damage_to_XP,
        }, {
            key = 'HandToHand_Strength',
            name = 'Factor Strength into Hand to Hand',
            description = 'H2H damage is multiplied by [STR]/[This] when calculating XP.\nDefault is same as OpenMW\'s.\nSet to 1 to disable.',
            renderer = 'select',
            argument = {
                l10n = 'Skill_Uses_Scaled',
                items = deep_insert(num_range(1,9,1), num_range(10, 100, 5)),
                },
            default = Cfg.HandToHand_Strength,
        }, {
            key = 'H2H_STR_Werewolves',
            name = 'Factor Strength for Werewolf Claw Damage',
            description = 'Whether STR affects Werewolf bonus damage as well.',
            renderer = 'checkbox',
            default = Cfg.H2H_STR_Werewolves,
        }, {
            key = 'toggle_physical',
            name = 'Enable Scaling for this Skill Group:',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'axe',
            name = 'Axe',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'bluntweapon',
            name = 'Blunt Weapon',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'longblade',
            name = 'Long Blade',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'shortblade',
            name = 'Short Blade',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'spear',
            name = 'Spear',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'marksman',
            name = 'Marksman',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'handtohand',
            name = 'Hand To Hand',
            renderer = 'checkbox',
            default = 'true',
        },
    },
}

pc_cfg.Settings_SUS_armor = {}

settings.registerGroup {
    key = 'Settings_SUS_armor',
    name = 'Armor',
    description = 'Hits taken will provide XP proportional to incoming damage.\n Like vanilla, this does NOT include damage from spells or magic effects.',
    page = 'susconfig',
    order = 2,
    l10n = 'Skill_Uses_Scaled',
    permanentStorage = false,
    settings = {
        {
            key = 'Armor_Damage_To_XP',
            name = 'Damage to XP',
            description = 'How much incoming damage is equivalent to one vanilla skill use.\n Not affected by your Armor Rating or by game difficulty.',
            renderer = 'select',
            argument = {
                l10n = 'Skill_Uses_Scaled',
                items = deep_insert(num_range(1,25,1), num_range(30, 100, 5)),
                },
            default = Cfg.Armor_Damage_To_XP,
        }, {
            key = 'Block_Damage_To_XP',
            name = 'Block - Damage to XP',
            description = 'How much blocked damage is equivalent to one vanilla skill use.\n Remember that blocked hits are prevented completely.',
            renderer = 'select',
            argument = {
                l10n = 'Skill_Uses_Scaled',
                items = deep_insert(num_range(1,25,1), num_range(30, 100, 5)),
                },
            default = Cfg.Block_Damage_To_XP,
        }, {
            key = 'toggle_armor',
            name = 'Enable Scaling for this Skill Group:',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'heavyarmor',
            name = 'Heavy Armor',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'mediumarmor',
            name = 'Medium Armor',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'lightarmor',
            name = 'Light Armor',
            renderer = 'checkbox',
            default = 'true',
        }, {
            key = 'block',
            name = 'Block',
            renderer = 'checkbox',
            default = 'true',
        },
    },
}

pc_cfg.custom = function(group, key)
    if key == 'toggle_refund' then
        local args = pc_cfg.Settings_SUS_magic.args
        local offset = 'MP_Refund_Skill_Offset'
        local mult = 'MP_Refund_Armor_mult'
        local max = 'MP_Refund_Max_Percent'
        if pc_cfg[group].section:get(key) then
            Cfg.toggle('refund', true)
            settings.updateRendererArgument(group, offset , edit_args(args[offset], {disabled = false}))
            settings.updateRendererArgument(group, mult   , edit_args(args[mult  ], {disabled = false}))
            settings.updateRendererArgument(group, max    , edit_args(args[max   ], {disabled = false}))
        else
            Cfg.toggle('refund', nil)
            settings.updateRendererArgument(group, offset, edit_args(args[offset], {disabled = true}))
            settings.updateRendererArgument(group, mult  , edit_args(args[mult  ], {disabled = true}))
            settings.updateRendererArgument(group, max   , edit_args(args[max   ], {disabled = true}))
        end
    end
end

pc_cfg.update = async:callback(function(group,key)
    if (not group) or (not key) then return
    elseif Cfg.group_toggles[key] then
        for _, _skill in ipairs(Cfg.group_toggles[key]) do
            if pc_cfg[group].section:get(key) then
                Cfg.toggle(_skill, pc_cfg[group].section:get(_skill))
                settings.updateRendererArgument(group, _skill, {disabled = false})
            else
                Cfg.toggle(_skill, nil)
                settings.updateRendererArgument(group, _skill, {disabled = true})
            end
            print(_skill..': '..tostring(Cfg.enabled[_skill]))
        end
    elseif Cfg.custom[key] then
        pc_cfg.custom(group, key)
    elseif Cfg.SKILLS_MAP[key] then
        Cfg.toggle(key, pc_cfg[group].section:get(key))
        print(key..': '..tostring(Cfg.enabled[key]))
    else
        Cfg[key] = pc_cfg[group].section:get(key)
        if type(Cfg[key]) == 'number' then print(key..': '.. string.format('%.1f', Cfg[key]))
        else print(key..'| Cfg.enabled? '..tostring(Cfg.enabled[key])..' | Cfg? '..tostring(Cfg[key]))
        end
    end
end)

for _, name in ipairs{'physical', 'magic', 'armor'} do
    local id = 'Settings_SUS_'..name
    pc_cfg[id].section = storage.playerSection(id)
    pc_cfg[id].section:subscribe(pc_cfg.update)
end
