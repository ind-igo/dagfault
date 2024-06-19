// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { UUPSUpgradeable } from "solady/src/utils/UUPSUpgradeable.sol";
import { ERC1967Factory } from "solady/src/utils/ERC1967Factory.sol";
import { Initializable } from "solady/src/utils/Initializable.sol";
import { LibString } from "solady/src/utils/LibString.sol";
import { LibClone } from "solady/src/utils/LibClone.sol";
import { LibDAG } from "./LibDAG.sol";

import { console2 } from "forge-std/console2.sol";

/*
function DEPS() external view returns (Dependency[] memory deps) {
    deps = new Dependency[](2);
    bytes4[2] memory poolMgrSelectors = [
        BPOOL.addLiquidityTo.selector,
        BPOOL.removeLiquidityFrom.selector
    ];
    deps.push(Dependency(PoolManager.NAME(), poolMgrSelectors);
    deps.push(Dependency(TokenManager.NAME(), new bytes4[]); // NO_SELECTORS);
}

function ENDPOINTS() external view returns (bytes4[] memory endpoints) {
    endpoints = new bytes4[](1);
    endpoints[0] = this.exampleEndpoint.selector;
}
*/

abstract contract Component {
    struct Dependency {
        bytes32 label;
        bytes4[] funcSelectors;
    }

    Kernel public kernel;
    mapping(address => mapping(bytes4 => bool)) public permissions;

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
        if (msg.sender != address(kernel) && !permissions[msg.sender][msg.sig]) {
            revert Component_NotPermitted();
        }
        _;
    }

    // Must be overriden to actual name of the component or else will fail on install
    function LABEL() public view virtual returns (bytes32) {
        return toLabel("");
    }

    function ACTIVE() external virtual returns (bool) {
        return kernel.isComponentActive(LABEL());
    }

    // Hook for defining and configuring dependencies
    // Gets called during installation of dependents
    function DEPENDENCIES() external virtual returns (Dependency[] memory);

    // TODO add to router's endpoints mapping
    // Hook for defining which functions can be routed through the kernel
    function ENDPOINTS() external virtual returns (bytes4[] memory endpoints_);

    function INIT(bytes memory data_) external onlyKernel {
        _init(data_);
    }

    // Must be overridden to do custom initialization
    function _init(bytes memory data_) internal virtual;

    /// @notice Function used by kernel when migrating to a new kernel.
    function changeKernel(Kernel newKernel_) external onlyKernel {
        kernel = newKernel_;
    }

    function setPermissions(address component_, bytes4[] memory selectors_, bool isAllowed_) external onlyKernel {
        if (selectors_[0] == bytes4(0)) return;
        for (uint256 i; i < selectors_.length; i++) {
            console2.log("permission ");
            console2.logBytes32(Component(component_).LABEL());
            console2.logBytes4(selectors_[i]);

            permissions[component_][selectors_[i]] = isAllowed_;
        }
    }

    // ERC-165. Used by Kernel to check if a component is installable.
    // TODO might need to be virtual, so it can be overridden by mutable components
    function supportsInterface(bytes4 interfaceId_) external view virtual returns (bool) {
        return type(Component).interfaceId == interfaceId_;
    }

    function toLabel(string memory typeName_) internal pure returns (bytes32) {
        return bytes32(bytes(typeName_));
    }

    function getComponentAddr(string memory labelString_) internal view returns (address) {
        return getComponentAddr(toLabel(labelString_));
    }

    function getComponentAddr(bytes32 contractName_) internal view returns (address) {
        return address(kernel.getComponentForLabel(contractName_));
    }
}

// TODO make upgrades via kernel action. Uses transparent proxy pattern.
// TODO should be UUPS?
//      - if so, this contract needs to inherit UUPSUpgradeable
// TODO needs ERC1967Factory to be able to upgrade
abstract contract MutableComponent is Component, Initializable {
    // TODO think about versioning
    /*uint8 public version;*/

    // TODO bool to indicate if component is mutable
    function isMutable() external pure returns (bool) {
        return true;
    }

    // TODO make sure this works
    // Special INIT function for upgradeable that can only be called once
    function _init(bytes memory encodedArgs_) internal override onlyInitializing onlyKernel {
        /*super._init(encodedArgs_);*/
    }
}

