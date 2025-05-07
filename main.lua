local f = CreateFrame("Frame")

-- Color helper (RGB: 1.0 scale)
local function ColorText(text, r, g, b)
  return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

-- Evaluate a single item for /bvde
local function EvaluateItem(bag, slot)
  local itemLink = GetContainerItemLink(bag, slot)
  if not itemLink then return end

  local _, _, rarity, _, _, itemType = GetItemInfo(itemLink)
  if not rarity then
    C_Timer.After(1, function() EvaluateItem(bag, slot) end)
    return
  end

  if rarity < 2 then return end
  if itemType ~= "Armor" and itemType ~= "Weapon" then return end

  local itemString = TSMAPI:GetItemString(itemLink)
  if not itemString then return end

  local vendorFunc = TSMAPI:ParseCustomPrice("vendorSell")
  local deFunc = TSMAPI:ParseCustomPrice("Disenchant")
  local vendorValue = vendorFunc and vendorFunc(itemString) or 0
  local deValue = deFunc and deFunc(itemString) or 0

  local difference = math.abs(vendorValue - deValue)
  if difference < 100 then return end

  if deValue > vendorValue then
    print(ColorText(itemLink .. " → Disenchant (" .. GetCoinTextureString(deValue) .. ")", 0.2, 1, 0.2))
  elseif vendorValue > deValue then
    print(ColorText(itemLink .. " → Vendor (" .. GetCoinTextureString(vendorValue) .. ")", 1, 0.85, 0))
  else
    print(ColorText(itemLink .. " → Equal value", 1, 1, 1))
  end
end

local function EvaluateBagItems()
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      EvaluateItem(bag, slot)
    end
  end
end

-- Slash command to manually evaluate items
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  SLASH_BVDE1 = "/bvde"
  SlashCmdList["BVDE"] = function()
    print(ColorText("[Void or Coin] Evaluating bag items...", 0.5, 0.8, 1))
    EvaluateBagItems()
  end
end)

-- Tooltip enhancement
GameTooltip:HookScript("OnTooltipSetItem", function(self)
  local _, link = self:GetItem()
  if not link then return end

  local _, _, rarity, _, _, itemType = GetItemInfo(link)
  if not rarity or rarity < 2 then return end
  if itemType ~= "Armor" and itemType ~= "Weapon" then return end

  local itemString = TSMAPI:GetItemString(link)
  if not itemString then return end

  local vendorFunc = TSMAPI:ParseCustomPrice("vendorSell")
  local deFunc = TSMAPI:ParseCustomPrice("Disenchant")
  local vendorValue = vendorFunc and vendorFunc(itemString) or 0
  local deValue = deFunc and deFunc(itemString) or 0

  if vendorValue == 0 and deValue == 0 then return end

  local suggestion, color
  if deValue > vendorValue then
    suggestion = "Disenchant"
    color = "|cff33ff33"
  elseif vendorValue > deValue then
    suggestion = "Vendor"
    color = "|cffffcc00"
  else
    suggestion = "Equal Value"
    color = "|cffffffff"
  end

  self:AddLine(color .. "Void or Coin: " .. suggestion .. " (" .. GetCoinTextureString(math.max(deValue, vendorValue)) .. ")|r")
end)

-- UI Button on Vendor Frame
local sellButton = CreateFrame("Button", "VoidOrCoinSellButton", MerchantFrame, "UIPanelButtonTemplate")
sellButton:SetSize(175, 22)
sellButton:SetText("Sell `Void or Coin` Items")
sellButton:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -50, -40)
sellButton:Hide()

-- Tooltip for button
sellButton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
  GameTooltip:AddLine("Sell `Void or Coin` Items", 1, 1, 1)
  GameTooltip:AddLine("Automatically sells uncommon+ gear", 0.8, 0.8, 0.8)
  GameTooltip:AddLine("if vendor price > disenchant value.", 0.8, 0.8, 0.8)
  GameTooltip:Show()
end)
sellButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Simple soulbound check
function IsItemSoulbound(itemLink)
  GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
  GameTooltip:SetHyperlink(itemLink)
  for i = 1, GameTooltip:NumLines() do
    local text = _G["GameTooltipTextLeft" .. i]:GetText()
    if text and text:find(ITEM_SOULBOUND) then
      return true
    end
  end
  return false
end

-- Determine if item should be vendored
local function ShouldVendorItem(itemLink)
  if not itemLink then return false end
  local _, _, rarity, _, _, itemType, _, _, _, _, vendorPrice = GetItemInfo(itemLink)
  if not rarity or rarity < 2 or not vendorPrice then return false end
  if itemType ~= "Armor" and itemType ~= "Weapon" then return false end
  if IsItemSoulbound(itemLink) then return false end

  local itemString = TSMAPI:GetItemString(itemLink)
  if not itemString then return false end

  local vendorFunc = TSMAPI:ParseCustomPrice("vendorSell")
  local deFunc = TSMAPI:ParseCustomPrice("Disenchant")
  local vendorValue = vendorFunc and vendorFunc(itemString) or 0
  local deValue = deFunc and deFunc(itemString) or 0

  return vendorValue > deValue
end

-- Vendor matching items
local function SellVoidOrCoinItems()
  local soldCount = 0
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local itemLink = GetContainerItemLink(bag, slot)
      if ShouldVendorItem(itemLink) then
        UseContainerItem(bag, slot)
        soldCount = soldCount + 1
      end
    end
  end
  print("|cff33ff99[Void or Coin]|r Sold " .. soldCount .. " item(s).")
end

sellButton:SetScript("OnClick", SellVoidOrCoinItems)

-- Show/hide button when merchant is open
local merchantFrame = CreateFrame("Frame")
merchantFrame:RegisterEvent("MERCHANT_SHOW")
merchantFrame:RegisterEvent("MERCHANT_CLOSED")
merchantFrame:SetScript("OnEvent", function(_, event)
  if event == "MERCHANT_SHOW" then
    sellButton:Show()
  else
    sellButton:Hide()
  end
end)
