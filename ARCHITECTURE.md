# Equipment sound data and verification

## What the audit found

- Current ItemRack Universal already leaves the global SFX CVar alone. Its prior LibSoundIndex integration muted `ALL_EQUIP` plus UI sounds such as backpack and character-panel open and close. It started muting even before a locked move could reach the client.
- The old material groups could miss item-specific inventory sounds. In the Anniversary export, item `30293` points to `ItemGroupSounds` row `14`. Its kits `1193` and `1210` resolve to files `567542` and `567551`. Other trinkets can have different group IDs. The item table supplies that distinction directly. [Item and ItemGroupSounds schemas](https://github.com/wowdev/WoWDBDefs/tree/master/definitions)
- The old listener observed Lua sound calls. Native equip audio can bypass those calls. The current listener is labeled accordingly. Blizzard's `C_Sound.PlayItemSound` accepts an item location and action but returns no file IDs. [Blizzard Forever Sound API export](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua)
- Forever can report the mainline project ID. LibSoundIndex detects the Forever interface first and uses a Camelot-specific manifest and data set. The Mists standalone manifest uses the `_Mists` suffix.

## Resolution and muting

1. The exporter reads the item's base ID, inventory type, `ItemGroupSoundsID`, and material from `Item.csv`. It keeps rows with a positive inventory type, including equippable bags and ammunition.
2. It reads the kit IDs for that row from `ItemGroupSounds.csv` and adds material foley for armor and sheathe/unsheathe kits for weapons, shields, and held off-hands. These material additions are candidates based on the game's data, with live coverage subject to the engine's equip behavior.
3. It expands all direct and child kit files using `SoundKitEntry.csv` and `SoundKitChild.csv`. It deduplicates each set and shares identical sets across item IDs. It uses each client's rows, including differences between the older Era and Anniversary interfaces and their current builds.
4. ItemRack passes the exact source and displaced item identities immediately before each validated move submission. A retry, an independently batched move, or a rollback starts its own 0.35-second window. The secure combat binding can request the known weapon endpoints before its macro fires when WoW exposes their identities.
5. The engine applies file mutes client-wide. An unrelated sound with a different FileDataID can continue. Any playback of a shared FileDataID during the window can also be affected. Overlapping mutes within LibSoundIndex release independently. Other addons using the native mute API directly share the same engine state.

## Regenerate the index

Export these five tables as CSV from [Wago Tools](https://wago.tools/db2) for every pinned build in [scripts/generate_item_sounds.py](scripts/generate_item_sounds.py). Put each build's CSVs in `RawData/<full build>/` with their table names as filenames.

| Family | Interface | DB2 export build |
|---|---|---|
| Era | `11508` | `1.15.8.67156` |
| Era | `11509` | `1.15.9.70576` |
| Anniversary | `20505` | `2.5.5.68575` |
| Anniversary | `20506` | `2.5.6.70577` |
| Forever | `16001` | `1.60.1.71037` |

Run `python scripts/generate_item_sounds.py` from the repository root. The script accepts `--raw-data <path>` and repeatable `--client Vanilla|TBC|Forever` selections. It regenerates `Data/ItemSounds_*.lua` and the Forever SoundKit lookup. The pre-existing curated UI/material and other clients' universal SoundKit tables are separate from the item index.

Run `lua tests/item_sound_mutes.lua` from the repository root with Lua 5.1. The test loads each supported TOC and exercises actual item data, different trinket groups, missing items, failed native calls, and overlapping mutes. In the ItemRack repository run `npm.cmd test` for transaction and secure binding coverage.

## Sound capture and probes

The capture uses secure post-hooks on available Lua sound APIs. `PlaySoundFile` gives a FileDataID when its caller supplies one. For `PlaySound`, the kit ID gives candidate variations. For `C_Sound.PlayItemSound` and equipment changes, the profiler resolves readable item IDs against the item index. Native sounds can bypass Lua, so the report distinguishes observed calls from equipment-based candidates.

Open `/lsi profile` for the item grouped view. It includes controls for capture, per-item testing, an all-items probe, listening results, and the copied dump.

Capture lasts 30 seconds by default. Use `/lsi debug start <seconds>` for 1–120 seconds. The recorder keeps the last 100 observations and reports discarded rows. A probe defaults to five seconds and can run for 1–30 seconds. `items` uses the equipment and item sound candidates, `lua` uses direct file requests and indexed SoundKits, and `all` combines them. An explicit FileDataID can be probed without a session. The report records requested and acquired file counts and the manually reported listening outcome.

Run `lua tests/sound_profile.lua` to verify recording with a closed listener, unreadable inventory data, visual item grouping and pagination, probe isolation and expiration, record limits, and the copy window contents.

## Verify in game

1. Install the current development builds and restart the client. In Era, Hardcore, Season of Discovery, TBC Anniversary, and Forever, run `/lsi info` and confirm the expected family, build, and mute API availability.
2. Start with **Disable Swap Sounds** off and ambience and SFX on. Swap one item and note the sound. Enable the option and repeat the exact move. While it runs, check that ambience and an unrelated UI sound such as opening the backpack are still audible. After the window expires, repeat with suppression off and listen for the original sounds.
3. Repeat with trinkets that have different sound groups, armor, and a weapon. Try a multi-slot set, removing gear into an empty bag slot, a queued move, an event move, and a secure weapon binding in combat. Verify the swap still completes when LibSoundIndex is absent. Secure macros can also trigger secondary native effects that aren't exposed to the addon.
4. For a remaining sound, record the interface/build from `/lsi info`, the item IDs or links at both endpoints, the move type, and whether the sound appears in `/lsi listen`. Run `/lsi item <item>` for each endpoint. Use `/lsi debug start`, repeat the swap, and stop the capture. Probe `items`, `lua`, or a specific file ID in the report. Attach the `/lsi dump` text with the listening result.

The automated tests cover Lua timing and file ownership. Live testing establishes whether the selected files and default window catch the client audio for a particular move.
