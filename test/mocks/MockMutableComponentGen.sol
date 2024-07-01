// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Kernel, Component, MutableComponent } from "src/Kernel.sol";
import {console2} from "forge-std/console2.sol";
import {Initializable} from "solady/src/utils/Initializable.sol";

contract MockMutableComponentGen is MutableComponent {
    bytes32 label;
    uint8 private version;
    Component.Dependency[] public dependencies;
    mapping(bytes4 => bool) public functionCalled;
    bool initCalled;

    constructor(bytes32 label_, Component.Dependency[] memory deps_)
    {
        label = label_;
        version = 1;

        setDependencies(deps_);
    }

    function LABEL() public view override returns (bytes32) {
        return label;
    }

    function VERSION() public view override returns (uint8) {
        return version;
    }

    function setVersion(uint8 newVersion) public {
        version = newVersion;
    }

    function CONFIG() external view override returns (Component.Dependency[] memory) {
        return dependencies;
    }

    function INIT(bytes memory data_) internal override {
        Component.Dependency[] memory deps_;

        (label, deps_) = abi.decode(data_, (bytes32, Component.Dependency[]));

        version = 1;

        setDependencies(deps_);

        initCalled = true;
    }

    // Function to check if a specific function was called
    function wasFunctionCalled(bytes4 functionSelector) public view returns (bool) {
        return functionCalled[functionSelector];
    }

    // Add more functions as needed for testing
    function functionTest() public {
        functionCalled[this.functionTest.selector] = true;
    }

    function permissionedFunction() public permissioned {
        functionCalled[this.permissionedFunction.selector] = true;
    }

    // Function to set dependencies (for testing purposes)
    function setDependencies(Component.Dependency[] memory deps_) public {
        for (uint256 i; i < deps_.length; i++) {
            dependencies.push(deps_[i]);
        }
    }
}
