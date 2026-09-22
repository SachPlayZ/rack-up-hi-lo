// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @notice Minimal Chainlink VRF v2.5 request types, wire-compatible with the coordinator.
library VRFV2PlusClient {
    bytes4 internal constant EXTRA_ARGS_V1_TAG = bytes4(keccak256("VRF ExtraArgsV1"));

    struct ExtraArgsV1 {
        bool nativePayment;
    }

    struct RandomWordsRequest {
        bytes32 keyHash;
        uint256 subId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        uint32 numWords;
        bytes extraArgs;
    }

    function _argsToBytes(ExtraArgsV1 memory extraArgs) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSelector(EXTRA_ARGS_V1_TAG, extraArgs);
    }
}
