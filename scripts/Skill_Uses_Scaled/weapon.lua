local core  = require('openmw.core')
local self  = require('openmw.self')
local types = require('openmw.types')

-- All we do here is recover weapon condition from 4X vanilla loss down to 2X vanilla loss
-- We don't use a more aggressive modifier because yes, we can make the player not notice...
-- ...but going over 4X will risk crippling NPCs in long fights.
-- I'm considering giving NPCs a constant weapon restoration effect, but I'm unsure about it.
-- Nevermind, this CAN be done instead by attaching this very same script to their weapons
-- Then sending events from an NPC script once/s to restore the same amount as func.lua does.
-- Even though we can't use a SkillUsed handler, we _can_ just check their equipped weapon's durability.
-- Of course, event calls should not happen while the NPC is under the effect of Disintegrate Weapon, for obvious reasons.

return {
    eventHandlers = {
        modifyCondition = function(amount)
            types.Item.itemData(self).condition = types.Item.itemData(self).condition + math.max(math.floor(amount), 0)
        end
    }
}
