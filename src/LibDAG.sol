// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library LibDAG {
    struct Node {
        uint256[] outgoingEdges;
        uint256[] incomingEdges;
        bytes32 data; // Generic data field, can be used to store any 32-byte information
        bool exists;
    }

    struct DAG {
        mapping(uint256 => Node) nodes;
        mapping(uint256 => mapping(uint256 => bool)) edges;
        uint256 nodeCount;
    }

    error NodeDoesNotExist(uint256 id);
    error NodeExists(uint256 id);
    error EdgeAlreadyExists(uint256 from, uint256 to);
    error EdgeDoesNotExist(uint256 from, uint256 to);
    error AddingEdgeCreatesCycle(uint256 from, uint256 to);

    function addNode(DAG storage self, bytes32 data) internal returns (uint256) {
        uint256 newId = ++self.nodeCount;
        if (self.nodes[newId].exists) revert NodeExists(newId);

        self.nodes[newId].exists = true;
        self.nodes[newId].data = data;
        self.nodeCount = newId;

        return newId;
    }

    function addEdge(DAG storage self, uint256 from, uint256 to) internal {
        if (!self.nodes[from].exists) revert NodeDoesNotExist(from);
        if (!self.nodes[to].exists) revert NodeDoesNotExist(to);
        if (self.edges[from][to]) revert EdgeAlreadyExists(from, to);
        if (hasCycle(self, from, to)) revert AddingEdgeCreatesCycle(from, to);

        self.edges[from][to] = true;
        self.nodes[from].outgoingEdges.push(to);
        self.nodes[to].incomingEdges.push(from);
    }

    function removeEdge(DAG storage self, uint256 from, uint256 to) internal {
        if (!self.nodes[from].exists) revert NodeDoesNotExist(from);
        if (!self.nodes[to].exists) revert NodeDoesNotExist(to);
        if (!self.edges[from][to]) revert EdgeDoesNotExist(from, to);

        self.edges[from][to] = false;
        removeFromArray(self.nodes[from].outgoingEdges, to);
        removeFromArray(self.nodes[to].incomingEdges, from);
    }

    function removeNode(DAG storage self, uint256 id) internal {
        if (!self.nodes[id].exists) revert NodeDoesNotExist(id);

        // Remove all outgoing edges
        for (uint256 i = 0; i < self.nodes[id].outgoingEdges.length; i++) {
            uint256 to = self.nodes[id].outgoingEdges[i];
            self.edges[id][to] = false;
            removeFromArray(self.nodes[to].incomingEdges, id);
        }

        // Remove all incoming edges
        for (uint256 i = 0; i < self.nodes[id].incomingEdges.length; i++) {
            uint256 from = self.nodes[id].incomingEdges[i];
            self.edges[from][id] = false;
            removeFromArray(self.nodes[from].outgoingEdges, id);
        }

        delete self.nodes[id];
    }

    function hasCycle(DAG storage self, uint256 from, uint256 to) internal view returns (bool) {
        if (from == to) return true;

        bool[] memory visited = new bool[](self.nodeCount + 1);
        uint256[] memory stack = new uint256[](self.nodeCount);
        uint256 stackSize;

        stack[stackSize++] = to;

        while (stackSize > 0) {
            uint256 current = stack[--stackSize];

            if (current == from) return true;

            if (!visited[current]) {
                visited[current] = true;

                uint256[] storage neighbors = self.nodes[current].outgoingEdges;
                for (uint256 i; i < neighbors.length; i++) {
                    if (!visited[neighbors[i]]) {
                        stack[stackSize++] = neighbors[i];
                    }
                }
            }
        }

        return false;
    }

    function getNode(DAG storage self, uint256 id) internal view returns (Node memory) {
        return self.nodes[id];
    }

    function getOutgoingEdges(DAG storage self, uint256 id) internal view returns (uint256[] memory) {
        if (!self.nodes[id].exists) revert NodeDoesNotExist(id);
        return self.nodes[id].outgoingEdges;
    }

    function getIncomingEdges(DAG storage self, uint256 id) internal view returns (uint256[] memory) {
        if (!self.nodes[id].exists) revert NodeDoesNotExist(id);
        return self.nodes[id].incomingEdges;
    }

    function hasEdge(DAG storage self, uint256 from, uint256 to) internal view returns (bool) {
        if (!self.nodes[from].exists) revert NodeDoesNotExist(from);
        if (!self.nodes[to].exists) revert NodeDoesNotExist(to);
        return self.edges[from][to];
    }

    function getInDegree(DAG storage self, uint256 id) internal view returns (uint256) {
        if (!self.nodes[id].exists) revert NodeDoesNotExist(id);
        return self.nodes[id].incomingEdges.length;
    }

    function getOutDegree(DAG storage self, uint256 id) internal view returns (uint256) {
        if (!self.nodes[id].exists) revert NodeDoesNotExist(id);
        return self.nodes[id].outgoingEdges.length;
    }

    function removeFromArray(uint256[] storage array, uint256 value) private {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
    }
}
