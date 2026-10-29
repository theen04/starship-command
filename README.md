# Starship Command

*A relational database designed to power a text-based science fiction adventure game through SQL-driven gameplay.*

---

## Project Overview

Starship Command is a database design project developed to demonstrate the complete lifecycle of relational database development, from conceptual modeling through physical implementation.  The project explores how a relational database can be used to represent and manage the state of an interactive game world, including locations, player progression, inventory, and gameplay rules.

Version 2.0 ports the game engine from SQL Server to PostgreSQL and adds a browser-based terminal UI, so the game can be played with a single `docker compose up`.

---

## Quick Start

Requires [Docker](https://www.docker.com/products/docker-desktop/).

```bash
docker compose up --build
```

Open **http://localhost:8080**, enter a callsign and type `help`.

To wipe all players and rebuild the database from the scripts in `db/init`:

```bash
docker compose down -v && docker compose up --build
```

Ports can be changed with `WEB_PORT` and `DB_PORT` (for example, `WEB_PORT=9000 docker compose up`).

---

## Project Objectives

- Design and document a conceptual model representing the game world
- Define entity relationships through an entity relationship diagram
- Develop a logical data model containing the entities, attributes and relationships required for implementation
- Implement the database schema using SQL
- Demonstrate gameplay through stored procedures and database-driven game logic

---

## Game Overview

**Starship Command** is a text-based science fiction adventure game in which players must survive after crash-landing on a hostile alien planet.  With their spacecraft heavily damaged and critical systems offline, players must explore the surrounding environment, gather resources and recover the components needed to restore their ship.

Success depends on exploration and careful resource management.  Players navigate interconnected locations, search for supplies and collect the items required to complete their mission.  Each action moves the player closer to repairing the spacecraft and escaping the planet.

Inspired by classic text-based adventure games such as *Oregon Trail*, **Starship Command** combines exploration, resource collection and progression into a simple but engaging gameplay experience.  The objective is straightforward: recover the necessary components, return to the crash site and relaunch the starship.

![Game Map](images/game_map.png)

---

## Database Design

### Conceptual Model

The conceptual model focuses on the key game concepts that need to be implemented for the game to operate.  This diagram maps game rules and restrictions (constraints) to illustrate the relationships between data.

![Conceptual Model](images/conceptual_data_model.png)

---

### Logical Data Model

The logical model refines the conceptual design by defining attributes, keys, and relationships while remaining independent of any specific database platform.

![Logical Data Model](images/logical_data_model.png)

---

### Entities and Relationships

This section provides an overview of the physical database implementation and illustrates the tables, primary keys, foreign keys and relationships used throughout the application.

#### Entities

| **Entity** | **Attribute** | **Description** |
|-------------|---------------|-----------------|
| **Locations** | Name | Name of the location. |
| | Description | Description of the location. |
| | Dark | Indicates whether the location is dark. |
| | Connection | Locations that can be reached from the current location. |
| **Players** | Username | Unique username for each player. |
| | Current Location | The player's current location. |
| | Last Action Time | The most recent time the player performed an action. |
| **Items** | Name | Name of the item. |
| | Description | Description of the item. |
| | Can Pickup | Indicates whether the item can be collected. |
| | Location | The location where the item is placed. |
| **Action Log** | Player Name | Player associated with the logged event. |
| | Location Name | Location where the event occurred. |
| | Time | Timestamp of the logged event. |
| | Action | Type of action performed. |
| | Details | Additional information about the event. |
| **Inventory** | Player Name | Player associated with the inventory record. |
| | Item Name | Item contained in the player's inventory. |
| | Quantity | Number of that item in the player's inventory. |

#### Relationships

| **Relationship** | **From Entity** | **Relationship** | **Min** | **Max** | **To Entity** |
|------------------|-----------------|------------------|:-------:|:-------:|---------------|
| Player → Inventory | Player | has | 1 | 1 | Inventory |
| Inventory → Player | Inventory | belongs to | 1 | 1 | Player |
| Player → Action Log | Player | logs | 0 | Many | Action Log |
| Action Log → Player | Action Log | logged by | 0 | Many | Player |
| Player → Location | Player | occupies | 1 | 1 | Location |
| Location → Player | Location | occupied by | 0 | Many | Player |
| Inventory → Item | Inventory | contains | 0 | Many | Item |
| Item → Inventory | Item | contained in | 0 | Many | Inventory |
| Item → Location | Item | located in | 1 | 1 | Location |
| Location → Item | Location | contains | 0 | Many | Item |

---

## Database Implementation: Modeling a Game World

The foundation of **Starship Command** is a relational database designed to represent and manage an interactive game world.  Rather than storing game state directly in application code, the database defines the game's environment, player progression, inventory and gameplay rules through structured tables, relationships, stored procedures and constraints.

### Game World and Locations

The game map is represented through a `Locations` table containing the name and description of each area available for exploration.  To create movement between locations, a bridge table defines valid connections by mapping location relationships in a `From/To` pattern.

This approach allows the game world to be expanded by adding new locations and connections without requiring changes to the underlying gameplay logic.

### Items and Inventory Management

Items required for completing the mission are stored in an `Items` table, with each item containing a name and description aligned with the game's objectives.  Items are placed throughout the world using a mapping table that establishes relationships between items and locations.

When a player explores a location, available items are returned through gameplay logic that allows the player to collect and store them in their inventory.  Players must successfully recover the required components to complete the mission and relaunch their spacecraft.

### Player State Management

Each player is represented by a unique `Player ID` that connects the player to their current location, inventory and gameplay history.  The player table maintains key game state information, including:

* Username
* Current location
* Last action timestamp

The Player ID serves as the primary identifier required for executing gameplay operations.

### Inventory and Gameplay Tracking

The `Inventory` table manages the many-to-many relationship between players and collected items.  This design supports multiple players, with each player maintaining an independent inventory and progression state.

An `Action Log` table records gameplay activity, including:

* Player ID
* Action performed
* Location
* Date and time of the event

This audit history supports debugging, gameplay analysis and future enhancements by providing visibility into player behavior.

---

## Database Schema Creation

The database build scripts define the physical schema required to support gameplay.  The implementation includes seven tables with primary key, foreign key, unique and check constraints that establish the required relationships and enforce data integrity.

Key database elements include:

* Primary keys for entity identification
* Foreign keys to maintain relationships
* Constraints to enforce valid game states
* Structured relationships between players, locations, items, and gameplay events

---

## Data Population

The initial game world is populated through SQL insert statements that create the locations, items, players and supporting relationships required for gameplay.

The current game map contains:

* 5 primary locations
* 3 sub-locations per primary location
* 17 total explorable locations

The design is intentionally scalable.  Expanding the game world requires only adding new location records and connection mappings.  Additional items can be introduced through independent inserts without requiring changes to the existing database structure.

---

## CRUD Operations and Stored Procedures

Stored procedures implement the primary gameplay actions by performing database operations required for player interaction.  Each procedure manages a specific game function while maintaining database integrity.

Examples of supported actions include:

* Creating or resuming a player
* Moving between locations
* Looking around an area
* Collecting items
* Updating player state
* Recording gameplay events

For example, `usp_move_player` accepts a player ID and movement direction, validates the requested action and updates the player's current location within the game map.

In v2.0 every gameplay function returns a single JSON document instead of `PRINT` messages and multiple result sets, so any client (psql, the web UI, a test script) can drive the game the same way:

```json
{
  "ok": true,
  "message": "You head east to Nav Ping (East).",
  "state": { "player": {}, "location": {}, "items": [], "exits": [], "inventory": [], "mission": {} }
}
```

| Function | Purpose |
|---|---|
| `usp_create_player(username)` | Create a player at the Crash Site, or resume an existing one |
| `usp_look_around(player_id)` | Describe the location, its items and exits |
| `usp_move_player(player_id, direction)` | Move along a valid connection |
| `usp_pick_up_item(player_id, item_id)` | Collect an item at the current location |
| `usp_show_inventory(player_id)` | List collected items |
| `usp_complete_game(player_id)` | Relaunch the ship, or get hints for missing components |
| `usp_restart_game(player_id)` | Empty the inventory and return to the Crash Site |
| `fn_game_state(player_id)` | Read-only snapshot of a player's game |
| `fn_action_log(player_id, limit)` | Recent action log entries |

---

## Triggers and Automated Validation

Triggers were implemented to enforce game rules, automate logging and reduce duplicate logic across stored procedures.

### Player Movement Logging (`trg_players_move_log`)

Automatically records player movement events whenever a player's location changes, capturing the player ID, destination location and timestamp.

### Inventory Audit (`trg_inventory_audit`)

Tracks item additions and removals from player inventories by writing corresponding events to the action log.

### Inventory Validation (`trg_inventory_validate`)

Enforces item collection rules by preventing invalid inventory states, including:

* Collecting items that are not available for pickup
* Creating duplicate item quantities for a player

Together, these triggers centralize validation logic, improve maintainability, and ensure consistent enforcement of gameplay rules throughout the database.


---

## v2.0: PostgreSQL and Web Interface

The original SQL Server implementation (in `sql/`) was played by running stored procedures by hand in SSMS.  Version 2.0 keeps the database as the game engine and adds a thin web layer on top:

```text
Browser (terminal UI)  ──HTTP/JSON──▶  Flask API  ──SELECT usp_*()──▶  PostgreSQL
  app/static/game.js                   app/app.py                       db/init/*.sql
                                                                        tables, functions,
                                                                        triggers = game rules
```

The Flask app contains no game logic.  Each route calls one database function and returns its JSON unchanged, so every rule is still enforced by the database.

Changes from the v1.0 design:

* **Per-player worlds.** v1.0 deleted an item from `location_items` when it was picked up, so only the first player could ever find it.  Item placement is now static world data, and a player's `inventory` decides whether an item is still visible to them.
* **Data-driven win condition.** `items.is_required` and `items.hint` replace the hard-coded item IDs in `usp_complete_game`, and `locations.is_start` replaces looking up the Crash Site by name.
* **Persistent progress.** `players.completed_at` records a finished mission; `usp_create_player` and `usp_restart_game` support new and returning players.
* **Stronger constraints.** Unique location and item names, case-insensitive unique usernames, one connection per direction from each location, and a foreign key on `action_log.action_location`.
* **Triggers ported.** `trg_inventory_validate` now runs `BEFORE` the write, correcting the row up front instead of rolling back afterwards.

---

## Repository Structure

```text
docker-compose.yml          # PostgreSQL + web app
db/
├── init/                   # run automatically on first database start
│   ├── 01_schema.sql       # tables and constraints
│   ├── 02_seed.sql         # locations, connections, items, Player One
│   ├── 03_functions.sql    # gameplay functions (stored procedures)
│   └── 04_triggers.sql     # logging and validation triggers
└── gameplay_demo.sql       # full speed run in SQL
app/
├── app.py                  # Flask API
├── templates/index.html    # terminal UI
├── static/                 # styles and client-side command parser
└── Dockerfile
sql/                        # original SQL Server (T-SQL) v1.0 scripts
images/                     # data models, ERDs and game map
```

---

## Getting Started

See [Quick Start](#quick-start) to play in the browser.

To play directly in SQL, open a psql session against the running database:

```bash
docker compose exec db psql -U starship -d starship_command
```

Or run the full speed run script:

```bash
docker compose exec -T db psql -U starship -d starship_command < db/gameplay_demo.sql
```

The original SQL Server version can still be built by running `sql/starship_command_build_script.sql` and then `sql/starship_command_gameplay.sql` in SSMS or Azure Data Studio.

---

## Gameplay

The game begins with the player stranded on an alien planet after a spacecraft crash. The objective is to explore the surrounding area, recover the four missing components required to repair the ship, and return to the crash site to relaunch the spacecraft.

### Playing in the Browser

Enter a callsign to start.  Entering the same callsign later resumes that commander's mission.

| Command | Action |
|---|---|
| `look` (`l`) | Describe your surroundings |
| `go <direction>` | Move: north, south, east, west, forward, back, left, right |
| `n` `s` `e` `w` `f` `b` | Direction shortcuts; a bare direction such as `left` also works |
| `take <item>` | Pick up an item (partial names work) |
| `inventory` (`i`) | List what you are carrying |
| `launch` | Repair and relaunch the ship at the Crash Site |
| `log` | Show your recent actions |
| `restart` | Start the mission over |

The side panel shows exits, nearby items, your cargo hold and the live action log, and its buttons issue the same commands.

### Playing in SQL

The seed script creates an initial player, `Player One`, with `player_id = 1`.  New players can be created with `SELECT usp_create_player('Ripley');`.

To view the player's current location, items and exits:

```sql
SELECT jsonb_pretty(usp_look_around(1));
```

Players navigate the game world using directional commands:

```sql
SELECT usp_move_player(1, 'east') ->> 'message';
```

When a required component is discovered, players can add it to their inventory.  Available item IDs are listed in `state.items` when an item is present at the current location:

```sql
SELECT usp_pick_up_item(1, <item_id>) ->> 'message';
```

Once all four required components have been collected, the player must return to the crash site and attempt to repair the spacecraft:

```sql
SELECT jsonb_pretty(usp_complete_game(1) - 'state');
```

If all required items have been collected, the player successfully completes the mission and relaunches the starship. If items are missing, the response lists each remaining component with a hint about where it can be found.

---

## Technologies

* SQL (PostgreSQL 17, PL/pgSQL; original version in T-SQL for SQL Server)
* Relational Database Design
* Entity Relationship Modeling
* Database Normalization
* Python / Flask / psycopg
* HTML, CSS and JavaScript
* Docker Compose

---

## Lessons Learned

This project provided experience designing a complete database-backed application from requirements through implementation.

Key lessons learned:  
- Strong data modeling is foundational to application design.  A well-designed schema simplifies application logic and improves scalability
- Relational databases can support dynamic application behavior through stored procedures, triggers and constraints
- Requirements evolve during development, requiring teams to balance desired functionality with project scope
- Collaboration and version control become increasingly important as technical complexity grows

---

## Future Enhancements

Potential future improvements include:

- Add user authentication (callsigns are currently unprotected)
- Use `locations.is_dark` and `items.is_usable` for new mechanics, such as needing a light source to search dark locations
- Introduce randomized maps and item placement
- Add game scoring and achievement tracking
- Create analytics dashboards using player action logs
- Migrate the architecture to a cloud database platform

---

## Project Contributors

**Starship Command** was developed as a collaborative database design project.  I contributed to the database design, SQL implementation, documentation and gameplay development alongside my project teammates.

Contributors:
- Robert Nitto
- Jeong Hwan Son
- Darrell Collison
- Tristan Morlock

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
