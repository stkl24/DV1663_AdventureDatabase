import mysql.connector
import random 

# *** database connection ***

def connect_to_mysql(host_name, username, pwd):
    global db
    db = mysql.connector.connect(host=host_name, user=username, password=pwd, database="dnd_campaign")
    return 

def close_connection():
    db.close()
    return

# *** adventure scripting ***


def adventure_loop(playerID):

    player_alive = True
    enemies_exist = True
    adv_cursor = db.cursor()
    available_actions = ["1", "2", "3", "4"]

    while player_alive and enemies_exist:

        # Check if player character is alive
        adv_cursor.execute(f"SELECT health FROM Party WHERE {playerID} = memberID;")
        player_health = adv_cursor.fetchone()

        if player_health[0] <= 0:
            player_alive = False
            print("\n")
            input("Your character has died\n")
            continue
        
        # Check if there are any enemies left
        adv_cursor.execute(f"SELECT get_next_enemy();")
        next_alive_enemy = adv_cursor.fetchone()

        if next_alive_enemy[0] == None:
            enemies_exist = False
            print("\n")
            input("There are no enemies left alive")
            input("Congratulations!")
            continue


        # Let player choose an action 
        input("What do you want to do?")
        print("You can:\n 1. Check party stats\n 2. Check adventure stats\n 3. Fight an enemy\n 4. Exit adventure")
        player_action = input("Please select the number for the action you want to do\n")

        while (player_action not in available_actions):
            player_action = input("Please select the number for the action you want to do\n")

        # Show stats for party
        if player_action == "1":
            print("Showing party statistics:")
            print("MemberID, Name, Class, Health, Level, Skill, Killcounter")

            adv_cursor.execute("SELECT * FROM PartyStats;")
            partystats = adv_cursor.fetchall()

            for x in range(len(partystats)):
                print(partystats[x])
            print("\n")

        # Show game stats
        elif player_action == "2":
            print("Showing game statistics:")
            print("Class, NrMembersOfClass, TotalEnemiesKilled, NrCharactersDead")

            adv_cursor.execute("SELECT * FROM GameStats;")
            gamestats = adv_cursor.fetchall()

            for x in range(len(gamestats)):
                print(gamestats[x])
            print("\n")

        # Enter a battle
        elif player_action == "3":
            adv_cursor.execute("SELECT get_next_enemy();")
            enemyID = adv_cursor.fetchone()
            enemyID = enemyID[0]

            adv_cursor.execute(f"SELECT type FROM Enemies WHERE {enemyID} = enemyEncounter;")
            enemy_type = adv_cursor.fetchall()

            if enemy_type[0][0] == "Evil Name Wizard":
                battle_name_wizard(playerID, enemyID)
            else:
                battle_loop(playerID, enemyID)

        # Exit the game
        elif player_action == "4":
            adv_cursor.close()
            return
        
        
    adv_cursor.close()
    return 


def battle_loop(playerID, enemyID):
    
    bttl_cursor = db.cursor()
    player_alive = True
    enemy_alive = True
    random_hit = [True, False]

    input("You are now fighting an enemy")
    print("\n")

    while (player_alive and enemy_alive):
        
        # Print enemy info
        bttl_cursor.execute(f"SELECT enemyEncounter, type, health FROM Enemies WHERE {enemyID} = enemyEncounter;")
        enemy_info = bttl_cursor.fetchone()

        print("EnemyID, Type, Health")
        print(enemy_info)
        print("\n")

        
        # Check if player still alive
        bttl_cursor.execute(f"SELECT health FROM Party WHERE {playerID} = memberID;")
        player_health = bttl_cursor.fetchone()

        if player_health[0] <= 0:
            player_alive = False
            continue
        
        # Check if enemy still alive
        bttl_cursor.execute(f"SELECT health FROM Enemies WHERE {enemyID} = enemyEncounter;")
        enemy_health = bttl_cursor.fetchone()

        if enemy_health[0] <= 0:
            input("The enemy is dead! Phew")
            enemy_alive = False
            continue
            
        # Action choice, player
        input("It is your turn")
        print("\n")
        print("What spell will you cast?")
        print("You know the following spells:")
        print("Class, Level, Spell, Damage")

        # Check available spells to cast
        bttl_cursor.execute("CALL check_available_spells(%s)", (playerID,))
        available_spells = {}

        # Print all available spells returned from the CALL
        while True:
            spellinfo = bttl_cursor.fetchall()
            for x in spellinfo:
                print(x)
                available_spells.update({x[2]: x[3]})
            if bttl_cursor.nextset() is None:
                break
        
        # Player must make choice of spell to use
        spell_choice = input("Choose a spell you know\n")
        while spell_choice not in available_spells.keys():
            spell_choice = input("Choose a spell you know\n")
        
        input(f"You cast {spell_choice}")
        input("...")
        input(f"It hits the target with {available_spells[spell_choice]} damage")
        input("...")

        bttl_cursor.execute("CALL end_player_turn(%s,%s,%s)", (playerID, enemyID, spell_choice,))
        db.commit()


        # Enemy turn
        # Takes random 50/50 hit or miss
        input("It is the enemy's turn")
        input("It strikes at you with incredible force")
        enemy_hits = random.choice(random_hit)
        
        input("...")
        if enemy_hits:
            input("It hits you and you take 10 damage")
        else:
            input("The enemy misses you. Lucky!")
        
        bttl_cursor.execute("CALL end_enemy_turn(%s,%s,%s)", (enemyID, playerID, enemy_hits,))
        db.commit()

        input("The round is over")
        print("\n")



    input("The battle is now over")
    print("\n")

    bttl_cursor.close()

    return


