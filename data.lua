function copyPrototype(type, name, newName)
  if not data.raw[type][name] then error("type "..type.." "..name.." doesn't exist", 2) end
  local p = table.deepcopy(data.raw[type][name])
  p.name = newName
  if p.minable and p.minable.result then
    p.minable.result = newName
  end
  if p.place_result then
    p.place_result = newName
  end
  if p.result then
    p.result = newName
  end
  return p
end

local item = copyPrototype("item","constant-combinator","resource-combinator")
item.icon = "__ResourceCombinator__/graphics/resource-combinator.png"
item.order = "b[combinators]-c[resource-combinator]"

local ent = copyPrototype("constant-combinator","constant-combinator","resource-combinator")
ent.sprite.filename = "__ResourceCombinator__/graphics/constanter.png"
ent.minable.result = "resource-combinator-proxy"

local recipe = copyPrototype("recipe","constant-combinator","resource-combinator")
recipe.hidden = true
recipe.enabled = false

data:extend({item, ent})

local proxy_i = copyPrototype("item", "small-electric-pole", "resource-combinator-proxy")
proxy_i.icon = item.icon
proxy_i.subgroup = "circuit-network"
proxy_i.order = item.order

local proxy_e = copyPrototype("constant-combinator", "resource-combinator", "resource-combinator-proxy")
proxy_e.type = "electric-pole"
proxy_e.sprite = nil
proxy_e.circuit_wire_connection_point = nil
proxy_e.item_slot_count = nil
proxy_e.pictures = ent.sprite
proxy_e.pictures.direction_count = 1
proxy_e.maximum_wire_distance = 0
proxy_e.supply_area_distance = 6.5
proxy_e.connection_points = {{shadow={copper={0,0},red={0,0},green={0,0}},wire={copper={0,0},red={0,0},green={0,0}}}}
proxy_e.radius_visualisation_picture =
  {
    filename = "__ResourceCombinator__/graphics/radius-visualization.png",
    width = 12,
    height = 12,
    priority = "extra-high-no-scale"
  }

data:extend({recipe, proxy_i, proxy_e})
local proxy_r = copyPrototype("recipe", "resource-combinator", "resource-combinator-proxy")
proxy_r.hidden = false

data:extend({proxy_r})

table.insert(data.raw.technology["circuit-network"].effects, {type="unlock-recipe", recipe="resource-combinator-proxy"})

data:extend({{
  type = "container",
  name = "rm_overlay",
  icon = "__ResourceCombinator__/graphics/rm_Overlay.png",
  flags = {"placeable-neutral", "player-creation"},
  minable = {mining_time = 1, result = "resource-combinator"},
  order = "b[rm_overlay]",
  collision_mask = {"resource-layer"},
  max_health = 100,
  corpse = "small-remnants",
  resistances ={{type = "fire",percent = 80}},
  collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
  selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
  inventory_size = 1,
  picture =
  {
    filename = "__ResourceCombinator__/graphics/rm_Overlay.png",
    priority = "extra-high",
    width = 32,
    height = 32,
    shift = {0.0, 0.0}
  }
}})
