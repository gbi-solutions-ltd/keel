# checkout-client

The storefront's client for the partner bank's checkout API. It opens a session for a cart, reads
the session back, and reports the outcome to the storefront.

## Layout

- `src/client/` talks to the partner bank
- `src/checkout/` turns a cart into a session request

## Running

```
npm install
npm test
```
