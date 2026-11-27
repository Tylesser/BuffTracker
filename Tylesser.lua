local addonName, ns = ...

-- The shared Tylesser "Runestone" look: dark stone panels, double gold borders, hex studs in the corners,
-- the emblem medallion and Cinzel headings. Every Tylesser addon ships the same copy of this file; change
-- them together. Only plain textures and font strings, so it works on every client from Classic to Retail.

local T = {}
ns.T = T

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
T.LOCALE = GetLocale and GetLocale() or "enUS"
-- Cinzel has no Cyrillic (or Korean / Chinese) letters: those clients write the headings in the game's own font.
local GAME_FONT_LOCALES = { ruRU = true, koKR = true, zhCN = true, zhTW = true }
T.FONT = GAME_FONT_LOCALES[T.LOCALE] and (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF") or (MEDIA .. "Cinzel-Bold.ttf")

-- Translations (2026-11-27, the user's request: German, French, Spanish, Russian, Portuguese). Every text is written
-- in English and read through ns.L: L["Feedback"] is the client's language when a Locales file gave it, else the
-- English text itself (a missing translation shows English, never nothing). Texts with values keep the placeholders:
-- L["Next post in %s."]:format(time). Locales files call T.Translations(locale, { [english] = text, ... }); esMX
-- reads esES, enGB nothing.
-- A key may carry a context after "##" when one English word needs two translations ("Soft##sound" next to "Soft"
-- for a glow): the English shown is the part before "##".
local translated = {}
ns.L = setmetatable({}, { __index = function(_, key)
  local text = translated[key]
  if text then
    return text
  end
  return type(key) == "string" and key:match("^(.-)##") or key
end })
local SAME_AS = { esMX = "esES", ptPT = "ptBR" }
function T.Translations(locale, list)
  if locale ~= T.LOCALE and locale ~= SAME_AS[T.LOCALE] then
    return
  end
  for english, text in pairs(list) do
    if type(english) == "string" and type(text) == "string" and text ~= "" then
      translated[english] = text
    end
  end
end
local L = ns.L
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

-- A thin line between the groups of an options page (2026-11-28, the user's request: the sections of the settings
-- ran together): gold in the middle, fading out to both ends. A frame `width` wide and `height` high with the line
-- across its middle, to anchor the next row under.
function T.Divider(parent, width, height)
  local divider = CreateFrame("Frame", nil, parent)
  divider:SetSize(width or 540, height or 13)
  local left = divider:CreateTexture(nil, "BORDER")
  left:SetHeight(1)
  left:SetPoint("LEFT", divider, "LEFT", 0, 0)
  left:SetPoint("RIGHT", divider, "CENTER", 0, 0)
  T.Gradient(left, "HORIZONTAL", T.GOLD_DEEP, T.GOLD_DEEP, 0, 0.7)
  local right = divider:CreateTexture(nil, "BORDER")
  right:SetHeight(1)
  right:SetPoint("LEFT", divider, "CENTER", 0, 0)
  right:SetPoint("RIGHT", divider, "RIGHT", 0, 0)
  T.Gradient(right, "HORIZONTAL", T.GOLD_DEEP, T.GOLD_DEEP, 0.7, 0)
  divider.left, divider.right = left, right
  return divider
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

-- Feedback ---------------------------------------------------------------------------------------
-- The game can't open a browser, so links are shown in a small window, selected and ready to copy.

T.FEEDBACK_URL = "https://tylesser.com/feedback/#" .. addonName:lower()
T.SITE_URL = "https://tylesser.com/"

local linkWindow

local function CreateLinkWindow()
  local window = CreateFrame("Frame", nil, UIParent)
  window:SetSize(400, 132)
  window:SetPoint("CENTER", 0, 140)
  window:SetFrameStrata("DIALOG")
  window:SetToplevel(true)
  window:EnableMouse(true)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window:SetClampedToScreen(true)
  T.Stone(window, 14)
  window.band = T.TitleBar(window, "Tylesser", 26)

  local close = T.CloseButton(window)
  close:SetPoint("RIGHT", window.band, "RIGHT", -4, 0)
  close:SetScript("OnClick", function()
    window:Hide()
  end)

  window.text = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  window.text:SetPoint("TOPLEFT", window.band, "BOTTOMLEFT", 10, -10)
  window.text:SetPoint("RIGHT", window, "RIGHT", -16, 0)
  window.text:SetJustifyH("LEFT")
  window.text:SetTextColor(T.PARCHMENT[1], T.PARCHMENT[2], T.PARCHMENT[3])

  local box = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
  box:SetSize(360, 20)
  box:SetPoint("TOP", window.text, "BOTTOM", 0, -10)
  box:SetPoint("LEFT", window, "LEFT", 22, 0)
  box:SetAutoFocus(false)
  T.EditBox(box)
  -- read only: any typing puts the link back
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput and self:GetText() ~= window.url then
      self:SetText(window.url)
      self:HighlightText()
    end
  end)
  box:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
  end)
  box:SetScript("OnEscapePressed", function()
    window:Hide()
  end)
  box:SetScript("OnEnterPressed", function()
    window:Hide()
  end)
  window.box = box

  local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOP", box, "BOTTOM", 0, -8)
  hint:SetText(L["Press Ctrl+C to copy, then paste it into your browser."])
  window:Hide()
  return window
