# Song Marketplace Smart Contract

A decentralized marketplace built on StarkNet for buying, selling, and managing digital music assets using IPFS for storage.

## Overview

This project implements a decentralized song marketplace where users can:
- Register songs and set their prices
- Preview songs before purchasing
- Buy songs from other users
- Manage their song collections

The smart contract is written in Cairo for the StarkNet L2 scaling solution, with IPFS integration for decentralized storage of audio files.

## Smart Contract Architecture

The codebase is organized into three main files:

### `lib.cairo`
Entry point that organizes and exports the contract modules:
```cairo
mod interface;
mod song_marketplace;

use song_marketplace::SongMarketplace;
```

### `interface.cairo`
Defines the contract interface with all available functions:
```cairo
#[starknet::interface]
trait ISongMarketplace<TContractState> {
    fn register_song(...) -> u64;
    fn get_song_info(...) -> (...);
    fn update_song_price(...);
    fn get_preview(...) -> felt252;
    fn buy_song(...) -> felt252;
    fn get_user_songs(...) -> Array<u64>;
    fn is_song_owner(...) -> bool;
}
```

### `song_marketplace.cairo`
Contains the main contract implementation with storage structures and function logic.

## Key Features

### Song Registration
Users can register songs by providing:
- Song name
- IPFS hash of the full song
- IPFS hash of a preview clip
- Initial price

### Song Preview
Potential buyers can access a preview version of songs before purchasing, reducing the risk associated with digital asset purchases.

### Ownership Management
The contract maintains a complete record of song ownership and validates all transactions to ensure only legitimate owners can modify or sell songs.

### User Song Collections
Each user has a tracked collection of owned songs, making it easy to manage digital assets.

## IPFS Integration

The contract uses IPFS (InterPlanetary File System) for decentralized storage:
- Full songs are stored as complete files on IPFS
- Preview clips (shorter/lower quality versions) are stored separately
- Only the IPFS content identifiers (CIDs) are stored on-chain

This approach provides:
- Cost efficiency (only storing hash references on-chain)
- Data permanence through IPFS
- Reduced blockchain bloat

## Getting Started

### Prerequisites
- [Cairo](https://www.cairo-lang.org/docs/quickstart.html) development environment
- [StarkNet](https://docs.starknet.io/documentation/) CLI tools
- Access to IPFS (via local node or gateway service)

### Deployment

1. Compile the contract:
```bash
starknet-compile lib.cairo --output song_marketplace_compiled.json
```

2. Deploy to StarkNet:
```bash
starknet deploy --contract song_marketplace_compiled.json
```

3. Interact with the deployed contract using StarkNet CLI or integrate with a frontend application.

## Interacting with the Contract

### Registering a Song
```bash
starknet invoke --address CONTRACT_ADDRESS --function register_song --inputs "Song Name" "IPFS_FULL_SONG_HASH" "IPFS_PREVIEW_HASH" PRICE
```

### Buying a Song
```bash
starknet invoke --address CONTRACT_ADDRESS --function buy_song --inputs SONG_ID
```

### Getting Song Preview
```bash
starknet call --address CONTRACT_ADDRESS --function get_preview --inputs SONG_ID
```

## Frontend Integration

To create a complete dApp experience, integrate this contract with a frontend that handles:
1. Uploading songs to IPFS and generating hash values
2. Creating preview clips and uploading them to IPFS
3. Interacting with the StarkNet contract
4. Wallet connectivity for payments and transaction signing
5. Playback interface for previewing and listening to purchased songs

## Security Considerations

- The contract implements ownership verification before allowing price changes or sales
- In a production environment, additional security measures should be added:
  - Reentrancy guards
  - Formal verification
  - Rate limiting
  - Additional access controls

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Future Enhancements

- Royalty distribution to original creators
- Subscription-based access models
- Auction mechanisms for rare songs
- Integration with artist verification systems
- Support for album collections and bundled sales