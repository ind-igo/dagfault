// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { Kernel, Component, MutableComponent } from "src/Kernel.sol";
import "test/mocks/MockComponentGen.sol";
import "test/mocks/MockComponent1.sol";
import "test/mocks/MockComponent2.sol";
import "test/mocks/MockComponent3.sol";

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
        component1 = new MockComponent1(address(kernel));
        component2 = new MockComponent2(address(kernel));
        component3 = new MockComponent3(address(kernel));
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
        Component readOnly = new MockComponentGen(address(kernel), "ReadOnlyDep", readDep);

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

        // Check that endpoint 
    }

    // TODO might not be possible
    // function testRevert_Install_BadConfig() public { }

    function test_Upgrade() public afterInstallMockComp1 afterInstallMockComp2 {
        MutableComponent impl2 = MutableComponent(address(new MockComponentGen(
            address(kernel),
            "MockComponent2",
            new Component.Dependency[](0)
        )));
        MockComponent1 newComponent1 = new MockComponent1(address(kernel));
        kernel.executeAction(Kernel.Actions.UPGRADE, address(component1), abi.encode(address(newComponent1)));

        assertTrue(kernel.isComponentInstalled(newComponent1.LABEL()));
        assertFalse(kernel.isComponentInstalled(component1.LABEL()));
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
