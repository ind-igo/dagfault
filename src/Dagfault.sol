// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { UUPSUpgradeable, Initializable, LibClone } from "solady/src/Milady.sol";
import { LibDAG } from "./LibDAG.sol";

abstract contract Component is Initializable {
    struct Permissions {
        bytes32 label;
        bytes4[] funcSelectors;
    }

    Kernel public kernel;
    mapping(Component => mapping(bytes4 => bool)) public permissions;

    error Component_OnlyKernel(address sender_);
    error Component_NotPermitted();

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

    // --- Component API ------------------------------------------------------

    // Must be overidden to actual name of the component or else will fail on install
    function LABEL() public view virtual returns (bytes32) {
        return toLabel("");
    }

    // Denotes version of the upgrade. Used to ensure `INIT` only gets called once per version.
    function VERSION() public view virtual returns (uint8) {
        return 1;
    }

    // Custom initialization logic. Only called once per version.
    function INIT(bytes memory data_) internal virtual;

    /// @notice Hook for defining and configuring dependencies.
    /// @return An array of dependencies for kernel to record
    function CONFIG() internal virtual returns (Permissions[] memory);

    // --- Kernel API ------------------------------------------------------

    // Initializer for setting kernel and calling custom INIT logic.
    // Called by kernel when installing/upgrading a component.
    function initializeComponent(address kernel_, bytes memory data_)
        external
        reinitializer(VERSION())
    {
        kernel = Kernel(kernel_);
        INIT(data_);
    }

    // Called by kernel to configure dependencies and return permissions needed for a component.
    function configureDependencies() external onlyKernel returns (Permissions[] memory) {
        return CONFIG();
    }

    function setPermissions(
        Component component_,
        bytes4[] memory selectors_,
        bool isAllowed_
    ) external onlyKernel {
        // Early return if no selectors
        if (selectors_[0] == bytes4(0)) return;

        for (uint256 i; i < selectors_.length; i++) {
            permissions[component_][selectors_[i]] = isAllowed_;
        }
    }

    // --- Query Functions ---------------------------------------------

    // Return if the component is installed in the kernel
    function isInstalled() external view returns (bool) {
        return kernel.isComponentInstalled(LABEL());
    }

    function isMutable() external view virtual returns (bool) {
        return false;
    }

    // ERC-165. Used by Kernel to check if a component is installable.
    function supportsInterface(bytes4 interfaceId_) external pure virtual returns (bool) {
        return type(Component).interfaceId == interfaceId_;
    }

    // --- Helpers ------------------------------------------------------

    function toLabel(string memory typeName_) internal pure returns (bytes32) {
        return bytes32(bytes(typeName_));
    }

    function getComponentAddr(bytes32 label_) internal view returns (address) {
        return address(kernel.getComponentForLabel(label_));
    }
}

abstract contract MutableComponent is Component, UUPSUpgradeable {

    function _authorizeUpgrade(address) internal view override onlyKernel {}

    function isMutable() external pure override returns (bool) {
        return true;
    }

    function supportsInterface(bytes4 interfaceId_) external pure override returns (bool) {
        return
            interfaceId_ == type(Component).interfaceId ||
            interfaceId_ == type(MutableComponent).interfaceId;
    }
}

