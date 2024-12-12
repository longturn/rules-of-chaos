-- Initialise global scalar for persistent portal data
function init_invisible_portals()
  local density = 1 / 37
  local half_life = 8
  
  local collapse_chance = 1 - 2^(-1 / half_life)
  local form_chance = (density * collapse_chance) / (1 - density)

  return {
    initial_density_freq = density * 1000000,
    initial_density_range = 1000000,
    collapse_chance_freq = collapse_chance * 1000000,
    collapse_chance_range = 1000000,
    form_chance_freq = form_chance * 1000000,
    form_chance_range = 1000000,
    portals = {}
  }
end

-- Create a new portal on a tile
function create_portal(tile)
  portals[tile.id] = random(1, invisible_portals.tile_count)
end

-- Set up initial portals at map creation
function create_initial_portals_after_mapgen()
  -- Count how many tiles are in the map
  local tile_count = 0
  for tile in whole_map_iterate() do
    tile_count++
  end
  invisible_portals.tile_count = tile_count
  -- Place initial portals
  local range = invisible_portals.initial_density_range
  local freq = invisible_portals.initial_density_freq
  for tile in whole_map_iterate() do
    if random(0, range) < freq then
      create_portal(tile)
    end
  end
end

-- New portals form over time
function create_new_portals()
  local portals = invisible_portals.portals
  local range = invisible_portals.form_chance_range
  local freq = invisible_portals.form_chance_freq
  for tile in whole_map_iterate() do
    local destination = portals[tile.id]
    if not destination and random(0, range) < freq then
      create_portal(tile)
    end
  end
end

-- Existing portals have a chance to collapse each turn
function expire_old_portals()
  local range = invisible_portals.collapse_chance_range
  local freq = invisible_portals.collapse_chance_freq
  for source, destination in pairs(invisible_portals.portals) do
    if random(0, range) < freq then
      destroy_portal(source)
    end
  end
end

-- Expire old portals and create new portals at turn start
function update_portals_at_tc()
  expire_old_portals()
  create_new_portals()
end

-- When a unit lands on a portal, it teleports to the destination
function traverse_portal_on_enter(unit, src_tile, dst_tile)
  local portals = invisible_portals.portals
  local destination = find.tile(portals[dst_tile.id])
  if destination then
    local owner = unit.owner
    local survived = unit:teleport(destination)
    if survived then
      notify.event(owner, destination, "E_SCRIPT", 
        "Your unit has fallen through a tear in space" .. 
        ", reappearing some distance away.")
    else
      notify.event(owner, destination, "E_SCRIPT", 
        "Your unit has fallen through a tear in space" .. 
        ", never to be seen again.")
    end
  end
end

if invisible_portals == NIL then
  invisible_portals = init_invisible_portals()
end

signal.connect("map_generated", "create_initial_portals_after_mapgen")
signal.connect("turn_begin", "update_portals_at_tc")
signal.connect("unit_moved", "traverse_portal_on_enter")
