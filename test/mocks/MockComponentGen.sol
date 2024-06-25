// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Kernel, Component } from "src/Kernel.sol";

contract MockComponentGen is Component {
    bytes32 public label;
    Dependency[] public deps;

    constructor(
        address kernel_,
        bytes32 label_,
        Dependency[] memory deps_
    )
        Component(kernel_)
    {
        label = label_;

        for (uint256 i; i < deps_.length; i++) {
            deps.push(deps_[i]);
        }
    }

    function LABEL() public view override returns (bytes32) {
        return label;
    }

    function CONFIG() external view override returns (Dependency[] memory) {
        return deps;
    }

    function _init(bytes memory) internal override { }
}
