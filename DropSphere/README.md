# Drop Sphere

An advanced airdrop distribution platform built with Clarity smart contracts that enables sophisticated token distribution with vesting schedules, whitelist management, batch processing, and comprehensive analytics.

## Overview

Drop Sphere addresses the complex needs of token distribution in the blockchain ecosystem. Whether you're launching a new project, rewarding community members, or implementing tokenomics with vesting schedules, Drop Sphere provides a comprehensive, secure, and efficient solution for managing large-scale airdrops.

## Features

- **Multi-Campaign Management**: Create and run multiple airdrop campaigns simultaneously
- **Advanced Vesting**: Linear vesting with configurable cliff periods to prevent token dumps
- **Whitelist System**: Controlled distribution with recipient verification and custom allocations
- **Batch Processing**: Efficiently handle thousands of recipients with gas-optimized operations
- **Merkle Tree Support**: Scalable verification for massive airdrop campaigns
- **Real-time Analytics**: Track campaign performance, claim rates, and user participation
- **Emergency Controls**: Pause campaigns instantly for security or regulatory compliance
- **Platform Sustainability**: Built-in fee structure for ongoing development and maintenance

## Quick Start

### Creating an Airdrop Campaign

```clarity
;; Create a 30-day campaign with 6-month vesting
(contract-call? .drop-sphere create-campaign
  "PROJECT-TOKEN"           ;; token name
  u1000000                 ;; total tokens (1M)
  u4320                    ;; campaign duration (30 days in blocks)
  u8640                    ;; claim deadline (60 days)
  (some u129600)           ;; vesting period (6 months)
  true)                    ;; requires whitelist
```

### Adding Recipients in Batches

```clarity
;; Add multiple recipients efficiently
(contract-call? .drop-sphere add-recipients-batch
  u1  ;; campaign ID
  (list 'SP1... 'SP2... 'SP3...)  ;; recipient addresses
  (list u1000 u2000 u1500))       ;; token allocations
```

### Whitelisting Individual Recipients

```clarity
;; Add VIP recipient with large allocation
(contract-call? .drop-sphere whitelist-recipient
  u1                    ;; campaign ID
  'SP-VIP-ADDRESS      ;; recipient
  u50000)              ;; allocation amount
```

### Claiming Tokens

```clarity
;; Recipients claim their allocated tokens
(contract-call? .drop-sphere claim-airdrop u1)

;; Claim vested tokens as they become available
(contract-call? .drop-sphere claim-vested-tokens u1)
```

## Core Functions

| Function | Access | Description |
|----------|--------|-------------|
| `create-campaign` | Public | Launch new airdrop campaign |
| `add-recipients-batch` | Creator | Add multiple recipients efficiently |
| `whitelist-recipient` | Creator | Add individual recipients with custom allocations |
| `claim-airdrop` | Recipients | Claim allocated tokens |
| `claim-vested-tokens` | Recipients | Claim tokens as they vest |
| `emergency-pause-campaign` | Creator/Owner | Pause campaign for security |

## Campaign Types

### Instant Distribution
Perfect for community rewards and marketing campaigns:
```clarity
(contract-call? .drop-sphere create-campaign
  "COMMUNITY-REWARD" u100000 u1440 u4320 none false)
```

### Vested Distribution
Ideal for team tokens and investor allocations:
```clarity
(contract-call? .drop-sphere create-campaign
  "TEAM-TOKENS" u5000000 u144 u144 (some u525600) true)
```

### Time-Limited Campaigns
For promotional events with urgency:
```clarity
(contract-call? .drop-sphere create-campaign
  "LIMITED-DROP" u50000 u720 u720 none false)
```

## Vesting Mechanism

### Linear Vesting with Cliff
- **Cliff Period**: 25% of total vesting duration (prevents immediate selling)
- **Linear Release**: Tokens unlock proportionally over time
- **Claim Flexibility**: Recipients can claim vested tokens at any time

### Vesting Example
```
Total Allocation: 10,000 tokens
Vesting Duration: 12 months (525,600 blocks)
Cliff Period: 3 months (131,400 blocks)

Timeline:
- Months 0-3: 0 tokens available (cliff period)
- Month 6: 5,000 tokens available (50% vested)
- Month 12: 10,000 tokens available (fully vested)
```

## Analytics & Tracking

### Campaign Analytics
```clarity
(contract-call? .drop-sphere get-campaign-stats u1)
;; Returns: unique-claimants, total-claims, average-claim, last-claim-block
```

### User Profiles
```clarity
(contract-call? .drop-sphere get-user-profile 'SP-USER-ADDRESS)
;; Returns: campaigns-participated, total-claimed, reputation-score
```

### Platform Statistics
```clarity
(contract-call? .drop-sphere get-platform-stats)
;; Returns: total-campaigns, total-distributed, platform-fee-rate
```

## Security Features

