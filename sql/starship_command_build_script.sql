/**********************************************************************
  IST-657: Database Administration and Concepts
  Final Project (Summer 2025) - Team 1
  Database Build Script
  Jeong Hwan Son, Darrell Collison, Tristan Morlock, Robert Nitto
  Date: 2025-09-01
  
  Starship Command v1.0
  A relational database designed to support a text-based strategy game featuring 
  resource management, exploration and mission planning.

  Script Outline
  0. Create Database
  1. DOWN (tear-down / drop objects)
  2. UP Metadata (create tables)
       - locations
       - location_connections
       - items
       - location_items
       - players
       - inventory
       - action_log
  3. UP Data (insert initial records)
  4. Stored Procedures (gameplay logic)
  5. Verify Database
**********************************************************************/

/**********************************************************************
  START DATABASE SCRIPT
**********************************************************************/

/**********************************************************************
  SECTION 0: DROP/CREATE DATABASE
  -- Create or specify a database to use to build the game
**********************************************************************/

-- create game database if it does not exist
IF NOT EXISTS (SELECT * FROM sys.databases WHERE NAME = 'starship_command')
    CREATE DATABASE starship_command;
GO

-- use the game database
USE starship_command;
GO

/**********************************************************************
  SECTION 1: DOWN
  -- Tear-down: drop objects in reverse dependency order
**********************************************************************/

-- 20 soft drop usp_completeGame
IF OBJECT_ID('dbo.trg_inventory_validate','TR') IS NOT NULL DROP TRIGGER dbo.trg_inventory_validate;

-- 19 soft drop usp_completeGame
IF OBJECT_ID('dbo.trg_inventory_audit',   'TR') IS NOT NULL DROP TRIGGER dbo.trg_inventory_audit;

-- 18 soft drop usp_completeGame
IF OBJECT_ID('dbo.trg_players_move_log', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_players_move_log;

-- 17 soft drop usp_completeGame
IF OBJECT_ID('dbo.usp_completeGame', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_completeGame;
GO

-- 16 soft drop usp_PickUpItem
IF OBJECT_ID('dbo.usp_PickUpItem', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_PickUpItem;
GO

-- 15 soft drop usp_ShowInventory
IF OBJECT_ID('dbo.usp_ShowInventory', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_ShowInventory;
GO

-- 14 soft drop usp_MovePlayer
IF OBJECT_ID('dbo.usp_MovePlayer', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_MovePlayer;
GO

-- 13 soft drop usp usp_LookAround
IF OBJECT_ID('dbo.usp_LookAround', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_LookAround;
GO

-- 12 soft drop action_log fk constraints
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_NAME = 'fk_action_log_player_id')
    ALTER TABLE action_log DROP CONSTRAINT fk_action_log_player_id
GO

-- 11 soft drop action_log table
DROP TABLE IF EXISTS action_log
GO

-- 10 soft drop inventory fk constraints
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_NAME = 'fk_inventory_item_id')
    ALTER TABLE inventory DROP CONSTRAINT fk_inventory_item_id
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_NAME = 'fk_inventory_player_id')
    ALTER TABLE inventory DROP CONSTRAINT fk_inventory_player_id
GO

-- 9 soft drop inventory table
DROP TABLE IF EXISTS inventory
GO

-- 8 soft drop players fk constraints
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_NAME = 'fk_players_current_location_id')
    ALTER TABLE players DROP CONSTRAINT fk_players_current_location_id
GO


-- 7 soft drop players table
DROP TABLE IF EXISTS players
GO

-- 6 soft drop location_items fk constraints
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_NAME = 'fk_location_items_item_id')
    ALTER TABLE location_items DROP CONSTRAINT fk_location_items_item_id
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_NAME = 'fk_location_items_location_id')
    ALTER TABLE location_items DROP CONSTRAINT fk_location_items_location_id
GO

-- 5 soft drop location_items table
DROP TABLE IF EXISTS location_items
GO

-- 4 soft drop items table
DROP TABLE IF EXISTS items
GO

-- 3 soft drop location_connections fk constraints
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_NAME = 'fk_to_location_id')
    ALTER TABLE location_connections DROP CONSTRAINT fk_to_location_id
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_NAME = 'fk_from_location_id')
    ALTER TABLE location_connections DROP CONSTRAINT fk_from_location_id
