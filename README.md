# CleanUI

A minimalist UI addon for the **WoW Forever** beta (build 1.60.1.69893, Interface 16001). It strips away the clutter Blizzard leaves on screen — the bag bar, the micro menu, and the quest tracker — and shrinks the XP bar down to a thin sliver at the bottom of the screen.

No config screen, no dependencies, no saved settings to fiddle with. It just runs.

---

## What it does

| Element | What happens | Why |
|---|---|---|
| **Bag bar** | Hidden (backpack + all 4 bag slots) | You open bags with a keybind, not by clicking |
| **Micro menu** | Hidden (character, spellbook, talents, quest log, social, map, help, game menu, store, collections, EJ, LFD) | Everything here has a keybind or slash command |
| **Quest tracker** | Hidden (both `QuestWatchFrame` and `ObjectiveTrackerFrame`) | Toggle it back on demand with `/cleanui quest` |
| **XP bar** | Blizzard status bar hidden, replaced by an XP ring around the minimap | Keeps the info without eating screen space |

### Mini XP ring

Since the default status bar is hidden, CleanUI draws a **slim XP bar styled after the minimap zone-text bar**, sitting just beneath it and matching its width:

- **Purple** = current XP, **blue** = the rested bonus ahead of it, with a **gold percentage** on the right like the zone bar's clock.
- **Hover** it for the exact numbers (XP, remaining, rested).
- At **max level** it hides itself automatically.
- Toggle it with `/cleanui minixp` (aliases `mini`, `xp`).

## Addon list icon

The AddOns list shows an icon for CleanUI via `## IconTexture` in the TOC. It points at a built-in game icon (`Interface\ICONS\INV_Misc_Gear_01`), so nothing extra ships with the addon. To change it:

- **Another built-in icon** — swap the path, e.g. `Interface\ICONS\INV_Misc_Broom_01` (broom), `INV_Misc_Spyglass_02`, or any `Interface\ICONS\...` name (no file extension).
- **A built-in atlas** — use `## IconAtlas: <atlasName>` instead of `## IconTexture`.
- **A custom image** — drop a square `.tga` or `.blp` (e.g. 64×64) into the `CleanUI/` folder and point to it: `## IconTexture: Interface\AddOns\CleanUI\icon.tga`.

## Config panel

Run `/cleanui config` (aliases `gui`, `settings`) to open the settings page. It's draggable, and everything applies live:

**Hide elements** — checkboxes for the bag bar, micro menu, quest tracker, and Blizzard XP bar. (The bag/micro toggles are disabled in combat; the checkbox re-syncs if a click was blocked.)

**XP bar** — a "Show mini XP bar" checkbox plus four sliders:

| Slider | Adjusts |
|---|---|
| Width | bar length |
| Height | bar thickness |
| Horizontal offset | left/right position |
| Vertical offset | gap below the zone bar |

A **Reset XP bar size** button restores the size sliders to their defaults.

Every slash toggle (`/cleanui bagbar`, `/cleanui quest`, etc.) still works and stays in sync with the panel. Settings are saved to `CleanUIDB` — they'll persist between sessions **once Blizzard fixes SavedVariables on the beta**; until then they reset to defaults each login (see caveats).

Color knobs still live at the top of the XP module in `CleanUI.lua`: `XP_PURPLE` / `XP_BLUE` / `XP_GOLD`.

Everything re-applies automatically every time you log in or zone (`PLAYER_ENTERING_WORLD`), so the UI stays clean even after a `/reload`.

---

## Install

1. Copy the `CleanUI/` folder into your AddOns directory:
   ```
   World of Warcraft/_classic_beta_/Interface/AddOns/CleanUI/
   ```
   The folder must contain `CleanUI.toc` and `CleanUI.lua`.

