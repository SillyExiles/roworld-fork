# Empires Front

**Empires Front** is a Roblox strategy game about history's great empires, a modified version of
[RoWorld](https://github.com/lukechatton/roworld) (itself a modified version of
[OpenFront](https://github.com/openfrontio/OpenFrontIO)), released under the GNU AGPL v3 like them.

What Empires Front changes (see the git history for every change):

- **Empire maps, each in its own era:** Rome (117 AD), Persia (500 BC), Ming China, the Mongols, the
  Ottomans, Ancient Greece (431 BC), Sengoku Japan (1560), the Inca, the Aztecs, Mali, Russia, plus World
  and the continents. Every era renames units, ships and buildings and has its own Forge tiers
  (`src/shared/Data/Eras.luau`); maps are built from Natural Earth / NOAA data by
  `tools/maps/make_empire_maps.py`.
- **Economy:** mines and ore, markets with a dynamic ore price, trade ships carrying ore, trade and
  defence pacts between allies, Forge (arms & armour), Border Walls and Barracks (4 per player).
- **Terrain:** hills and mountains are natural walls (costlier and slower to take).
- **Roads link every building** in a Way Station's reach (mines and markets on the roads produce more).
- **Captured buildings change hands**; walls and defense posts are destroyed when overrun.
- **Empire Shop:** ~85 pixel-art flags that tile over the owner's land (territory skins) and fly beside
  their name, bought with Stars (earned by performance in every match) or, for a few, Robux (developer
  products, regional prices). `src/client/EmpireShop.luau`, `src/shared/Data/EmpireFlags.luau`
  (made by `tools/make_empire_flags.py`).
- **Public lobbies** spread players over the open matches (`LobbyRules.spread`).
- No nukes/SAMs/Arsenal, no crates, no subscription.

The rest of this file is RoWorld's original README.

---

# RoWorld
