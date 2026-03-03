-- MaterialSounds.lua
-- Resolves foley/equip sounds directly from Material.db2 -> SoundKitEntry.db2 for dynamic expansion support

local MAJOR = "LibSoundIndex-1.0"
local lib = LibStub:GetLibrary(MAJOR, true)
if not lib then return end

lib.MaterialSounds = {
    -- Weapon sheathe/unsheathe (Material 1: Metal)
    METAL_SHEATHE = {
        description = "Metal weapon sheathe (swords, axes, maces)",
        Vanilla = {567498}, TBC = {567498}, MoP = {567498}, Retail = {567498}
    },
    METAL_UNSHEATHE = {
        description = "Metal weapon unsheathe (swords, axes, maces)",
        Vanilla = {567473}, TBC = {567473}, MoP = {567473}, Retail = {567473}
    },
    -- Weapon sheathe/unsheathe (Material 2: Wood/Non-metal)
    NONMETAL_SHEATHE = {
        description = "Non-metal weapon sheathe (staves, wands, bows)",
        Vanilla = {567456}, TBC = {567456}, MoP = {567456}, Retail = {567456}
    },
    NONMETAL_UNSHEATHE = {
        description = "Non-metal weapon unsheathe (staves, wands, bows)",
        Vanilla = {567506}, TBC = {567506}, MoP = {567506}, Retail = {567506}
    },
    -- Weapon sheathe/unsheathe (Material 3: Liquid — potions, wands, misc)
    LIQUID_SHEATHE = {
        description = "Liquid/misc weapon sheathe (potions, wands, off-hands)",
        Vanilla = {567395}, TBC = {567395}, MoP = {567395}, Retail = {567395}
    },
    LIQUID_UNSHEATHE = {
        description = "Liquid/misc weapon unsheathe",
        Vanilla = {567430}, TBC = {567430}, MoP = {567430}, Retail = {567430}
    },
    -- Weapon sheathe/unsheathe (Material 6: Plate — shares sheathe with Liquid, plus foley)
    PLATE_SHEATHE = {
        description = "Plate weapon sheathe (shields, plate off-hands)",
        Vanilla = {567395}, TBC = {567395}, MoP = {567395}, Retail = {567395}
    },
    PLATE_UNSHEATHE = {
        description = "Plate weapon unsheathe",
        Vanilla = {567430}, TBC = {567430}, MoP = {567430}, Retail = {567430}
    },
    -- Weapon sheathe/unsheathe (Material 7: Misc/unknown — TBC+ only)
    MISC_SHEATHE = {
        description = "Miscellaneous sheathe (Material 7, TBC+)",
        TBC = {569842}, MoP = {569842}, Retail = {569842}
    },
    MISC_UNSHEATHE = {
        description = "Miscellaneous unsheathe (Material 7, TBC+)",
        TBC = {569839}, MoP = {569839}, Retail = {569839}
    },
    -- Armor foley (Material 8: Leather)
    LEATHER_FOLEY = {
        description = "Leather armor foley (equip rustling)",
        Vanilla = {567604,567599,567591,567580,567606,567598,567601,567586,567607,567602}, TBC = {567604,567599,567591,567580,567606,567598,567601,567586,567607,567602}, MoP = {567604,567599,567591,567580,567606,567598,567601,567586,567607,567602}, Retail = {567604,567599,567591,567580,567606,567598,567601,567586,567607,567602}
    },
    -- Armor foley (Material 6: Plate)
    PLATE_FOLEY = {
        description = "Plate armor foley (metal clinking)",
        Vanilla = {567589,567595,567579,567578,567588,567581,567583,567584,567596,567582}, TBC = {567589,567595,567579,567578,567588,567581,567583,567584,567596,567582}, MoP = {567589,567595,567579,567578,567588,567581,567583,567584,567596,567582}, Retail = {567589,567595,567579,567578,567588,567581,567583,567584,567596,567582}
    },
    -- Armor foley (Material 5: Chain/Mail)
    CHAIN_FOLEY = {
        description = "Chain/Mail armor foley (chain rustling)",
        Vanilla = {567585,567600,567597,567605,567587,567590,567603,567594,567592,567593}, TBC = {567585,567600,567597,567605,567587,567590,567603,567594,567592,567593}, MoP = {567585,567600,567597,567605,567587,567590,567603,567594,567592,567593}, Retail = {567585,567600,567597,567605,567587,567590,567603,567594,567592,567593}
    },
}

lib.EquipCategories = {
    ALL_WEAPONS = { "METAL_SHEATHE", "METAL_UNSHEATHE", "NONMETAL_SHEATHE", "NONMETAL_UNSHEATHE", "LIQUID_SHEATHE", "LIQUID_UNSHEATHE", "PLATE_SHEATHE", "PLATE_UNSHEATHE", "MISC_SHEATHE", "MISC_UNSHEATHE" },
    ALL_ARMOR_FOLEY = { "LEATHER_FOLEY", "PLATE_FOLEY", "CHAIN_FOLEY" },
    ALL_EQUIP = { "METAL_SHEATHE", "METAL_UNSHEATHE", "NONMETAL_SHEATHE", "NONMETAL_UNSHEATHE", "LIQUID_SHEATHE", "LIQUID_UNSHEATHE", "PLATE_SHEATHE", "PLATE_UNSHEATHE", "MISC_SHEATHE", "MISC_UNSHEATHE", "LEATHER_FOLEY", "PLATE_FOLEY", "CHAIN_FOLEY" },
    CLOTH = { "LEATHER_FOLEY" },
    LEATHER = { "LEATHER_FOLEY" },
    MAIL = { "CHAIN_FOLEY", "NONMETAL_SHEATHE", "NONMETAL_UNSHEATHE" },
    PLATE = { "PLATE_FOLEY", "PLATE_SHEATHE", "PLATE_UNSHEATHE" },
    SWORDS = { "METAL_SHEATHE", "METAL_UNSHEATHE" },
    STAVES = { "NONMETAL_SHEATHE", "NONMETAL_UNSHEATHE" },
    SHIELDS = { "PLATE_SHEATHE", "PLATE_UNSHEATHE" },
}