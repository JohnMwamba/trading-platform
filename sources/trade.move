#[allow(lint(self_transfer))] // Allow self-transfer lint
module trade::trade { // Define the module trade::trade
    use sui::tx_context::{sender}; // Import the sender function from sui::tx_context
    use sui::coin::{Self, Coin, CoinMetadata}; // Import Coin, CoinMetadata from sui::coin
    use sui::balance::{Self, Balance}; // Import Balance from sui::balance
    use sui::bag::{Self, Bag}; // Import Bag from sui::bag
    use sui::clock::{Self, Clock,}; // Import Clock, timestamp_ms from sui::clock
    use std::string::{Self, String}; // Import String from std::string

    /// Error Constants ///
    #[allow(unused_const)]
    const EInsufficientFunds: u64 = 1; // Error code for insufficient funds
    #[allow(unused_const)]
    const EInvalidCap: u64 = 4; // Error code for invalid cap

    const PERFORMANCE_FEE_RATE: u128 = 10; // Performance fee rate in percentage

    // Type that stores trader account data:
    public struct TraderAccount<phantom COIN> has key { // Define TraderAccount struct with a phantom type parameter COIN and key ability
        id: UID, // Unique identifier for the trader
        trader_address: address,  // Address of the trader
        join_date: u64, // Timestamp of when the trader joined
        last_trade_date: u64, // Timestamp of the last trade
        total_followers: u64, // Total number of followers
        total_trades: u64, // Total number of trades executed by the trader
        total_profit: u64, // Total profit earned by the trader
    }
    
    // Type that represents the trading platform:
    public struct TradingPlatform<phantom COIN> has key, store { // Define TradingPlatform struct with a phantom type parameter COIN and key, store abilities
        id: UID, // Unique identifier for the trading platform
        inner: ID, // Internal ID for the platform
        balance: Bag, // Bag containing the platform's balance
        performance_fee_rate: u64 // Performance fee rate applied to profits
    }

    public struct TradingPlatformCap has key { // Define TradingPlatformCap struct with key ability
        id: UID, // Unique identifier for the cap
        platform: ID // Internal ID of the associated trading platform
    }

    public struct Protocol has key, store { // Define Protocol struct with key, store abilities
        id: UID, // Unique identifier
        balance: Bag // Bag containing the protocol's balance
    }

    public struct AdminCap has key { // Define AdminCap struct with key ability
        id: UID // Unique identifier
    }

    /// Create a new trading platform.
    public fun new_trading_platform<COIN>(performance_fee_rate: u64, ctx: &mut TxContext) { // Function to create a new trading platform
        let id_ = object::new(ctx); // Create a new unique identifier
        let inner_ = object::uid_to_inner(&id_); // Convert UID to inner ID
        transfer::share_object(TradingPlatform<COIN> { // Share TradingPlatform object
            id: id_, // Set ID
            inner: inner_, // Set inner ID
            balance: bag::new(ctx), // Initialize balance as a new bag
            performance_fee_rate: performance_fee_rate // Set performance fee rate
        });
        transfer::transfer(TradingPlatformCap{id: object::new(ctx), platform: inner_}, sender(ctx)); // Transfer TradingPlatformCap to the caller
    }

    // Execute a trade by a trader.
    public fun execute_trade<COIN>( // Function to execute a trade
        protocol: &mut Protocol, // Reference to the protocol
        trading_platform: &mut TradingPlatform<COIN>, // Reference to the trading platform
        clock: &Clock, // Reference to the clock
        coin_metadata: &CoinMetadata<COIN>, // Reference to the coin metadata
        mut coin: Coin<COIN>, // Mutable reference to the coin
        ctx: &mut TxContext // Reference to the transaction context
    ) : TraderAccount<COIN> { // Returns a TraderAccount
        let trade_value = coin::value(&coin); // Get the value of the coin
        let performance_fee = ((trade_value as u128) * PERFORMANCE_FEE_RATE / 100) as u64; // Calculate the performance fee
        assert!(trade_value >= performance_fee, EInsufficientFunds); // Check if trade value is sufficient to cover the fee

        let protocol_fee = performance_fee; // Set protocol fee to performance fee
        let protocol_fee_coin = coin::split(&mut coin, protocol_fee, ctx); // Split the coin for the protocol fee
        let protocol_balance = coin::into_balance(protocol_fee_coin); // Convert protocol fee to balance
        let trader_balance = coin::into_balance(coin); // Convert remaining coin to balance

        let protocol_bag = &mut protocol.balance; // Get protocol's balance bag
        let trading_platform_bag = &mut trading_platform.balance; // Get trading platform's balance bag

        let _name = coin::get_name(coin_metadata); // Get the coin name
        let coin_names = string::utf8(b"coins"); // Convert byte string to UTF-8 string

        helper_bag(protocol_bag, coin_names, protocol_balance); // Update protocol bag with protocol balance
        helper_bag(trading_platform_bag, coin_names, trader_balance); // Update trading platform bag with trader's balance

        let id_ = object::new(ctx); // Create a new unique identifier
        let trader_account = TraderAccount { // Create a new TraderAccount
            id: id_, // Set ID
            trader_address: sender(ctx), // Set trader address to sender
            join_date: clock::timestamp_ms(clock), // Set join date to current timestamp
            last_trade_date: clock::timestamp_ms(clock), // Set last trade date to current timestamp
            total_followers: 0, // Initialize total followers to 0
            total_trades: 1, // Initialize total trades to 1 (since this is the first trade)
            total_profit: trade_value - performance_fee, // Set total profit earned by the trader
        };
        trader_account // Return the TraderAccount
    }

