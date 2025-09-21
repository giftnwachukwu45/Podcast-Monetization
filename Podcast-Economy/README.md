# Decentralized Podcast Monetization Smart Contract

A Clarity smart contract for Stacks blockchain that enables decentralized podcast monetization through subscriptions, tiered access, and advertising revenue distribution.

## Overview

This smart contract provides a complete solution for podcast creators to monetize their content without relying on centralized platforms. It supports multiple revenue streams including subscription tiers, advertising campaigns, and automated revenue distribution.

## Features

### Core Functionality
- **Podcast Creation**: Register and manage podcast metadata
- **Multi-tier Subscriptions**: Support for different subscription levels with varying prices and benefits
- **Automated Revenue Distribution**: Built-in platform fee collection and creator payouts
- **Advertising Integration**: Ad campaign management with impression tracking and revenue sharing
- **Subscription Management**: Automated renewal and access control

### Revenue Streams
- Subscription-based access with configurable tiers
- Cost-per-mille (CPM) advertising revenue
- Platform fee collection (5% default)

## Contract Architecture

### Data Structures

#### Podcasts
- Creator identification and metadata
- Subscription pricing and statistics
- Revenue tracking
- Active status management

#### Subscription Tiers
- Flexible pricing models
- Duration configuration
- Benefit descriptions
- Access level management

#### User Subscriptions
- Time-based access control
- Payment tracking
- Auto-renewal options
- Tier-specific benefits

#### Ad Campaigns
- Budget management
- Targeting options
- Performance tracking
- Revenue distribution

## Public Functions

### Podcast Management

#### `create-podcast`
```clarity
(create-podcast (title (string-ascii 100)) (description (string-ascii 500)) (base-price uint))
```
Creates a new podcast with basic subscription tier.

**Parameters:**
- `title`: Podcast title (max 100 characters)
- `description`: Podcast description (max 500 characters)  
- `base-price`: Default subscription price in microSTX

**Returns:** Podcast ID on success

#### `add-subscription-tier`
```clarity
(add-subscription-tier (podcast-id uint) (tier-id uint) (name (string-ascii 50)) (price uint) (duration-blocks uint) (benefits (string-ascii 200)))
```
Adds a new subscription tier to an existing podcast.

**Authorization:** Must be called by podcast creator

### Subscription Management

#### `subscribe-to-podcast`
```clarity
(subscribe-to-podcast (podcast-id uint) (tier-id uint))
```
Subscribe to a podcast with specified tier.

**Payment:** Automatically transfers subscription fee to creator
**Platform Fee:** 5% deducted from creator revenue

#### `renew-subscription`
```clarity
(renew-subscription (podcast-id uint))
```
Renews an existing subscription for the same tier duration.

### Advertising

#### `create-ad-campaign`
```clarity
(create-ad-campaign (title (string-ascii 100)) (target-podcast-id (optional uint)) (budget uint) (cpm uint) (duration-blocks uint))
```
Creates a new advertising campaign.

**Parameters:**
- `target-podcast-id`: Optional podcast targeting (none = general campaign)
- `budget`: Total campaign budget in microSTX
- `cpm`: Cost per thousand impressions
- `duration-blocks`: Campaign duration in blocks

#### `record-ad-impression`
```clarity
(record-ad-impression (campaign-id uint) (podcast-id uint) (impressions uint))
```
Records ad impressions and distributes revenue.

**Authorization:** Must be called by podcast creator
**Revenue Distribution:** Automatic payment to creator minus platform fee

### Financial Management

#### `withdraw-earnings`
```clarity
(withdraw-earnings)
```
Withdraws accumulated earnings for the caller.

**Security:** Only pending earnings can be withdrawn

## Read-Only Functions

### Information Retrieval

- `get-podcast`: Retrieve podcast information
- `get-subscription`: Get user subscription details
- `get-subscription-tier`: Get tier configuration
- `get-ad-campaign`: Retrieve campaign information
- `get-creator-earnings`: View creator earnings breakdown
- `get-ad-impressions`: Get impression statistics
- `check-subscription-access`: Verify current access status
- `is-subscription-active`: Check if subscription is valid
- `get-current-block`: Get current block height

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR-UNAUTHORIZED-ACCESS | Caller lacks required permissions |
| 101 | ERR-PODCAST-NOT-FOUND | Specified podcast does not exist |
| 102 | ERR-SUBSCRIPTION-NOT-FOUND | User subscription not found |
| 103 | ERR-INVALID-AMOUNT | Invalid payment or amount value |
| 104 | ERR-ALREADY-SUBSCRIBED | User already has active subscription |
| 105 | ERR-INSUFFICIENT-BALANCE | Insufficient funds for operation |
| 106 | ERR-INVALID-DURATION | Invalid time duration specified |
| 107 | ERR-SUBSCRIPTION-EXPIRED | Subscription has expired |
| 108 | ERR-AD-CAMPAIGN-NOT-FOUND | Campaign does not exist |
| 109 | ERR-INVALID-PERCENTAGE | Invalid percentage value |
| 110 | ERR-CAMPAIGN-ENDED | Ad campaign has ended |
| 111 | ERR-INVALID-TIER | Subscription tier not found |

## Usage Examples

### Creating a Podcast
```clarity
(contract-call? .podcast-contract create-podcast 
  "My Tech Podcast" 
  "Weekly discussions about blockchain technology" 
  u1000000) ;; 1 STX base price
```

### Adding Premium Tier
```clarity
(contract-call? .podcast-contract add-subscription-tier 
  u1 ;; podcast-id
  u2 ;; tier-id 
  "Premium"
  u5000000 ;; 5 STX
  u2880 ;; ~60 days
  "Ad-free episodes, exclusive content, early access")
```

### Subscribing to Podcast
```clarity
(contract-call? .podcast-contract subscribe-to-podcast u1 u1)
```

### Creating Ad Campaign
```clarity
(contract-call? .podcast-contract create-ad-campaign
  "Crypto Exchange Ads"
  (some u1) ;; Target specific podcast
  u50000000 ;; 50 STX budget
  u5000 ;; 5 STX per 1000 impressions
  u1440) ;; 30-day campaign
```

## Security Considerations

### Access Control
- Function-level authorization checks
- Creator-only operations protected
- Subscription validation on access

### Financial Security
- Automatic fee calculation and distribution
- Balance verification before transfers
- Protected withdrawal mechanisms

### Data Integrity
- Input validation on all parameters
- State consistency checks
- Immutable transaction records

## Block Time Assumptions

The contract uses block-based timing with the following assumptions:
- Average block time: ~30 seconds
- 1 day ≈ 2,880 blocks
- 30 days ≈ 43,200 blocks

## Platform Economics

### Fee Structure
- Platform fee: 5% of all revenue
- Creator revenue: 95% of subscription and ad income
- Automatic fee collection and distribution

### Revenue Tracking
- Real-time earnings calculation
- Separate tracking for subscription vs. ad revenue
- Withdrawal history maintenance

## Development and Testing

### Prerequisites
- Clarity CLI tools
- Stacks blockchain testnet access
- STX tokens for testing

### Deployment Steps
1. Deploy contract to Stacks testnet
2. Initialize with appropriate parameters
3. Test all functions with various scenarios
4. Verify economic calculations
5. Deploy to mainnet

## Integration Guidelines

### Frontend Integration
- Use read-only functions for UI state
- Handle all error codes appropriately
- Implement subscription status checking
- Provide clear payment confirmation flows

### Backend Services
- Monitor block height for subscription expiration
- Aggregate impression data for reporting
- Handle webhook notifications for state changes