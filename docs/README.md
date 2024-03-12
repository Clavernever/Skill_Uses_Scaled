## GENERAL FACTORS

- **Gains are usually balanced around some average early-midgame value.**  
    Here's the factors I balanced around:
  
    - Making the spammage of ultracheap 'training' options an unoptimal choice.  
        > 1 cost spells, 1 damage attacks, mudcrab struggle sessions.. you know the drill.  
    - Making the use of expensive options a rewarding choice.  
        > You shouldn't be punished for casting big spells, surviving big hits from scary enemies or dealing big damage, you should be rewarded for it.  
    - Keeping overall skill progression around non-exploitey speeds.  
        > Reward big things too much and you'll end up with accidental powerleveling.  
        > Nerf small things too hard and you end up with neverleveling..  
        > ..or worse, with expensive things being the only option.  
    - Skills that progress faster as they increase were weighted around midgame values to keep them both accessible and hard to max. The result should be a more balanced XP curve, more enjoyable and less exploitable from start to end, across all skills.

- **Values in [brackets] indicate you can tweak them with a setting.**  

#### Magic
- [x] Magic XP scales positively with Spell Cost, and less positively with Max MP.

    `  XP Multiplier = Spellcost/[9] * 4.8 /(4 + <MP over 100>/100)  `

    - Note that while large magicka pools will result in less XP _per spell_, they'll still result in more XP _per full magicka bar._
        > Cast chance is not accounted for, and failing still gives zero XP. This is on purpose.   
        > If you have trouble casting then use cheaper spells, it's what they're _actually_ meant for.

- [x] Dynamic Spell Cost: it's an optional feature, disabled by default but highly recommended if you like Oblivion's and Skyrim's spell cost mechanics, where costs decrease at as you become proficcient and increase while wearing heavy gear.  
    The formula is way too convoluted to explain here, but here's the gist of it:  
    - On default settings, you get up to ~28% of spell cost refunded at 100 magic skill.  
    - Refund keeps increasing after 100 (in case you have fortified your skill or use a skill uncapper): you'll get ~33% at 150, 40% at 300, 43% at 600, etc. You'll never go over 50%.  
    - Half your total armor weight is deducted from your skill value when Dynamic Cost is calculated.  
        Can be disabled if you're already using another mod that adds an armor penalty. [Co.Re](https://www.nexusmods.com/morrowind/mods/53663) comes to mind.  
        > If the resulting skill value is under zero (due to heavy armor and a low spellcasting skill), the spell's cost will be _increased_ instead.  
        > Under normal gameplay, the resulting penalty shouldn't increase spell cost by more than 50%.  
    - Bigger spells are less affected by Dynamic Cost, both for discounts and penalties, but still benefit/suffer from them.  
        > This gives pure mages a reason to use small spells, without punishing them for using large ones.  
        > Likewise, mages in heavy armor will want to use the largest spells they can, to pay a smaller premium in penalties.

#### Physical Attacks (Melee and Ranged weapons, as well as Hand to Hand)

- [x] Physical XP scales with your outgoing Physical damage.
    
    `  XP Multiplier = Damage/[15] * 80 /(40 + Skill)  `
    
    - XP per combat enocunter will be mainly determined by _enemy HP_ rather than by how a$$ your weapon's minimal damage is.
    - Like with Armor, damage is counted before your difficulty slider takes effect.
        > So the effect of difficulty (if any) on weapon leveling is the same as vanilla.  
    - Any enchantments on your weapons do not contribute to your leveling progress.
        > When enchanting scaling is added, weapon enchantments will be used there.  
    - Hand to Hand additionally has a setting to let you factor in Strength.
        > It's toggled on by default and you should disable it only if you don't use the 'Strength affects Hand to Hand' option in the launcher.  
        > It does not affect Werewolves, as the game doesn't give any H2H experience when in werewolf form.  

#### Armor (Light/Medium/Heavy) and Block

- [x] Armor and Block XP scale with pre-mitigation damage received.  
    
    `  XP Multiplier = Damage/[9] * 60 / (30 + Skill)  `
    
    - You benefit little from getting hit by rats and other vermin.
    - Your Armor Rating / Armor Quality does not meaningfully affect XP rates, but of course surviving more damage will result in more XP.
      > There really isn't much more to say.. armor scaling is very clean. It _just works_.

