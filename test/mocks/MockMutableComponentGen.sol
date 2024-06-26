// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Kernel, Component, MutableComponent } from "src/Kernel.sol";
import {console2} from "forge-std/console2.sol";

contract MockMutableComponentGen is MutableComponent {
    bytes32 immutable label;
    uint8 private version;
    Component.Dependency[] public dependencies;
    mapping(bytes4 => bool) public functionCalled;
    bool initCalled;

    constructor(address kernel_, bytes32 label_, Component.Dependency[] memory deps_) 
        MutableComponent(kernel_) 
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

    function __init(bytes memory) internal override {
        console2.log("IN INIT");
        // Custom initialization logic can be added here
        initCalled = true;
    }

    // Function to check if a specific function was called
    function wasFunctionCalled(bytes4 functionSelector) public view returns (bool) {
        return functionCalled[functionSelector];
    }

    // Add more functions as needed for testing
    function testFunction() public {
        functionCalled[this.testFunction.selector] = true;
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