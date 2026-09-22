// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";
import {ReentrancyGuardTransient} from "openzeppelin-contracts/utils/ReentrancyGuardTransient.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/**
 * @title BaseSepoliaFaucet
 * @notice Relayer-operated, one-claim-per-address native ETH faucet.
 * @custom:security-contact security@hi-lo.game
 */
contract BaseSepoliaFaucet is Ownable2Step, ReentrancyGuardTransient {
    using SafeTransferLib for address;

    address public relayer;
    uint256 public claimAmount;

    mapping(address account => bool claimed) private s_claimed;

    event FaucetFunded(address indexed funder, uint256 amount);
    event FaucetClaimed(address indexed recipient, uint256 amount);
    event RelayerUpdated(address indexed previousRelayer, address indexed newRelayer);
    event ClaimAmountUpdated(uint256 previousAmount, uint256 newAmount);
    event FundsRecovered(address indexed recipient, uint256 amount);

    error BaseSepoliaFaucet__ZeroAddress();
    error BaseSepoliaFaucet__ZeroAmount();
    error BaseSepoliaFaucet__OnlyRelayer();
    error BaseSepoliaFaucet__AlreadyClaimed();
    error BaseSepoliaFaucet__InsufficientBalance();

    constructor(address initialOwner, address initialRelayer, uint256 initialClaimAmount) Ownable(initialOwner) {
        if (initialOwner == address(0) || initialRelayer == address(0)) revert BaseSepoliaFaucet__ZeroAddress();
        if (initialClaimAmount == 0) revert BaseSepoliaFaucet__ZeroAmount();
        relayer = initialRelayer;
        claimAmount = initialClaimAmount;
    }

    receive() external payable {
        emit FaucetFunded(msg.sender, msg.value);
    }

    function claimFor(address recipient) external nonReentrant {
        if (msg.sender != relayer) revert BaseSepoliaFaucet__OnlyRelayer();
        if (recipient == address(0)) revert BaseSepoliaFaucet__ZeroAddress();
        if (s_claimed[recipient]) revert BaseSepoliaFaucet__AlreadyClaimed();

        uint256 amount = claimAmount;
        if (address(this).balance < amount) revert BaseSepoliaFaucet__InsufficientBalance();
        s_claimed[recipient] = true;
        recipient.safeTransferETH(amount);

        emit FaucetClaimed(recipient, amount);
    }

    function setRelayer(address newRelayer) external onlyOwner {
        if (newRelayer == address(0)) revert BaseSepoliaFaucet__ZeroAddress();
        address previousRelayer = relayer;
        relayer = newRelayer;
        emit RelayerUpdated(previousRelayer, newRelayer);
    }

    function setClaimAmount(uint256 newClaimAmount) external onlyOwner {
        if (newClaimAmount == 0) revert BaseSepoliaFaucet__ZeroAmount();
        uint256 previousAmount = claimAmount;
        claimAmount = newClaimAmount;
        emit ClaimAmountUpdated(previousAmount, newClaimAmount);
    }

    function recover(address recipient, uint256 amount) external nonReentrant onlyOwner {
        if (recipient == address(0)) revert BaseSepoliaFaucet__ZeroAddress();
        if (amount == 0) revert BaseSepoliaFaucet__ZeroAmount();
        if (address(this).balance < amount) revert BaseSepoliaFaucet__InsufficientBalance();
        recipient.safeTransferETH(amount);
        emit FundsRecovered(recipient, amount);
    }

    function hasClaimed(address account) external view returns (bool claimed) {
        claimed = s_claimed[account];
    }
}
