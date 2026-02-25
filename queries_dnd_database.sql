-- Here follows all queries used to setup the databse and test its functionality

-- *************************************************
-- Creating the database in MySQL activate it

CREATE DATABASE dnd_campaign;

USE dnd_campaign;


-- *************************************************
-- Creation of tables and populating with data


CREATE TABLE Classes (
    class VARCHAR(15) NOT NULL,
    skill VARCHAR(25) NOT NULL,
    baseHealth SMALLINT NOT NULL,

    PRIMARY KEY (class)
);


CREATE TABLE Party (
    memberID SMALLINT NOT NULL AUTO_INCREMENT,
    name VARCHAR(25) NOT NULL,
    class VARCHAR(15) NOT NULL, 
    health SMALLINT DEFAULT NULL,
    level SMALLINT NOT NULL DEFAULT 1, 

    PRIMARY KEY (memberID),
    FOREIGN KEY (class) REFERENCES Classes(class)
);

CREATE TABLE LevelSpells (
    class VARCHAR(15) NOT NULL, 
    level SMALLINT NOT NULL, 
    spell VARCHAR(25) NOT NULL, 
    damage SMALLINT,

    CONSTRAINT levelspell PRIMARY KEY (class, level),
    FOREIGN KEY (class) REFERENCES Classes(class)
);


CREATE TABLE Enemies (
    enemyEncounter SMALLINT NOT NULL AUTO_INCREMENT,
    type VARCHAR(25) NOT NULL,
    health SMALLINT NOT NULL, 
    killedBy SMALLINT DEFAULT NULL,

    PRIMARY KEY (enemyEncounter),
    FOREIGN KEY (killedBy) REFERENCES Party(memberID)
);


INSERT INTO Classes(class, skill, baseHealth)
VALUES 
('Wizard', 'Intelligence', 80),
('Ranger', 'Stealth', 110),
('Bard', 'Charisma', 100);

INSERT INTO Party(memberID, name, class)
VALUES 
(1, 'John', 'Wizard'),
(2, 'Hilda', 'Bard'),
(3, 'Ania', 'Ranger');

INSERT INTO LevelSpells(class, level, spell, damage)
VALUES 
('Wizard', 1,'Fireball', 25),
('Wizard', 2,'Ice Shard', 30),
('Wizard', 3,'Teleportation', 20),
('Bard', 1,'Sleep', 20),
('Bard', 2,'Ice Shard', 30),
('Bard', 3,'Friendship', 40),
('Ranger', 1,'Sneak Attack', 25),
('Ranger', 2,'Fireball', 25),
('Ranger', 3,'Explosive Arrow', 45);

INSERT INTO Enemies(enemyEncounter, type, health, killedBy)
VALUES 
(1, "Zombie", 50, NULL),
(2, "Skeleton", 40, NULL),
(3, "Zombie", 50, NULL),
(4, "Evil Name Wizard", 80, NULL),
(5, "Cat", 100, NULL);



-- *************************************************
-- functions, triggers, procedures, views
-- Queries that creates and stores in the database


-- Trigger for updating health attribute on a new party member
DROP TRIGGER IF EXISTS update_new_party_member;
DELIMITER ##
CREATE TRIGGER update_new_party_member
BEFORE INSERT 
ON Party FOR EACH ROW 
BEGIN 
    DECLARE bhealth SMALLINT;
    SELECT baseHealth INTO bhealth FROM Classes WHERE NEW.class = Classes.class;
    SET NEW.health = bhealth;
END; ##
DELIMITER ;


SET @bhealth = 0;
SELECT baseHealth INTO @bhealth FROM Classes WHERE "Wizard" = Classes.class;
SELECT @bhealth;



-- Create view of the statistics of the party members 
DROP VIEW IF EXISTS PartyStats;
CREATE VIEW PartyStats AS 
SELECT memberID, name, Party.class, Party.health, level, Classes.skill, COUNT(killedBy) AS killcounter 
FROM Party
LEFT JOIN Enemies ON memberID = killedBy
INNER JOIN Classes ON Party.class = Classes.class
GROUP BY memberID;

SELECT * FROM PartyStats;




-- Create view of game statistics sorted by the different classes
DROP VIEW IF EXISTS GameStats;
CREATE VIEW GameStats AS
SELECT class, 
COUNT(class) AS NrMembersOfClass, 
COUNT(killedBy) AS TotalEnemiesKilled,
COUNT(IF (Party.health = 0, 1, NULL)) AS NrCharactersDead
FROM Party 
LEFT JOIN Enemies ON memberID = killedBy
GROUP BY Party.class;