GO

-- 2 soft drop location_connections table
DROP TABLE IF EXISTS location_connections
GO

-- 1 soft drop locations table
DROP TABLE IF EXISTS locations
GO

/**********************************************************************
  SECTION 2: UP Metadata
  -- Create all tables, relationships, constraints, indexes
**********************************************************************/

-- 1 create locations table
CREATE TABLE locations (
    location_id INT IDENTITY PRIMARY KEY,
    location_name VARCHAR(100) NOT NULL,
    location_description TEXT NOT NULL,
    is_dark BIT DEFAULT 0,
)
GO

-- 2 create location_connections table
CREATE TABLE location_connections (
    connection_id INT IDENTITY PRIMARY KEY,
    from_location_id INT NOT NULL,
    to_location_id INT NOT NULL,
    direction VARCHAR(20) NOT NULL -- e.g., 'north', 'south'
)
GO

-- 3 add location_connections fk constraints
ALTER TABLE location_connections
ADD CONSTRAINT fk_location_connections_from_location_id FOREIGN KEY (from_location_id) REFERENCES locations(location_id)
GO
ALTER TABLE location_connections
ADD CONSTRAINT fk_location_connections_to_location_id FOREIGN KEY (to_location_id) REFERENCES locations(location_id)
GO

-- 4 create items table
CREATE TABLE items (
    item_id INT IDENTITY PRIMARY KEY,
    item_name VARCHAR(100) NOT NULL,
    item_description TEXT,
    is_pickable BIT DEFAULT 1,
    is_usable BIT DEFAULT 0
)
GO

-- 5 create location_items table
CREATE TABLE location_items (
    location_id INT NOT NULL,
    item_id INT NOT NULL,
    PRIMARY KEY (location_id, item_id)
)
GO

-- 6 add location_itmes fk constraints
ALTER TABLE location_items
ADD CONSTRAINT fk_location_items_location_id FOREIGN KEY (location_id) REFERENCES locations(location_id)
GO
ALTER TABLE location_items
ADD CONSTRAINT fk_location_items_item_id FOREIGN KEY (item_id) REFERENCES items(item_id)
GO

-- 7 create players table
CREATE TABLE players (
    player_id INT IDENTITY PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    current_location_id INT NOT NULL,
    last_action_time DATETIME DEFAULT CURRENT_TIMESTAMP
)
GO

-- 8 add players fk constraints
ALTER TABLE players
ADD CONSTRAINT fk_players_current_location_id FOREIGN KEY (current_location_id) REFERENCES locations(location_id)
GO

-- 9 create inventory table
CREATE TABLE inventory (
    player_id INT NOT NULL,
    item_id INT NOT NULL,
    quantity INT DEFAULT 1,
    PRIMARY KEY (player_id, item_id)
);
GO

-- 10 add inventory fk constraints
ALTER TABLE inventory
ADD CONSTRAINT fk_inventory_player_id FOREIGN KEY (player_id) REFERENCES players(player_id)
GO
ALTER TABLE inventory
ADD CONSTRAINT fk_inventory_item_id FOREIGN KEY (item_id) REFERENCES items(item_id)
GO

-- 11 create action_log
CREATE TABLE action_log (
    log_id INT IDENTITY PRIMARY KEY,
    player_id INT NOT NULL,
    action_location INT NOT NULL,
    action_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    player_action VARCHAR(50),
    details TEXT
)

-- 12 add action log fk constraints
ALTER TABLE action_log
ADD CONSTRAINT fk_action_log_player_id FOREIGN KEY (player_id) REFERENCES players(player_id)
GO


/**********************************************************************
  SECTION 3: UP Data
  -- Seed initial records for locations, items, players, etc.
**********************************************************************/

/*======================================================================
  3.1 CREATE LOCATIONS
======================================================================*/

/* Crash Site */
-- Home Location: Crash Site
DECLARE @crash_id INT;
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Crash Site')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Crash Site', 'Your ship lies broken at the crash site.', 0);
END;
SELECT @crash_id = location_id FROM locations WHERE location_name = 'Crash Site';

