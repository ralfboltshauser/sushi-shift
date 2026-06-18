# Sushi Shift MVP Plan

## Goal

Build a small, complete, polished Godot 4 cooking game using the Quaternius Sushi Restaurant Kit.

The MVP should feel like a real tiny indie game: launchable, playable from a main menu, understandable without explanation, restartable, and fun for a short 3-minute run.

## Game Concept

`Sushi Shift` is a compact sushi-counter rush game.

The player runs around a small sushi kitchen, grabs ingredients, prepares simple dishes, and serves customer orders before they expire. The goal is to score as high as possible before the shift timer reaches zero.

## MVP Promise

The first complete version should include:

- One fixed 3D kitchen level
- One controllable player
- One 3-minute timed shift
- Three recipes
- Four interaction stations
- Active order queue
- Score and missed-order tracking
- Main menu
- Pause menu
- Game-over screen
- Restart flow
- Basic animation, sound, and visual feedback
- A tested playable run from start to finish

## Non-Goals For MVP

These are intentionally out of scope until the basic game is fun:

- Multiplayer
- Upgrades
- Money/economy
- Multiple levels
- Complex customer AI
- Physics-based cooking
- Inventory grids
- Character customization
- Save files
- Online leaderboards

## Core Loop

1. A customer order appears.
2. The player reads the required dish.
3. The player collects ingredients from stations.
4. The player prepares ingredients if needed.
5. The player assembles the final dish.
6. The player serves the dish at the counter.
7. Score increases if the order is correct.
8. Orders expire if ignored too long.
9. The shift ends after 3 minutes.
10. The player sees final score and can restart.

## Controls

Keyboard:

- `WASD`: move
- `E`: interact
- `Q`: drop held item
- `Esc`: pause

Gamepad can be added after keyboard controls are solid.

## MVP Recipes

### Onigiri

- Ingredient: `Rice`
- Station: `Assembly Counter`
- Output: `Food_Onigiri`
- Score: 100
- Difficulty: easy

### Salmon Nigiri

- Ingredients: `Rice`, `Salmon`
- Station: `Assembly Counter`
- Output: `Food_SalmonNigiri`
- Score: 150
- Difficulty: medium

### Cucumber Roll

- Ingredients: `Rice`, `Nori`, `Cucumber`
- Prep: `Cucumber` at `Cutting Board` becomes `SlicedCucumber`
- Station: `Assembly Counter`
- Output: `Food_Roll`
- Score: 200
- Difficulty: medium-hard

## Stations

### Ingredient Station

Purpose: gives raw ingredients.

Initial bins:

- Rice
- Salmon
- Nori
- Cucumber

Implementation:

- `Area3D` interaction zone
- Shows ingredient label or icon
- Press `E` while empty-handed to pick up ingredient

### Cutting Board

Purpose: transforms raw prep ingredients.

Initial transform:

- `Cucumber` -> `SlicedCucumber`

Implementation:

- Requires holding a valid raw ingredient
- Plays short progress timer
- Plays `Chop_Loop` animation while active
- Replaces held item with prepared output

### Assembly Counter

Purpose: combines ingredients into dishes.

Implementation:

- Holds a small list of deposited ingredients
- When ingredients match a recipe, starts assembly timer
- Plays `Assembly_Loop`
- Spawns final dish
- Clears used ingredients

### Serving Counter

Purpose: accepts finished dishes.

Implementation:

- Requires holding a dish
- Checks active orders
- If matching order exists, completes earliest matching order
- Adds score
- Removes held dish
- Shows success feedback
- If no match, shows small error feedback

## Game Timing

Initial tuning:

- Shift length: 180 seconds
- Order spawn interval: 8-12 seconds
- Order patience: 25-35 seconds
- Cutting time: 1.25 seconds
- Assembly time: 1.5 seconds
- Missed order penalty: -50

Balancing target:

- First run: 400-700 score
- Decent run: 900-1200 score
- Great run: 1500+ score

## Main Scenes

Recommended Godot scene layout:

```text
res://
  project.godot
  scenes/
    Main.tscn
    Game.tscn
    player/Player.tscn
    stations/IngredientStation.tscn
    stations/CuttingBoard.tscn
    stations/AssemblyCounter.tscn
    stations/ServingCounter.tscn
    items/CarryItem.tscn
    ui/MainMenu.tscn
    ui/HUD.tscn
    ui/PauseMenu.tscn
    ui/GameOverMenu.tscn
  scripts/
    game/GameManager.gd
    game/OrderManager.gd
    data/RecipeBook.gd
    player/PlayerController.gd
    stations/Station.gd
    stations/IngredientStation.gd
    stations/CuttingBoard.gd
    stations/AssemblyCounter.gd
    stations/ServingCounter.gd
    items/CarryItem.gd
    ui/HUD.gd
  assets/
    quaternius_sushi/
  audio/
```

## Data Model

Keep data simple for MVP.

Items:

- `rice`
- `salmon`
- `nori`
- `cucumber`
- `sliced_cucumber`
- `onigiri`
- `salmon_nigiri`
- `cucumber_roll`

Each item needs:

- id
- display name
- type: ingredient, prepared, dish
- model path

Recipes need:

- id
- display name
- required ingredients
- output item id
- score
- prep requirements, if any

Orders need:

- recipe id
- time remaining
- max patience
- status

