// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {BaseSepoliaFaucet} from "contracts/BaseSepoliaFaucet.sol";
import {HiLoGame} from "contracts/HiLoGame.sol";

interface IVRFSubscriptionCoordinator {
    function addConsumer(uint256 subscriptionId, address consumer) external;
}

contract DeployBaseSepolia is Script {
    address internal constant BASE_SEPOLIA_VRF_COORDINATOR = 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE;
    bytes32 internal constant BASE_SEPOLIA_30_GWEI_KEY_HASH =
        0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71;
    uint32 internal constant CALLBACK_GAS_LIMIT = 500_000;
    uint16 internal constant REQUEST_CONFIRMATIONS = 3;
    uint256 internal constant DEFAULT_CLAIM_AMOUNT = 0.001 ether;

    function run() external returns (HiLoGame game, BaseSepoliaFaucet faucet) {
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address relayer = vm.envAddress("RELAYER_ADDRESS");
        uint256 subscriptionId = vm.envUint("VRF_SUBSCRIPTION_ID");

        vm.startBroadcast();
        game = new HiLoGame(
            admin,
            BASE_SEPOLIA_VRF_COORDINATOR,
            subscriptionId,
            BASE_SEPOLIA_30_GWEI_KEY_HASH,
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS
        );
        faucet = new BaseSepoliaFaucet(admin, relayer, DEFAULT_CLAIM_AMOUNT);
        IVRFSubscriptionCoordinator(BASE_SEPOLIA_VRF_COORDINATOR).addConsumer(subscriptionId, address(game));
        vm.stopBroadcast();

        console2.log("HiLoGame", address(game));
        console2.log("BaseSepoliaFaucet", address(faucet));
    }
}
