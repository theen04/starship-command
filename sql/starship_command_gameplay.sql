/**********************************************************************
  IST-657: Database Administration and Concepts
  Final Project (Summer 2025) - Team 1
  Jeong Hwan Son, Darrell Collison, Tristan Morlock, Robert Nitto
  Date: 2025-09-14
**********************************************************************/

/**********************************************************************
  Starship Command v1.1
  Gameplay Script
  -- each player starts at the Crash Site
  -- explore 4 locations to find 4 items needed to fix your ship
  -- navigate back to the Crash Site, fix your ship and relaunch
**********************************************************************/
-- Load database game
USE starship_command
GO

-- look around crash site
EXEC usp_lookaround @player_id = 1
GO

-- optionally, try and complete the game without having requried items
-- hints help the player find the item
EXEC usp_completeGame @player_id = 1

/**********************************************************************
  Explore the East Location 
**********************************************************************/
-- Navigate from Crash Site to the East
EXEC usp_MovePlayer @player_id = 1, @direction = 'east';
EXEC usp_lookaround @player_id = 1

-- demonstrate usp_completeGame messaging (return to crash site to install parts)
EXEC usp_completeGame @player_id = 1

-- explore forward
EXEC usp_MovePlayer @player_id = 1, @direction = 'forward';
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';

-- explore left
EXEC usp_MovePlayer @player_id = 1, @direction = 'left';
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';

-- right location has the item
-- the item and item_id are returned in the results of the procedure
EXEC usp_MovePlayer @player_id = 1, @direction = 'right';

-- pick up item, use the item_id from the item you see in the location
EXEC usp_pickUpItem @player_id = 1, @item_id = 1

-- navigate back to the East Location
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';

-- navigate back to the Crash Site
EXEC usp_MovePlayer @player_id = 1, @direction = 'west';

/**********************************************************************
  Explore West 
**********************************************************************/
-- Navigate from Crash Site to the West
EXEC usp_MovePlayer @player_id = 1, @direction = 'west';
EXEC usp_lookaround @player_id = 1

-- explore forward
EXEC usp_MovePlayer @player_id = 1, @direction = 'forward';
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';

-- explore right
EXEC usp_MovePlayer @player_id = 1, @direction = 'right';
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';

-- left location has the item
EXEC usp_MovePlayer @player_id = 1, @direction = 'left';

-- pick up item, use the item_id from the item you see in the location
EXEC usp_pickUpItem @player_id = 1, @item_id = 2

-- navigate back to East Location
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';

-- navigate back to Crash Site
EXEC usp_MovePlayer @player_id = 1, @direction = 'east';

/**********************************************************************
  Explore North 
**********************************************************************/
-- Navigate from Crash Site to the North
EXEC usp_MovePlayer @player_id = 1, @direction = 'north';
EXEC usp_lookaround @player_id = 1

-- explore forward
EXEC usp_MovePlayer @player_id = 1, @direction = 'forward';
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';

-- explore left
EXEC usp_MovePlayer @player_id = 1, @direction = 'left';
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';

-- right location has the item
EXEC usp_MovePlayer @player_id = 1, @direction = 'right';

-- pick up item, use the item_id from the item you see in the location
EXEC usp_pickUpItem @player_id = 1, @item_id = 3

-- navigate back to North Location
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';

-- navigate back to Crash Site
EXEC usp_MovePlayer @player_id = 1, @direction = 'south';

/**********************************************************************
  Explore South 
**********************************************************************/
-- Navigate from Crash Site to the South
EXEC usp_MovePlayer @player_id = 1, @direction = 'south';
EXEC usp_lookaround @player_id = 1

-- explore forward
EXEC usp_MovePlayer @player_id = 1, @direction = 'forward';
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';

-- explore right
EXEC usp_MovePlayer @player_id = 1, @direction = 'right';
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';

-- left location has the item
EXEC usp_MovePlayer @player_id = 1, @direction = 'left';

-- pick up item, use the item_id from the item you see in the location
EXEC usp_pickUpItem @player_id = 1, @item_id = 4

-- navigate back to South Location
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';

-- navigate back to Crash Site
EXEC usp_MovePlayer @player_id = 1, @direction = 'north';

/**********************************************************************
  Complete the Game
  Notes about completing the game
  -- if you are not at the Crash Site, a message will instruct you to return
  -- you must have all 4 items AND be at the Crash Site in order to win
  -- if you are missing 1 or more items,
  -- usp_completeGame will return a table with hints for each missing item
**********************************************************************/

-- complete the game
EXEC usp_completeGame @player_id = 1

/*Review action_log to audit each action the player took*/
SELECT * FROM action_log ORDER BY action_time DESC

/**********************************************************************
  Starship Command v1.1
  Speed Run :)
  -- best to run this with a clean database build
  -- otherwise, start from the Crash Site with 0 items
  -- run code between start and end
  -- review action log to audit each step
**********************************************************************/
-- start
-- set database
USE starship_command
GO

-- get east item
EXEC usp_movePlayer @player_id = 1, @direction = 'east';
EXEC usp_movePlayer @player_id = 1, @direction = 'right';
EXEC usp_pickUpItem @player_id = 1, @item_id = 1

-- back to crash site
EXEC usp_movePlayer @player_id = 1, @direction = 'back';
EXEC usp_movePlayer @player_id = 1, @direction = 'west';

-- get west item
EXEC usp_movePlayer @player_id = 1, @direction = 'west';
EXEC usp_movePlayer @player_id = 1, @direction = 'left';
EXEC usp_pickUpItem @player_id = 1, @item_id = 2

-- back to crash site
EXEC usp_movePlayer @player_id = 1, @direction = 'back';
EXEC usp_movePlayer @player_id = 1, @direction = 'east';

-- get north item
EXEC usp_movePlayer @player_id = 1, @direction = 'north';
EXEC usp_movePlayer @player_id = 1, @direction = 'right';
EXEC usp_pickUpItem @player_id = 1, @item_id = 3

-- back to crash site
EXEC usp_movePlayer @player_id = 1, @direction = 'back';
EXEC usp_movePlayer @player_id = 1, @direction = 'south';

-- get south item
EXEC usp_movePlayer @player_id = 1, @direction = 'south';
EXEC usp_MovePlayer @player_id = 1, @direction = 'left';
EXEC usp_pickUpItem @player_id = 1, @item_id = 4;

-- back to crash site
EXEC usp_MovePlayer @player_id = 1, @direction = 'back';
EXEC usp_MovePlayer @player_id = 1, @direction = 'north';

-- complete game
EXEC usp_completeGame @player_id = 1
-- end

/*Review action_log to audit each action the player took*/
SELECT * FROM action_log ORDER BY action_time DESC





