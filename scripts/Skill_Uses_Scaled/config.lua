local Dt = require('scripts.Skill_Uses_Scaled.data')

-- CONFIGURATION
-----------------------------------------------------------------------------------------------------------
local Cfg = {}

Cfg.Magicka_to_XP          =  9 --> [This] much magicka is equivalent to one vanilla spellcast.

Cfg.MP_Refund_Skill_Offset = 15 --> [This] much magic skill is deducted on refund calculation.
                                -- | The resulting skill value CAN BE NEGATIVE, and you'll get EXTRA COST instead of a refund.
Cfg.MP_Refund_Armor_Mult  = 0.5 --> [This] number times your Armor Weight is added to your Skill Offset.
Cfg.MP_Refund_Max_Percent = 50  --> Refund will never go above [this] Percentage of spell cost. I strongly advice you never set [this] above [100].
                                -- | Due to how offsets work, this also affects penalties from heavy armor.

Cfg.Armor_Damage_To_XP = 9 --> [This] much pre-mitigation physical damage is equivalent to one vanilla armor hit. Roughly.
Cfg.Block_Damage_To_XP = 9 --> [This] much pre-mitigation physical damage is equivalent to one vanilla block hit. Roughly.

Cfg.Physical_Damage_to_XP = 15 --> [This] much physical damage is equivalent to one vanilla hit. Roughly.
                               -- | All Melee and Ranged weapons, as well as Hand to Hand, use this setting.
Cfg.HandToHand_Strength = 40 --> Hand to Hand xp per hit is multiplied by STR * [this]. Set [this] to 1 if you want to disable it.
                             -- The default 1/40 means at 40 STR you deal vanilla damage, at 80 2x as much, at 100 2.5x etc
                             -- The default is what OpenMW's "Factor strength into hand-to-hand combat" setting uses.
Cfg.H2H_STR_Werewolves = false --> If this is true, Cfg.HandToHand_Strength will affect your xp as a werewolf.

                                -- ALL OF THE FOLLOWING TIMERS ARE IN "REAL" SECONDS AND IGNORE WAIT/REST ACTIONS.
Cfg.Unarmored_Armor_Mult  = 0.5 --> [This] number times your Armor Weight is added to your Unarmored Skill when calculating XP.
                                -- | Note that since skills level slower the higher they get, lighter armor / no armor will always result in better XP rates.
Cfg.Unarmored_Start       = 3   --> Unarmored XP is multiplied by [This], and divided by [Recent Hits Taken]. Only enemy PHYSICAL attacks count for this formula, magic damage doesn't.
                                -- |This results in Unarmored XP being frontloaded, which encourages it's use for mages and rogues that want a defensive skill but can't take enough hits to meaninfully progress an armor skill.
Cfg.Unarmored_Min         = 0.1 --> The hit-based multiplier can't go below this number.
Cfg.Unarmored_Decay_Time  = 30  --> [This] many seconds have to pass for a hit taken to stop reducing Unarmored XP gained from following hits.
-- Cfg.Unarmored_Beast_Races = 6   --> Unarmored levels [this] times faster when you're an armor-clad Argonian or Khajiit. It's for your head and feetsies.
                                -- | Only applies if you've got 3 or less empty slots (counting shield). Bonus is divided among those empty slots.
                                -- | It's meant to make the heavy handicap from not being able to equip head and feet armor less bad, if you're running an armored character.
                                -- | It's NOT meant to help, and will NOT affect, fully unarmored characters. Unarmored beast characters level the same as all others.
Cfg.Acrobatics_Start      = 1.5 --> Acrobatics XP is multiplied by [This], and divided by [Recent Jumps]. The internal formula a lot more generous than the one used for Unarmored, as it's only meant to tone down spam jumping up hills.
Cfg.Acrobatics_Decay_Time = 5   --> [This] many seconds have to pass for an Acrobatics skill use to have no effect on XP from further uses.
Cfg.Acrobatics_Encumbrance_Max = 0.5 --> At full carry weight, your skill progress will be multiplied by [this].
Cfg.Acrobatics_Encumbrance_Min = 1.5 --> At empty carry weight, your skill progress will be multiplied by [this].
                                     -- | Acrobatics is a Stealth skill, and this favours staying light an nimble.

Cfg.Athletics_Start      = 0.5 --> Athletics XP is multiplied by [This] when you begin running after a long period of inactivity.
Cfg.Athletics_Marathon   = 2   --> Athletics XP increases gradually as you run around, up to [This] times it's normal rate.
Cfg.Athletics_Decay_Time = 300 --> You have to run for [This] many seconds to reach the Marathon multiplier, and stay idle the same amount of time for the it to be cleared back to Start.
                               -- | In the multiplier goes up and down gradually, you won't lose your bonus for staying still a few seconds, now will you keep marathon rates by tapping forwards every couple seconds.
Cfg.Athletics_No_Move_Penalty = 0.01 --> When not ACTUALLY MOVING, your Athletics XP will be multiplied by this. You can still leave your character running into a wall and benefit, but you'll benefit roughly [This] times as much.
Cfg.Athletics_Encumbrance_Max = 1.5  --> At full carry weight, your skill progress will be multiplied by [this].
Cfg.Athletics_Encumbrance_Min = 0.5  --> At empty carry weight, your skill progress will be multiplied by [this].
                                     -- | Athletics is a Combat skill, and this favours carrying heavy gear into battle.

Cfg.Security_Lock_Points_To_XP = 20 --> [This] many lock points are equivalent of one vanilla Security use (vanilla triggers a use whenever you open a lock of any level).
Cfg.Security_Trap_Points_To_XP = 20 --> [This] much trap spell cost is equivalent to one vanilla Security use (vanilla triggers a use whenever you open a lock of any level).
                                    -- | Trap difficulty is equivalent to it's spell cost.

Cfg.SUS_DEBUG   = true  -- You can use this too if you're not a modder! A message will be printed to your F10 window every time a skill is used, with helpful data.
Cfg.SUS_VERBOSE = false -- | You can use these messages to fine-tune your settings if something feels off.
                        -- | READ THE README FIRST! Some numbers will make a lot more sense if you know the logic behind them.
                        -- | Also, remember this is always on top of your load order's XP values.
                        -- | If you have another mod that changes XP rates, be sure to check their changes as well.
-----------------------------------------------------------------------------------------------------------

local function makeKeyEnum(keys) local result = {} for _, key in ipairs(keys) do result[key] = true end return result end
Cfg.SKILLS_MAP = makeKeyEnum(Dt.SKILLS)

Cfg.enabled = {}
for k in pairs(Cfg.SKILLS_MAP) do Cfg.enabled[k] = Cfg.SKILLS_MAP[k] end
Cfg.enabled.toggle_refund = false

Cfg.group_toggles = {
    toggle_physical   = {'axe', 'bluntweapon', 'longblade', 'shortblade', 'spear', 'marksman', 'handtohand'}, --1~7
    toggle_magic      = {'alteration', 'conjuration', 'destruction', 'illusion', 'mysticism', 'restoration'}, --8~13
    toggle_armor      = {'heavyarmor', 'lightarmor', 'mediumarmor', 'block'}, --14~17
    toggle_other      = {'armorer', 'enchant', 'alchemy', 'sneak', 'speechcraft', 'mercantile'}, --18~27
}
Cfg.custom = {
    toggle_refund = true,
}
Cfg.toggle = function(skillid, toggle)
    if toggle then Cfg.enabled[skillid] = true
    else Cfg.enabled[skillid] = false
    end
end


-- RETURN || NEED THIS SO FILE DO THING
return Cfg
