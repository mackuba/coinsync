# CoinSync

CoinSync is a command-line tool for crypto traders written in Ruby that helps you import data like your transaction histories from multiple exchanges, convert it into a single unified format and process it in various ways.


## IMPORTANT ⚠️

These tools are provided without any warranty (just like the license says), and I cannot guarantee that they work correctly. The project is currently in an alpha stage, so a lot of parts might be incomplete, might not do error handling properly, not take various edge cases into account, and generally might fail in unexpected ways. And don't even look at the test suite…

Basically, please verify and double-check any data you get from these scripts before you use it for anything remotely serious. You take full responsibility for any problems you might run into if you use them e.g. for your crypto tax calculations.


## Assumptions

The tool makes several assumptions about how it calculates things - if they are different than what you expect, you might have to work around them by writing some code yourself based on the provided classes. For example:

- fiat amounts are rounded to 2 decimal digits (4 digits for numbers smaller than 10), and crypto amounts are rounded to 8 digits
- exchange fees are simply added/subtracted from the amounts, i.e. they're treated as if you simply bought less units of an asset or paid more for it
- withdrawal fees are ignored
- for crypto-to-crypto transactions (also called "swaps" here), the base currency is determined automatically if possible, e.g. for a BTC-XMR pair XMR will always be the asset you buy/sell and BTC the currency you buy/sell it for


## Installation

You're going to need some version of Ruby installed, but any fairly recent version should do.

To just install the gem in the system, call:

    $ gem install coinsync

You might need to add `sudo` if you don't use any Ruby version manager like [RVM](https://rvm.io), though it's better if you get one.

### Installing with a Gemfile

Alternatively, you can add it to your application's Gemfile:

```ruby
gem 'coinsync'
```

And then call `bundle` to install it, and `bundle exec coinsync` to run it.

You can also create a project directory with a Gemfile specifically for CoinSync:

```
gem install bundle
mkdir mycrypto
cd mycrypto
bundle init
echo "gem 'coinsync'" >> Gemfile
bundle
bundle exec coinsync
```

This also lets you install the gem locally in that directory, by adding a path argument to `bundle`, e.g. `bundle --path ./bundle`.

### Installing development version

To use the latest development version, check out the repository to a local directory:

```
git clone git@github.com:mackuba/coinsync.git
```

And then run `bin/coinsync` from inside that directory.


## Configuration

To use CoinSync, you will need to create a config file first. By default it looks for the config file at `config.yml` in the current directory, though you can specify a different path with `-c path/to/config`.

