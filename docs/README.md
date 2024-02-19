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
    - Toning down things that scale with themselves.
        > This goes back to the 1st section, but let's just say it's not surprising weapon skills increase fast.  
        > Not only do you use them a lot, but you also get more hits at higher skill levels, which results in more XP, which results in more levels...  
        > Weapon XP requirements are basically a flat constant diguised as a linear slope.  

- **Values in [brackets] indicate you can tweak them with a setting.**  


## TRACKABLE SKILLS

> All of these skills scale with their ideal variables.  
> They may receive balance tweaks, but are unlikely to change in core behavior.

#### Armor (Light/Medium/Heavy)

- [x] Armor XP scales positively with pre-mitigation damage received, and with current armor skill.  
    
    `  XP Multiplier = Damage/[6] * 60 / (30 + Skill)  `
    
    - You benefit little from getting hit by rats and other vermin.
    - Early armor levels are easier to get. Later ones harder.
    - Your Armor Rating / Armor Quality does not meaningfully affect XP rates, your _skill_ does.
      > There really isn't much more to say.. armor scaling is very clean. It _just works_.

#### Magic
- [x] Magic XP scales positively with Spell Cost, and less positively with Max MP.

    `  XP Multiplier = Spellcost/[9] *4.8 /(4 + xINT + FortifyMP/100)  `

    > Cast chance is not accounted for, and failing still gives zero XP. This is on purpose.  
    > If you have trouble casting use cheaper spells, it's what they're _actually_ meant for.

- There is an MP refund, and the formula is way too convoluted to explain here.  
    All you need to know is what follows:  
    - On default settings, refund starts at 15 skill and goes up to ~28% at 100.  
    - Refund keeps increasing after 100: you'll get ~33% at 150, 40% at 300, 43% at 600, etc. You'll never go over 50%.  
    - Half your total armor weight is deducted from your skill value when refund is calculated.  
        Can be disabled if you're already using another mod that adds an armor penalty. [Co.Re](https://www.nexusmods.com/morrowind/mods/53663) comes to mind.  
        > This CAN send "refunds" into the negative, if your armor is heavy enough or your skill is too low.  
        > Under normal gameplay, the resulting penalty shouldn't increase spell cost by more than 50%.  
    - Bigger spells get a smaller refund %, but will always result in more magicka recovered per spell cast.  
        > This gives pure mages a reason to use small spells, without punishing them for using large ones.  
        > Note that this also affects penalties from heavy armor..  
        > ..a smaller negative refund means a big spell's cost is _increased less_.  
 
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

## UNTRACKABLE SKILLS
> All of these skills scale with workaround or compromise variables.  
> They will get better scaling formulas as soon as Lua API support is added for the missing factors.

#### Weapon

- [x] Weapon XP scales posi-negatively with Weapon Skill isn't affected by Weapon Speed, and scales positively with net Damage Dealt (taken from item condition lost)  
    
    `  XP Multiplier = Damage/[10] / Weapon Speed * 80 /(40 + Skill)  `
    
    - XP per combat enocunter will be mainly determined by _enemy HP_ rather than by how a$$ your weapon's minimal damage is.
    - Weapon Skill is set as a divider, to stabilise the effect of hit chance on levling.  
        > This makes high levels not result in uberfast XP.  
        > Likewise, it also tones down the badness of missing a lot when skill is low.
    - All weapons level at the same rate regardless of attack speed
        > Yes, it's dividing in the formula. Don't get scared, all that does is neutralise it.  
    - Damage is counted before your difficulty settings are applied.
        > So the effect of difficulty (if any) on weapon leveling is the same as vanilla.
    - Condition lost only changes every 10 damage for weapons, unless you have changed a specific GMST.  
        > This makes the formula more a staircase than a line.  
        > This makes the formula not work when you're dealing less than 20 damage.  
        > ..a compromise was made and a different formula is used when you deal low damage, which averages weapon stats.
        - The ***S_U_S_Weapon-XP-Precision*** addon eliminates this issue almost completely.

- The ***S_U_S_Weapon-XP-Precision*** addon doubles weapon degradation speed, and doubles Armorer repair rates.
    - The addon is completely optional, but highly recommended, especially along [Weaponry of Resdayn Rebalanced](https://www.nexusmods.com/morrowind/mods/51247)
    - It makes Armorer field repairs more valuable, and increases the need to carry backup weapons.
    - It MASSIVELY reduces the number of cases where the alternate, compromised backup formula gets used.
        > It basically goes back to being a "Trackable Skill" if you have it.

#### Throwing

- [ ] Throwing XP scales with marksman level and average item damage.
