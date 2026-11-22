# CHANGELOG

## [2.1.0] - 2026-11-21
- Added a visual sound profiler with item icons, candidate files grouped by item, per-item and all-item probes for repeat swaps, and a copyable diagnostic report.
- Added item-level sound data and timed swap muting for Classic Era, Hardcore, Season of Discovery, TBC Anniversary, and WoW Forever.
- Shared files stay muted until all LibSoundIndex requests that own them expire or release them.
- Added item lookup and audio diagnostics for verifying native swap sounds.

## [2.0.0] - Universal Multi-Client Expansion
- **Universal Support**: The library now dynamically serves **up to 315,000+ `SOUNDKIT` constants** and all foley/equip sounds natively across four game clients: WoW Classic Era (Vanilla), The Burning Crusade Classic (TBC), Mists of Pandaria Classic (MoP), and modern Retail!
- **Memory & Loading Optimization**: Separated the library into version-specific `.toc` files (`LibSoundIndex_Vanilla.toc`, `LibSoundIndex_Mainline.toc`, etc.) so the client only loads the ~3-5MB of data relevant to its version, rather than loading the entire 80MB database into memory.
- Rebuilt the internal database creation structure using aggregation scripts that drill through DB2 raw data across expansions.

## [1.0.0] - Initial Release
- **Initial deployment** of LibSoundIndex-1.0.
- Implemented comprehensive mapping tool utilizing `MuteSoundFile()` and `UnmuteSoundFile()` APIs.
- Embedded data to resolve **213 `SOUNDKIT` constants** specifically targeting Classic Era and Burning Crusade Classic (TBC) Anniversary editions.
- Categorized elements smoothly into categories including UI, Chat, Spells, Auction, PvP, Pets, Transmog, etc., providing easy namespace control using `MuteCategory(categoryName)`.
- Discovered and manually mapped out **40 primary equip/foley** raw FileDataIDs derived from the `wow_classic` build's `Material.db2`. This ensures equipment swaps (Leather, Plate, Cloth, Mail, Metal Weapon, Non-metal Weapon) can be reliably silenced in the character screen without corrupting other UI sounds or utilizing destructive CVars.
- Added `/lsi info` commands for tracking internal library states along with programmatic Callback Handlers for embedding addons.
