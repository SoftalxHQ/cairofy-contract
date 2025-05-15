// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^1.0.0
#[starknet::contract]
pub mod CairofyV0 {
    use cairofy_contract::events::Events::{SongPriceUpdated, Song_Registered};
    use cairofy_contract::interfaces::ICairofy::ICairofy;
    use cairofy_contract::structs::Structs::{
        PlatformStats, Song, SongStats, User, UserSubscription,
    };
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{
        ClassHash, ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
        get_contract_address,
    };

    const SUBSCRIPTION_FEE: u256 = 20_000_000_000_000_000_000_000;
    const PREMIUM_SUBSCRIPTION_FEE: u256 = 40_000_000_000_000_000_000_000;
    const ROYALTY_PERCENTAGE: u256 = 70; // 70% of streaming revenue goes to artist

    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // External
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    // Internal
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        // contract storage
        songs: Map<u64, Song>,
        song_count: u64,
        user_songs: Map<(ContractAddress, u64), bool>,
        user_song_count: Map<ContractAddress, u64>,
        user_song_ids: Map<(ContractAddress, u64), u64>,
        token_addr: ContractAddress,
        user_subscription: Map<ContractAddress, UserSubscription>,
        user: Map<ContractAddress, User>,
        subscription_count: u64,
        song_stream_count: Map<u64, u64>,
        suscription_history: Map<u64, u64>,
        platform_revenue: u256,
        streaming_access: Map<
            (ContractAddress, u64), bool,
        >, // Tracks if user has streaming access to a song
        streaming_history: Map<
            (ContractAddress, u64), u64,
        >, // Tracks number of times a user has streamed a song
        subscription_tier: Map<
            ContractAddress, u8,
        > // Tracks user's subscription tier (0=none, 1=basic, 2=premium)
    }

    #[event]
    #[derive(Drop, Destruct, starknet::Event)]
    pub enum Event {
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        // contract events
        Song_Registered: Song_Registered,
        SongPriceUpdated: SongPriceUpdated,
        SubscriptionRenewed: SubscriptionRenewed,
        SubscriptionTierChanged: SubscriptionTierChanged,
        RoyaltyDistributed: RoyaltyDistributed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SubscriptionRenewed {
        pub user: ContractAddress,
        pub subscription_id: u64,
        pub expiry_date: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SubscriptionTierChanged {
        pub user: ContractAddress,
        pub old_tier: u8,
        pub new_tier: u8,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoyaltyDistributed {
        pub song_id: u64,
        pub artist: ContractAddress,
        pub amount: u256,
        pub total_streams: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, token_addr: ContractAddress) {
        self.ownable.initializer(owner);
        self.token_addr.write(token_addr);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.pause();
        }

        #[external(v0)]
        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.unpause();
        }
    }

    // Upgradeable
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    // contract Implementation
    #[abi(embed_v0)]
    impl CairofyImpl of ICairofy<ContractState> {
        fn register_song(
            ref self: ContractState,
            name: felt252,
            ipfs_hash: felt252,
            preview_ipfs_hash: felt252,
            price: u256,
        ) -> u64 {
            let caller = get_caller_address();

            assert!(name != 0, "Song name cannot be empty");
            assert!(ipfs_hash != 0, "Your song hash cannot be empty");
            assert!(preview_ipfs_hash != 0, "Your song preview hash cannot be empty");
            assert!(price > 0, "Price must be greater than 0");
            // Increment song count and return the new song ID
            let song_id = self.song_count.read() + 1;
            self.song_count.write(song_id);

            let song = Song {
                id: song_id,
                name: name,
                ipfs_hash: ipfs_hash,
                preview_ipfs_hash: preview_ipfs_hash,
                price: price,
                owner: caller,
                for_sale: false,
            };
            //store the song in the contract storage
            self.songs.write(song_id, song);

            // Update user song mappings
            let user_song_count = self.user_song_count.read(caller);
            self.user_songs.write((caller, song_id), true);
            self.user_song_ids.write((caller, user_song_count), song_id);
            self.user_song_count.write(caller, user_song_count + 1);

            self.song_count.write(song_id);

            self
                .emit(
                    Event::Song_Registered(
                        Song_Registered {
                            song_id: song_id,
                            name: name,
                            ipfs_hash: ipfs_hash,
                            preview_ipfs_hash: preview_ipfs_hash,
                            price: price,
                            for_sale: false,
                        },
                    ),
                );
            song_id
        }

        // TODO: Implement function to get detailed song info
        fn get_song_info(self: @ContractState, song_id: u64) -> Song {
            // Check if the song_id is valid
            let total_songs = self.song_count.read();
            assert!(song_id <= total_songs, "Song ID does not exist");

            // Read and return the song information from storage
            self.songs.read(song_id)
        }

        // TODO: Implement function to update the price of a song
        fn update_song_price(ref self: ContractState, song_id: u64, new_price: u256) {
            // Check if the song_id is valid
            let total_songs = self.song_count.read();
            assert!(song_id <= total_songs, "Song ID does not exist");
            let mut song = self.songs.read(song_id);
            assert!(new_price > 0, "Price must be greater than 0");

            //Verify that the caller is the owner of the song
            let caller = get_caller_address();
            assert!(song.owner == caller, "Only the owner can update the song price");

            let song = Song {
                id: song_id,
                name: song.name,
                ipfs_hash: song.ipfs_hash,
                preview_ipfs_hash: song.preview_ipfs_hash,
                price: new_price,
                owner: caller,
                for_sale: song.for_sale,
            };

            //store the song in the contract storage
            self.songs.write(song_id, song);

            self
                .emit(
                    Event::SongPriceUpdated(
                        SongPriceUpdated {
                            song_id: song_id,
                            name: song.name,
                            ipfs_hash: song.ipfs_hash,
                            preview_ipfs_hash: song.preview_ipfs_hash,
                            updated_price: song.price,
                            for_sale: song.for_sale,
                        },
                    ),
                );
        }

        // fn purchase_song(ref self: ContractState, song_id: u64)-> bool{
        //     assert!(song_id !)
        // }

        fn subscribe(ref self: ContractState) -> u64 {
            let caller = get_caller_address();
            assert!(caller != contract_address_const::<0>(), "Invalid caller");

            // get user subscription status
            let user_subscription = self.get_user_subscription(caller);
            let user = self.get_user(caller);
            assert!(
                user.user_id == user_subscription.user_id, "An error occured creating subscription",
            );
            // Check if subscription is not expired
            let current_timestamp = get_block_timestamp();
            assert!(current_timestamp < user_subscription.expiry_date, "Subscription has expired");

            // Check if user has already subscribed
            assert!(!user.has_subscribed, "User has an active subscription");

            let payment = self.pay_stark(SUBSCRIPTION_FEE, caller, get_contract_address());
            assert!(payment == 'PAID', "subscription failed, try again");

            let get_subscription_count = self.get_subscription_count();
            let subscription_id = get_subscription_count + 1;

            self.update_subscription_details(caller);
            self.update_user(caller);

            subscription_id
        }

        fn update_subscription_details(
            ref self: ContractState, user: ContractAddress,
        ) -> UserSubscription {
            let user_subscription = self.get_user_subscription(user);

            let new_subscription = UserSubscription {
                start_date: get_block_timestamp(),
                expiry_date: get_block_timestamp() + (30 * 86400),
                user: user,
                subscription_id: self.get_subscription_count() + 1,
                user_id: user_subscription.user_id,
            };

            self.user_subscription.write(user, new_subscription);
            new_subscription
        }

        fn update_user(ref self: ContractState, caller: ContractAddress) -> User {
            let user = self.get_user(caller);
            let update_user = User {
                user_name: user.user_name,
                user_id: user.user_id,
                user: caller,
                has_subscribed: true,
            };
            self.user.write(caller, update_user);
            update_user
        }

        fn get_user(self: @ContractState, caller: ContractAddress) -> User {
            assert!(caller != contract_address_const::<0>(), "Invalid caller address");
            let user = self.user.read(caller);
            user
        }

        fn get_user_subscription(self: @ContractState, user: ContractAddress) -> UserSubscription {
            assert!(user != contract_address_const::<0>(), "user is invalid, please try again");
            self.user_subscription.read(user)
        }

        fn get_subscription_count(self: @ContractState) -> u64 {
            self.subscription_count.read()
        }

        // TODO: Implement function to get the preview hash of a song
        fn get_preview(self: @ContractState, song_id: u64) -> felt252 {
            // Validate song ID
            let total_songs = self.song_count.read();
            assert!(song_id <= total_songs, "Song ID does not exist");

            // Return preview IPFS hash
            let song = self.songs.read(song_id);
            song.preview_ipfs_hash
        }
        fn set_song_for_sale(ref self: ContractState, song_id: u64) {
            // Validate song ID
            let total_songs = self.song_count.read();
            assert!(song_id <= total_songs, "Song ID does not exist");

            // Check if the caller is the owner of the song
            let caller = get_caller_address();
            let mut song = self.songs.read(song_id);
            assert!(song.owner == caller, "Only the owner can set the song for sale");
            assert!(!song.for_sale, "Song is already for sale");

            // Set the song for sale
            song.for_sale = true;
            self.songs.write(song_id, song);
        }

        // TODO: Implement function to buy a song and transfer ownership
        fn buy_song(ref self: ContractState, song_id: u64) -> felt252 {
            let buyer = get_caller_address();

            let mut song = self.songs.read(song_id);
            assert!(song.for_sale, "Song is not for sale");
            assert!(song.owner != buyer, "You cannot buy your own song");

            let pay_stark = self.pay_stark(song.price, buyer, song.owner);
            assert!(pay_stark == 'PAID', "Payment failed, please try again");

            // Update song mapping
            let old_owner = song.owner;
            self.user_songs.write((old_owner, song_id), false);

            // Add to buyer's collection
            let buyer_song_count = self.user_song_count.read(buyer);
            self.user_songs.write((buyer, song_id), true);
            self.user_song_ids.write((buyer, buyer_song_count), song_id);
            self.user_song_count.write(buyer, buyer_song_count + 1);

            // Transfer ownership
            song.owner = buyer;
            song.for_sale = false;
            self.songs.write(song_id, song);

            // self.ownable.transfer_ownership(buyer);

            song.ipfs_hash
        }

        fn get_user_songs(self: @ContractState, user: ContractAddress) -> Array<u64> {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'ZERO_ADDRESS_CALLER');
            // get the count of songs for the user
            let user_song_count = self.user_song_count.read(user);
            // create an array to store the song IDs
            let mut song_ids = ArrayTrait::new();
            // iterate through the user's songs
            let mut i: u64 = 0;
            while i < user_song_count {
                let song_id = self.user_song_ids.read((user, i));
                song_ids.append(song_id);
                i += 1;
            }

            song_ids
        }

        fn is_song_owner(self: @ContractState, song_id: u64) -> bool {
            // check if the song ID is valid
            let user = get_caller_address();
            assert(!user.is_zero(), 'ZERO_ADDRESS_CALLER');
            assert(!song_id.is_zero(), 'ZERO_SONG_ID');

            // check if the song ID is valid
            let total_songs = self.song_count.read();
            if song_id > total_songs {
                return false;
            }

            // check if the user is the owner of the song
            let song = self.songs.read(song_id);
            song.owner == user
        }

        fn get_all_songs(self: @ContractState) -> Array<Song> {
            let total_songs = self.song_count.read();
            let mut songs = ArrayTrait::new();

            // Iterate through all songs and add them to the array
            let mut i: u64 = 1;
            while i != total_songs + 1 {
                let song = self.songs.read(i);
                songs.append(song);
                i += 1;
            }

            songs
        }

        fn stream_song(ref self: ContractState, song_id: u64) -> felt252 {
            let user = get_caller_address();
            assert(!user.is_zero(), 'ZERO_ADDRESS_CALLER');
            assert(!song_id.is_zero(), 'ZERO_SONG_ID');

            let current_stream_count = self.song_stream_count.read(song_id);
            let song = self.songs.read(song_id);
            assert!(!song.name.is_zero() && !song.ipfs_hash.is_zero(), "Song does not exist");

            let get_user = self.get_user(user);
            assert!(get_user.has_subscribed, "User has not subscribed");

            let user_subscription = self.get_user_subscription(user);
            assert!(user_subscription.expiry_date > get_block_timestamp(), "Subscription expired");

            self.song_stream_count.write(song_id, current_stream_count + 1);

            song.ipfs_hash
        }

        fn get_platform_stats(self: @ContractState) -> PlatformStats {
            PlatformStats {
                total_suscribers: self.subscription_count.read(),
                platform_revenue: self.platform_revenue.read(),
                // total_plays: ,
            }
        }

        fn get_popular_songs_stats(self: @ContractState, limit: u64) -> Array<SongStats> {
            let mut popular_songs = array![];
            let total_songs = self.song_count.read();

            let mut i: u64 = 0;
            while i < total_songs && i < limit {
                let song = self.songs.read(i + 1);
                let song_stats = SongStats {
                    song_id: i + 1, name: song.name, play_count: 0, revenue_generated: 0,
                };
                popular_songs.append(song_stats);
                i += 1;
            }
            popular_songs
        }

        fn get_song_count(self: @ContractState) -> u64 {
            self.song_count.read()
        }

        fn can_stream(self: @ContractState, user: ContractAddress, song_id: u64) -> bool {
            // First check if user owns the song (owners can always stream)
            let song = self.get_song_info(song_id);
            if song.owner == user {
                return true;
            }

            // For non-owners, check subscription status
            let user_subscription = self.get_user_subscription(user);
            let current_timestamp = get_block_timestamp();

            // Check if subscription is active
            if current_timestamp >= user_subscription.expiry_date {
                return false;
            }

            // Check if user has streaming access
            self.streaming_access.read((user, song_id))
        }

        fn log_stream(ref self: ContractState, user: ContractAddress, song_id: u64) {
            // First check if user owns the song (owners can always stream)
            let song = self.get_song_info(song_id);
            if song.owner == user {
                // Increment streaming count
                let current_count = self.streaming_history.read((user, song_id));
                self.streaming_history.write((user, song_id), current_count + 1);

                // Update song stream count
                let song_streams = self.song_stream_count.read(song_id);
                self.song_stream_count.write(song_id, song_streams + 1);
                return;
            }

            // For non-owners, verify subscription and access
            let user_subscription = self.get_user_subscription(user);
            let current_timestamp = get_block_timestamp();

            // Check if subscription is active
            assert!(current_timestamp < user_subscription.expiry_date, "Subscription has expired");

            // Check if user has streaming access
            assert!(self.streaming_access.read((user, song_id)), "User cannot stream this song");

            // Increment streaming count
            let current_count = self.streaming_history.read((user, song_id));
            self.streaming_history.write((user, song_id), current_count + 1);

            // Update song stream count
            let song_streams = self.song_stream_count.read(song_id);
            self.song_stream_count.write(song_id, song_streams + 1);
        }

        fn grant_streaming_access(ref self: ContractState, user: ContractAddress, song_id: u64) {
            // Only song owner can grant streaming access
            let song = self.get_song_info(song_id);
            let caller = get_caller_address();
            assert!(song.owner == caller, "Only song owner can grant streaming access");

            self.streaming_access.write((user, song_id), true);
        }

        fn revoke_streaming_access(ref self: ContractState, user: ContractAddress, song_id: u64) {
            // Only song owner can revoke streaming access
            let song = self.get_song_info(song_id);
            let caller = get_caller_address();
            assert!(song.owner == caller, "Only song owner can revoke streaming access");

            self.streaming_access.write((user, song_id), false);
        }

        fn get_streaming_stats(self: @ContractState, user: ContractAddress, song_id: u64) -> u64 {
            self.streaming_history.read((user, song_id))
        }

        fn renew_subscription(ref self: ContractState) -> u64 {
            let caller = get_caller_address();
            assert!(caller != contract_address_const::<0>(), "Invalid caller");

            // Get user subscription status
            let user_subscription = self.get_user_subscription(caller);
            let user = self.get_user(caller);
            assert!(
                user.user_id == user_subscription.user_id,
                "An error occurred renewing subscription",
            );

            // Get current subscription tier
            let current_tier = self.subscription_tier.read(caller);
            let subscription_fee = if current_tier == 2 {
                PREMIUM_SUBSCRIPTION_FEE
            } else {
                SUBSCRIPTION_FEE
            };

            // Process payment
            let payment = self.pay_stark(subscription_fee, caller, get_contract_address());
            assert!(payment == 'PAID', "subscription renewal failed, try again");

            // Update subscription details
            let new_subscription = UserSubscription {
                start_date: get_block_timestamp(),
                expiry_date: get_block_timestamp() + (30 * 86400),
                user: caller,
                subscription_id: user_subscription.subscription_id,
                user_id: user.user_id,
            };

            self.user_subscription.write(caller, new_subscription);

            // Emit event
            self
                .emit(
                    SubscriptionRenewed {
                        user: caller,
                        subscription_id: new_subscription.subscription_id,
                        expiry_date: new_subscription.expiry_date,
                    },
                );

            new_subscription.subscription_id
        }

        fn upgrade_subscription_tier(ref self: ContractState, new_tier: u8) -> bool {
            let caller = get_caller_address();
            assert!(caller != contract_address_const::<0>(), "Invalid caller");
            assert!(new_tier <= 2, "Invalid subscription tier");

            let current_tier = self.subscription_tier.read(caller);
            if current_tier == new_tier {
                return false;
            }

            // Get user subscription status
            let user_subscription = self.get_user_subscription(caller);
            let current_timestamp = get_block_timestamp();
            assert!(current_timestamp < user_subscription.expiry_date, "Subscription has expired");

            // Calculate upgrade fee
            let upgrade_fee = if new_tier == 2 {
                PREMIUM_SUBSCRIPTION_FEE - SUBSCRIPTION_FEE
            } else {
                0
            };

            if upgrade_fee > 0 {
                let payment = self.pay_stark(upgrade_fee, caller, get_contract_address());
                assert!(payment == 'PAID', "upgrade payment failed");
            }

            // Update subscription tier
            self.subscription_tier.write(caller, new_tier);

            // Emit event
            self
                .emit(
                    SubscriptionTierChanged {
                        user: caller, old_tier: current_tier, new_tier: new_tier,
                    },
                );

            true
        }

        fn get_subscription_tier(self: @ContractState, user: ContractAddress) -> u8 {
            self.subscription_tier.read(user)
        }

        fn distribute_royalties(ref self: ContractState, song_id: u64) -> bool {
            let caller = get_caller_address();
            assert!(caller != contract_address_const::<0>(), "Invalid caller");

            // Get song info
            let song = self.get_song_info(song_id);
            assert!(song.owner != contract_address_const::<0>(), "Invalid song");

            // Calculate total streams
            let total_streams: u64 = self.song_stream_count.read(song_id);
            if total_streams == 0 {
                return false;
            }

            // Calculate revenue based on subscription tier
            let subscription_tier = self.subscription_tier.read(caller);
            let revenue_per_stream = if subscription_tier == 2 {
                SUBSCRIPTION_FEE / 1000 // Premium users generate more revenue
            } else {
                SUBSCRIPTION_FEE / 2000 // Basic users generate less revenue
            };

            // Calculate total revenue and artist's share
            let total_revenue = total_streams.into() * revenue_per_stream;
            let artist_share = (total_revenue * ROYALTY_PERCENTAGE) / 100;

            // Transfer royalties to artist
            let strk_token = IERC20Dispatcher { contract_address: self.token_addr.read() };
            strk_token.transfer(song.owner, artist_share);

            // Update platform revenue
            let platform_share = total_revenue - artist_share;
            let current_revenue = self.platform_revenue.read();
            self.platform_revenue.write(current_revenue + platform_share);

            // Reset stream count
            self.song_stream_count.write(song_id, 0);

            // Emit event
            self
                .emit(
                    RoyaltyDistributed {
                        song_id: song_id,
                        artist: song.owner,
                        amount: artist_share,
                        total_streams: total_streams,
                    },
                );

            true
        }

        fn get_royalty_info(self: @ContractState, song_id: u64) -> (u64, u256) {
            let total_streams: u64 = self.song_stream_count.read(song_id);
            let subscription_tier = self.subscription_tier.read(get_caller_address());
            let revenue_per_stream = if subscription_tier == 2 {
                SUBSCRIPTION_FEE / 1000
            } else {
                SUBSCRIPTION_FEE / 2000
            };
            let total_revenue = total_streams.into() * revenue_per_stream;
            let artist_share = (total_revenue * ROYALTY_PERCENTAGE) / 100;
            (total_streams, artist_share)
        }
    }

    #[generate_trait]
    impl Private of PrivateTrait {
        fn pay_stark(
            ref self: ContractState,
            amount: u256,
            caller: ContractAddress,
            recipient: ContractAddress,
        ) -> felt252 {
            let strk_token = IERC20Dispatcher { contract_address: self.token_addr.read() };

            // Check allowance to ensure the contract can transfer tokens
            let contract_address = get_contract_address();
            let subscriber = get_caller_address();
            let allowed_amount = strk_token.allowance(subscriber, contract_address);
            assert(allowed_amount >= amount, 'Insufficient allowance');

            // Transfer the pool creation fee from creator to the contract
            strk_token.transfer_from(caller, recipient, amount);

            'PAID'
        }
    }
}