/// @notice Kernel contract that manages the installation and execution of components.
/// @dev    Uses a DAG to manage dependencies and permissions between components
contract Kernel {
    using LibDAG for LibDAG.DAG;

    /// @notice Actions to trigger state changes in the kernel. Passed by the executor
    enum Actions {
        INSTALL,
        UPGRADE,
        UNINSTALL,
        RUN_SCRIPT,
        ADD_EXEC,
        REMOVE_EXEC
    }

    /// @notice Used by executor to select an action and a target contract for a kernel action
    struct Instruction {
        Actions action;
        address target;
    }

    struct ComponentCall {
        bytes32 componentLabel;
        bytes4 funcSelector;
        bytes callData;
    }

    mapping(address => bool) public executors;

    LibDAG.DAG private componentGraph;
    mapping(bytes32 => Component) public getComponentForLabel;
    mapping(bytes32 => uint256) public getIdForLabel;

    event ActionExecuted(Actions action, address target);

    error Kernel_CannotInstall();
    error Kernel_ComponentNotFound();
    error Kernel_ComponentAlreadyInstalled();
    error Kernel_ComponentNotInstalled();
    error Kernel_ComponentMustBeMutable();
    error Kernel_ComponentHasDependents(uint256 numDependents);
    error Kernel_InvalidConfig();
    error Kernel_EndpointAlreadyExists();
    error Kernel_InvalidAddress();
    error Kernel_CannotRemoveSelf();

    constructor() {
        _addExecutor(msg.sender);
    }

    modifier verifyComponent(address target_) {
        if (!Component(target_).supportsInterface(type(Component).interfaceId)) revert Kernel_InvalidConfig();
        _;
    }

    function isComponentInstalled(bytes32 label_) public view returns (bool) {
        return componentGraph.getNode(getIdForLabel[label_]).exists;
    }

    // TODO
    function batchExecuteActions(Actions[] memory actions_, address[] memory targets_, bytes[] memory data_) external {
        // Only executors can execute actions
        if (!executors[msg.sender]) revert Kernel_InvalidAddress();

        for (uint256 i; i < actions_.length; i++) {
            executeAction(actions_[i], targets_[i], data_[i]);
        }
    }

    function executeAction(Actions action_, address target_, bytes memory data_) public {
        // Only executors can execute actions
        if (!executors[msg.sender]) revert Kernel_InvalidAddress();

        if (action_ == Actions.INSTALL)          _installComponent(target_, data_);
        else if (action_ == Actions.UPGRADE)     _upgradeComponent(target_, data_);
        else if (action_ == Actions.UNINSTALL)   _uninstallComponent(target_);
        else if (action_ == Actions.RUN_SCRIPT)  _runScript(data_);
        else if (action_ == Actions.ADD_EXEC)    _addExecutor(target_);
        else if (action_ == Actions.REMOVE_EXEC) _removeExecutor(target_);

        emit ActionExecuted(action_, target_);
    }

    function _installComponent(address target_, bytes memory data_) internal verifyComponent(target_) {
        bytes32 label = Component(target_).LABEL();

        if (isComponentInstalled(label)) revert Kernel_ComponentAlreadyInstalled();
        if (label == "") revert Kernel_InvalidConfig();

        // If component is mutable, deploy its proxy and use that address as the install target
        // Else, use the target argument as a regular component
        Component component = Component(target_).isMutable()
            ? MutableComponent(LibClone.deployERC1967(target_))
            : Component(target_);


        // Initialize component to set kernel and pass init data
        component.initializeComponent(address(this), data_);

        // Add node to graph and mappings
        uint256 id = componentGraph.addNode(label);
        getComponentForLabel[label] = component;
        getIdForLabel[label] = id;

        // Add all read and write dependencies
        _addDependencies(component);

        emit ActionExecuted(Actions.INSTALL, address(component));
    }

    // Upgrade a mutable component to a new implementation
    // NOTE: Can add new dependencies, but cannot remove existing ones
    // NOTE: MAKE SURE UPGRADE IS SAFE. Use provided tools to ensure safety.
    function _upgradeComponent(address newImpl_, bytes memory data_) internal verifyComponent(newImpl_) {
        bytes32 label = MutableComponent(newImpl_).LABEL();

        if (!isComponentInstalled(label)) revert Kernel_ComponentNotInstalled();

        // Get previous version by label
        MutableComponent componentProxy = MutableComponent(address(getComponentForLabel[label]));

        if (!componentProxy.isMutable()) revert Kernel_ComponentMustBeMutable();
        if (MutableComponent(newImpl_).VERSION() <= componentProxy.VERSION()) revert Kernel_InvalidConfig();

        // Remove all permissions for old implementation
        Component.Permissions[] memory deps = componentProxy.configureDependencies();
        for (uint256 i; i < deps.length; ++i) {
            Component Permissions = getComponentForLabel[deps[i].label];
            Permissions.setPermissions(componentProxy, deps[i].funcSelectors, false);
        }

        // Upgrade to and initialize the new implementation
        componentProxy.upgradeToAndCall(
            newImpl_,
            abi.encodeWithSelector(
                Component.initializeComponent.selector,
                address(this),
                data_
            )
        );

        // Add new dependencies and permissions for the new implementation, if any
        _addDependencies(componentProxy);

        // Reconfigure all dependents to point to new implementation
        _reconfigureDependents(componentProxy);

        emit ActionExecuted(Actions.UPGRADE, newImpl_);
    }

    function _uninstallComponent(address target_) internal verifyComponent(target_) {
        Component component = Component(target_);

        bytes32 label = component.LABEL();
        if (!isComponentInstalled(label)) revert Kernel_ComponentNotInstalled();

        uint256 id = getIdForLabel[label];

        uint256 numDependents = componentGraph.getInDegree(id);
        if (numDependents > 0) revert Kernel_ComponentHasDependents(numDependents);

        // Remove all permissions
        Component.Permissions[] memory deps = component.configureDependencies();

        for (uint256 i; i < deps.length; ++i) {
            Component Permissions = getComponentForLabel[deps[i].label];
            Permissions.setPermissions(component, deps[i].funcSelectors, false);
        }

        // Remove component node and associated edges from graph
        componentGraph.removeNode(id);
        getComponentForLabel[label] = Component(address(0));

        emit ActionExecuted(Actions.UNINSTALL, target_);
    }

    function _runScript(bytes memory scriptData_) internal {
        (ComponentCall[] memory calls) = abi.decode(scriptData_, (ComponentCall[]));

        for (uint256 i; i < calls.length; i++) {
            Component component = getComponentForLabel[calls[i].componentLabel];
            if (address(component) == address(0)) revert Kernel_ComponentNotFound();

            (bool success, bytes memory result) = address(component).call(
                abi.encodePacked(calls[i].funcSelector, calls[i].callData)
            );

            if (!success) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }
        }
    }

    function _addExecutor(address newExecutor_) internal {
        if (newExecutor_ == address(0)) revert Kernel_InvalidAddress();
        executors[newExecutor_] = true;
    }

    function _removeExecutor(address executor_) internal {
        if (!executors[executor_]) revert Kernel_InvalidAddress();
        if (msg.sender == executor_) revert Kernel_CannotRemoveSelf();
        executors[executor_] = false;
    }

    // === HELPER FUNCTIONS ======================================================

    // Add all read and write dependencies
    // NOTE: This can only add new dependencies. Will also SKIP existing ones.
    //       This means it will NOT revert if a component has duplicate dependencies.
    function _addDependencies(Component component_) internal {
        uint256 id = getIdForLabel[component_.LABEL()];
        Component.Permissions[] memory deps = component_.configureDependencies();

        for (uint256 i; i < deps.length; ++i) {
            uint256 depId = getIdForLabel[deps[i].label];

            // If Permissions exists, skip
            if (componentGraph.hasEdge(id, depId)) continue;

            // Check for new dependencies and add permissions as needed
            componentGraph.addEdge(id, depId);

            // Add permissions for any functions that need it
            Component Permissions = getComponentForLabel[deps[i].label];
            Permissions.setPermissions(component_, deps[i].funcSelectors, true);
        }
    }

    // Use DFS to call CONFIG on all dependents
    function _reconfigureDependents(MutableComponent component_) internal {
        uint256 startId = getIdForLabel[component_.LABEL()];

        bool[] memory visited = new bool[](componentGraph.nodeCount + 1);
        uint256[] memory stack = new uint256[](componentGraph.nodeCount);
        uint256 stackSize;

        stack[stackSize++] = startId;

        while (stackSize > 0) {
            uint256 currentId = stack[--stackSize];

            if (!visited[currentId]) {
                visited[currentId] = true;

                // Process the current node
                getComponentForLabel[componentGraph.getNode(currentId).data].configureDependencies();

                // Push all unvisited incoming neighbors to the stack
                uint256[] memory incomingEdges = componentGraph.getIncomingEdges(currentId);
                for (uint256 i; i < incomingEdges.length; i++) {
                    uint256 neighborId = incomingEdges[i];
                    if (!visited[neighborId]) {
                        stack[stackSize++] = neighborId;
                    }
                }
            }
        }
    }

    // === VIEW FUNCTIONS ======================================================

    function getComponentDetails(bytes32 label) public view returns (
        address componentAddress,
        bytes32[] memory dependencyLabels,
        bytes32[] memory dependentLabels
    ) {
        uint256 id = getIdForLabel[label];
        LibDAG.Node memory node = componentGraph.getNode(id);
        if(!node.exists) revert Kernel_ComponentNotFound();

        componentAddress = address(getComponentForLabel[label]);

        // Convert Permissions (outgoing) edges to labels
        dependencyLabels = new bytes32[](node.outgoingEdges.length);
        for (uint256 i; i < node.outgoingEdges.length; i++) {
            dependencyLabels[i] = bytes32(componentGraph.getNode(node.outgoingEdges[i]).data);
        }

        // Convert dependent (incoming) edges to labels
        dependentLabels = new bytes32[](node.incomingEdges.length);
        for (uint256 i; i < node.incomingEdges.length; i++) {
            dependentLabels[i] = bytes32(componentGraph.getNode(node.incomingEdges[i]).data);
        }
    }
}