/* East */
-- East Location: Nav Ping (East)
DECLARE @east_id INT, @east_sub1 INT, @east_sub2 INT, @east_sub3 INT;
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Nav Ping (East)')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Nav Ping (East)', 'Scanner pings suggest a beacon nearby.', 0);
END;
SELECT @east_id = location_id FROM locations WHERE location_name = 'Nav Ping (East)';

-- East Sub1: Signal Ridge
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Signal Ridge')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Signal Ridge', 'A jagged ridge amplifies your comm signals.', 0);
END;
SELECT @east_sub1 = location_id FROM locations WHERE location_name = 'Signal Ridge';

-- East Sub2: Debris Field
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Debris Field')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Debris Field', 'Fragments of old wreckage litter the ground.', 0);
END;
SELECT @east_sub2 = location_id FROM locations WHERE location_name = 'Debris Field';

-- East Sub3: Beacon Tower
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Beacon Tower')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Beacon Tower', 'An ancient navigation beacon flickers weakly.', 0);
END;
SELECT @east_sub3 = location_id FROM locations WHERE location_name = 'Beacon Tower';

/* West */
-- West Location: Forest (West)
DECLARE @West_id INT, @West_sub1 INT, @West_sub2 INT, @West_sub3 INT;
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Forest (West)')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Forest (West)', 'Thick canopy and earthy scents fill the western forest. Shadows dance between the trees.', 0);
END;
SELECT @West_id = location_id FROM locations WHERE location_name = 'Forest (West)';

-- West Sub1: Babbling Brook
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Babbling Brook')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Babbling Brook', 'A gentle stream winds through mossy stones. The sound of water soothes the air.', 0);
END;
SELECT @West_sub1 = location_id FROM locations WHERE location_name = 'Babbling Brook';

-- West Sub2: Dark Cave
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Dark Cave')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Dark Cave', 'A narrow cave mouth yawns beneath a rocky ledge. The interior is pitch black.', 0);
END;
SELECT @West_sub2 = location_id FROM locations WHERE location_name = 'Dark Cave';

-- West Sub3: Dense Brush
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Dense Brush')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Dense Brush', 'Thick undergrowth blocks the path. Twigs snap underfoot and visibility is poor.', 0);
END;
SELECT @West_sub3 = location_id FROM locations WHERE location_name = 'Dense Brush';

/* North */
-- North Location: Dust Storm (North)
DECLARE @north_id INT, @north_sub1 INT, @north_sub2 INT, @north_sub3 INT;
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Dust Storm (North)')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Dust Storm (North)', 'A low, thick, slow moving dust storm is visible due North. Electric sparks and loud rolls of thunder emanate from its bowls. Heavens know what awaits but maybe its worth exploring....', 0);
END;
SELECT @north_id = location_id FROM locations WHERE location_name = 'Dust Storm (North)';

-- North Sub1: Open Cavern
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Open Cavern')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Open Cavern', 'An open hungry looking cavern with sharp fang like Stalactites pruturding from the dark domain.', 0);
END;
SELECT @north_sub1 = location_id FROM locations WHERE location_name = 'Open Cavern';

-- North Sub2: Massive Stone
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Massive stone')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Massive stone', 'A Massive stone stands obstinately againt the raging storm.', 0);
END;
SELECT @north_sub2 = location_id FROM locations WHERE location_name = 'Massive stone';

-- North Sub3: Dreary desert dune
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Dreary desert dune')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Dreary desert dune', 'A Dreary desert dune devoid of distinguishable details, debatable doth digging to devludge debris.', 0);
END;
SELECT @north_sub3 = location_id FROM locations WHERE location_name = 'Dreary desert dune';

/* South */
-- South Location: Alien Marshland
DECLARE @South_id INT, @South_sub1 INT, @South_sub2 INT, @South_sub3 INT;
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Alien Marshland')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Alien Marshland', 'This seemingly endless watery landscape smells of toxins and the vegetation has an unsettling movement to it...', 0);
END;
SELECT @South_id = location_id FROM locations WHERE location_name = 'Alien Marshland';

-- South Sub1: Hidden Grove
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Hidden Grove')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Hidden Grove', 'A small grove of crooked and broken trees at the base of a hill looks like it could have signs of life.', 0);
END;
SELECT @South_sub1 = location_id FROM locations WHERE location_name = 'Hidden Grove';

