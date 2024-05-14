// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UUPSUpgradeable} from "solady/src/utils/UUPSUpgradeable.sol";
import {ERC1967Factory} from "solady/src/utils/ERC1967Factory.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

/// @notice Actions to trigger state changes in the kernel. Passed by the executor
enum Actions {
    INSTALL,
    UNINSTALL,
    UPGRADE,
    RUN_SCRIPT,
    CHANGE_EXEC,
    MIGRATE
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

    error Component_NotKernel(address sender_);

    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

    modifier onlyKernel() {
        if (msg.sender != address(kernel)) revert Component_NotKernel(msg.sender);
        _;
    }

    modifier permissioned() {
        if (msg.sender == address(kernel) ||
            !kernel.permissions(NAME(), Component(msg.sender), msg.sig)
        ) revert Component_NotPermitted(msg.sender);
        _;
    }

    function NAME() public view virtual returns (bytes32) {
        return type(Component).name;
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

    /// @notice Function used by kernel when migrating to a new kernel.
    function changeKernel(Kernel newKernel_) external onlyKernel {
        kernel = newKernel_;
    }

    // ERC-165. Used by Kernel to check if a component is installable.
    // TODO add interface for Modules and Policies?? to allow change kernel to work
    function supportsInterface(bytes4 interfaceId_) external view virtual returns (bool) {
        return
            type(Component).interfaceId == interfaceId_ ||
            super.supportsInteface(interfaceId_);
    }
}

// TODO make upgrades via kernel action. Needs 1967 factory
abstract contract MutableComponent is Component, UUPSUpgradeable {}

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

    mapping(bytes32 => Component) public getComponentForName;
    mapping(Component => bytes32) public getNameForComponent;

    /// @notice Component <> Component Permissions.
    /// @dev    Component -> Component -> Function Selector -> bool for permission
    mapping(Component => mapping(Component => mapping(bytes4 => bool))) public permissions;

    error Kernel_CannotInstall();
    error Kernel_NotInstalled();

    constructor() {
        executor = msg.sender;
    }

    modifier verifyComponent(address target_) internal {
        if (!Component(target_).supportsInterface(Component.interfaceId)) revert;
    }

    // TODO think about allowing other contracts to install components. ie, a factory
    function executeAction(Actions action_, address target_) external {
        // Only Executor can execute actions
        require(msg.sender == executor);

        if      (action_ == Actions.INSTALL)     _installComponent(target_);
        else if (action_ == Actions.UNINSTALL)   _uninstallComponent(target_);
        else if (action_ == Actions.UPGRADE)     _upgradeComponent(target_);
        else if (action_ == Actions.CHANGE_EXEC) executor = target_;
        else if (action_ == Actions.MIGRATE)     _migrateKernel(Kernel(target_));

        emit ActionExecuted(action_, target_);
    }

    function _installComponent(address target_) internal verifyComponent(target_) {
        Component component = Component(target_);

        if (components[components.NAME()] != address(0)) revert Kernel_CannotInstall();
        components[component.NAME()] = component;

        // TODO get READs and WRITEs
        // TODO check for cycles
        // TODO add dependencies
        // TODO add permissions

        component.INIT();
    }

    function _uninstallComponent(address target_) internal verifyComponent(target_) {
        Component component = Component(target_);

        if (components[component.NAME()] != address(0)) revert Kernel_NotInstalled;
        delete components[component.NAME()];

        // TODO check if dependency to anything. If so, revert
    }

    function _upgradeComponent(address target_) internal verifyComponent(target_) {}
    function _migrateKernel(address target_) internal {}

    // TODO Add dynamic routing to components
    // TODO allow router to load data into transient memory before routing

}
