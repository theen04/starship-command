/**********************************************************************
  Starship Command v2.0 (PostgreSQL)
  02 Seed Data

  SECTION 3: UP Data
  -- Seed initial records for locations, connections, items and players
  -- Rows reference each other by name, so the world can be extended by
     adding lines to the VALUES lists below
**********************************************************************/

/*======================================================================
  3.1 CREATE LOCATIONS
======================================================================*/

INSERT INTO locations (location_name, location_description, is_dark, is_start) VALUES
    -- Home Location
    ('Crash Site',         'Your ship lies broken at the crash site.', FALSE, TRUE),

    -- East
    ('Nav Ping (East)',    'Scanner pings suggest a beacon nearby.', FALSE, FALSE),
    ('Signal Ridge',       'A jagged ridge amplifies your comm signals.', FALSE, FALSE),
    ('Debris Field',       'Fragments of old wreckage litter the ground.', FALSE, FALSE),
    ('Beacon Tower',       'An ancient navigation beacon flickers weakly.', FALSE, FALSE),

    -- West
    ('Forest (West)',      'Thick canopy and earthy scents fill the western forest. Shadows dance between the trees.', FALSE, FALSE),
    ('Babbling Brook',     'A gentle stream winds through mossy stones. The sound of water soothes the air.', FALSE, FALSE),
    ('Dark Cave',          'A narrow cave mouth yawns beneath a rocky ledge. The interior is pitch black.', FALSE, FALSE),
    ('Dense Brush',        'Thick undergrowth blocks the path. Twigs snap underfoot and visibility is poor.', FALSE, FALSE),

    -- North
    ('Dust Storm (North)', 'A low, thick, slow moving dust storm is visible due North. Electric sparks and loud rolls of thunder emanate from its bowels. Heavens know what awaits but maybe it''s worth exploring....', FALSE, FALSE),
    ('Open Cavern',        'An open hungry looking cavern with sharp fang like stalactites protruding from the dark domain.', FALSE, FALSE),
    ('Massive stone',      'A massive stone stands obstinately against the raging storm.', FALSE, FALSE),
    ('Dreary desert dune', 'A dreary desert dune devoid of distinguishable details, debatable doth digging to devludge debris.', FALSE, FALSE),

    -- South
    ('Alien Marshland',    'This seemingly endless watery landscape smells of toxins and the vegetation has an unsettling movement to it...', FALSE, FALSE),
    ('Hidden Grove',       'A small grove of crooked and broken trees at the base of a hill looks like it could have signs of life.', FALSE, FALSE),
    ('Foggy Mud Flat',     'In the distance there appears to be a muddy clearing with a mound of reeds emitting a bioluminescent light.', FALSE, FALSE),
    ('Boat Dock',          'There appears to be an ominous looking boat dock covered in algae and small glowing insects.', FALSE, FALSE);

/*======================================================================
  3.2 CREATE LOCATION CONNECTIONS
  -- each row creates a two-way path: from -> to via direction,
     and to -> from via return_direction
======================================================================*/

INSERT INTO location_connections (from_location_id, to_location_id, direction)
SELECT f.location_id, t.location_id, path.direction
FROM (VALUES
    -- East
    ('Crash Site',         'Nav Ping (East)',    'east',    'west'),
    ('Nav Ping (East)',    'Signal Ridge',       'forward', 'back'),
    ('Nav Ping (East)',    'Debris Field',       'left',    'back'),
    ('Nav Ping (East)',    'Beacon Tower',       'right',   'back'),

    -- West
    ('Crash Site',         'Forest (West)',      'west',    'east'),
    ('Forest (West)',      'Babbling Brook',     'forward', 'back'),
    ('Forest (West)',      'Dark Cave',          'left',    'back'),
    ('Forest (West)',      'Dense Brush',        'right',   'back'),

    -- North
    ('Crash Site',         'Dust Storm (North)', 'north',   'south'),
    ('Dust Storm (North)', 'Open Cavern',        'forward', 'back'),
    ('Dust Storm (North)', 'Massive stone',      'left',    'back'),
    ('Dust Storm (North)', 'Dreary desert dune', 'right',   'back'),

    -- South
    ('Crash Site',         'Alien Marshland',    'south',   'north'),
    ('Alien Marshland',    'Hidden Grove',       'forward', 'back'),
    ('Alien Marshland',    'Foggy Mud Flat',     'left',    'back'),
    ('Alien Marshland',    'Boat Dock',          'right',   'back')
) AS pairs (from_name, to_name, direction, return_direction)
CROSS JOIN LATERAL (VALUES
    (pairs.from_name, pairs.to_name, pairs.direction),
    (pairs.to_name, pairs.from_name, pairs.return_direction)
) AS path (from_name, to_name, direction)
JOIN locations f ON f.location_name = path.from_name
JOIN locations t ON t.location_name = path.to_name;

/*======================================================================
  3.3 CREATE ITEMS AND PLACE THEM IN LOCATIONS
======================================================================*/

INSERT INTO items (item_name, item_description, is_pickable, is_usable, is_required, hint) VALUES
    ('Nav Beacon Core',          'A stabilized navigation beacon core, essential for long-range relaunch calibration.', TRUE, TRUE, TRUE,
                                 'Head east in search of a tower as beacon of hope...'),
    ('Electronics Control Unit', 'An electronic control unit salvaged from a damaged drone. Vital for ship diagnostics.', TRUE, TRUE, TRUE,
                                 'There is a dark location to explore to the west...'),
    ('Fuel Cell',                'A still functioning and charged Fuel Cell from a previous unmanned surveying satellite.', TRUE, TRUE, TRUE,
                                 'To the north, a mound of sand might fuel your escape...'),
    ('Micro-generator',          'This micro-generator was emitting the bioluminescent light! It will help bring power back to the starship control panel.', TRUE, TRUE, TRUE,
                                 'A southern wind generates a toxic smell from the mud flats...');

INSERT INTO location_items (location_id, item_id)
SELECT l.location_id, i.item_id
FROM (VALUES
    ('Beacon Tower',       'Nav Beacon Core'),
    ('Dark Cave',          'Electronics Control Unit'),
    ('Dreary desert dune', 'Fuel Cell'),
    ('Foggy Mud Flat',     'Micro-generator')
) AS placement (location_name, item_name)
JOIN locations l ON l.location_name = placement.location_name
JOIN items i ON i.item_name = placement.item_name;

/*======================================================================
  3.4 ADD PLAYER
  -- Player One (player_id = 1) is kept for the SQL walkthrough in
     db/gameplay_demo.sql; the web UI creates players with usp_create_player
======================================================================*/

INSERT INTO players (username, current_location_id)
SELECT 'Player One', location_id FROM locations WHERE is_start;
