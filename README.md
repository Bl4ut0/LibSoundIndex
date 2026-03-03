# LibSoundIndex-1.0
A standalone, embeddable WoW addon library that provides a complete index of game sound FileDataIDs and a surgical muting API via `MuteSoundFile()`/`UnmuteSoundFile()`.

**Replaces the blunt `SetCVar("Sound_EnableSFX", "0")` approach** that kills all game audio during gear swaps, causing noticeable silence patches in group play.

## Features
- **869 resolved SoundKitIDs** → FileDataIDs dynamically aggregated from Retail, MoP Classic, TBC Anniversary, and Classic Era DB2 data. Includes sounds across ui, combat, arena, dungeon finders, collections, and events (e.g., *Fel Reaver*, *You Are Not Prepared*).
- Complete automated tracking of **equip/foley/sheathe** FileDataIDs covering all armor and weapon material types across all 4 client versions. Automatically intercepts character screen gear swap audio events directly from the CASC file structure.
- **Surgical muting** — mute only the specific sounds you want, everything else plays normally.
- **Category-based API** — mute entire sound categories at once (e.g., all plate foley, all UI quest sounds, or transmog events).
- **Duration-based muting** — auto-unmute after a timeout (perfect for mitigating gear swap audio).
- **LibStub + CallbackHandler** — standard Ace3 embed pattern, works with any addon.

## Compatibility

| Client | Status |
|--------|--------|
| Retail / Modern | ✅ Supported |
| MoP Classic | ✅ Supported |
| TBC Anniversary | ✅ Supported |
| Classic Era / SoD / Hardcore | ✅ Supported |

> `MuteSoundFile()` / `UnmuteSoundFile()` have been seamlessly supported in the WoW Client since Classic Era 1.14.0.

## Quick Start

### For Addon Authors

Add LibSoundIndex as a dependency, then:

```lua
local LSI = LibStub("LibSoundIndex-1.0")

-- Mute all equip sounds for 1 second (gear swap)
LSI:MuteForDuration("ALL_EQUIP", 1.0)

-- Mute specific armor type
LSI:MuteMaterial("PLATE_FOLEY")

-- Mute by convenience category
LSI:MuteEquipCategory("MAIL")     -- mutes chain foley
LSI:MuteEquipCategory("ALL_ARMOR_FOLEY")  -- mutes leather + plate + chain

-- Mute a UI sound category
LSI:MuteCategory("AUCTION")

-- Specific Sound Muting
LSI:MuteSoundKit(9417) -- Mutes the FELREAVER alert specifically

-- Query data
local ids = LSI:GetFileDataIDs(862)  -- IG_BACKPACK_OPEN → {567461}
local name = LSI:GetSoundKitName(862)  -- "IG_BACKPACK_OPEN"

-- Check state
print(LSI:IsMuted(567461))  -- true/false
print(LSI:IsCategoryMuted("AUCTION"))

-- Callbacks
LSI.RegisterCallback(myAddon, "OnCategoryMuted", function(event, category)
    print("Muted:", category)
end)
```

### Slash Commands

- `/lsi info` — Show library stats
- `/lsi muteall` — Mute all indexed sounds
- `/lsi unmuteall` — Unmute everything

## Embedding

Copy the `LibSoundIndex` folder into your addon's `Libs/` directory.

In your TOC file:
```toc
## OptionalDeps: LibSoundIndex
```

In your `embeds.xml`:
```xml
<Include file="Libs\LibSoundIndex\LibSoundIndex.toc"/>
```

Or simply depend on it as a standalone addon and access it strictly via LibStub.

## Data Sources

All sound data is datamined and manually tracked from Blizzard's raw DB2 tables via [wago.tools](https://wago.tools):

- **Material.db2** → Material types with foley/sheathe/unsheathe File data pointers
- **SoundKitEntry.db2** → Master index for resolving abstract UI entries into actionable CASC file IDs.
- **SoundKitConstants.lua** → Named SOUNDKIT constants mapped from the Blizzard Interface Code.

### Material Sound Mapping Reference

| Material | Sound Type | Internal ID | File Variations |
|----------|-----------|------------|-----------------|
| Metal | Sheathe | 698 | 1 |
| Metal | Unsheathe | 700 | 1 |
| Non-metal | Sheathe | 697 | 1 |
| Non-metal | Unsheathe | 699 | 1 |
| Leather | Foley | 1003 | 10 files |
| Plate | Foley | 1004 | 10 files |
| Chain/Mail | Foley | 1005 | 10 files |

## License
MIT
