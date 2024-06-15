// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Component} from "src/Kernel.sol";

// Make cause a cycle
contract BadComponent_Cycle is Component {
    constructor(address kernel_) Component(kernel_) {}

    function LABEL() public pure override returns (bytes32) {
        return bytes32("MockBadComponent");
    }

    function DEPENDENCIES() external pure override returns (Dependency[] memory) {
        Dependency[] memory deps = new Dependency[](1);

    }

    function ENDPOINTS() external pure override returns (bytes4[] memory) {}

    function _init(bytes memory data_) internal pure override {
    }

    function mockEndpoint1() external view returns (uint256) {
        return 1;
    }

    function mockEndpoint2() external pure returns (uint256) {
        return 2;
    }
}

contract MockComponent_BadLabel is Component {
    constructor(address kernel_) Component(kernel_) {}

    function LABEL() public pure override returns (bytes32) {
        return bytes32("");
    }
}

contract MockComponent_DupeLabel is Component {
    constructor(address kernel_) Component(kernel_) {}

    function LABEL() public pure override returns (bytes32) {
        return bytes32("MockComponent1");
    }
}

contract MockComponent_DupeDependency is Component {
    constructor(address kernel_) Component(kernel_) {}

    function LABEL() public pure override returns (bytes32) {
        return bytes32("DupeDep");
    }

    function DEPENDENCIES() external pure override returns (Dependency[] memory) {
        Dependency[] memory deps = new Dependency[](2);
        deps[0].label = "MockComponent1";
        deps[1].label = "MockComponent1";
    }
}

contract MockComponentGen is Component {
    bytes32 public label;
    Dependency[] public deps;
    bytes4[] public endpoints;

    constructor(
        bytes32 label_,
        Dependency[] memory deps_,
        bytes4[] memory endpoints_
    ) {
        label = label_;
        if (deps_.length > 0) deps = deps;
        if (endpoints_.length > 0) endpoints = endpoints_;
    }

    function LABEL() external override view returns (bytes32) {
        return label;
    }

    function DEPENDENCIES() external override view returns (Dependency[] memory) {
        return deps;
    }

    function ENDPOINTS() external override view returns (bytes4[] memory) {
        return endpoints;
    }

    function _init(bytes memory) internal override {}
}
