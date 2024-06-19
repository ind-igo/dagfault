// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Kernel, Component} from "src/Kernel.sol";

contract MockComponentGen is Component {
    bytes32 public label;
    Dependency[] public deps;
    bytes4[] public endpoints;

    constructor(
        address kernel_,
        bytes32 label_,
        Dependency[] memory deps_,
        bytes4[] memory endpoints_
    ) Component(kernel_) {
        label = label_;
        deps = deps_;
        endpoints = endpoints_;
    }

    function LABEL() public override view returns (bytes32) {
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