-- South Sub2: Foggy Mud Flat
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Foggy Mud Flat')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Foggy Mud Flat', 'In the distance there appears to be a muddy clearing with a mound of reeds emitting a bioluminescent light.', 0);
END;
SELECT @South_sub2 = location_id FROM locations WHERE location_name = 'Foggy Mud Flat';

-- South Sub3: Boat Dock
IF NOT EXISTS (SELECT 1 FROM locations WHERE location_name = 'Boat Dock')
BEGIN
    INSERT INTO locations (location_name, location_description, is_dark)
    VALUES ('Boat Dock', 'There appears to be an ominous looking boat dock covered in algae and small glowing insects.', 0);
END;
SELECT @South_sub3 = location_id FROM locations WHERE location_name = 'Boat Dock';

/*======================================================================
  3.2 CREATE LOCATION CONNECTIONS
======================================================================*/

/* East */
-- Crash Site <-> East
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@crash_id AND to_location_id=@east_id AND direction='east')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@crash_id, @east_id, 'east');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@east_id AND to_location_id=@crash_id AND direction='west')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@east_id, @crash_id, 'west');

-- East <-> Signal Ridge
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@east_id AND to_location_id=@east_sub1 AND direction='forward')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@east_id, @east_sub1, 'forward');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@east_sub1 AND to_location_id=@east_id AND direction='back')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@east_sub1, @east_id, 'back');

-- East <-> Debris Field
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@east_id AND to_location_id=@east_sub2 AND direction='left')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@east_id, @east_sub2, 'left');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@east_sub2 AND to_location_id=@east_id AND direction='back')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@east_sub2, @east_id, 'back');

-- East <-> Beacon Tower
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@east_id AND to_location_id=@east_sub3 AND direction='right')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@east_id, @east_sub3, 'right');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@east_sub3 AND to_location_id=@east_id AND direction='back')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@east_sub3, @east_id, 'back');

/* West */
-- Crash Site <-> West
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@crash_id AND to_location_id=@west_id AND direction='west')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@crash_id, @west_id, 'west');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@west_id AND to_location_id=@crash_id AND direction='east')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@west_id, @crash_id, 'east');

-- west <-> Sub1
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@west_id AND to_location_id=@west_sub1 AND direction='forward')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@west_id, @west_sub1, 'forward');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@west_sub1 AND to_location_id=@west_id AND direction='back')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@west_sub1, @west_id, 'back');

-- west <-> Sub2
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@west_id AND to_location_id=@west_sub2 AND direction='left')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@west_id, @west_sub2, 'left');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@west_sub2 AND to_location_id=@west_id AND direction='back')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@west_sub2, @west_id, 'back');

-- west <-> Sub3
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@west_id AND to_location_id=@west_sub3 AND direction='right')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@west_id, @west_sub3, 'right');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@west_sub3 AND to_location_id=@west_id AND direction='back')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@west_sub3, @west_id, 'back');

/* North */
-- Crash Site <-> North
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@crash_id AND to_location_id=@north_id AND direction='north')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@crash_id, @north_id, 'north');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@north_id AND to_location_id=@crash_id AND direction='south')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@north_id, @crash_id, 'south');

-- North <-> Open Cavern
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@north_id AND to_location_id=@north_sub1 AND direction='forward')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@north_id, @north_sub1, 'forward');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@north_sub1 AND to_location_id=@north_id AND direction='back')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@north_sub1, @north_id, 'back');

-- North <-> Massive Stone
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@north_id AND to_location_id=@north_sub2 AND direction='left')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@north_id, @north_sub2, 'left');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@north_sub2 AND to_location_id=@north_id AND direction='back')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@north_sub2, @north_id, 'back');

-- North <-> Dreary desert dune
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@north_id AND to_location_id=@north_sub3 AND direction='right')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@north_id, @north_sub3, 'right');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@north_sub3 AND to_location_id=@north_id AND direction='back')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@north_sub3, @north_id, 'back');

/* South */
-- Crash Site <-> South
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@crash_id AND to_location_id=@south_id AND direction='south')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@crash_id, @south_id, 'south');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@south_id AND to_location_id=@crash_id AND direction='north')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@south_id, @crash_id, 'north');

