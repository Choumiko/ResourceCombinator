require "defines"

function initGlob()

  global.resourceMonitor = nil

  -- update every X ticks (1s = 60 ticks)
  global.updateFreq = 60

  if global.combinators == nil then
    global.combinators = {}
  end

  if global.fields == nil then
    global.fields = {}
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

function isInSolidList(resource_category)
  for _, category in ipairs (global.resourceSolidList) do
    if resource_category == category then
      return true
    end
  end
  return false
end

function setValue(entity, name, count)
  entity.set_circuit_condition(1, {parameters={
    {signal={type = "item", name = name}, count = count, index = 1}}})
end

function updateValues()
  for k, combinator in pairs(global.combinators) do
    combinator.amount = 0
    if combinator.entity.valid then
      for i=#combinator.oreDeposits,1,-1 do
        local deposit = combinator.oreDeposits[i]
        if deposit and deposit.valid and deposit.amount > 0 then
          combinator.amount = combinator.amount + deposit.amount
        else
          table.remove(combinator.oreDeposits, i)
        end
      end
      setValue(combinator.entity, combinator.resourceType, combinator.amount)
    end
  end
end

function createCombinator(event)
  if event.created_entity.name == "resource-combinator" then
    event.created_entity.operable = false
    local surface = event.created_entity.surface
    local pos ={x = event.created_entity.position.x, y = event.created_entity.position.y}
    local ent = surface.find_entities_filtered{area = {{pos.x - 0.01, pos.y - 0.01}, {pos.x + 0.01, pos.y + 0.01}}, type="resource"}
    if (#ent > 0) and ((ent[1].prototype.resource_category == "basic-solid") or (isInSolidList(ent[1].prototype.resource_category))) then
      local k = key(event.created_entity)
      global.combinators[k] = addCombinator(ent[1])
      global.combinators[k].entity = event.created_entity
      setValue(event.created_entity, global.combinators[k].resourceType, global.combinators[k].amount)
    end
  end
end

function addCombinator(entity)
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
    end,
    addResource = function(newCategory, type)
      if type == "solid" then
        for _, category in ipairs (global.resourceSolidList) do
          if category == newCategory then
            return false
          end
        end
        table.insert(global.resourceSolidList, newCategory)
        return true
      elseif type == "liquid" then
        for _, category in ipairs (global.resourceLiquidList) do
          if category == newCategory then
            return false
          end
        end
        table.insert(global.resourceLiquidList, newCategory)
        return true
      else
        return false
      end
    end,
  })
