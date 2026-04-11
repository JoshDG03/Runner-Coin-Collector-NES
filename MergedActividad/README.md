# MergedActividad Code Flow

This project is a standalone NES 6502 assembly project that combines:

- the compressed metatile background map from `act 5`
- the animated 2x2 player
- controller movement
- player-vs-map collision
- a 2x2 animated enemy that chases the player

The main entry point is `main` in `main.asm`. The reset entry point is `reset_handler` in `reset.asm`.

## File Overview

`main.asm`

- Includes all game modules.
- Loads palettes.
- Decompresses the packed metatile map into the nametable.
- Loads the attribute table.
- Enables rendering.
- Runs the main frame loop.
- Calls controller, player, enemy, drawing, and OAM DMA routines each frame.

`reset.asm`

- Runs first after reset.
- Disables interrupts/rendering while the system starts.
- Waits for vblank.
- Clears OAM sprite Y positions.
- Jumps to `main`.

`controller.asm`

- Reads controller 1 from `$4016`.
- Stores the current button state in `controller1`.
- Tracks `previousController1` so Start can toggle pause only once per press.
- Stores pause state in `pauseFlag`.
- Defines the directional button masks:
  - `BUTTON_RIGHT`
  - `BUTTON_LEFT`
  - `BUTTON_DOWN`
  - `BUTTON_UP`
  - `BUTTON_START`

`player.asm`

- Owns player position, animation state, sprite drawing, and OAM DMA helper routines.
- `update_animation` reads `controller1`, updates the player direction, and runs movement at `PLAYER_MOVE_SPEED_TICKS`.
- `move_character` uses candidate movement:
  - copy `player_x/player_y` into `candidatePlayerX/candidatePlayerY`
  - modify the candidate position based on direction
  - call `IsPlayerCandidatePositionBlocked`
  - commit the move only if `collisionResult` is `$00`
- `draw_character` writes the player 2x2 sprite into the OAM buffer.

`collision.asm`

- Owns the reusable map collision logic.
- Converts pixel positions into metatile coordinates.
- Reads metatile IDs from the packed compressed map.
- Decides whether a metatile is solid.
- Checks four corners of a 16x16 candidate hitbox.
- Current solidity rule:
  - metatile `0` = solid border/wall
  - metatile `1` = walkable
  - metatile `2` = solid obstacle
  - metatile `3` = walkable

`enemy.asm`

- Owns enemy position, chase logic, collision checks, animation, and sprite drawing.
- `InitializeEnemy` places the enemy at `$80,$70`.
- `UpdateEnemy` runs on a slower timer, controlled by `ENEMY_MOVE_SPEED_TICKS`.
- `DetermineEnemyChaseDirection` compares enemy position to player position.
- `AttemptEnemyMovement` tries the preferred axis, then tries the other axis if blocked.
- `CheckEnemyCandidatePosition` reuses the shared collision module by copying the enemy candidate position into the shared candidate collision variables.
- `DrawEnemySprites` writes the animated 2x2 enemy sprite after the player sprites in OAM.

`compressed_map.asm`

- Contains the packed 2-bit metatile map.
- Each row has 4 bytes.
- Each byte stores 4 metatile IDs.
- Total map size is 16 metatiles wide by 15 metatiles tall.

`map.asm`

- Defines the `metatile_table`.
- Defines the `attrtable`.
- The metatile table maps each metatile ID to four background tile IDs: top-left, top-right, bottom-left, bottom-right.

`palettes.pal`

- Contains background and sprite palette data loaded into `$3F00-$3F1F`.
- Sprite palette 3 is used by the enemy wizard artwork.

`tileset.chr`

- Background pattern table data.

`sprites.chr`

- Sprite pattern table data.
- Contains player sprite tiles.
- Also contains copied partner wizard enemy animation tiles at `$20-$3B`.

## Startup Flow

1. The NES starts at `reset_handler` in `reset.asm`.
2. `reset_handler` disables interrupts and rendering.
3. It waits for vblank.
4. It clears sprite OAM Y positions.
5. It jumps to `main`.
6. `main` clears PPU state variables and initializes `controller1`.
7. `main` calls `init_player`.
8. `main` calls `InitializeEnemy`.
9. `main` loads palettes into `$3F00`.
10. `main` decompresses `packed_map` into nametable `$2000`.
11. `main` writes the attribute table to `$23C0`.
12. `main` draws the first player and enemy sprite data into the OAM buffer.
13. `main` enables NMI and rendering.
14. The game enters `main_loop`.

## Main Loop Flow

The frame loop is in `main.asm`:

```asm
main_loop:
wait_vblank:
  LDA vblank_ready
  BEQ wait_vblank

  LDA #$00
  STA vblank_ready

  JSR ReadController
  JSR UpdatePauseToggle
  LDA pauseFlag
  BNE skip_game_updates

  JSR update_animation
  JSR UpdateEnemy

skip_game_updates:
  JSR clear_oam_buffer
  JSR draw_character
  JSR DrawEnemySprites
  JSR ppu_commit

  JMP main_loop
```

