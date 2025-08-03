local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayMode = ReplicatedStorage:WaitForChild("PlayMode")
local UnitsSettings = PlayMode:WaitForChild("Modules"):WaitForChild("UnitsSettings")

local Options = Library.Options
local Toggles = Library.Toggles

local profileNameMap = {}

local function getUnitNames()
	local unitNames = {}
	local possiblePaths = {
		ReplicatedStorage:FindFirstChild("UnitStorage"),
		ReplicatedStorage:FindFirstChild("Units"),
		ReplicatedStorage:FindFirstChild("PlayMode") and ReplicatedStorage.PlayMode:FindFirstChild("Units"),
		ReplicatedStorage:FindFirstChild("PlayMode") and ReplicatedStorage.PlayMode:FindFirstChild("UnitStorage"),
		ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Units"),
		UnitsSettings
	}

	for _, path in ipairs(possiblePaths) do
		if path then
			for _, child in pairs(path:GetChildren()) do
				table.insert(unitNames, child.Name)
			end
			break
		end
	end

	local uniqueNames, seen = {}, {}
	for _, name in ipairs(unitNames) do
		if not seen[name] then
			seen[name] = true
			table.insert(uniqueNames, name)
		end
	end

	return #uniqueNames > 0 and uniqueNames or {"No units found"}
end

local function getCosmeticUnitNames()
	local unitNames = {}

    for _, child in pairs(game:GetService("ReplicatedStorage").Cosmetic:GetChildren()) do
        table.insert(unitNames, child.Name)
    end



	local uniqueNames, seen = {}, {}
	for _, name in ipairs(unitNames) do
		if not seen[name] then
			seen[name] = true
			table.insert(uniqueNames, name)
		end
	end

	return #uniqueNames > 0 and uniqueNames or {"No units found"}
end

local function getUnitProfiles()
	local profileList = {}
	profileNameMap = {}

	local player = Players.LocalPlayer
	if not player then return {"No profiles found"} end

	local possiblePaths = {
		player:FindFirstChild("UnitsInventory"),
		player:FindFirstChild("UnitInventory"),
		player:FindFirstChild("Inventory"),
		player:FindFirstChild("Units"),
	}

	for _, path in ipairs(possiblePaths) do
		if path then
			for _, profile in ipairs(path:GetChildren()) do
				if profile:IsA("Folder") then
					local id = profile.Name

					local trait = profile:FindFirstChild("data")
						and profile.data:FindFirstChild("traits")
						and profile.data.traits:FindFirstChild("1")
					local traitName = (trait and trait.Value ~= "") and trait.Value or "Traitless"

					local artifact = profile:FindFirstChild("Artifacts")
					local artifactName = (artifact and artifact.Value ~= "") and artifact.Value or "No artifact"

					local displayName = traitName .. " / " .. artifactName

					table.insert(profileList, displayName)
					profileNameMap[displayName] = id
				end
			end
			break
		end
	end

	if #profileList == 0 then
		profileList = {"Traitless / No artifact"}
		profileNameMap["Traitless / No artifact"] = "Default"
	end

	return profileList
end

-- Helper function to get unit settings table
local function GetUnitSettings(unitName)
	local unitModule = UnitsSettings:FindFirstChild(unitName)
	if not unitModule or not unitModule:IsA("ModuleScript") then return nil end

	local success, unitData = pcall(require, unitModule)
	if not success or typeof(unitData) ~= "table" then return nil end

	local settingsFunc = unitData.settings
	if typeof(settingsFunc) ~= "function" then return nil end

	return settingsFunc()
end

-- UI Setup
Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
	Title = "Wyvern.ag",
	Footer = "@velocityontop",
	NotifySide = "Right",
	ShowCustomCursor = true,
})

