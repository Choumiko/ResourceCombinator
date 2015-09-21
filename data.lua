function copyPrototype(type, name, newName)
  if not data.raw[type][name] then error("type "..type.." "..name.." doesn't exist") end
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
local recipe = copyPrototype("recipe","constant-combinator","resource-combinator")

data:extend({item, ent, recipe})
table.insert(data.raw.technology["circuit-network"].effects, {type="unlock-recipe", recipe="resource-combinator"})

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
