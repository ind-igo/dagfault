// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { Kernel, Component, MutableComponent } from "src/Kernel.sol";
import {LibDAG} from "src/LibDAG.sol";
import "test/mocks/MockComponentGen.sol";
import "test/mocks/MockMutableComponentGen.sol";
import "test/mocks/MockComponent1.sol";
import "test/mocks/MockComponent2.sol";
import "test/mocks/MockComponent3.sol";
import {MockMutableComponent2 as MockMutableV1} from "test/mocks/MockMutableComponent2V1.sol";
import {MockMutableComponent2 as MockMutableV2} from "test/mocks/MockMutableComponent2V2.sol";

import {console2} from "forge-std/console2.sol";

/*
todo tests:
- upgrade
- upgrade with perms and deps
- upgrade with re-init
- upgrade with cycle (fail)
*/
contract KernelTest is Test {
    Kernel kernel;
    MockComponent1 component1;
    MockComponent2 component2;
    MockComponent3 component3;

    function setUp() public {
        kernel = new Kernel();
        component1 = new MockComponent1();
        component2 = new MockComponent2();
        component3 = new MockComponent3();
    }

    modifier afterInstallMockComp1() {
        kernel.executeAction(Kernel.Actions.INSTALL, address(component1), bytes(""));
        _;
    }

    modifier afterInstallMockComp2() {
        kernel.executeAction(Kernel.Actions.INSTALL, address(component2), bytes(""));
        _;
    }

    modifier afterInstallMockComp3() {
        address data1 = address(0x1234);
        bytes32 data2 = bytes32("hello");
        bytes memory encodedData = abi.encode(data1, data2);
        kernel.executeAction(Kernel.Actions.INSTALL, address(component3), encodedData);
        _;
    }

    function test_Install() public afterInstallMockComp1 {
        assertTrue(kernel.isComponentInstalled(component1.LABEL()));
        assertEq(address(kernel.getComponentForLabel(component1.LABEL())), address(component1));
    }

    function test_Install_WithDeps() public afterInstallMockComp1 afterInstallMockComp2 {
        assertTrue(kernel.isComponentInstalled(component1.LABEL()));
        assertTrue(kernel.isComponentInstalled(component2.LABEL()));
        assertEq(address(kernel.getComponentForLabel(component1.LABEL())), address(component1));
        assertEq(address(kernel.getComponentForLabel(component2.LABEL())), address(component2));

        // Check dependencies were properly set
        assertEq(address(component2.comp1()), address(component1));
    }

    function test_Install_WithInitAndPerms() public afterInstallMockComp1 afterInstallMockComp2 afterInstallMockComp3 {
        assertTrue(kernel.isComponentInstalled(component1.LABEL()));
        assertEq(address(kernel.getComponentForLabel(component1.LABEL())), address(component1));

        // Check dependencies were properly set
        assertEq(address(component3.comp1()), address(component1));
        assertEq(address(component3.comp2()), address(component2));

        // Check data from init
        vm.prank(address(kernel));
        uint256 data3 = component3.dataFromComponent1();

        assertEq(component3.data1(), address(0x1234));
        assertEq(component3.data2(), bytes32("hello"));
        assertEq(component3.dataFromComponent1(), data3);
    }

    function test_Install_ReadOnlyDep() public afterInstallMockComp1 {
        Component.Dependency[] memory readDep = new Component.Dependency[](1);
        bytes4[] memory funcSelectors = new bytes4[](1);
        readDep[0] = Component.Dependency({ label: component1.LABEL(), funcSelectors: funcSelectors });

        // Make new component with read only dependency
        Component readOnly = new MockComponentGen("ReadOnlyDep", readDep);

        kernel.executeAction(Kernel.Actions.INSTALL, address(readOnly), bytes(""));

        assertTrue(kernel.isComponentInstalled(readOnly.LABEL()));
        assertEq(address(kernel.getComponentForLabel(readOnly.LABEL())), address(readOnly));
    }

    // TODO this test fails but not sure why
    function testRevert_Install_NotComponent() public {
        vm.expectRevert(Kernel.Kernel_InvalidConfig.selector);
        kernel.executeAction(Kernel.Actions.INSTALL, address(0x1234), bytes(""));
    }

    // TODO
    // function testRevert_Install_WithCycle() public {}

    function testRevert_Install_AlreadyExists() public afterInstallMockComp1 {
        vm.expectRevert(Kernel.Kernel_ComponentAlreadyInstalled.selector);
        kernel.executeAction(Kernel.Actions.INSTALL, address(component1), bytes(""));
    }

    function test_Upgrade() public afterInstallMockComp1 {
        // Create initial mutable component
        // Component.Dependency[] memory initialDeps = new Component.Dependency[](1);

        MockMutableV1 initialComponent = new MockMutableV1();
        bytes32 label = initialComponent.LABEL();

        // Install initial component
        kernel.executeAction(Kernel.Actions.INSTALL, address(initialComponent), "");

        // Create new version of the component
        MockMutableV2 newComponent = new MockMutableV2();

        // Perform upgrade
        bytes32 testData = "test deez nutz";
        bytes memory upgradeData = abi.encode(420, testData);
        kernel.executeAction(Kernel.Actions.UPGRADE, address(newComponent), upgradeData);

        MockMutableV2 proxy = MockMutableV2(
            address(kernel.getComponentForLabel(newComponent.LABEL()))
        );
        bytes32 ERC1967_IMPLEMENTATION_SLOT =
            0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 v = vm.load(address(proxy), ERC1967_IMPLEMENTATION_SLOT);

        // Verify upgrade
        assertTrue(kernel.isComponentInstalled(newComponent.LABEL()));
        assertEq(address(uint160(uint256(v))), address(newComponent));
        assertEq(proxy.LABEL(), label);
        assertEq(proxy.VERSION(), 2);
        assertEq(proxy.number(), 420);
        assertEq(proxy.testData(), testData);
    }

    // function test_PreventCyclicDependency() public {
    function testRevert_Upgrade_withCycle() public {
        // Create component A
        bytes32 labelA = bytes32("ComponentA");
        Component.Dependency[] memory depsA = new Component.Dependency[](1);
        MockMutableComponentGen componentA = new MockMutableComponentGen(
            labelA,
            depsA
        );
        bytes memory componentAData = abi.encode(labelA, depsA);
        kernel.executeAction(Kernel.Actions.INSTALL, address(componentA), componentAData);

        // Create component B with a dependency on A
        Component.Dependency[] memory depsB = new Component.Dependency[](1);
        depsB[0] = Component.Dependency({
            label: componentA.LABEL(),
            funcSelectors: new bytes4[](1)
        });
        depsB[0].funcSelectors[0] = componentA.permissionedFunction.selector;
        MockMutableComponentGen componentB = new MockMutableComponentGen(
            bytes32("ComponentB"),
            depsB
        );
        kernel.executeAction(Kernel.Actions.INSTALL, address(componentB), "");

        // Now try to upgrade component A to depend on B, which would create a cycle
        Component.Dependency[] memory newDepsA = new Component.Dependency[](1);
        newDepsA[0] = Component.Dependency({
            label: componentB.LABEL(),
            funcSelectors: new bytes4[](1)
        });
        newDepsA[0].funcSelectors[0] = componentB.permissionedFunction.selector;
        MockMutableComponentGen newComponentA = new MockMutableComponentGen(
            bytes32("ComponentA"),
            newDepsA
        );
        newComponentA.setVersion(2);

        // This should revert due to creating a cyclic dependency
        vm.expectRevert(LibDAG.AddingEdgeCreatesCycle.selector);
        kernel.executeAction(Kernel.Actions.UPGRADE, address(componentA), abi.encode(address(newComponentA)));
    }

    function test_Uninstall() public afterInstallMockComp1 {
        kernel.executeAction(Kernel.Actions.UNINSTALL, address(component1), "");
        assertFalse(kernel.isComponentInstalled(component1.LABEL()));
    }

    function test_Uninstall2() public afterInstallMockComp1 afterInstallMockComp2 {
        kernel.executeAction(Kernel.Actions.UNINSTALL, address(component2), "");
        assertTrue(kernel.isComponentInstalled(component1.LABEL()));
        assertFalse(kernel.isComponentInstalled(component2.LABEL()));
    }

    function testRevert_Uninstall_NotInstalled() public {
        vm.expectRevert(Kernel.Kernel_ComponentNotInstalled.selector);
        kernel.executeAction(Kernel.Actions.UNINSTALL, address(component1), "");
    }

    function testRevert_Uninstall_WithDependents() public afterInstallMockComp1 afterInstallMockComp2 {
        vm.expectRevert(
            abi.encodeWithSelector(Kernel.Kernel_ComponentHasDependents.selector, 1)
        );
        kernel.executeAction(Kernel.Actions.UNINSTALL, address(component1), "");
    }

    function test_ChangeExecutor() public {
        address newExecutor = address(0x1234);
        kernel.executeAction(Kernel.Actions.CHANGE_EXEC, newExecutor, "");

        assertEq(kernel.executor(), newExecutor);
    }
}
