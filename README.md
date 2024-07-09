# Dagfault

Dagfault is a minimal framework for building modular smart contract protocols, built on ideas from [Default Framework](https://github.com/fullyallocated/Default) and inspired by various dependency injection and management frameworks.

## TLDR

- Dagfault is a framework for building modular and composable smart contracts by managing dependencies and permissions between components
- Depend is built around a DAG (Directed Acyclic Graph) of `Component` contracts
- Each component is a self-contained smart contract that can be installed, upgraded, and uninstalled by the Kernel
- Components can define required dependencies for other components
- Components can be immutable or mutable (upgradeable via UUPS)