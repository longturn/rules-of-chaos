-- Copyright (c) 2007-2020 Freeciv21 and Freeciv contributors. This file is
--   part of Freeciv21. Freeciv21 is free software: you can redistribute it
--   and/or modify it under the terms of the GNU General Public License
--   as published by the Free Software Foundation, either version 3
--   of the License,  or (at your option) any later version.
--   You should have received a copy of the GNU General Public License
--   along with Freeciv21. If not, see https://www.gnu.org/licenses/.

-- This file is for lua-functionality that is specific to a given
-- ruleset. When freeciv loads a ruleset, it also loads script
-- file called 'default.lua'. The one loaded if your ruleset
-- does not provide an override is default/default.lua.

-- Import data from game.json
project = { version = 0.1 }
options = { cityWorkRadiusSqInitial = 15, cityWorkRadiusSqTheologyBonus = 3, cityWorkRadiusSqMassTransitBonus = 6 }
features = { impetuousUnits = { enabled = true, provokingChance = 0.15 }, inaccessibleClimates = { enabled = true, baseCityPollution = 1, globalWarmingAccumulationFactor = 5.0, pollutionProductionIncrease = 1 }, explosiveExpansion = { enabled = true, speed = 3 }, invisiblePortals = { enabled = true, allowFatalTransit = false, allowFatalTransitAI = false, density = 0.027, halfLife = 8 }, blindWorld = { enabled = true, blindVisionRadius = 0, nonBlindUnderwaterVisionRadius = 1, nonBlindSurfaceVisionRadius = 2, nonBlindAirVisionRadius = 5, surfaceMountainVisionBonus = 1 }, powerfulSpecials = { enabled = true }, spaceExodus = { enabled = true, expectedLaunchTurn = 250, earlyFinishMultiplier = 15, firstPlaceBonus = 500 } }

-- Place Ruins at the location of the destroyed city.
function city_destroyed_callback(city, loser, destroyer)
  city.tile:create_extra("Ruins", NIL)
  -- continue processing
  return false
end

signal.connect("city_destroyed", "city_destroyed_callback")

