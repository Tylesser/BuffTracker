local addonName, ns = ...

-- The shared Tylesser "Runestone" look: dark stone panels, double gold borders, hex studs in the corners,
-- the emblem medallion and Cinzel headings. Every Tylesser addon ships the same copy of this file; change
-- them together. Only plain textures and font strings, so it works on every client from Classic to Retail.

local T = {}
ns.T = T

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
T.FONT = MEDIA .. "Cinzel-Bold.ttf"
T.EMBLEM = MEDIA .. "Emblem"
T.STUD = MEDIA .. "Stud"
T.STUD_RUBY = MEDIA .. "StudRuby"

T.GOLD = { 0.94, 0.76, 0.31 }
T.GOLD_DEEP = { 0.78, 0.54, 0.12 }
T.BRONZE = { 0.54, 0.35, 0.05 }
T.EDGE = { 0.29, 0.18, 0.02 }
T.PARCHMENT = { 0.91, 0.87, 0.78 }
T.MUTED = { 0.72, 0.65, 0.49 }
T.RUBY = { 0.88, 0.19, 0.31 }
T.GREY = { 0.35, 0.35, 0.35 }
T.STONE_TOP = { 0.15, 0.13, 0.18 }
T.STONE_BOTTOM = { 0.09, 0.07, 0.11 }

-- Fills a texture with a gradient; VERTICAL runs from `from` at the bottom to `to` at the top.
function T.Gradient(texture, orientation, from, to, alphaFrom, alphaTo)
  local a1, a2 = alphaFrom or 1, alphaTo or 1
  texture:SetColorTexture(1, 1, 1, 1)
  if CreateColor and texture.SetGradient then
    local ok = pcall(texture.SetGradient, texture, orientation,
      CreateColor(from[1], from[2], from[3], a1), CreateColor(to[1], to[2], to[3], a2))
    if ok then
      return
    end
  end
  if texture.SetGradientAlpha then
    texture:SetGradientAlpha(orientation, from[1], from[2], from[3], a1, to[1], to[2], to[3], a2)
  else
    texture:SetColorTexture(from[1], from[2], from[3], (a1 + a2) / 2)
  end
end

-- Cinzel at `size`, with the game font as fallback if the file can't be loaded.
function T.Font(fontString, size, color)
  if not fontString:SetFont(T.FONT, size, "") then
    fontString:SetFontObject(size >= 16 and "GameFontNormalLarge" or "GameFontNormal")
  end
  fontString:SetShadowOffset(1, -1)
  fontString:SetShadowColor(0, 0, 0, 1)
  color = color or T.GOLD
  fontString:SetTextColor(color[1], color[2], color[3])
end

-- A rectangle of lines `inset` units in from the frame's edges.
function T.Outline(frame, inset, color, thickness, layer, sublevel)
  thickness = thickness or 1
  local lines = {}
  for index = 1, 4 do
    lines[index] = frame:CreateTexture(nil, layer or "BORDER", nil, sublevel or 0)
  end
  local top, bottom, left, right = lines[1], lines[2], lines[3], lines[4]
  top:SetPoint("TOPLEFT", inset, -inset)
  top:SetPoint("TOPRIGHT", -inset, -inset)
  top:SetHeight(thickness)
  bottom:SetPoint("BOTTOMLEFT", inset, inset)
  bottom:SetPoint("BOTTOMRIGHT", -inset, inset)
  bottom:SetHeight(thickness)
  left:SetPoint("TOPLEFT", inset, -inset)
  left:SetPoint("BOTTOMLEFT", inset, inset)
  left:SetWidth(thickness)
  right:SetPoint("TOPRIGHT", -inset, -inset)
  right:SetPoint("BOTTOMRIGHT", -inset, inset)
  right:SetWidth(thickness)
  T.ColorLines(lines, color)
  return lines
end

