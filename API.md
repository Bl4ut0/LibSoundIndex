# LibSoundIndex API

Retrieve the optional library with `local LSI = LibStub and LibStub("LibSoundIndex-1.0", true)`. Check for the returned library before use.

## Item and file muting

| Method | Behavior |
|---|---|
| `CanMuteItemSounds()` | Returns whether the client has a loaded item index, native file mute functions, and a timer API. |
| `GetItemSoundFileDataIDs(item)` | Returns a fresh array of candidate FileDataIDs. Accepts a base item ID, an item hyperlink, an `item:` string, or an ItemRack item string. Returns an empty array for unknown items. |
| `MuteItemSwapSounds(source, destination, seconds)` | Mutes the union of the two items' candidate files. Pass `nil` or `0` for an empty endpoint. Defaults to 0.35 seconds. Returns the number of distinct files acquired by the request. |
| `MuteFileDataIDsForDuration(ids, seconds)` | Applies the same timed mute to an array of explicit FileDataIDs. Defaults to 0.35 seconds. Returns zero if no files could be acquired. |
| `MuteFileDataID(id)` / `UnmuteFileDataID(id)` | Acquires or releases a direct mute for the given file. Repeating the same direct mute is idempotent. |
| `IsMuted(id)` | Reports a file mute tracked by this library. |

Pass both endpoints before the first pickup, including when a swap displaces a different item. Start a new window for each submitted retry or later step. A timed request releases only its own library claims, so overlapping calls and direct mutes can safely share a file. The client exposes a file-level mute flag shared with other addons. LibSoundIndex tracks ownership for calls made through LibSoundIndex.

## SoundKit and category API

| Method | Behavior |
|---|---|
| `GetFileDataIDs(kit)` | Resolves a numeric kit ID or Blizzard `SOUNDKIT` constant name. Returns an array, empty when unresolved. |
| `GetFileDataIDsBySoundKitID(id)` | Resolves a numeric ID directly against the loaded client index. |
| `GetSoundKitByName(name)` / `GetSoundKitName(id)` | Looks up a Blizzard `SOUNDKIT` constant or its numeric ID. Returns `nil` if unknown. |
| `GetCategories()` / `GetCategoryIDs(category)` | Lists UI categories or resolves a category to candidate files. |
| `GetMaterialKeys()` / `GetMaterialSoundIDs(key)` | Lists material groups or resolves a group to files. |
| `GetEquipCategories()` | Lists broad material presets such as `ALL_EQUIP` and `ALL_ARMOR_FOLEY`. |
| `MuteSoundKit(kit)` / `UnmuteSoundKit(kit)` | Acquires or releases a mute for the kit's files. |
| `MuteCategory(name)` / `UnmuteCategory(name)` | Acquires or releases a named UI category. |
| `MuteMaterial(key)` / `UnmuteMaterial(key)` | Acquires or releases a material group. |
| `MuteEquipCategory(name)` / `UnmuteEquipCategory(name)` | Acquires or releases a broad equipment preset. |
| `MuteForDuration(category, seconds)` | Temporarily mutes a UI category, material group, or equipment preset. Defaults to 1 second. Another call for that category refreshes its timer. |
| `IsCategoryMuted(category)` | Reports a tracked UI category. For a material group, pass `MATERIAL_` followed by its key. |
| `MuteAll()` / `UnmuteAll()` | Applies the curated material and named SoundKit groups or clears library mutes, respectively. |

Treat arrays returned by the SoundKit and material lookups as read-only.

## Callbacks

Register through CallbackHandler with your addon's receiver and receive the event name and FileDataID or category key. File callbacks fire on the first acquisition and final release.

```lua
LSI.RegisterCallback(myAddon, "OnSoundMuted", function(event, fileDataID)
    print(event, fileDataID)
end)
```

The events are `OnSoundMuted`, `OnSoundUnmuted`, `OnCategoryMuted`, and `OnCategoryUnmuted`.

## Sound profile report

`GetSoundProfileReport()` returns the same plain text as `/lsi dump`. The report includes the client and data builds, audio settings, observed Lua sound requests, equipment changes with candidate files, and temporary mute probes with any manually recorded outcome. Start and stop the profile with `/lsi debug start` and `/lsi debug stop`.

## Loading

For a standalone install, the client selects the LibSoundIndex TOC for its game family. Consumers declare `## OptionalDeps: LibSoundIndex` and access it through LibStub.

An embedder must list the Lua files from its target client's TOC in order, or include an XML file containing equivalent `Script` entries. Copying the folder under `Libs` does not load it. XML includes load XML files and cannot include a TOC. For a multi-client addon, the standalone dependency lets WoW select the correct manifest.
