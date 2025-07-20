local function GetItemInfoTexture(name)
	local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(name);
	return texture
end

-- ========== Containers ==========
local function ContainerFrame_Update_Hook(frame)
	local id = frame:GetID();
	local name = frame:GetName();
	local itemButton;
	local texture, itemCount, locked, quality, readable;
	for i = 1, frame.size, 1 do
		itemButton = _G[name.."Item"..i];
		local itemLink = GetContainerItemLink(id, itemButton:GetID());
		if itemLink then
			texture = GetItemInfoTexture(itemLink);
		else
			texture = nil;
		end
		_, itemCount, locked, quality, readable = GetContainerItemInfo(id, itemButton:GetID());
		SetItemButtonTexture(itemButton, texture);
		SetItemButtonCount(itemButton, itemCount);
		SetItemButtonDesaturated(itemButton, locked, 0.5, 0.5, 0.5);
		if texture then
			ContainerFrame_UpdateCooldown(id, itemButton);
			itemButton.hasItem = 1;
			itemButton.locked = locked;
			itemButton.readable = readable;
		else
			_G[name.."Item"..i.."Cooldown"]:Hide();
			itemButton.hasItem = nil;
		end
	end
end

-- ========== Action Buttons ==========
local function ActionButton_Update_Hook(self)
	if self.isBonus and self.inTransition then
		return
	end
	local action = self.action;
	if not action then return end
	local icon = _G[self:GetName().."Icon"];
	local texture = GetActionTexture(action);
	local type, id = GetActionInfo(action);
	if texture == "Interface\\Icons\\INV_Misc_QuestionMark" and type == "item" then
		texture = GetItemInfoTexture(id);
	elseif texture == "Interface\\Icons\\INV_Misc_QuestionMark" and type == "spell" then
		local spellName = GetSpellName(id, "General");
		if spellName == "Attack" then
			texture = GetInventoryItemTexture("player", 16);
		elseif spellName == "Auto Shot" then
			texture = GetInventoryItemTexture("player", 18);
		end
	end
	if texture then
		icon:SetTexture(texture);
		icon:Show();
	else
		icon:Hide();
	end
end

hooksecurefunc("ActionButton_Update", function()
	local frame = this or _G[this:GetName()];
	if frame then
		ActionButton_Update_Hook(frame);
	end
end)

local function ActionButton_OnEvent_Hook(event)
	if event == "PLAYER_AURAS_CHANGED" then
		ActionButton_Update();
	end
end

-- ========== Spellbook Buttons ==========
local function SpellButton_UpdateButton_Hook()
	local id = SpellBook_GetSpellID(this:GetID());
	local name = this:GetName();
	local iconTexture = _G[name.."IconTexture"];
	local spellString = _G[name.."SpellName"];
	local subSpellString = _G[name.."SubSpellName"];
	if SpellBookFrame.bookType == BOOKTYPE_PET then return end
	local spellName, subSpellName = GetSpellName(id, SpellBookFrame.bookType);
	local texture = GetSpellTexture(id, SpellBookFrame.bookType);
	if texture == "Interface\\Icons\\INV_Misc_QuestionMark" then
		if spellName == "Attack" then
			texture = GetInventoryItemTexture("player", 16);
		elseif spellName == "Auto Shot" then
			texture = GetInventoryItemTexture("player", 18);
		end
		if not texture or #texture == 0 then
			iconTexture:Hide();
			spellString:Hide();
			subSpellString:Hide();
			_G[name.."Cooldown"]:Hide();
			_G[name.."AutoCastable"]:Hide();
			_G[name.."AutoCast"]:Hide();
			_G[name.."Highlight"]:SetTexture("Interface\\Buttons\\ButtonHilight-Square");
			this:SetChecked(false);
			_G[name.."NormalTexture"]:SetVertexColor(1, 1, 1);
			return
		end
		iconTexture:SetTexture(texture);
		iconTexture:Show();
		SpellButton_UpdateSelection();
	end
end

local function SpellButton_OnShow_Hook() this:RegisterEvent("PLAYER_AURAS_CHANGED") end
local function SpellButton_OnHide_Hook() this:UnregisterEvent("PLAYER_AURAS_CHANGED") end
local function SpellButton_OnEvent_Hook(event)
	if event == "PLAYER_AURAS_CHANGED" then
		SpellButton_UpdateButton();
	end
end