end

-- Shows a link to copy, with a line of text above it.
function T.ShowLink(url, text)
  linkWindow = linkWindow or CreateLinkWindow()
  linkWindow.url = url
  linkWindow.text:SetText(text or "")
  -- grow with the text: one line of text gives the original 132
  linkWindow:SetHeight(118 + math.max(linkWindow.text:GetStringHeight() or 14, 14))
  linkWindow:Show()
  linkWindow.box:SetText(url)
  linkWindow.box:SetFocus()
  linkWindow.box:HighlightText()
end

-- Opens the feedback link: bug reports and ideas go to tylesser.com/feedback.
function T.ShowFeedback()
  T.ShowLink(T.FEEDBACK_URL, L["Found a bug or have an idea? Tell us on the Tylesser feedback page."] .. "\n"
    .. L["More Tylesser addons are on tylesser.com."])
end

-- Opens the link to all Tylesser addons.
function T.ShowMoreAddons()
  T.ShowLink(T.SITE_URL, L["All Tylesser addons, with their features and changelogs, are on tylesser.com."])
end

-- Addon compartment ------------------------------------------------------------------------------
-- The addon menu button by the minimap (Retail and WoW Forever). Registered at run time, so no global
-- functions are needed; clients without the menu are skipped.
-- info: text, onClick (function), tooltip (list of lines, optional), icon (optional, defaults to Media/Icon).
function T.AddCompartment(info)
  local frame = AddonCompartmentFrame
  if not (frame and frame.RegisterAddon) then
    return false
  end
  frame:RegisterAddon({
    text = info.text,
    icon = info.icon or (MEDIA .. "Icon"),
    notCheckable = true,
    registerForAnyClick = true,
    func = function()
      info.onClick()
    end,
    funcOnEnter = function(button)
      GameTooltip:SetOwner(button, "ANCHOR_LEFT")
      GameTooltip:SetText(info.text, T.GOLD[1], T.GOLD[2], T.GOLD[3])
      for _, line in ipairs(info.tooltip or {}) do
        GameTooltip:AddLine(line, 1, 1, 1, true)
      end
      GameTooltip:Show()
    end,
    funcOnLeave = function()
      GameTooltip:Hide()
    end,
  })
  return true
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
function T.OptionsPage(panel, name, subtitle, noVersion)
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
  local version = not noVersion and Version()
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
  local feedback = T.Button(panel, 92, 22, L["Feedback"])
  feedback:SetPoint("TOPRIGHT", -16, -16)
  feedback:SetScript("OnClick", T.ShowFeedback)
  panel.feedbackButton = feedback

  local more = T.Button(panel, 92, 22, L["More addons"])
  more:SetPoint("TOPRIGHT", feedback, "BOTTOMRIGHT", 0, -6)
  more:SetScript("OnClick", T.ShowMoreAddons)
  panel.moreAddonsButton = more

  local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("TOP", tagline, "BOTTOM", 0, -8)
  text:SetPoint("LEFT", 24, 0)
  text:SetPoint("RIGHT", -24, 0)
  text:SetJustifyH("CENTER")
  text:SetTextColor(T.PARCHMENT[1], T.PARCHMENT[2], T.PARCHMENT[3])
  text:SetText(subtitle or "")
  return text
end

