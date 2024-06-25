// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { UUPSUpgradeable } from "solady/src/utils/UUPSUpgradeable.sol";
import { Initializable } from "solady/src/utils/Initializable.sol";
import { LibString } from "solady/src/utils/LibString.sol";
import { LibClone } from "solady/src/utils/LibClone.sol";
import { LibDAG } from "./LibDAG.sol";

import { console2 } from "forge-std/console2.sol";

abstract contract Component {
    struct Dependency {
        bytes32 label;
        bytes4[] funcSelectors;
    }

    Kernel public kernel;
    mapping(Component => mapping(bytes4 => bool)) public permissions;

    error Component_OnlyKernel(address sender_);
    error Component_NotPermitted();

    constructor(address kernel_) {
        kernel = Kernel(kernel_);
    }

    modifier onlyKernel() {
        if (msg.sender != address(kernel)) revert Component_OnlyKernel(msg.sender);
        _;
    }

    /// @notice Modifier to restrict access to only the kernel or components with permission
    modifier permissioned() {
        if (msg.sender != address(kernel) && !permissions[Component(msg.sender)][msg.sig]) {
            revert Component_NotPermitted();
        }
        _;
    }

    // Must be overriden to actual name of the component or else will fail on install
    function LABEL() public view virtual returns (bytes32) {
        return toLabel("");
    }

    function INSTALLED() external view returns (bool) {
        return kernel.isComponentInstalled(LABEL());
    }

    // Hook for defining and configuring dependencies. Returns an array of dependencies.
    // Gets called during installation of dependents. Should be idempotent.
    // TODO consider split into read and write dependencies. writes check for cycles

    /// @notice Hook for defining and configuring dependencies.
    /// @return An array of dependencies for kernel to record
    function CONFIG() external virtual returns (Dependency[] memory);

    // Wrapper for internal `_init` call. Can only be called by kernel.
    function INIT(bytes memory data_) external onlyKernel {
        _init(data_);
    }

    // Must be overridden to do custom initialization. Will only ever be called once.
    function _init(bytes memory data_) internal virtual;

    function setPermissions(Component component_, bytes4[] memory selectors_, bool isAllowed_) external onlyKernel {
        // Early return if no selectors
        if (selectors_[0] == bytes4(0)) return;

        for (uint256 i; i < selectors_.length; i++) {
            permissions[component_][selectors_[i]] = isAllowed_;
        }
    }

    /// @notice Function used by kernel when migrating to a new kernel.
    function changeKernel(Kernel newKernel_) external onlyKernel {
        kernel = newKernel_;
    }

    // ERC-165. Used by Kernel to check if a component is installable.
    // TODO might need to be virtual, so it can be overridden by mutable components
    function supportsInterface(bytes4 interfaceId_) external view virtual returns (bool) {
        return type(Component).interfaceId == interfaceId_;
    }

    function isMutable() external view virtual returns (bool) {
        return false;
    }

    // --- Helpers ---------

    function toLabel(string memory typeName_) internal pure returns (bytes32) {
        return bytes32(bytes(typeName_));
    }

    function getComponentAddr(bytes32 label_) internal view returns (address) {
        return address(kernel.getComponentForLabel(label_));
    }
}

// TODO needs LibClone to be able to upgrade
abstract contract MutableComponent is Component, UUPSUpgradeable, Initializable {

    // Denotes version of the upgrade. Used to ensure `INIT` only gets called once per upgrade.
    function VERSION() public pure virtual returns (uint8);

    function isMutable() external view override returns (bool) {
        return proxiableUUID() == _ERC1967_IMPLEMENTATION_SLOT;
    }

    function _authorizeUpgrade(address) internal override onlyKernel {}

    // Guarded init with reinitializer modifier to ensure only gets called once per upgrade.
    function _init(bytes memory encodedArgs_) internal override reinitializer(VERSION()) {
        __init(encodedArgs_);
    }

    // Special INIT function for upgradeable that can only be called per install/upgrade
    function __init(bytes memory encodedArgs_) internal virtual;
}

