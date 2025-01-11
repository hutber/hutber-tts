-- FTC-GUID: 863da2, 863da8

currentSelection = {}
weaponColors = {}
spawnedDiceCount = 0
savedPositions = {}
customDieData = nil

function onSave()
  return JSON.encode(uiData)
end

function onLoad()
  addHotkey('Save position', savePositionClicked)
  addHotkey('Restore position', restorePositionClicked)
  self.addContextMenuItem("Set Custom Dice", onSetCustomDiceClicked)
  self.addContextMenuItem("Reset Custom Dice", onResetCustomDiceClicked)
end

function onResetCustomDiceClicked()
  customDieData = nil
  printMessage("Custom die data reset complete!")
end

function onSetCustomDiceClicked()
  local die = findCustomDie()
  if die == nil then
    printMessage("Place your die in the white zone")
  else
    saveCustomDie(die)
    die.destruct()
    printMessage("Custom Die successfully configured!")
  end
end

function findCustomDie()
  local cast = Physics.cast({
    debug = true,
    direction = {0, -1, 0},
    origin = self.positionToWorld({0, 3, 8}),
    type = 3,
    size = {4, 1, 4}
  })

  for i,v in ipairs(cast) do
    if v.hit_object.tag == "Dice" then
      return v.hit_object
    end
  end
end

function saveCustomDie(die)
  customDieData = {}
  customDieData.colorTint = die.getColorTint()
  customDieData.image = die.getCustomObject().image
end

