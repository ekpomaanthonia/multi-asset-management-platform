# Tokenized Multi-Asset Management Platform

A Clarity smart contract for managing multiple tokenized assets on the Stacks blockchain.

## Overview

This platform enables the creation, management, and transfer of various tokenized assets within a single contract. It's designed for flexibility and security, allowing asset administrators to create different categories of assets while users can safely trade and delegate spending permissions.

## Features

- **Asset Creation and Management**: Create and configure various asset types with customizable parameters.
- **Ownership Tracking**: Secure tracking of asset holdings across users.
- **Authorization System**: Delegated spending with time-based expiration.
- **Contract Administration**: Ability to pause operations and transfer admin rights.
- **Metadata Support**: Optional URI support for extended asset information.

## Contract Structure

### Data Structures

- `registered-assets`: Stores asset details including name, category, supply, and pricing.
- `user-holdings`: Tracks asset balances for users with last update timestamps.
- `spending-authorizations`: Manages delegated spending permissions with expiration.

### Core Functions

#### Administration
- `update-contract-admin`: Transfers contract administration rights.
- `set-contract-status`: Pauses or activates contract operations.

#### Asset Management
- `register-asset`: Creates a new asset type with initial supply.
- `update-asset-price`: Updates the current price of an existing asset.

#### User Operations
- `authorize-spender`: Grants spending permission to another user.
- `transfer-asset`: Transfers assets between users.
- `transfer-from`: Executes transfers using delegated permissions.

#### Read-Only Functions
- `get-asset-details`: Retrieves detailed information about an asset.
- `get-user-holdings`: Checks a user's balance for a specific asset.
- `get-contract-status`: Returns the current operational status.
- `get-contract-admin`: Returns the current administrator's address.

## Security Features

- Input validation for all external data
- Time-based authorization expiration
- Contract pause mechanism for emergency situations
- Comprehensive error handling

## Usage Examples

### Creating a New Asset

```clarity
(contract-call? .multi-asset-platform register-asset 
  "Corporate Bond XYZ" 
  "Bond" 
  u10000 
  u100000000 
  (some u"https://metadata.example.com/assets/bond-xyz"))
```

### Authorizing a Spender

```clarity
(contract-call? .multi-asset-platform authorize-spender 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  u1 
  u500 
  (some (+ block-height u1440)))
```

### Transferring Assets

```clarity
(contract-call? .multi-asset-platform transfer-asset 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  u1 
  u100)
```

## Error Codes

| Code | Description |
|------|-------------|
| u100 | ERR_ADMIN_ONLY: Only the administrator can perform this action |
| u101 | ERR_ASSET_EXISTS: Asset ID already exists |
| u102 | ERR_ASSET_NOT_FOUND: Asset ID does not exist |
| u103 | ERR_INSUFFICIENT_BALANCE: Sender has insufficient balance |
| ... | ... |
