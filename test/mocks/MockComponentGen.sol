// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Kernel, Component } from "src/Kernel.sol";

contract MockComponentGen is Component {
    bytes32 public label;
    Dependency[] public deps;
    bytes4[] public endpoints;

    constructor(
        address kernel_,
        bytes32 label_,
        Dependency[] memory deps_,
        bytes4[] memory endpoints_
    )
        Component(kernel_)
    {
        label = label_;
        endpoints = endpoints_;

        for (uint256 i; i < deps_.length; i++) {
            deps.push(deps_[i]);
        }
    }

    function LABEL() public view override returns (bytes32) {
        return label;
    }

    function DEPENDENCIES() external view override returns (Dependency[] memory) {
        return deps;
    }

    function ENDPOINTS() external view override returns (bytes4[] memory) {
        return endpoints;
    }

    function _init(bytes memory) internal override { }
}
