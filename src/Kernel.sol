// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

/// @notice Used to define which module functions a policy needs access to
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
        //if (
        //msg.sender == address(kernel) ||
        //!kernel.modulePermissions(KEYCODE(), Policy(msg.sender), msg.sig)
        //) revert Module_PolicyNotPermitted(msg.sender);
        _;
    }

    function LABEL() public view virtual returns (bytes32) {
        return bytes32(abi.encodePacked(type(this).name));
    }

    // TODO CONFIGS or READS or configureDependencies?
    function READS() external virtual returns (bytes32[] memory dependencies) {}

    // TODO REQUESTS or WRITES or requestPermissions?
    function WRITES()
        external
        virtual
        returns (Permissions[] memory requests)
    {}
}

// TODO make upgradeable via kernel action. Needs 1967 factory
abstract contract MutableComponent is Component {

}

contract Kernel {}