function savePositionClicked(playerColor, hoveredObject)
  savedPositions = {}
  local objects = getObjectsPositionToSave(Player[playerColor], hoveredObject)

  if objects != nil then
    for i,v in ipairs(objects) do
      savePosition(v)
    end
    printToColor(#objects..' objects positions saved!', playerColor)
  end
end

function restorePositionClicked(playerColor)
  for i,v in ipairs(savedPositions) do
    local obj = getObjectFromGUID(v.guid)
    if obj != nil then
      obj.setRotation(v.rotation)
      obj.setPositionSmooth(v.position, false, true)
    end
  end
end

function getObjectsPositionToSave(player, hoveredObject)
  if #player.getSelectedObjects() != 0 then
    return player.getSelectedObjects()
  elseif hoveredObject != nil then
    return table.insert({}, hoveredObject)
  end
  return nil
end

function savePosition(obj)
  table.insert(savedPositions, {
    guid = obj.getGUID(),
    position = obj.getPosition(),
    rotation = obj.getRotation()
  })
end

function setCurrentSelection(player)
  if (#player.getSelectedObjects() == 0) then
    printMessage("Select some models first!")
    return false
  end
  currentSelection = player.getSelectedObjects()
  return true
end

function onCountClicked(player)
  cleanUpWeaponsData()
  if setCurrentSelection(player) then
    drawWeaponData(player.getSelectedObjects())
  end
end

function onShowRangeEditEnd(player, value, id)
  cleanCurrentVectorLines()
  if setCurrentSelection(player) then
    drawFiguresRange(currentSelection, tonumber(value))
  end
end

function onCleanClicked(player)
  if (#player.getSelectedObjects() != 0) then
    currentSelection = player.getSelectedObjects()
  end
  cleanCurrentVectorLines()
end

function cleanUpWeaponsData()
  drawWeaponData({})
  spawnedDiceCount = 0
end

function drawFiguresRange(figures, range)
  for i,v in ipairs(figures) do
    drawFigureRange(range, v)
  end
end

function cleanCurrentVectorLines()
  for i,v in ipairs(currentSelection) do
    v.setVectorLines({})
  end
end

function drawWeaponData(figures)
  drawWeaponsDataUI(createWeaponsMap(createFiguresData(figures)))
end

function drawWeaponsDataUI(weaponMap)
  local ui = self.UI.getXmlTable()
  ui[2].children[3].children = createWeaponTableRows(weaponMap)
  self.UI.setXmlTable(ui)
end

function createWeaponTableRows(weaponMap)
  local result = {}
  for i,v in pairs(weaponMap) do
    table.insert(result, createWeaponRowUI(v))
  end
  return result
end

function createWeaponRowUI(weaponData)
  return {
    tag = "Row",
    attributes = {
      preferredHeight = 130
    },
    children = {
      createTextCell(weaponData.data.name),
      createTextCell(weaponData.data.stats),
      createTextCell(weaponData.count),
      createButtonCell(getAttackInfo(weaponData), "attackButton_"..weaponData.data.name, "onAttackClicked"),
      createButtonCell(getRangeText(weaponData.data.range), "rangeButton_"..weaponData.data.name, "onRangeClicked"),
    }
  }
end

function getAttackInfo(weaponData)
  local result = "";
  if weaponData.attack != 0 then
    result = result..tostring(weaponData.attack)
  end
  if weaponData.data.bonusAttack then
    local pref = weaponData.count > 1 and weaponData.count..'*' or ''
    return pref..weaponData.data.bonusAttack
  end
  return result
end

function spawnDices(count, color, name, offset)
  local ratioX = math.cos(math.rad(self.getRotation()[2]))
  local ratioY = math.sin(math.rad(self.getRotation()[2]))
  local rowSize = 20
  for i = 1, count do
    local column = (i + offset - 1) % rowSize + 1
    local row = math.ceil((i + offset) / rowSize)
    local x = self.getPosition()[1] + column * ratioX + ratioY * (3 + row)
    local z = self.getPosition()[3] + (3 + row) * ratioX - column * ratioY
    local die = spawnObject({
      type = getDiceType(),
      position = {x, self.getPosition()[2] + 1, z},
      callback_function = function(dice)
        setDieTint(dice, color)
        dice.setName(name)
      end
    })
    setDieCustomObject(die)
  end
end

function setDieCustomObject(die)
  if customDieData and customDieData.image then
    die.setCustomObject({
      image = customDieData.image,
      type = 1
    })
  end
end

function setDieTint(die, color)
  local customTint = customDieData and customDieData.colorTint
  die.setColorTint(customTint or color)
end

function getDiceType()
  if customDieData and customDieData.image then
    return "Custom_Dice"
  end

  return "Die_6"
end

function onAttackClicked(player, _, id)
  if (#currentSelection == 0) then
    return
  end
  spawnDicesForWeaponByFigures((splitStr(id, "_")[2]), currentSelection)
end

function spawnDicesForWeaponByFigures(name, figures)
  local weaponMap = createWeaponsMap(createFiguresData(figures))
  if weaponMap[name] != nil then
    spawnDicesForWeapon(weaponMap[name])
  end
end

function spawnDicesForWeapon(weaponMapData)
  local attacks = getWeaponMapAttacks(weaponMapData)
  spawnDices(attacks, getWeaponColor(weaponMapData.data.name), getWeaponDescription(weaponMapData.data), spawnedDiceCount)
  spawnedDiceCount = spawnedDiceCount + attacks
end

function getWeaponMapAttacks(weaponMapData)
  if weaponMapData.data.bonusAttack then
    return getBonusAttackValueForCount(weaponMapData.data.bonusAttack, weaponMapData.count)
  end
  return weaponMapData.attack
end

function getBonusAttackValueForCount(bonusAttack, count)
  local result = 0
  for i = 1, count do
    result = result + getBonusAttackValue(bonusAttack)
  end
  return result
end

function getBonusAttackValue(bonusAttack)
  local appendums = splitStr(bonusAttack, "+")
  local result = 0
  for i,app in ipairs(appendums) do
    result = result + getBonusAttackAppendum(app)
  end
  return result
end

function getBonusAttackAppendum(appendum)
  if tonumber(appendum) != nil then
    return tonumber(appendum)
  end
  if string.find(appendum, "D") != nil then
    local split = splitStr(appendum, "D")
    local count = (#split == 2) and tonumber(split[1]) or 1
    local value = (#split == 2) and tonumber(split[2]) or tonumber(split[1])
    local result = 0
    for i = 1, count do
      local rnd = math.random(value)
      printMessage("Rolling one D"..value..", the value is: "..rnd)
      result = result + rnd
    end
    return result
  end
  return 0
end

function getWeaponDescription(weaponData)
  return "[c6c930]"..weaponData.name.." [-]"
end

function getWeaponColor(name)
  if weaponColors[name] == nil then
    local color = {math.random(), math.random(), math.random()}
    weaponColors[name] = color
  end

  return weaponColors[name]
end

function onRangeClicked(player, _, id)
  if (#currentSelection == 0) then
    return
  end

  drawRangeForWeapon(splitStr(id, "_")[2], currentSelection)
end

function drawRangeForWeapon(name, figures)
  local figuresData = createFiguresData(figures)
  for i,v in ipairs(figuresData) do
    local weapon = getFigureWeaponByName(v, name)
    if weapon != nil then
      drawFigureRange(weapon.range, figures[i])
    end
  end
end

function getFigureWeaponByName(figureData, weaponName)
  for i,v in ipairs(figureData.ranged) do
    if v.name == weaponName then
      return v
    end
  end
end

function drawFigureRange(range, figure)
  range = range / figure.getScale()[1]
  local width = (figure.getBounds().size[1] / 2) / figure.getScale()[1]
  figure.setVectorLines({getCircleVectorPoints(range + width, 30, 0.5, 0.1 / figure.getScale()[1])})
end

function getCircleVectorPoints(radius, steps, y, thickness)
    local points = {}
    local angle = 360 / steps

    for i = 0,steps do
        table.insert(points, {
            math.cos(math.rad(angle * i)) * radius,
            y,
            math.sin(math.rad(angle * i)) * radius
        })
    end

    return {
      points = points,
      thickness = thickness
    }
end

function getRangeText(range)
  if range == nil then
    return "-"
  end
  return "″"..tostring(range)
end

function createButtonCell(text, id, click)
  return {
    tag = "Cell",
    children = {
      {
        tag = "Button",
        attributes = {
          text = text,
          id = id,
          onClick = click
        }
      }
    }
  }
end

function createTextCell(text)
  return {
    tag = "Cell",
    children = {
      {
        tag = "Text",
        attributes = {
          text = text
        }
      }
    }
  }
end

function createFiguresData(figures)
  local result = {}
  for i,v in ipairs(figures) do
    table.insert(result, parseFigureData(v))
  end
  return result
end

function createWeaponsMap(figuresData)
  local result = {}
  for i,v in ipairs(figuresData) do
    convertWeaponDataToMap(v.ranged, result)
  end
  for i,v in ipairs(figuresData) do
    convertWeaponDataToMap(v.melee, result)
  end
  return result
end

function convertWeaponDataToMap(weaponsData, resultData)
  for i,v in ipairs(weaponsData) do
    if resultData[v.name] == nil then
      resultData[v.name] = {
        count = 0,
        attack = 0,
        data = v
      }
    end
    resultData[v.name].count = resultData[v.name].count + 1
    resultData[v.name].attack = resultData[v.name].attack + v.attack
  end
end

function parseFigureData(figure)
  local arr = splitStr(figure.getDescription(), "\n")
  local result = {
    ranged = {},
    melee = {}
  }
  for i,v in ipairs(arr) do
    if (getBlockName(v) != nil) and (getBlockName(v) != "abilities") then
      result[getBlockName(v)] = parseWeaponBlock(arr, i)
    end
  end
  local statsHeaders = {"m", "t", "sv", "w", "ld", "oc"}
  local stats = splitStr(arr[2] or "", " ")
  for i,v in ipairs(statsHeaders) do
    result[v] = stats[i]
  end
  return result
end

function parseWeaponBlock(arr, fromIndex)
  local result = {}
  local i = fromIndex
  while i < #arr do
    table.insert(result, {
      name = parseWeaponName(arr[i + 1]),
      stats = removeColorTags(arr[i + 2]),
      range = parseRange(arr[i + 2]),
      attack = parseWeaponAttack(arr[i + 2]),
      bonusAttack = parseWeaponBonusAttack(arr[i + 2]),
      accuracy = parseWeaponAccuracy(arr[i + 2]),
      strength = getWeaponStatValue(arr[i + 2], "S"),
      ap = getWeaponStatValue(arr[i + 2], "AP"),
      damage = getWeaponStatValue(arr[i + 2], "D")
    })
    if getBlockName(arr[i + 3]) != nil then
      return result
    end
    i = i + 2
  end
  return result
end

function removeColorTags(str)
  str = string.gsub(str, "%[7bc596%]", "")
  str = string.gsub(str, "%[%-%]", "")
  return str
end

function parseWeaponName(data)
  return string.sub(data, 9, -4)
end

function parseWeaponAccuracy(stats)
  return  getWeaponStatValue(stats, "BS") or getWeaponStatValue(stats, "WS")
end

function parseWeaponAttack(stats)
  local stat = getWeaponStatValue(stats, "A")
  return tonumber(stat) or 0
end

function parseWeaponBonusAttack(stats)
  local stat = getWeaponStatValue(stats, "A")
  if tonumber(stat) == nil then
    return stat
  end
  return nil
end

function getWeaponStatValue(stats, statName)
  local statPairs = splitStr(stats, " ")
  for i,v in ipairs(statPairs) do
    local stat = splitStr(v, ':')
    if stat[1] == statName then
      return stat[2]
    end
  end
end

function parseRange(stats)
  local inches = string.find(stats, "″") or string.find(stats, '"')
  if inches != nil then
    return tonumber(string.sub(stats, 1, inches - 1))
  end
end

function getBlockName(str)
  if str == nil then
    return
  end
  if (string.find(str, "Ranged weapons") != nil) then
    return "ranged"
  end
  if (string.find(str, "Melee weapons") != nil) then
    return "melee"
  end
  if (string.find(str, "Abilities") != nil) then
    return "abilities"
  end
end

function splitStr(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t={}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

function printMessage(text, color)
  color = color or {1, 0.5, 0}
  broadcastToAll(text, color)
end
