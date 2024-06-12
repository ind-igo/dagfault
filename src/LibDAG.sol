// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

// TODO fail gracefully instead of reverting everywhere
library LibDAG {
    struct Node {
        uint[] outgoingEdges;
        uint inDegree;
        bool exists;
    }

    struct DAG {
        mapping(bytes32 => Node) nodes;
        mapping(bytes32 => mapping(bytes32 => bool)) edges;
    }

    error NodeDoesNotExist(bytes32 id);
    error EdgeAlreadyExists(bytes32 from, bytes32 to);
    error AddingEdgeCreatesCycle(bytes32 from, bytes32 to);

    function addNode(DAG storage self, bytes32 id) internal {
        self.nodes[id].exists = true; // Set node existence flag to true
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
        self.nodes[from].outgoingEdges.push(uint256(to));
        self.nodes[to].inDegree++;
    }

    function removeNode(DAG storage self, bytes32 id) internal {
        if (!self.nodes[id].exists) {
            revert NodeDoesNotExist(id);
        }

        // Remove all outgoing edges from the node
        uint[] memory outgoing = self.nodes[id].outgoingEdges;
        for (uint i = 0; i < outgoing.length; i++) {
            bytes32 to = bytes32(outgoing[i]);
            self.nodes[to].inDegree--;
            delete self.edges[id][to];
        }

        // Remove all incoming edges to the node
        for (uint i = 0; i < self.nodes[id].outgoingEdges.length; i++) {
            bytes32 from = bytes32(self.nodes[id].outgoingEdges[i]);
            if (self.edges[from][id]) {
                self.edges[from][id] = false;
                self.nodes[id].inDegree--;
            }
        }

        // Remove the node itself
        delete self.nodes[id];
    }

    function hasCycle(DAG storage self, bytes32 from, bytes32 to) internal view returns (bool) {
        if (from == to) return true;

        mapping(bytes32 => Node) storage nodes = self.nodes;
        mapping(bytes32 => bool) memory visited;
        bytes32[] memory stack = new bytes32[](nodes.length);
        uint stackSize = 0;

        stack[stackSize++] = to;

        while (stackSize > 0) {
            bytes32 current = stack[--stackSize];

            if (current == from) return true;

            if (!visited[current]) {
                visited[current] = true;

                uint[] memory neighbors = nodes[current].outgoingEdges;
                for (uint i; i < neighbors.length; i++) {
                    bytes32 neighbor = bytes32(neighbors[i]);
                    if (!visited[neighbor]) {
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

    function getEdges(DAG storage self, bytes32 id) internal view returns (uint[] memory) {
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