function T.ColorLines(lines, color, alpha)
  for _, line in ipairs(lines) do
    line:SetColorTexture(color[1], color[2], color[3], alpha or 1)
  end
end

-- Double gold border, as on icons and party buttons. Recolor it with T.SetBorderColor.
function T.DoubleBorder(frame, color, layer)
  local border = {
    outer = T.Outline(frame, 0, color or T.GOLD_DEEP, 1, layer or "OVERLAY"),
    inner = T.Outline(frame, 2, color or T.GOLD_DEEP, 1, layer or "OVERLAY"),
    shade = T.Outline(frame, 1, { 0, 0, 0 }, 1, layer or "OVERLAY"),
  }
  return border
end

function T.SetBorderColor(border, color, alpha)
  T.ColorLines(border.outer, color, alpha)
  T.ColorLines(border.inner, color, alpha)
end

function T.Stud(parent, size, ruby, layer)
  local stud = parent:CreateTexture(nil, layer or "OVERLAY", nil, 7)
  stud:SetTexture(ruby and T.STUD_RUBY or T.STUD)
  stud:SetSize(size, size)
  return stud
end

function T.Emblem(parent, size, layer)
  local emblem = parent:CreateTexture(nil, layer or "ARTWORK")
  emblem:SetTexture(T.EMBLEM)
  emblem:SetSize(size, size)
  return emblem
end

-- Inline texture for chat and tooltip text.
function T.TextIcon(path, size)
  return "|T" .. path .. ":" .. (size or 0) .. "|t"
end

-- Chat prefix: a stud and the addon's name in gold.
function T.Prefix(name)
  return T.TextIcon(T.STUD, 12) .. " |cfff0c24e" .. name .. ":|r "
end

