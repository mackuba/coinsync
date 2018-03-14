## Supported exchanges / importers

### Ark Voting Rewards (`ark_voting`)

Connects to the API: **YES**

Parameters:

- file: path where the transaction history will be saved
- address: your Ark address

The importer loads a list of transactions sent to a given address from the Ark explorer, picks those that are voting rewards sent from the delegates, and saves them as purchases made with zero cost.

### Binance API (`binance_api`)

Connects to the API: **YES**

Parameters:

- file: path where the transaction history will be saved
- api_key: API key
- secret_key: secret API key
- traded_pairs: a list of all pairs you trade there

Create the API keys on your Binance profile page. Only the "Read Info" permission is required.

Unfortunately, the Binance API currently doesn't allow loading transaction history for all pairs in one go, and checking all possible pairs would take too much time, so you need to explicitly specify the list of pairs to be downloaded, in such format:

```
traded_pairs:
  - XRPBTC
  - ETHBTC
  - NANOETH
  - BTCUSDT
  - LTCUSDT
```

The Binance importer has a custom command that you can use to generate this list. This task scans all available trading pairs and finds those with some trades present on your account. It may take about 5-10 minutes to complete, that's why this isn't done automatically during the import.

```
coinsync run binance_api find_all_pairs
```


### BitBay API (`bitbay_api`)

Connects to the API: **YES**

Parameters:

- file: path where the transaction history will be saved
- api_public_key: API public key
- api_private_key: API secret key

Create the API keys on your BitBay profile page. You will need to select the "History" permission for transaction history, and "Crypto deposit" + "Updating a wallets list" for downloading balances.

### BitBay 2.0 (`bitbay20`)

Connects to the API: **NO**

Parameters:

- file: path from where the transaction history will be loaded

This is meant for importing transaction history from the older version of BitBay (before September 2017), available at <https://old.bitbay.net>.

### Bitcurex (`bitcurex`)

Connects to the API: **NO**

Parameters:

- file: path from where the transaction history will be loaded

This is used to import transaction history from the late Polish Bitcurex exchange (RIP in peace), in case you happen to have downloaded one before the owners disappeared with all the money.

### Bittrex (`bittrex`)

Connects to the API: **NO**

Parameters:

- file: path from where the transaction history will be loaded

This parses the full transaction history CSV, downloaded using the "Load All" button on the History page.

### Changelly (`changelly`)

Connects to the API: **NO**

Parameters:

- file: path from where the transaction history will be loaded

Download the history from the My Account / History page, using the "Export .csv" button.

### Circle (`circle`)

Connects to the API: **NO**

Parameters:

- file: path from where the transaction history will be loaded

You can get the transaction history from the Settings / Advanced page - it will be sent to you via email.

### Default (`default`)

Connects to the API: **NO**

Parameters:

- file: path from where the transaction history will be loaded

This is a generic CSV format that you can use to import a list of random transactions from any other sources.

The expected columns in the CSV are:

- number: an incrementing integer number (ignored, it's just to make the file more readable)
- exchange: name of the exchange or source
- type: "Purchase" or "Sale"
- date: date in a recognizable format
- amount: amount of the asset bought or sold (uses decimal separator defined in the settings)
- value: amount received or paid for the asset (as above)
- currency: currency in which you've paid for the asset

Any other columns after that are ignored.

To list crypto-to-crypto transactions in the CSV (e.g. BTC-NANO), put the base currency in the "currency" column with a "$" prefix (e.g. `$BTC`) and the other one as asset.

Airdrops and mined coins can be listed as a purchase with value 0 and an empty "currency" field.

### EtherDelta / ForkDelta (`etherdelta`)

Connects to the API: **NO**

Parameters:

- file: path from where the transaction history will be loaded

To download a transaction history, use the [DeltaBalances tool](https://deltabalances.github.io), look up your transactions on the History page specifying the time range you need, and then download the "Default" CSV in the top-right section.

### Kraken (`kraken`)

Connects to the API: **NO**

Parameters:

- file: path from where the transaction history will be loaded

The Kraken importer expects a "Ledgers" CSV file downloaded from the Kraken's History page.

### Kucoin API (`kucoin`)

Connects to the API: **YES**

Parameters:

- file: path where the transaction history will be saved
- api_key: API public key
- api_secret: API secret key

Create the API keys on your Kucoin profile page.

**Warning**: there's currently no way to create an API key on Kucoin with partial permissions; any key you create will have full access to your account, including placing orders and making withdrawals. Be careful with it.

### Lisk Voting Rewards (`lisk_voting`)

Connects to the API: **YES**

Parameters:

- file: path where the transaction history will be saved
- address: your Lisk address

The importer loads a list of transactions sent to a given address from the Lisk explorer, picks those that are voting rewards sent from the delegates, and saves them as purchases made with zero cost.