-- ========== Bank ==========
local function BankFrameItemButton_Update_Hook(button)
	local texture = _G[button:GetName().."IconTexture"];
	local inventoryID = button:GetInventorySlot();
	local textureName = GetInventoryItemTexture("player", inventoryID);
	local slotName = button:GetName();
	button.hasItem = nil;
	if button.isBag then
		local id, slotTextureName = GetInventorySlotInfo(string.sub(slotName, 10));
		local itemLink = GetInventoryItemLink("player", id);
		if itemLink then
			slotTextureName = GetItemInfoTexture(itemLink);
		end
		textureName = slotTextureName or textureName;
	end
	local itemLink = GetInventoryItemLink("player", inventoryID);
	if itemLink then
		textureName = GetItemInfoTexture(itemLink);
	end
	if textureName then
		texture:SetTexture(textureName);
		texture:Show();
		SetItemButtonCount(button, GetInventoryItemCount("player", inventoryID));
		button.hasItem = 1;
	else
		texture:Hide();
		SetItemButtonCount(button, 0);
	end
	BankFrameItemButton_UpdateLocked(button);
end

-- ========== Bags ==========
local f = CreateFrame("Frame", nil, UIParent);
local nextUpdate = 1;
local function SetBagButtonTexture(id)
	local frame = _G["CharacterBag"..(id - 1).."SlotIconTexture"];
	local name = GetBagName(id);
	if name and frame then
		local texture = GetItemInfoTexture(name);
		if frame:GetTexture() ~= texture then
			frame:SetTexture(texture);
		end
	end
end
local function BagSlotButton_UpdateChecked_Hook()
	for i = 1, NUM_CONTAINER_FRAMES do
		SetBagButtonTexture(i);
	end
end
function BagSlotButton_OnModifiedClick()
	if IsModifiedClick("OPENALLBAGS") then
		OpenAllBags();
	end
	BagSlotButton_UpdateChecked();
end
f:SetScript("OnUpdate", function(self, elapsed)
	nextUpdate = nextUpdate - elapsed;
	if nextUpdate < 0 then
		BagSlotButton_UpdateChecked_Hook();
		nextUpdate = 1;
	end
end);

-- ========== Right-click Equip ==========
local origItemLink;
local function ContainerFrameItemButton_OnEnter_Hook(self)
	origItemLink = GetContainerItemLink(self:GetParent():GetID(), self:GetID());
end
local function ContainerFrameItemButton_OnClick_Hook(button)
	local bagID = this:GetParent():GetID();
	local slot = this:GetID();
	itemLink = GetContainerItemLink(bagID, slot);
	if button == "RightButton" and itemLink == origItemLink then
		local _, _, _, _, _, itemType = GetItemInfo(itemLink);
		if itemType == "Armor" or itemType == "Weapon" then
			PickupContainerItem(bagID, slot);
			AutoEquipCursorItem();
		end
	end
	origItemLink = itemLink;
end

-- Secure Hooks
hooksecurefunc("ActionButton_OnEvent", ActionButton_OnEvent_Hook);
hooksecurefunc("ActionButton_Update", ActionButton_Update_Hook);
hooksecurefunc("BankFrameItemButton_Update", BankFrameItemButton_Update_Hook);
hooksecurefunc("BagSlotButton_UpdateChecked", BagSlotButton_UpdateChecked_Hook);
hooksecurefunc("ContainerFrame_Update", ContainerFrame_Update_Hook);
hooksecurefunc("ContainerFrameItemButton_OnEnter", ContainerFrameItemButton_OnEnter_Hook);
hooksecurefunc("ContainerFrameItemButton_OnClick", ContainerFrameItemButton_OnClick_Hook);
hooksecurefunc("SpellButton_OnEvent", SpellButton_OnEvent_Hook);
hooksecurefunc("SpellButton_OnHide", SpellButton_OnHide_Hook);
hooksecurefunc("SpellButton_OnShow", SpellButton_OnShow_Hook);
--hooksecurefunc("SpellButton_UpdateButton", SpellButton_UpdateButton_Hook);

if DEFAULT_CHAT_FRAME then
	DEFAULT_CHAT_FRAME:AddMessage("|cffff8000ArcCorrect has loaded!|r");
end

WOW_GetContainerItemInfo = GetContainerItemInfo;
function GetContainerItemInfo(index, id)
	local texture, itemCount, locked, quality, readable = WOW_GetContainerItemInfo(index, id);
	if texture and string.find(texture, "INV_Misc_QuestionMark") then
		local itemlink = GetContainerItemLink(index, id);
		if itemlink then
			local _, _, itemid = string.find(itemlink, "Hitem:(%d+):");
			local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemlink);
			texture = itemTexture;
		end
	end
	return texture, itemCount, locked, quality, readable;
end
