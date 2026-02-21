sizeData = {
  {id=1, name='King of the Colosseum - 36" x 36"', width=36, height=36},
  {id=2, name='Combat Patrol - 44" x 30"', width=44, height=30},
  {id=3, name='Incursion - 44" x 60"', width=44, height=60},
  {id=4, name='Strike Force - 44" x 60"', width=44, height=60},
  {id=5, name='Onslaught - 44" x 90"', width=44, height=90},
}

mapSizeSelected = 4
playAreaGuid = nil

function onLoad(saved_state)
  if saved_state and saved_state ~= "" then
    local decoded = JSON.decode(saved_state)
    if decoded then
      mapSizeSelected = tonumber(decoded.mapSizeSelected) or mapSizeSelected
      playAreaGuid = decoded.playAreaGuid
    end
  end

  clampSizeSelected()
  applyPlayAreaSize()
  writeMenu()
end

function onSave()
  return JSON.encode({
    mapSizeSelected = mapSizeSelected,
    playAreaGuid = playAreaGuid,
  })
end

function clampSizeSelected()
  if mapSizeSelected < 1 then
    mapSizeSelected = #sizeData
  end
  if mapSizeSelected > #sizeData then
    mapSizeSelected = 1
  end
end

function writeMenu()
  local host = getOrCreatePlayArea()
  if not host then
    return
  end
  host.clearButtons()

  local selected = sizeData[mapSizeSelected]
  local menuY = 0.22
  local menuZ = -(selected.height * 0.28)
  local arrowOffset = 12

  host.createButton({
    label="S E L E C T     B A T T L E F I E L D     S I Z E",
    click_function="none",
    function_owner=self,
    position={0, menuY, menuZ - 8},
    rotation={0,0,0},
    height=1200,
    width=18000,
    font_size=850,
    color={0.08, 0.08, 0.08},
    font_color={1,1,1},
    tooltip=""
  })

  host.createButton({
    label=sizeData[mapSizeSelected].name,
    click_function="none",
    function_owner=self,
    position={0, menuY, menuZ},
    rotation={0,0,0},
    height=1100,
    width=14000,
    font_size=900,
    color={0.92, 0.92, 0.92},
    font_color={0.04, 0.04, 0.04},
    tooltip=""
  })

  host.createButton({
    label="▼",
    click_function="sizeDown",
    function_owner=self,
    position={-arrowOffset, menuY, menuZ},
    rotation={0,0,0},
    height=1100,
    width=1700,
    font_size=1200,
    color={0.22, 0.22, 0.22},
    font_color={1,1,1},
    tooltip="Previous size"
  })

  host.createButton({
    label="▲",
    click_function="sizeUp",
    function_owner=self,
    position={arrowOffset, menuY, menuZ},
    rotation={0,0,0},
    height=1100,
    width=1700,
    font_size=1200,
    color={0.22, 0.22, 0.22},
    font_color={1,1,1},
    tooltip="Next size"
  })

  host.createButton({
    label="A P P L Y",
    click_function="applySizeFromMenu",
    function_owner=self,
    position={0, menuY, menuZ + 8},
    rotation={0,0,0},
    height=1000,
    width=6000,
    font_size=850,
    color={0.1, 0.55, 0.2},
    font_color={1,1,1},
    tooltip="Apply selected battlefield size to center play area"
  })
end

function none()
end

function sizeUp(_, _)
  mapSizeSelected = mapSizeSelected + 1
  clampSizeSelected()
  applyPlayAreaSize()
  writeMenu()
end

function sizeDown(_, _)
  mapSizeSelected = mapSizeSelected - 1
  clampSizeSelected()
  applyPlayAreaSize()
  writeMenu()
end

function applySizeFromMenu(_, _)
  applyPlayAreaSize()
  writeMenu()
end

function getOrCreatePlayArea()
  local current = nil

  if playAreaGuid then
    current = getObjectFromGUID(playAreaGuid)
  end

  if current then
    return current
  end

  local tablePos = self.getPosition()
  current = spawnObject({
    type = "BlockSquare",
    position = {tablePos.x, tablePos.y + 0.18, tablePos.z},
    rotation = {0, 0, 0},
    scale = {44, 0.08, 60},
    sound = false,
  })

  current.setName("Play Area")
  current.setDescription("Warhammer 40k 10th Edition battlefield area")
  current.setColorTint({0.12, 0.14, 0.18})
  current.setLock(true)
  current.interactable = true

  playAreaGuid = current.getGUID()
  return current
end

function applyPlayAreaSize()
  local entry = sizeData[mapSizeSelected]
  local area = getOrCreatePlayArea()
  if not area then
    return
  end

  local tablePos = self.getPosition()
  area.setPositionSmooth({tablePos.x, tablePos.y + 0.18, tablePos.z}, false, false)
  area.setScale({entry.width, 0.08, entry.height})
  area.setName("Play Area - " .. entry.name)
end
