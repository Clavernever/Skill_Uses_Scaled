## GENERAL FACTORS
- **More Success Chance usually means less XP per success, but still more XP in general.** Some examples:  
    _# More Max MP means less XP per Magic Point spent, but still more XP per full MP bar spent_  
    _# Higher Weapon Skill and Strength both result in less XP per damage point, but the DPS increase from both still results in faster leveling (just not as fast as vanilla dagger spam)._  
    _# Higher Alchemy means less XP per potion, but the increase in brewing success chance still makes high alchemy give more total XP per ingredients spent  (just not as much as vanilla)._
- **Gains are usually balanced around some average early-midgame value.** Here's the fatcors I balanced around:  
    _# Making the spammage of ultracheap 'training' options an unoptimal choice._  
        > 1 cost spells, 1 damage attacks, getting hit by rats.. you know the drill.  
    _# Making the use of expensive options a rewarding choice._  
        > You shouldn't be punished for casting big spells, surviving big hits from scary enemies, dealing big damage, etc.  
    _# Keeping overall skill progression around non-exploitey speeds._  
        > Reward big things too much and you'll end up with accidental powerleveling.
        > Nerf small things too hard and you end up with neverleveling..
        > ..or worse, with expensive things being the only option.
        > This would just be the previous situation reversed.
        > I'm not interested in working dozens of hours just to make a different flavour of the same problem.

    _# Toning down things that scale with themselves._
        > This goes back to the 1st section, but let's just say it's not surprising weapon skills increase fast.
        > Not only do you use them a lot but you also get more hits at higher skill levels, which results in more hits which results in higher levels.
        > Weapon XP requirements are basically a flat constant diguised as a linear slope.

## TRACKABLE SKILLS
> All of these skills scale with their ideal variables.
> They may receive balance tweaks, but are unlikely to change in core behavior.

#### Armor
- [ ] Armor XP scales with Max HP, Base AR and amount of damage prevented (taken from item condition lost).
    -  On the base AR point specifically, the middle ground should be somewhere around 25 damage  
      # Where less than 25 damage favours low ARs, and more than 25 favours high ARs.  
      # This should help make leveling armor easier early on, and make light armors harder to max in the lategame.

#### Weapon
- [ ] Weapon XP scales with Weapon Skill, Strength and net damage dealt (taken from item condition lost)  
    # Weapon Skill and Strength are dividers.  
        This is to balance the fact that weapons get more hits at high skill values, and deal more damage per hit at high strength values.  
    # Condition Loss = NetDamage * \[fWeaponDamageMult->0.1\]  
        This means Strength factors directly into it, and so does enemy armor reduction.  
        As a result, XP will be mainly determined by _enemy HP_ rather than by how a$$ your weapon's minimal damage is.

#### Magic
- [ ] Magic XP scales with Max MP, MP spent and cast chance.
    \# Spells with low cast chances give more XP to compensate for the fact your MP is not refunded on fail.  
    \# Detailed formula ahead.

#### Enchanting
- Enchanting XP scales with different things for each of it's uses:
    - [ ] Soul Size for item enchants
    - [ ] Points Recharged for Soulgem-Based Recharging  
         \# Note you don't get any XP from passive recovery. This is on purpose.
    - [ ] Points Spent for Item Uses

#### Alchemy
- Alchemy XP scales with the value of all items 

## UNTRACKABLE SKILLS
> All of these skills scale with workaround or compromise variables.
> The will get better scaling formulas as soon as Lua API support is added for the missing factors.

#### Throwing
- [ ] Throwing XP scales with marksman level and average item damage.
