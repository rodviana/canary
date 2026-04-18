/**
 * Canary - A free and open-source MMORPG server emulator
 * Copyright (©) 2019–present OpenTibiaBR <opentibiabr@outlook.com>
 * Repository: https://github.com/opentibiabr/canary
 * License: https://github.com/opentibiabr/canary/blob/main/LICENSE
 * Contributors: https://github.com/opentibiabr/canary/graphs/contributors
 * Website: https://docs.opentibiabr.com/
 */

#include "io/iomap.hpp"

#include "game/movement/teleport.hpp"
#include "game/game.hpp"
#include "io/filestream.hpp"
#include "utils/benchmark.hpp"

#include <filesystem>

/*
    OTBM_ROOTV1
    |
    |--- OTBM_MAP_DATA
    |	|
    |	|--- OTBM_TILE_AREA
    |	|	|--- OTBM_TILE
    |	|	|--- OTBM_TILE_SQUARE (not implemented)
    |	|	|--- OTBM_TILE_REF (not implemented)
    |	|	|--- OTBM_HOUSETILE
    |	|
    |	|--- OTBM_SPAWNS (not implemented)
    |	|	|--- OTBM_SPAWN_AREA (not implemented)
    |	|	|--- OTBM_MONSTER (not implemented)
    |	|
    |	|--- OTBM_TOWNS
    |	|	|--- OTBM_TOWN
    |	|
    |	|--- OTBM_WAYPOINTS
    |		|--- OTBM_WAYPOINT
    |
    |--- OTBM_ITEM_DEF (not implemented)
*/

void IOMap::loadMap(Map* map, const Position &pos) {
	Benchmark bm_mapLoad;
	const bool verbose = g_configManager().getBoolean(TOGGLE_MAP_LOAD_VERBOSE);
	const std::string pathStr = map->path.string();

	if (verbose) {
		std::error_code ec;
		const auto fileSize = std::filesystem::file_size(map->path, ec);
		if (ec) {
			g_logger().warn("[IOMap::loadMap] could not read file size for {}: {}", pathStr, ec.message());
		} else {
			g_logger().info("[IOMap::loadMap] opening {} ({} bytes)", pathStr, fileSize);
		}
	}

	const auto &fileByte = mio::mmap_source(pathStr);

	const auto begin = fileByte.begin() + sizeof(OTB::Identifier { { 'O', 'T', 'B', 'M' } });

	FileStream stream { begin, fileByte.end() };

	if (!stream.startNode()) {
		throw IOMapException("Could not read map node.");
	}

	stream.skip(1); // Type Node

	uint32_t version = stream.getU32();
	map->width = stream.getU16();
	map->height = stream.getU16();
	uint32_t majorVersionItems = stream.getU32();
	const uint32_t minorVersionItems = stream.getU32();

	if (version > 5) {
		throw IOMapException("Unknown OTBM version detected.");
	}

	if (majorVersionItems < 3) {
		throw IOMapException("This map need to be upgraded by using the latest map editor version to be able to load correctly.");
	}

	if (verbose) {
		g_logger().info("[IOMap::loadMap] OTBM header: format version {} | map size {}x{} | items.dat major {} minor {}", version, map->width, map->height, majorVersionItems, minorVersionItems);
	}

	MapLoadStats stats;

	Benchmark bm_mapData;
	if (stream.startNode(OTBM_MAP_DATA)) {
		parseMapDataAttributes(stream, map);
		if (verbose) {
			const auto showPath = [](const std::string &p) -> std::string {
				return p.empty() ? std::string("(not set; defaults apply)") : p;
			};
			g_logger().info("[IOMap::loadMap] embedded spawn paths — monster: {} | npc: {} | house: {} | zones: {}", showPath(map->monsterfile), showPath(map->npcfile), showPath(map->housefile), showPath(map->zonesfile));
		}
		parseTileArea(stream, *map, pos, stats);
		stream.endNode();
	}
	if (verbose) {
		g_logger().info("[IOMap::loadMap] map data + tiles section: {} ms", bm_mapData.duration());
	}

	Benchmark bm_towns;
	parseTowns(stream, *map, stats);
	if (verbose) {
		g_logger().info("[IOMap::loadMap] towns section: {} ms ({} towns)", bm_towns.duration(), stats.towns);
	}

	Benchmark bm_waypoints;
	parseWaypoints(stream, *map, stats);
	if (verbose) {
		g_logger().info("[IOMap::loadMap] waypoints section: {} ms ({} entries, {} duplicate names)", bm_waypoints.duration(), stats.waypoints, stats.duplicateWaypointNames);
	}

	Benchmark bm_flush;
	map->flush();
	if (verbose) {
		g_logger().info("[IOMap::loadMap] map flush: {} ms", bm_flush.duration());
	}

	if (stats.duplicateTileOverwrites > 0) {
		g_logger().warn("[IOMap::loadMap] {} duplicate tile position(s) in OTBM (later fragment wins)", stats.duplicateTileOverwrites);
	}
	if (stats.outOfBoundsTiles > 0) {
		g_logger().warn("[IOMap::loadMap] {} tile(s) outside declared map bounds {}x{} (verify editor export / OTBM header)", stats.outOfBoundsTiles, map->width, map->height);
	}
	if (stats.duplicateWaypointNames > 0) {
		g_logger().warn("[IOMap::loadMap] {} duplicate waypoint name(s) in OTBM (later entry wins)", stats.duplicateWaypointNames);
	}

	const std::string summary = fmt::format(
		"{} | {}x{} | {} ms | tile areas {} | tile nodes {} | placed {} | skipped empty {} | dup writes {} | OOB {} | towns {} | waypoints {} | dup waypoint names {}",
		map->path.filename().string(),
		map->width,
		map->height,
		bm_mapLoad.duration(),
		stats.tileAreas,
		stats.tileNodes,
		stats.placedTiles,
		stats.skippedEmptyTiles,
		stats.duplicateTileOverwrites,
		stats.outOfBoundsTiles,
		stats.towns,
		stats.waypoints,
		stats.duplicateWaypointNames
	);

	if (verbose) {
		g_logger().info("[IOMap::loadMap] summary: {}", summary);
	} else {
		g_logger().debug("Map Loaded {}", summary);
	}
}

