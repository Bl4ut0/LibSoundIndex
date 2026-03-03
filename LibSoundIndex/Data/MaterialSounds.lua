-- MaterialSounds.lua
-- Resolves foley/equip sounds directly from Material.db2 -> SoundKitEntry.db2 for dynamic expansion support

local MAJOR = "LibSoundIndex-1.0"
local lib = LibStub:GetLibrary(MAJOR, true)
if not lib then return end

lib.MaterialSounds = {
    METAL_SHEATHE = {
        description = "Metal weapon sheathe (swords, axes, maces)",
        Vanilla = {567498}, TBC = {567498}, MoP = {567498}, Retail = {567498}
    },
    NONMETAL_SHEATHE = {
        description = "Non-metal weapon sheathe (staves, wands, bows)",
        Vanilla = {567456}, TBC = {567456}, MoP = {567456}, Retail = {567456}
    },
    METAL_UNSHEATHE = {
        description = "Metal weapon unsheathe (swords, axes, maces)",
        Vanilla = {567473}, TBC = {567473}, MoP = {567473}, Retail = {567473}
    },
    NONMETAL_UNSHEATHE = {
        description = "Non-metal weapon unsheathe (staves, wands, bows)",
        Vanilla = {567506}, TBC = {567506}, MoP = {567506}, Retail = {567506}
    },
    LEATHER_FOLEY = {
        description = "Leather armor foley (equip rustling)",
        Vanilla = {567604,567599,567591,567580,567606,567598,567601,567586,567607,567602}, TBC = {567604,567599,567591,567580,567606,567598,567601,567586,567607,567602}, Retail = {567604,567599,567591,567580,567606,567598,567601,567586,567607,567602}
    },
    PLATE_FOLEY = {
        description = "Plate armor foley (metal clinking)",
        Vanilla = {567589,567595,567579,567578,567588,567581,567583,567584,567596,567582}, TBC = {567589,567595,567579,567578,567588,567581,567583,567584,567596,567582}, Retail = {567589,567595,567579,567578,567588,567581,567583,567584,567596,567582}
    },
    CHAIN_FOLEY = {
        description = "Chain/Mail armor foley (chain rustling)",
        Vanilla = {567585,567600,567597,567605,567587,567590,567603,567594,567592,567593}, TBC = {567585,567600,567597,567605,567587,567590,567603,567594,567592,567593}, Retail = {567585,567600,567597,567605,567587,567590,567603,567594,567592,567593}
    },
}

lib.EquipCategories = {
    ALL_WEAPONS = { "METAL_SHEATHE", "NONMETAL_SHEATHE", "METAL_UNSHEATHE", "NONMETAL_UNSHEATHE" },
    ALL_ARMOR_FOLEY = { "LEATHER_FOLEY", "PLATE_FOLEY", "CHAIN_FOLEY" },
    ALL_EQUIP = { "METAL_SHEATHE", "NONMETAL_SHEATHE", "METAL_UNSHEATHE", "NONMETAL_UNSHEATHE", "LEATHER_FOLEY", "PLATE_FOLEY", "CHAIN_FOLEY" },
    CLOTH = { "LEATHER_FOLEY" },
    LEATHER = { "LEATHER_FOLEY" },
    MAIL = { "CHAIN_FOLEY" },
    PLATE = { "PLATE_FOLEY" },
}