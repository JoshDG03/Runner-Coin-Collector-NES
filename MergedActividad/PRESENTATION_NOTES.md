# Runner Coin Collector NES Presentation Notes

This file is a speaking guide for the required presentation.

Recommended structure:
- Optional title slide
- 9 required slides, one per requirement
- Short live demo at the end

If your instructor wants exactly 9 slides, keep only the 9 requirement slides and say the intro/demo parts verbally.

## Optional Title Slide

Title:
`Runner Coin Collector NES`

Subtitle:
`NES game in 6502 assembly with animation, map compression, coins, HUD, enemy AI, and pause`

Short intro script:
`Our project is a continuous-movement coin collector inspired by Snake. The player keeps running, collects coins to increase score and speed, avoids walls and an enemy, and loses after running out of lives.`

## Slide 1 - Player Sprite And 4-Direction Animation

Requirement:
`The character must be at least one metatile, animated, move in 4 directions, and use at least 3 colors.`

What to show:
- Screenshot of the player facing up, down, left, and right
- Mention that the player is a `2x2` metasprite, so it is `16x16` pixels

Talking points:
- The player is built from four hardware sprites, arranged as a `2x2` metasprite.
- Each movement direction has its own visual posture.
- The animation alternates between frames while the player is moving.
- The sprite uses the NES sprite palette, so it satisfies the color requirement.

Conceptual explanation:
`We did not treat the player as one image. On the NES, the player is assembled from four smaller sprites. That let us keep the required metatile size while still animating the character in all four directions.`

Code references:
- `draw_character` in [player.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/player.asm)
- `draw_posture` in [player.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/player.asm)

## Slide 2 - Continuous Running And Direction Control

Requirement:
`The character runs continuously and the arrow buttons change the direction.`

What to show:
- Small diagram: controller input -> direction state -> automatic movement

Talking points:
- The D-pad does not move the player only once.
- The D-pad changes the `direction` variable.
- After direction is set, the game keeps moving the player automatically every few ticks.
- This makes the game feel like Snake, because the character is always in motion.

Conceptual explanation:
`The controller is used to steer, not to start and stop the movement. Every frame we read the buttons, update the current direction, and then the movement system advances the player automatically.`

Code references:
- `ReadController` and `UpdatePauseToggle` in [controller.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/controller.asm)
- `update_animation` and `move_character` in [player.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/player.asm)

## Slide 3 - Initial Slow Speed And Speed Increase

Requirement:
`Initially the player starts slow and increases speed as more coins are collected.`

What to show:
- A simple progression like `start: 6 ticks -> later: 5 -> 4 -> 3 -> 2`

Talking points:
- The player starts with a slower update speed.
- Each collected coin reduces the movement tick value.
- Lower tick values mean the player moves more often.
- The speed has a minimum limit so gameplay stays controllable.

Conceptual explanation:
`Instead of changing how many pixels the player moves, we changed how often the movement update happens. That makes the game faster while keeping control precise.`

Code references:
- speed constants and `InitCoinSystem` in [coin.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/coin.asm)
- `IncreasePlayerSpeed` in [coin.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/coin.asm)

## Slide 4 - Coin Respawn And Score Increase

Requirement:
`When the player collides with a coin, a new coin appears in an empty random position and the score indicator increases.`

What to show:
- Before/after screenshot of a coin pickup
- One sentence: `Coin collected -> score +10 -> respawn elsewhere`

Talking points:
- The game checks if the player overlaps the coin.
- When collected, the score increases by `10`.
- A pseudo-random routine generates a new coin position.
- The new position is validated so it does not appear inside a wall, on the player, or on the enemy.

Conceptual explanation:
`The important part is not only spawning the coin randomly, but validating the spawn location. We reused the map collision system so the new coin appears only in legal, empty spaces.`

Code references:
- `CheckCoinCollected` in [coin.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/coin.asm)
- `SpawnCoin` in [coin.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/coin.asm)
- `AddScoreTen` in [hud.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/hud.asm)

## Slide 5 - Map, Walls, Metatiles, Compression, And Colors

Requirement:
`The screen must be surrounded by 2x2 metatile walls, contain at least 20 metatiles of 3 different types, use 2-bit metatile compression, and have at least 6 colors in the background.`

What to show:
- Screenshot of the full map
- Tiny 2-bit diagram: `1 byte = 4 metatiles`

Talking points:
- The map uses `16 x 15` metatiles, and each metatile is `16 x 16` pixels.
- The outer border is solid, so the screen is surrounded by walls.
- The compressed map stores four metatile IDs inside one byte using `2 bits` per metatile.
- The map uses four metatile IDs total, and all four appear on screen.
- The packed map contains many more than `20` placed metatiles and at least `3` different metatile types.
- The background palettes include more than `6` colors overall.

