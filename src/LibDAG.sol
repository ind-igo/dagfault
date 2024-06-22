// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

library LibDAG {
    struct Node {
        bytes32[] outgoingEdges;
        bytes32[] incomingEdges;
        bool exists;
    }

    struct DAG {
        mapping(bytes32 => Node) nodes;
        mapping(bytes32 => mapping(bytes32 => bool)) edges;
        uint256 nodeCount;
    }

    error NodeExists(bytes32 id);
    error NodeDoesNotExist(bytes32 id);
    error EdgeAlreadyExists(bytes32 from, bytes32 to);
    error EdgeDoesNotExist(bytes32 from, bytes32 to);
    error AddingEdgeCreatesCycle(bytes32 from, bytes32 to);

    function addNode(DAG storage self, bytes32 id) internal {
        if(self.nodes[id].exists) revert NodeExists(id);
        self.nodes[id].exists = true;
        self.nodeCount++;
    }

    function addEdge(DAG storage self, bytes32 from, bytes32 to) internal {
        if (!self.nodes[from].exists) revert NodeDoesNotExist(from);
        if (!self.nodes[to].exists) revert NodeDoesNotExist(to);
        if (self.edges[from][to]) revert EdgeAlreadyExists(from, to);
        if (hasCycle(self, from, to)) revert AddingEdgeCreatesCycle(from, to);

        self.edges[from][to] = true;
        self.nodes[from].outgoingEdges.push(to);
        self.nodes[to].incomingEdges.push(from);
    }

    function removeEdge(DAG storage self, bytes32 from, bytes32 to) internal {
        if (!self.nodes[from].exists) revert NodeDoesNotExist(from);
        if (!self.nodes[to].exists) revert NodeDoesNotExist(to);
        if (!self.edges[from][to]) revert EdgeDoesNotExist(from, to);

        self.edges[from][to] = false;
        removeFromArray(self.nodes[from].outgoingEdges, to);
        removeFromArray(self.nodes[to].incomingEdges, from);
    }

    function removeNode(DAG storage self, bytes32 id) internal {
        if (!self.nodes[id].exists) revert NodeDoesNotExist(id);

        // Remove all outgoing edges
        for (uint256 i; i < self.nodes[id].outgoingEdges.length; i++) {
            bytes32 to = self.nodes[id].outgoingEdges[i];
            self.edges[id][to] = false;
            removeFromArray(self.nodes[to].incomingEdges, id);
        }

        // Remove all incoming edges
        for (uint256 i; i < self.nodes[id].incomingEdges.length; i++) {
            bytes32 from = self.nodes[id].incomingEdges[i];
            self.edges[from][id] = false;
            removeFromArray(self.nodes[from].outgoingEdges, id);
        }

        delete self.nodes[id];
        self.nodeCount--;
    }

    function hasCycle(DAG storage self, bytes32 from, bytes32 to) internal view returns (bool) {
        if (from == to) return true;

        bytes32[] memory stack = new bytes32[](self.nodeCount);
        bytes32[] memory visited = new bytes32[](self.nodeCount);
        uint256 stackSize = 0;
        uint256 visitedSize = 0;

        stack[stackSize++] = to;

        while (stackSize > 0) {
            bytes32 current = stack[--stackSize];

            if (current == from) return true;

            bool isVisited;
            for (uint256 i; i < visitedSize; i++) {
                isVisited = visited[i] == current;
                if (isVisited) break;
                // if (visited[i] == current) {
                //     isVisited = true;
                //     break;
                // }
            }

            if (!isVisited) {
                visited[visitedSize++] = current;

                bytes32[] memory neighbors = self.nodes[current].outgoingEdges;
                for (uint256 i; i < neighbors.length; i++) {
                    stack[stackSize++] = neighbors[i];
                }
            }
        }

        return false;
    }

    function getNode(DAG storage self, bytes32 id) internal view returns (Node storage) {
        return self.nodes[id];
    }

    function getOutgoingEdges(DAG storage self, bytes32 id) internal view returns (bytes32[] memory) {
        if (!self.nodes[id].exists) revert NodeDoesNotExist(id);
        return self.nodes[id].outgoingEdges;
    }

    function getIncomingEdges(DAG storage self, bytes32 id) internal view returns (bytes32[] memory) {
        if (!self.nodes[id].exists) revert NodeDoesNotExist(id);
        return self.nodes[id].incomingEdges;
    }

    function getInDegree(DAG storage self, bytes32 id) internal view returns (uint256) {
        if (!self.nodes[id].exists) revert NodeDoesNotExist(id);
        return self.nodes[id].incomingEdges.length;
    }

    function hasEdge(DAG storage self, bytes32 from, bytes32 to) internal view returns (bool) {
        if (!self.nodes[from].exists) revert NodeDoesNotExist(from);
        if (!self.nodes[to].exists) revert NodeDoesNotExist(to);
        return self.edges[from][to];
    }

    function removeFromArray(bytes32[] storage array, bytes32 value) private {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == value) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
    }
}

/*
library LibDAG {
    struct Node {
        bytes32[] outgoingEdges;
        uint256 inDegree;
        bool exists;
        uint256 index; // Index of the node in the array
    }

    struct DAG {
        mapping(bytes32 => Node) nodes;
        mapping(bytes32 => mapping(bytes32 => bool)) edges;
        uint256 nodeCount; // Total number of nodes created
    }

    error NodeDoesNotExist(bytes32 id);
    error EdgeAlreadyExists(bytes32 from, bytes32 to);
    error AddingEdgeCreatesCycle(bytes32 from, bytes32 to);

    function addNode(DAG storage self, bytes32 id) internal {
        self.nodes[id].exists = true;
        self.nodes[id].index = self.nodeCount;
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
        for (uint256 i = 0; i < outgoing.length; i++) {
            bytes32 to = outgoing[i];
            self.nodes[to].inDegree--;
            delete self.edges[id][to];
        }

        // Remove all incoming edges to the node
        for (uint256 i = 0; i < outgoing.length; i++) {
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
        uint256 stackSize = 0;

        stack[stackSize++] = to;

        while (stackSize > 0) {
            bytes32 current = stack[--stackSize];

            if (current == from) {
                return true;
            }

            uint256 currentIndex = self.nodes[current].index;
            if (!visited[currentIndex]) {
                visited[currentIndex] = true;

                bytes32[] memory neighbors = self.nodes[current].outgoingEdges;
                for (uint256 i = 0; i < neighbors.length; i++) {
                    bytes32 neighbor = neighbors[i];
                    uint256 neighborIndex = self.nodes[neighbor].index;
                    if (!visited[neighborIndex]) {
                        stack[stackSize++] = neighbor;
                    }
                }
            }
        }

        return false;
    }

    function getNode(DAG storage self, bytes32 id) internal view returns (Node memory) {
        return self.nodes[id];
    }

    function getEdges(DAG storage self, bytes32 id) internal view returns (bytes32[] memory) {
        if (!self.nodes[id].exists) {
            revert NodeDoesNotExist(id);
        }
        return self.nodes[id].outgoingEdges;
    }

    function getInDegree(DAG storage self, bytes32 id) internal view returns (uint256) {
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
*/