-- South <-> Sub1
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@South_id AND to_location_id=@South_sub1 AND direction='forward')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@South_id, @South_sub1, 'forward');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@South_sub1 AND to_location_id=@South_id AND direction='back')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@South_sub1, @South_id, 'back');

-- South <-> Sub2
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@South_id AND to_location_id=@South_sub2 AND direction='left')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@South_id, @South_sub2, 'left');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@South_sub2 AND to_location_id=@South_id AND direction='back')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@South_sub2, @South_id, 'back');

-- South <-> Sub3
IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@South_id AND to_location_id=@South_sub3 AND direction='right')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@South_id, @South_sub3, 'right');

IF NOT EXISTS (SELECT 1 FROM location_connections WHERE from_location_id=@South_sub3 AND to_location_id=@South_id AND direction='back')
    INSERT INTO location_connections (from_location_id, to_location_id, direction)
    VALUES (@South_sub3, @South_id, 'back');

/*======================================================================
  3.3 PLACE ITEMS IN LOCATIONS
======================================================================*/

/* East */
-- East Item: Nav Beacon Core
IF NOT EXISTS (SELECT 1 FROM items WHERE item_name = 'Nav Beacon Core')
BEGIN
    INSERT INTO items (item_name, item_description, is_pickable, is_usable)
    VALUES ('Nav Beacon Core', 'A stabilized navigation beacon core, essential for long-range relaunch calibration.', 1, 1);
END;
DECLARE @nav_core_id INT = (SELECT item_id FROM items WHERE item_name='Nav Beacon Core');

-- Map the item east_sub3 (Beacon Terminal)
IF NOT EXISTS (SELECT 1 FROM location_items WHERE location_id=@east_sub3 AND item_id=@nav_core_id)
BEGIN
    INSERT INTO location_items (location_id, item_id) VALUES (@east_sub3, @nav_core_id);
END;

/* West */
-- West Item: Electronics Control Unit
IF NOT EXISTS (SELECT 1 FROM items WHERE item_name = 'Electronics Control Unit')
BEGIN
    INSERT INTO items (item_name, item_description, is_pickable, is_usable)
    VALUES ('Electronics Control Unit', 'An electronic control unit salvaged from a damaged drone. Vital for ship diagnostics.', 1, 1);
END;
DECLARE @ecu_id INT = (SELECT item_id FROM items WHERE item_name='Electronics Control Unit');

-- Place Item
IF NOT EXISTS (SELECT 1 FROM location_items WHERE location_id=@west_sub2 AND item_id=@ecu_id)
    INSERT INTO location_items (location_id, item_id) VALUES (@west_sub2, @ecu_id);

/* North */
-- North Item: Fuel Cell
IF NOT EXISTS (SELECT 1 FROM items WHERE item_name = 'Fuel Cell')
BEGIN
    INSERT INTO items (item_name, item_description, is_pickable, is_usable)
    VALUES ('Fuel Cell', 'A still functioning and charged Fuel Cell from a previous unmanned surveying satalite.', 1, 1);
END;
DECLARE @fuel_id INT = (SELECT item_id FROM items WHERE item_name='Fuel Cell');

-- Map Item to north_sub3 (Dreary desert dune)
IF NOT EXISTS (SELECT 1 FROM location_items WHERE location_id=@north_sub3 AND item_id=@fuel_id)
    INSERT INTO location_items (location_id, item_id) VALUES (@north_sub3, @fuel_id);

/* South */
-- South Item: Micro-generator
IF NOT EXISTS (SELECT 1 FROM items WHERE item_name = 'Micro-generator')
BEGIN
    INSERT INTO items (item_name, item_description, is_pickable, is_usable)
    VALUES ('Micro-generator', 'This micro-generator was emitting the bioluminescent light! It will help bring power back to the starship control panel.', 1, 1);
END;
DECLARE @micro_id INT = (SELECT item_id FROM items WHERE item_name='Micro-generator');

-- Map Item to south_sub2 (tbd)
IF NOT EXISTS (SELECT 1 FROM location_items WHERE location_id=@south_sub2 AND item_id=@micro_id)
    INSERT INTO location_items (location_id, item_id) VALUES (@south_sub2, @micro_id);


/*======================================================================
  3.4 ADD PLAYER
======================================================================*/
-- create Player One
-- INSERT INTO players (username, current_location_id) VALUES ('Player One',1)
INSERT INTO players (username, current_location_id) VALUES ('Player One', @crash_id)

