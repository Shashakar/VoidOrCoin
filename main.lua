-- Void or Coin Addon - Full Lua with Auctionator + TSM support

local f = CreateFrame("Frame")

VoidOrCoinAccountStats = VoidOrCoinAccountStats or {}
VoidOrCoinAccountStats.vendorGoldTotal = VoidOrCoinAccountStats.vendorGoldTotal or 0
VoidOrCoinAccountStats.deGoldTotal = VoidOrCoinAccountStats.deGoldTotal or 0

VoidOrCoinStats = VoidOrCoinStats or {}
VoidOrCoinStats.vendorGoldTotal = VoidOrCoinStats.vendorGoldTotal or 0
VoidOrCoinStats.deGoldTotal = VoidOrCoinStats.deGoldTotal or 0

-- Get vendor price (native WoW API)
local function GetVendorValue(itemLink)
  if not itemLink then return 0 end
  return select(11, GetItemInfo(itemLink)) or 0
end

-- Get DE price from TSM or Auctionator
local function GetDisenchantValue(itemLink)
  if not itemLink then return 0 end
  if TSMAPI and TSMAPI.ParseCustomPrice and TSMAPI.GetItemString then
    local itemString = TSMAPI:GetItemString(itemLink)
    local deFunc = TSMAPI:ParseCustomPrice("Disenchant")
    return deFunc and deFunc(itemString) or 0
  elseif Atr_GetDisenchantPrice then
    return Atr_GetDisenchantPrice(itemLink) or 0
  end
  return 0
end

-- Color helper (RGB: 1.0 scale)
local function ColorText(text, r, g, b)
  return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

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

  local vendorValue = GetVendorValue(itemLink)
  local deValue = GetDisenchantValue(itemLink)

  local difference = math.abs(vendorValue - deValue)
  if difference < 100 then return end

  if deValue > vendorValue then
    print(ColorText(itemLink .. " \226\134\146 Disenchant (" .. GetCoinTextureString(deValue) .. ")", 0.2, 1, 0.2))
  elseif vendorValue > deValue then
    print(ColorText(itemLink .. " \226\134\146 Vendor (" .. GetCoinTextureString(vendorValue) .. ")", 1, 0.85, 0))
  else
    print(ColorText(itemLink .. " \226\134\146 Equal value", 1, 1, 1))
  end
end

local function EvaluateBagItems()
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      EvaluateItem(bag, slot)
    end
  end
end

f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  SLASH_VOC1 = "/voc"
  SlashCmdList["VOC"] = function(msg)
    msg = msg:lower():trim()
    if msg == "items" then
      print(ColorText("[Void or Coin] Evaluating bag items...", 0.5, 0.8, 1))
      EvaluateBagItems()
    elseif msg == "stats" then
      local v, d = VoidOrCoinStats.vendorGoldTotal or 0, VoidOrCoinStats.deGoldTotal or 0
      local earned = math.max(v - d, 0)
      local av, ad = VoidOrCoinAccountStats.vendorGoldTotal or 0, VoidOrCoinAccountStats.deGoldTotal or 0
      local aearned = math.max(av - ad, 0)
      print("|cff9370DB[VoidOrCoin]|r Character stats:")
      print(" - Vendor Total:   |cffffff00" .. GetCoinTextureString(v))
      print(" - DE Total:       |cff9999ff" .. GetCoinTextureString(d))
      print(" - Total Extra Earned:    |cff33ff33" .. GetCoinTextureString(earned))
      print("|cff9370DB[VoidOrCoin]|r Account stats:")
      print(" - Vendor Total:   |cffffff00" .. GetCoinTextureString(av))
      print(" - DE Total:       |cff9999ff" .. GetCoinTextureString(ad))
      print(" - Total Extra Earned:    |cff33ff33" .. GetCoinTextureString(aearned))
    elseif msg == "reset" then
      StaticPopupDialogs["VOCRESET_CONFIRM"] = {
        text = "Reset VoidOrCoin stats for this character?",
        button1 = "Yes",
        button2 = "Cancel",
        OnAccept = function()
          VoidOrCoinStats.vendorGoldTotal = 0
          VoidOrCoinStats.deGoldTotal = 0
          print("|cff9370DB[VoidOrCoin]|r Stats reset.")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
      }
      StaticPopup_Show("VOCRESET_CONFIRM")
    else
      print("|cff9370DB[VoidOrCoin]|r Usage:")
      print(" - /voc items : Evaluate bag items")
      print(" - /voc stats : Show character metrics")
      print(" - /voc reset : Reset metrics for this character")
    end
  end