#### Unarmored

- [x] Unarmored XP scales positively with not getting hit and negatively with armor weight.  

    `  XP Multiplier = 100 / (35 + rating + skill + [armor weight]) * ([3 - 0.1] / (2 * <Hits taken in the last [30] seconds>) + [0.1])  `

    - Due to mechanical limitations Unarmored, unlike Armor skills, does _not_ scale with damage taken.  
        Instead, you get more XP per hit the least you've been hit within a 30 second window.
        > This means unarmored is a viable defensive skill for mages and assassins that prefer to avoid damage rather than resist it.  
        > In vanilla, this kind of gameplay results in such low amounts of experience that, despite unarmored being a magic skill, you can never meaningfully progress without trainers.  
        > Now it will actually level at a decent rate if you don't get hit very often.  
        > On the reverse, armor is a better choice if you intend to be hit a lot.  
    - Armor Weight slows down Unarmored progress.
        > You can do with mixing some light armor in, such as a shield.  
        > You should avoid combining unarmored with heavy armor.  
        > They're opposite sides of a spectrum, and aren't meant to be used together.  

#### Acrobatics

- [x] Acrobatics XP scales with current encumbrance ratio and with long sessions of running.

    `  XP Multiplier = ([1.5] + [0.5 - 1.5] * Encumbrance%) * 2/ (1 + <Jumps in the last [5] seconds>/2)  `

    - You get more XP while light on your feet.
    - You benefit more from calculated jumps, and less from spam jumping up hills.
        > These two factors together encourage you to actually _play_ as an agile character if you intend to raise acrobatics.

#### Athletics

- [x] Acrobatics XP scales with current encumbrance ratio and with long sessions of running.

    `  XP Multiplier = ([0.5] + [1.5 - 0.5] * Encumbrance%) * ([0.5] + [2 - 0.5] * <seconds running>/[300])

    - Running for extended periods of time rewards more experience. (<seconds running> caps at 300)
    - You gain _more_ Athletics XP when heavily encumbered.
        > These two factors together encourage the use of Athletics for characters that rely on heavy gear, since they will both get more experience from running and run for longer periods of time (due to weight making them run slower). 
    - You no longer get experience while flying or jumping.
        > This makes Athletics mutually exclusive with jumping as a means of transportaion.
    - Your experience rate gets multiplied by [0.01] if you're not meaningfully moving.
        > This makes running into a wall still _viable_ as an athletics training method, but it's no longer a super free 100.

#### Security

- [x] Security scales with the difficulty of the target lock or trap.
    
    `  XP Multiplier = Difficulty/[20]  `
    
    - Difficulty is lock level when lockpicking, and trap spell cost while probing.
    - Opening big locks and disarming dangerous traps rewards large amounts of XP.
        > Likewise, opening 1pt locks is usually more trouble than it's worth.  
        > You can still use lock spells to train security, but you're encouraged to use larger lock spells for it.

### TODO: These are in the planning stage, and have not been implemented yet:

#### Enchanting

- Enchanting XP scales with different things for each of it's uses:
    - [ ] Soul Size for item enchants
    - [ ] Points Recharged for Soulgem-Based Recharging  
        > Note you don't get any XP from passive recovery. This is on purpose.
    - [ ] Points Spent for Item Uses

#### Alchemy

- [ ] Alchemy XP scales Alchemy Skill and with the combined value and weight of all items consumed.

   `  XP Multiplier = (Ingr.Value + 10*Ingr.Weight + 20) / 80 + 80/(40 + Skill)  `

    - Alchemy Skill is a divider.  
        > This is to tone down the effect of getting more potions from any given amount of ingredients.
    - Rewards spending expensive ingredients instead of selling them.
    - Rewards you for actually bothering to use heavy ingredients, which are more cumbersome to get and make more cumbersome potions.
    - Tones down XP from easily gathered/purchased ingredients.
    - More ingredients means more Value, means more XP. As it should.  
        > Now you can make 4 ingredient superpotions and not feel wasteful for doing the objectively cool thing.