-- Turns `frame` into a runestone panel: stone background, double gold border, studs in the corners.
function T.Stone(frame, studSize)
  local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  background:SetPoint("TOPLEFT", 1, -1)
  background:SetPoint("BOTTOMRIGHT", -1, 1)
  T.Gradient(background, "VERTICAL", T.STONE_BOTTOM, T.STONE_TOP, 0.97, 0.97)
  T.Outline(frame, 0, T.GOLD_DEEP, 1, "BORDER")
  T.Outline(frame, 3, T.GOLD_DEEP, 1, "BORDER")
  T.Outline(frame, 4, T.EDGE, 1, "BORDER")
  if studSize ~= 0 then
    studSize = studSize or 18
    local corners = { { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }
    for _, corner in ipairs(corners) do
      local stud = T.Stud(frame, studSize)
      stud:SetPoint("CENTER", frame, corner[1], corner[2], corner[3])
    end
  end
  frame.tylesserBackground = background
  return background
end

-- A bronze title band across the top of a stone panel, with the emblem and the title in Cinzel.
function T.TitleBar(frame, text, height)
  height = height or 28
  local band = CreateFrame("Frame", nil, frame)
  band:SetPoint("TOPLEFT", 5, -5)
  band:SetPoint("TOPRIGHT", -5, -5)
  band:SetHeight(height)
  local fill = band:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  T.Gradient(fill, "VERTICAL", { 0.14, 0.08, 0.04 }, { 0.29, 0.16, 0.06 })
  local line = band:CreateTexture(nil, "BORDER")
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetHeight(2)
  line:SetColorTexture(T.GOLD_DEEP[1], T.GOLD_DEEP[2], T.GOLD_DEEP[3], 1)
  local emblem = T.Emblem(band, height - 4)
  emblem:SetPoint("LEFT", 6, 1)
  band.title = band:CreateFontString(nil, "OVERLAY")
  T.Font(band.title, 13)
  band.title:SetPoint("LEFT", emblem, "RIGHT", 8, 0)
  band.title:SetText(text and text:upper())
  return band
end

-- "◆ TEXT ◆" heading with gold lines running out to both sides.
function T.Heading(parent, text, width)
  local heading = CreateFrame("Frame", nil, parent)
  heading:SetSize(width or 260, 16)
  heading.text = heading:CreateFontString(nil, "OVERLAY")
  T.Font(heading.text, 11)
  heading.text:SetPoint("CENTER")
  local left = T.Stud(heading, 10, false, "ARTWORK")
  left:SetPoint("RIGHT", heading.text, "LEFT", -5, 0)
  local right = T.Stud(heading, 10, false, "ARTWORK")
  right:SetPoint("LEFT", heading.text, "RIGHT", 5, 0)
  local lineLeft = heading:CreateTexture(nil, "BORDER")
  lineLeft:SetHeight(1)
  lineLeft:SetPoint("LEFT")
  lineLeft:SetPoint("RIGHT", left, "LEFT", -4, 0)
  T.Gradient(lineLeft, "HORIZONTAL", T.GOLD_DEEP, T.GOLD_DEEP, 0, 1)
  local lineRight = heading:CreateTexture(nil, "BORDER")
  lineRight:SetHeight(1)
  lineRight:SetPoint("LEFT", right, "RIGHT", 4, 0)
  lineRight:SetPoint("RIGHT")
  T.Gradient(lineRight, "HORIZONTAL", T.GOLD_DEEP, T.GOLD_DEEP, 1, 0)
  function heading:SetText(value)
    self.text:SetText(value and value:upper() or "")
  end
  heading:SetText(text)
  return heading
end

local function ButtonState(button)
  local color = button:IsEnabled() and (button.textColor or T.GOLD) or T.GREY
  button.label:SetTextColor(color[1], color[2], color[3])
end

-- Stone button with a bronze border. `primary` gives the bigger gold-framed button with Cinzel text.
function T.Button(parent, width, height, text, primary)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width, height)
  local fill = button:CreateTexture(nil, "BACKGROUND")
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", -1, 1)
  if primary then
    T.Gradient(fill, "VERTICAL", { 0.16, 0.09, 0.04 }, { 0.29, 0.16, 0.06 })
    T.Outline(button, 0, T.GOLD_DEEP, 2)
    T.Outline(button, 2, T.EDGE, 1)
  else
    T.Gradient(fill, "VERTICAL", { 0.11, 0.10, 0.14 }, { 0.24, 0.22, 0.27 })
    T.Outline(button, 0, T.BRONZE, 1)
  end
  local shine = button:CreateTexture(nil, "BORDER", nil, 1)
  shine:SetPoint("TOPLEFT", primary and 3 or 1, primary and -3 or -1)
  shine:SetPoint("TOPRIGHT", primary and -3 or -1, primary and -3 or -1)
  shine:SetHeight(1)
  shine:SetColorTexture(1, 0.95, 0.75, 0.22)
  local glow = button:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints(fill)
  glow:SetColorTexture(T.GOLD[1], T.GOLD[2], T.GOLD[3], 0.14)

  button.label = button:CreateFontString(nil, "OVERLAY")
  if primary then
    T.Font(button.label, 11)
  else
    button.label:SetFontObject("GameFontNormalSmall")
  end
  button.label:SetPoint("LEFT", 4, 0)
  button.label:SetPoint("RIGHT", -4, 0)
  button.label:SetWordWrap(false)
  button:SetFontString(button.label)
  button:SetPushedTextOffset(1, -1)
  button:HookScript("OnEnable", ButtonState)
  button:HookScript("OnDisable", ButtonState)
  if text then
    button:SetText(primary and text:upper() or text)
  end
  ButtonState(button)
  return button
end

-- Small square close button with an X.
function T.CloseButton(parent)
  local button = T.Button(parent, 20, 20, "X")
  return button
end

