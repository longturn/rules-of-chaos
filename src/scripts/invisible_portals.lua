-- Initialise global namespace for portal data
invisible_portals = {
  density = 1 / 37,
  half_life = 8
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
  local collapse_chance = 1 - 2^(-1 / self.half_life)
  local form_chance = (self.density * collapse_chance) / (1 - self.density)
    self.initial_density_freq = math.floor(self.density * 1000000)
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
  self:debug("%d portals saved: %s", 
    self:portal_count(), invisible_portals_data)
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

function invisible_portals:traverse_portal(unit, src_tile, dst_tile)  
  self:debug("Unit %s moved from (%d, %d) to (%d, %d)",
    unit, src_tile.x, src_tile.y, dst_tile.x, dst_tile.y)
  local dest_id = self.portals[dst_tile.id]
  if not dest_id then return end
  local destination = find.tile(dest_id)
  local owner = unit.owner
  local survived = unit:teleport(destination)
  if survived then
    notify.event(owner, destination, E.SCRIPT, 
      "Your unit has fallen through a tear in space" .. 
      ", reappearing some distance away.")
  else
    notify.event(owner, destination, E.SCRIPT, 
      "Your unit has fallen through a tear in space" .. 
      ", never to be seen again.")
  end
  self:info("Unit %s took portal from (%d, %d) to (%d, %d) and %s",
    unit, src_tile.x, src_tile.y, dst_tile.x, dst_tile.y,
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
