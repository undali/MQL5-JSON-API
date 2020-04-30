### 30th April 2020

- add support for spreads
- add support for drawing custom indicator data to charts
- add support for indicator data output

### 16th February 2020

- add support for candle ask/bid price spread

### 11th January 2020

- add support for multiple datastreams in parallel for any combination of symbols and timeframes independently of the timeframe and symbol of the attached chart
- add support for tick data
- add support for direct download as CSV files
- add one automatic retry binding to sockets. When running under Wine in Linux, sockets will be blocked for 60 seconds if closed uncleanly. This can happen if the client is still connected while the EA gets reloaded.
- skip re-initialization on chart timeframe change
