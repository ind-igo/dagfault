// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Kernel, Component} from "../src/Kernel.sol";

contract DirectMigrationScript is Script {
    Kernel public oldKernel;
    Kernel public newKernel;
    address public deployer;

    function setUp() public {
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
        oldKernel = Kernel(vm.envAddress("OLD_KERNEL_ADDRESS"));
    }

    function run() public {
        vm.startBroadcast(deployer);

        // Deploy new kernel
        newKernel = new Kernel();

        console.log("Starting direct migration from kernel at", address(oldKernel));

        // Iterate through all components and migrate them
        for (uint256 i = 1; i <= oldKernel.componentGraph().nodeCount; i++) {
            (bool exists, bytes32 label, uint256[] memory outgoingEdges, uint256[] memory incomingEdges) = oldKernel.getComponentDetails(i);
            
            if (exists) {
                address componentAddress = address(oldKernel.getComponentForLabel(label));
                
                // Import component to new kernel
                newKernel.importComponent(label, componentAddress, outgoingEdges, incomingEdges);
                
                // Update component's kernel reference
                Component(componentAddress).changeKernel(newKernel);
                
                console.log("Migrated component: %s", vm.toString(label));
            }
        }

        // Transfer executor role to the new kernel
        newKernel.setExecutor(oldKernel.executor());

        // Disable old kernel
        oldKernel.setExecutor(address(0));

        console.log("Migration completed successfully");
        console.log("New kernel address:", address(newKernel));

        // Verify migration
        require(newKernel.executor() == oldKernel.executor(), "Executor not transferred correctly");
        require(oldKernel.executor() == address(0), "Old kernel not disabled");

        vm.stopBroadcast();
    }
}