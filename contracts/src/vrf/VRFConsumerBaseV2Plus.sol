// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/**
 * @title VRFConsumerBaseV2Plus
 * @notice Minimal callback gate compatible with Chainlink VRF v2.5.
 * @custom:security-contact security@hi-lo.game
 */
abstract contract VRFConsumerBaseV2Plus {
    address internal immutable i_vrfCoordinator;

    error VRFConsumerBaseV2Plus__OnlyCoordinatorCanFulfill(address sender, address coordinator);

    constructor(address coordinator) {
        i_vrfCoordinator = coordinator;
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        if (msg.sender != i_vrfCoordinator) {
            revert VRFConsumerBaseV2Plus__OnlyCoordinatorCanFulfill(msg.sender, i_vrfCoordinator);
        }
        fulfillRandomWords(requestId, randomWords);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal virtual;
}