Concrete evidence you can say:
- `packed_map` contains `60` bytes for `240` metatiles on screen.
- The map uses metatile types `0, 1, 2, and 3`.
- Counts in the current map are: `type 0 = 58`, `type 1 = 82`, `type 2 = 51`, `type 3 = 49`.

Conceptual explanation:
`This requirement is really about memory-efficient background design. We do not store a full tile map directly. Instead, we store compact metatile IDs and expand them when the game loads.`

Code references:
- map decompression in [main.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/main.asm)
- `packed_map` in [compressed_map.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/compressed_map.asm)
- `metatile_table` and `attrtable` in [map.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/map.asm)

## Slide 6 - Collision, Lives, And Game Over

Requirement:
`If the player collides with a side wall, internal metatiles, or the enemy, one life is lost. After 3 lives, a missed-game indicator must appear.`

What to show:
- Flow: `collision -> lose one life -> update HUD -> game over screen at 0 lives`

Talking points:
- The player uses collision detection against the background map.
- The game checks the four corners of the player hitbox against the metatile map.
- Hitting a wall or internal obstacle removes one life.
- Touching the enemy also removes one life.
- The HUD starts at `3` lives.
- When lives reach `0`, the game changes state and draws a game over screen.

Conceptual explanation:
`We separated map collision and enemy collision, but both feed into the same life system. That made it easier to manage the rule that any dangerous collision costs one life.`

Code references:
- collision system in [collision.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/collision.asm)
- `HandlePlayerWallCollision`, `CheckEnemyHitPlayer`, `LoseOneLife`, and `DrawGameOverScreen` in [hud.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/hud.asm)

## Slide 7 - Enemy Size, Colors, Start Position, And Chase Behavior

Requirement:
`The enemy must be a 2x2 metatile-size character, have at least 3 colors, start on screen, and constantly seek the player.`

What to show:
- Screenshot with enemy and player
- Simple chase diagram: `compare X/Y -> choose direction -> attempt move`

Talking points:
- The enemy is also a `2x2` metasprite, so it matches the size requirement.
- It uses a different sprite palette, so it is visually distinct from the player.
- The enemy starts at a fixed visible position on the map.
- Each update compares enemy position to player position.
- The enemy chooses a direction toward the player and tries to move there.
- If one axis is blocked, it tries the other axis.

Conceptual explanation:
`The enemy does not use full pathfinding. Instead, it uses simple pursuit logic that still guarantees pressure on the player because it always tries to reduce the distance.`

Code references:
- `InitializeEnemy`, `DetermineEnemyChaseDirection`, `AttemptEnemyMovement`, and `DrawEnemySprites` in [enemy.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/enemy.asm)

## Slide 8 - Enemy Speed Increases But Stays Slower Than The Player

Requirement:
`The enemy must increase speed as more coins are held, but it should always stay slower than the player.`

What to show:
- Two lines:
  `Player ticks: 6 -> 2`
  `Enemy ticks: 16 -> 4`

Talking points:
- Coin collection speeds up both the player and the enemy.
- The player starts faster than the enemy and stays faster even at the minimum values.
- This keeps the game challenging, but still fair.

Conceptual explanation:
`We balanced difficulty by scaling both speeds together. The enemy becomes more dangerous over time, but we preserved a gap so the player still has a chance to react and escape.`

Code references:
- speed constants in [coin.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/coin.asm)
- `UpdateEnemy` in [enemy.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/enemy.asm)

## Slide 9 - Pause With Start Button

Requirement:
`The game should be paused with the START button.`

What to show:
- Flow: `Start pressed once -> pauseFlag toggles -> movement updates stop`

Talking points:
- The controller module detects when Start is newly pressed.
- The game toggles a pause flag only once per button press.
- While paused, player and enemy updates stop.
- Sprites remain visible because drawing still continues.
- Pressing Start again resumes the game.

Conceptual explanation:
`We used edge detection for the Start button. That prevents the game from rapidly switching pause on and off while the player is still holding the button.`

Code references:
- `UpdatePauseToggle` in [controller.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/controller.asm)
- main loop pause branch in [main.asm](/c:/Users/NamekianDragon/repos/Runner-Coin-Collector-NES/MergedActividad/main.asm)

## Demo Plan

Suggested order for the video demo:
1. Show the player moving in 4 directions.
2. Show continuous running.
3. Collect one coin and point out the score increase and speed increase.
4. Let the enemy chase the player.
5. Show collision with a wall and loss of life.
6. Show collision with the enemy and loss of life.
7. Pause and resume with Start.
8. Lose all lives and show the game over screen.

## Short Closing Script

`In summary, the project combines sprite animation, controller steering, compressed metatile maps, collision detection, coin spawning, score and life management, enemy chase logic, speed scaling, and pause control. The final result satisfies the 9 required systems while keeping the game simple and playable on the NES architecture.`