## Asset Mapping

Use these Quaternius models first:

Characters:

- `Characters/Normal/glTF/Panda.gltf`
- `Characters/With Knife and Pan/glTF/Panda.gltf`

Environment:

- `Environment/glTF/Environment_Counter_Straight.gltf`
- `Environment/glTF/Environment_Counter_Corner.gltf`
- `Environment/glTF/Environment_CuttingTable.gltf`
- `Environment/glTF/Environment_Fridge.gltf`
- `Environment/glTF/Environment_KitchenKnives.gltf`
- `Environment/glTF/Environment_Plate.gltf`
- `Environment/glTF/Environment_Pot_1_Filled.gltf`
- `Environment/glTF/Environment_Stool.gltf`
- `Environment/glTF/Floor_Kitchen1.gltf`
- `Environment/glTF/Wall_Shoji.gltf`

Food:

- `Food/glTF/FoodIngredient_Rice.gltf`
- `Food/glTF/FoodIngredient_Salmon.gltf`
- `Food/glTF/FoodIngredient_Cucumber.gltf`
- `Food/glTF/FoodIngredient_SlicedCucumber.gltf`
- `Food/glTF/FoodIngredient_Nori.gltf`
- `Food/glTF/Food_Onigiri.gltf`
- `Food/glTF/Food_SalmonNigiri.gltf`
- `Food/glTF/Food_Roll.gltf`

Decoration:

- `Decoration/glTF/Decoration_Light.gltf`
- `Decoration/glTF/Decoration_Sign.gltf`
- `Decoration/glTF/Decoration_Bamboo.gltf`

## UI Requirements

### Main Menu

Required:

- Game title
- Start button
- Quit button

Nice polish:

- Small preview camera of the kitchen behind UI
- Best score placeholder, if easy

### HUD

Required:

- Time left
- Score
- Held item
- Active orders
- Station progress

Order cards should show:

- Dish name
- Time remaining bar
- Expiring visual state

### Pause Menu

Required:

- Resume
- Restart
- Main Menu

### Game Over

Required:

- Final score
- Orders served
- Orders missed
- Restart
- Main Menu

## Feedback And Polish

Minimum polish pass:

- Order card flashes or shakes when nearly expired
- Score popup on successful serve
- Error feedback for wrong dish
- Progress bar while chopping/assembling
- Short success sound
- Short error sound
- Chopping sound
- Assembly sound
- Warm directional light
- Fixed isometric camera
- Character switches between idle, walk, holding, chop, and assembly animations

## Implementation Order

### Phase 1: Project Setup

- Create Godot project
- Configure input actions
- Import `.gltf` assets
- Create folder structure
- Create blank `Main.tscn`
- Create placeholder `Game.tscn`

### Phase 2: Graybox Playable Loop

- Add player movement
- Add one ingredient station
- Add one assembly station
- Add one serving counter
- Add one recipe: Onigiri
- Add score when served

Completion test:

- Start game scene
- Pick up rice
- Assemble onigiri
- Serve it
- Score increases

### Phase 3: Orders And Timer

- Add `OrderManager`
- Spawn order cards
- Add order patience timers
- Add game shift timer
- Add missed order tracking
- Add game-over trigger

Completion test:

- Orders appear
- Correct dish completes order
- Expired order counts as missed
- Shift ends and shows final score

### Phase 4: Add Recipe Depth

- Add salmon nigiri
- Add cucumber roll
- Add cutting board station
- Add ingredient bins for salmon, nori, cucumber

Completion test:

- All three recipes can be completed
- Cucumber roll requires cutting cucumber first
- Wrong dish does not complete order

### Phase 5: Replace Grayboxes With Assets

- Build compact sushi kitchen
- Place stations clearly
- Add character model
- Add carry item models
- Add dish output models
- Add decorations and warm lighting

Completion test:

- No missing models
- Objects are readable from camera
- Player/station collisions feel reasonable

### Phase 6: Menus And Restart Flow

- Add main menu
- Add pause menu
- Add game-over menu
- Implement restart
- Implement return to main menu

Completion test:

- Launch starts at menu
- Start begins round
- Pause/resume works
- Restart works mid-game
- Game over restart works

### Phase 7: Polish

- Add simple sounds
- Add station progress bar
- Add order urgency feedback
- Add score popups
- Add animation switching
- Tune movement speed and station timing

Completion test:

- A 3-minute run feels understandable and slightly frantic
- Mistakes are clear
- Serving is satisfying
- Restarting feels natural

### Phase 8: End-To-End Verification

- Run the game from main menu
- Complete at least one order of each recipe
- Let at least one order expire
- Pause and resume
- Restart during a round
- Finish a full shift
- Restart from game-over
- Check console for errors
- Export or run a local playable build

## Definition Of Done

The MVP is done only when:

- The game launches into a menu
- The player can start a round
- The player can complete all three recipes
- Orders spawn and expire
- Score updates correctly
- The shift timer ends the game
- Game-over screen shows useful results
- Restart works from pause and game-over
- The game has real Quaternius visual assets in the level
- Basic sound/visual feedback exists
- A full run has been tested end-to-end without blocking bugs

## First Build Target

The first target is not beauty. It is this tiny proof:

`Start -> move -> pick up rice -> assemble onigiri -> serve -> score increases -> timer runs -> game over -> restart`

Once that works, the game has a spine.
