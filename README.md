# sui-trading-platform

INTRODUCTION

This module facilitates trading operations within the Sui Move ecosystem, enabling the creation of trading platforms, execution and replication of trades, and management of trader accounts and protocol balances.

STRUCTURES

TraderAccount

Stores details of individual trader accounts:
- id: Unique identifier of the trader.
- trader_address: Address of the trader.
- join_date: Timestamp when the trader joined the platform.
- last_trade_date: Timestamp of the trader's last trade.
- total_followers: Total number of followers the trader has.
- total_trades: Total number of trades executed by the trader.
- total_profit: Total profit earned by the trader.

TradingPlatform

Represents a trading platform:
- id: Unique identifier of the trading platform.
- inner: Internal ID for the platform.
- balance: A Bag containing the platform's balance.
- performance_fee_rate: Fee rate applied to trader profits.

TradingPlatformCap

Ensures authorized management of a trading platform:
- id: Unique identifier of the cap.
- platform: Internal ID of the associated trading platform.

Protocol

Manages the protocol's balance:
- id: Unique identifier.
- balance: A Bag containing the protocol's balance.

AdminCap

Allows only admins to withdraw fees:
- id: Unique identifier.

CORE FUNCTIONS

new_trading_platform

Creates a new trading platform with a specified performance fee rate.
- Parameters: `performance_fee_rate`, `ctx`
- Returns: Transfers TradingPlatformCap to the caller.

execute_trade

Executes a trade on behalf of a trader.
- Parameters: `protocol`, `trading_platform`, `clock`, `coin_metadata`, `coin`, `ctx`
- Returns: `TraderAccount`

replicate_trade

Replicates a trader's trade.
- Parameters: `protocol`, `trading_platform`, `trader_account`, `coin_metadata`, `coin`, `ctx`

distribute_profits

Distributes profits to followers of a trader.
- Parameters: `trader_account`, `_ctx`

Error Constants

- EInsufficientFunds (1): Insufficient funds to process the trade.
- EInvalidCap (4): Invalid cap for trading operations.

HELPER FUNCTIONS

helper_bag

Manages balances within a Bag.
- Parameters: `bag_`, `coin`, `balance`

Accessor Functions

Accessor functions are available for fetching trader account details such as join date, trader ID, last trade date, and total profit.

SUMMARY

This module enables the creation and management of trading platforms, execution and replication of trades, and distribution of profits to followers. It ensures secure handling of balances and error-free transaction processing within the Sui Move environment.


# trading-platform
