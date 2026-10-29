/**********************************************************************
  Starship Command v2.0 (PostgreSQL)
  03 Gameplay Functions

  SECTION 4: Stored Procedures
  -- Postgres functions replace the v1.0 T-SQL procedures. Instead of
     PRINT messages and multiple result sets, every gameplay function
     returns one JSONB document so any client can drive the game:

       {
         "ok":      true | false,   -- did the action succeed?
         "message": "...",          -- text to show the player
         "state":   { ... }         -- fn_game_state(), or null if the player does not exist
       }

  -- Helpers
     fn_game_state       full snapshot of a player's game (read only)
     fn_result           builds the response document above
     fn_log_action       writes to action_log and touches last_action_time
     fn_mission_stats    moves and elapsed time for the current run
     fn_action_log       recent action_log entries for a player
  -- Gameplay
     4.0 usp_create_player
     4.1 usp_look_around
     4.2 usp_move_player
     4.3 usp_pick_up_item
     4.4 usp_show_inventory
     4.5 usp_complete_game
     4.6 usp_restart_game
**********************************************************************/

/*======================================================================
  Helpers
======================================================================*/

-- snapshot of everything a client needs to draw the game for one player
-- returns NULL when the player does not exist
CREATE OR REPLACE FUNCTION fn_game_state(p_player_id INT)
RETURNS JSONB
LANGUAGE sql STABLE
AS $$
    SELECT jsonb_build_object(
        'player', jsonb_build_object(
            'id', p.player_id,
            'username', p.username,
            'completed_at', p.completed_at
        ),
        'location', jsonb_build_object(
            'id', l.location_id,
            'name', l.location_name,
            'description', l.location_description,
            'is_start', l.is_start
        ),
        -- items placed here that this player has not already collected
        'items', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'id', i.item_id,
                       'name', i.item_name,
                       'description', i.item_description
                   ) ORDER BY i.item_name)
            FROM location_items li
            JOIN items i ON i.item_id = li.item_id
            WHERE li.location_id = l.location_id
              AND NOT EXISTS (
                  SELECT 1 FROM inventory inv
                  WHERE inv.player_id = p.player_id AND inv.item_id = li.item_id
              )
        ), '[]'::jsonb),
        'exits', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'direction', c.direction,
                       'location_id', c.to_location_id,
                       'location_name', dest.location_name
                   ) ORDER BY c.connection_id)
            FROM location_connections c
            JOIN locations dest ON dest.location_id = c.to_location_id
            WHERE c.from_location_id = l.location_id
        ), '[]'::jsonb),
        'inventory', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                       'id', i.item_id,
                       'name', i.item_name,
                       'description', i.item_description,
                       'quantity', inv.quantity,
                       'is_required', i.is_required
                   ) ORDER BY i.item_name)
            FROM inventory inv
            JOIN items i ON i.item_id = inv.item_id
            WHERE inv.player_id = p.player_id
        ), '[]'::jsonb),
        'mission', jsonb_build_object(
            'required', (SELECT count(*) FROM items WHERE is_required),
            'collected', (
                SELECT count(*)
                FROM inventory inv
                JOIN items i ON i.item_id = inv.item_id
                WHERE inv.player_id = p.player_id AND i.is_required
            ),
            'complete', p.completed_at IS NOT NULL
        )
    )
    FROM players p
    JOIN locations l ON l.location_id = p.current_location_id
    WHERE p.player_id = p_player_id;
$$;

-- standard response document returned by every gameplay function
CREATE OR REPLACE FUNCTION fn_result(p_player_id INT, p_ok BOOLEAN, p_message TEXT, p_extra JSONB DEFAULT '{}'::jsonb)
RETURNS JSONB
LANGUAGE sql STABLE
AS $$
    SELECT jsonb_build_object(
        'ok', p_ok,
        'message', p_message,
        'state', fn_game_state(p_player_id)
    ) || p_extra;
$$;

-- record an action at the player's current location
CREATE OR REPLACE FUNCTION fn_log_action(p_player_id INT, p_action VARCHAR, p_details TEXT)
RETURNS VOID
LANGUAGE sql
AS $$
    INSERT INTO action_log (player_id, action_location, player_action, details)
    SELECT player_id, current_location_id, p_action, p_details
    FROM players
    WHERE player_id = p_player_id;

    UPDATE players SET last_action_time = now() WHERE player_id = p_player_id;
$$;

-- moves taken and time spent since the player's run began
-- a run begins at 'New Player' or the latest 'Restart Game'
CREATE OR REPLACE FUNCTION fn_mission_stats(p_player_id INT)
RETURNS JSONB
LANGUAGE sql STABLE
AS $$
    WITH run AS (
        SELECT player_action, action_time
        FROM action_log
        WHERE player_id = p_player_id
          AND log_id >= COALESCE((
              SELECT max(log_id)
              FROM action_log
              WHERE player_id = p_player_id
                AND player_action IN ('New Player', 'Restart Game')
          ), 0)
    )
    SELECT jsonb_build_object(
        'moves', count(*) FILTER (WHERE player_action = 'Move Player'),
        'elapsed_seconds', COALESCE(round(extract(epoch FROM max(action_time) - min(action_time)))::INT, 0)
    )
    FROM run;
