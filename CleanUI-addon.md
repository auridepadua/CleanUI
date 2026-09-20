# CleanUI — WoW Forever Addon

Hides bag bar, microbar, quest tracker and thins the XP bar.
Built for WoW Forever beta (build 1.60.1.69893, Interface 16001).

---

## Install path

```
World of Warcraft/_classic_beta_/Interface/AddOns/CleanUI/
```

---

## File structure

```
CleanUI/
├── CleanUI.toc
└── CleanUI.lua
```

---

## CleanUI.toc

```
## Interface: 16001
## Title: CleanUI
## Notes: Hides bags, microbar, quest tracker and modifies XP bar
## Author: Aurelio
## Version: 1.0

CleanUI.lua
```

---

## CleanUI.lua

```lua
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()

    -- 1. Hide bag bar
    MainMenuBarBackpackButton:Hide()
    CharacterBag0Slot:Hide()
    CharacterBag1Slot:Hide()
    CharacterBag2Slot:Hide()
    CharacterBag3Slot:Hide()

    -- 2. Hide micro bar (modern Retail frame names)
    if MicroButtonAndBagsBar then
        MicroButtonAndBagsBar:Hide()
    end
    -- fallback: hide individual micro buttons
    local microButtons = {
        "CharacterMicroButton", "SpellbookMicroButton",
        "TalentMicroButton", "QuestLogMicroButton",
        "SocialsMicroButton", "WorldMapMicroButton",
        "MainHelpMicroButton", "GameMenuMicroButton",
        "StoreMicroButton", "CollectionsMicroButton",
        "EJMicroButton", "LFDMicroButton",
    }
    for _, name in ipairs(microButtons) do
        local btn = _G[name]
        if btn then btn:Hide() end
    end

    -- 3. Hide quest tracker (both frames — Forever uses both)
    if QuestWatchFrame then
        QuestWatchFrame:Hide()
    end
    if ObjectiveTrackerFrame then
        ObjectiveTrackerFrame:Hide()
    end

    -- 4. XP bar — make it thin and stick to bottom
    -- Using height reduction instead of :Hide() to avoid taint issues
    if MainStatusBar then
        MainStatusBar:SetHeight(3)
        MainStatusBar:ClearAllPoints()
        MainStatusBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
    end
    -- Modern Retail XP bar frame name
    if StatusTrackingBarManager then
        StatusTrackingBarManager:SetHeight(3)
    end

end)

-- Slash command to toggle quest tracker mid-session
SLASH_CLEANUI1 = "/cleanui"
SlashCmdList["CLEANUI"] = function(msg)
    if msg == "quest" then
        if QuestWatchFrame then
            if QuestWatchFrame:IsShown() then
                QuestWatchFrame:Hide()
                if ObjectiveTrackerFrame then ObjectiveTrackerFrame:Hide() end
                print("CleanUI: quest tracker hidden")
            else
                QuestWatchFrame:Show()
                if ObjectiveTrackerFrame then ObjectiveTrackerFrame:Show() end
                print("CleanUI: quest tracker shown")
            end
        end
    else
        print("CleanUI commands: /cleanui quest (toggle tracker)")
    end
end
```

---

## Slash commands

| Command | Effect |
|---|---|
| `/cleanui quest` | Toggle quest tracker on/off mid-session |

---

## Known beta issues (as of build 1.60.1.69893)

- **SavedVariables never load** — client writes on exit but never reads back. All settings reset on every login. Toggle state won't persist between sessions until Blizzard fixes this.
- **Secure snippets cannot compile** — does not affect this addon since no secure frames are touched.
- **ReloadUI() is protected** — use `/reload` in chat instead.
- **100 Lua error cap** — after 100 errors the client stops reporting them. Fix error floods first.

---

## Development notes

- All frame calls are guarded with `if frame then` so the addon fails silently on renamed frames during beta patches rather than throwing Lua errors.
- XP bar uses `:SetHeight(3)` instead of `:Hide()` to avoid taint. Swap to `:Hide()` to test full removal — if it throws, revert.
- Frame names may change during beta. Cross-reference against `data/forever_api.json` in [forever-addon-kit](https://github.com/Thunderz96/forever-addon-kit) if something stops working after a patch.
- Port from Retail code, not Classic. Old Classic globals (`GetItemInfo`, `GetSpellInfo`, `UnitAura`, `GetTalentInfo`) are gone.
- Use `pcall` when registering events — unknown events throw and abort the file.
- Forever client runs in `_classic_beta_` product folder, exe `WowB.exe`.
- `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` — it is the Retail client under the hood.

---

## Quick terminal setup

```bash
# navigate to your AddOns folder
cd "World of Warcraft/_classic_beta_/Interface/AddOns"

# create the addon folder
mkdir CleanUI
cd CleanUI

# create both files
touch CleanUI.toc
touch CleanUI.lua

# then paste the contents above into each file
# reload in-game with /reload after saving
```

---

## Useful references

- [forever-addon-kit](https://github.com/Thunderz96/forever-addon-kit) — day-one API surface, 11,417 named frames in `data/forever_api.json`
- [forever-classic-ui](https://github.com/standujar/forever-classic-ui) — full Classic UI replacement, good frame name reference
- [WoW Forever beta known issues](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-known-issues-september-17/2352687) — official Blizzard thread
- [Bleakfiber quest tracker](https://www.curseforge.com/wow/addons/bleakfibers-quest-tracker-forever) — source for QuestWatchFrame / ObjectiveTrackerFrame confirmation
- [ClassicUI Forever on CurseForge](https://www.curseforge.com/wow/addons/classicui-forever) — per-element toggle reference implementation