### Access Control
- **Campaign Creators**: Full control over their campaigns
- **Contract Owner**: Emergency powers and platform management
- **Recipients**: Can only claim their allocated tokens

### Input Validation
- All user inputs validated for security
- Campaign ID bounds checking
- String input sanitization
- Amount and timing validations

### Anti-Abuse Measures
- **Double-Claim Prevention**: Users cannot claim the same allocation twice
- **Time-Based Controls**: Block height validation for all time-sensitive operations
- **Whitelist Verification**: Controlled access for sensitive distributions
- **Emergency Pause**: Immediate campaign suspension capability

## Error Codes

- `u401` - Unauthorized access
- `u404` - Campaign not found
- `u400` - Invalid input data
- `u403` - Campaign ended or inactive
- `u405` - Already claimed
- `u402` - Not eligible for claim
- `u406` - Insufficient funds
- `u407` - Claim period ended

## Use Cases

### Project Launches
```clarity
;; Fair launch with community distribution
(contract-call? .drop-sphere create-campaign
  "FAIR-LAUNCH" u10000000 u2160 u4320 none false)
```

### Team & Advisor Tokens
```clarity
;; 4-year vesting for team allocation
(contract-call? .drop-sphere create-campaign
  "TEAM-VESTING" u20000000 u144 u144 (some u2102400) true)
```

### Marketing Campaigns
```clarity
;; Time-limited promotional airdrop
(contract-call? .drop-sphere create-campaign
  "PROMO-DROP" u500000 u1440 u1440 none false)
```

### Retroactive Rewards
```clarity
;; Reward early adopters and contributors
(contract-call? .drop-sphere create-campaign
  "RETROACTIVE" u2000000 u4320 u8640 (some u262800) true)
```

## Integration Examples

### DeFi Protocol Integration
```clarity
(define-public (distribute-yield-rewards (users (list 100 principal)) (amounts (list 100 uint)))
  (contract-call? .drop-sphere add-recipients-batch
    u5  ;; yield rewards campaign
    users
    amounts
  )
)
```

### Governance Token Distribution
```clarity
(define-public (distribute-governance-tokens (snapshot-block uint))
  ;; Custom logic to determine allocations based on snapshot
  (contract-call? .drop-sphere create-campaign
    "GOVERNANCE" u50000000 u4320 u17280 (some u1051200) true)
)
```

### Community Engagement Rewards
```clarity
(define-read-only (check-eligibility (user principal))
  (let ((profile (contract-call? .drop-sphere get-user-profile user)))
    (match profile
      some-profile (>= (get reputation-score some-profile) u500)
      false
    )
  )
)
```

## Best Practices

### For Campaign Creators
- **Plan Vesting Carefully**: Consider token economics and market conditions
- **Set Realistic Deadlines**: Allow sufficient time for recipients to claim
- **Batch Operations**: Use batch functions for gas efficiency
- **Monitor Analytics**: Track campaign performance and adjust strategies

### For Recipients
- **Claim Promptly**: Don't miss claim deadlines
- **Understand Vesting**: Know when your tokens become available
- **Track Multiple Campaigns**: Manage participation across different projects
- **Maintain Good Standing**: Build reputation for future opportunities

### For Integrators
- **Validate Inputs**: Always check return values and handle errors
- **Gas Optimization**: Use batch operations when possible
- **User Experience**: Provide clear information about vesting schedules
- **Security**: Implement additional checks in your application layer

## Advanced Features

### Merkle Tree Integration
For campaigns with millions of recipients:
```clarity
;; Set merkle root for efficient verification
(map-set airdrop-campaigns { campaign-id: u1 } 
  (merge campaign-data { merkle-root: (some merkle-hash) }))
```

### Reputation System
Users build reputation through participation:
- **+5 points** per successful claim
- **Higher reputation** may unlock exclusive campaigns
- **Reputation tracking** across all platform interactions

### Platform Fee Structure
- **1% platform fee** on distributed tokens
- **Sustainable revenue model** for ongoing development
- **Fee collected** only on successful distributions

## Testing

Comprehensive test coverage should include:
- Campaign creation with various parameters
- Batch recipient addition and validation
- Vesting calculation accuracy
- Claim prevention mechanisms
- Emergency pause functionality
- Analytics accuracy
- Edge cases and error conditions

## Gas Optimization

Drop Sphere is optimized for efficiency:
- **Batch Processing**: Add up to 100 recipients per transaction
- **Lazy Evaluation**: Vesting calculated on-demand
- **Efficient Data Structures**: Minimal storage overhead
- **Optimized Loops**: Reduced computational complexity

## Contributing

This project welcomes contributions for:
- Additional vesting schedule types
- Enhanced analytics and reporting
- Integration with external data sources
- Gas optimization improvements
- User experience enhancements

## Roadmap

- **v2.0**: Cross-chain airdrop support
- **v2.1**: Advanced analytics dashboard
- **v2.2**: Automated campaign management
- **v2.3**: Integration with popular DeFi protocols