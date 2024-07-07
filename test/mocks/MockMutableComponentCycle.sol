// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { Kernel, Component, MutableComponent } from "src/Dagfault.sol";

contract MockCycleComponentA_V1 is MutableComponent {
    Component.Permissions[] public dependencies;

    function LABEL() public pure override returns (bytes32) {
        return bytes32("CycleComponentA");
    }

    function VERSION() public pure override returns (uint8) {
        return 1;
    }

    function CONFIG() internal view override returns (Permissions[] memory) {
        return dependencies;
    }

    function INIT(bytes memory) internal override {}

    function setDependencies(Component.Permissions[] memory deps_) public {
        for (uint256 i; i < deps_.length; i++) {
            dependencies.push(deps_[i]);
        }
    }

    function functionA() public permissioned {}
}

contract MockCycleComponentB_V1 is MutableComponent {
    Component.Permissions[] public dependencies;

    function LABEL() public pure override returns (bytes32) {
        return bytes32("CycleComponentB");
    }

    function VERSION() public pure override returns (uint8) {
        return 1;
    }

    function CONFIG() internal pure override returns (Permissions[] memory) {
        Component.Permissions[] memory depsB = new Component.Permissions[](1);
        depsB[0] = Component.Permissions({
            label: bytes32("CycleComponentA"),
            funcSelectors: new bytes4[](1)
        });
        depsB[0].funcSelectors[0] = MockCycleComponentA_V1.functionA.selector;
        return depsB;
    }

    function INIT(bytes memory) internal override {}

    function functionB() public permissioned {}
}

contract MockCycleComponentA_V2 is MutableComponent {
    Component.Permissions[] public dependencies;

    function LABEL() public pure override returns (bytes32) {
        return bytes32("CycleComponentA");
    }

    function VERSION() public pure override returns (uint8) {
        return 2;
    }

    function CONFIG() internal pure override returns (Permissions[] memory) {
        // return dependencies;
        Component.Permissions[] memory newDepsA = new Component.Permissions[](1);
        newDepsA[0] = Component.Permissions({
            label: bytes32("CycleComponentB"),
            funcSelectors: new bytes4[](1)
        });
        newDepsA[0].funcSelectors[0] = MockCycleComponentB_V1.functionB.selector;
        return newDepsA;
    }

    function INIT(bytes memory) internal override {}

    function functionA() public permissioned {}
}