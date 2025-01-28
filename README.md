# ENS DAO Steward Compensation Contract

A smart contract system for managing and distributing monthly USDC compensation to ENS DAO stewards.

## Overview

This contract enables monthly USDC payments to ENS DAO stewards. The MetaGov Safe controls recipient management and period setup, while anyone can trigger payments once a period's timestamp is reached.

## Contract Details

- Owner: MetaGov Safe (can be transferred to ENS DAO)
- Token: USDC (Mainnet: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`)
- Maximum Monthly Amount: 10,000 USDC per recipient

## Setup

1. Deploy contract with constructor parameters:
```solidity
constructor(
    address _usdc,    // USDC token address
    address _initialOwner  // MetaGov Safe address
)
```

2. Set USDC allowance from MetaGov Safe:
```solidity
// From MetaGov Safe
USDC.approve(compensationContractAddress, amount)
```

## Functions

### Recipient Management

#### Add Recipient
```solidity
function addRecipient(
    address _recipient,
    uint256 _monthlyAmount,
    string calldata _role
)
```
Example:
```solidity
// Add a regular steward receiving 4,000 USDC monthly
addRecipient(
    "0x123...",
    4000000000, // 4,000 USDC (6 decimals)
    "Regular Steward"
)
```

#### Update Recipient
```solidity
function updateRecipient(
    address _recipient,
    uint256 _newAmount,
    string calldata _role
)
```
Example:
```solidity
// Update to lead steward with 5,500 USDC
updateRecipient(
    "0x123...",
    5500000000, // 5,500 USDC
    "Lead Steward"
)
```

#### Remove Recipient
```solidity
function removeRecipient(address _recipient)
```
Example:
```solidity
removeRecipient("0x123...")
```

### Payment Period Management

#### Set Payment Period
```solidity
function setPeriod(
    uint256 _periodId,
    uint256 _dueTimestamp
)
```
Example:
```solidity
// Set period 1 for January 1, 2025 00:00:00 UTC
setPeriod(1, 1704067200)
```

#### Process Payments
```solidity
function sendComp(
    uint256 _periodId,
    address[] calldata _recipientsToProcess,
    uint256 _termNumber
)
```
Example:
```solidity
// Process payments for three recipients in period 1
sendComp(
    1,
    [
        "0x123...", // recipient 1
        "0x456...", // recipient 2
        "0x789..."  // recipient 3
    ],
    6 // Term 6
)
```

### View Functions

#### Get Active Recipients
```solidity
function getActiveRecipients() external view returns (
    address[] memory addresses,
    uint256[] memory amounts,
    string[] memory roles
)
```
Returns arrays of all active recipient details.

### Emergency Functions

#### Pause Contract
```solidity
function pause()
```
Prevents payment processing. Only callable by owner.

#### Unpause Contract
```solidity
function unpause()
```
Resumes payment processing. Only callable by owner.

## State Tracking

The contract tracks:
1. Active recipients and their monthly amounts
2. Payment periods and their completion status
3. Per-period payment status for each recipient

## Events

1. `RecipientAdded(address indexed recipient, uint256 monthlyAmount, string role)`
2. `RecipientUpdated(address indexed recipient, uint256 newAmount, string role)`
3. `RecipientRemoved(address indexed recipient)`
4. `CompensationPaid(uint256 indexed periodId, address indexed recipient, uint256 amount, string role, uint256 termNumber)`
5. `PeriodInitialized(uint256 indexed periodId, uint256 dueTimestamp)`

## Example Usage Flow

1. Initial Setup:
```solidity
// Deploy contract
const contract = await deploy("StewardCompensation", [USDC_ADDRESS, METAGOV_SAFE])

// Approve USDC spend from MetaGov Safe
await usdcContract.approve(contract.address, TOTAL_AMOUNT)
```

2. Add Recipients:
```solidity
// Add lead steward
await contract.addRecipient(LEAD_STEWARD_ADDRESS, 5500000000, "Lead Steward")

// Add regular steward
await contract.addRecipient(REGULAR_STEWARD_ADDRESS, 4000000000, "Regular Steward")
```

3. Set Payment Period:
```solidity
// Set January 2025 period
await contract.setPeriod(1, 1704067200)
```

4. Process Payments:
```solidity
// Once timestamp is reached, anyone can call:
await contract.sendComp(1, [LEAD_STEWARD_ADDRESS, REGULAR_STEWARD_ADDRESS], 6)
```

## Security Considerations

1. Owner Controls:
   - Adding/removing recipients
   - Setting payment periods
   - Emergency pause
   
2. Payment Controls:
   - Timestamp validation
   - One payment per recipient per period
   - Maximum monthly amount cap
   - Period completion tracking

3. USDC Controls:
   - Allowance from MetaGov Safe required
   - SafeERC20 for token transfers
   - No token storage in contract

## Gas Optimization

The `sendComp` function accepts an array of recipients, allowing batch processing if gas limits are a concern. This enables splitting large payment sets across multiple transactions while maintaining payment period integrity.