2. Launch the game (or if you're already in, type `/reload`).

3. Open the character screen → **AddOns** (bottom-left) and make sure **CleanUI** is checked and **Load out of date AddOns** is enabled if the game complains about the interface version.

That's it. The bag bar, micro menu, and quest tracker disappear on your next login.

---

## How to use it in-game

Because the UI elements are hidden, here's how to still do everything you need:

### Open your bags
The bag *bar* is gone, not your bags. Use the default keybinds:
- **`B`** — open/close all bags
- **`Shift+B`** *(if bound)* — open bags one at a time
- You can rebind these under **Game Menu → Options → Keybindings → Interface Panel Functions**.

### Reach the menus that used to be in the micro bar
| I want to open... | Do this |
|---|---|
| Character sheet | press **`C`** |
| Spellbook | press **`P`** |
| Talents | press **`N`** |
| Quest log | press **`L`** |
| World map | press **`M`** |
| Social / friends | press **`O`** |
| Collections | press **`Shift+P`** |
| Game menu (logout, settings) | press **`Esc`** |

*(Defaults — check your keybindings if any don't respond.)*

### Toggle the quest tracker back on
When you actually need to see objectives:

```
/cleanui quest
```

Run it again to hide the tracker. The command flips whatever state it's currently in. Note the tracker starts **hidden** on every login (see caveat below).

### See all commands
```
/cleanui
```
Prints the list of available commands to chat.

---

## Slash commands

| Command | Effect |
|---|---|
| `/cleanui` | Print the command list |
| `/cleanui quest` | Toggle the quest tracker |
| `/cleanui expbar` | Toggle the XP / status bar |
| `/cleanui microbar` | Toggle the micro menu |
| `/cleanui bagbar` | Toggle the bag bar |
| `/cleanui find` | Print the frame name (and parent) under your mouse — use it to discover exact Forever frame names when something won't hide |

Every element starts **hidden** at login. Each command flips that element on or off independently. Short aliases work too: `bag`/`bags`, `micro`, `exp`/`xp`.

> **Combat note:** the bag bar and micro menu contain protected (secure) frames, so toggling them is blocked while you're in combat — CleanUI prints a notice and you can retry once combat ends. The XP bar and quest tracker toggle any time.

### Finding a frame that won't hide

Because Forever (interface `16001`) renames frames that don't match Retail, an element may leak through. To fix it:

1. Hover your mouse directly over the stubborn element (quest tracker, a bag slot, a micro button).
2. Run `/cleanui find` — it prints that frame's name and its parent to chat.
3. Add that name to the relevant list in `CleanUI.lua`, or reparent its container.

The built-in `/fstack` frame-stack tool does the same thing if you prefer hovering over typing.

---

## Beta caveats

These are limitations of the **WoW Forever beta client itself**, not bugs in CleanUI:

- **Settings don't persist.** The beta client writes SavedVariables on exit but never reads them back, so nothing is remembered between sessions. In practice this addon has no persistent settings anyway — it re-hides everything on login — but the quest tracker always starts **hidden** each session regardless of how you left it.
- **`/reload` only.** The in-game `ReloadUI()` is protected on this build. Use `/reload` typed into chat, not a macro/button that calls the function.
- **100-error cap.** After 100 Lua errors the client silently stops reporting them. If something breaks, fix the first error rather than chasing later noise.
- **Frame names may change between beta patches.** If an element stops hiding after a patch, a frame was probably renamed — see the development notes in `CleanUI-addon.md`.
- **The quest tracker is a managed Edit Mode frame** (`ObjectiveTrackerFrame`, parented to `RightManagedFrameContainer`). It resists a plain `:Hide()` *and* a `Show` hook, because the layout system re-shows it through an internal path that never calls `:Show()`. CleanUI keeps it down with a throttled watchdog (`OnUpdate`, ~10×/sec) that re-hides it whenever it reappears. This is intentional — don't "simplify" it back to a one-shot `:Hide()`, it will leak straight back on.

---

## Files

```
CleanUI/
├── CleanUI.toc   # addon manifest (interface version, metadata)
└── CleanUI.lua   # all the logic
```

Full design notes, known-issue tracking, and reference links live in [`CleanUI-addon.md`](./CleanUI-addon.md).
