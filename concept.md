# Koldunchiki — Game Concept

## Overview

**Koldunchiki** (lit. "Little Wizards") is a programming puzzle game where players write scripts in a custom DSL to guide wizards through tile-based levels. The core loop: write code, watch your wizards execute it, solve the puzzle. At least one wizard must reach the goal tile to complete a level.

The game teaches real programming concepts — variables, conditionals, loops, and function calls - through incremental level design, without ever feeling like a tutorial.

## Genre & References

Programming puzzle / educational game

## The 4:44 Split
### 4 

One level. One wizard. One mob. One spell. That's it.

- **A wizard** that moves on a tile grid via DSL commands (`move(1, 0)`, `move(0, -1)`)
- **Fireball spell** — one spell, one verb: `fireball.cast(x, y)` destroys a target tile's obstacle
- **One completable level** — a single grid with a spawn point, a goal tile, walls, and a win condition (wizard reaches goal)
- **One mob** — a simple enemy that walks back and forth on a fixed path; its script is visible to the player before they write their own code

The DSL at this stage is intentionally minimal: `move`, `fireball.cast`, and possibly not even loops yet. The mob's back-and-forth patrol can be hardcoded or use a simple repeat mechanism. No variables, no conditionals — just sequential commands and one spell.

Visual style: colored squares on a grid. No art, no polish — just the core loop of "read the mob's code → write your code → hit run → watch what happens." If this loop is fun with squares, the idea works.

This phase includes building the DSL interpreter from scratch (lexer → parser → evaluator), the game grid, and the execution loop. The interpreter is the biggest chunk of work — everything else is a thin layer on top.

### 44 

Everything that makes the spark into a game:

**DSL expansion:**
- Variables (`let x = 5`)
- Conditional operators (`if`, `else`)
- Loops (`for`, `while`)
- Multiple spell types beyond fireball
- User-defined spells (for custom levels)

**Level design:**
- 10+ built-in levels forming a tutorial campaign that gradually introduces DSL features
- Destructible obstacles (barrels) alongside indestructible walls
- Moving obstacles (dynamic hazards beyond mobs)
- Progressive command restrictions — each level only unlocks the commands it wants to teach
- Bonus challenges: extra rewards for solving levels without certain commands ("no loops allowed")

**Mobs:**
- Multiple mob types with different behavior scripts
- All mob scripts are visible to the player — reading enemy code is part of the puzzle
- Mobs are written in the same DSL as the player's code, so understanding them teaches the language

**Infrastructure:**
- Level definition in DSL (levels, mobs, and player code all in one language)
- Custom level support - players create and share their own levels
- Leaderboard for custom levels ranked by solution efficiency (AST node count and/or execution steps)
- Level submissions via pull requests to the game repository (post-44, just as a think that I would like to have)
- WASM-based web deployment - playable in browser, no install

**Visual & feedback (stretch):**
- Pixel art tileset replacing the colored squares
- Visual code execution - highlight the current line as the wizard acts (debugger-style)
- Satisfying feedback on level completion: unlock animation for the next level

## Core Mechanics

### The DSL

Players write scripts in a custom language designed for the game. The language supports movement, variables, conditionals, loops, and spell casting

Spell casting example:

```koldun
fireball.cast(x, y)
```

A more advanced example — casting spells in a loop:

```koldun
for i in range(3, 8) {
    koldun.cast(i, x, y);
    move(1, 0);
}
```

### Levels

Each level is a tile-based grid consisting of empty tiles (walkable), spawn points, goal tiles, and obstacles (barrels, indestructible walls, moving hazards). Mobs patrol the grid following their own scripts.

Levels are defined in the same DSL as everything else — one language for player code, mob behavior, and level layout. This means custom level creators use the same tools as players, lowering the barrier to entry. Example level definition might look like:

```koldun
level.wall(0, 0, 10, 1)
level.spawn(koldun, 3, 5)
level.goal(9, 5)
level.spawn(mob, 6, 5, patrol_script)
```

### Mobs

Mobs are enemies with their own DSL scripts. Mob scripts are visible to the player before they write their code. This turns every level into a code-reading puzzle first and a code-writing puzzle second. A basic mob might have a script as simple as:

```koldun
while true {
    move(1, 0);
    move(-1, 0);
}
```

