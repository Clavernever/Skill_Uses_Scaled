-- CONFIGURATION
-----------------------------------------------------------------------------------------------------------
local Cfg = {}

Cfg.Magicka_to_XP          =  9 -- [This] much magicka is equivalent to one vanilla spellcast.

Cfg.MP_Refund_Skill_Offset = 15 -- [This] much magic skill is deducted on refund calculation.
                                  -- | The resulting skill value CAN BE NEGATIVE, and you'll get EXTRA COST instead of a refund.
Cfg.MP_Refund_Armor_Mult  = 0.5 -- [This] number times your Armor Weight is added to your Skill Offset.
Cfg.MP_Refund_Max_Percent = 50  -- Refund will never go above [this] Percentage of spell cost. I strongly advice you never set [this] above [100].
                                  -- | Due to how offsets work, this also affects penalties from heavy armor.

Cfg.Unarmored_Armor_Mult  = 0.5 -- [This] number times your Armor Weight is added to your Unarmored Skill when calculating XP.
                                  -- | Note that since skills level slower the higher they get, lighter / no armor will always result in better XP rates.
Cfg.Unarmored_Hits_To_XP  = 3   -- Unarmored XP is multiplied by [this]/[hits] from enemy PHYSICAL attacks in the last [Cfg.Unarmored_Hit_Timer] seconds.
Cfg.Unarmored_Hit_Timer   = 60  -- [This] many seconds have to pass for a hit taken to stop reducing Unarmored XP gained from following hits.
Cfg.Unarmored_Beast_Races = 6   -- Unarmored levels [this] times faster when you're an armor-clad Argonian/Khajiit. It's for your head and feetsies.
                                  -- | Only applies if you've got 3 or less empty slots (counting shield). Bonus is divided among those empty slots.
                                  -- | It's meant to make the heavy handicap from not being able to equip head and feet armor less bad, if you're running an armored character.
                                  -- | It's NOT meant to help, and will NOT affect, fully unarmored characters. Unarmored beast characters level the same as all others.

Cfg.Armor_Damage_To_XP = 9 -- [This] much pre-mitigation physical damage is equivalent to one vanilla armor hit. Roughly.
Cfg.Block_Damage_To_XP = 9 -- [This] much pre-mitigation physical damage is equivalent to one vanilla block hit. Roughly.

Cfg.Weapon_Wear_Mult      = 2  -- Directly multiplies Vanilla durability loss. Only takes effect if you have S_U_S_Weapon-XP-Precision in your load order.
                                 -- | You'll always lose at least 1 durability per hit, even if you set [this] to 0.
Cfg.Physical_Damage_to_XP = 15 -- [This] much physical damage is equivalent to one vanilla hit. Roughly.
                                 -- | All Melee and Ranged weapons, as well as Hand to Hand, use this setting.
Cfg.HandToHand_Strength = 1/40 -- Hand to Hand xp per hit is multiplied by STR * [this]. Set [this] to 1 if you want to disable it.
                                 -- The default 1/40 means at 40 STR you deal vanilla damage, at 80 2x as much, at 100 2.5x etc
                                 -- The default is what OpenMW's "Factor strength into hand-to-hand combat" setting uses.
Cfg.H2H_STR_Werewolves = false -- If this is true, Cfg.HandToHand_Strength will affect your xp as a werewolf.

Cfg.Acrobatics_FP_Max = 3 -- With a full FP bar, your skill progress will be multiplied by [this].
Cfg.Acrobatics_FP_Min = 0 -- With an empty FP bar, your skill progress will be multiplied by [this].
                            -- | The multiplier goes down gradually, approaching FP_Min as your FP gets closer to empty.
Cfg.Acrobatics_Encumbrance_Max = 0.5 -- At full carry weight, your skill progress will be multiplied by [this].
Cfg.Acrobatics_Encumbrance_Min = 1.5 -- At empty carry weight, your skill progress will be multiplied by [this].
                                       -- | Acrobatics is a Stealth skill, and this favours staying light an nimble.

Cfg.Athletics_FP_Max = 3 -- With a full FP bar, your skill progress will be multiplied by [this].
Cfg.Athletics_FP_Min = 0 -- With an empty FP bar, your skill progress will be multiplied by [this].
                           -- | The multiplier goes down gradually, approaching FP_Min as your FP gets closer to empty.                                     -- | Acrobatics is a Stealth skill, and this favours staying light and agile.
Cfg.Athletics_Encumbrance_Max = 1.5 -- At full carry weight, your skill progress will be multiplied by [this].
Cfg.Athletics_Encumbrance_Min = 0.5 -- At empty carry weight, your skill progress will be multiplied by [this].
                                      -- | Athletics is a Combat skill, and this favours carrying heavy gear into battle.

Cfg.Security_Lock_Points_To_XP = 20 -- [This] many lock points are equivalent of one vanilla Security use (vanilla triggers a use whenever you open a lock of any level).
Cfg.Security_Trap_Points_To_XP = 20 -- [This] much trap spell cost is equivalent to one vanilla Security use (vanilla triggers a use whenever you open a lock of any level).
                                      -- | Trap difficulty is equivalent to it's spell cost.

Cfg.SUS_DEBUG = true -- You can use this too if you're not a modder! A message will be printed to your F10 window every time a skill is used, with helpful data.
                       -- | You can use these messages to fine-tune your settings if something feels off.
                       -- | READ THE README FIRST! Some numbers will make a lot more sense if you know the logic behind them.
                       -- | Also, remember this is always on top of your load order's XP values.
                       -- | If you have another mod that changes XP rates, be sure to check their changes as well.
-----------------------------------------------------------------------------------------------------------

-- RETURN || NEED THIS SO FILE DO THING
return Cfg
