// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {IVRFCoordinatorV2Plus} from "contracts/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "contracts/libraries/VRFV2PlusClient.sol";
import {VRFConsumerBaseV2Plus} from "contracts/vrf/VRFConsumerBaseV2Plus.sol";

/**
 *  @notice Deterministic local-only VRF coordinator mock.
 */
contract VRFCoordinatorV2PlusMock is IVRFCoordinatorV2Plus {
    struct StoredRequest {
        address consumer;
        uint32 numWords;
        bool fulfilled;
    }

    uint256 public nextRequestId = 1;
    bool public requestShouldRevert;
    mapping(uint256 requestId => StoredRequest request) public requests;

    event MockRandomWordsRequested(uint256 indexed requestId, address indexed consumer);
    event MockRandomWordsFulfilled(uint256 indexed requestId, address indexed consumer);

    error VRFCoordinatorV2PlusMock__UnknownRequest();
    error VRFCoordinatorV2PlusMock__AlreadyFulfilled();
    error VRFCoordinatorV2PlusMock__InvalidWords();
    error VRFCoordinatorV2PlusMock__RequestFailed();

    function requestRandomWords(VRFV2PlusClient.RandomWordsRequest calldata request)
        external
        returns (uint256 requestId)
    {
        if (requestShouldRevert) revert VRFCoordinatorV2PlusMock__RequestFailed();
        requestId = nextRequestId++;
        requests[requestId] = StoredRequest({consumer: msg.sender, numWords: request.numWords, fulfilled: false});
        emit MockRandomWordsRequested(requestId, msg.sender);
    }

    function setRequestShouldRevert(bool shouldRevert) external {
        requestShouldRevert = shouldRevert;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        StoredRequest storage request = requests[requestId];
        if (request.consumer == address(0)) revert VRFCoordinatorV2PlusMock__UnknownRequest();
        if (request.fulfilled) revert VRFCoordinatorV2PlusMock__AlreadyFulfilled();
        if (randomWords.length != request.numWords) revert VRFCoordinatorV2PlusMock__InvalidWords();
        request.fulfilled = true;
        VRFConsumerBaseV2Plus(request.consumer).rawFulfillRandomWords(requestId, randomWords);
        emit MockRandomWordsFulfilled(requestId, request.consumer);
    }

    function fulfillRandomWord(uint256 requestId, uint256 randomWord) external {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;
        this.fulfillRandomWords(requestId, randomWords);
    }
}
