// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./Consts.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract KingOfTheCastle is AccessControl {

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant WHITELIST_ROLE = keccak256("WHITELIST_ROLE");
	
    struct Army {
        uint256 archers;
        uint256 infantry;
        uint256 cavalry;
    }

    struct Castle {
        Army defense;
        address currentKing;
        uint256 lastKingChangedAt;
    }

    struct Player {
        string generalName;
        Army attackingArmy;
        uint256 points;
        uint256 turns;
    }

    struct GameState {
        mapping(address => Player) players;
        uint256 numberOfAttacks;
        Castle castle;
    }

    GameState public gameState;
    uint256 public lastTickTock;
    address public immutable owner;
    address[] public playerAddresses;

    event PlayerJoined(address player, string generalName);
    event ArmyMobilized(address player, uint256 archers, uint256 infantry, uint256 cavalry);
    event AttackLaunched(address attacker, address defender, bool success);
    event DefenseChanged(address king, uint256 archers, uint256 infantry, uint256 cavalry);
    event TurnAdded(address player, uint256 newTurns);
    event Whitelist(address to);

    constructor() {
        owner = msg.sender;
        lastTickTock = block.timestamp;
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(MANAGER_ROLE, owner);
        initializeGame();
    }

    function initializeGame() private {
        gameState.castle.defense = Army(Consts.INITIAL_ARMY_SIZE, Consts.INITIAL_ARMY_SIZE, Consts.INITIAL_ARMY_SIZE);
        gameState.castle.currentKing = owner;
        gameState.castle.lastKingChangedAt = block.timestamp;

        // Initialize the owner as the first player
        gameState.players[owner] = Player("Castle Owner", Army(Consts.INITIAL_ARMY_SIZE, Consts.INITIAL_ARMY_SIZE, Consts.INITIAL_ARMY_SIZE), Consts.INITIAL_POINTS, Consts.INITIAL_TURNS);
        playerAddresses.push(owner);
    }

    // Public functions for the game

    // Only Whitelisted users can join the game, because they need to have some SFUEL to play the game
    function joinGame(string memory generalName) external {
        require(bytes(gameState.players[msg.sender].generalName).length == 0, "Player has already joined");
        gameState.players[msg.sender] = Player(
            generalName,
            Army(Consts.INITIAL_ARMY_SIZE, Consts.INITIAL_ARMY_SIZE, Consts.INITIAL_ARMY_SIZE),
            Consts.INITIAL_POINTS,
            Consts.INITIAL_TURNS
        );
        playerAddresses.push(msg.sender);

        // Remove the Whitelist role after the user has joined the game
        // make sure they do not get SFUEL again
        _revokeRole(WHITELIST_ROLE, msg.sender);
        emit PlayerJoined(msg.sender, generalName);
    }

    function mobilize(uint256 archers, uint256 infantry, uint256 cavalry) external {
        Player storage player = gameState.players[msg.sender];
        require(player.turns > 0, "Player has not joined the game");
        require(player.turns >= Consts.TURNS_NEEDED_FOR_MOBILIZE, "Not enough turns");
        require(archers + infantry + cavalry <= Consts.MAX_ATTACK, "Army size exceeds maximum");

        player.attackingArmy = Army(archers, infantry, cavalry);
        player.turns -= Consts.TURNS_NEEDED_FOR_MOBILIZE;

        emit ArmyMobilized(msg.sender, archers, infantry, cavalry);
    }

    function attack() external {
        Player storage attacker = gameState.players[msg.sender];
        require(attacker.turns > 0, "Attacker has not joined the game");
        require(msg.sender != gameState.castle.currentKing, "Current king cannot attack");
        require(attacker.turns >= Consts.TURNS_NEEDED_FOR_ATTACK, "Not enough turns");
        require(block.timestamp >= gameState.castle.lastKingChangedAt + Consts.ATTACK_COOLDOWN, "Castle is under protection");

        bool attackSuccess = calculateBattleOutcome(attacker.attackingArmy, gameState.castle.defense);

        if (attackSuccess) {
            gameState.castle.currentKing = msg.sender;
            gameState.castle.lastKingChangedAt = block.timestamp;
            gameState.castle.defense = Army(Consts.INITIAL_ARMY_SIZE, Consts.INITIAL_ARMY_SIZE, Consts.INITIAL_ARMY_SIZE);
            attacker.points += Consts.POINTS_FOR_ATTACK_WIN;
        }

        attacker.turns -= Consts.TURNS_NEEDED_FOR_ATTACK;
        gameState.numberOfAttacks++;

        emit AttackLaunched(msg.sender, gameState.castle.currentKing, attackSuccess);
    }

    function changeDefense(uint256 archers, uint256 infantry, uint256 cavalry) external {
        require(msg.sender == gameState.castle.currentKing, "Only the current king can change defense");
        Player storage king = gameState.players[msg.sender];
        require(king.turns >= Consts.TURNS_NEEDED_FOR_CHANGE_DEFENSE, "Not enough turns");
        require(archers + infantry + cavalry <= Consts.MAX_DEFENSE, "Defense size exceeds maximum");

        gameState.castle.defense = Army(archers, infantry, cavalry);
        king.turns -= Consts.TURNS_NEEDED_FOR_CHANGE_DEFENSE;

        emit DefenseChanged(msg.sender, archers, infantry, cavalry);
    }

    function tickTock() external {
        require(block.timestamp >= lastTickTock + Consts.TURN_INTERVAL, "Too soon to call tickTock");
        
        for (uint i = 0; i < playerAddresses.length; i++) {
            Player storage player = gameState.players[playerAddresses[i]];
            if (player.turns < Consts.MAX_TURNS) {
                player.turns++;
                emit TurnAdded(playerAddresses[i], player.turns);
            }
        }

        if (gameState.players[gameState.castle.currentKing].points < type(uint256).max) {
            gameState.players[gameState.castle.currentKing].points += Consts.POINTS_PER_TURN_FOR_KING;
        }

        lastTickTock = block.timestamp;
    }

    // view functions for the game

    function getPlayerCount() public view returns (uint256) {
        return playerAddresses.length;
    }

    function getCastle() public view returns (Castle memory) {
        return gameState.castle;
    }

    function getPlayer(address playerAddress) public view returns (Player memory) {
        return gameState.players[playerAddress];
    }

    // To be Gasless, we whitelist users - to send them SFUEL, so that before they can play the game, they can get some SFUEL
    function whitelist(address to) external onlyRole(MANAGER_ROLE) {
        require(!hasRole(WHITELIST_ROLE, to), "AlreadyWhitelisted");

        if(to.balance < 0.000005 ether){
            require(address(this).balance >= Consts.SFUEL_DISTRIBUTION_AMOUNT, "ContractOutOfSFuel");
            payable(to).transfer(Consts.SFUEL_DISTRIBUTION_AMOUNT);
            emit Whitelist(to);
        }
        _grantRole(WHITELIST_ROLE, to);

    }

    // Internal functions for the game
    function getRandom() private view returns (bytes32 addr) {
        assembly {
            let freemem := mload(0x40)
            let start_addr := add(freemem, 0)
            if iszero(staticcall(gas(), 0x18, 0, 0, start_addr, 32)) {
              invalid()
            }
            addr := mload(freemem)
        }
    }

    // returns a random number between 1 and max
    function getRandomNumber(uint256 max) private view returns (uint256) {
        uint256 number =  uint256(getRandom()) % max;
        return number == 0 ? 1 : number;
    }

    function calculateBattleOutcome(Army memory attackingArmy, Army memory defendingArmy) private view returns (bool) {
        // Stage 1: Cavalry vs Cavalry
        uint256 attackingCavalryRemaining = attackingArmy.cavalry;
        uint256 defendingCavalryRemaining = defendingArmy.cavalry;
        bool attackerWonCavalry = false;

        if (attackingArmy.cavalry > 0 || defendingArmy.cavalry > 0) {
            uint256 winningCavalry = cavalryBattle(attackingArmy.cavalry, defendingArmy.cavalry);
            attackerWonCavalry = attackingArmy.cavalry > defendingArmy.cavalry;
            if (attackerWonCavalry) {
                attackingCavalryRemaining = winningCavalry;
                defendingCavalryRemaining = 0;
            } else {
                attackingCavalryRemaining = 0;
                defendingCavalryRemaining = winningCavalry;
            }
        }

        // Stage 2: Archers firing on advancing infantry
        uint256 attackingInfantryRemaining = archerVolley(defendingArmy.archers, attackingArmy.infantry);
        uint256 defendingInfantryRemaining = defendingArmy.infantry; // Defending infantry doesn't advance, so no archer volley

        // Stage 3: Infantry vs Infantry
        if (attackingInfantryRemaining > 0 && defendingInfantryRemaining > 0) {
            (attackingInfantryRemaining, defendingInfantryRemaining) = infantryBattle(
                attackingInfantryRemaining, 
                defendingInfantryRemaining
            );
        }

        // Stage 4: Winning cavalry hitting archers and remaining infantry
        uint256 attackingArchersRemaining = attackingArmy.archers;
        uint256 defendingArchersRemaining = defendingArmy.archers;

        if (attackerWonCavalry && attackingCavalryRemaining > 0) {
            // Attacker's cavalry attacks defender's archers and infantry
            (defendingArchersRemaining, defendingInfantryRemaining) = cavalryCleanup(
                attackingCavalryRemaining, 
                defendingArchersRemaining, 
                defendingInfantryRemaining
            );
        } else if (!attackerWonCavalry && defendingCavalryRemaining > 0) {
            // Defender's cavalry attacks attacker's archers and remaining infantry
            (attackingArchersRemaining, attackingInfantryRemaining) = cavalryCleanup(
                defendingCavalryRemaining, 
                attackingArchersRemaining, 
                attackingInfantryRemaining
            );
        }

        // Calculate total remaining troops
        uint256 totalAttackerRemaining = attackingCavalryRemaining + 
                                        attackingInfantryRemaining + 
                                        attackingArchersRemaining;

        uint256 totalDefenderRemaining = defendingCavalryRemaining + 
                                        defendingInfantryRemaining + 
                                        defendingArchersRemaining;

        // Attacker wins if they have more troops remaining
        return totalAttackerRemaining > totalDefenderRemaining;
    }

    function cavalryBattle(uint256 attackingCavalry, uint256 defendingCavalry) private pure returns (uint256) {
        uint256 attackingHealth = attackingCavalry * Consts.CAVALRY_HEALTH;
        uint256 defendingHealth = defendingCavalry * Consts.CAVALRY_HEALTH;
        
        while (attackingHealth > 0 && defendingHealth > 0) {
            defendingHealth -= attackingCavalry * Consts.CAVALRY_ATTACK;
            if (defendingHealth > 0) {
                attackingHealth -= defendingCavalry * Consts.CAVALRY_ATTACK;
            }
        }

        return attackingHealth > 0 ? attackingHealth / Consts.CAVALRY_HEALTH : defendingHealth / Consts.CAVALRY_HEALTH;
    }

    function archerVolley(uint256 archers, uint256 targetInfantry) private view returns (uint256) {
        uint256 infantryHealth = targetInfantry * Consts.INFANTRY_HEALTH;
        uint256 volleys = Consts.DISTANCE_TO_CASTLE / Consts.INFANTRY_SPEED;

        for (uint i = 0; i < volleys; i++) {
            // adding randomness to the archer attack
            // archers have a upto 5% chance of hitting
            uint256 random_damage_factor  = getRandomNumber(6); 
            uint256 damage = archers * Consts.ARCHER_ATTACK * random_damage_factor/100;
            if (damage >= infantryHealth) {
                return 0; // All infantry killed
            }
            infantryHealth -= damage;
        }

        return infantryHealth / Consts.INFANTRY_HEALTH; // Return remaining infantry
    }

    function infantryBattle(uint256 attackingInfantry, uint256 defendingInfantry) private view returns (uint256, uint256) {
        uint256 attackingHealth = attackingInfantry * Consts.INFANTRY_HEALTH;
        uint256 defendingHealth = defendingInfantry * Consts.INFANTRY_HEALTH;

        uint256 attackingAttack = attackingInfantry * Consts.INFANTRY_ATTACK;
        uint256 defendingAttack = defendingInfantry * Consts.INFANTRY_ATTACK;

        // adding randomness to the attack
        // not all attacks are lethal, upto 20% attack can hit, rest are blocked by shields
        uint256 attacker_effective_attack = getRandomNumber(attackingAttack/20);
        uint256 defender_effective_attack = getRandomNumber(defendingAttack/20);

        attackingHealth -= defender_effective_attack;
        defendingHealth -= attacker_effective_attack;

        return (
            attackingHealth > 0 ? attackingHealth / Consts.INFANTRY_HEALTH : 0,
            defendingHealth > 0 ? defendingHealth / Consts.INFANTRY_HEALTH : 0
        );
    }

    function cavalryCleanup(uint256 cavalry, uint256 archers, uint256 infantry) private view returns (uint256, uint256) {
        uint256 cavalryHealth = cavalry * Consts.CAVALRY_HEALTH;
        uint256 archerHealth = archers * Consts.ARCHER_HEALTH;
        uint256 infantryHealth = infantry * Consts.INFANTRY_HEALTH;

        // While loop to simulate cavalry attacking archers first, then infantry
        // not possible in a non performant chain
        while (cavalryHealth > 0 && (archerHealth > 0 || infantryHealth > 0)) {

            // add randomness to the attack
            // cavalry can hit upto 30% of the time
            uint256 random_cavalry_damage_factor  = getRandomNumber(31);
            // archers have a upto 5% chance of hitting cavalry
            uint256 random_archer_damage_factor  = getRandomNumber(6);
            // infantry have a upto 30% chance of hitting cavalry
            uint256 random_infantry_damage_factor  = getRandomNumber(31);

            // Cavalry attacks archers first
            uint256 effCavalryDamage = (cavalry * Consts.CAVALRY_ATTACK * random_cavalry_damage_factor)/100;
            if (archerHealth > 0) {
                if (effCavalryDamage >= archerHealth) {
                    effCavalryDamage -= archerHealth;
                    archerHealth = 0;
                    // Remaining damage goes to infantry
                    infantryHealth = infantryHealth > effCavalryDamage ? infantryHealth - effCavalryDamage : 0;
                } else {
                    archerHealth -= effCavalryDamage;
                }
            } else {
                // If no archers left, attack infantry
                infantryHealth = infantryHealth > effCavalryDamage ? infantryHealth - effCavalryDamage : 0;
            }

            // Archers and infantry counterattack
            uint256 effArcherDamage = (archers * Consts.ARCHER_ATTACK * random_archer_damage_factor)/100;
            uint256 effInfantryDamage = (infantry * Consts.INFANTRY_ATTACK * random_infantry_damage_factor)/100;
            uint256 counterDamage = effArcherDamage + effInfantryDamage;
            cavalryHealth = cavalryHealth > counterDamage ? cavalryHealth - counterDamage : 0;

            // Update troop numbers
            cavalry = cavalryHealth / Consts.CAVALRY_HEALTH;
            archers = archerHealth / Consts.ARCHER_HEALTH;
            infantry = infantryHealth / Consts.INFANTRY_HEALTH;
        }

        return (archers, infantry);
    }

}