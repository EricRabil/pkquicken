# pkquicken
Exports all statements for your Apple Card (or any other card where PassKitCore supports exports) to `qfx` files for mass import. Supports date ranges under the hood, will expose via a proper CLI in the future (next time I need to export :P)

> If you can use AMFITrustedKeys, my `certDigest` is `MnmLHzvxdg25/I5+IRT9TwTAAe4+vwQqF4UPRgJViYY=` – the binaries in the release section are signed with my self-trusted CA.

## usage
```bash
# Prints the debug descriptions of all PKAccounts visible to the process
pkquicken accounts list
# Prints the debug descriptions of all PKCreditAccountStatements visible to the process, either for a given account or for all accounts
pkquicken statements list [account-identifier]
# Exports statements using the specified parameters, to ~/Documents/PKQuicken/
pkquicken statements export <account-identifier> [--format qfx|qix|pdf|whatever] [--after statement-id]
```
