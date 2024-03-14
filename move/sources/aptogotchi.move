module aptogotchi::main {
    use aptogotchi::food;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::object::{Self, ExtendRef};
    use aptos_framework::timestamp;
    use aptos_std::string_utils::{to_string};
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use std::error;
    use std::option;
    use std::signer::address_of;
    use std::string::{Self, String};
    use std::vector;

    /// aptogotchi not available
    const ENOT_AVAILABLE: u64 = 1;
    /// accessory not available
    const EACCESSORY_NOT_AVAILABLE: u64 = 1;
    const EPARTS_LIMIT: u64 = 2;
    const ENAME_LIMIT: u64 = 3;
    const EUSER_ALREADY_HAS_APTOGOTCHI: u64 = 4;


    // maximum health points: 5 hearts * 2 HP/heart = 10 HP
    const ENERGY_UPPER_BOUND: u64 = 10;
    const NAME_UPPER_BOUND: u64 = 40;
    const PARTS_SIZE: u64 = 3;
    const UNIT_PRICE: u64 = 100000000;

    #[event]
    struct MintAptogotchiEvent has drop, store {
        aptogotchi_name: String,
        parts: vector<u8>,
    }

    struct Aptogotchi has key {
        name: String,
        birthday: u64,
        energy_points: u64,
        parts: vector<u8>,
        mutator_ref: token::MutatorRef,
        burn_ref: token::BurnRef,
    }

    struct Accessory has key {
        category: String,
        id: u64,
    }

    // We need a contract signer as the creator of the aptogotchi collection and aptogotchi token
    // Otherwise we need admin to sign whenever a new aptogotchi token is minted which is inconvenient
    struct ObjectController has key {
        // This is the extend_ref of the app object, not the extend_ref of collection object or token object
        // app object is the creator and owner of aptogotchi collection object
        // app object is also the creator of all aptogotchi token (NFT) objects
        // but owner of each token object is aptogotchi owner (i.e. user who mints aptogotchi)
        app_extend_ref: ExtendRef,
    }

    const APP_OBJECT_SEED: vector<u8> = b"APTOGOTCHI";
    const APTOGOTCHI_COLLECTION_NAME: vector<u8> = b"Aptogotchi Collection";
    const APTOGOTCHI_COLLECTION_DESCRIPTION: vector<u8> = b"Aptogotchi Collection Description";
    const APTOGOTCHI_COLLECTION_URI: vector<u8> = b"https://otjbxblyfunmfblzdegw.supabase.co/storage/v1/object/public/aptogotchi/aptogotchi.png";

    const ACCESSORY_COLLECTION_NAME: vector<u8> = b"Aptogotchi Accessory Collection";
    const ACCESSORY_COLLECTION_DESCRIPTION: vector<u8> = b"Aptogotchi Accessories";
    const ACCESSORY_COLLECTION_URI: vector<u8> = b"https://otjbxblyfunmfblzdegw.supabase.co/storage/v1/object/public/aptogotchi/bowtie.png";

    const ACCESSORY_CATEGORY_BOWTIE: vector<u8> = b"bowtie";

    // This function is only callable during publishing
    fun init_module(account: &signer) {
        let constructor_ref = &object::create_named_object(account, APP_OBJECT_SEED);
        let extend_ref = object::generate_extend_ref(constructor_ref);
        let app_signer = &object::generate_signer(constructor_ref);

        move_to(app_signer, ObjectController {
            app_extend_ref: extend_ref,
        });

        create_aptogotchi_collection(app_signer);
        create_accessory_collection(app_signer);
    }

    fun get_app_signer_address(): address {
        object::create_object_address(&@aptogotchi, APP_OBJECT_SEED)
    }

    fun get_app_signer(app_signer_address: address): signer acquires ObjectController {
        object::generate_signer_for_extending(&borrow_global<ObjectController>(app_signer_address).app_extend_ref)
    }

    // Create the collection that will hold all the Aptogotchis
    fun create_aptogotchi_collection(creator: &signer) {
        let description = string::utf8(APTOGOTCHI_COLLECTION_DESCRIPTION);
        let name = string::utf8(APTOGOTCHI_COLLECTION_NAME);
        let uri = string::utf8(APTOGOTCHI_COLLECTION_URI);

        collection::create_unlimited_collection(
            creator,
            description,
            name,
            option::none(),
            uri,
        );
    }

    // Create the collection that will hold all the accessories
    fun create_accessory_collection(creator: &signer) {
        let description = string::utf8(ACCESSORY_COLLECTION_DESCRIPTION);
        let name = string::utf8(ACCESSORY_COLLECTION_NAME);
        let uri = string::utf8(ACCESSORY_COLLECTION_URI);

        collection::create_unlimited_collection(
            creator,
            description,
            name,
            option::none(),
            uri,
        );
    }

    // Create an Aptogotchi token object
    public entry fun create_aptogotchi(user: &signer, name: String, parts: vector<u8>) acquires ObjectController {
        assert!(vector::length(&parts) == PARTS_SIZE, error::invalid_argument(EPARTS_LIMIT));
        assert!(string::length(&name) <= NAME_UPPER_BOUND, error::invalid_argument(ENAME_LIMIT));
        let uri = string::utf8(APTOGOTCHI_COLLECTION_URI);
        let description = string::utf8(APTOGOTCHI_COLLECTION_DESCRIPTION);
        let user_addr = address_of(user);
        assert!(!has_aptogotchi(user_addr), error::already_exists(EUSER_ALREADY_HAS_APTOGOTCHI));

        let constructor_ref = token::create_named_token(
            &get_app_signer(get_app_signer_address()),
            string::utf8(APTOGOTCHI_COLLECTION_NAME),
            description,
            get_aptogotchi_token_name(&address_of(user)),
            option::none(),
            uri,
        );

        let token_signer = object::generate_signer(&constructor_ref);
        let mutator_ref = token::generate_mutator_ref(&constructor_ref);
        let burn_ref = token::generate_burn_ref(&constructor_ref);
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);

        // initialize/set default Aptogotchi struct values
        let gotchi = Aptogotchi {
            name,
            birthday: timestamp::now_seconds(),
            energy_points: ENERGY_UPPER_BOUND,
            parts,
            mutator_ref,
            burn_ref,
        };

        move_to(&token_signer, gotchi);

        // Emit event for minting Aptogotchi token
        event::emit<MintAptogotchiEvent>(
            MintAptogotchiEvent {
                aptogotchi_name: name,
                parts,
            },
        );

        object::transfer_with_ref(object::generate_linear_transfer_ref(&transfer_ref), address_of(user));
    }

    // Get reference to Aptogotchi token object (CAN'T modify the reference)
    fun get_aptogotchi_address(creator_addr: &address): (address) {
        let token_address = token::create_token_address(
            &get_app_signer_address(),
            &string::utf8(APTOGOTCHI_COLLECTION_NAME),
            &get_aptogotchi_token_name(creator_addr),
        );

        token_address
    }

    // Returns true if this address owns an Aptogotchi
    #[view]
    public fun has_aptogotchi(owner_addr: address): (bool) {
        let token_address = get_aptogotchi_address(&owner_addr);

        exists<Aptogotchi>(token_address)
    }

    // Returns all fields for this Aptogotchi (if found)
    #[view]
    public fun get_aptogotchi(owner_addr: address): (String, u64, u64, vector<u8>) acquires Aptogotchi {
        // if this address doesn't have an Aptogotchi, throw error
        assert!(has_aptogotchi(owner_addr), error::unavailable(ENOT_AVAILABLE));

        let token_address = get_aptogotchi_address(&owner_addr);
        let gotchi = borrow_global_mut<Aptogotchi>(token_address);

        // view function can only return primitive types.
        (gotchi.name, gotchi.birthday, gotchi.energy_points, gotchi.parts)
    }

    #[view]
    public fun get_energy_points(owner_addr: address): u64 acquires Aptogotchi {
        assert!(has_aptogotchi(owner_addr), error::unavailable(ENOT_AVAILABLE));

        let token_address = get_aptogotchi_address(&owner_addr);
        let gotchi = borrow_global<Aptogotchi>(token_address);

        gotchi.energy_points
    }

    public entry fun buy_food(owner: &signer, amount: u64) {
        // charge price for food
        coin::transfer<AptosCoin>(owner, @aptogotchi, UNIT_PRICE * amount);
        food::mint_food(owner, amount);
    }

    public entry fun feed(owner: &signer, points: u64) acquires Aptogotchi {
        let owner_addr = address_of(owner);
        assert!(has_aptogotchi(owner_addr), error::unavailable(ENOT_AVAILABLE));

        let token_address = get_aptogotchi_address(&owner_addr);
        let gotchi = borrow_global_mut<Aptogotchi>(token_address);

        food::burn_food(owner, points);

        gotchi.energy_points = if (gotchi.energy_points + points > ENERGY_UPPER_BOUND) {
            ENERGY_UPPER_BOUND
        } else {
            gotchi.energy_points + points
        };

        gotchi.energy_points;
    }

    public entry fun play(owner: &signer, points: u64) acquires Aptogotchi {
        let owner_addr = address_of(owner);
        assert!(has_aptogotchi(owner_addr), error::unavailable(ENOT_AVAILABLE));

        let token_address = get_aptogotchi_address(&owner_addr);
        let gotchi = borrow_global_mut<Aptogotchi>(token_address);

        gotchi.energy_points = if (gotchi.energy_points < points) {
            0
        } else {
            gotchi.energy_points - points
        };

        gotchi.energy_points;
    }

    // ==== ACCESSORIES ====
    // Create an Aptogotchi token object
    public entry fun create_accessory(user: &signer, category: String) acquires ObjectController {
        let uri = string::utf8(ACCESSORY_COLLECTION_URI);
        let description = string::utf8(ACCESSORY_COLLECTION_DESCRIPTION);

        let constructor_ref = token::create_named_token(
            &get_app_signer(get_app_signer_address()),
            string::utf8(ACCESSORY_COLLECTION_NAME),
            description,
            get_accessory_token_name(&address_of(user), category),
            option::none(),
            uri,
        );

        let token_signer = object::generate_signer(&constructor_ref);
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let category = string::utf8(ACCESSORY_CATEGORY_BOWTIE);
        let id = 1;

        let accessory = Accessory {
            category,
            id,
        };

        move_to(&token_signer, accessory);
        object::transfer_with_ref(object::generate_linear_transfer_ref(&transfer_ref), address_of(user));
    }

    public entry fun wear_accessory(owner: &signer, category: String) acquires ObjectController {
        let owner_addr = &address_of(owner);
        // retrieve the aptogotchi object
        let token_address = get_aptogotchi_address(owner_addr);
        let gotchi = object::address_to_object<Aptogotchi>(token_address);

        // retrieve the accessory object by category
        let accessory_address = get_accessory_address(owner_addr, category);
        let accessory = object::address_to_object<Accessory>(accessory_address);

        object::transfer_to_object(owner, accessory, gotchi);
    }

    #[view]
    public fun has_accessory(owner: &signer, category: String): bool acquires ObjectController {
        let owner_addr = &address_of(owner);
        // retrieve the accessory object by category
        let accessory_address = get_accessory_address(owner_addr, category);

        exists<Accessory>(accessory_address)
    }

    public entry fun unwear_accessory(owner: &signer, category: String) acquires ObjectController {
        let owner_addr = &address_of(owner);

        // retrieve the accessory object by category
        let accessory_address = get_accessory_address(owner_addr, category);
        let has_accessory = exists<Accessory>(accessory_address);
        if (has_accessory == false) {
            assert!(false, error::unavailable(EACCESSORY_NOT_AVAILABLE));
        };
        let accessory = object::address_to_object<Accessory>(accessory_address);

        object::transfer(owner, accessory, address_of(owner));
    }

    fun get_aptogotchi_token_name(owner_addr: &address): String {
        let token_name = string::utf8(b"aptogotchi");
        string::append(&mut token_name, to_string(owner_addr));

        token_name
    }

    fun get_accessory_token_name(owner_addr: &address, category: String): String {
        let token_name = category;
        string::append(&mut token_name, to_string(owner_addr));

        token_name
    }

    fun get_accessory_address(creator_addr: &address, category: String): (address) acquires ObjectController {
        let collection = string::utf8(ACCESSORY_COLLECTION_NAME);
        let token_name = category;
        string::append(&mut token_name, to_string(creator_addr));
        let creator = &get_app_signer(get_app_signer_address());

        let token_address = token::create_token_address(
            &address_of(creator),
            &collection,
            &get_accessory_token_name(creator_addr, category),
        );

        token_address
    }

    // ==== TESTS ====
    // Setup testing environment
    #[test_only]
    use aptos_framework::account::create_account_for_test;
    #[test_only]
    use aptos_framework::aptos_coin;

    #[test_only]
    fun setup_test(aptos: &signer, account: &signer, creator: &signer) {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos);

        // create fake accounts (only for testing purposes) and deposit initial balance

        create_account_for_test(address_of(account));
        coin::register<AptosCoin>(account);

        let creator_addr = address_of(creator);
        create_account_for_test(address_of(creator));
        coin::register<AptosCoin>(creator);
        let coins = coin::mint(3 * UNIT_PRICE, &mint_cap);
        coin::deposit(creator_addr, coins);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        timestamp::set_time_has_started_for_testing(aptos);
        init_module(account);
    }

    // Test creating an Aptogotchi
    #[test(aptos = @0x1, account = @aptogotchi, creator = @0x123)]
    fun test_create_aptogotchi(aptos: &signer, account: &signer, creator: &signer) acquires ObjectController {
        setup_test(aptos, account, creator);

        create_aptogotchi(creator, string::utf8(b"test"), vector[1, 1, 1]);

        let has_aptogotchi = has_aptogotchi(address_of(creator));
        assert!(has_aptogotchi, 1);
    }

    // Test getting an Aptogotchi, when user has not minted
    #[test(aptos = @0x1, account = @aptogotchi, creator = @0x123)]
    #[expected_failure(abort_code = 851969, location = aptogotchi::main)]
    fun test_get_aptogotchi_without_creation(
        aptos: &signer,
        account: &signer,
        creator: &signer
    ) acquires Aptogotchi {
        setup_test(aptos, account, creator);

        // get aptogotchi without creating it
        get_aptogotchi(address_of(creator));
    }

    #[test(aptos = @0x1, account = @aptogotchi, creator = @0x123)]
    fun test_feed_and_play(aptos: &signer, account: &signer, creator: &signer) acquires ObjectController, Aptogotchi {
        setup_test(aptos, account, creator);
        food::init_module_for_test(account);

        let creator_addr = address_of(creator);
        let account_addr = address_of(account);

        create_aptogotchi(creator, string::utf8(b"test"), vector[1, 1, 1]);
        assert!(get_energy_points(creator_addr) == ENERGY_UPPER_BOUND, 1);

        play(creator, 5);
        assert!(get_energy_points(creator_addr) == ENERGY_UPPER_BOUND - 5, 1);

        assert!(coin::balance<AptosCoin>(creator_addr) == 3 * UNIT_PRICE, 1);
        assert!(coin::balance<AptosCoin>(account_addr) == 0, 1);
        buy_food(creator, 3);
        assert!(coin::balance<AptosCoin>(creator_addr) == 0, 1);
        assert!(coin::balance<AptosCoin>(account_addr) == 3 * UNIT_PRICE, 1);
        feed(creator, 3);
        assert!(get_energy_points(address_of(creator)) == ENERGY_UPPER_BOUND - 2, 1);
    }

    #[test(aptos = @0x1, account = @aptogotchi, creator = @0x123)]
    #[expected_failure(abort_code = 393218, location = 0x1::object)]
    fun test_feed_with_no_food(aptos: &signer, account: &signer, creator: &signer) acquires ObjectController, Aptogotchi {
        setup_test(aptos, account, creator);
        food::init_module_for_test(account);

        create_aptogotchi(creator, string::utf8(b"test"), vector[1, 1, 1]);
        assert!(get_energy_points(address_of(creator)) == ENERGY_UPPER_BOUND, 1);

        play(creator, 5);
        assert!(get_energy_points(address_of(creator)) == ENERGY_UPPER_BOUND - 5, 1);

        feed(creator, 3);
        assert!(get_energy_points(address_of(creator)) == ENERGY_UPPER_BOUND - 2, 1);
    }

    #[test(aptos = @0x1, account = @aptogotchi, creator = @0x123)]
    fun test_create_accessory(aptos: &signer, account: &signer, creator: &signer) acquires ObjectController, Accessory {
        setup_test(aptos, account, creator);
        let creator_address = &address_of(creator);

        create_aptogotchi(creator, string::utf8(b"test"), vector[1, 1, 1]);
        create_accessory(creator, string::utf8(ACCESSORY_CATEGORY_BOWTIE));
        let accessory_address = get_accessory_address(creator_address, string::utf8(ACCESSORY_CATEGORY_BOWTIE));

        let accessory = borrow_global<Accessory>(accessory_address);

        assert!(accessory.category == string::utf8(ACCESSORY_CATEGORY_BOWTIE), 1);
    }

    #[test(aptos = @0x1, account = @aptogotchi, creator = @0x123)]
    fun test_wear_accessory(aptos: &signer, account: &signer, creator: &signer) acquires ObjectController {
        setup_test(aptos, account, creator);
        let creator_address = &address_of(creator);

        create_aptogotchi(creator, string::utf8(b"test"), vector[1, 1, 1]);
        create_accessory(creator, string::utf8(ACCESSORY_CATEGORY_BOWTIE));
        let accessory_address = get_accessory_address(creator_address, string::utf8(ACCESSORY_CATEGORY_BOWTIE));
        let aptogotchi_address = get_aptogotchi_address(creator_address);

        let accessory_obj = object::address_to_object<Accessory>(accessory_address);
        assert!(object::is_owner(accessory_obj, address_of(creator)), 2);

        wear_accessory(creator, string::utf8(ACCESSORY_CATEGORY_BOWTIE));
        assert!(object::is_owner(accessory_obj, aptogotchi_address), 3);

        unwear_accessory(creator, string::utf8(ACCESSORY_CATEGORY_BOWTIE));
        assert!(object::is_owner(accessory_obj, address_of(creator)), 4);
    }

    // Test getting an Aptogotchi, when user has not minted
    #[test(aptos = @0x1, account = @aptogotchi, creator = @0x123)]
    #[expected_failure(abort_code = 524292, location = aptogotchi::main)]
    fun test_create_aptogotchi_twice(
        aptos: &signer,
        account: &signer,
        creator: &signer
    ) acquires ObjectController {
        setup_test(aptos, account, creator);

        create_aptogotchi(creator, string::utf8(b"test"), vector[1, 1, 1]);
        create_aptogotchi(creator, string::utf8(b"test"), vector[1, 1, 1]);
    }
}
