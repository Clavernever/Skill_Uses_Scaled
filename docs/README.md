## GENERAL FACTORS

- **More Success Chance usually means less XP per success, but still more XP in general.**  
    Some examples:
  
    - More Max MP means less Spell School XP per magic point spent, but still more XP per full MP bar spent.
    - More Max HP means less Armor XP per point of damage taken, but still more XP per full HP bar spent.
    - Higher Weapon Skill means less XP per damage point dealt, but the DPS increase from both still results in faster leveling per minute in combat.  
    - Higher Alchemy means less XP per potion, but the increase in number of potions made still results in more total XP per amount of ingredients spent .

- **Gains are usually balanced around some average early-midgame value.**  
    Here's the fatcors I balanced around:
  
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

## TRACKABLE SKILLS

> All of these skills scale with their ideal variables.
> They may receive balance tweaks, but are unlikely to change in core behavior.

#### Armor

- [ ] Armor XP scales with Max HP, Base AR and amount of damage prevented (taken from item condition lost).
    On the base AR point specifically, the middle ground should be somewhere around 25 damage:  
    - Less than 25 damage favours low ARs.
    - More than 25 damage favours high ARs.  
    - This should help make leveling armor easier early on, and make light armor harder to max in the lategame (while heavy becomes easier and medium stays around vanilla).

#### Weapon

- [ ] Weapon XP scales with Weapon Skill and net damage dealt (taken from item condition lost)  
    - Weapon Skill is a divider.  
    > This is to balance the fact that weapons get more hits at high skill values.  
    - Condition Loss = NetDamage * \[fWeaponDamageMult->0.1\]  
    > This means Strength factors directly into it, and so does enemy armor reduction.  
    > As a result, XP will be mainly determined by _enemy HP_ rather than by how a$$ your weapon's minimal damage is.

#### Magic
- [ ] Magic XP scales with Max MP and MP spent.
    > Cast chance is not accounted for, and failing still gives zero XP. This is on purpose.  
    > It's what cheap spells are _actually_ meant for.
    - Detailed formula ahead.

#### Enchanting

- Enchanting XP scales with different things for each of it's uses:
    - [ ] Soul Size for item enchants
    - [ ] Points Recharged for Soulgem-Based Recharging  
        > Note you don't get any XP from passive recovery. This is on purpose.
    - [ ] Points Spent for Item Uses

#### Alchemy

- [ ] Alchemy XP scales with the combined value and weight of all items consumed.
    - Rewards spending expensive ingredients instead of selling them.
    - Rewards you for actually bothering to use heavy ingredients, which are more cumbersome to get and make more cumbersome potions.
    - Tones down XP from easily gathered/purchased ingredients

## UNTRACKABLE SKILLS
> All of these skills scale with workaround or compromise variables.  
> They will get better scaling formulas as soon as Lua API support is added for the missing factors.

#### Throwing
- [ ] Throwing XP scales with marksman level and average item damage.
