/**********************************************************************
  Starship Command v2.0 (PostgreSQL)
  Gameplay Script (speed run)

  Plays the whole game as Player One (player_id = 1) from psql:
    docker compose exec -T db psql -U starship -d starship_command < db/gameplay_demo.sql

  -- each player starts at the Crash Site
  -- explore 4 locations to find 4 items needed to fix your ship
  -- navigate back to the Crash Site, fix your ship and relaunch
  -- every function returns JSON: { ok, message, state }
**********************************************************************/

-- start from the Crash Site with an empty inventory
SELECT usp_restart_game(1) ->> 'message' AS restart;

-- look around crash site
SELECT jsonb_pretty(usp_look_around(1));

-- optionally, try and complete the game without the required items
-- "missing" lists each item with a hint
SELECT jsonb_pretty(usp_complete_game(1) - 'state');

-- get east item
SELECT usp_move_player(1, 'east')  ->> 'message' AS east;
SELECT usp_move_player(1, 'right') ->> 'message' AS east;
SELECT usp_pick_up_item(1, (SELECT item_id FROM items WHERE item_name = 'Nav Beacon Core')) ->> 'message' AS pick_up;

-- back to crash site
SELECT usp_move_player(1, 'back') ->> 'message' AS back;
SELECT usp_move_player(1, 'west') ->> 'message' AS back;

-- get west item
SELECT usp_move_player(1, 'west') ->> 'message' AS west;
SELECT usp_move_player(1, 'left') ->> 'message' AS west;
SELECT usp_pick_up_item(1, (SELECT item_id FROM items WHERE item_name = 'Electronics Control Unit')) ->> 'message' AS pick_up;

-- back to crash site
SELECT usp_move_player(1, 'back') ->> 'message' AS back;
SELECT usp_move_player(1, 'east') ->> 'message' AS back;

-- get north item
SELECT usp_move_player(1, 'north') ->> 'message' AS north;
SELECT usp_move_player(1, 'right') ->> 'message' AS north;
SELECT usp_pick_up_item(1, (SELECT item_id FROM items WHERE item_name = 'Fuel Cell')) ->> 'message' AS pick_up;

-- back to crash site
SELECT usp_move_player(1, 'back')  ->> 'message' AS back;
SELECT usp_move_player(1, 'south') ->> 'message' AS back;

-- get south item
SELECT usp_move_player(1, 'south') ->> 'message' AS south;
SELECT usp_move_player(1, 'left')  ->> 'message' AS south;
SELECT usp_pick_up_item(1, (SELECT item_id FROM items WHERE item_name = 'Micro-generator')) ->> 'message' AS pick_up;

-- back to crash site
SELECT usp_move_player(1, 'back')  ->> 'message' AS back;
SELECT usp_move_player(1, 'north') ->> 'message' AS back;

-- check inventory
SELECT jsonb_pretty(usp_show_inventory(1) -> 'state' -> 'inventory');

-- complete game
SELECT jsonb_pretty(usp_complete_game(1) - 'state');

/* Review action_log to audit each action the player took */
SELECT log_id, action_time, player_action, details
FROM action_log
WHERE player_id = 1
ORDER BY log_id DESC;
