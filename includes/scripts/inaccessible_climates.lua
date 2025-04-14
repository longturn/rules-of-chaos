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