def battle_name_wizard(playerID, enemyID):
    
    nw_cursor =db.cursor()
    
    input("Oh no!")
    input("You have encountered the Evil Name Wizard!")

    nw_cursor.execute(f"SELECT enemyEncounter, type, health FROM Enemies WHERE {enemyID} = enemyEncounter;")
    enemy_info = nw_cursor.fetchone()

    print("EnemyID, Type, Health")
    print(enemy_info)

    input("This time, the enemy strikes first")
    input("The Evil Name Wizard casts the spell 'Change Name' on you")
    input("It is effective")
    input("...")

    nw_cursor.execute(f"UPDATE Party SET name = 'Juan' WHERE memberID = {playerID};")
    db.commit()

    input("Your name is now Juan")
    input("...")
    input("The Evil Name Wizard disappeared")
    input("Congratulations?")

    nw_cursor.execute(f"UPDATE Enemies SET killedBy = {playerID} WHERE enemyEncounter = {enemyID};")
    db.commit()

    input("The battle is over")


    nw_cursor.close()

    return 


def character_creation():
    # Set a name for new character
    input("You are a new member of a party")

    input("Time to create your character")
    myname = input("What is your name? (max 25 characters)\n")
 
    input("Hello " + myname)

    # Fetch allowed classes to select from
    cursor = db.cursor()
    cursor.execute("SELECT class from Classes;")
    db_classes = cursor.fetchall()
    available_classes = []

    for x in range(len(db_classes)): 
        available_classes.append(db_classes[x][0])

    print("What is your class? You can Choose:\n")

    print(available_classes)

    # Player must choose one class
    myclass = input("")
    while (myclass not in available_classes):
        print("Select class")
        myclass = input("")
    
    input("You are " + myname + " the " + myclass)

    # Add character to database
    add_member = "INSERT INTO Party(name, class) VALUES (%s, %s);"
    new_member = (myname, myclass)

    cursor.execute(add_member, new_member)


    input("Good luck on your adventure")

    db.commit()
    cursor.close()

    return 


def main():
    # Startup connect to database
    # Use your own MySQL credentials!
    host_name = ""
    username = ""
    pwd = ""

    connect_to_mysql(host_name, username, pwd)

    # Start adventure 
    print("***Welcome to the adventure of a lifetime.***")
    input("Press enter to continue")
    input("You and your partymembers are fighting monsters")
    input("Use your spells to attack your enemies, and save the world")

    # New character creation
    new_character_input = input("Do you want to create a new character? (y/n)\n")
    if (new_character_input.casefold() == "y" or new_character_input.casefold() == "yes"): 
        character_creation()
    

    # Select character
    cursor = db.cursor()
    cursor.execute("SELECT memberID, name, class FROM Party")
    db_members = cursor.fetchall()
    cursor.close()
    available_ids = []

    for x in range(len(db_members)):
        available_ids.append(str(db_members[x][0]))

    print("Select the ID of the character you want to be")
    print("Available characters:")

    print(db_members)
    print("Available ID:s for the members")
    print(available_ids)

    playerID = input("")

    while (playerID not in available_ids):
        print("Select the ID of the character you want to be")
        playerID = input()

    playerID = int(playerID)
    print(f"You have ID: ", playerID)

    
    # Begin adventure
    input("Let the adventure begin")
    adventure_loop(playerID)

    # End connection and adventure 
    print("Adventure ends")
    close_connection()

    return


if __name__ == "__main__":
    main()

