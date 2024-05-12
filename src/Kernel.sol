// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Factory} from "solady/src/utils/ERC1967Factory.sol";

/// @notice Actions to trigger state changes in the kernel. Passed by the executor
enum Actions {
    InstallComponent,
    UninstallComponent,
    UpgradeComponent,
    RunScript,
    ChangeExecutor,
    MigrateKernel
}

/// @notice Used by executor to select an action and a target contract for a kernel action
struct Instruction {
    Actions action;
    address target;
}

/// @notice Used to define which functions a component needs access to
struct Permissions {
    bytes32 label;
    bytes4 funcSelector;
}

abstract contract Component {
    Kernel public immutable kernel;
    uint8 public version;

    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

    modifier permissioned() {
        if (msg.sender == address(kernel) ||
            !kernel.permissions(NAME(), Component(msg.sender), msg.sig)
        ) revert Component_NotPermitted(msg.sender);
        _;
    }

    // TODO virtual?
    function NAME() public view virtul returns (bytes32) {
        return bytes32(abi.encodePacked(type(Component).name));
    }

    // Hook for defining which components to read from
    function READ() external virtual returns (bytes32[] memory reads) {}

    // Hook for defining which functions to request write access to
    function WRITE()
        external
        virtual
        returns (Permissions[] memory writes)
    {}

    function INIT() external onlyKernel {
        _init();
    }

    function _init() internal virtual {}

    // ERC-165. Used by Kernel to check if a component is installable.
    function supportsInterface(bytes4 interfaceId_) external view virtual returns (bool) {
        return
            type(Component).interfaceId == interfaceId_ ||
            super.supportsInteface(interfaceId_);
    }
}

// TODO make upgradeable via kernel action. Needs 1967 factory
abstract contract MutableComponent is Component {}

// TODO make clonable components
abstract contract ReplicableComponent is Component {
    function REPLICATE() external virtual;
}

// TODO what does this need
abstract contract Script is Component {
    function run() external virtual;
}

contract Kernel is ERC1967Factory {

    address public executor;

    mapping(bytes32 => address) public components;
}