end)

GameTooltip:HookScript("OnTooltipSetItem", function(self)
  local _, link = self:GetItem()
  if not link then return end
  local _, _, rarity, _, _, itemType = GetItemInfo(link)
  if not rarity or rarity < 2 or (itemType ~= "Armor" and itemType ~= "Weapon") then return end
  local vendorValue = GetVendorValue(link)
  local deValue = GetDisenchantValue(link)
  if vendorValue == 0 and deValue == 0 then return end
  local suggestion, color = "Equal Value", "|cffffffff"
  if deValue > vendorValue then
    suggestion, color = "Disenchant", "|cff33ff33"
  elseif vendorValue > deValue then
    suggestion, color = "Vendor", "|cffffcc00"
  end
  self:AddLine(color .. "Void or Coin: " .. suggestion .. " (" .. GetCoinTextureString(math.max(deValue, vendorValue)) .. ")|r")
end)

local sellButton = CreateFrame("Button", "VoidOrCoinSellButton", MerchantFrame, "UIPanelButtonTemplate")
sellButton:SetSize(175, 22)
sellButton:SetText("Sell Void or Coin Items")
sellButton:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -50, -40)
sellButton:Hide()

sellButton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
  GameTooltip:AddLine("Sell Void or Coin Items", 1, 1, 1)
  GameTooltip:AddLine("Automatically sells uncommon+ gear", 0.8, 0.8, 0.8)
  GameTooltip:AddLine("if vendor price > disenchant value.", 0.8, 0.8, 0.8)
  GameTooltip:AddLine(" ")
  local v, d = VoidOrCoinStats.vendorGoldTotal or 0, VoidOrCoinStats.deGoldTotal or 0
  local earned = math.max(v - d, 0)
  local av, ad = VoidOrCoinAccountStats.vendorGoldTotal or 0, VoidOrCoinAccountStats.deGoldTotal or 0
  local aearned = math.max(av - ad, 0)
  GameTooltip:AddLine("Total Extra Earned (Character): " .. GetCoinTextureString(earned), 0.2, 1, 0.2)
  GameTooltip:AddLine("Total Extra Earned (Account):  " .. GetCoinTextureString(aearned), 0.6, 0.8, 1)
  GameTooltip:Show()
end)

sellButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function IsItemSoulbound(itemLink)
  GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
  GameTooltip:SetHyperlink(itemLink)
  for i = 1, GameTooltip:NumLines() do
    local text = _G["GameTooltipTextLeft" .. i]:GetText()
    if text and text:find(ITEM_SOULBOUND) then return true end
  end
  return false
end

local function ShouldVendorItem(itemLink)
  if not itemLink then return false end
  local _, _, rarity, _, _, itemType, _, _, _, _, vendorPrice = GetItemInfo(itemLink)
  if not rarity or rarity < 2 or not vendorPrice then return false end
  if itemType ~= "Armor" and itemType ~= "Weapon" then return false end
  if IsItemSoulbound(itemLink) then return false end
  local vendorValue = GetVendorValue(itemLink)
  local deValue = GetDisenchantValue(itemLink)
  return vendorValue > deValue
end

local function SellVoidOrCoinItems()
  local soldCount = 0
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local itemLink = GetContainerItemLink(bag, slot)
      if ShouldVendorItem(itemLink) then
        local vendorValue = GetVendorValue(itemLink)
        local deValue = GetDisenchantValue(itemLink)
        UseContainerItem(bag, slot)
        soldCount = soldCount + 1
        VoidOrCoinStats.vendorGoldTotal = (VoidOrCoinStats.vendorGoldTotal or 0) + vendorValue
        VoidOrCoinStats.deGoldTotal = (VoidOrCoinStats.deGoldTotal or 0) + deValue
        VoidOrCoinAccountStats.vendorGoldTotal = (VoidOrCoinAccountStats.vendorGoldTotal or 0) + vendorValue
        VoidOrCoinAccountStats.deGoldTotal = (VoidOrCoinAccountStats.deGoldTotal or 0) + deValue
      end
    end
  end
  print("|cff33ff99[Void or Coin]|r Sold " .. soldCount .. " item(s).")
end

sellButton:SetScript("OnClick", SellVoidOrCoinItems)

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