$$;

-- most recent action_log entries for a player, newest first
CREATE OR REPLACE FUNCTION fn_action_log(p_player_id INT, p_limit INT DEFAULT 25)
RETURNS JSONB
LANGUAGE sql STABLE
AS $$
    SELECT COALESCE(jsonb_agg(entry ORDER BY log_id DESC), '[]'::jsonb)
    FROM (
        SELECT a.log_id,
               jsonb_build_object(
                   'id', a.log_id,
                   'time', a.action_time,
                   'action', a.player_action,
                   'location', l.location_name,
                   'details', a.details
               ) AS entry
        FROM action_log a
        JOIN locations l ON l.location_id = a.action_location
        WHERE a.player_id = p_player_id
        ORDER BY a.log_id DESC
        LIMIT LEAST(GREATEST(p_limit, 1), 200)
    ) recent;
$$;

/*======================================================================
  4.0 usp_create_player(username)
  -- creates a player at the start location
  -- if the username already exists (any case), resumes that player
======================================================================*/

CREATE OR REPLACE FUNCTION usp_create_player(p_username TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_username  TEXT := btrim(p_username);
    v_player_id INT;
BEGIN
    IF v_username IS NULL OR v_username = '' OR length(v_username) > 50 THEN
        RETURN jsonb_build_object('ok', FALSE, 'message', 'Callsign must be between 1 and 50 characters.', 'state', 'null'::jsonb);
    END IF;

    INSERT INTO players (username, current_location_id)
    SELECT v_username, location_id FROM locations WHERE is_start
    ON CONFLICT ((lower(username))) DO NOTHING
    RETURNING player_id INTO v_player_id;

    -- username already taken: resume that player
    IF v_player_id IS NULL THEN
        SELECT player_id, username INTO v_player_id, v_username FROM players WHERE lower(username) = lower(v_username);
        RETURN fn_result(v_player_id, TRUE, format('Welcome back, Commander %s.', v_username), '{"is_new": false}');
    END IF;

    PERFORM fn_log_action(v_player_id, 'New Player', format('Commander %s registered', v_username));
    RETURN fn_result(v_player_id, TRUE, format('Welcome, Commander %s.', v_username), '{"is_new": true}');
END;
$$;

/*======================================================================
  4.1 usp_look_around(player_id)
  -- message is the current location description
  -- state lists the items and exits at the location
======================================================================*/

CREATE OR REPLACE FUNCTION usp_look_around(p_player_id INT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_location locations%ROWTYPE;
BEGIN
    SELECT l.* INTO v_location
    FROM players p
    JOIN locations l ON l.location_id = p.current_location_id
    WHERE p.player_id = p_player_id;

    IF NOT FOUND THEN
        RETURN fn_result(p_player_id, FALSE, 'Player not found.');
    END IF;

    PERFORM fn_log_action(p_player_id, 'Look Around',
        format('Player looked around in the %s location', v_location.location_name));

    RETURN fn_result(p_player_id, TRUE, v_location.location_description);
END;
$$;

/*======================================================================
  4.2 usp_move_player(player_id, direction)
  -- moves player in a valid direction based on location_connections
  -- logging handled by trg_players_move_log
======================================================================*/

CREATE OR REPLACE FUNCTION usp_move_player(p_player_id INT, p_direction TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_direction TEXT := lower(btrim(p_direction));
    v_current   INT;
    v_next      INT;
    v_next_name VARCHAR(100);
BEGIN
    SELECT current_location_id INTO v_current FROM players WHERE player_id = p_player_id;

    IF NOT FOUND THEN
        RETURN fn_result(p_player_id, FALSE, 'Player not found.');
    END IF;

    SELECT c.to_location_id, l.location_name INTO v_next, v_next_name
    FROM location_connections c
    JOIN locations l ON l.location_id = c.to_location_id
    WHERE c.from_location_id = v_current AND c.direction = v_direction;

    IF NOT FOUND THEN
        RETURN fn_result(p_player_id, FALSE, 'You cannot go that direction.');
    END IF;

    UPDATE players
    SET current_location_id = v_next,
        last_action_time = now()
    WHERE player_id = p_player_id;

    RETURN fn_result(p_player_id, TRUE, format('You head %s to %s.', v_direction, v_next_name));
END;
$$;

/*======================================================================
  4.3 usp_pick_up_item(player_id, item_id)
  -- picks up an item from the location (if present and pickable)
  -- the item stays in location_items so other players can still find it
  -- logging handled by trg_inventory_audit
======================================================================*/

CREATE OR REPLACE FUNCTION usp_pick_up_item(p_player_id INT, p_item_id INT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_location INT;
    v_item     items%ROWTYPE;
BEGIN
    SELECT current_location_id INTO v_location FROM players WHERE player_id = p_player_id;

    IF NOT FOUND THEN
        RETURN fn_result(p_player_id, FALSE, 'Player not found.');
    END IF;

    IF EXISTS (SELECT 1 FROM inventory WHERE player_id = p_player_id AND item_id = p_item_id) THEN
        RETURN fn_result(p_player_id, FALSE, 'You already have that item.');
    END IF;

    SELECT i.* INTO v_item
    FROM location_items li
    JOIN items i ON i.item_id = li.item_id
    WHERE li.location_id = v_location AND li.item_id = p_item_id;

    IF NOT FOUND THEN
        RETURN fn_result(p_player_id, FALSE, 'That item is not here.');
    END IF;

    IF NOT v_item.is_pickable THEN
        RETURN fn_result(p_player_id, FALSE, 'You cannot pick up that item.');
    END IF;

    INSERT INTO inventory (player_id, item_id, quantity)
    VALUES (p_player_id, p_item_id, 1)
    ON CONFLICT DO NOTHING;

    UPDATE players SET last_action_time = now() WHERE player_id = p_player_id;

    RETURN fn_result(p_player_id, TRUE, format('You have picked up an item: %s.', v_item.item_name));
END;
$$;

/*======================================================================
  4.4 usp_show_inventory(player_id)
  -- items are listed in state.inventory
======================================================================*/

CREATE OR REPLACE FUNCTION usp_show_inventory(p_player_id INT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM players WHERE player_id = p_player_id) THEN
        RETURN fn_result(p_player_id, FALSE, 'Player not found.');
    END IF;

    SELECT count(*) INTO v_count FROM inventory WHERE player_id = p_player_id;

    PERFORM fn_log_action(p_player_id, 'Show Inventory', 'Player viewed the items in their inventory');

    RETURN fn_result(p_player_id, TRUE,
        CASE WHEN v_count = 0 THEN 'Your inventory is empty.'
             ELSE format('You are carrying %s item(s).', v_count)
        END);
END;
$$;

/*======================================================================
  4.5 usp_complete_game(player_id)
  -- player must be at the start location (Crash Site)
  -- if the player has every required item -> declare victory
  -- if missing items -> "missing" lists each item with a hint
======================================================================*/

CREATE OR REPLACE FUNCTION usp_complete_game(p_player_id INT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_player  players%ROWTYPE;
    v_missing JSONB;
BEGIN
    SELECT * INTO v_player FROM players WHERE player_id = p_player_id;

    IF NOT FOUND THEN
        RETURN fn_result(p_player_id, FALSE, 'Player not found.');
    END IF;

    IF v_player.completed_at IS NOT NULL THEN
        RETURN fn_result(p_player_id, FALSE, 'Your starship has already launched. Restart to play again.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM locations WHERE location_id = v_player.current_location_id AND is_start) THEN
        RETURN fn_result(p_player_id, FALSE, 'You must return to your starship at the crash site in order to install missing parts.');
    END IF;

    -- find missing items
    SELECT jsonb_agg(jsonb_build_object('name', i.item_name, 'hint', i.hint) ORDER BY i.item_id)
    INTO v_missing
    FROM items i
    WHERE i.is_required
      AND NOT EXISTS (
          SELECT 1 FROM inventory inv
          WHERE inv.player_id = p_player_id AND inv.item_id = i.item_id
      );

    IF v_missing IS NOT NULL THEN
        PERFORM fn_log_action(p_player_id, 'Attempted to Complete Game',
            'Player attempted to finish the game without all of the required items');

        RETURN fn_result(p_player_id, FALSE,
            format('Repairs failed: %s component(s) still missing.', jsonb_array_length(v_missing)),
            jsonb_build_object('missing', v_missing));
    END IF;

    -- player has every required item
    UPDATE players SET completed_at = now() WHERE player_id = p_player_id;
    PERFORM fn_log_action(p_player_id, 'Complete Game', 'Player finished the game');

    RETURN fn_result(p_player_id, TRUE,
        'You have everything you need to launch! Time to leave this strange planet. Game over.',
        jsonb_build_object('stats', fn_mission_stats(p_player_id)));
END;
$$;

/*======================================================================
  4.6 usp_restart_game(player_id)
  -- empties the inventory and returns the player to the start location
  -- the action_log history is kept
======================================================================*/

CREATE OR REPLACE FUNCTION usp_restart_game(p_player_id INT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM players WHERE player_id = p_player_id) THEN
        RETURN fn_result(p_player_id, FALSE, 'Player not found.');
    END IF;

    DELETE FROM inventory WHERE player_id = p_player_id;

    UPDATE players
    SET current_location_id = (SELECT location_id FROM locations WHERE is_start),
        completed_at = NULL
    WHERE player_id = p_player_id;

    PERFORM fn_log_action(p_player_id, 'Restart Game', 'Player restarted the mission');

    RETURN fn_result(p_player_id, TRUE, 'Mission restarted. You come to beside the wreckage of your ship...');
END;
$$;