SELECT * FROM GameStats;




-- Procedure that shows available spells a party member can use
DROP PROCEDURE IF EXISTS check_available_spells;
DELIMITER ##
CREATE PROCEDURE check_available_spells(IN memid SMALLINT)
BEGIN 
    DECLARE myclass VARCHAR(15);
    DECLARE mylevel SMALLINT;
    SELECT class INTO myclass FROM Party WHERE memid = memberID;
    SELECT level INTO mylevel FROM Party WHERE memid = memberID;
    SELECT * FROM LevelSpells WHERE myclass = LevelSpells.class 
    AND mylevel >= LevelSpells.level;
END; ##
DELIMITER ;

CALL check_available_spells(1);



-- Procedure that is run after the player's turn, updating enemy health and level
DROP PROCEDURE IF EXISTS end_player_turn;
DELIMITER ##
CREATE PROCEDURE end_player_turn(IN memid SMALLINT, IN enemyid SMALLINT, IN usedspell VARCHAR(25))
BEGIN
    DECLARE enemy_health SMALLINT;
    DECLARE dealt_damage SMALLINT;

    SELECT damage INTO dealt_damage FROM LevelSpells
    INNER JOIN Party 
    ON Party.class = LevelSpells.class
    WHERE memid = Party.memberID
    AND LevelSpells.spell = usedspell;

    SELECT health INTO enemy_health FROM Enemies WHERE enemyid = enemyEncounter;

    SET enemy_health = enemy_health - dealt_damage;

    IF (enemy_health <= 0)
    THEN
        UPDATE Enemies SET killedBy = memid, health = 0 WHERE enemyid = enemyEncounter;
        UPDATE Party SET level = level + 1 WHERE memid = memberID;
    ELSE
        UPDATE Enemies SET health = enemy_health WHERE enemyid = enemyEncounter;
    END IF;
END; ##
DELIMITER ;


UPDATE Enemies SET killedBy = Null WHERE enemyEncounter = 1;
SELECT * FROM Enemies;
SELECT * FROM Party;
UPDATE Party SET level = 1 WHERE memberID = 1;
UPDATE Enemies SET health = health - 25 WHERE enemyEncounter = 1;
CALL end_player_turn(1, 1);


-- Procedure that is run after every enemy's turn, updating player health
DROP PROCEDURE IF EXISTS end_enemy_turn;
DELIMITER ##
CREATE PROCEDURE end_enemy_turn(IN enemynr SMALLINT, IN memid SMALLINT, IN hitSucessful BOOLEAN)
BEGIN 
    IF (hitSucessful)
    THEN 
        UPDATE Party SET health = health - 10 WHERE memid = memberID;
    END IF;
END; ##
DELIMITER ; 



-- Function that returns the next alive enemy to fight 
DROP FUNCTION IF EXISTS get_next_enemy;
DELIMITER ##
CREATE FUNCTION get_next_enemy()
RETURNS SMALLINT READS SQL DATA 
BEGIN
    DECLARE next_encounter SMALLINT;

    SELECT enemyEncounter 
    INTO next_encounter
    FROM Enemies
    WHERE killedBy IS NULL
    ORDER BY enemyEncounter
    LIMIT 1;

    RETURN next_encounter;
END; ## 
DELIMITER ;

SELECT get_next_enemy();






-- ********************************************
-- Queries used in the Python script file: 'dnd_script.py'

-- Main
SELECT memberID, name, class FROM Party;

-- Character creation
SELECT class from Classes;
INSERT INTO Party(name, class) VALUES(myname, myclass);

-- Adventure loop
SELECT health FROM Party WHERE {playerID} = memberID;
SELECT get_next_enemy();
SELECT * FROM PartyStats;
SELECT * FROM GameStats;
SELECT type FROM Enemies WHERE {enemyID} = enemyEncounter;

-- Battle loop
SELECT enemyEncounter, type, health FROM Enemies WHERE {enemyID} = enemyEncounter;
SELECT health FROM Party WHERE {playerID} = memberID;
SELECT health FROM Enemies WHERE {enemyID} = enemyEncounter;
CALL check_available_spells(playerID);
CALL end_player_turn(playerID, enemyID, spell_choice);
CALL end_enemy_turn(enemyID, playerID, enemy_hits);


-- Battle name wizard
SELECT enemyEncounter, type, health FROM Enemies WHERE {enemyID} = enemyEncounter;
UPDATE Party SET name = "Juan" WHERE memberID = {playerID};
UPDATE Enemies SET killedBy = {playerID} WHERE enemyEncounter = {enemyID};

-- ************************************************************************

