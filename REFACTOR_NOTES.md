# TinyTooltip-Remake refactor notes

This refactor pass was applied against the uploaded addon package.

## Goals
- Improve flow and maintainability without removing existing features.
- Keep Blizzard API compatibility patterns already present in the addon.
- Reduce duplication in high-churn tooltip logic.
- Fix real behavior bugs discovered during review.

## Files changed
- `Config.lua`
- `About.xml`
- `Core.lua`
- `General.lua`
- `Item.lua`
- `Model.lua`
- `Mount.lua`
- `Target.lua`
- `Unit.lua`
- `Anchor.lua`
- `Options.lua`
- `LinkID.lua`
- `Spell.lua`
- `Quest.lua`

## Key changes

### Shared utility layer in `Core.lua`
Added `addon.Util` with reusable helpers for:
- protected API calls
- safe boolean evaluation
- tooltip line lookup
- tooltip line text reads
- color-code stripping
- safe string concatenation
- safe unit GUID access

This reduces repeated `pcall` helper definitions across feature files and gives the addon a cleaner internal contract.

### Status bar flow cleanup in `General.lua`
Refactored status bar behavior into smaller functions:
- unit resolution
- color handling
- dead/live text rendering
- font + widget initialization
- database load path

Behavior is preserved while making the execution path easier to follow and safer to change later.

### Item tooltip fix in `Item.lua`
Fixed a real settings mismatch:
- the addon used `showStackCount`
- the config and options use `showItemMaxStack`

The refactor now respects the configured option and keeps icon + expansion handling in dedicated helpers.

### Model handling cleanup in `Model.lua`
Split model work into:
- creation
- reset
- show/hide decision
- update

This removes repeated branching and keeps the GameTooltip model lifecycle explicit.

### Mount cache fix in `Mount.lua`
Fixed a real logic bug:
- the old code checked `#mounts > 0` on a dictionary table keyed by spell ID
- that length check does not work reliably for non-array tables

The refactor now counts cached mounts explicitly and uses a source fallback when mount source text is missing.

### Target line flow cleanup in `Target.lua`
Refactored target display logic into smaller helpers for:
- target text resolution
- target line lookup/update
- duplicate target line cleanup
- target-of-target resolution
- right-click hint cleanup
- targeted-by summary generation

This keeps existing capacity while making the file much easier to reason about.

### Unit tooltip composition cleanup in `Unit.lua`
Refactored the heaviest tooltip content path into focused helpers for:
- specialization line preservation
- specialization icon resolution
- optional player-only payload gathering
- tooltip row writing
- NPC title formatting
- faction/hint cleanup
- quick focus binding resolution

This keeps the same feature set but removes a lot of repeated branching and local helper duplication.

### Anchor state cleanup in `Anchor.lua`
Refactored the anchor path into smaller responsibilities for:
- anchor cache refresh
- combat hide rule resolution
- cursor tracking
- static anchor fallback
- mouseover context resolution
- modifier key matching

This also fixes a subtle fallback issue where inherited/static return positioning could ignore the configured anchor point on some code paths.

### Options/UI state cleanup in `Options.lua`
Refactored the option-state plumbing around a few high-churn paths:
- centralized tooltip iteration for style updates
- split general-setting trigger handling into smaller helpers
- fixed font-setting updates so they no longer rely on a leaked loop variable
- added live status-bar position refresh when offset/position options change
- replaced repeated dotted-path traversal with reusable path-resolution helpers
- ensured the `SavedVariablesPerCharacter` toggle always mirrors into the global saved variables table

This keeps the existing options UI intact while making future maintenance safer and more predictable.


### Link/ID flow cleanup in `LinkID.lua`
Refactored ID-display handling into smaller helpers for:
- exact tooltip label detection
- modifier-gated display decisions
- tooltip item/spell payload resolution
- item link segment parsing
- wrapped bonus-id formatting
- achievement button hook guards

This keeps the same feature set while reducing duplication and avoiding repeated `HookScript` attachments on recycled achievement UI buttons.

### Spell tooltip safety cleanup in `Spell.lua`
Refactored spell tooltip styling into focused helpers for:
- safe spell texture resolution
- tooltip header icon insertion
- shared spell-style application
- tooltip spell-id fallback resolution

This also fixes a compatibility hazard where the file could error at load time if `GetSpellTexture` was unavailable and `C_Spell` was also nil.

### Quest tooltip border cleanup in `Quest.lua`
Refactored quest hyperlink handling into helpers for:
- quest-id parsing
- difficulty color resolution
- guarded border-color application

Behavior is preserved while making the hyperlink path clearer and safer.


### Chat-link hover cleanup in `ChatHover.lua`
Refactored chat hyperlink hover handling into smaller helpers for:
- supported link-type detection
- tooltip owner setup
- current hover-tooltip cleanup
- battle pet tooltip routing
- guarded chat-frame hook registration

This keeps the same chat hover behavior while making tooltip cleanup and cursor anchoring more reliable.

### Dialogue UI compatibility cleanup in `DialogueUICompat.lua`
Refactored DialogueUI scaling support into helpers for:
- desired tooltip-scale computation
- tooltip iteration
- one-time DialogueUI hook installation
- one-time scale-detector installation
- per-tooltip scale-hook registration
- guarded dialogue scale activation/deactivation

This keeps DialogueUI compatibility intact while reducing repeated hook work and making scale state clearer.

### Extra frame skin registration cleanup in `SkinFrames.lua`
Refactored extra tooltip-frame registration into helpers for:
- late global frame resolution
- duplicate-registration guards
- immediate style initialization for newly discovered frames
- login/addon-load refresh for late Blizzard UI frames

This preserves the addon's extra-frame skinning behavior while making late-loaded tooltip discovery more reliable.

## Notes
This pass intentionally avoided changing the addon's public feature surface or configuration schema.
This pass completes the main structural cleanup requested for the addon while preserving its existing feature surface.


### Default-schema cleanup in `Config.lua`
Refactored repeated default-table literals into small constructor helpers for:
- color tuples
- background descriptors
- anchor descriptors

This keeps the existing configuration schema intact while making the defaults easier to audit and less error-prone to extend.

### About page cleanup in `About.xml` + `Options.lua`
Refactored the About page support into explicit Lua helpers for:
- URL edit-box show/reset behavior
- guarded highlight/reset handling
- localized text lookup with alias fallback

This removes fragile inline XML scripting and avoids recursive text-reset behavior in the copyable help URL field.

### Locale key consistency cleanup
Standardized the announcement option keys around `general.announcements` while preserving the legacy misspelled `general.annoucements` entries as compatibility aliases in shipped locale files.

This lets the options UI use consistent naming without breaking existing locale lookups.
