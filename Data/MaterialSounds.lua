-- MaterialSounds.lua
-- Datamined equip/foley/sheathe/unsheathe FileDataIDs from Material.db2 + SoundKitEntry.db2
-- Source: wago.tools DB2 export (wow_classic_era)
-- Generated: 2026-03-02
--
-- Chain: Item.db2 → MaterialID → Material.db2 → SoundKitID → SoundKitEntry.db2 → FileDataID
--
-- Material.db2 Flags: bit 1 = isMetal
-- MaterialID 1: Metal (Plate weapons/armor sheathe)     Flags=1
-- MaterialID 2: Non-metal (Cloth/Leather sheathe)       Flags=0
-- MaterialID 5: Chain/Mail foley                        Flags=5
-- MaterialID 6: Plate foley                             Flags=3
-- MaterialID 8: Leather foley                           Flags=0

local MAJOR = "LibSoundIndex-1.0"
local lib = LibStub:GetLibrary(MAJOR, true)
if not lib then return end

lib.MaterialSounds = {
    -- Sheathe sounds (weapon draw/holster)
    METAL_SHEATHE = {
        soundKitID = 698,
        fileDataIDs = { 567498 },
        description = "Metal weapon sheathe (swords, axes, maces)",
        materialID = 1,
    },
    NONMETAL_SHEATHE = {
        soundKitID = 697,
        fileDataIDs = { 567456 },
        description = "Non-metal weapon sheathe (staves, wands, bows)",
        materialID = 2,
    },

    -- Unsheathe sounds (weapon draw)
    METAL_UNSHEATHE = {
        soundKitID = 700,
        fileDataIDs = { 567473 },
        description = "Metal weapon unsheathe (swords, axes, maces)",
        materialID = 1,
    },
    NONMETAL_UNSHEATHE = {
        soundKitID = 699,
        fileDataIDs = { 567506 },
        description = "Non-metal weapon unsheathe (staves, wands, bows)",
        materialID = 2,
    },

    -- Foley sounds (armor equip/movement rustling)
    LEATHER_FOLEY = {
        soundKitID = 1003,
        fileDataIDs = {
            567580, 567586, 567591, 567598, 567599,
            567601, 567602, 567604, 567606, 567607,
        },
        description = "Leather armor foley (equip rustling, 10 variations)",
        materialID = 8,
    },
    PLATE_FOLEY = {
        soundKitID = 1004,
        fileDataIDs = {
            567578, 567579, 567581, 567582, 567583,
            567584, 567588, 567589, 567595, 567596,
        },
        description = "Plate armor foley (metal clinking, 10 variations)",
        materialID = 6,
    },
    CHAIN_FOLEY = {
        soundKitID = 1005,
        fileDataIDs = {
            567585, 567587, 567590, 567592, 567593,
            567594, 567597, 567600, 567603, 567605,
        },
        description = "Chain/Mail armor foley (chain rustling, 10 variations)",
        materialID = 5,
    },
}

-- Convenience categories that group multiple material sounds
lib.EquipCategories = {
    -- Mute all weapon equip sounds (sheathe + unsheathe)
    ALL_WEAPONS = { "METAL_SHEATHE", "NONMETAL_SHEATHE", "METAL_UNSHEATHE", "NONMETAL_UNSHEATHE" },
    -- Mute all armor foley sounds
    ALL_ARMOR_FOLEY = { "LEATHER_FOLEY", "PLATE_FOLEY", "CHAIN_FOLEY" },
    -- Mute everything equip-related
    ALL_EQUIP = { "METAL_SHEATHE", "NONMETAL_SHEATHE", "METAL_UNSHEATHE", "NONMETAL_UNSHEATHE",
                  "LEATHER_FOLEY", "PLATE_FOLEY", "CHAIN_FOLEY" },
    -- Armor type shortcuts
    CLOTH = { "LEATHER_FOLEY" }, -- Cloth uses leather foley sounds (MaterialID 8)
    LEATHER = { "LEATHER_FOLEY" },
    MAIL = { "CHAIN_FOLEY" },
    PLATE = { "PLATE_FOLEY" },
}
