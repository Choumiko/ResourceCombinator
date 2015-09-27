require "defines"
require "util"

function initGlob()

  -- update every X ticks (1s = 60 ticks)
  global.updateFreq = 60
  -- output as oil per x sec
  global.oilPer = 60

  if global.combinators == nil then
    global.combinators = {}
  end
  global.version = global.version or "0.0.1"
  
  if global.overlayStack == nil then
    global.overlayStack = {}
  end
  global.nextIndex = global.nextIndex or 1
  global.ticklist = global.ticklist or {}

  if global.updateFreq < 30 then
    global.updateFreq = 30
  end
  global.oilPer = 1/7500* global.oilPer

  if global.version < "0.0.2" then
    --    global.ticklist = {}
    --    global.nextIndex = 1
    --    for k, comb in pairs(global.combinators) do
    --      global.ticklist[global.nextIndex] = global.ticklist[global.nextIndex] or {}
    --      global.ticklist[global.nextIndex][k] = global.combinators[k]
    --      global.nextIndex = (global.nextIndex + 1) % 30
    --      if global.nextIndex == 0 then
    --        global.nextIndex = 1
    --      end
    --    end
    for k, comb in pairs(global.combinators) do
      if comb.oilWells then
        for _, well in pairs(comb.oilWells) do
          local pos = well.position
          local range = 0.25
          local jacks = well.surface.find_entities_filtered{area = {{pos.x - range, pos.y - range}, {pos.x + range, pos.y + range}}, name="pumpjack"}
          if #jacks == 1 then
            addPumpjack({created_entity = jacks[1]})
          end
        end
      end
    end
    global.version = "0.0.2"
  end

  if global.version < "0.0.3" then
    for k, comb in pairs(global.combinators) do
      comb.oilWells = comb.oilWells or {}
      comb.jacks = 0
      if comb.pumpjacks then
        for _, jack in pairs(comb.pumpjacks) do
          jack.speed = 1
          comb.jacks = comb.jacks + 1
          local modules = jack.entity.get_inventory(defines.inventory.mining_drill_modules).get_contents()
          for module, c in pairs(modules) do
            --debugDump({module,c},true)
            local prototype = game.item_prototypes[module]
            if module and prototype.module_effects and prototype.module_effects["speed"] then
              jack.speed = jack.speed + prototype.module_effects["speed"].bonus*c
            end
          end
        end
      else
        comb.pumpjacks = {}
      end
    end
    global.version = "0.0.3"
  end

  global.version = "0.0.3"
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
  local oilPer = global.oilPer
  local para = {parameters={
    {signal={type = "item", name = combinator.resourceType}, count = combinator.amount, index = 1}}}
  if combinator.flow and combinator.flow > 0 then
    local flow = math.ceil(combinator.flow * oilPer)
    table.insert(para.parameters, {signal={type = "fluid", name = "crude-oil"}, count = flow, index = 2})
    table.insert(para.parameters, {signal={type = "item", name = "pumpjack"}, count = combinator.jacks, index = 3})
    if combinator.pumped and combinator.pumped > 0 then
      local pumped = math.ceil(combinator.pumped * oilPer)
      table.insert(para.parameters, {signal={type = "virtual", name = "signal-oil-speed"}, count = pumped, index = 4})
    end
  end
  ent.set_circuit_condition(1, para)
end

function updateValues()
  local status, err = pcall(function()
    for k, combinator in pairs(global.combinators) do
      combinator.amount = 0
      if combinator.entity and combinator.entity.valid then
        --for i=#combinator.oreDeposits,1,-1 do
        for i, deposit in pairs(combinator.oreDeposits) do
          --local deposit = combinator.oreDeposits[i]
          if deposit and deposit.valid and deposit.amount > 0 then
            combinator.amount = combinator.amount + deposit.amount
          else
            --table.remove(combinator.oreDeposits, i)
            combinator.oreDeposits[i] = nil
          end
        end
        combinator.flow = 0
        combinator.pumped = 0
        if combinator.pumpjacks then
          for k, jack in pairs(combinator.pumpjacks) do
            if jack.entity and jack.entity.valid and jack.well and jack.well.valid then
              local amount = jack.well.amount
              combinator.pumped = combinator.pumped + (amount * jack.speed)
              combinator.flow = combinator.flow + amount
            else
              combinator.pumpjacks[k] = nil
            end
          end
        end
        setValue(combinator)
      end
    end
  end)
  if not status then
    debugDump(err, true)
  end
end

