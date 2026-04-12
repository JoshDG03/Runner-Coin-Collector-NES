# MergedActividad Code Flow

This project is a standalone NES 6502 assembly game that combines:

- a compressed metatile background map
- a continuously running 2x2 animated player
- controller-based direction changes
- player-vs-map collision
- collectible coins with random respawn
- score and lives HUD
- a 2x2 animated enemy that chases the player
- increasing player and enemy speeds as coins are collected
- pause with Start
- game over and restart flow

The main entry point is `main` in `main.asm`. The reset entry point is `reset_handler` in `reset.asm`.

## File Overview

`main.asm`

- Includes all game modules.
- Loads palettes.
- Decompresses the packed metatile map into the nametable.
- Loads the attribute table.
- Draws the HUD.
- Enables rendering.
- Runs the main frame loop.
- Handles pause, coin collection, enemy contact, game over, and restart.

`reset.asm`

- Runs first after reset.
- Disables interrupts and rendering while the system starts.
- Waits for vblank.
- Clears OAM sprite Y positions.
- Jumps to `main`.

`controller.asm`

- Reads controller 1 from `$4016`.
- Stores the current button state in `controller1`.
- Tracks `previousController1` so Start toggles pause only once per press.
- Stores pause state in `pauseFlag`.

`player.asm`

- Owns player position, animation state, sprite drawing, and OAM DMA helper routines.
- `update_animation` reads the controller direction and advances movement using `playerMoveSpeedTicks`.
- `move_character` uses candidate movement and only commits a move if collision allows it.
- `draw_character` writes the player 2x2 metasprite into the OAM buffer.

`collision.asm`

- Owns the reusable map collision logic.
- Converts pixel positions into metatile coordinates.
- Reads metatile IDs from the packed 2-bit compressed map.
- Checks four corners of the player hitbox.
- Treats metatile `0` and metatile `2` as solid.

`enemy.asm`

- Owns enemy position, chase logic, collision checks, animation, and sprite drawing.
- `InitializeEnemy` places the enemy at a fixed spawn point.
- `UpdateEnemy` runs on a slower timer controlled by `enemyMoveSpeedTicks`.
- `DetermineEnemyChaseDirection` compares enemy position to player position.
- `AttemptEnemyMovement` tries the preferred axis, then the other axis if blocked.
- `CheckEnemyCandidatePosition` reuses the shared collision module.
- `DrawEnemySprites` writes the enemy 2x2 metasprite after the player sprites in OAM.

`coin.asm`

- Owns coin position, pseudo-random spawning, coin collection, and speed scaling.
- `InitCoinSystem` initializes the coin RNG and the starting player/enemy speeds.
- `SpawnCoin` finds a random walkable metatile that does not overlap the player or enemy.
- `CheckCoinCollected` tests player overlap with the coin.
- `IncreasePlayerSpeed` and `IncreaseEnemySpeed` reduce movement tick values after a coin is collected.
- `DrawCoinSprite` appends the coin sprite after the player and enemy sprites.

`hud.asm`

- Owns lives, score digits, HUD drawing, enemy touch handling, wall collision life loss, game over, and restart state.
- `InitHudSystem` starts the game with 3 lives and score 000.
- `AddScoreTen` increments the score by 10 per coin.
- `LoseOneLife` updates lives and enters the game-over state at 0 lives.
- `DrawGameOverScreen` replaces the map view with a game-over message.

`compressed_map.asm`

- Contains the packed 2-bit metatile map.
- The map is 16 metatiles wide by 15 metatiles tall.
- Each row uses 4 bytes, and each byte stores 4 metatile IDs.

`map.asm`

- Defines the `metatile_table`.
- Defines the `attrtable`.
- Maps metatile IDs to four background tile IDs each.

`palettes.pal`

- Contains background and sprite palette data loaded into `$3F00-$3F1F`.
- Provides the colors for the map, player, coin, and enemy.

`tileset.chr`

- Background pattern table data.

`sprites.chr`

- Sprite pattern table data.
- Contains player sprite tiles, enemy sprite tiles, HUD sprite graphics, and coin sprite graphics.

## Startup Flow

1. The NES starts at `reset_handler` in `reset.asm`.
2. `reset_handler` disables interrupts and rendering.
3. It waits for vblank.
4. It clears sprite OAM Y positions.
5. It jumps to `main`.
6. `main` clears PPU state variables and controller state.
7. `main` initializes the player.
8. `main` initializes the enemy.
9. `main` initializes the HUD and coin systems.
10. `main` loads palettes into `$3F00`.
11. `main` decompresses `packed_map` into nametable `$2000`.
12. `main` writes the attribute table to `$23C0`.
13. `main` draws the HUD.
14. `main` draws the first player, enemy, and coin sprite data into the OAM buffer.
15. `main` enables NMI and rendering.
16. The game enters `main_loop`.

## Main Loop Flow

The frame loop is in `main.asm`:

```asm
main_loop:
wait_vblank:
  LDA vblank_ready
  BEQ wait_vblank

  LDA #$00
  STA vblank_ready

  LDA gameState
  CMP #GAME_STATE_OVER
  BEQ game_over_loop

  LDA hudDirty
  BEQ hud_up_to_date
  JSR UpdateHudDynamic

hud_up_to_date:
  JSR ReadController
  JSR UpdatePauseToggle
  LDA pauseFlag
  BNE skip_game_updates

  JSR update_animation
  JSR CheckCoinCollected
  JSR UpdateEnemy
  JSR CheckEnemyHitPlayer

skip_game_updates:
  JSR clear_oam_buffer
  JSR draw_character
  JSR DrawEnemySprites
  JSR DrawCoinSprite

  JMP main_loop
```

