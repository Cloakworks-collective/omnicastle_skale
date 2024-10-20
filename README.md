**Deployed Contract** : 0x18975871ab7E57e0f26fdF429592238541051Fb0
**Network**: Nebula Testnet

# Omni Castles Smart Contract Documentation

## Overview
The **Omni Castles** smart contract is designed for a multiplayer game where players compete to capture and hold a castle in a King of the Hill scenario. The castle changes hands based on successful attacks, and players earn points for holding it. The game involves managing armies, deploying attacks, and strategically defending the castle.

## Main Features

**Gasless**

The Omni Castles smart contract enables gasless transactions by distributing sFuel to whitelisted players, covering approximately 10,000 transactions. When a player is whitelisted, the contract checks their sFuel balance and, if needed, automatically transfers enough for them to participate without incurring gas fees. Once the player joins, their Whitelist Role is revoked to prevent further sFuel distribution, ensuring a sustainable gasless system while simplifying onboarding and gameplay. This allows players to focus on the game without managing gas costs.

```solidity
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
```


**Use of Randomness**

We use the native skale randomness to enhance the battle strategies

```solidity
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
 ```   

 We use the `getRandomNumber()` function to simulate uncertainties of battle throughout our contracts.


**Non Trivial Battle**

We also have non-trivial battle calculations compared to other castles.
e.g. a while loop calculation in `cavalryCleanup()` is not possible in other chains.

You can see the difference in battle calculation for another chain - https://github.com/Cloakworks-collective/omnicastle_airdao/blob/main/packages/foundry/contracts/KingOfTheCastle.sol#L187


## Key Concepts

- **Castle**: The central point of the game, defended by the current king. The goal is to attack the castle, defeat its defense, and take over as the new king.
- **King**: The player currently holding the castle, responsible for defending it with an army. The king earns points each turn they maintain control.
- **Army**: Each player has an army composed of archers, infantry, and cavalry, which they use for attacking and defending.
- **Turns**: Players have a limited number of turns to take actions like mobilizing their army or launching an attack.
- **Points**: Players accumulate points by successfully attacking the castle and for each turn they hold the castle as king.

## Game Structures

- **Army**: Composed of archers, infantry, and cavalry.
- **Castle**: Has a defense army and tracks the current king and the last time the king was changed.
- **Player**: Each player has a name, an attacking army, points, and turns.

## Key Functions

- **`joinGame(string memory generalName)`**: Allows a new player to join the game. Players must be whitelisted and receive SFUEL for their first game.
- **`mobilize(uint256 archers, uint256 infantry, uint256 cavalry)`**: Allows players to mobilize their army. Players must have enough turns to mobilize, and the army size must not exceed the maximum allowed for an attack.
- **`attack()`**: Executes an attack on the castle. The attack's outcome is calculated based on the armies' compositions and random factors. If successful, the attacker becomes the new king.
- **`changeDefense(uint256 archers, uint256 infantry, uint256 cavalry)`**: The king can change the composition of the castle's defending army using their turns.
- **`tickTock()`**: Increases each player's turns and adds points to the current king after a time interval.

## Events

- **`PlayerJoined`**: Emitted when a player joins the game.
- **`ArmyMobilized`**: Emitted when a player mobilizes their army.
- **`AttackLaunched`**: Emitted when an attack is launched.
- **`DefenseChanged`**: Emitted when the king changes the castle's defense.
- **`TurnAdded`**: Emitted when players receive additional turns.
- **`Whitelist`**: Emitted when a player is whitelisted and receives SFUEL.

## Randomness and Battle Outcomes

The contract uses randomness in battle outcomes, including cavalry battles, archer volleys, and infantry combat. The army's performance in each battle stage depends on the army's composition and random factors.

## Access Control

- **Manager Role**: Manages the game's whitelist and SFUEL distribution.
- **Whitelist Role**: Allows new players to join the game.

This contract represents the core game mechanics of **Omni Castles**, where strategic army management and attacking at the right time are crucial to becoming and staying the king.