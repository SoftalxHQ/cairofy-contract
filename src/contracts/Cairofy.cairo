// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^1.0.0
#[starknet::contract]
pub mod CairofyV0 {
    use cairofy_contract::events::Events::{Artiste_Created, SongPriceUpdated, Song_Registered};
    use cairofy_contract::interfaces::ICairofy::ICairofy;
    use cairofy_contract::structs::Structs::{
        ArtisteMetadata, PlatformStats, Song, SongStats, User, UserSubscription,
    };
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess, Vec,
    };
    use starknet::{
        ClassHash, ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
        get_contract_address,
    };

    const SUBSCRIPTION_FEE: u256 = 20_000_000_000_000_000_000_000;

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
        artiste: Map<ContractAddress, ArtisteMetadata>,
        artiste_songs: Map<ContractAddress, Vec<Song>>,
        artiste_count: u64,
        platform_revenue: u256,
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
        Artiste_Created: Artiste_Created,
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
        fn register_artiste(
            ref self: ContractState,
            name: felt252,
            description: ByteArray,
            profile_image_uri: felt252,
        ) -> ArtisteMetadata {
            assert!(!name.is_zero(), "The name should not be empty");
            assert!(description.len() != 0, "The description is invalid");
            assert!(!profile_image_uri.is_zero(), "The name should not be empty");

            let caller = get_caller_address();
            let artiste = self.artiste.read(caller);
            assert(
                artiste.name.is_zero() || artiste.description.len() > 5, 'artiste already exist',
            );

            let artiste = ArtisteMetadata {
                name: name,
                contract_address: caller,
                amount_earned: 0,
                profile_image_uri: profile_image_uri,
                creation_date: get_block_timestamp(),
                total_followers: 0,
                total_songs: 0,
                verified: false,
                total_sales: 0,
                highest_sale: 0,
                description: description.clone(),
            };
            self.artiste.write(caller, artiste.clone());

            self
                .emit(
                    Event::Artiste_Created(
                        Artiste_Created {
                            name: name,
                            description: description,
                            creation_date: get_block_timestamp(),
                        },
                    ),
                );

            artiste
        }

        fn register_song(
            ref self: ContractState,
            name: ByteArray,
            ipfs_hash: ByteArray,
            preview_ipfs_hash: ByteArray,
            price: u256,
        ) -> u64 {
            let caller = get_caller_address();

            assert!(name.len() > 0, "Song name cannot be empty");
            assert!(ipfs_hash.len() > 0, "Your song hash cannot be empty");
            assert!(preview_ipfs_hash.len() > 0, "Your song preview hash cannot be empty");
            assert!(price > 0, "Price must be greater than 0");
            // Increment song count and return the new song ID
            let song_id = self.song_count.read() + 1;
            self.song_count.write(song_id);

            let song = Song {
                id: song_id,
                name: name.clone(),
                ipfs_hash: ipfs_hash.clone(),
                preview_ipfs_hash: preview_ipfs_hash.clone(),
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
                ipfs_hash: song.ipfs_hash.clone(),
                preview_ipfs_hash: song.preview_ipfs_hash.clone(),
                price: new_price.clone(),
                owner: caller,
                for_sale: song.for_sale,
            };

            //store the song in the contract storage
            self.songs.write(song_id, song);
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
        fn get_preview(self: @ContractState, song_id: u64) -> ByteArray {
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
        fn buy_song(ref self: ContractState, song_id: u64) {
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

        fn stream_song(ref self: ContractState, song_id: u64) -> ByteArray {
            let user = get_caller_address();
            assert(!user.is_zero(), 'ZERO_ADDRESS_CALLER');
            assert(!song_id.is_zero(), 'ZERO_SONG_ID');

            let current_stream_count = self.song_stream_count.read(song_id);
            let song = self.songs.read(song_id);
            assert!(song.name.len() == 0 && song.ipfs_hash.len() != 0, "Song does not exist");

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
