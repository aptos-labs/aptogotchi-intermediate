module aptogotchi::food {
    use aptos_framework::fungible_asset::{Self, MintRef, BurnRef};
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::primary_fungible_store;
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use std::option;
    use std::signer::address_of;
    use std::string::Self;

    const APP_OBJECT_SEED: vector<u8> = b"APTOGOTCHI_FOOD";
    /// The food collection name
    const FOOD_COLLECTION_NAME: vector<u8> = b"Food Collection Name";
    /// The food collection description
    const FOOD_COLLECTION_DESCRIPTION: vector<u8> = b"Food Collection Description";
    /// The food collection URI
    const FOOD_COLLECTION_URI: vector<u8> = b"https://food.collection.uri";
    const FOOD_DESCRIPTION: vector<u8> = b"Food Description";
    const FOOD_URI: vector<u8> = b"https://otjbxblyfunmfblzdegw.supabase.co/storage/v1/object/public/aptogotchi/food.png";
    const FOOD_NAME: vector<u8> = b"Food";
    const FOOD_SYMBOL: vector<u8> = b"FOOD";
    const PROJECT_URI: vector<u8> = b"https://www.aptoslabs.com";

    // Tokens require a signer to create, so this is the signer for the collection
    struct AppCapability has key {
        extend_ref: ExtendRef,
    }

    struct FoodToken has key {
        /// Used to mint fungible assets.
        fungible_asset_mint_ref: MintRef,
        /// Used to burn fungible assets.
        fungible_asset_burn_ref: BurnRef,
    }

    fun init_module(account: &signer) {
        let constructor_ref = &object::create_named_object(account, APP_OBJECT_SEED);
        let extend_ref = object::generate_extend_ref(constructor_ref);
        let app_signer = &object::generate_signer(constructor_ref);

        move_to(app_signer, AppCapability {
            extend_ref,
        });

        create_food_collection(app_signer);
        create_food_token(app_signer);
    }

    fun get_app_signer_address(): address {
        object::create_object_address(&@aptogotchi, APP_OBJECT_SEED)
    }

    fun get_app_signer(app_signer_address: address): signer acquires AppCapability {
        object::generate_signer_for_extending(&borrow_global<AppCapability>(app_signer_address).extend_ref)
    }

    /// Creates the food collection.
    fun create_food_collection(creator: &signer) {
        collection::create_unlimited_collection(
            creator,
            string::utf8(FOOD_COLLECTION_DESCRIPTION),
            string::utf8(FOOD_COLLECTION_NAME),
            option::none(),
            string::utf8(FOOD_COLLECTION_URI),
        );
    }

    /// Creates the food token as fungible token.
    fun create_food_token(creator: &signer) {
        let constructor_ref = &token::create_named_token(
            creator,
            string::utf8(FOOD_COLLECTION_NAME),
            string::utf8(FOOD_DESCRIPTION),
            string::utf8(FOOD_NAME),
            option::none(),
            string::utf8(FOOD_URI),
        );

        // Creates the fungible asset.
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            string::utf8(FOOD_NAME),
            string::utf8(FOOD_SYMBOL),
            0,
            string::utf8(FOOD_URI),
            string::utf8(PROJECT_URI),
        );
        let fungible_asset_mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let fungible_asset_burn_ref = fungible_asset::generate_burn_ref(constructor_ref);

        let food_token_signer = &object::generate_signer(constructor_ref);
        // Publishes the FoodToken resource with the refs.
        move_to(food_token_signer, FoodToken {
            fungible_asset_mint_ref,
            fungible_asset_burn_ref,
        });
    }

    #[view]
    public fun get_food_token_address(): address {
        token::create_token_address(
            &get_app_signer_address(),
            &string::utf8(FOOD_COLLECTION_NAME),
            &string::utf8(FOOD_NAME),
        )
    }

    #[view]
    /// Returns the balance of the food token of the owner
    public fun food_balance(owner_addr: address, food: Object<FoodToken>): u64 {
        // should remove this function when re-publish the contract to the final address
        // this function is replaced by get_food_balance
        primary_fungible_store::balance(owner_addr, food)
    }

    #[view]
    /// Returns the balance of the food token of the owner
    public fun get_food_balance(owner_addr: address): u64 {
        let food_token = object::address_to_object<FoodToken>(get_food_token_address());
        primary_fungible_store::balance(owner_addr, food_token)
    }

    // Warning: There is a vulnerability here where an attacker can directly invoke mint_food and mint any amount of token.
    // To fix this issue, we advise modifying both the `burn_food` and `mint_food` functions to `public(friend)`, as well as adding `aptogotchi.move` as a `friend` module. 
    public fun mint_food(user: &signer, amount: u64) acquires FoodToken {
        let food_token = borrow_global<FoodToken>(get_food_token_address());
        let fungible_asset_mint_ref = &food_token.fungible_asset_mint_ref;
        primary_fungible_store::deposit(
            address_of(user),
            fungible_asset::mint(fungible_asset_mint_ref, amount),
        );
    }

    public fun burn_food(user: &signer, amount: u64) acquires FoodToken {
        let food_token = borrow_global<FoodToken>(get_food_token_address());
        primary_fungible_store::burn(&food_token.fungible_asset_burn_ref, address_of(user), amount);
    }

    #[test_only]
    use aptos_framework::account::create_account_for_test;

    #[test_only]
    public fun init_module_for_test(creator: &signer) {
        init_module(creator);
    }

    #[test(account = @aptogotchi, creator = @0x123)]
    fun test_food(account: &signer, creator: &signer) acquires FoodToken {
        init_module(account);
        create_account_for_test(address_of(creator));

        mint_food(creator, 1);
        assert!(get_food_balance(address_of(creator)) == 1, 0);

        burn_food(creator, 1);
        assert!(get_food_balance(address_of(creator)) == 0, 0);
    }
}