GO


/**********************************************************************
  SECTION 4: Stored Procedures
  -- Stored procedures govern gameplay
  -- 4.1 usp_lookAround
  -- 4.2 usp_movePlayer
  -- 4.3 usp_showInventory
  -- 4.4 usp_pickUpItem
  -- 4.5 usp_completeGame
**********************************************************************/

/*======================================================================
  4.1 usp_lookAround @player_id
-- shows current location description
-- lists items in the location
-- lists available exits (with directions)
======================================================================*/

-- 13 create usp_lookAround 
CREATE PROCEDURE usp_lookAround
    @player_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @location_id INT;

    -- get players current location
    SELECT @location_id = current_location_id
    FROM players
    WHERE player_id = @player_id;

    -- get location description
    SELECT location_name AS LocationName, location_description AS LocationDescription
    FROM locations
    WHERE location_id = @location_id;

    -- check for items in location
    SELECT i.item_id, i.item_name AS ItemName, i.item_description
    FROM location_items AS li
    JOIN items i ON li.item_id = i.item_id
    WHERE li.location_id = @location_id;

    -- return available exits
    SELECT direction, to_location_id
    FROM location_connections
    WHERE from_location_id = @location_id;

    -- update action_log
    DECLARE @current_location_name NVARCHAR(20)
    DECLARE @lookMessage VARCHAR(100);

    -- get item name
    SELECT @current_location_name = location_name FROM locations WHERE location_id = @location_id
    SET @lookMessage = 'Player looked around in the ' + @current_location_name + ' location'
    INSERT INTO action_log (player_id, action_location, action_time, player_action, details)
    VALUES (@player_id, @location_id, CURRENT_TIMESTAMP, 'Look Around', @lookMessage);
END;
GO

/*======================================================================
  4.2 usp_movePlayer @player_id, @direction
-- moves player in a valid direction based on location_connections
-- automatically calls usp_lookaround after moving
======================================================================*/

-- 14 create usp_movePlayer
CREATE PROCEDURE dbo.usp_movePlayer
    @player_id INT,
    @direction VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @current_location INT, @next_location INT;

    SELECT @current_location = current_location_id
    FROM players
    WHERE player_id = @player_id;

    SELECT @next_location = to_location_id
    FROM location_connections
    WHERE from_location_id = @current_location AND direction = @direction;

    IF @next_location IS NULL
    BEGIN
        PRINT 'You cannot go that direction.';
        RETURN;
    END

    UPDATE players
    SET current_location_id = @next_location,
        last_action_time = GETDATE()
    WHERE player_id = @player_id;

    -- (JEONGHWAN) moved logging to trigger: dbo.trg_players_move_log
END;
GO

/*======================================================================
  4.3 usp_pickUpItem @player_id, @item_id
-- picks up an item from the location (if present and pickable)
-- adds it to the player's inventory (increments if held)
-- removes it from the location
======================================================================*/

-- 15 create usp_pickUpItem
CREATE PROCEDURE dbo.usp_pickUpItem
    @player_id INT,
    @item_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @location_id INT;

    SELECT @location_id = current_location_id
    FROM players
    WHERE player_id = @player_id;

    IF NOT EXISTS (
        SELECT 1
        FROM location_items
        WHERE location_id = @location_id AND item_id = @item_id
    )
    BEGIN
        PRINT 'That item is not here.';
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM items WHERE item_id = @item_id AND is_pickable = 0
    )
    BEGIN
        PRINT 'You cannot pick up that item.';
        RETURN;
    END

    -- upsert with quantity capped at 1 (even without trigger, stay consistent)
    IF EXISTS (
        SELECT 1 FROM inventory WHERE player_id = @player_id AND item_id = @item_id
    )
    BEGIN
        UPDATE inventory
           SET quantity = 1
         WHERE player_id = @player_id AND item_id = @item_id;
    END
    ELSE
    BEGIN
        INSERT INTO inventory (player_id, item_id, quantity)
        VALUES (@player_id, @item_id, 1);
    END

    DELETE FROM location_items
    WHERE location_id = @location_id AND item_id = @item_id;

    DECLARE @item_name NVARCHAR(100);
    SELECT @item_name = item_name FROM items WHERE item_id = @item_id;

    IF @item_name IS NOT NULL
        PRINT 'You have picked up an item: ' + @item_name + '.';
    ELSE
        PRINT 'Item not found.';