/// @notice Kernel contract that manages the installation and execution of components.
/// @dev    Uses a DAG to manage dependencies and permissions between components
contract Kernel is ERC1967Factory {
    using LibDAG for LibDAG.DAG;

    /// @notice Actions to trigger state changes in the kernel. Passed by the executor
    enum Actions {
        INSTALL,
        INSTALL_MUT,
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

    /// @notice Component <> Component permissions
    /// @dev    Component -> Component -> function selector -> bool for permission
    /*mapping(Component => mapping(Component => mapping(bytes4 => bool))) public permissions;*/

    event ActionExecuted(Actions action, address target);

    error Kernel_CannotInstall();
    error Kernel_ComponentNotInstalled();
    error Kernel_ComponentMustBeMutable();
    error Kernel_ComponentHasDependents(uint256 numDependents);
    error Kernel_InvalidConfig();

    constructor() {
        _changeExecutor(msg.sender);
    }

    // TODO add real error message
    modifier verifyComponent(address target_) {
        if (!Component(target_).supportsInterface(type(Component).interfaceId)) revert();
        _;
    }

    // TODO think about allowing other contracts to install components. ie, a factory
    function executeAction(Actions action_, address target_, bytes memory data_) external {
        // Only Executor can execute actions
        require(msg.sender == executor);

        if (action_ == Actions.INSTALL) _installComponent(target_, data_);
        /*else if (action_ == Actions.INSTALL_MUT) _installMutableComponent(target_);*/
        else if (action_ == Actions.UNINSTALL) _uninstallComponent(target_);
        /*else if (action_ == Actions.UPGRADE)     _upgradeComponent(target_);*/
        else if (action_ == Actions.CHANGE_EXEC) _changeExecutor(target_);
        /*else if (action_ == Actions.MIGRATE)     _migrateKernel(Kernel(target_));*/

        emit ActionExecuted(action_, target_);
    }

    function _installComponent(address target_, bytes memory data_) internal verifyComponent(target_) {
        Component component = Component(target_);

        bytes32 label = component.LABEL();
        if (isComponentActive(label)) revert Kernel_CannotInstall();
        if (label == "") revert Kernel_CannotInstall();

        console2.log("STEP 1");

        // Add node to graph
        componentGraph.addNode(label);
        getComponentForLabel[label] = component;

        console2.log("STEP 2");
        // Add all read and write dependencies
        Component.Dependency[] memory deps = component.DEPENDENCIES();

        for (uint256 i; i < deps.length; ++i) {
            // TODO don't think this is possible. If label doesn't exist, then the edge can't exist
            if (componentGraph.hasEdge(label, deps[i].label)) revert Kernel_InvalidConfig();

            Component dependency = getComponentForLabel[deps[i].label];

            console2.log("STEP 3");
            // Create edge between component and dependency
            componentGraph.addEdge(label, deps[i].label);

            // Add permissions for any functions that need it
            dependency.setPermissions(target_, deps[i].funcSelectors, true);
        }

        // TODO Add endpoints to router

        component.INIT(data_);

        // emit event
    }

    // TODO takes implementation contract and deploys proxy for it, and records proxy
    function _installMutableComponent(address target_, bytes memory data_) internal verifyComponent(target_) {
        MutableComponent component = MutableComponent(target_);
        if (!component.isMutable()) revert Kernel_ComponentMustBeMutable();

        // TODO get READs and WRITEs
        // TODO check for cycles
        // TODO add dependencies
        // TODO add permissions

        component.INIT(data_);
    }

    function _uninstallComponent(address target_) internal verifyComponent(target_) {
        Component component = Component(target_);
        bytes32 label = component.LABEL();
        if (!isComponentActive(label)) revert Kernel_ComponentNotInstalled();

        uint256 numDependents = componentGraph.getInDegree(label);
        if (numDependents > 0) revert Kernel_ComponentHasDependents(numDependents);

        // Remove all permissions
        Component.Dependency[] memory deps = component.DEPENDENCIES();

        for (uint256 i; i < deps.length; ++i) {
            Component dependency = getComponentForLabel[deps[i].label];

            // Remove permissions for any functions that need it
            dependency.setPermissions(target_, deps[i].funcSelectors, false);
        }

        // Remove component node and associated edges from graph
        componentGraph.removeNode(label);
        getComponentForLabel[label] = Component(address(0));
    }

    // TODO call `upgradeAndCall` on the target and its INIT function
    function _upgradeComponent(address target_, bytes calldata data_) internal verifyComponent(target_) {
        //Component component = Component(target_);

        // TODO Check if component is installed
        // TODO get dependencies
        // TODO check for cycles
        // TODO add dependencies
        // TODO add permissions

        // TODO call `upgradeAndCall` on the traget and its INIT function
        /*upgradeAndCall(
            target_,
            abi.encodeWithSelector(Component.INIT.selector),
            encodedArgs_
        );*/

        // Emit
    }

    function _runScript(address target_) internal {
        // TODO
    }

    function _changeExecutor(address target_) internal {
        executor = target_;
    }

    function _migrateKernel(address target_) internal {
        // TODO
    }

    function _reconfigureDependents(address target_) internal {
        // TODO needs to be called for all dependencies. Needs DFS
    }

    // TODO Add dynamic routing to components
    // TODO allow router to load data into transient memory before routing

    function isComponentActive(bytes32 label_) public view returns (bool) {
        return componentGraph.getNode(label_).exists;
    }
}