/// @notice Kernel contract that manages the installation and execution of components.
/// @dev    Uses a DAG to manage dependencies and permissions between components
contract Kernel {
    using LibDAG for LibDAG.DAG;

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

    address public executor;

    LibDAG.DAG private componentGraph;
    mapping(bytes32 => Component) public getComponentForLabel;

    event ActionExecuted(Actions action, address target);

    error Kernel_CannotInstall();
    error Kernel_ComponentAlreadyInstalled();
    error Kernel_ComponentNotInstalled();
    error Kernel_ComponentMustBeMutable();
    error Kernel_ComponentHasDependents(uint256 numDependents);
    error Kernel_InvalidConfig();
    error Kernel_EndpointAlreadyExists();

    constructor() {
        _changeExecutor(msg.sender);
    }

    modifier verifyComponent(address target_) {
        if (!Component(target_).supportsInterface(type(Component).interfaceId)) revert Kernel_InvalidConfig();
        _;
    }

    // TODO think about allowing other contracts to install components. ie, a factory
    function executeAction(Actions action_, address target_, bytes memory data_) external {
        // Only Executor can execute actions
        require(msg.sender == executor);

        if (action_ == Actions.INSTALL)          _installComponent(target_, data_);
        else if (action_ == Actions.UNINSTALL)   _uninstallComponent(target_);
        else if (action_ == Actions.UPGRADE)     _upgradeComponent(target_, data_);
        else if (action_ == Actions.CHANGE_EXEC) _changeExecutor(target_);
        //else if (action_ == Actions.MIGRATE)     _migrateKernel(Kernel(target_));

        emit ActionExecuted(action_, target_);
    }

    function _installComponent(address target_, bytes memory data_) internal verifyComponent(target_) {
        // If component is mutable, deploy its proxy and use that address as the install target
        // Else, use the target argument as a regular component
        Component component = Component(target_).isMutable()
            ? MutableComponent(LibClone.deployERC1967(target_))
            : Component(target_);

        bytes32 label = component.LABEL();
        console2.log("STEP 0");

        if (isComponentInstalled(label)) revert Kernel_ComponentAlreadyInstalled();
        if (label == "") revert Kernel_InvalidConfig();

        console2.log("STEP 1");

        // Add node to graph
        componentGraph.addNode(label);
        getComponentForLabel[label] = component;

        console2.log("STEP 2");

        // Add all read and write dependencies
        _addDependencies(component);

        component.INIT(data_);

        emit ActionExecuted(Actions.INSTALL, address(component));
    }

    // Upgrade a mutable component to a new implementation
    // NOTE: Can add new dependencies, but cannot remove existing ones
    // NOTE: MAKE SURE UPGRADE IS SAFE. Use provided tools to ensure safety.
    function _upgradeComponent(address newImpl_, bytes memory data_) internal verifyComponent(newImpl_) {
        bytes32 label = MutableComponent(newImpl_).LABEL();

        if (!isComponentInstalled(label)) revert Kernel_ComponentNotInstalled();

        MutableComponent componentProxy = MutableComponent(address(getComponentForLabel[label]));

        if (!componentProxy.isMutable()) revert Kernel_ComponentMustBeMutable();

        // Remove all permissions for old implementation
        Component.Dependency[] memory deps = componentProxy.CONFIG();
        for (uint256 i; i < deps.length; ++i) {
            Component dependency = getComponentForLabel[deps[i].label];
            dependency.setPermissions(componentProxy, deps[i].funcSelectors, false);
        }

        // Upgrade to and initialize the new implementation
        componentProxy.upgradeToAndCall(
            newImpl_,
            abi.encodeWithSelector(Component.INIT.selector, data_)
        );

        // Add new dependencies and permissions for the new implementation, if any
        _addDependencies(componentProxy);

        emit ActionExecuted(Actions.UPGRADE, newImpl_);
    }

    function _uninstallComponent(address target_) internal verifyComponent(target_) {
        Component component = Component(target_);
        bytes32 label = component.LABEL();
        if (!isComponentInstalled(label)) revert Kernel_ComponentNotInstalled();

        uint256 numDependents = componentGraph.getInDegree(label);
        if (numDependents > 0) revert Kernel_ComponentHasDependents(numDependents);

        // Remove all permissions
        Component.Dependency[] memory deps = component.CONFIG();

        for (uint256 i; i < deps.length; ++i) {
            Component dependency = getComponentForLabel[deps[i].label];
            dependency.setPermissions(component, deps[i].funcSelectors, false);
        }

        // Remove component node and associated edges from graph
        componentGraph.removeNode(label);
        getComponentForLabel[label] = Component(address(0));

        emit ActionExecuted(Actions.UNINSTALL, target_);
    }


    function _runScript(address target_) internal {
        // TODO
    }

    function _changeExecutor(address target_) internal {
        executor = target_;
    }

    function _migrateKernel(address target_) internal {
        // TODO traverse graph and call changeKernel on all components from bottom up
    }

    function _reconfigureDependents(address target_) internal {
        // TODO needs to be called for all dependencies. Needs DFS
    }

    function isComponentInstalled(bytes32 label_) public view returns (bool) {
        return componentGraph.getNode(label_).exists;
    }

    // Add all read and write dependencies
    // NOTE: This can only add new dependencies. Will also SKIP existing ones.
    // This means it will NOT revert if a component has duplicate dependencies
    function _addDependencies(Component component_) internal {
        bytes32 label = component_.LABEL();
        Component.Dependency[] memory deps = component_.CONFIG();

        for (uint256 i; i < deps.length; ++i) {
            // If dependency exists, skip
            if (componentGraph.hasEdge(label, deps[i].label)) continue;

            // Check for new dependencies and add permissions as needed
            componentGraph.addEdge(label, deps[i].label);

            // Add permissions for any functions that need it
            Component dependency = getComponentForLabel[deps[i].label];
            dependency.setPermissions(component_, deps[i].funcSelectors, true);
        }
    }
}
