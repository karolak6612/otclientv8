/*
 * Copyright (c) 2010-2017 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "map.h"

bool Map::isPositionWithinMapBounds(const Position& pos)
{
    // Check z bounds
    if(pos.z < 0 || pos.z > Otc::MAX_Z)
        return false;
    
    // Check if we have ANY tiles at this Z level
    if(m_tileBlocks[pos.z].empty())
        return false;
    
    // Find the nearest loaded block
    uint blockIndex = getBlockIndex(pos);
    auto it = m_tileBlocks[pos.z].find(blockIndex);
    
    if(it == m_tileBlocks[pos.z].end())
        return false;
    
    // Check if the specific tile exists (not null)
    const TilePtr& tile = it->second.get(pos);
    return tile != nullptr;
}

std::tuple<std::vector<Otc::Direction>, Otc::PathFindResult> Map::findPathSafe(const Position& start, const Position& goal, int maxComplexity, int flags)
{
    // Bounds check
    if(!isPositionWithinMapBounds(start) || !isPositionWithinMapBounds(goal)) {
        g_logger.debug("Pathfinding: Start or dest outside map bounds");
        std::vector<Otc::Direction> emptyDirs;
        Otc::PathFindResult failResult = Otc::PathFindResultNoWay;
        return std::make_tuple(emptyDirs, failResult);
    }
    
    // Check if start and dest have actual tiles
    const TilePtr& startTile = getTile(start);
    const TilePtr& destTile = getTile(goal);
    
    if(!startTile || !destTile) {
        g_logger.debug("Pathfinding: Start or dest tile is null");
        std::vector<Otc::Direction> emptyDirs;
        Otc::PathFindResult failResult = Otc::PathFindResultNoWay;
        return std::make_tuple(emptyDirs, failResult);
    }
    
    // Check walkability
    if(!startTile->isWalkable() || !destTile->isWalkable()) {
        g_logger.debug("Pathfinding: Start or dest not walkable");
        std::vector<Otc::Direction> emptyDirs;
        Otc::PathFindResult failResult = Otc::PathFindResultNoWay;
        return std::make_tuple(emptyDirs, failResult);
    }
    
    // Safe to call original findPath
    return findPath(start, goal, maxComplexity, flags);
}