END;
GO

/*======================================================================
  4.4 usp_showinventory @player_id
-- lists all items a player has picked up
-- includes quantity and item descriptions
======================================================================*/

-- 16 create usp_showInventory 
CREATE PROCEDURE usp_showInventory
    @player_id INT
AS
BEGIN
    SET NOCOUNT ON;
    -- get items from item inventory for @player_id
    SELECT i.item_id, i.item_name AS ItemName, i.item_description, inv.quantity
    FROM inventory inv
    JOIN items i ON inv.item_id = i.item_id
    WHERE inv.player_id = @player_id;

    DECLARE @location_id INT;
    -- get player's current location 
    SELECT @location_id = current_location_id
    FROM players
    WHERE player_id = @player_id;

    -- update action_log
    INSERT INTO action_log (player_id, action_location, action_time, player_action, details)
    VALUES (@player_id, @location_id, CURRENT_TIMESTAMP, 'Show Inventory', 'Player viewed the items in their inventory');
END;
GO

/**********************************************************************
  4.5 usp_completeGame
  -- Checks a player's inventory for the 4 required items
  -- If the player has all 4 items → declare victory
  -- If missing items → return guidance message
**********************************************************************/

-- 17 create usp_completeGame
CREATE OR ALTER PROCEDURE usp_completeGame
    @player_id INT
AS
BEGIN
    SET NOCOUNT ON;

    -- check that the player is back at the Crash Site
    DECLARE @player_location_id INT;
    DECLARE @crash_site_id INT;

    -- get Crash Site location_id
    SELECT @crash_site_id = location_id
    FROM locations
    WHERE location_name = 'Crash Site';

    -- get player's current location_id
    SELECT @player_location_id = current_location_id
    FROM players
    WHERE player_id = @player_id;

    -- check to see if the player is at the Crash Site
    IF @player_location_id <> @crash_site_id
    BEGIN
        PRINT 'You must return to your starship at the crash site in order to install missing parts';
        RETURN;
    END

    -- check for required items
    BEGIN TRY
        -- define 4 required items and the hints to find them
        DECLARE @requiredItems TABLE (item_id INT, item_name VARCHAR(50), hint VARCHAR(200));
        INSERT INTO @requiredItems (item_id, item_name, hint)
        VALUES 
            (1, 'Nav Beacon Core', 'Head east in search of a tower as beacon of hope...'),
            (2, 'Electronics Control Unit',  'There is a dark location to explore to the west...'),
            (3, 'Fuel Cell',    'To the north, a mound of sand might fuel your escape...'),
            (4, 'Micro-generator', 'A southern wind generates a toxic smell from the mud flats...');

        -- check the players inventory for required items
        DECLARE @playerItems TABLE (item_id INT);
        INSERT INTO @playerItems (item_id)
        SELECT inv.item_id
        FROM inventory AS inv
        WHERE inv.player_id = @player_id;

        -- Find missing items
        IF EXISTS (
            SELECT r.item_id
            FROM @requiredItems AS r
            WHERE r.item_id NOT IN (SELECT item_id FROM @playerItems)
        )
        BEGIN
            -- Player is missing one or more items
            SELECT 
                r.item_name AS MissingItem,
                r.hint AS SuggestedLocation
            FROM @requiredItems AS r
            WHERE r.item_id NOT IN (SELECT item_id FROM @playerItems);

            -- update action log
            INSERT INTO action_log (player_id, action_location, action_time, player_action, details)
            VALUES (@player_id, @player_location_id, CURRENT_TIMESTAMP, 'Attempted to Complete Game', 'Player attempted to finished the game without all of the required items');
        END
        ELSE
        BEGIN
            -- Player has all 4 items
            -- update action_log
            INSERT INTO action_log (player_id, action_location, action_time, player_action, details)
            VALUES (@player_id, @player_location_id, CURRENT_TIMESTAMP, 'Complete Game', 'Player finished the game');
            -- return message
            PRINT 'You have everything you need to launch!  Time to leave this strange planet.  Game over';
        END
    END TRY
    BEGIN CATCH
        PRINT 'Error in usp_completeGame.';
        PRINT ERROR_MESSAGE();
    END CATCH
    
