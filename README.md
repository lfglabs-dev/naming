# StarknetId Naming Contract

This naming contract defines the Stark Naming System. It allows resolving a `stark` domain to a Starknet address or any other field.

## Features

- **Domain Resolution**: Resolve a `stark` domain to a Starknet address or any other field.
- **Native Resolver**: By default, `stark` names are attached to identities where the value associated with any field is stored.
- **Resolver Contracts**: Domain owners can delegate the resolution of their subdomains to resolver contracts.
- **Off-Chain Resolving**: Resolver contracts support reading off-chain data to resolve a name and a field to a target value.
- **On-Chain Resolving**: You can resolve a domain on-chain (and not a hash), allowing you to natively send money to a `.stark` domain instead of resolving off-chain before forging the actual transaction.
- **Optimized Encoding**: This feature forbids homograph attacks and allows for longer shortstrings. For more information, visit the [Encoding Documentation](https://docs.starknet.id/architecture/naming/encoding).

## Ecosystem Support

The Stark Naming System can be integrated into your dApp for seamless domain resolution. Here are some useful resources:

- **Integration Guide**: To integrate the Stark Naming System into your dApp, please check the [Developer Documentation](https://docs.starknet.id/devs).
- **Subdomains**: To create subdomains and determine if you should use the native resolver built on top of identities or create your own contract, visit the [Subdomains Documentation](https://docs.starknet.id/devs/subdomains).
- **Off-Chain Resolver**: To see how you can create an off-chain resolver and access data from web3, check out the [CCIP Architecture Documentation](https://docs.starknet.id/architecture/ccip) and follow the [CCIP Tutorial](https://docs.starknet.id/architecture/ccip/tutorial) which shows how to use Notion to resolve your Stark subdomains.

## Audits

For additional trust and transparency, this contract has been audited by independent third-party security firms. You can view the audit reports below:

- [Cairo Security Clan Audit](./audits/cairo_security_clan.pdf)
- [Subsix Audit](./audits/subsix.pdf)

## How to Build/Test?

This project was built using Scarb.

### Building

To build the project, run the following command:

```
scarb --release build
```

### Testing

To run the tests, use the following command:

```
scarb test
```

For details on the identity contract, see the [StarknetID Identity Contract](https://github.com/starknet-id/identity).
