# CoinSync

CoinSync is a command-line tool for crypto traders written in Ruby that helps you import data like your transaction histories from multiple exchanges, convert it into a single unified format and process it in various ways, including calculating profits using FIFO for tax purposes.


## IMPORTANT ⚠️

These tools are provided without any warranty (just like the license says). None of them, including the FIFO part in particular, have been formally reviewed by any accounting firm or tax agency (though the general idea was discussed with my accountant), and I cannot guarantee that they work correctly and follow the tax code of my own country, not to mention any other countries whose laws I'm completely unfamiliar with. You take full responsibility for any problems you might run into if you use them for your crypto tax calculations.

On top of that, this project is currently in an alpha stage, so a lot of parts might be incomplete, might not do error handling properly, not take various edge cases into account, and generally might fail in unexpected ways. And don't even look at the test suite…

Basically, please verify and double-check any data you get from these scripts before you use it for anything remotely serious.


## Assumptions

The tool makes several assumptions about how it calculates things - if they are different than what you expect, you might have to work around them by writing some code yourself based on the provided classes. For example:

- fiat amounts are rounded to 2 decimal digits (4 digits for numbers smaller than 10), and crypto amounts are rounded to 8 digits
- exchange fees are simply added/subtracted from the amounts, i.e. they're treated as if you simply bought less units of an asset or paid more for it
- withdrawal fees are ignored
- for crypto-to-crypto transactions (also called "swaps" here), the base currency is determined automatically if possible, e.g. for a BTC-XMR pair XMR will always be the asset you buy/sell and BTC the currency you buy/sell it for
- crypto-to-crypto transactions DO NOT create a taxable profit
- the FIFO cost for crypto-to-crypto transactions is calculated by tracking which portion of one asset was exchanged into which portion of another, even across multiple swap transactions


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


## Configuration

To use CoinSync, you will need to create a config file first. By default it looks for the config file at `config.yml` in the current directory, though you can specify a different path with `-c path/to/config`.

The config uses the [YAML format](http://yaml.org), and the expected structure is:

```
sources:
  bittrex:
    type: bittrex
    file: bittrex.csv
  kraken:
    type: kraken
    file: kraken-ledgers.csv
  bitbay_api:
    file: data/bitbay.json
    api_public_key: 12345-678-90abc
    api_private_key: 45678-90a-bcdef
settings:
  timezone: Europe/Warsaw
  time_format: "%Y-%m-%d %H:%M"
  column_separator: ";"
  decimal_separator: ","
  convert_to: PLN
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

See the separate ["Exchanges"](doc/exchanges.md) doc file for a full list of supported exchanges.

### Settings

`settings` is an optional section that lets you change the behavior of the tool in various ways. Here's the list of currently supported keys:

- `base_cryptocurrencies`: an array listing which cryptocurrencies might be considered the base currency for a trading pair; if both sides of the pair are included in the list, the one earlier in the list takes priority (default: `['USDT', 'BTC', 'ETH', 'BNB', 'KCS', 'LTC', 'BCH', 'NEO']`)
- `column_separator`: what character is used to separate columns in saved CSV files (default: `","`)
- `convert_to`: what fiat currency should fiat amounts be converted to (default: none)
- `convert_with`: what currency converter module should be used to do the currency conversions (default: `fixer`)
- `decimal_separator`: what character is used to separate decimal digits in numbers (default: `"."`)
- `time_format`: the [time format string](http://ruby-doc.org/core-2.5.0/Time.html#method-i-strftime) to use when printing dates (default: `"%Y-%m-%d %H:%M:%S"`)
- `timezone`: an explicit timezone to use for printing dates and currency conversion (default: system timezone)

### Includes

If you want to extend the tool with support for additional importers, build tasks, currency converters etc., you can add an `include` key to the config and list there any local Ruby files you want to be loaded when CoinSync runs.


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


#### Build FIFO

```
coinsync build fifo
```

This will run FIFO calculations on all crypto-to-crypto and sale to fiat transactions, calculating the profits you made for tax purposes, and save the result in `build/fifo.csv`. (See the ["Assumptions"](#assumptions) section earlier about FIFO and crypto swap transactions!)

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

You can output a compiled transactions list in any other format you specifically need, by creating a custom importer class inheriting from `CoinSync::Outputs::Base` based on the [provided output classes](lib/coinsync/outputs) and loading it with the `include` option in the config.


## Credits & contributing

Copyright © 2018 [Kuba Suder](https://mackuba.eu). Licensed under [MIT License](http://opensource.org/licenses/MIT).

If anything doesn't work as expected, please [file a bug report](https://github.com/mackuba/coinsync/issues), and any contributions in the form of pull requests (especially adding support for new exchanges) are [very welcome](https://github.com/mackuba/coinsync/pulls).