END;
GO

/**********************************************************************
  SECTION 5: Triggers (JEONGHWAN patch)
  - trg_players_move_log: logs moves when players.current_location_id changes
  - trg_inventory_audit:  logs pickups/drops when inventory changes
  - trg_inventory_validate: enforces is_pickable=1 and quantity<=1
**********************************************************************/

-- 18 create trg_players_move_log
-- JEONGHWAN: log moves when player's current_location_id changes
CREATE TRIGGER dbo.trg_players_move_log
ON dbo.players
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(current_location_id)
    BEGIN
        ;WITH moved AS (
            SELECT i.player_id,
                   d.current_location_id AS from_loc,
                   i.current_location_id AS to_loc
            FROM inserted i
            JOIN deleted  d ON d.player_id = i.player_id
            WHERE ISNULL(d.current_location_id,-1) <> ISNULL(i.current_location_id,-1)
        )
        INSERT INTO dbo.action_log (player_id, action_location, action_time, player_action, details)
        SELECT m.player_id,
               m.to_loc,
               CURRENT_TIMESTAMP,
               'Move Player',
               CONCAT('Player moved from ', lf.location_name, ' to ', lt.location_name, ' (trigger)')
        FROM moved m
        LEFT JOIN dbo.locations lf ON lf.location_id = m.from_loc
        LEFT JOIN dbo.locations lt ON lt.location_id = m.to_loc;
    END
END;
GO

-- 19 create trg_inventory_audit
-- JEONGHWAN: audit pickups/drops on inventory changes
CREATE TRIGGER dbo.trg_inventory_audit
ON dbo.inventory
AFTER INSERT, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT only (pickup)
    INSERT INTO dbo.action_log (player_id, action_location, action_time, player_action, details)
    SELECT i.player_id,
           p.current_location_id,
           CURRENT_TIMESTAMP,
           'Pick Up Item',
           CONCAT('Player picked up ', it.item_name, ' (trigger). Qty=', i.quantity)
    FROM inserted i
    JOIN dbo.players p ON p.player_id = i.player_id
    JOIN dbo.items   it ON it.item_id   = i.item_id
    WHERE NOT EXISTS (
        SELECT 1 FROM deleted d
        WHERE d.player_id = i.player_id AND d.item_id = i.item_id
    );

    -- DELETE only (drop)
    INSERT INTO dbo.action_log (player_id, action_location, action_time, player_action, details)
    SELECT d.player_id,
           p.current_location_id,
           CURRENT_TIMESTAMP,
           'Drop Item',
           CONCAT('Player dropped ', it.item_name, ' (trigger). Qty=', d.quantity)
    FROM deleted d
    JOIN dbo.players p ON p.player_id = d.player_id
    JOIN dbo.items   it ON it.item_id   = d.item_id
    WHERE NOT EXISTS (
        SELECT 1 FROM inserted i
        WHERE i.player_id = d.player_id AND i.item_id = d.item_id
    );
END;
GO

-- 20 create trg_inventory_validate
-- JEONGHWAN: enforce inventory business rules (pickable only, quantity <= 1)
CREATE TRIGGER dbo.trg_inventory_validate
ON dbo.inventory
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- deny unpickable items
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.items it ON it.item_id = i.item_id
        WHERE it.is_pickable = 0
    )
    BEGIN
        RAISERROR('Cannot pick up this item (is_pickable = 0).', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- normalize quantity to 1 (v1.0 rule)
    UPDATE inv
      SET quantity = 1
    FROM dbo.inventory inv
    JOIN inserted i
      ON inv.player_id = i.player_id AND inv.item_id = i.item_id
    WHERE inv.quantity > 1;
END;
GO

-- END TRIGGERS (JEONGHWAN)

/**********************************************************************
  SECTION 6: Verify Database
  -- Check database tables to ensure script ran properly
**********************************************************************/

SELECT * FROM locations;
SELECT * FROM location_connections;
SELECT * FROM items;
SELECT * FROM location_items;
SELECT * FROM players;
SELECT * FROM inventory;
SELECT * FROM action_log;
GO

-- END DATABASE SCRIPT
--##########################################################################################