-- Restore inaccessible tiles adjacent to nuclear explosions
function inaccessible_climates_nuke_exploded(tile, player)
  local inaccessible = "Inaccessible "
  for adj_tile in tile:square_iterate(1) do
    local terrain = adj_tile.terrain:rule_name()
    if terrain:sub(1, #inaccessible) == inaccessible then
      local accessible = terrain:sub(#inaccessible + 1)
      adj_tile:change_terrain(find.terrain(accessible))
    end
  end
end

signal.connect("nuke_exploded", "inaccessible_climates_nuke_exploded")

-- Initialise global namespace for portal data
invisible_portals = {
  traversing = {}
}

function invisible_portals:log(level, fmt, ...)
  log.base(level, string.format("Invisible Portals: " .. fmt, ...))
end

function invisible_portals:debug(fmt, ...)
  self:log(log.level.DEBUG, "[DEBUG] " .. fmt, ...)
end

function invisible_portals:info(fmt, ...)
  self:log(log.level.NORMAL, "[INFO] " .. fmt, ...)
end

function invisible_portals:portal_count()
  local count = 0
  for source_id, dest_id in pairs(self.portals) do
    count = count + 1
  end
  return count
end

function invisible_portals:serialise_portals()
  local portals = {}
  for source_id, dest_id in pairs(self.portals) do
    table.insert(portals, source_id .. "=" .. dest_id)
  end
  return table.concat(portals, ",")
end

function invisible_portals:init()
  self:debug("Creating namespace")
  local half_life = features.invisiblePortals.halfLife
  local density = features.invisiblePortals.density
  local collapse_chance = 1 - 2^(-1 / half_life)
  local form_chance = (density * collapse_chance) / (1 - density)
  self.initial_density_freq = math.floor(density * 1000000)
  self.initial_density_range = 1000000
  self:info("Initial portal density = %d / %d", 
  self.initial_density_freq, self.initial_density_range)
  self.collapse_chance_freq = math.floor(collapse_chance * 1000000)
  self.collapse_chance_range = 1000000
  self:info("Portal collapse chance per turn = %d / %d",
  self.collapse_chance_freq, self.collapse_chance_range)
  self.form_chance_freq = math.floor(form_chance * 1000000)
  self.form_chance_range = 1000000
  self:info("Portal form chance per turn = %d / %d", 
  self.form_chance_freq, self.form_chance_range)
  local _portal_cache = NIL
  setmetatable(self, {
    __index = function(table, key)
      if key == "portals" then
        if not _portal_cache then
          _portal_cache = {}
          self:load_portals()
        end
        return _portal_cache
      end
    end
  })
  self:debug("Namespace created")
end

function invisible_portals:save_portals()
  self:debug("Saving portals")
  invisible_portals_data = self:serialise_portals()
  self:info("%d portals saved", self:portal_count())
  self:debug("invisible_portals_data = %s", invisible_portals_data)
  self:debug("Portal save complete")
end

function invisible_portals:load_portals()
  self:debug("Loading portals")
  if not invisible_portals_data then
    self:debug("No previous portal data found")
    return
  end
  -- If the map has already been generated, count the map tiles
  invisible_portals:count_map_tiles()
  for source_id, dest_id in string.gmatch(invisible_portals_data, "(%w+)=(%w+)") do
    self:create_portal(source_id, dest_id)
  end
  self:info("%d portals loaded", self:portal_count())
  self:debug("Portal data loaded from save: %s", invisible_portals_data)
end

-- Count the number of tiles in the map after map generation
function invisible_portals:count_map_tiles()
  self:debug("Counting map tiles")
  local tile_count = 0
  for tile in whole_map_iterate() do
    tile_count = tile_count + 1
  end
  self.tile_count = tile_count
  self:info("%d map tiles detected", self.tile_count)
end

-- Create a new portal on a tile with a random destination
function invisible_portals:create_random_portal(tile)
  self:debug("Creating a new portal at %s", tile)
  local dest_id = random(0, self.tile_count - 1)
  self.portals[tile.id] = dest_id
  local dest_tile = find.tile(dest_id)
  self:info("A new portal formed at (%d, %d) leading to (%d, %d)",
    tile.x, tile.y, dest_tile.x, dest_tile.y)
end

-- Create a portal on a tile with a specific destination
function invisible_portals:create_portal(source_id, dest_id)
  self:debug("Creating a portal at %s to %s", source_id, dest_id)
  self.portals[tonumber(source_id)] = tonumber(dest_id)
  local source_tile = find.tile(source_id)
  local dest_tile = find.tile(dest_id)
  self:info("A portal opened at (%d, %d) leading to (%d, %d)",
    source_tile.x, source_tile.y, dest_tile.x, dest_tile.y)
end

-- Remove a portal
function invisible_portals:destroy_portal(tile_id)
  self:debug("Destroying portal #%s", tile_id)
  local tile = find.tile(tile_id)
  local dest_id = self.portals[tile_id]
  self.portals[tile_id] = NIL
  local dest_tile = find.tile(dest_id)
  self:info("Portal at (%d, %d) leading to (%d, %d) collapsed",
    tile.x, tile.y, dest_tile.x, dest_tile.y)
end

-- Mark a portal on the map
function invisible_portals:mark_portal(source_tile, dest_tile)
  source_tile:set_label(string.format("(%d, %d)", dest_tile.x, dest_tile.y))
  source_tile:create_extra("Portal")
end

-- Remove a portal marker from the map
function invisible_portals:unmark_portal(source_tile)
  source_tile:set_label("")
  source_tile:remove_extra("Portal")
end

-- Distribute initial portals across the map
function invisible_portals:create_initial_portals()
  self:info("Creating initial portals")
  local range = self.initial_density_range
  local freq = self.initial_density_freq
  for tile in whole_map_iterate() do
    if random(0, range) < freq then
      self:create_random_portal(tile)
    end
  end
  self:info("Initial portals created")
  self:save_portals()
end

-- New portals form over time
function invisible_portals:create_new_portals()
  self:info("New portals forming")
  local range = self.form_chance_range
  local freq = self.form_chance_freq
  for tile in whole_map_iterate() do
    local destination = self.portals[tile.id]
    if not destination and random(0, range) < freq then
      self:create_random_portal(tile)
    end
  end
  self:info("Done forming new portals")
end

-- Existing portals have a chance to collapse each turn
function invisible_portals:expire_old_portals()
  self:info("Expiring old portals")
  local range = self.collapse_chance_range
  local freq = self.collapse_chance_freq
  for source_id, dest_id in pairs(self.portals) do
    if random(0, range) < freq then
      self:destroy_portal(source_id)
    end
  end
  self:info("Done expiring old portals")
end

function invisible_portals:disembark_at_portal(unit, source_tile)
  for cargo in unit:cargo_iterate() do
    self:info("%s %s was forced to disembark from %s %s during portal transit",
      cargo, cargo.utype:name_translation(), 
      unit, unit.utype:name_translation()
    )
    self:traverse_portal(cargo, source_tile, source_tile)
  end
end

function invisible_portals:fatal_transit_allowed(player)
  if player:has_flag("ai") then
    return features.invisiblePortals.allowFatalTransitAI
  else
    return features.invisiblePortals.allowFatalTransit
  end
end 

function invisible_portals:traverse_portal(unit, src_tile, dst_tile)  
  self:debug("Unit %s moved from (%d, %d) to (%d, %d)",
    unit, src_tile.x, src_tile.y, dst_tile.x, dst_tile.y)
  local dest_id = self.portals[dst_tile.id]
  if not dest_id then
    if dst_tile:has_extra("Portal") then
      self:unmark_portal(dst_tile)
    end
    return
  end
  local unit_id = unit.id
  if self.traversing[unit_id] then 
    return -- Units can't traverse two portals at once
  end 
  local destination = find.tile(dest_id)
  local owner = unit.owner
  local fatal = self:fatal_transit_allowed(owner)
  local unit_string = tostring(unit)
  local unit_tag = unit.utype:name_translation()
  -- Fix for https://github.com/longturn/freeciv21/issues/2475
  local survived
  if not unit.utype:can_exist_at_tile(destination) then
    self:disembark_at_portal(unit, dst_tile)
    if fatal then
      unit:kill("nonnative_terr", NIL)
      survived = false
    else
      return
    end
  elseif destination:is_enemy(owner) then
    if fatal then
      unit:kill("killed", NIL)
      survived = false
    else
      return
    end
  else
    self.traversing[unit_id] = true
    survived = unit:teleport(destination)
    self.traversing[unit_id] = NIL
  end
  local outcome_text = survived 
    and string.format(
      "reappearing some distance away at (%d, %d)", 
      destination.x, destination.y
    ) 
    or "never to be seen again"
  local message = string.format(
    "Your %s has fallen through a tear in space at (%d, %d), %s.",
    unit_tag, dst_tile.x, dst_tile.y, outcome_text
  )
  notify.event(owner, destination, E.SCRIPT, message)
  self:mark_portal(dst_tile, destination)
  self:info("%s %s took portal from (%d, %d) to (%d, %d) and %s",
    unit_string, unit_tag, dst_tile.x, dst_tile.y, destination.x, destination.y,
    survived and "survived" or "died")
end

-- Initialise portals at map creation
function invisible_portals_initialise_portals_on_map_gen()
  invisible_portals:debug("Starting post-mapgen actions")
  invisible_portals:count_map_tiles()
  invisible_portals:create_initial_portals()
  invisible_portals:debug("Finished post-mapgen actions")
end

-- Expire old portals and create new portals at turn start
function invisible_portals_update_portals_at_tc()
  invisible_portals:debug("Starting post-TC actions")
  invisible_portals:expire_old_portals()
  invisible_portals:create_new_portals()
  invisible_portals:save_portals()
  invisible_portals:debug("Finished post-TC actions")
end

-- When a unit lands on a portal, it teleports to the destination
function invisible_portals_traverse_portal_on_enter(unit, src_tile, dst_tile)
  invisible_portals:debug("Starting post-unit-move actions")
  invisible_portals:traverse_portal(unit, src_tile, dst_tile)
  invisible_portals:debug("Finished post-unit-move actions")
end

invisible_portals:info("Initialising...")
invisible_portals:init()
signal.connect("map_generated", "invisible_portals_initialise_portals_on_map_gen")
signal.connect("turn_begin", "invisible_portals_update_portals_at_tc")
signal.connect("unit_moved", "invisible_portals_traverse_portal_on_enter")
invisible_portals:info("Initialisation complete")
space_exodus = {}

function space_exodus:early_finish_bonus()
  local target_turn = features.spaceExodus.expectedLaunchTurn
  local turns_early = target_turn - game.current_turn()
  return turns_early * features.spaceExodus.earlyFinishMultiplier
end

function space_exodus:first_place_bonus(first)
  if first then
    return features.spaceExodus.firstPlaceBonus
  else
    return 0
  end
end

function space_exodus:score(player, first)
  local civ_score = player:civilization_score()
  local early_finish_bonus = self:early_finish_bonus()
  local first_place_bonus = self:first_place_bonus(first)
  local total_score = civ_score + early_finish_bonus + first_place_bonus
  log.normal("%s won a space exodus victory with %d civilization points, " ..
      "%d early finish points, and %d position bonus, for a total of %d", 
    player,
    civ_score,
    early_finish_bonus,
    first_place_bonus,
    total_score
  )
  return total_score
end

function space_exodus:save_score(player, score)
  if (space_exodus_scores) then
    space_exodus_scores = space_exodus_scores .. ";"
  else
    space_exodus_scores = ""
  end
  space_exodus_scores = space_exodus_scores ..
      string.format("%d=%d", player.id, score)
end

function space_exodus:exodus(player)
  for unit in player:units_iterate() do
    unit:kill("disbanded")
  end
  for city in player:cities_iterate() do
    city:remove()
  end
end

function space_exodus:spaceship_launched(player, first)
  local score = self:score(player, first)
  notify.all(
    "%s has built a massive spaceship and departed in a great exodus, " .. 
        "leaving only ruins behind. Final score: %d", 
    player.name,
    score
  )
  self:save_score(player, score)
  self:exodus(player)
end

-- When a spaceship is launched, all units and cities leave the planet
function space_exodus_on_achievement_gained(achievement, gainer, first)
  if achievement:rule_name() ~= "Spaceship Launch" then return end
  space_exodus:spaceship_launched(gainer, first)
end

signal.connect("achievement_gained", "space_exodus_on_achievement_gained")