The player reads this, understands the patrol pattern, and writes code to navigate around it or destroy it with a spell at the right moment.

### Wizards (Koldunchiki)

Each wizard can move across the grid, cast spells, and execute the player's script. There are usually multiple wizards per level, and at least one must reach the goal — meaning some can be sacrificed strategically. All wizards run the same script simultaneously.

### Leaderboard

Custom levels have a leaderboard that ranks solutions by efficiency. Two candidate metrics: **AST node count** (measures code conciseness — how few language constructs you used) and **execution steps** (measures runtime efficiency - how few operations the interpreter performed). Both can be computed automatically by the interpreter. The final metric may be one or a combination of both.

### Progressive Complexity

The built-in campaign introduces DSL features one at a time: first movement, then variables, then conditionals, then loops, then spells, then combinations. Available commands per level are restricted by the level creator — this forces learning and enables creative constraints.

Levels can offer bonus challenges for solving without certain commands ("complete without loops", "no variables allowed"), adding replayability.

## Custom Levels

 They are written in the same DSL, and players can define their own spells within them. The dream: people submit levels via pull requests to the repository, building a community-driven level library.

## Tech Stack

- **Language:** TBD (likely Rust or Zig, and I really want to write it using Zig)
- **Platform:** Web
- **Runtime:** WASM - the DSL interpreter compiles to WASM for in-browser execution
- **Deployment:** Static website hosting the WASM module
- **DSL Implementation:** Custom interpreter following *Crafting Interpreters* 

## Team

- **miko** — solo 🥺 (game design, DSL implementation, frontend, level design)

## Timeline

### Phase 1: 4 

The first two weeks are dedicated entirely to making at least something work.

Lexer and parser. Tokenize the DSL, parse it into an AST. Target grammar: `move(x, y)`, `fireball.cast(x, y)`, and function calls with literal arguments. Tree-walk evaluator. Execute the AST against a game state. Wire up `move` to actually move an entity on a grid, `fireball.cast` to destroy a tile. The mob's patrol script can be a hardcoded sequence of moves at this stage — loops are a stretch goal. This is the riskiest part of the entire project. 
> Note for myself: keep the grammar tiny, resist adding features.

Tile grid rendering (HTML canvas or similar), level loading from a hardcoded definition. Colored squares, spawn point, goal tile, walls.
Wizard executes player script on the grid. Mob executes its own script. Collision detection (mob kills wizard, fireball destroys obstacle). Win condition (wizard reaches goal).
Mob script display — show the mob's code to the player before they write theirs. Text input for player code, "Run" button, reset. One playable level.
Buffer for debugging, edge cases, and polish. If time remains: add a second level, or implement `while` loops in the DSL.

**End of Phase 1 deliverable:** a browser page with one playable level where you read a mob's patrol code, write movement + fireball commands, and guide your wizard to the goal.

### Phase 2: 44

**DSL improving:**
- Variables, conditionas, loops
- Multiple spell types
- Mob AI diversity (different scripts -> different behaviors)
- Level-as-DSL format (defining levels in the same language)

**Content & campaign:**
- Built-in tutorial levels with progressive command unlocking
- Destructible obstacles, moving hazards
- Bonus challenges (solve without loops, etc.)
- Pixel art tileset replacing colored squares

**Infrastructure:**
- Custom level support (player-created levels)
- Leaderboard (AST node count / execution steps)
- Level submission 

**Stretch goals (if time allows):**
- Visual code execution (debugger-style line highlighting)
- User-defined spells in custom levels
- Sound design
- Level editor UI

## Open Questions

1. **DSL syntax style** - `fireball.cast(x, y)` (spell as object) vs `koldun.cast(fireball, x, y)` (wizard as actor). Leaning toward the first — shorter and more intuitive.
2. **Error handling** - What happens when player code crashes mid-execution? Wizard dies? Level resets? A runtime error message in the game UI? I mean, maybe it's cool to ignore bad command (like if someone wants to move in wall to create cool loop), but idk, I'll think about it when I'll get 4 ready
3. **Level definition format** — Full DSL vs hybrid (JSON structure + DSL scripts for mobs). Full DSL is more elegant, JSON is easier to parse and validate.
4. **Multiplayer potential** — Could two players write competing scripts for the same level? PvP code battles? But these questions are for future
5. **Sound** — Undecided. Needs exploration once core gameplay exists