    // Replicate a trader's trade.
    public fun replicate_trade<COIN>( // Function to replicate a trader's trade
        protocol: &mut Protocol, // Reference to the protocol
        trading_platform: &mut TradingPlatform<COIN>, // Reference to the trading platform
        trader_account: &mut TraderAccount<COIN>, // Reference to the trader account whose trade is being replicated
        coin_metadata: &CoinMetadata<COIN>, // Reference to the coin metadata
        mut coin: Coin<COIN>, // Mutable reference to the coin
        ctx: &mut TxContext // Reference to the transaction context
    ) {
        let trade_value = coin::value(&coin); // Get the value of the coin
        let performance_fee = ((trade_value as u128) * PERFORMANCE_FEE_RATE / 100) as u64; // Calculate the performance fee
        assert!(trade_value >= performance_fee, EInsufficientFunds); // Check if trade value is sufficient to cover the fee

        let protocol_fee = performance_fee; // Set protocol fee to performance fee
        let protocol_fee_coin = coin::split(&mut coin, protocol_fee, ctx); // Split the coin for the protocol fee
        let protocol_balance = coin::into_balance(protocol_fee_coin); // Convert protocol fee to balance
        let follower_balance = coin::into_balance(coin); // Convert remaining coin to balance

        let protocol_bag = &mut protocol.balance; // Get protocol's balance bag
        let trading_platform_bag = &mut trading_platform.balance; // Get trading platform's balance bag

        let _coin_name = coin::get_name(coin_metadata); // Get the coin name
        let coin_names = string::utf8(b"coins"); // Convert byte string to UTF-8 string

        helper_bag(protocol_bag, coin_names, protocol_balance); // Update protocol bag with protocol balance
        helper_bag(trading_platform_bag, coin_names, follower_balance); // Update trading platform bag with follower's balance

        trader_account.total_followers +1; // Increment total followers of the trader
        trader_account.total_trades +1; // Increment total trades of the trader
        trader_account.total_profit = trade_value - performance_fee; // Update total profit earned by the trader
        //trader_account.last_trade_date timestamp_ms(clock); // Update last trade date to current timestamp
    }

    // Function to calculate profits distributed to followers
    public fun distribute_profits<COIN>( // Function to distribute profits to followers
        _protocol: &mut Protocol, // Reference to the protocol
        _trading_platform: &mut TradingPlatform<COIN>, // Reference to the trading platform
        trader_account: &mut TraderAccount<COIN>, // Reference to the trader account
        _ctx: &mut TxContext // Reference to the transaction context
    ) {
        // Calculate profits based on trader's total profit and follower count
        let _total_profit = trader_account.total_profit;
        let _total_followers = trader_account.total_followers;

        
    }

    // Example accessor function for fetching trader's account details
    public fun get_trader_join_date<COIN>(self: &TraderAccount<COIN>): u64 { // Get trader join date
        self.join_date // Return trader join date
    }
    public fun get_trader_id<COIN>(self: &TraderAccount<COIN>): address { // Get trader ID
        self.trader_address // Return trader ID
    }
    public fun get_last_trade_date<COIN>(self: &TraderAccount<COIN>): u64 { // Get last trade date
        self.last_trade_date // Return last trade date
    }
    public fun get_total_profit<COIN>(self: &TraderAccount<COIN>): u64 { // Get total profit
        self.total_profit // Return total profit
    }

    fun helper_bag<COIN>(bag_: &mut Bag, coin: String, balance: Balance<COIN>) { // Helper function to update bag
        if(bag::contains(bag_, coin)) {  // Check if bag contains the coin
            let coin_value = bag::borrow_mut(bag_, coin); // Borrow mutable reference to the coin balance in the bag
            balance::join(coin_value, balance); // Join the balances
        }
        else { // If bag does not contain the coin
            bag::add(bag_, coin, balance); // Add new coin balance to the bag
        };
    }
    
}

