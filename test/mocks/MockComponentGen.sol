// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Kernel, Component } from "src/Dagfault.sol";

contract MockComponentGen is Component {
    bytes32 public label;
    Dependency[] public deps;

    constructor(
        bytes32 label_,
        Dependency[] memory deps_
    ) {
        label = label_;

        for (uint256 i; i < deps_.length; i++) {
            deps.push(deps_[i]);
        }
    }

    function LABEL() public view override returns (bytes32) {
        return label;
    }

    function CONFIG() internal view override returns (Dependency[] memory) {
        return deps;
    }

    function INIT(bytes memory) internal pure override {}
}
