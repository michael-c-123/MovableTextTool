-- Code for bag to identify text tool objects
movableTextTool_cowgoesmoo33 = true

-- Number of characters before the text box width expands.
EXPAND_INTERVAL = 20

-- This table controls what is passed between save/load
data = {}

function onLoad(saved_data)
  if saved_data ~= '' then
    data = JSON.decode(saved_data)
    if data.text ~= '' then
      self.interactable = data.interactable
      staticMode()
      return
    end
  else
    data = {size=200, color=Color(0,0,0), text='', interactable=true,
        enter_to_finish=false, autolock=false, autolift=false,
        hover_height=0.05, box_transparency=1}
  end

  inputMode()
end

-- True if in the middle of delay after pressing Enter (with enter_to_finish on)
finishing = false
function input_func(obj, color, input, stillEditing)
  local params = getBox(input)
  if params then
    params.value = input
    self.editInput(params)
  end

  if not stillEditing then
    data.text = input
    updateState()
    if input ~= '' then staticMode() end
  elseif data.enter_to_finish then
    -- If enter is pressed: remove last newline and force finish
    if not finishing and input:sub(-1) == '\n' then
      finishing = true
      -- Delay to avoid user's Enter keypress being detected (opens chat box)
      Wait.frames(function()
        input = input:sub(1, -2)
        data.text = input
        updateState()
        if input ~= '' then staticMode() else inputMode() end
        finishing = false
      end, 10)
    end
  end
end

-- When the inpupt box appears and lets the player type in it.
-- If player is passed, the clear button was clicked and their selection is removed.
function inputMode(player)
  self.clearContextMenu()
  self.clearInputs()
  self.clearButtons()
  if player then
    self.removeFromPlayerSelection(player)
  end

  local size = getBox(data.text, true)

  self.createInput({
    input_function = "input_func",
    function_owner = self,
    label          = "Type Here",
    alignment      = 3,
    position       = {x=0, y=data.hover_height, z=0},
    width          = size.width,
    height         = size.height,
    color          = getBackground(data.color),
    font_color     = data.color,
    font_size      = data.size,
    value          = data.text,
  })

  self.addContextMenuItem('Color: Object Tint', function() setColor(self.getColorTint():setAt('a', 1)) end)
  self.addContextMenuItem('Color: Player', function(color) setColor(Color.fromString(color)) end)
  self.addContextMenuItem('Color: Black', function() setColor(Color(0,0,0)) end)
  self.addContextMenuItem('Color: White', function() setColor(Color(1,1,1)) end)
  self.addContextMenuItem('Size: Increase', function() changeSize(50) end, true)
  self.addContextMenuItem('Size: Decrease', function() changeSize(-50) end, true)
end

-- When the input box disappears and displays the text.
function staticMode()
  self.clearContextMenu()
  if data.autolock then
    self.locked = true
  end
  if self.getInputs() and #self.getInputs() ~= 0 then
    self.removeInput(0)
  end

  local displayText = data.text
  if data.enter_to_finish then
    displayText = displayText:gsub('%[n%]', '\n')
  end

  self.createButton({
    label=displayText,
    click_function="none",
    function_owner=self,
    position={0,data.hover_height,0}, rotation={0,0,0}, height=0, width=0,
    font_color=data.color, font_size=data.size
  })

  self.addContextMenuItem('Edit Text', inputMode)
  self.addContextMenuItem('Clear', clear)
  self.addContextMenuItem('Color: Object Tint', function() setColor(self.getColorTint():setAt('a', 1)) end)
  self.addContextMenuItem('Color: Player', function(color) setColor(Color.fromString(color)) end)
  self.addContextMenuItem('Color: Black', function() setColor(Color(0,0,0)) end)
  self.addContextMenuItem('Color: White', function() setColor(Color(1,1,1)) end)
  self.addContextMenuItem('Size: Increase', function() changeSize(50) end, true)
  self.addContextMenuItem('Size: Decrease', function() changeSize(-50) end, true)
  self.addContextMenuItem('Permalock', permalock)
end

function changeSize(delta)
  local newSize = data.size + delta
  if newSize > 800  or newSize < 50 then
    return
  end
  data.size = newSize
  updateState()
  if self.getButtons() and #self.getButtons() ~= 0 then
    self.editButton({font_size=data.size})
  else
    local size = getBox(data.text, true)
    self.editInput({width=size.width, height=size.height, font_size=data.size})
  end
end

function setColor(color)
  data.color = color
  updateState()
  if self.getButtons() and #self.getButtons() ~= 0 then
    self.editButton({font_color=data.color})
  else
    self.editInput({font_color=data.color, color=getBackground(data.color)})
  end
end

function getBackground(color) --determines whether to use black or white depending on luminance
  local r,g,b = Color(color):get()

  local lum = 0.2126*r + 0.7152*g + 0.0722*b
  if lum > 0.75 then
    return {0.2,0.2,0.2, data.box_transparency}
  else
    return {1,1,1, data.box_transparency}
  end
end

function clear(player)
  data.text = ''
  updateState()
  inputMode(player)
end

function permalock()
  self.interactable = false
  data.interactable = false
  updateState()
end

function getBox(input, force)
  local maxLength, lineCount = EXPAND_INTERVAL, 1
  local lineLength = 0
  for i = 1, #input do
    local c = input:sub(i,i)
    if c == '\n' then
      lineCount = lineCount + 1
      if lineLength > maxLength then maxLength = (math.floor(lineLength / EXPAND_INTERVAL) + 1) * EXPAND_INTERVAL end
      lineLength = 0
    else
      lineLength = lineLength + 1
    end
  end
  if lineLength > maxLength then maxLength = (math.floor(lineLength / EXPAND_INTERVAL) + 1) * EXPAND_INTERVAL end

  newWidth = data.size * maxLength * 0.9
  newHeight = data.size * lineCount + 23

  if force or boxWidth ~= newWidth or boxHeight ~= newHeight then
    boxWidth, boxHeight = newWidth, newHeight
    return {width = boxWidth, height = boxHeight}
  end
  return nil
end

temp_lift = nil
function onPickUp(player_color)
  if data.autolift then
    local player = Player[player_color]
    temp_lift = player.lift_height
    player.lift_height = 0
  end
end

function onDrop(player_color)
  if data.autolift and temp_lift then
    Player[player_color].lift_height = temp_lift
  end
end

-- Should be called every time data is modified, allows info to be saved on copy/paste
function updateState()
  self.script_state = JSON.encode(data)
end

function onSave()
  self.script_state = JSON.encode(data)
  return self.script_state
end