void IOMap::parseMapDataAttributes(FileStream &stream, Map* map) {
	bool end = false;
	while (!end) {
		const uint8_t attr = stream.getU8();
		switch (attr) {
			case OTBM_ATTR_DESCRIPTION: {
				stream.getString();
			} break;

			case OTBM_ATTR_EXT_SPAWN_MONSTER_FILE: {
				map->monsterfile = map->path.string().substr(0, map->path.string().rfind('/') + 1);
				map->monsterfile += stream.getString();
			} break;

			case OTBM_ATTR_EXT_SPAWN_NPC_FILE: {
				map->npcfile = map->path.string().substr(0, map->path.string().rfind('/') + 1);
				map->npcfile += stream.getString();
			} break;
			case OTBM_ATTR_EXT_HOUSE_FILE: {
				map->housefile = map->path.string().substr(0, map->path.string().rfind('/') + 1);
				map->housefile += stream.getString();
			} break;

			case OTBM_ATTR_EXT_ZONE_FILE: {
				map->zonesfile = map->path.string().substr(0, map->path.string().rfind('/') + 1);
				map->zonesfile += stream.getString();
			} break;

			default:
				stream.back();
				end = true;
				break;
		}
	}
}

void IOMap::parseTileArea(FileStream &stream, Map &map, const Position &pos, MapLoadStats &stats) {
	while (stream.startNode(OTBM_TILE_AREA)) {
		stats.tileAreas++;
		const uint16_t base_x = stream.getU16();
		const uint16_t base_y = stream.getU16();
		const uint8_t base_z = stream.getU8();

		while (stream.startNode()) {
			stats.tileNodes++;
			const uint8_t tileType = stream.getU8();
			if (tileType != OTBM_HOUSETILE && tileType != OTBM_TILE) {
				throw IOMapException("Could not read tile type node.");
			}

			const auto tile = std::make_shared<BasicTile>();

			const uint8_t tileCoordsX = stream.getU8();
			const uint8_t tileCoordsY = stream.getU8();

			const uint16_t x = base_x + tileCoordsX + pos.x;
			const uint16_t y = base_y + tileCoordsY + pos.y;
			const auto z = static_cast<uint8_t>(base_z + pos.z);

			if (tileType == OTBM_HOUSETILE) {
				tile->houseId = stream.getU32();
				if (!map.houses.addHouse(tile->houseId)) {
					throw IOMapException(fmt::format("[x:{}, y:{}, z:{}] Could not create house id: {}", x, y, z, tile->houseId));
				}
			}

			if (stream.isProp(OTBM_ATTR_TILE_FLAGS)) {
				const uint32_t flags = stream.getU32();
				if ((flags & OTBM_TILEFLAG_PROTECTIONZONE) != 0) {
					tile->flags |= TILESTATE_PROTECTIONZONE;
				} else if ((flags & OTBM_TILEFLAG_NOPVPZONE) != 0) {
					tile->flags |= TILESTATE_NOPVPZONE;
				} else if ((flags & OTBM_TILEFLAG_PVPZONE) != 0) {
					tile->flags |= TILESTATE_PVPZONE;
				}

				if ((flags & OTBM_TILEFLAG_NOLOGOUT) != 0) {
					tile->flags |= TILESTATE_NOLOGOUT;
				}
			}

			if (stream.isProp(OTBM_ATTR_ITEM)) {
				const uint16_t id = stream.getU16();
				const auto &iType = Item::items[id];

				if (!tile->isHouse() || !iType.isBed()) {
					const auto item = std::make_shared<BasicItem>();
					item->id = id;

					if (tile->isHouse() && iType.movable) {
						g_logger().warn("[IOMap::loadMap] - "
						                "Movable item with ID: {}, in house: {}, "
						                "at position: x {}, y {}, z {}",
						                id, tile->houseId, x, y, z);
					} else if (iType.isGroundTile()) {
						tile->ground = map.tryReplaceItemFromCache(item);
					} else {
						tile->items.emplace_back(map.tryReplaceItemFromCache(item));
					}
				}
			}

			while (stream.startNode()) {
				auto type = stream.getU8();
				switch (type) {
					case OTBM_ITEM: {
						const uint16_t id = stream.getU16();
						const auto &iType = Item::items[id];
						const auto item = std::make_shared<BasicItem>();
						item->id = id;

						if (!item->unserializeItemNode(stream, x, y, z)) {
							throw IOMapException(fmt::format("[x:{}, y:{}, z:{}] Failed to load item {}, Node Type.", x, y, z, id));
						}

						if (tile->isHouse() && (iType.isBed() || iType.isTrashHolder())) {
							// nothing
						} else if (tile->isHouse() && iType.movable) {
							g_logger().warn("[IOMap::loadMap] - "
							                "Movable item with ID: {}, in house: {}, "
							                "at position: x {}, y {}, z {}",
							                id, tile->houseId, x, y, z);
						} else if (iType.isGroundTile()) {
							tile->ground = map.tryReplaceItemFromCache(item);
						} else {
							tile->items.emplace_back(map.tryReplaceItemFromCache(item));
						}
					} break;
					case OTBM_TILE_ZONE: {
						const auto zoneCount = stream.getU16();
						for (uint16_t i = 0; i < zoneCount; ++i) {
							const auto zoneId = stream.getU16();
							if (!zoneId) {
								throw IOMapException(fmt::format("[x:{}, y:{}, z:{}] Invalid zone id.", x, y, z));
							}
							auto zone = Zone::getZone(zoneId);
							zone->addPosition(Position(x, y, z));
						}
					} break;
					default:
						throw IOMapException(fmt::format("[x:{}, y:{}, z:{}] Could not read item/zone node.", x, y, z));
				}

				if (!stream.endNode()) {
					throw IOMapException(fmt::format("[x:{}, y:{}, z:{}] Could not end node.", x, y, z));
				}
			}

			if (!stream.endNode()) {
				throw IOMapException(fmt::format("[x:{}, y:{}, z:{}] Could not end node.", x, y, z));
			}

			if (tile->isEmpty(true)) {
				stats.skippedEmptyTiles++;
				continue;
			}

			if (map.width > 0 && map.height > 0 && (x >= map.width || y >= map.height)) {
				stats.outOfBoundsTiles++;
			}

			if (const auto sector = map.getMapSector(x, y)) {
				if (const auto floor = sector->getFloor(z)) {
					if (floor->getTileCache(x, y)) {
						stats.duplicateTileOverwrites++;
					}
				}
			}

			stats.placedTiles++;
			map.setBasicTile(x, y, z, tile);
		}

		if (!stream.endNode()) {
			throw IOMapException("Could not end node.");
		}
	}
}

