# CHANGELOG

## [1.1.0] - Universal Multi-Client Expansion
- **Universal Support**: The library now dynamically serves over **869 `SOUNDKIT` constants** and all foley/equip sounds natively across four game clients: WoW Classic Era (Vanilla), The Burning Crusade Classic (TBC), Mists of Pandaria Classic (MoP), and modern Retail!
- Rebuilt the internal database creation structure using aggregation scripts that drill through DB2 raw data across expansions.
- Refactored `LibSoundIndex-1.0.lua` to automatically detect the current `WOW_PROJECT_ID` at runtime and switch to the exact CASC file IDs corresponding to the user's active game client.

## [1.0.0] - Initial Release
- **Initial deployment** of LibSoundIndex-1.0.
- Implemented comprehensive mapping tool utilizing `MuteSoundFile()` and `UnmuteSoundFile()` APIs.
- Embedded data to resolve **213 `SOUNDKIT` constants** specifically targeting Classic Era and Burning Crusade Classic (TBC) Anniversary editions.
- Categorized elements smoothly into categories including UI, Chat, Spells, Auction, PvP, Pets, Transmog, etc., providing easy namespace control using `MuteCategory(categoryName)`.
- Discovered and manually mapped out **34 primary equip/foley** raw FileDataIDs derived from the `wow_classic` build's `Material.db2`. This ensures equipment swaps (Leather, Plate, Cloth, Mail, Metal Weapon, Non-metal Weapon) can be reliably silenced in the character screen without corrupting other UI sounds or utilizing destructive CVars.
- Added `/lsi info` commands for tracking internal library states along with programmatic Callback Handlers for embedding addons.
