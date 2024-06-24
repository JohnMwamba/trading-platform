#[allow(lint(self_transfer))] // Allow self-transfer lint
module trade::trade {
    use sui::tx_context::{sender};
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::balance::{Self, Balance};
    use sui::bag::{Self, Bag};
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};

    /// Error Constants ///
    const EInsufficientFunds: u64 = 1; // Error code for insufficient funds
    const EInvalidCap: u64 = 4; // Error code for invalid cap
    const ENoFollowers: u64 = 5; // Error code for no followers

    const PERFORMANCE_FEE_RATE: u128 = 10; // Performance fee rate in percentage

    // Type that stores trader account data:
    public struct TraderAccount<phantom COIN> has key {
        id: UID, // Unique identifier for the trader
        trader_address: address,  // Address of the trader
        join_date: u64, // Timestamp of when the trader joined
        last_trade_date: u64, // Timestamp of the last trade
        total_followers: u64, // Total number of followers
        total_trades: u64, // Total number of trades executed by the trader
        total_profit: u64, // Total profit earned by the trader
    }
    
    // Type that represents the trading platform:
    public struct TradingPlatform<phantom COIN> has key, store {
        id: UID, // Unique identifier for the trading platform
        inner: ID, // Internal ID for the platform
        balance: Bag, // Bag containing the platform's balance
        performance_fee_rate: u64 // Performance fee rate applied to profits
    }

    public struct TradingPlatformCap has key {
        id: UID, // Unique identifier for the cap
        platform: ID // Internal ID of the associated trading platform
    }

    public struct Protocol has key, store {
        id: UID, // Unique identifier
        balance: Bag // Bag containing the protocol's balance
    }

    public struct AdminCap has key {
        id: UID // Unique identifier
    }

    /// Create a new trading platform.
    public fun new_trading_platform<COIN>(performance_fee_rate: u64, ctx: &mut TxContext) {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        transfer::share_object(TradingPlatform<COIN> {
            id: id_,
            inner: inner_,
            balance: bag::new(ctx),
            performance_fee_rate: performance_fee_rate
        });
        transfer::transfer(TradingPlatformCap{id: object::new(ctx), platform: inner_}, sender(ctx));
    }

    // Execute a trade by a trader.
    public fun execute_trade<COIN>(
        protocol: &mut Protocol,
        trading_platform: &mut TradingPlatform<COIN>,
        clock: &Clock,
        coin_metadata: &CoinMetadata<COIN>,
        mut coin: Coin<COIN>,
        ctx: &mut TxContext
    ) : TraderAccount<COIN> {
        let trade_value = coin::value(&coin);
        let performance_fee = ((trade_value as u128) * PERFORMANCE_FEE_RATE / 100) as u64;
        assert!(trade_value >= performance_fee, EInsufficientFunds);

        let protocol_fee = performance_fee;
        let protocol_fee_coin = coin::split(&mut coin, protocol_fee, ctx);
        let protocol_balance = coin::into_balance(protocol_fee_coin);
        let trader_balance = coin::into_balance(coin);

        let protocol_bag = &mut protocol.balance;
        let trading_platform_bag = &mut trading_platform.balance;

        let _name = coin::get_name(coin_metadata);
        let coin_names = string::utf8(b"coins");

        helper_bag(protocol_bag, coin_names, protocol_balance);
        helper_bag(trading_platform_bag, coin_names, trader_balance);

        let id_ = object::new(ctx);
        let trader_account = TraderAccount {
            id: id_,
            trader_address: sender(ctx),
            join_date: clock::timestamp_ms(clock),
            last_trade_date: clock::timestamp_ms(clock),
            total_followers: 0,
            total_trades: 1,
            total_profit: trade_value - performance_fee,
        };

        emit!({
            "event": "TradeExecuted",
            "trader": trader_account.trader_address,
            "trade_value": trade_value,
            "performance_fee": performance_fee
        });

        trader_account
    }

    // Replicate a trader's trade.
    public fun replicate_trade<COIN>(
        protocol: &mut Protocol,
        trading_platform: &mut TradingPlatform<COIN>,
        trader_account: &mut TraderAccount<COIN>,
        coin_metadata: &CoinMetadata<COIN>,
        mut coin: Coin<COIN>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let trade_value = coin::value(&coin);
        let performance_fee = ((trade_value as u128) * PERFORMANCE_FEE_RATE / 100) as u64;
        assert!(trade_value >= performance_fee, EInsufficientFunds);

        let protocol_fee = performance_fee;
        let protocol_fee_coin = coin::split(&mut coin, protocol_fee, ctx);
        let protocol_balance = coin::into_balance(protocol_fee_coin);
        let follower_balance = coin::into_balance(coin);

        let protocol_bag = &mut protocol.balance;
        let trading_platform_bag = &mut trading_platform.balance;

        let _coin_name = coin::get_name(coin_metadata);
        let coin_names = string::utf8(b"coins");

        helper_bag(protocol_bag, coin_names, protocol_balance);
        helper_bag(trading_platform_bag, coin_names, follower_balance);

        trader_account.total_followers += 1;
        trader_account.total_trades += 1;
        trader_account.total_profit += trade_value - performance_fee;
        trader_account.last_trade_date = clock::timestamp_ms(clock);

        emit!({
            "event": "TradeReplicated",
            "trader": trader_account.trader_address,
            "trade_value": trade_value,
            "performance_fee": performance_fee
        });
    }

    // Function to distribute profits to followers
    public fun distribute_profits<COIN>(
        trading_platform: &mut TradingPlatform<COIN>,
        trader_account: &TraderAccount<COIN>,
        ctx: &mut TxContext
    ) {
        let total_profit = trader_account.total_profit;
        let total_followers = trader_account.total_followers;

        assert!(total_followers > 0, ENoFollowers); // Ensure there are followers to distribute profits to

        let profit_per_follower = total_profit / total_followers;

        // Logic to distribute profits to each follower would go here
        // This might involve iterating through a list of followers or using a suitable data structure to track follower information
        // For simplicity, this part is left abstract

        emit!({
            "event": "ProfitsDistributed",
            "total_profit": total_profit,
            "total_followers": total_followers,
            "profit_per_follower": profit_per_follower
        });
    }

    // Example accessor functions for fetching trader's account details
    public fun get_trader_join_date<COIN>(self: &TraderAccount<COIN>): u64 {
        self.join_date
    }
    public fun get_trader_id<COIN>(self: &TraderAccount<COIN>): address {
        self.trader_address
    }
    public fun get_last_trade_date<COIN>(self: &TraderAccount<COIN>): u64 {
        self.last_trade_date
    }
    public fun get_total_profit<COIN>(self: &TraderAccount<COIN>): u64 {
        self.total_profit
    }

    fun helper_bag<COIN>(bag_: &mut Bag, coin: String, balance: Balance<COIN>) {
        if (bag::contains(bag_, coin)) {
            let coin_value = bag::borrow_mut(bag_, coin);
            balance::join(coin_value, balance);
        } else {
            bag::add(bag_, coin, balance);
        };
    }
}