-- Tylesser's settings window (2026-11-28, the user's requests: one Tylesser entry in Options > AddOns, then "open
-- Tylesser addons settings on its separate window so you can fit everything"). Every Tylesser addon's options page is
-- shown in one window of ours, `TylesserSettingsWindow`: the installed addons listed on the left (an addon's own
-- sub-pages indented under it), the picked page on the right, with room the game's settings canvas didn't have.
-- Options > AddOns has only a "Tylesser" entry; its page opens that window, and Codex's (T.RegisterLauncher: Codex has a
-- window of its own). The addons share one table, the global `TylesserSettings` (pages, launchers, window, the game's
-- category), made by the first Tylesser addon that registers: the one global this file writes.
--   T.RegisterOptions(panel, title, parent) -> page   (title "Tylesser - <Name>" is listed as "<Name>"; parent = a page)
--   T.OpenOptions(page)                                  (nil = the first page)
--   T.RegisterLauncher(label, open)                      (a button on the game's Tylesser page and under the list)
local WIN_W, WIN_H, LIST_W = 1100, 760, 200

local function Registry()
  local registry = _G.TylesserSettings
  if type(registry) ~= "table" then
    registry = { pages = {}, launchers = {} }
    _G.TylesserSettings = registry
  end
  return registry
end

local function ShortName(title)
  return type(title) == "string" and title:match("^Tylesser %- (.+)$") or title
end

-- The pages in list order: addons by name, each followed by its sub-pages in the order they came.
local function Ordered()
  local registry, list = Registry(), {}
  local tops = {}
  for _, page in ipairs(registry.pages) do
    if not page.parent then
      tops[#tops + 1] = page
    end
  end
  table.sort(tops, function(x, y)
    return tostring(x.name):lower() < tostring(y.name):lower()
  end)
  for _, top in ipairs(tops) do
    list[#list + 1] = top
    for _, page in ipairs(registry.pages) do
      if page.parent == top then
        list[#list + 1] = page
      end
    end
  end
  return list
end

local function SelectPage(window, page)
  for _, other in ipairs(Registry().pages) do
    if other ~= page and other.panel then
      other.panel:Hide()
    end
  end
  window.current = page
  for _, button in ipairs(window.buttons) do
    local on = button.page == page
    button.mark:SetShown(on)
    if button.label and button.label.SetTextColor then
      local color = on and T.GOLD or T.PARCHMENT
      button.label:SetTextColor(color[1], color[2], color[3])
    end
  end
  if page and page.panel then
    local panel = page.panel
    panel:SetParent(window.content)
    panel:ClearAllPoints()
    panel:SetAllPoints(window.content)
    panel:Show()
  end
end

-- The list on the left (again on each show: an addon may have registered since).
local function FillList(window)
  local pages = Ordered()
  for index, page in ipairs(pages) do
    local button = window.buttons[index]
    if not button then
      button = T.Button(window, LIST_W - 16, 26, "")
      button.mark = button:CreateTexture(nil, "OVERLAY")
      button.mark:SetPoint("TOPLEFT", 2, -3)
      button.mark:SetPoint("BOTTOMLEFT", 2, 3)
      button.mark:SetWidth(3)
      button.mark:SetColorTexture(T.GOLD[1], T.GOLD[2], T.GOLD[3], 1)
      button:SetScript("OnClick", function(self)
        SelectPage(window, self.page)
      end)
      window.buttons[index] = button
    end
    local sub = page.parent ~= nil
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", window, "TOPLEFT", sub and 28 or 14, -48 - (index - 1) * 30)
    button:SetWidth(sub and LIST_W - 30 or LIST_W - 16)
    button:SetText(page.name)
    button.page = page
    button:Show()
  end
  for index = #pages + 1, #window.buttons do
    window.buttons[index]:Hide()
  end
  local launchers = Registry().launchers
  for index, launcher in ipairs(launchers) do
    local button = window.launchers[index]
    if not button then
      button = T.Button(window, LIST_W - 16, 26, "")
      window.launchers[index] = button
    end
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 14, 16 + (#launchers - index) * 30)
    button:SetText(launcher.label)
    button:SetScript("OnClick", function()
      pcall(launcher.open)
    end)
    button:Show()
  end
  return pages
end

local function Window()
  local registry = Registry()
  if registry.window then
    return registry.window
  end
  local window = CreateFrame("Frame", "TylesserSettingsWindow", UIParent)
  window:SetSize(WIN_W, WIN_H)
  window:SetPoint("CENTER")
  -- the game's settings window's strata, raised over it when opened (T.OpenOptions): the pages' own pop-ups (art
  -- gallery, pickers, the conditions window, feedback: DIALOG) stay above it (2026-11-28, the user's screenshot)
  window:SetFrameStrata("HIGH")
  window:SetToplevel(true)
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  T.Stone(window)
  T.TitleBar(window, "Tylesser")
  local close = T.CloseButton(window)
  close:SetPoint("TOPRIGHT", -10, -9)
  close:SetScript("OnClick", function()
    window:Hide()
  end)
  if UISpecialFrames then
    table.insert(UISpecialFrames, "TylesserSettingsWindow") -- Esc closes it
  end
  local line = window:CreateTexture(nil, "BORDER")
  line:SetWidth(1)
  line:SetPoint("TOPLEFT", window, "TOPLEFT", LIST_W + 4, -44)
  line:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", LIST_W + 4, 14)
  line:SetColorTexture(T.BRONZE[1], T.BRONZE[2], T.BRONZE[3], 0.8)
  window.content = CreateFrame("Frame", nil, window)
  window.content:SetPoint("TOPLEFT", window, "TOPLEFT", LIST_W + 12, -40)
  window.content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -10, 10)
  window.buttons, window.launchers = {}, {}
  window:SetScript("OnShow", function(self)
    -- smaller screens: the whole window scaled down to fit
    local width, height = UIParent:GetWidth() or WIN_W, UIParent:GetHeight() or WIN_H
    self:SetScale(math.min(1, (width - 20) / WIN_W, (height - 20) / WIN_H))
    local pages = FillList(self)
    SelectPage(self, self.wanted or self.current or pages[1])
    self.wanted = nil
  end)
  window:Hide()
  registry.window = window
  return window
end

-- Options > AddOns: the one Tylesser entry, a page with buttons for the window and the launchers.
local function GamePage()
  local registry = Registry()
  if registry.category or not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
    return
  end
  local page = CreateFrame("Frame")
  page.name = "Tylesser"
  local text = T.OptionsPage(page, "Tylesser",
    L["Tylesser addons have a settings window of their own, with room for everything."], true)
  page.buttons = {}
  page:SetScript("OnShow", function(self)
    local entries = {}
    if #registry.pages > 0 then
      entries[1] = { label = L["Open Tylesser settings"], open = function() T.OpenOptions() end }
    end
    for _, launcher in ipairs(registry.launchers) do
      entries[#entries + 1] = launcher
    end
    for index, entry in ipairs(entries) do
      local button = self.buttons[index]
      if not button then
        button = T.Button(self, 240, 26, "", index == 1)
        button:SetPoint("TOP", text, "BOTTOM", 0, -18 - (index - 1) * 34)
        self.buttons[index] = button
      end
      button:SetText(entry.label)
      button:SetScript("OnClick", function()
        pcall(entry.open)
      end)
      button:Show()
    end
    for index = #entries + 1, #self.buttons do
      self.buttons[index]:Hide()
    end
  end)
  local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, page, "Tylesser")
  if ok and category then
    Settings.RegisterAddOnCategory(category)
    registry.category = category
  end
end

function T.RegisterOptions(panel, title, parent)
  local registry = Registry()
  local page = { panel = panel, name = ShortName(title), parent = parent }
  registry.pages[#registry.pages + 1] = page
  panel:Hide()
  pcall(GamePage)
  return page
end

function T.RegisterLauncher(label, open)
  local registry = Registry()
  registry.launchers[#registry.launchers + 1] = { label = label, open = open }
  pcall(GamePage)
end

function T.OpenOptions(page)
  local window = Window()
  if window:IsShown() then
    window.current = nil
    FillList(window)
    SelectPage(window, page or Ordered()[1])
  else
    window.wanted = page
    window:Show()
  end
  window:Raise()
end

-- This file's own texts in the other languages (Locales files of each addon hold the rest).
T.Translations("deDE", {
  ["Tylesser addons have a settings window of their own, with room for everything."] = "Tylesser-Addons haben ein eigenes Einstellungsfenster, mit Platz für alles.",
  ["Open Tylesser settings"] = "Tylesser-Einstellungen öffnen",
  ["Press Ctrl+C to copy, then paste it into your browser."] = "Mit Strg+C kopieren, dann im Browser einfügen.",
  ["Found a bug or have an idea? Tell us on the Tylesser feedback page."] = "Einen Fehler gefunden oder eine Idee? Schreib uns auf der Tylesser-Feedbackseite.",
  ["More Tylesser addons are on tylesser.com."] = "Weitere Tylesser-Addons gibt es auf tylesser.com.",
  ["All Tylesser addons, with their features and changelogs, are on tylesser.com."] = "Alle Tylesser-Addons mit ihren Funktionen und Änderungen findest du auf tylesser.com.",
  ["Feedback"] = "Feedback",
  ["More addons"] = "Mehr Addons",
})
T.Translations("frFR", {
  ["Tylesser addons have a settings window of their own, with room for everything."] = "Les addons Tylesser ont leur propre fenêtre de réglages, avec de la place pour tout.",
  ["Open Tylesser settings"] = "Ouvrir les réglages Tylesser",
  ["Press Ctrl+C to copy, then paste it into your browser."] = "Ctrl+C pour copier, puis collez-le dans votre navigateur.",
  ["Found a bug or have an idea? Tell us on the Tylesser feedback page."] = "Un bug ou une idée ? Dites-le-nous sur la page de retours Tylesser.",
  ["More Tylesser addons are on tylesser.com."] = "D'autres addons Tylesser sur tylesser.com.",
  ["All Tylesser addons, with their features and changelogs, are on tylesser.com."] = "Tous les addons Tylesser, avec leurs fonctions et leurs nouveautés, sont sur tylesser.com.",
  ["Feedback"] = "Retours",
  ["More addons"] = "Autres addons",
})
T.Translations("esES", {
  ["Tylesser addons have a settings window of their own, with room for everything."] = "Los addons de Tylesser tienen su propia ventana de opciones, con sitio para todo.",
  ["Open Tylesser settings"] = "Abrir las opciones de Tylesser",
  ["Press Ctrl+C to copy, then paste it into your browser."] = "Pulsa Ctrl+C para copiar y pégalo en tu navegador.",
  ["Found a bug or have an idea? Tell us on the Tylesser feedback page."] = "¿Has encontrado un error o tienes una idea? Cuéntanoslo en la página de comentarios de Tylesser.",
  ["More Tylesser addons are on tylesser.com."] = "Más addons de Tylesser en tylesser.com.",
  ["All Tylesser addons, with their features and changelogs, are on tylesser.com."] = "Todos los addons de Tylesser, con sus funciones y novedades, están en tylesser.com.",
  ["Feedback"] = "Comentarios",
  ["More addons"] = "Más addons",
})
T.Translations("ruRU", {
  ["Tylesser addons have a settings window of their own, with room for everything."] = "У аддонов Tylesser своё окно настроек, где всё помещается.",
  ["Open Tylesser settings"] = "Открыть настройки Tylesser",
  ["Press Ctrl+C to copy, then paste it into your browser."] = "Нажмите Ctrl+C, чтобы скопировать, и вставьте в браузер.",
  ["Found a bug or have an idea? Tell us on the Tylesser feedback page."] = "Нашли ошибку или есть идея? Напишите нам на странице отзывов Tylesser.",
  ["More Tylesser addons are on tylesser.com."] = "Другие аддоны Tylesser — на tylesser.com.",
  ["All Tylesser addons, with their features and changelogs, are on tylesser.com."] = "Все аддоны Tylesser с описанием и списком изменений — на tylesser.com.",
  ["Feedback"] = "Отзыв",
  ["More addons"] = "Другие аддоны",
})
T.Translations("ptBR", {
  ["Tylesser addons have a settings window of their own, with room for everything."] = "Os addons da Tylesser têm uma janela de configurações própria, com espaço para tudo.",
  ["Open Tylesser settings"] = "Abrir as configurações da Tylesser",
  ["Press Ctrl+C to copy, then paste it into your browser."] = "Pressione Ctrl+C para copiar e cole no seu navegador.",
  ["Found a bug or have an idea? Tell us on the Tylesser feedback page."] = "Encontrou um erro ou tem uma ideia? Conte para nós na página de feedback da Tylesser.",
  ["More Tylesser addons are on tylesser.com."] = "Mais addons da Tylesser em tylesser.com.",
  ["All Tylesser addons, with their features and changelogs, are on tylesser.com."] = "Todos os addons da Tylesser, com funções e novidades, estão em tylesser.com.",
  ["Feedback"] = "Feedback",
  ["More addons"] = "Mais addons",
})
