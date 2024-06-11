// SPX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibDAG {

    struct Node {
        uint id;
        string data;
        uint[] outgoingEdges;
        uint inDegree;
    }

    struct DAG {
        mapping(uint => Node) nodes;
        mapping(uint => mapping(uint => bool)) edges;
        uint nodeCount;
    }

    error NodeDoesNotExist(uint id);
    error EdgeAlreadyExists(uint from, uint to);
    error AddingEdgeCreatesCycle(uint from, uint to);

    function addNode(DAG storage self, string memory data) internal {
        self.nodes[self.nodeCount] = Node({
            id: self.nodeCount,
            data: data,
            outgoingEdges: new uint ,
            inDegree: 0
        });
        self.nodeCount++;
    }

    function addEdge(DAG storage self, uint from, uint to) internal {
        if (bytes(self.nodes[from].data).length == 0) {
            revert NodeDoesNotExist(from);
        }
        if (bytes(self.nodes[to].data).length == 0) {
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

    function removeNode(DAG storage self, uint id) internal {
        if (bytes(self.nodes[id].data).length == 0) {
            revert NodeDoesNotExist(id);
        }

        // Remove all outgoing edges from the node
        uint[] memory outgoing = self.nodes[id].outgoingEdges;
        for (uint i = 0; i < outgoing.length; i++) {
            uint to = outgoing[i];
            self.nodes[to].inDegree--;
            delete self.edges[id][to];
        }

        // Remove all incoming edges to the node
        for (uint i = 0; i < self.nodeCount; i++) {
            if (i != id && bytes(self.nodes[i].data).length != 0) {
                if (self.edges[i][id]) {
                    self.edges[i][id] = false;
                    self.nodes[id].inDegree--;
                }
            }
        }

        // Remove the node itself
        delete self.nodes[id];
    }

    function hasCycle(DAG storage self, uint from, uint to) internal view returns (bool) {
        if (from == to) {
            return true;
        }

        uint nodeCount = self.nodeCount;
        bool[] memory visited = new bool[](nodeCount);
        uint[] memory stack = new uint[](nodeCount);
        uint stackSize = 0;

        stack[stackSize++] = to;

        while (stackSize > 0) {
            uint current = stack[--stackSize];

            if (current == from) {
                return true;
            }

            if (!visited[current]) {
                visited[current] = true;

                uint[] memory neighbors = self.nodes[current].outgoingEdges;
                for (uint i = 0; i < neighbors.length; i++) {
                    uint neighbor = neighbors[i];
                    if (!visited[neighbor]) {
                        stack[stackSize++] = neighbor;
                    }
                }
            }
        }

        return false;
    }

    function getNode(DAG storage self, uint id) internal view returns (Node memory) {
        if (bytes(self.nodes[id].data).length == 0) {
            revert NodeDoesNotExist(id);
        }
        return self.nodes[id];
    }

    function getEdges(DAG storage self, uint id) internal view returns (uint[] memory) {
        if (bytes(self.nodes[id].data).length == 0) {
            revert NodeDoesNotExist(id);
        }
        return self.nodes[id].outgoingEdges;
    }

    function getInDegree(DAG storage self, uint id) internal view returns (uint) {
        if (bytes(self.nodes[id].data).length == 0) {
            revert NodeDoesNotExist(id);
        }
        return self.nodes[id].inDegree;
    }

    function hasEdge(DAG storage self, uint from, uint to) internal view returns (bool) {
        if (bytes(self.nodes[from].data).length == 0) {
            revert NodeDoesNotExist(from);
        }
        if (bytes(self.nodes[to].data).length == 0) {
            revert NodeDoesNotExist(to);
        }
        return self.edges[from][to];
    }
}