The config uses the [YAML format](http://yaml.org), and the expected structure is:

```
sources:
  bittrex:
    type: bittrex
    file: data/bittrex.csv
  kraken:
    type: kraken
    file: data/kraken-ledgers.csv
  bitbay_api:
    file: data/bitbay.json
    api_public_key: 12345-678-90abc
    api_private_key: 45678-90a-bcdef
settings:
  timezone: Europe/Warsaw
  time_format: "%Y-%m-%d %H:%M"
  column_separator: ";"
  decimal_separator: ","
  convert_currency:
    to: PLN
include:
  - extras.rb
```

### Sources

The `sources` list is a map of { key => definition } entries which lists the exchanges from which you want to import the transaction history and other data. There are generally two types of sources:

- those that import a CSV file that you've downloaded yourself from your profile on the exchange, and don't connect to the exchange API at all
- those that can connect to an exchange's API and download its transaction history and other data like current balances

The key is any valid identifier you want to use to refer to this source, and the definition is a list of parameters:

- `type` specifies which importer module to use
- `file` specifies from where it should load a file you've downloaded, or where it should save the transaction history it imports itself

Depending on the exchange, some sources might allow or require additional parameters like API keys or addresses. You can have more than one source of the same type, if you want to import multiple transaction histories from one exchange.

If the type of the importer is the same as the source key, the `type` parameter might be skipped. If no other parameters are needed, you can also use a shorthand format, passing just a filename instead of a full hash:

    kraken: kraken-ledgers.csv

See the separate ["Importers"](doc/importers.md) doc file for a full list of supported exchanges.

### Settings

`settings` is an optional section that lets you change the behavior of the tool in various ways. Here's the list of currently supported keys:

- `base_cryptocurrencies`: an array listing which cryptocurrencies might be considered the base currency for a trading pair; if both sides of the pair are included in the list, the one earlier in the list takes priority (default: `['USDT', 'BTC', 'ETH', 'BNB', 'KCS', 'LTC', 'BCH', 'NEO']`)
- `column_separator`: what character is used to separate columns in saved CSV files (default: `","`)
- `convert_currency`: currency conversion config, see below
- `decimal_separator`: what character is used to separate decimal digits in numbers (default: `"."`)
- `time_format`: the [time format string](http://ruby-doc.org/core-2.5.0/Time.html#method-i-strftime) to use when printing dates (default: `"%Y-%m-%d %H:%M:%S"`)
- `timezone`: an explicit timezone to use for printing dates and currency conversion (default: system timezone)

### Includes

If you want to extend the tool with support for additional importers, build tasks, currency converters etc., you can add an `include` key to the config and list there any local Ruby files you want to be loaded when CoinSync runs.


### Currency conversion

If you make transactions in multiple fiat currencies (e.g. USD on Bitfinex, EUR on Kraken) and you want to have all values converted to one currency (for example, to calculate profits for tax purposes), add a `currency_conversion` section in the settings. Currency conversion is done using pluggable modules that load currency rates from specific sources. Currently, two are available:

- `exchangeratesapi` loads exchange rates from [exchangeratesapi.io](https://exchangeratesapi.io) API
- `nbp` loads rates from [Polish National Bank](http://www.nbp.pl/home.aspx?f=/statystyka/kursy.html) (this might be moved to a separate gem?)

You can always write another module that connects to your preferred source and plug it in using `include`.

The `currency_conversion` option value should be a hash with keys:

- `using`: name of the currency converter module (default: `exchangeratesapi`)
- `to`: code of the currency to convert to (required)


### Transaction value estimation

In some cases you might want to know the total value of a transaction in a chosen fiat currency. For purchase and sale transactions, this is just the total amount for which you've bought or sold the given asset. However, for swap (crypto-to-crypto) transactions, the total value can't be simply calculated from the available data, and it might not even be obvious *how* it should be calculated at all.

This is where value estimation modules aka price loaders come in. They're another type of pluggable modules that load historical prices of a given coin from a selected source. For simplicity, only the price of the base coin is checked - e.g. when you buy STEEM with BTC, the value of the transaction (i.e. the value of both the sold BTC and the bought STEEM) is set to the price of BTC at that moment times the amount of BTC spent, and the price of STEEM in USD/EUR isn't checked separately.

Currently only one price loader is available: `cryptowatch`, which can load the price of any coin listed on [Cryptowat.ch](https://cryptowat.ch) (requires the [cointools gem](https://github.com/mackuba/cointools)).

To estimate transaction value using Cryptowat.ch, add a `value_estimation` section in the settings:

- `using`: name of the price loader module (required - `cryptowatch`)
- `exchange`: name of an exchange listed on Cryptowat.ch (default: `bitfinex`)
- `currency`: code of the fiat currency in which value should be calculated (default: `USD`)

At the moment this feature is only used in the [Split List](#build-split-list) output.


## Using the tool

Once you have a config file, you can run one of the commands described below to import or process your data:


### Balance

```
coinsync balance [sources...]
```

This connects to the exchange APIs using any importers that support it (and where you've provided the keys), downloads the wallet balances, and prints them in a list like this:

```
Coin   |      binance          kucoin    |     TOTAL
-------------------------------------------------------
BTC    |          0.1 (+)         0.1    |          0.2
ETH    |             10.5                |         10.5
LTC    |                           20    |           20
NANO   |               15          25    |           40
XMR    |               33         1.8    |         34.8
```

The "(+)" means that some amount of funds is locked in an open order.

You can filter the list of sources by listing one or more source names as arguments, or by listing source names with a '^' symbol (e.g. `^kucoin`) to *exclude* them.


### Import

```
coinsync import [sources...]
```

This connects to the exchange APIs using any importers that support it (and where you've provided the keys) and downloads the transaction histories to specified files, which are later used in the build tasks below. Again, you can choose or exclude specific sources as above.


### Build

```
coinsync build <task>
```

The build tasks process all downloaded transaction history files, combine them into a single chronologically sorted list in memory, and then output it in a selected format or run some additional calculations on it:


#### Build List

```
coinsync build list
```

This will just print all your transactions to a single unified CSV file (in `build/list.csv`).


#### Build Split List

```
coinsync build split-list
```

Builds a list similar to `build list`, but all "swap" transactions (crypto-to-crypto) are split into separate sale and purchase parts (`build/split-list.csv`). This can be useful for some tax-related calculations, and is only really useful if you also enable the [transaction value estimation option](#transaction-value-estimation).


#### Build Raw

```
coinsync build raw
```

This prints a list of transactions in a way similar to `build list`, but in the same format as CoinSync stores transactions internally in memory: each transaction, no matter the type or source, is stored in exactly the same way - the amount and code of the fiat or crypto currency received (bought) and the amount & code of the fiat/crypto currency paid (sold). This means that when e.g. buying BTC for USD, the bought currency will be BTC and the sold one will be USD, and when selling BTC for USD, it will be the other way around (bought: USD, sold: BTC).

This output is mostly meant if you intend to use it as input for some other tools written in other languages and process the data further there.

The columns in the CSV are:

- exchange: name of the exchange or source
- date: transaction date
- bought amount: amount of the bought (received) asset/currency
- bought currency: code of the bought (received) asset/currency
- sold amount: amount of the asset/currency you sold (paid in)
- sold currency: code of the asset/currency you sold (paid in)


#### Build Summary

```
coinsync build summary
```

This will calculate how much of each traded asset you're supposed to have right now (this will differ more or less from the actual amounts because of transaction and withdrawal fees paid, payments/donations or mined coins you haven't counted, etc.):

```
Coin       Amount
---------------------
BTC               0.5
BCH                 0
ETH              12.5
LTC                40
NEO                15
IOTA             1800
```

#### Custom build tasks

You can output a compiled transactions list in any other format you specifically need, by creating a custom output class inheriting from `CoinSync::Outputs::Base` based on the [provided output classes](lib/coinsync/outputs) and loading it with the `include` option in the config.


### Run command

```
coinsync run <source> <command> [args...]
```

Some importers (currently only Binance) may have custom commands implemented that only make sense for a given importer. This allows you to run these commands from the command line. See the ["Importers"](doc/importers.md) doc for more info.


## Credits & contributing

Copyright © 2018 [Kuba Suder](https://mackuba.eu). Licensed under [MIT License](http://opensource.org/licenses/MIT).

If anything doesn't work as expected, please [file a bug report](https://github.com/mackuba/coinsync/issues), and any contributions in the form of pull requests (especially adding support for new exchanges) are [very welcome](https://github.com/mackuba/coinsync/pulls).