-- Check box with a bronze frame and a gold tick. The label is `check.Text` (also `check.label`).
function T.Check(parent, label, fontObject)
  local check = CreateFrame("CheckButton", nil, parent)
  check:SetSize(22, 22)
  local box = check:CreateTexture(nil, "BACKGROUND")
  box:SetPoint("TOPLEFT", 4, -4)
  box:SetPoint("BOTTOMRIGHT", -4, 4)
  box:SetColorTexture(0.06, 0.05, 0.07, 1)
  T.Outline(check, 3, T.BRONZE, 2)
  local glow = check:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints(box)
  glow:SetColorTexture(T.GOLD[1], T.GOLD[2], T.GOLD[3], 0.2)
  check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  local tick = check:GetCheckedTexture()
  if tick then
    tick:ClearAllPoints()
    tick:SetPoint("CENTER", 1, 0)
    tick:SetSize(22, 22)
  end
  check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
  local text = check:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlight")
  text:SetPoint("LEFT", check, "RIGHT", 4, 0)
  text:SetJustifyH("LEFT")
  check.Text, check.label = text, text
  check:SetHitRectInsets(0, -200, 0, 0)
  if label then
    text:SetText(label)
  end
  return check
end

-- Restyles an edit box made from InputBoxTemplate or SearchBoxTemplate: hides the template's frame
-- and draws a dark field with a bronze border instead.
function T.EditBox(box)
  local name = box:GetName()
  for _, key in ipairs({ "Left", "Middle", "Mid", "Right" }) do
    local region = box[key] or (name and _G[name .. key])
    if type(region) == "table" and region.Hide then
      region:Hide()
    end
  end
  local field = CreateFrame("Frame", nil, box)
  field:SetPoint("TOPLEFT", -5, 2)
  field:SetPoint("BOTTOMRIGHT", 2, -2)
  field:SetFrameLevel(math.max(box:GetFrameLevel() - 1, 0))
  local fill = field:CreateTexture(nil, "BACKGROUND")
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", -1, 1)
  fill:SetColorTexture(0.06, 0.05, 0.07, 0.95)
  T.Outline(field, 0, T.BRONZE, 1)
  return field
end

local function Version()
  local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local version = getMetadata and getMetadata(addonName, "Version")
  if version and not version:find("^@") then
    return version:gsub("^v", "")
  end
end

-- Header for an options page (Esc > Options > AddOns): the whole page becomes a runestone panel, with the
-- emblem medallion, the addon's name and a short line under it. Content starts at T.OPTIONS_TOP.
T.OPTIONS_TOP = -124
function T.OptionsPage(panel, name, subtitle)
  T.Stone(panel)
  local emblem = T.Emblem(panel, 44)
  emblem:SetPoint("TOP", 0, -10)
  local title = panel:CreateFontString(nil, "OVERLAY")
  T.Font(title, 18)
  title:SetPoint("TOP", emblem, "BOTTOM", 0, -4)
  title:SetText(name:upper())
  local tagline = panel:CreateFontString(nil, "OVERLAY")
  T.Font(tagline, 9, T.MUTED)
  tagline:SetPoint("TOP", title, "BOTTOM", 0, -4)
  local version = Version()
  tagline:SetText(version and ("TYLESSER  ·  V" .. version) or "TYLESSER")
  for _, side in ipairs({ -1, 1 }) do
    local line = panel:CreateTexture(nil, "BORDER")
    line:SetSize(60, 1)
    line:SetColorTexture(T.BRONZE[1], T.BRONZE[2], T.BRONZE[3], 1)
    if side < 0 then
      line:SetPoint("RIGHT", tagline, "LEFT", -8, 0)
    else
      line:SetPoint("LEFT", tagline, "RIGHT", 8, 0)
    end
  end
  local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("TOP", tagline, "BOTTOM", 0, -8)
  text:SetPoint("LEFT", 24, 0)
  text:SetPoint("RIGHT", -24, 0)
  text:SetJustifyH("CENTER")
  text:SetTextColor(T.PARCHMENT[1], T.PARCHMENT[2], T.PARCHMENT[3])
  text:SetText(subtitle or "")
  return text
end
