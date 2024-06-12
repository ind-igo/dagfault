// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibDAG {
    struct Node {
        bytes32[] outgoingEdges;
        uint inDegree;
        bool exists;
        uint index; // Index of the node in the array
    }

    struct DAG {
        mapping(bytes32 => Node) nodes;
        mapping(bytes32 => mapping(bytes32 => bool)) edges;
        uint nodeCount; // Total number of nodes created
    }

    error NodeDoesNotExist(bytes32 id);
    error EdgeAlreadyExists(bytes32 from, bytes32 to);
    error AddingEdgeCreatesCycle(bytes32 from, bytes32 to);

    function addNode(DAG storage self, bytes32 id) internal {
        self.nodes[id].exists = true; // Set node existence flag to true
        self.nodes[id].index = self.nodeCount; // Assign an index to the node
        self.nodeCount++;
    }

    function addEdge(DAG storage self, bytes32 from, bytes32 to) internal {
        if (!self.nodes[from].exists) {
            revert NodeDoesNotExist(from);
        }
        if (!self.nodes[to].exists) {
            revert NodeDoesNotExist(to);
        }
        if (self.edges[from][to]) {
            revert EdgeAlreadyExists(from, to);
        }
        if (hasCycle(self, from, to)) {
            revert AddingEdgeCreatesCycle(from, to);
        }

        self.edges[from][to] = true;
        self.nodes[from].outgoingEdges.push(to);
        self.nodes[to].inDegree++;
    }

    function removeNode(DAG storage self, bytes32 id) internal {
        if (!self.nodes[id].exists) {
            revert NodeDoesNotExist(id);
        }

        // Remove all outgoing edges from the node
        bytes32[] memory outgoing = self.nodes[id].outgoingEdges;
        for (uint i = 0; i < outgoing.length; i++) {
            bytes32 to = outgoing[i];
            self.nodes[to].inDegree--;
            delete self.edges[id][to];
        }

        // Remove all incoming edges to the node
        for (uint i = 0; i < outgoing.length; i++) {
            bytes32 from = outgoing[i];
            if (self.edges[from][id]) {
                self.edges[from][id] = false;
                self.nodes[id].inDegree--;
            }
        }

        // Remove the node itself
        delete self.nodes[id];
    }

    function hasCycle(DAG storage self, bytes32 from, bytes32 to) internal view returns (bool) {
        if (from == to) {
            return true;
        }

        bool[] memory visited = new bool[](self.nodeCount);
        bytes32[] memory stack = new bytes32[](self.nodeCount);
        uint stackSize = 0;

        stack[stackSize++] = to;

        while (stackSize > 0) {
            bytes32 current = stack[--stackSize];

            if (current == from) {
                return true;
            }

            uint currentIndex = self.nodes[current].index;
            if (!visited[currentIndex]) {
                visited[currentIndex] = true;

                bytes32[] memory neighbors = self.nodes[current].outgoingEdges;
                for (uint i = 0; i < neighbors.length; i++) {
                    bytes32 neighbor = neighbors[i];
                    uint neighborIndex = self.nodes[neighbor].index;
                    if (!visited[neighborIndex]) {
                        stack[stackSize++] = neighbor;
                    }
                }
            }
        }

        return false;
    }

    function getNode(DAG storage self, bytes32 id) internal view returns (Node memory) {
        if (!self.nodes[id].exists) {
            revert NodeDoesNotExist(id);
        }
        return self.nodes[id];
    }

    function getEdges(DAG storage self, bytes32 id) internal view returns (bytes32[] memory) {
        if (!self.nodes[id].exists) {
            revert NodeDoesNotExist(id);
        }
        return self.nodes[id].outgoingEdges;
    }

    function getInDegree(DAG storage self, bytes32 id) internal view returns (uint) {
        if (!self.nodes[id].exists) {
            revert NodeDoesNotExist(id);
        }
        return self.nodes[id].inDegree;
    }

    function hasEdge(DAG storage self, bytes32 from, bytes32 to) internal view returns (bool) {
        if (!self.nodes[from].exists) {
            revert NodeDoesNotExist(from);
        }
        if (!self.nodes[to].exists) {
            revert NodeDoesNotExist(to);
        }
        return self.edges[from][to];
    }
}
