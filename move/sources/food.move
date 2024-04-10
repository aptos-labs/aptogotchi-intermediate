module aptogotchi_addr::food {
    use aptos_framework::fungible_asset::{Self, MintRef, BurnRef};
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::primary_fungible_store;
    use std::option;
    use std::signer::address_of;
    use std::string::Self;
    // declare main module as a friend so only it can call mint_food and burn_food, but not other modules
    friend aptogotchi_addr::main;

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

    // We need a contract signer as the creator of the food collection and food token
    // Otherwise we need admin to sign whenever a new food token is minted which is inconvenient
    struct ObjectController has key {
        // This is the extend_ref of the app object, not the extend_ref of food collection object or food token object
        // app object is the creator and owner of food collection object
        // app object is also the creator of all food token (ERC-1155 like semi fungible token) objects
        // but owner of each food token object is aptogotchi owner
        app_extend_ref: ExtendRef,
    }

    struct FoodController has key {
        /// Used to mint fungible assets.
        fungible_asset_mint_ref: MintRef,
        /// Used to burn fungible assets.
        fungible_asset_burn_ref: BurnRef,
    }

    fun init_module(account: &signer) {
        let constructor_ref = &object::create_named_object(account, APP_OBJECT_SEED);
        let extend_ref = object::generate_extend_ref(constructor_ref);
        let app_signer = &object::generate_signer(constructor_ref);

        move_to(app_signer, ObjectController {
            app_extend_ref: extend_ref,
        });

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

        // Publishes the FoodController resource with the refs.
        move_to(app_signer, FoodController {
            fungible_asset_mint_ref,
            fungible_asset_burn_ref,
        });
    }

    fun get_app_signer_address(): address {
        object::create_object_address(&@aptogotchi_addr, APP_OBJECT_SEED)
    }

    fun get_app_signer(app_signer_address: address): signer acquires ObjectController {
        object::generate_signer_for_extending(&borrow_global<ObjectController>(app_signer_address).app_extend_ref)
    }

    public(friend) fun mint_food(user: &signer, amount: u64) acquires FoodController {
        let food_controller = borrow_global<FoodController>(get_app_signer_address());
        let fungible_asset_mint_ref = &food_controller.fungible_asset_mint_ref;
        primary_fungible_store::deposit(
            address_of(user),
            fungible_asset::mint(fungible_asset_mint_ref, amount),
        );
    }

    public(friend) fun burn_food(user: &signer, amount: u64) acquires FoodController {
        let food_controller = borrow_global<FoodController>(get_app_signer_address());
        primary_fungible_store::burn(&food_controller.fungible_asset_burn_ref, address_of(user), amount);
    }

    #[view]
    /// Returns the balance of the food token of the owner
    public fun food_balance(owner_addr: address, food: Object<FoodController>): u64 {
        // should remove this function when re-publish the contract to the final address
        // this function is replaced by get_food_balance
        primary_fungible_store::balance(owner_addr, food)
    }

    #[view]
    /// Returns the balance of the food token of the owner
    public fun get_food_balance(owner_addr: address): u64 {
        let food_controller = object::address_to_object<FoodController>(get_app_signer_address());
        primary_fungible_store::balance(owner_addr, food_controller)
    }

    #[test_only]
    use aptos_framework::account::create_account_for_test;

    #[test_only]
    public fun init_module_for_test(creator: &signer) {
        init_module(creator);
    }

    #[test(account = @aptogotchi_addr, creator = @0x123)]
    fun test_food(account: &signer, creator: &signer) acquires FoodController {
        init_module(account);
        create_account_for_test(address_of(creator));

        mint_food(creator, 1);
        assert!(get_food_balance(address_of(creator)) == 1, 0);

        burn_food(creator, 1);
        assert!(get_food_balance(address_of(creator)) == 0, 0);
    }
}

