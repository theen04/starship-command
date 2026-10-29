/**********************************************************************
  Starship Command v2.0 (PostgreSQL)
  01 Schema

  Port of the original SQL Server build script (sql/starship_command_build_script.sql).
  Scripts in db/init run in filename order the first time the Postgres
  container starts with an empty data volume.

  Script Outline
  1. DOWN (tear-down / drop objects)
  2. UP Metadata (create tables)
       - locations
       - location_connections
       - items
       - location_items
       - players
       - inventory
       - action_log

  Changes from v1.0
  - locations.is_start marks the Crash Site instead of looking it up by name
  - items.is_required / items.hint drive usp_complete_game instead of hard-coded ids
  - players.completed_at records a finished mission
  - location_items is now static world data; a player's inventory decides
    whether an item is still visible to them, so every player gets a full world
  - unique (from_location_id, direction) so a move can never be ambiguous
  - action_log.action_location now has a foreign key
**********************************************************************/

/**********************************************************************
  SECTION 1: DOWN
  -- Tear-down: drop objects in reverse dependency order
**********************************************************************/

DROP TABLE IF EXISTS action_log;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS players;
DROP TABLE IF EXISTS location_items;
DROP TABLE IF EXISTS items;
DROP TABLE IF EXISTS location_connections;
DROP TABLE IF EXISTS locations;

/**********************************************************************
  SECTION 2: UP Metadata
  -- Create all tables, relationships, constraints, indexes
**********************************************************************/

-- 1 create locations table
CREATE TABLE locations (
    location_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    location_name        VARCHAR(100) NOT NULL,
    location_description TEXT NOT NULL,
    is_dark              BOOLEAN NOT NULL DEFAULT FALSE,
    is_start             BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_locations_location_name UNIQUE (location_name)
);

-- only one location can be the starting point
CREATE UNIQUE INDEX uq_locations_single_start ON locations (is_start) WHERE is_start;

-- 2 create location_connections table
CREATE TABLE location_connections (
    connection_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    from_location_id INT NOT NULL,
    to_location_id   INT NOT NULL,
    direction        VARCHAR(20) NOT NULL, -- e.g., 'north', 'south', 'back'
    CONSTRAINT fk_location_connections_from_location_id FOREIGN KEY (from_location_id) REFERENCES locations (location_id),
    CONSTRAINT fk_location_connections_to_location_id FOREIGN KEY (to_location_id) REFERENCES locations (location_id),
    CONSTRAINT uq_location_connections_from_direction UNIQUE (from_location_id, direction),
    CONSTRAINT ck_location_connections_direction_lower CHECK (direction = lower(direction)),
    CONSTRAINT ck_location_connections_no_self_loop CHECK (from_location_id <> to_location_id)
);

-- 3 create items table
CREATE TABLE items (
    item_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_name        VARCHAR(100) NOT NULL,
    item_description TEXT,
    is_pickable      BOOLEAN NOT NULL DEFAULT TRUE,
    is_usable        BOOLEAN NOT NULL DEFAULT FALSE,
    is_required      BOOLEAN NOT NULL DEFAULT FALSE, -- needed to relaunch the ship
    hint             TEXT,                           -- shown when a required item is missing
    CONSTRAINT uq_items_item_name UNIQUE (item_name)
);

-- 4 create location_items table
CREATE TABLE location_items (
    location_id INT NOT NULL,
    item_id     INT NOT NULL,
    PRIMARY KEY (location_id, item_id),
    CONSTRAINT fk_location_items_location_id FOREIGN KEY (location_id) REFERENCES locations (location_id),
    CONSTRAINT fk_location_items_item_id FOREIGN KEY (item_id) REFERENCES items (item_id)
);

-- 5 create players table
CREATE TABLE players (
    player_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username            VARCHAR(50) NOT NULL,
    current_location_id INT NOT NULL,
    last_action_time    TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at        TIMESTAMPTZ,
    CONSTRAINT fk_players_current_location_id FOREIGN KEY (current_location_id) REFERENCES locations (location_id),
    CONSTRAINT ck_players_username_not_blank CHECK (btrim(username) <> '')
);

-- usernames are unique regardless of case
CREATE UNIQUE INDEX uq_players_username_ci ON players (lower(username));

-- 6 create inventory table
CREATE TABLE inventory (
    player_id INT NOT NULL,
    item_id   INT NOT NULL,
    quantity  INT NOT NULL DEFAULT 1,
    PRIMARY KEY (player_id, item_id),
    CONSTRAINT fk_inventory_player_id FOREIGN KEY (player_id) REFERENCES players (player_id),
    CONSTRAINT fk_inventory_item_id FOREIGN KEY (item_id) REFERENCES items (item_id),
    CONSTRAINT ck_inventory_quantity_positive CHECK (quantity > 0)
);

-- 7 create action_log table
CREATE TABLE action_log (
    log_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    player_id       INT NOT NULL,
    action_location INT NOT NULL,
    action_time     TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    player_action   VARCHAR(50) NOT NULL,
    details         TEXT,
    CONSTRAINT fk_action_log_player_id FOREIGN KEY (player_id) REFERENCES players (player_id),
    CONSTRAINT fk_action_log_action_location FOREIGN KEY (action_location) REFERENCES locations (location_id)
);

CREATE INDEX ix_action_log_player_id ON action_log (player_id, log_id DESC);