What this means:

1. Wait until `nmi_handler` sets `vblank_ready`.
2. Read controller input.
3. Toggle pause if Start was newly pressed.
4. If paused, skip player and enemy updates.
5. If not paused, update player direction, animation, movement, and collision.
6. If not paused, update enemy chase movement and collision.
7. Clear the OAM buffer.
8. Draw the player into OAM.
9. Draw the enemy into OAM after the player.
10. Run OAM DMA using `ppu_commit`.
11. Repeat forever.

## NMI Flow

The NMI handler in `main.asm` is intentionally small:

```asm
.proc nmi_handler
  LDA #$01
  STA vblank_ready
  RTI
.endproc
```

It does not draw directly. It only tells the main loop that vblank happened. The main loop then updates game state and commits sprites.

## Player Movement And Collision Flow

The player uses candidate movement so controller logic and collision logic stay separate.

The important pattern is:

```asm
LDA player_x
STA candidatePlayerX
LDA player_y
STA candidatePlayerY

; Change candidatePlayerX or candidatePlayerY here.

JSR IsPlayerCandidatePositionBlocked
LDA collisionResult
BNE done

LDA candidatePlayerX
STA player_x
LDA candidatePlayerY
STA player_y
```

If `collisionResult` is `$00`, the move is allowed.

If `collisionResult` is `$01`, the move is blocked and the old position stays unchanged.

## Enemy Movement And Collision Flow

The enemy chases the player without pathfinding.

The enemy update flow is:

1. `UpdateEnemy` increments `enemyMoveTimer`.
2. If the timer has not reached `ENEMY_MOVE_SPEED_TICKS`, the enemy does not move this frame.
3. When the timer reaches the speed value, the timer resets.
4. `enemyAnimFrame` toggles for animation.
5. `DetermineEnemyChaseDirection` compares the enemy position to the player position.
6. `AttemptEnemyMovement` tries to move toward the player.
7. If the preferred axis is blocked, the enemy tries the other axis.
8. `CheckEnemyCandidatePosition` reuses the same collision system as the player.

The enemy is slower than the player because:

```asm
PLAYER_MOVE_SPEED_TICKS = $08
ENEMY_MOVE_SPEED_TICKS  = $10
```

Higher values mean slower movement.

## Pause Flow

Pause is controlled by Start.

`ReadController` reads the current controller state. `UpdatePauseToggle` then checks whether Start is pressed now but was not pressed on the previous frame. If so, it toggles `pauseFlag`.

When `pauseFlag` is `$01`, the main loop skips:

- `update_animation`
- `UpdateEnemy`

The game still clears and redraws OAM, so the player and enemy remain visible in their current positions while paused. Press Start again to set `pauseFlag` back to `$00` and resume updates.

## Sprite Drawing Flow

The OAM buffer starts at `$0200`.

Each sprite uses 4 bytes:

1. Y position
2. tile ID
3. attributes
4. X position

The player is drawn first by `draw_character`.

The enemy is drawn second by `DrawEnemySprites`.

Both are 2x2 sprites, so each one uses 4 hardware sprites. The player uses the first 16 bytes of OAM, and the enemy uses the next 16 bytes.

After drawing, `ppu_commit` runs OAM DMA:

```asm
LDA #$00
STA OAMADDR
LDA #$02
STA OAMDMA
```

That copies `$0200-$02FF` into PPU sprite memory.

## Enemy Sprite Assets

The enemy uses partner wizard artwork from:

- `AnimationWithInput/wizard.chr`
- `AnimationWithInput/wizard.pal`
- frame references in `AnimationWithInput/Activity4Parte2.asm`

Because the merged ROM only has one 4 KB sprite pattern table available, the needed wizard tiles were copied into unused tile slots in `MergedActividad/sprites.chr`:

```asm
$20-$23  DOWN_IDLE
$24-$27  DOWN_A
$28-$2B  DOWN_B
$2C-$2F  UP_IDLE
$30-$33  UP_B
$34-$37  RIGHT_IDLE
$38-$3B  RIGHT_B
```

`enemy.asm` uses `enemyFrameTiles` to map animation frames to these copied tile IDs.

## Map Collision Rule

The current collision rule is in `IsMetatileSolid` in `collision.asm`.

Right now:

```asm
CMP #$00
BEQ metatile_is_solid
CMP #$02
BEQ metatile_is_solid
```

So metatile IDs `0` and `2` are solid. IDs `1` and `3` are walkable.

If the map art changes later, this is the main place to update which metatiles block movement.

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
- controller movement
- player animation
- player-vs-map collision
- animated enemy rendering
- enemy chase movement
- enemy-vs-map collision
- pause toggle with Start

Not implemented yet:

- lives
- game over
- score
- coins
- enemy touching player behavior
