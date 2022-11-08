
# Quantum Portal Developers Guide

Till now, block-chain application, operate in the realm of a singular block-chain. However, the proliferation of blockchains, has mad the need for cross-chain applications more pronounced.

Many blockchains are specializing in a niche domain, while many projects have tokens living on different chains. Each project is required to manage different chains separately and users have to manage their assets and utility tokens in different chains. Often users have to bridge their tokens to a different chain to utilize a specific use case.

True cross-chain applications are incredibly powerful, and liberating for users. A cross-chain bridge, is the only example of a cross-chain application. Study of a engineering behind a cross-chain bridge can highlight the complexities of creating a multi-chain application. If one has to manage very complex security and node infrastructure, just to write a cross-chain application, no real application will be built.

Ferrum Network, is building Quantum Portal, as a secure cross-chain message and value passing framework. Quantum Portal enables true cross-chain applications by secure cross-chain message passing.

### What is multi-chain applications

One can imagine a multi-chain application, similar to a traditional distributed system, where a distributed application, has business logic distributed on separate servers, and such servers communicate using message passing or remote procedure calls.

To form a familiar mental image, you can think of quantum portal as a remote procedure call mechanism, for block-chains. For example, in a multi-chain staking application, the contract running on Ethereum chain, can lock user assets and call method `stake(staker, amount)` on its peer contract on the Ferrum Network.

### What are the options

One may create a cross-chain application by having a trusted relayer that relays messages and calls across chains.

### What is Quantum Portal

Quantum Portal consists of a set of smart contracts deployed on various chains. Ferrum Mainnet nodes can be configured as Quantum Portal miners to collectively secure the system spanning multiple chains.

As a developer, you will need to interact with a small subset of Quantum Portal, on your applications local chain.

## A multi-chain application architecture

## Multi-chain smart contract

## Ferrum Quantum Portal SDK

### QP Smart Contracts SDK

### QP User Experience SDK

#### Quantum Portal Explorer

- Monitor and withdraw funds. As a result of cross-chain applications, users may have funds left in the QP repo which they can withdraw. QP Explorer provides UI, and API that facilitates monitoring and executing user balances.
- Track cross-chain transactions
- Interact with cross-chain contracts

#### UX Components

- Several open source UX components are available in the Ferrum Network component repository that can be used as drop-in and configured for cross-chain applications.

## Quantum Portal Contracts SDK

### Running methods on a remote contract

### Sending tokens to remote contracts

### Receiving data from a remote chain

# Tutorials

## Example 1 - Multi-chain Token

Definition

Link

## Example 2 - Multi-chain staking

Definition

Link


