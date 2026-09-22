// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {VRFV2PlusClient} from "contracts/libraries/VRFV2PlusClient.sol";

interface IVRFCoordinatorV2Plus {
    function requestRandomWords(VRFV2PlusClient.RandomWordsRequest calldata request)
        external
        returns (uint256 requestId);
}
