require "defines"
require "util"

function initGlob()

  -- update every X ticks (1s = 60 ticks)
  global.updateFreq = 60

  if global.combinators == nil then
    global.combinators = {}
  end

  if global.overlayStack == nil then
    global.overlayStack = {}
  end

  global.version = "0.0.1"
end

game.on_init(function()
  initGlob()
end)

game.on_load(function()
  initGlob()
end)

function key(entity)
  return entity.position.x..":"..entity.position.y
end

function inList(pos, list)
  for _, listTile in ipairs(list) do
    if (listTile.x == pos.x) and (listTile.y == pos.y) then
      return true
    end
  end
  return false
end

function checkTile(pos, resType , listA, listB, surface)
  local tmpTile = surface.find_entities_filtered{area = {{pos.x - 0.01, pos.y - 0.01}, {pos.x + 0.01, pos.y + 0.01}}, name = resType}
  if tmpTile[1] ~= nil then
    if not inList(pos, listA) and not inList(pos, listB) then
      return tmpTile[1]
    else
      return false
    end
  else
    return false
  end
end

function getInitialResources(entity)
  local listA = {}
  local listB = {}
  local deposits = {entity}
  local startPos = entity.position
  local resType = entity.name
  local tmpPos = {x = math.floor(startPos.x) + 0.5, y = math.floor(startPos.y) + 0.5}
  local amount = entity.amount
  local tmpEntry = {}
  local surface = entity.surface
  table.insert(listA, {x =tmpPos.x, y = tmpPos.y})

  local offsets = {
    {x=0,y=-1},
    {x=0,y=1},
    {x=1,y=0},
    {x=1,y=1},
    {x=1,y=-1},
    {x=-1,y=0},
    {x=-1,y=-1},
    {x=-1,y=1}
  }

  while (#listA > 0) do
    tmpEntry = {x = listA[#listA].x, y = listA[#listA].y}
    table.remove(listA)
    table.insert(listB, tmpEntry)
    for _, pos in pairs(offsets) do
      local tmpPos = {x = tmpEntry.x + pos.x, y = tmpEntry.y + pos.y}
      local ent = checkTile(tmpPos, resType, listA, listB, surface)
      if ent then
        table.insert(listA, tmpPos)
        table.insert(deposits, ent)
        amount = amount + ent.amount
      end
    end
  end

  return deposits, amount
end

function setValue(combinator)
  local ent = combinator.entity
  local para = {parameters={
    {signal={type = "item", name = combinator.resourceType}, count = combinator.amount, index = 1}}}
  if combinator.flow and combinator.flow > 0 then
    combinator.flow = math.ceil(combinator.flow)
    table.insert(para.parameters, {signal={type = "fluid", name = "crude-oil"}, count = combinator.flow, index = 2})
    table.insert(para.parameters, {signal={type = "item", name = "pumpjack"}, count = #combinator.oilWells, index = 3})
  end
  ent.set_circuit_condition(1, para)
end

function updateValues()
  local status, err = pcall(function()
    for k, combinator in pairs(global.combinators) do
      combinator.amount = 0
      if combinator.entity and combinator.entity.valid then
        for i=#combinator.oreDeposits,1,-1 do
          local deposit = combinator.oreDeposits[i]
          if deposit and deposit.valid and deposit.amount > 0 then
            combinator.amount = combinator.amount + deposit.amount
          else
            table.remove(combinator.oreDeposits, i)
          end
        end
        if combinator.oilWells then
          combinator.flow = 0
          for i=#combinator.oilWells,1,-1 do
            local deposit = combinator.oilWells[i]
            if deposit and deposit.valid and deposit.amount > 0 then
              combinator.flow = combinator.flow + deposit.amount
            else
              table.remove(combinator.oilWells, i)
            end
          end
          combinator.flow = combinator.flow / 750
        end
        setValue(combinator)
      end
    end
  end)
  if not status then
    debugDump(err, true)
  end
end

function createCombinator(event)
  local status, err = pcall(function()
    if event.created_entity.name == "resource-combinator-proxy" or event.created_entity.name == "resource-combinator" then
      local entity = event.created_entity
      local force = entity.force
      local pos ={x = entity.position.x, y = entity.position.y}
      local surface = entity.surface
      if entity.name == "resource-combinator-proxy" then
        entity.destroy()
        entity = surface.create_entity{name = "resource-combinator", position = pos, direction=0, force=force}
      end
      entity.operable = false
      local range = 0.01
      local ent = surface.find_entities_filtered{area = {{pos.x - range, pos.y - range}, {pos.x + range, pos.y + range}}, type="resource"}
      range = 5.5
      local ent2 = surface.find_entities_filtered{area = {{pos.x - range, pos.y - range}, {pos.x + range, pos.y + range}}, type="resource"}
      if #ent2 == 0 then
        return
      end
      local k = key(entity)
      global.combinators[k] = {oreDeposits = {}, amount = 0, resourceType = "", flow = 0, oilWells = {}}
      if (#ent > 0 or #ent2 > 0) then
        if #ent == 0 then
          ent = ent2
        end
        local found = false
        for i, e in pairs(ent) do
          if not found and e.prototype.resource_category == "basic-solid" and util.distance(e.position, entity.position) <= 1.5 then
            local ore = addOreField(e)
            global.combinators[k].oreDeposits = ore.oreDeposits
            global.combinators[k].amount = ore.amount
            global.combinators[k].resourceType = ore.resourceType
            found = true
          end
        end
        local tick = game.tick + 60*5
        global.overlayStack[tick] = global.overlayStack[tick] or {}
        for i,e in pairs(ent2) do
          if e.prototype.resource_category == "basic-fluid" and e.name == "crude-oil" then
            table.insert(global.combinators[k].oilWells, e)
            global.combinators[k].flow = global.combinators[k].flow + e.amount
            local overlay = surface.create_entity{name="rm_overlay", position = e.position}
            overlay.minable = false
            overlay.destructible = false
            table.insert(global.overlayStack[tick], overlay)
          end
        end
        global.combinators[k].entity = entity
        if global.combinators[k].flow > 0 then
          global.combinators[k].flow = global.combinators[k].flow / 750
        end
        setValue(global.combinators[k])
      end
    end
  end)
  if not status then
    debugDump(err, true)
  end
end

function addOreField(entity)
  local tmpResType = entity.name
  local oreDeposit, tmpAmount = getInitialResources(entity)
  local surface = entity.surface
  local tick = game.tick + 60*1
  global.overlayStack[tick] = {}
  for _, ent in pairs(oreDeposit) do
    local tmpPos = ent.position
    local tmpTile = surface.find_entities_filtered{area = {{tmpPos.x - 0.01, tmpPos.y - 0.01}, {tmpPos.x + 0.01, tmpPos.y + 0.01}}, name = tmpResType}
    local overlay = surface.create_entity{name="rm_overlay", position = tmpPos}
    overlay.minable = false
    overlay.destructible = false

    table.insert(global.overlayStack[tick], overlay)
  end
  return {oreDeposits = oreDeposit, amount = tmpAmount, resourceType = tmpResType}
end

function removeCombinator(event)
  if event.entity.name == "resource-combinator" then
    global.combinators[key(event.entity)] = nil
  end
end

game.on_event(defines.events.on_built_entity, createCombinator)
game.on_event(defines.events.on_robot_built_entity, createCombinator)

game.on_event(defines.events.on_entity_died, removeCombinator)
game.on_event(defines.events.on_preplayer_mined_item, removeCombinator)
game.on_event(defines.events.on_robot_pre_mined, removeCombinator)

game.on_event(defines.events.on_tick, function(event)
  if global.overlayStack and global.overlayStack[event.tick] then
    local tick = event.tick
    for _, overlay in pairs(global.overlayStack[tick]) do
      if overlay.valid then
        overlay.destroy()
      end
    end
    global.overlayStack[event.tick] = nil
  end
  if game.tick % global.updateFreq == 11 then
    updateValues()
  end
  if game.tick % 600 == 13 then
    for i, overlays in pairs(global.overlayStack) do
      if i < event.tick then
        for _, overlay in pairs(overlays) do
          if overlay.valid then
            overlay.destroy()
          end
        end
        global.overlayStack[i] = nil
      end
    end
  end
end)

function debugDump(var, force)
  if false or force then
    for i,player in ipairs(game.players) do
      local msg
      if type(var) == "string" then
        msg = var
      else
        msg = serpent.dump(var, {name="var", comment=false, sparse=false, sortkeys=true})
      end
      player.print(msg)
    end
  end
end

function saveVar(var, name)
  local var = var or global
  local n = name or ""
  game.makefile("resCom"..n..".lua", serpent.block(var, {name="glob"}))
end

remote.add_interface("resource-combinator",
  {
    saveVar = function(name)
      saveVar(global, name)
    end
  })
