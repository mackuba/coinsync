#### Version 0.2.1 (26.04.2018)

* fixed parsing of sale transactions in Kucoin importer
* fixed pagination in Binance importer
* fixed transaction matching in BitBay API importer
* fixed timezone handling in multiple importers and currency converters (using tzinfo gem)

#### Version 0.2.0 (24.04.2018)

* added `split-list` output
* added value estimation modules (`cryptowatch`) and configuration (`estimate_value`) for split list
* `convert_to` and `convert_with` options replaced with a `convert_currency` section
* replaced `fixer` currency converter with a new API (<https://exchangeratesapi.io>), since Fixer introduced paid plans now
* updated list of coins in the BitBay importer
* renamed `caches` directory to `cache`

#### Version 0.1.0 (8.04.2018)

* first public release:
  - outputs: `list`, `raw` and `summary`
  - importers: Ark address, Binance API, BitBay 3.0 API & 2.0 CSV, Bitcurex, Bittrex API (only balances) and CSV, Changelly, Circle, Default, EtherDelta, Kraken API & CSV, Kucoin API, Lisk address
  - currency converters: `fixer` and `nbp`
