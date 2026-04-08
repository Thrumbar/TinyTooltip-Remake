# TinyTooltip-Remake Git Changelog

## Suggested commit-style changelog

### refactor(core): introduce shared utility helpers and simplify tooltip internals
- add reusable internal helpers for protected calls, boolean guards, tooltip line access, string cleanup, and GUID reads
- reduce duplicated local helper definitions across tooltip feature modules
- improve maintainability without changing addon behavior

### refactor(general): clean up status bar initialization and update flow
- split status bar logic into smaller units for widget setup, color selection, live/dead text rendering, and saved-variable load flow
- preserve existing status bar behavior while making update paths easier to follow

### fix(item): honor configured max stack setting in item tooltip
- fix mismatch between `showStackCount` usage and configured `showItemMaxStack` option
- keep icon and expansion display behavior intact

### refactor(model): make tooltip model lifecycle explicit
- split model handling into create, update, reset, and show/hide helpers
- reduce repeated branching in GameTooltip model updates

### fix(mount): correct non-array mount cache completion logic
- replace unreliable `#mounts > 0` check on spell-keyed dictionary table
- count cached mounts explicitly
- add safer mount source fallback handling

### refactor(target): simplify target and targeted-by tooltip flow
- split target display logic into helpers for target text resolution, line updates, duplicate cleanup, and target-of-target resolution
- clean up right-click hint removal and targeted-by summary generation

### refactor(unit): break heavy unit tooltip composition into focused helpers
- separate specialization line preservation, spec icon resolution, optional player payload enrichment, row writing, NPC title formatting, and hint cleanup
- preserve player/NPC feature parity while reducing duplication and nesting

### refactor(anchor): reorganize anchor state and combat return behavior
- split anchor handling into cache refresh, combat hide rules, cursor tracking, static fallback, mouseover context resolution, and modifier matching
- make anchor flow easier to reason about and extend

### fix(anchor): preserve configured point during inherited/static return fallback
- fix subtle fallback path where configured anchor point could be ignored on some inherited/static return flows

### refactor(options): centralize option update plumbing and live style refresh
- centralize tooltip iteration for live style updates
- replace repeated dotted-path traversal with reusable path helpers
- keep options UI behavior intact while making settings propagation safer

### fix(options): apply font changes intentionally across tooltip instances
- remove reliance on leaked loop variable during header/body font setting updates
- ensure font changes are applied through explicit refresh flow

### feat(options): refresh status bar position live when offsets change
- add live update handling for `general.statusbarPosition`, `general.statusbarOffsetX`, and `general.statusbarOffsetY`

### fix(savedvars): mirror per-character toggle safely into global saved variables
- ensure `SavedVariablesPerCharacter` changes are synchronized more reliably

### refactor(linkid): simplify tooltip ID display and link parsing
- split item/spell ID display, modifier checks, link parsing, and wrapped bonus-id formatting into dedicated helpers
- reduce duplication in tooltip ID rendering paths

### fix(linkid): avoid repeated achievement button hook attachment
- guard achievement UI hook installation so recycled HybridScrollFrame buttons are not re-hooked repeatedly

### refactor(spell): harden spell tooltip icon and styling flow
- add safe spell texture resolution helpers
- split icon insertion and style application into focused helpers
- keep spell tooltip behavior unchanged for users

### fix(spell): prevent load-time nil dereference on clients without spell texture API
- guard `GetSpellTexture` fallback so file load does not error when both legacy and `C_Spell` APIs are unavailable

### refactor(quest): clean up quest hyperlink border styling
- split quest hyperlink parsing, difficulty color resolution, and guarded border-color application into small helpers

### refactor(chathover): simplify chat hyperlink tooltip handling
- add helper flow for supported link detection, tooltip cleanup, owner setup, battle pet routing, and guarded frame hooks
- improve reliability of cursor-anchored chat hover tooltips

### refactor(dialogueui): streamline DialogueUI compatibility hooks
- centralize desired tooltip scale computation and tooltip iteration
- add guarded one-time hook installation for DialogueUI and scale detectors
- reduce repeated hook work while preserving compatibility

### refactor(skinframes): improve late-loaded tooltip frame discovery
- resolve extra tooltip globals later instead of only at file load
- guard duplicate registration
- initialize styling immediately for newly discovered frames
- refresh late Blizzard tooltip frames during login/addon load

### refactor(config): replace repeated default literals with small constructors
- add helpers for color tuples, background descriptors, and anchor descriptors
- keep configuration schema unchanged while making defaults easier to audit

### refactor(about): move URL field behavior out of fragile inline XML scripting
- replace inline reset/highlight logic with guarded Lua helpers
- improve stability of copyable help URL interactions

### refactor(locale): normalize announcement option keys with compatibility aliases
- standardize on `general.announcements`
- keep legacy misspelled locale keys available as aliases to avoid breaking lookups

---

## Suggested squash commit message

`refactor: modernize TinyTooltip-Remake flow, fix tooltip setting bugs, and harden compatibility paths`

## Suggested short commit series

1. `refactor(core): add shared tooltip utility helpers`
2. `refactor(unit): simplify unit and target tooltip composition`
3. `refactor(anchor): clean up anchor and combat return flow`
4. `fix(item): respect showItemMaxStack setting`
5. `fix(mount): correct mount cache readiness check`
6. `refactor(options): centralize live option refresh handling`
7. `fix(spell): guard missing spell texture APIs at file load`
8. `refactor(linkid): simplify tooltip id rendering and hook guards`
9. `refactor(ui): clean up chat hover, DialogueUI, and extra frame skinning`
10. `refactor(config): normalize defaults, about-page helpers, and locale aliases`