void IOMap::parseTowns(FileStream &stream, Map &map, MapLoadStats &stats) {
	if (!stream.startNode(OTBM_TOWNS)) {
		throw IOMapException("Could not read towns node.");
	}

	while (stream.startNode(OTBM_TOWN)) {
		stats.towns++;
		const uint32_t townId = stream.getU32();
		const auto &townName = stream.getString();
		const uint16_t x = stream.getU16();
		const uint16_t y = stream.getU16();
		const uint8_t z = stream.getU8();

		auto town = map.towns.getOrCreateTown(townId);
		town->setName(townName);
		town->setTemplePos(Position(x, y, z));

		if (!stream.endNode()) {
			throw IOMapException("Could not end node.");
		}
	}

	if (!stream.endNode()) {
		throw IOMapException("Could not end node.");
	}
}

void IOMap::parseWaypoints(FileStream &stream, Map &map, MapLoadStats &stats) {
	const bool verbose = g_configManager().getBoolean(TOGGLE_MAP_LOAD_VERBOSE);

	if (!stream.startNode(OTBM_WAYPOINTS)) {
		throw IOMapException("Could not read waypoints node.");
	}

	while (stream.startNode(OTBM_WAYPOINT)) {
		const auto &name = stream.getString();
		const uint16_t x = stream.getU16();
		const uint16_t y = stream.getU16();
		const uint8_t z = stream.getU8();

		if (const auto it = map.waypoints.find(name); it != map.waypoints.end()) {
			stats.duplicateWaypointNames++;
			if (verbose) {
				g_logger().warn("[IOMap::loadMap] duplicate waypoint name '{}' — was {} now {}", name, it->second.toString(), Position(x, y, z).toString());
			}
		}

		map.waypoints[name] = Position(x, y, z);
		stats.waypoints++;

		if (!stream.endNode()) {
			throw IOMapException("Could not end node.");
		}
	}

	if (!stream.endNode()) {
		throw IOMapException("Could not end node.");
	}
}
