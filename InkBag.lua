s = {} -- Settings for the bag

s.color_adapt = {value=true, string="Player Color Adapt",
  desc=[[If ON, text taken from the bag will match the player's color.
If OFF, text will match the color of the bag.]]}
s.enter_to_finish = {value=false, string="Enter to Finish",
  desc=[[If ON, pressing ENTER will finish editing the text.
You can escape by typing "[n]" (without quotes).]]}
s.autolock = {value=false, string="Autolock",
  desc="If ON, the tool automatically locks after editing is complete."}
s.autolift = {value=false, string="Autolift",
  desc="If ON, your lift height is temporarily set to 0 when picking up the text tool."}
-- TODO admin restrictions?

s.size = {default=200, string="Size", float=false, min=50, max=800,
  desc="Size of the text. Range is [50, 800]."}
s.hover_height = {default=0.05, string="Hover Height", float=true, min=0, max=10,
  desc=[[Offset of the Y position of the text from the object.
Hovering a little can reduce clipping with some surfaces.]]}
s.box_transparency = {default=1, string="Box Transparency", float=true, min=0, max=1,
  desc="Transparency value for the text box. 0 is invisible, 1 is fully opaque."}

-- Tracking indices for buttons
button_index = 0
input_index = 0

function createToggle(option)
  option.index = button_index
  button_index = button_index + 1

  -- Clicking toggles the button
  _G['click' .. option.index] = function(obj, color, alt_click)
    option.value = not option.value
    updateState()
    self.editButton({index=option.index,
        color=getToggleColor(option.value),
        label=getToggleText(option.value, option.string)})

    updatePreviewText()
  end

  self.createButton({
    label=getToggleText(option.value, option.string),
    tooltip=option.desc,
    click_function='click' .. option.index, function_owner=self,
    position={0, 0.04, 2.0 + 0.4 * option.index}, height=100, width=2000,
    color=getToggleColor(option.value)
  })
end

function createSlider(option)
  option.index = button_index
  button_index = button_index + 1
  option.input_index = input_index
  input_index = input_index + 1

  -- If saved value not loaded, set to default
  if not option.value then
    option.value = option.default
  end

  -- Makes the display value match with the actual value
  local updateInput = function()
    self.editInput({index=option.input_index, value=option.value})
  end

  -- Clicking button resets to default
  _G['click' .. option.index] = function(obj, color, alt_click)
    option.value = option.default
    updateState()
    updateInput()
    updatePreviewText()
  end

  -- Handle input in the text box
  _G['input' .. option.index] = function(obj, color, input, stillEditing)
    if not stillEditing then
      -- Cancelled edit, keep old value
      if input == '' then
        Wait.frames(updateInput, 1)
        return
      end
      -- Check bounds and assign new value
      local val = tonumber(input)
      if val > option.max then val = option.max
      elseif val < option.min then val = option.min end
      option.value = val
      updateState()
      Wait.frames(updateInput, 1)
      updatePreviewText()
    end
  end

  self.createButton({
    label=option.string,
    tooltip=option.desc .. '\n\nClick to reset to default: ' .. option.default,
    click_function='click' .. option.index, function_owner=self,
    position={-1, 0.04, 2.0 + 0.4 * option.index}, height=100, width=1000
  })
  self.createInput({
    label="Size",
    tooltip=option.desc,
    input_function='input' .. option.index, function_owner=self,
    position={1, 0.04, 2.0 + 0.4 * option.index}, height=123, width=900,
    value=option.value,
    validation=option.float and 3 or 2
  })
end

function showPreviewText()
  self.createButton({
    label='Text',
    click_function='none', function_owner=self,
    position={0, s.hover_height.value or s.hover_height.default, 1.4}, height=0, width=0,
    font_size=s.size.value or s.size.default, font_color={1,1,1}
  })
  updatePreviewText()
end

function configMode()
  self.clearContextMenu()
  self.clearButtons()
  self.addContextMenuItem('Done', done)

  showPreviewText()
  button_index = 1 -- Preview text is a button
  input_index = 0

  createToggle(s.color_adapt)
  createToggle(s.enter_to_finish)
  createToggle(s.autolock)
  createToggle(s.autolift)

  createSlider(s.size)
  createSlider(s.hover_height)
  createSlider(s.box_transparency)

  -- Done button
  self.createButton({
    label='[b]Done[/b]',
    click_function='done', function_owner=self,
    position={0, 0.04, 2.0 + 0.4 * button_index}, height=100, width=2000,
    color={1,1,1}
  })
end

function done()
  self.clearContextMenu()
  self.clearButtons()
  self.clearInputs()
  showPreviewText()
  self.addContextMenuItem('Config', configMode)
end

function onLoad(saved_data)
  if saved_data ~= '' then
    local temp_s = JSON.decode(saved_data)
    for option,option_chunk in pairs(temp_s) do
      s[option].value = option_chunk.value
    end
  end
  done()
end

function onSave()
  updateState()
  return self.script_state
end

function updateState()
  self.script_state = JSON.encode(s)
end

function onHover(player_color)
  updatePreviewText()
end

function onObjectLeaveContainer(bag, obj)
  if bag.guid == self.guid then
    Wait.condition(function() applyBagInfo(obj) end, function() return not obj.spawning end)
  end
end

-- Apply the configuration data from the bag to the text tools
function applyBagInfo(obj)
  if obj.getVar('movableTextTool_cowgoesmoo33') then
    local applied_color = self.getColorTint()
    if obj.held_by_color and s.color_adapt.value then
      applied_color = Color.fromString(obj.held_by_color)
    end

    local applied_table = {}
    for option,value_table in pairs(s) do
      applied_table[option] = value_table.value
    end

    applied_table.color_adapt = nil -- Special case: no need to store color_adapt into text tool
    applied_table.color = applied_color
    applied_table.text = ''
    applied_table.interactable = true

    obj.setScale(self.getScale())
    obj.setTable('data', applied_table)
    obj.call('updateState')
    obj.call('inputMode')
  end
end

function getToggleColor(toggle)
  return toggle and {0.4, 1, 0.4} or {1, 0.4, 0.4}
end

function getToggleText(toggle, text)
  local toggleString = toggle and 'ON' or 'OFF'
  return text .. ': ' .. toggleString
end

function updatePreviewText()
  local get_host_color = function()
    local players = Player.getPlayers()
    for _,player in ipairs(players) do
      if player.host then
        return Color.fromString(player.color)
      end
    end
    return {1,1,1}
  end
  self.editButton({index=0, font_size=s.size.value,
      font_color=s.color_adapt.value and get_host_color() or self.getColorTint(),
      position={0, s.hover_height.value, 1.4}})
end