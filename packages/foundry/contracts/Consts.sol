// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library Consts {
    uint256 constant INITIAL_ARMY_SIZE = 500;
    uint256 constant INITIAL_POINTS = 0;
    uint256 constant INITIAL_TURNS = 10;
    uint256 constant MAX_ATTACK = 2000;
    uint256 constant MAX_DEFENSE = 1500;
    uint256 constant TURNS_NEEDED_FOR_MOBILIZE = 1;
    uint256 constant TURNS_NEEDED_FOR_ATTACK = 3;
    uint256 constant TURNS_NEEDED_FOR_CHANGE_DEFENSE = 3;
    uint256 constant TURN_INTERVAL = 1 hours;
    uint256 constant ATTACK_COOLDOWN = 1 hours;
    uint256 constant POINTS_FOR_ATTACK_WIN = 100;
    uint256 constant POINTS_PER_TURN_FOR_KING = 10;
    uint256 constant MAX_TURNS = 100;

    // battle design specific
    uint256 constant ARCHER_ATTACK = 20;
    uint256 constant ARCHER_HEALTH = 5;
    uint256 constant INFANTRY_ATTACK = 10;
    uint256 constant INFANTRY_HEALTH = 10;
    uint256 constant CAVALRY_ATTACK = 30;
    uint256 constant CAVALRY_HEALTH = 20;
    uint256 constant DISTANCE_TO_CASTLE = 100;
    uint256 constant INFANTRY_SPEED = 10;
    uint256 constant CAVALRY_SPEED = 50;

    // SKALE specific
    uint256 constant SFUEL_DISTRIBUTION_AMOUNT = 0.00001 ether;
}