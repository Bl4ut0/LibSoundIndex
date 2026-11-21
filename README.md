# LibSoundIndex-1.0

LibSoundIndex maps WoW SoundKitIDs to audio FileDataIDs and uses the client's file mute API to suppress selected sounds. ItemRack Universal can call it before a gear move to briefly suppress candidate files for the items being equipped and displaced. Music, ambience, and other effects continue playing when they use different files.

## ItemRack Universal support

| Client | Interface | Equipment sound data |
|---|---|---|
| Classic Era, Hardcore, Season of Discovery | `11508`, `11509` | Era snapshots for both interfaces |
| Burning Crusade Classic Anniversary | `20505`, `20506` | Anniversary snapshots for both interfaces |
| WoW Forever / Camelot | `11601`, `16001` | Forever 1.60.1 snapshot. `11601` uses the same data. |

This matches the [ItemRack Universal support matrix](https://github.com/Bl4ut0/ItemRack-Universal#supported-clients). The standalone SoundKit APIs also have data for Retail and Mists of Pandaria Classic.

Install the `LibSoundIndex` folder alongside `ItemRack` and `ItemRackOptions` in the appropriate client's `Interface\AddOns` directory. Restart the client after adding or renaming a TOC. Use an ItemRack build with item-level integration and enable **Disable Swap Sounds** in ItemRack's sound settings. The same option can be enabled for an individual event.

The game applies a mute to the FileDataID for the whole client. Any playback using the same file during the window can also be suppressed. The library resolves candidates from client data. WoW does not report which native file an individual equipment move plays. When an item is absent from the index its sounds can play normally.

## Addon integration

Declare the standalone addon as an optional dependency with `## OptionalDeps: LibSoundIndex`. Call immediately before the operation that can play the sound.

```lua
local LSI = LibStub and LibStub("LibSoundIndex-1.0", true)
if LSI and LSI.CanMuteItemSounds and LSI:CanMuteItemSounds() then
    LSI:MuteItemSwapSounds(incomingItem, displacedItem)
end
-- Submit the equipment move here.
```

See [API.md](API.md) for other mute and lookup methods and [ARCHITECTURE.md](ARCHITECTURE.md) for data generation and client testing.

## Profile a gear swap

1. Run `/lsi profile` to open the visual profiler. For the baseline, turn off ItemRack's **Disable Swap Sounds**. Click **Start Capture**, swap sets, and click **Stop Capture**.
2. Each row shows the equipped or removed item's icon, name, item ID, and candidate FileDataIDs. Return to the starting set, click **Probe** on an item or **Probe All Items**, then repeat the swap within five seconds.
3. Click **Quiet**, **Partial**, or **Audible** to record what you heard. Click **Copy Report** and press Ctrl+C. Copy the report before reloading the UI.

The profiler records Lua sound requests and derives candidate files from equipment changes. It groups observations by base item ID. An acquired mute means the library successfully requested a file mute or already owned one for that file. Your repeat swap establishes what changed audibly.

Slash commands remain available. Use `/lsi debug start` and `/lsi debug stop` to capture, `/lsi probe items` to test the item candidates, `/lsi probe lua` for files associated with Lua calls, or `/lsi probe <FileDataID>` to isolate a file. Use `/lsi result quiet|partial|audible` and `/lsi dump` to record and copy the results.

## Other diagnostics

- `/lsi info` shows the client family, data build, and file mute availability.
- `/lsi item <item ID or link>` prints the candidate FileDataIDs for an item.
- `/lsi testitem <item ID or link>` briefly mutes those candidate files for an A/B test.
- `/lsi listen` shows Lua audio calls. Drop an item onto the window to inspect its candidate files.
- `/lsi muteall` applies the curated named and material groups. `/lsi unmuteall` releases mutes tracked by the library.

## Publishing

GitHub Actions tests branch pushes and builds an installable ZIP from the exact Git commit. The package contains the LibSoundIndex addon folder and its client-specific TOCs. The workflow uses the repository's existing `CURSEFORGE_API_TOKEN` Actions secret and [CurseForge project 1476448](https://www.curseforge.com/wow/addons/libsoundindex).

1. Run **LibSoundIndex release** from the Actions tab with **upload** off to verify the package, token, and CurseForge game versions. Leave the tag blank to check the default branch. This check reads the game-version catalog.
2. For distribution, set all LibSoundIndex TOC `Version` values to the intended version and commit them. Tag that commit as `vX.Y.Z` for a release or `vX.Y.Z-betaN` for a beta. Publish the matching GitHub release or prerelease with changelog notes. Publishing it triggers the upload to CurseForge and attaches the ZIP and its SHA-256 checksum to GitHub.
3. Check the Actions result for the CurseForge file ID. Submission and moderation are separate. The workflow records a GitHub deployment before making the upload request. If an upload stops after that reservation, check the CurseForge project and the workflow's evidence before attempting another upload for the tag.

Build a local ZIP from a committed ref with `python scripts/release.py build --ref HEAD`. Add `--tag vX.Y.Z` to validate the tag and TOC versions and produce the versioned archive under `.versions/Release/`.

## License

MIT