function updateValues2(index)
  local status, err = pcall(function()
    if not global.ticklist[index] then
      return
    end
    --debugDump(game.tick.."-"..index.."#"..#global.ticklist[index],true)
    if not global.debug then global.debug = {} end
    if #global.debug < 500 then
      table.insert(global.debug, game.tick..":"..index)
    else
      global.debug = {}
    end

    for k, combinator in pairs(global.ticklist[index]) do
      --debugDump(game.tick.." "..k,true)
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

function on_built_entity(event)
  local status, err = pcall(function()
    local ent = event.created_entity
    if ent.name == "resource-combinator-proxy" or ent.name == "resource-combinator" then
      createCombinator(event)
    elseif ent.name == "pumpjack" then
      addPumpjack(event)
    end
  end)
  if not status then
    debugDump(err, true)
  end
end

function addPumpjack(event)
  local ent = event.created_entity
  local pos = ent.position
  for k, comb in pairs(global.combinators) do
    if comb.oilWells then
      for _, well in pairs(comb.oilWells) do
        local wpos = {x=math.floor(well.position.x)+0.5,y=math.floor(well.position.y)+0.5}
        if wpos.x == pos.x and wpos.y == pos.y then
          addPumpjackToCombinator(comb, ent, well)
          return
        end
      end
    end
  end
end

function addPumpjackToCombinator(comb, jack, well)
  comb.flow = comb.flow or 0
  comb.pumped = comb.pumped or 0
  comb.jacks = comb.jacks or 0
  local speed = 1
  comb.pumpjacks = comb.pumpjacks or {}
  if comb.pumpjacks[key(jack)] and comb.jacks > 0 then
    comb.jacks = comb.jacks - 1
  end
  comb.pumpjacks[key(jack)] = {entity = jack, well = well, speed = speed}
  comb.jacks = comb.jacks + 1
  comb.pumped = comb.pumped + (well.amount*speed)
  comb.flow = comb.flow + well.amount
end

function createCombinator(event)
  --  debugDump("a",true)
  --  local status, err = pcall(function()
  --    if event.created_entity.type == "entity-ghost" and event.created_entity.ghost_prototype.name == "resource-combinator" then
  --      debugDump("h",true)
  --      local entity = event.created_entity
  --      local force = entity.force
  --      local pos ={x = entity.position.x, y = entity.position.y}
  --      local surface = entity.surface
  --      event.created_entity.destroy()
  --      local new_entity = {
  --        name = "entity-ghost",
  --        inner_name = "resource-combinator-proxy",
  --        position = pos,
  --        direction = 0,
  --        force = force
  --      }
  --      surface.create_entity(new_entity)
  --      return
  --    end
  --  end)
  --  if not status then
  --    debugDump(err, true)
  --    return
  --  end
  --  debugDump("h1",true)
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
      global.combinators[k] = {oreDeposits = {}, amount = 0, resourceType = "", flow = 0, oilWells = {}, pumped = 0, jacks = 0, pumpjacks = {}}
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
            local overlay = surface.create_entity{name="rm_overlay", position = e.position}
            overlay.minable = false
            overlay.destructible = false
            table.insert(global.overlayStack[tick], overlay)
            --find pumpjacks
            local pos = e.position
            local range = 0.2
            local jacks = surface.find_entities_filtered{area = {{pos.x - range, pos.y - range}, {pos.x + range, pos.y + range}}, name="pumpjack"}
            if #jacks == 1 then
              global.combinators[k].flow = global.combinators[k].flow + e.amount
              addPumpjackToCombinator(global.combinators[k], jacks[1], e)
            end
          end
        end
        global.combinators[k].entity = entity
        setValue(global.combinators[k])
        --        global.ticklist[global.nextIndex] = global.ticklist[global.nextIndex] or {}
        --        global.ticklist[global.nextIndex][k] = global.combinators[k]
        --        global.nextIndex = (global.nextIndex + 1) % 30
        --        if global.nextIndex == 0 then
        --          global.nextIndex = 1
        --        end
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

function on_premined_entity(event)
  if event.entity.name == "resource-combinator" then
    global.combinators[key(event.entity)] = nil
  elseif event.entity.name == "pumpjack" then
    local k = key(event.entity)
    for _, comb in pairs(global.combinators) do
      if comb.pumpjacks and comb.pumpjacks[k] then
        comb.pumpjacks[k] = nil
        comb.jacks = comb.jacks - 1
        return
      end
    end
  end
end

game.on_event(defines.events.on_built_entity, on_built_entity)
game.on_event(defines.events.on_robot_built_entity, on_built_entity)

game.on_event(defines.events.on_entity_died, on_premined_entity)
game.on_event(defines.events.on_preplayer_mined_item, on_premined_entity)
game.on_event(defines.events.on_robot_pre_mined, on_premined_entity)

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
  local range = game.tick % global.updateFreq
  if range == 11 then
    updateValues()
  end

  if game.tick % 300 == 12 then
    for _, comb in pairs(global.combinators) do
      if comb.pumpjacks then
        for _1, jack in pairs(comb.pumpjacks) do
          jack.speed = 1
          local modules = jack.entity.get_inventory(defines.inventory.mining_drill_modules).get_contents()
          for module, c in pairs(modules) do
            --debugDump({module,c},true)
            local prototype = game.item_prototypes[module]
            if module and prototype.module_effects and prototype.module_effects["speed"] then
              jack.speed = jack.speed + prototype.module_effects["speed"].bonus*c
            end
          end
        end
      end
    end
  end
  --  if range >= 11 and range < 40 then
  --    updateValues2(range-10)
  --  end
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
