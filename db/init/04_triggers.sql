/**********************************************************************
  Starship Command v2.0 (PostgreSQL)
  04 Triggers

  SECTION 5: Triggers
  - trg_players_move_log:   logs moves when players.current_location_id changes
  - trg_inventory_audit:    logs pickups/drops when inventory changes
  - trg_inventory_validate: enforces is_pickable and quantity <= 1
**********************************************************************/

-- 1 trg_players_move_log
-- log moves when a player's current_location_id changes
CREATE OR REPLACE FUNCTION fn_trg_players_move_log()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO action_log (player_id, action_location, player_action, details)
    SELECT NEW.player_id,
           NEW.current_location_id,
           'Move Player',
           format('Player moved from %s to %s (trigger)', lf.location_name, lt.location_name)
    FROM locations lf, locations lt
    WHERE lf.location_id = OLD.current_location_id
      AND lt.location_id = NEW.current_location_id;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_players_move_log
AFTER UPDATE OF current_location_id ON players
FOR EACH ROW
WHEN (OLD.current_location_id IS DISTINCT FROM NEW.current_location_id)
EXECUTE FUNCTION fn_trg_players_move_log();

-- 2 trg_inventory_audit
-- audit pickups/drops on inventory changes
CREATE OR REPLACE FUNCTION fn_trg_inventory_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO action_log (player_id, action_location, player_action, details)
        SELECT NEW.player_id,
               p.current_location_id,
               'Pick Up Item',
               format('Player picked up %s (trigger). Qty=%s', it.item_name, NEW.quantity)
        FROM players p, items it
        WHERE p.player_id = NEW.player_id
          AND it.item_id = NEW.item_id;
    ELSE
        INSERT INTO action_log (player_id, action_location, player_action, details)
        SELECT OLD.player_id,
               p.current_location_id,
               'Drop Item',
               format('Player dropped %s (trigger). Qty=%s', it.item_name, OLD.quantity)
        FROM players p, items it
        WHERE p.player_id = OLD.player_id
          AND it.item_id = OLD.item_id;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_inventory_audit
AFTER INSERT OR DELETE ON inventory
FOR EACH ROW
EXECUTE FUNCTION fn_trg_inventory_audit();

-- 3 trg_inventory_validate
-- enforce inventory business rules (pickable only, quantity <= 1)
-- runs BEFORE the write, so bad rows are rejected or corrected up front
CREATE OR REPLACE FUNCTION fn_trg_inventory_validate()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- deny unpickable items
    IF EXISTS (SELECT 1 FROM items WHERE item_id = NEW.item_id AND NOT is_pickable) THEN
        RAISE EXCEPTION 'Cannot pick up this item (is_pickable = false).';
    END IF;

    -- normalize quantity to 1 (v1.0 rule)
    IF NEW.quantity > 1 THEN
        NEW.quantity := 1;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_inventory_validate
BEFORE INSERT OR UPDATE ON inventory
FOR EACH ROW
EXECUTE FUNCTION fn_trg_inventory_validate();