local Tabs = {
	Main = Window:AddTab("Lobby", "door-open"),
    Ingame = Window:AddTab("Match", "swords"),
	["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}


if workspace:FindFirstChild("GameSettings") then
local whatt = Tabs.Ingame:AddRightGroupbox("Match Details")

whatt:AddLabel(workspace.GameSettings.Stages.Value .. " - Act ".. workspace.GameSettings.Act.Value)

local difficulty = whatt:AddLabel(workspace.GameSettings.Difficulty.Value) 

local wave = whatt:AddLabel("Wave: " .. workspace.GameSettings.Wave.Value .. "/" .. workspace.GameSettings.MaxWave.Value) 


local function updateWaveText()
    wave:SetText("Wave: " .. workspace.GameSettings.Wave.Value .. "/" .. workspace.GameSettings.MaxWave.Value)
end

-- Connect to the Wave value's Changed event
workspace.GameSettings.Wave.Changed:Connect(updateWaveText)

-- Also connect to MaxWave in case that changes too
workspace.GameSettings.MaxWave.Changed:Connect(updateWaveText)

-- Set initial text
updateWaveText()
else
end

local LeftGroupBox = Tabs.Ingame:AddLeftGroupbox("Unit Selection")
local RightGroupbox = Tabs.Ingame:AddRightGroupbox("Profile Details")
local profileInfoLabel = RightGroupbox:AddLabel("Select a profile to view its details.", true)

LeftGroupBox:AddDropdown("UnitDropdown", {
	Values = {},
	Default = 1,
	Searchable = true,
	Multi = false,
	Text = "Select Unit",
	Tooltip = "Choose a unit from ReplicatedStorage.UnitStorage",
	Callback = function(Value)
		print("[cb] Selected unit:", Value)
	end,
})

LeftGroupBox:AddDropdown("ProfileDropdown", {
	Values = {},
	Default = 1,
	Multi = false,
	Searchable = true,
	Text = "Select Profile",
	Tooltip = "Choose a unit profile (trait/artifact)",
	Callback = function(Value)
		print("[cb] Selected profile display name:", Value)
	end,
})

Options.ProfileDropdown:OnChanged(function(displayName)
  local profileId = profileNameMap[displayName]
  if not profileId then
    print("Profile ID not found for:", displayName)
    return
  end

  local player = Players.LocalPlayer
  local profileFolder

  -- Search for profile folder in multiple locations
  for _, parentName in ipairs({
    "UnitsInventory",
    "UnitInventory",
    "Inventory",
    "Units",
  }) do
    local parent = player:FindFirstChild(parentName)
    if parent then
      local folder = parent:FindFirstChild(profileId)
      if folder then
        profileFolder = folder
        break
      end
    end
  end

  if not profileFolder then
    print("Profile folder not found for ID:", profileId)
    return
  end

  -- Get level with better error handling
  local levelText = "N/A"
  local data = profileFolder:FindFirstChild("data")
  if data then
    local levels = data:FindFirstChild("Levels")
    if levels and levels.Value then
      levelText = tostring(math.floor(tonumber(levels.Value) or 0))
    end
  end

  -- Get artifacts
  local artifacts = profileFolder:FindFirstChild("Artifacts")
  local artifactsText = "No artifact"
  if artifacts and artifacts.Value and artifacts.Value ~= "" then
    artifactsText = artifacts.Value
  end

  -- Format stats function with improved error handling
  local function formatStat(statName)
    if not data then
      return statName .. ": N/A"
    end

    local stat = data:FindFirstChild("stat")
    if not stat then
      return statName .. ": N/A"
    end

    local statObj = stat:FindFirstChild(statName)
    if not statObj then
      return statName .. ": N/A"
    end

    local percent = statObj:FindFirstChild("percents")
    local statname = statObj:FindFirstChild("statname")

    if percent and statname and percent.Value and statname.Value then
      return string.format(
        "%s: %s - %.2f%%",
        statName,
        statname.Value,
        tonumber(percent.Value) or 0
      )
    end

    return statName .. ": N/A"
  end

  local atkStat = formatStat("ATK")
  local rngStat = formatStat("RNG")
  local spaStat = formatStat("SPA")

  -- Get main trait
  local traitText = "None"
  if data then
    local traits = data:FindFirstChild("traits")
    if traits then
      local trait1 = traits:FindFirstChild("1")
      if trait1 and trait1.Value and trait1.Value ~= "" then
        traitText = trait1.Value
      end
    end
  end

  -- Get artifact trait
  local artifactTraitText = "None"
  if data then
    local traits = data:FindFirstChild("traits")
    if traits then
      local artifactTrait = traits:FindFirstChild("2") -- Changed from "ArtifactTrait" to "2"
      if artifactTrait and artifactTrait.Value and artifactTrait.Value ~= "" then
        artifactTraitText = artifactTrait.Value
      end
    end
  end

  -- Format and display the information with nil safety - FIXED: Changed second "Trait:" to "Artifact Trait:"
  local displayText = string.format(
    "Level: %s\nArtifacts: %s\n\n%s\n%s\n%s\n\nTrait: %s\nArtifact Trait: %s",
    levelText or "N/A",
    artifactsText or "N/A",
    atkStat or "ATK: N/A",
    rngStat or "RNG: N/A",
    spaStat or "SPA: N/A",
    traitText or "None",
    artifactTraitText or "None"
  )

  print("Artifacts found:", artifactsText)
  profileInfoLabel:SetText(displayText)
end)

local function UpdateProfileInfo()
	local displayName = Options.ProfileDropdown.Value
	local profileId = profileNameMap[displayName]
	if not profileId then return end

	local player = Players.LocalPlayer
	local profileFolder

	for _, path in ipairs({
		player:FindFirstChild("UnitsInventory"),
		player:FindFirstChild("UnitInventory"),
		player:FindFirstChild("Inventory"),
		player:FindFirstChild("Units"),
	}) do
		if path and path:FindFirstChild(profileId) then
			profileFolder = path:FindFirstChild(profileId)
			break
		end
	end
	if not profileFolder then return end

	local levels = profileFolder:FindFirstChild("data")
		and profileFolder.data:FindFirstChild("setting")
		and profileFolder.data:FindFirstChild("Levels")
	local levelText = levels and tostring(math.floor(levels.Value)) or "N/A"

	local artifacts = profileFolder:FindFirstChild("Artifacts")
	local artifactsText = (artifacts and artifacts.Value ~= "") and artifacts.Value or "No artifact"

	local function formatStat(statName)
		local stat = profileFolder:FindFirstChild("data")
			and profileFolder.data:FindFirstChild("stat")
			and profileFolder.data.stat:FindFirstChild(statName)
		if not stat then return statName .. ": N/A" end

		local percent = stat:FindFirstChild("percents")
		local statname = stat:FindFirstChild("statname")
		if percent and statname then
			return string.format("%s: %s - %.2f%%", statName, statname.Value, percent.Value)
		end
		return statName .. ": N/A"
	end

	local atkStat = formatStat("ATK")
	local rngStat = formatStat("RNG")
	local spaStat = formatStat("SPA")

	local trait = profileFolder:FindFirstChild("data")
		and profileFolder.data:FindFirstChild("traits")
		and profileFolder.data.traits:FindFirstChild("1")

	local traitText = "None"
	if trait and trait.Value and trait.Value ~= "" then
		traitText = trait.Value
	end

	local artifactTraitText = "None"
if artifacts and artifacts.Value then
    local itemsInventory = game:GetService("Players").LocalPlayer:FindFirstChild("ItemsInventory")
    if itemsInventory then
        local item = itemsInventory:FindFirstChild(tostring(artifacts.Value))
        if item then
            local traits = item:FindFirstChild("Traits")
            if traits and traits.Value then
                artifactTraitText = traits.Value
            end
        end
    end
end

	-- FIXED: Added artifact trait to format string
local displayText = string.format(
    "Level: %s\nArtifacts: %s\n\n%s\n%s\n%s\n\nTrait: %s\nArtifact Trait: %s",
    levelText,
    artifactsText,
    atkStat,
    rngStat,
    spaStat,
    traitText,
    artifactTraitText
)

profileInfoLabel:SetText(displayText)
end

Options.ProfileDropdown:OnChanged(function()
	UpdateProfileInfo()
end)


local unitNames = getUnitNames()
local cosmeticunitNames = getCosmeticUnitNames()
local profiles = getUnitProfiles()

Options.UnitDropdown:SetValues(unitNames)
Options.ProfileDropdown:SetValues(profiles)

if workspace:FindFirstChild("GameSettings") then
LeftGroupBox:AddButton({
	Text = "Spawn Unit",
	Func = function()
		local unitName = Options.UnitDropdown.Value
		local displayName = Options.ProfileDropdown.Value
		local profileName = profileNameMap[displayName]

		if not unitName or unitName == "No units found" then
			Library:Notify({ Title = "Error", Description = "No valid unit selected.", Time = 3 }) return
		end
		if not profileName then
			Library:Notify({ Title = "Error", Description = "No valid profile selected.", Time = 3 }) return
		end

		local player = Players.LocalPlayer
		local character = player.Character
		if not character then
			Library:Notify({ Title = "Error", Description = "Character not found.", Time = 3 }) return
		end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			Library:Notify({ Title = "Error", Description = "HumanoidRootPart not found.", Time = 3 }) return
		end

		local ohTable1 = {
			[1] = unitName,
			[2] = rootPart.CFrame - Vector3.new(0,2,0),
			[3] = 0
		}
		local ohString2 = profileName

		game:GetService("ReplicatedStorage").PlayMode.Events.spawnunit:InvokeServer(ohTable1, ohString2)

		Library:Notify({
			Title = "Success",
			Description = "Spawned " .. unitName .. " with profile " .. profileName,
			Time = 3,
		})
	end,
	Tooltip = "Spawn selected unit using selected profile",
})
else
end

if workspace:FindFirstChild("GameSettings") then
local autoVoteGroupBox = Tabs.Ingame:AddRightGroupbox("Auto-Save Units on Retry")

autoVoteGroupBox:AddToggle("AutoVoteOnStart", {
    Text    = "Auto Retry",
    Default = false,
    Tooltip = "Automatically votes to save units when a game starts.",
    Callback = function(enabled)
        if enabled then
            task.spawn(function()
                while enabled do
                    local gameSettings = workspace:FindFirstChild("GameSettings")
                    if gameSettings then
                        local gameStarted = gameSettings:FindFirstChild("GameStarted")
                        if gameStarted.Value == false then
                            -- Fire vote when game starts
                            game:GetService("ReplicatedStorage").PlayMode.Events.Vote:FireServer("Vote1")

                            Library:Notify({
                                Title       = "Auto Vote Sent",
                                Description = "Game started — vote sent automatically.",
                                Time        = 3,
                            })
							game:GetService("Players").LocalPlayer.PlayerGui.EndGUI.Enabled = false
                            -- Wait for game to end before checking again
                            repeat 
                                task.wait(0.25) 
                            until not gameStarted.Value or not enabled
                        end
                    end
                    task.wait(0.25)
                end
            end)
        end
    end
})
else
end

if workspace:FindFirstChild("GameSettings") then
else
local naurmore = Tabs.Main:AddLeftGroupbox("Summoning")

naurmore:AddDropdown("SummonDropdown", {
	Values = {"Standard Banner", "Event Banner", "Rukia Banner"},
	Default = 1,
	Searchable = true,
	Multi = false,
	Text = "Select Unit",
	Tooltip = "Choose a unit from ReplicatedStorage.UnitStorage",
	Callback = function(Value)
		print("[cb] Selected unit:", Value)
	end,
})

naurmore:AddInput("SummonAmount", {
	Default = "20",
	Numeric = true, -- true / false, only allows numbers
	Finished = false, -- true / false, only calls callback when you press enter
	ClearTextOnFocus = true, -- true / false, if false the text will not clear when textbox focused

	Text = "Summon Amount",
	Tooltip = "This is a tooltip", -- Information shown when you hover over the textbox

	Placeholder = "", -- placeholder text when the box is empty
	-- MaxLength is also an option which is the max length of the text

	Callback = function(Value)
	end,
})

naurmore:AddButton({
	Text = "Summon",
	Func = function()
		local selected = Options.SummonDropdown.Value
        local amount = Options.SummonAmount.Value
        if selected == "Standard Banner" then
        local ohString1 = "standard_summon"
        local ohString2 = amount

        game:GetService("ReplicatedStorage").PlayMode.Events.Summon:InvokeServer(ohString1, ohString2)
        elseif selected == "Event Banner" then
        local ohString1 = "event_summon"
        local ohString2 = amount

        game:GetService("ReplicatedStorage").PlayMode.Events.Summon:InvokeServer(ohString1, ohString2)
        elseif selected == "Rukia Banner" then
        local ohString1 = "ice_gacha"
        local ohNumber2 = amount

        game:GetService("ReplicatedStorage").PlayMode.Events.Summon:InvokeServer(ohString1, ohNumber2)
        end
		Library:Notify({
			Title = "Success",
			Description = "Summoned " .. amount .. " from the " .. selected,
			Time = 3,
		})
	end,
	Tooltip = "Spawn selected unit using selected profile",
})
end

if not workspace:FindFirstChild("GameSettings") then
	local toweradventures = Tabs.Main:AddRightGroupbox("Teleport Exploit")

	toweradventures:AddDropdown("StageDropdown", {
		Values = {"Mitsuri Event", "Tower Adventures 1", "Tower Adventures 2"},
		Default = 1,
		Searchable = true,
		Multi = false,
		Text = "Stage",
		Tooltip = "Select which map to teleport to.",
		Callback = function(Value) end,
	})

	toweradventures:AddInput("ActAmount", {
		Default = "1",
		Numeric = true,
		Finished = false,
		ClearTextOnFocus = true,
		Text = "Act",
		Tooltip = "Act number (used as difficulty or stage)",
		Placeholder = "",
		Callback = function(Value) end,
	})

	toweradventures:AddButton({
		Text = "Teleport",
		Func = function()
			local selected = Options.StageDropdown.Value
			local amount = tonumber(Options.ActAmount.Value) or 1 -- Ensure it's a number

			-- Step 1: Join the lobby
			game:GetService("ReplicatedStorage").PlayMode.Events.CreatingPortal:InvokeServer("Story", {
				[1] = "Large Village", -- or whatever default area is needed
				[2] = "1",
				[3] = "Normal"
			})

			-- Step 2: Create the actual portal
			local mapName, difficulty, category

			if selected == "Tower Adventures 1" then
				mapName = "Cursed Place"
				difficulty = tostring(amount)
				category = "Tower Adventures"
        elseif selected == "Tower Adventures 2" then
          mapName = "The Lost Ancient World"
          difficulty = tostring(amount) 
          category = "Tower Adventures"
			elseif selected == "Mitsuri Event" then
				mapName = "The Forest"
				difficulty = 1
				category = "Event"
			end

			game:GetService("ReplicatedStorage").PlayMode.Events.CreatingPortal:InvokeServer("Create", {
				[1] = mapName,
				[2] = difficulty,
				[3] = category
			})

			Library:Notify({
				Title = "Success",
				Description = "Summoned portal to " .. mapName .. " (" .. category .. ")",
				Time = 3,
			})
		end,
		Tooltip = "Summon the map using selected data.",
	})
end



if workspace:FindFirstChild("GameSettings") then
local TweenService = game:GetService("TweenService")
local infrangeshit = Tabs.Ingame:AddLeftGroupbox("Infinite Range")

local isEnabled = false

local function SetRNGLoop(active)
	enabled = active
	if active then
		task.spawn(function()
			while enabled do
				for _, child in ipairs(workspace.Ground.unitServer[game.Players.LocalPlayer.Name .. " (UNIT)"]:GetChildren()) do
					local rng = child:FindFirstChild("RNG")
					if rng and rng:IsA("NumberValue") then
						rng.Value = 999
					end
				end
				task.wait(0.1)
			end
		end)
	end
end

infrangeshit:AddToggle("testing", {
    Text    = "Enabled",
    Default = false,
    Tooltip = "Teleports units to enemy positions with smooth animations",
    Callback = function(enabled)
        isEnabled = enabled
        if enabled then
        SetRNGLoop(true)
        else
        SetRNGLoop(false)
        end
    end
})
else
end


if workspace:FindFirstChild("GameSettings") then
else
-- Create a new groupbox for redeeming codes
local CodeGroupbox = Tabs.Main:AddRightGroupbox("Codes")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local codeFolder = player:WaitForChild("Code")
local redeemRemote = ReplicatedStorage:WaitForChild("PlayMode"):WaitForChild("Events"):WaitForChild("Codes")
local totalRewardLabel = CodeGroupbox:AddLabel("Calculating total rewards...", true)

-- Function to fetch redeemable codes and accumulate their rewards
local function getTotalRewardsFromRedeemableCodes()
	local rewardTotals = {}

	for _, codeInstance in ipairs(codeFolder:GetChildren()) do
		local status = codeInstance:FindFirstChild("Status")
		if status and status:IsA("StringValue") and status.Value == "Active" then
			local rewardsFolder = codeInstance:FindFirstChild("Rewards")
			if rewardsFolder then
				for _, reward in ipairs(rewardsFolder:GetChildren()) do
					if reward:IsA("NumberValue") then
						rewardTotals[reward.Name] = (rewardTotals[reward.Name] or 0) + reward.Value
					end
				end
			end
		end
	end

	return rewardTotals
end


local function codebutton()
	CodeGroupbox:AddButton("Redeem All Codes", function()
	local codes = {}
	for _, codeInstance in ipairs(codeFolder:GetChildren()) do
		local status = codeInstance:FindFirstChild("Status")
		if status and status:IsA("StringValue") and status.Value == "Active" then
			table.insert(codes, codeInstance.Name)
		end
	end

	if #codes == 0 then
		Library:Notify({ Title = "No Codes", Description = "No redeemable codes found.", Time = 3 })
		return
	end

	for _, code in ipairs(codes) do
		redeemRemote:InvokeServer(code)
		task.wait(0.1)
	end

	Library:Notify({ Title = "Done", Description = "All active codes redeemed!", Time = 3 })
	updateRewardLabel()
end, "Automatically redeem all active codes")
end

local function updateRewardLabel()
	local rewardTotals = getTotalRewardsFromRedeemableCodes()
	if next(rewardTotals) == nil then
		totalRewardLabel:SetText("You've already redeemed all available codes.")
		return
	else
	codebutton()
	end

	local info = "Total Rewards from Redeemable Codes:\n"
	for currency, amount in pairs(rewardTotals) do
		info ..= string.format("- %s: %s\n", currency, amount)
	end
	totalRewardLabel:SetText(info)
end

-- Update once on load
updateRewardLabel()
end

if workspace:FindFirstChild("GameSettings") then
else
local function setupCapsuleUI()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")

    local LocalPlayer = Players.LocalPlayer
    local ItemsInventory = LocalPlayer:WaitForChild("ItemsInventory")
    local GiftPass = ReplicatedStorage:WaitForChild("GiftPass")
    local UseEvent = ReplicatedStorage:WaitForChild("PlayMode").Events:WaitForChild("Use")

    local LeftGroupBox2 = Tabs.Main:AddLeftGroupbox("Capsules/Bundles")

    local ValidItems = {}

    -- Only include items that are in both GiftPass and the player's inventory
    for _, item in ipairs(ItemsInventory:GetChildren()) do
        if GiftPass:FindFirstChild(item.Name) then
            table.insert(ValidItems, item.Name)
        end
    end

    -- Display message and skip buttons if none found
    if #ValidItems == 0 then
        LeftGroupBox2:AddLabel("No bundles found in your inventory.", true)
        return
    end

    -- UI setup
    local SelectedItem = ValidItems[1]
    local AmountToUse = 1

    -- Dropdown to select item
    LeftGroupBox2:AddDropdown("SelectItem", {
        Text = "Choose Bundle",
        Values = ValidItems,
        Default = ValidItems[1],
        Callback = function(value)
            SelectedItem = value
        end
    })

    -- Amount input
    LeftGroupBox2:AddInput("AmountToUse", {
        Text = "Amount",
        Default = "1",
        Numeric = true,
        Finished = true,
        Callback = function(value)
            AmountToUse = tonumber(value) or 1
        end
    })

    -- Normal Use Button
    LeftGroupBox2:AddButton({
        Text = "Use Selected Item",
        Func = function()
            if not SelectedItem or AmountToUse <= 0 then
                Library:Notify({
                    Title = "Error",
                    Description = "Invalid item or amount.",
                    Time = 3
                })
                return
            end

            UseEvent:InvokeServer(SelectedItem, AmountToUse)

            Library:Notify({
                Title = "Success",
                Description = "Used " .. AmountToUse .. "x " .. SelectedItem,
                Time = 3
            })
        end,
        Tooltip = "Uses the selected capsule or bundle by specified amount."
    })

    -- Obtain Button (negative use)
    LeftGroupBox2:AddButton({
        Text = "Obtain Selected Item",
        Func = function()
            if not SelectedItem or AmountToUse <= 0 then
                Library:Notify({
                    Title = "Error",
                    Description = "Invalid item or amount.",
                    Time = 3
                })
                return
            end

            UseEvent:InvokeServer(SelectedItem, -AmountToUse)

            Library:Notify({
                Title = "Success",
                Description = "Obtained " .. AmountToUse .. "x " .. SelectedItem,
                Time = 3
            })
        end,
        Tooltip = "Gives you the selected capsule or bundle."
    })
end


setupCapsuleUI()
end

if workspace:FindFirstChild("GameSettings") then
else
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local ItemsInventory = LocalPlayer:WaitForChild("ItemsInventory")
local GiftPass = ReplicatedStorage:WaitForChild("GiftPass")
local GiftEvent = ReplicatedStorage:WaitForChild("PlayMode").Events:WaitForChild("Gift")

local giftboxiguess = Tabs.Main:AddRightGroupbox("Auto-Gift")

-- Get giftable items from inventory
local ValidItems = {}
for _, item in ipairs(ItemsInventory:GetChildren()) do
    if GiftPass:FindFirstChild(item.Name) then
        table.insert(ValidItems, item.Name)
    end
end

if #ValidItems == 0 then
    giftboxiguess:AddLabel("❌ No giftable items.")
    return
end

-- Get player list excluding self
local function getOtherPlayers()
    local others = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(others, player.Name)
        end
    end
    return others
end

-- UI State
local SelectedItem = ValidItems[1]
local SelectedPlayer = getOtherPlayers()[1] or ""
local IsLooping = false

giftboxiguess:AddDropdown("Gift Item", {
    Text = "Select Item",
    Values = ValidItems,
    Default = SelectedItem,
    Callback = function(value)
        SelectedItem = value
    end
})

giftboxiguess:AddDropdown("Target Player", {
    Text = "Select Player",
    Values = getOtherPlayers(),
    Default = SelectedPlayer,
    Callback = function(value)
        SelectedPlayer = value
    end
})

giftboxiguess:AddToggle("Auto-Gift Toggle", {
    Text = "Auto-Gift Enabled",
    Default = false,
    Callback = function(state)
        IsLooping = state

        if IsLooping then
            task.spawn(function()
                while IsLooping and task.wait(0.5) do
                    if SelectedPlayer and SelectedItem then
                        local args = {
                            "Gift",
                            {
                                SelectedPlayer,
                                SelectedItem
                            }
                        }
                        GiftEvent:InvokeServer(unpack(args))
                    end
                end
            end)
        end
    end
})
end


-- UI Settings tab
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	NoUI = true,
	Text = "Menu keybind"
})
MenuGroup:AddButton("Unload", function() Library:Unload() end)
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("MyScriptHub")
SaveManager:SetFolder("MyScriptHub/specific-game")
SaveManager:SetSubFolder("specific-place")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()
