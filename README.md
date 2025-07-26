# Token Staking Smart Contract

A comprehensive token staking smart contract built for the Stacks blockchain that allows users to stake SIP-010 compliant tokens and earn rewards over time.

## Features

- **SIP-010 Token Compatibility**: Works with any token implementing the SIP-010 standard
- **Flexible Staking Periods**: Users can choose their staking duration up to 1 year
- **Reward System**: Earn 5% base rewards based on staking duration
- **Early Exit Penalty**: 10% penalty for unstaking before half the staking period
- **Admin Controls**: Contract owner can manage reward rates and pool deposits
- **Comprehensive Validation**: Robust error handling and input validation

## Contract Parameters

- **Minimum Stake**: 100 tokens
- **Maximum Stake**: 10,000 tokens  
- **Base Reward Rate**: 5% annually
- **Maximum Stake Period**: 52,560 blocks (~1 year)
- **Early Exit Threshold**: Must stake for at least half the chosen period

## Core Functions

### For Users

#### `stake-tokens`
```clarity
(stake-tokens token-contract stake-amount stake-period)
```
Stake tokens for a specified period to earn rewards.
- `token-contract`: SIP-010 compliant token contract
- `stake-amount`: Amount of tokens to stake (100-10,000)
- `stake-period`: Duration in blocks (max 52,560)

#### `claim-rewards`
```clarity
(claim-rewards token-contract)
```
Claim accumulated staking rewards without unstaking.

#### `unstake-tokens`
```clarity
(unstake-tokens token-contract)
```
Withdraw staked tokens and any pending rewards. Early exit incurs 10% penalty.

### View Functions

#### `get-stake-info`
```clarity
(get-stake-info staker-principal)
```
Returns staking information for a specific user.

#### `get-total-staked`
```clarity
(get-total-staked)
```
Returns the total amount of tokens currently staked in the contract.

### Admin Functions

#### `deposit-to-reward-pool`
```clarity
(deposit-to-reward-pool token-contract deposit-amount)
```
Add tokens to the reward pool to ensure sufficient rewards for stakers.

#### `update-reward-rate`
```clarity
(update-reward-rate token-contract new-reward-rate)
```
Update the base reward rate (contract owner only).

## Error Codes

| Code | Description |
|------|-------------|
| u1 | ERROR-UNAUTHORIZED |
| u2 | ERROR-INSUFFICIENT-BALANCE |
| u3 | ERROR-STAKE-NOT-FOUND |
| u4 | ERROR-UNSTAKE-FORBIDDEN |
| u5 | ERROR-ALREADY-STAKED |
| u6 | ERROR-INVALID-AMOUNT |
| u7 | ERROR-REWARD-CALCULATION |
| u8 | ERROR-INVALID-TOKEN-CONTRACT |
| u9 | ERROR-TRANSFER-FAILED |

## Usage Example

```clarity
;; Stake 1000 tokens for 26280 blocks (~6 months)
(contract-call? .staking-contract stake-tokens .my-token u1000 u26280)

;; Claim rewards after some time
(contract-call? .staking-contract claim-rewards .my-token)

;; Unstake tokens (after minimum period)
(contract-call? .staking-contract unstake-tokens .my-token)
```

## Security Features

- **Input Validation**: All parameters are validated before execution
- **Token Contract Verification**: Ensures only valid SIP-010 tokens are accepted
- **Balance Checks**: Verifies sufficient balances before transfers
- **Reentrancy Protection**: Safe state updates and external calls
- **Access Control**: Admin functions restricted to contract owner

## Deployment Requirements

1. Deploy the contract to Stacks blockchain
2. Ensure the reward pool has sufficient tokens for payouts
3. Configure the target SIP-010 token contract address
4. Set appropriate staking parameters for your use case

## Important Notes

- Users can only have one active stake at a time
- Rewards are calculated based on blocks passed since staking
- Early unstaking (before 50% of chosen period) incurs a 10% penalty
- The contract owner must maintain adequate reward pool balance
- All token transfers follow SIP-010 standard specifications
