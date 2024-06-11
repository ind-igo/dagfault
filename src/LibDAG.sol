// SPX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibDAG {
    struct Node {
        uint id;
        string data;
    }

    struct DAG {
        mapping(uint => Node) nodes;
        mapping(uint => mapping(uint => bool)) edges;
        mapping(uint => uint[]) outgoingEdges;
        mapping(uint => uint) inDegree;
        mapping(uint => bool) nodeExists;
        uint nodeCount;
    }

    function addNode(DAG storage self, string memory data) internal {
        self.nodes[self.nodeCount] = Node(self.nodeCount, data);
        self.nodeExists[self.nodeCount] = true;
        self.nodeCount++;
    }

    function addEdge(DAG storage self, uint from, uint to) internal {
        require(self.nodeExists[from], "From node does not exist");
        require(self.nodeExists[to], "To node does not exist");
        require(!self.edges[from][to], "Edge already exists");
        require(!hasCycle(self, from, to), "Adding this edge will create a cycle");

        self.edges[from][to] = true;
        self.outgoingEdges[from].push(to);
        self.inDegree[to]++;
    }

    function removeNode(DAG storage self, uint id) internal {
        require(self.nodeExists[id], "Node does not exist");

        // Remove all outgoing edges from the node
        uint[] memory outgoing = self.outgoingEdges[id];
        for (uint i = 0; i < outgoing.length; i++) {
            uint to = outgoing[i];
            self.inDegree[to]--;
            delete self.edges[id][to];
        }
        delete self.outgoingEdges[id];

        // Remove all incoming edges to the node
        for (uint i = 0; i < self.nodeCount; i++) {
            if (i != id && self.nodeExists[i]) {
                if (self.edges[i][id]) {
                    self.edges[i][id] = false;
                    self.inDegree[id]--;
                }
            }
        }

        // Remove the node itself
        delete self.nodes[id];
        delete self.nodeExists[id];
    }

    function hasCycle(DAG storage self, uint from, uint to) internal view returns (bool) {
        if (from == to) {
            return true;
        }

        return dfsIterative(self, to, from);
    }

    function dfsIterative(DAG storage self, uint start, uint target) internal view returns (bool) {
        uint nodeCount = self.nodeCount;
        bool[] memory visited = new bool[](nodeCount);
        uint[] memory stack = new uint[](nodeCount);
        uint stackSize = 0;

        stack[stackSize++] = start;

        while (stackSize > 0) {
            uint current = stack[--stackSize];

            if (current == target) {
                return true;
            }

            if (!visited[current]) {
                visited[current] = true;

                uint[] memory neighbors = self.outgoingEdges[current];
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
        require(self.nodeExists[id], "Node does not exist");
        return self.nodes[id];
    }

    function getEdges(DAG storage self, uint id) internal view returns (uint[] memory) {
        require(self.nodeExists[id], "Node does not exist");
        return self.outgoingEdges[id];
    }

    function getInDegree(DAG storage self, uint id) internal view returns (uint) {
        require(self.nodeExists[id], "Node does not exist");
        return self.inDegree[id];
    }
}