What this means:

1. Wait until `nmi_handler` signals vblank.
2. Stop if the game is already in the game-over state and branch to the game-over loop.
3. Update the HUD if score or lives changed.
4. Read controller input.
5. Toggle pause if Start was newly pressed.
6. If paused, skip player and enemy updates.
7. If not paused, update player movement and animation.
8. Check coin collection.
9. Update enemy chase movement.
10. Check enemy contact against the player.
11. Clear the OAM buffer.
12. Draw the player, enemy, and coin.
13. Repeat forever.

## NMI Flow

The NMI handler in `main.asm` performs sprite DMA and refreshes scroll:

```asm
.proc nmi_handler
  JSR ppu_commit

  LDA PPUSTATUS
  LDA #$00
  STA PPUSCROLL
  STA PPUSCROLL

  LDA #$01
  STA vblank_ready
  RTI
.endproc
```

It keeps the rendered frame synchronized with vblank while the main loop handles gameplay logic.

## Player Movement And Collision Flow

The player uses candidate movement so movement logic and collision logic stay separate.

The pattern is:

```asm
LDA player_x
STA candidatePlayerX
LDA player_y
STA candidatePlayerY

; Modify candidate position based on direction.

JSR IsPlayerCandidatePositionBlocked
LDA collisionResult
BNE blocked

LDA candidatePlayerX
STA player_x
LDA candidatePlayerY
STA player_y
```

If `collisionResult` is `$00`, the move is allowed.

If `collisionResult` is nonzero, the move is rejected. For player wall collisions, the HUD system also removes one life through `HandlePlayerWallCollision`.

## Coin System Flow

The coin system is responsible for three things:

1. spawning a coin at a legal random map position
2. detecting collection
3. increasing difficulty after each collection

When a coin is collected:

1. The score increases by 10.
2. The player speed increases by lowering `playerMoveSpeedTicks`.
3. The enemy speed also increases by lowering `enemyMoveSpeedTicks`.
4. A new coin is spawned in a new random walkable position.

Current speed values:

- player start speed: `$06`
- player minimum speed: `$02`
- enemy start speed: `$10`
- enemy minimum speed: `$04`

Lower values mean the object moves more often.

## Enemy Movement And Collision Flow

The enemy chases the player without full pathfinding.

The enemy update flow is:

1. `UpdateEnemy` increments `enemyMoveTimer`.
2. If the timer has not reached `enemyMoveSpeedTicks`, the enemy does not move this frame.
3. When the timer reaches the speed value, the timer resets.
4. `enemyAnimFrame` toggles for animation.
5. `DetermineEnemyChaseDirection` compares the enemy position to the player.
6. `AttemptEnemyMovement` tries to move toward the player.
7. If the preferred axis is blocked, the enemy tries the other axis.
8. `CheckEnemyCandidatePosition` reuses the same collision system as the player.

The enemy stays slower than the player because the enemy tick values remain larger than the player tick values.

## HUD, Lives, And Game Over Flow

The HUD system tracks:

- `livesRemaining`
- `scoreHundredsDigit`
- `scoreTensDigit`
- `gameState`

At the start of a new game:

- lives = `3`
- score = `000`
- state = playing

Life loss can happen in two ways:

- the player collides with a solid wall or obstacle
- the enemy overlaps the player

When lives reach 0:

1. `LoseOneLife` sets `gameState` to game over.
2. The main loop enters `game_over_loop`.
3. `DrawGameOverScreen` clears the screen and writes the game-over message.
4. Pressing Start from the game-over screen restarts the game through `restart_game`.

## Pause Flow

Pause is controlled by Start.

`ReadController` reads the current controller state. `UpdatePauseToggle` then checks whether Start is pressed now but was not pressed on the previous frame. If so, it toggles `pauseFlag`.

When `pauseFlag` is `$01`, the main loop skips:

- `update_animation`
- `CheckCoinCollected`
- `UpdateEnemy`
- `CheckEnemyHitPlayer`

The game still redraws sprites every frame, so the current scene remains visible while paused.

## Map Compression And Metatile Layout

The map uses 2-bit metatile compression:

- screen size: `16 x 15` metatiles
- each metatile: `16 x 16` pixels
- each row: `4` packed bytes
- each byte: `4` metatile IDs

That means the full map uses only `60` bytes of packed metatile data for the visible playfield.

The current map uses metatile IDs `0`, `1`, `2`, and `3`.

Current counts in `packed_map`:

- type `0`: `58`
- type `1`: `82`
- type `2`: `51`
- type `3`: `49`

This satisfies the requirement for a map surrounded by walls, with many metatiles and multiple metatile types.

## Sprite Drawing Flow

The OAM buffer starts at `$0200`.

Each hardware sprite uses 4 bytes:

1. Y position
2. tile ID
3. attributes
4. X position

The draw order is:

1. player
2. enemy
3. coin

After the draw routines update the OAM buffer, `ppu_commit` copies `$0200-$02FF` into sprite memory using DMA.

## Build Command

From inside `MergedActividad`:

```powershell
ca65 main.asm -o main.o
ca65 reset.asm -o reset.o
ld65 reset.o main.o -C nes.config -o MergedActividad.nes
```

## Current Scope

Implemented:

- compressed background map rendering
- controller steering with continuous movement
- 4-direction player animation
- player-vs-map collision
- coin collection and random respawn
- score HUD
- life system
- wall damage and enemy damage
- animated enemy rendering
- enemy chase movement
- enemy-vs-map collision
- speed scaling for player and enemy
- pause toggle with Start
- game over screen
- restart from game over with Start
