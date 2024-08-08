from treelib import Node, Tree

filename = "myTreeNumbers.txt"

myNumbers = None
with open(filename, 'r') as file:
    for line in file:
        line = line[0:-1]
        if line.isdigit():
            number = int(line)
            if number == 0:
                myNumbers = []
            myNumbers.append(number)

tree = Tree()
root = tree.create_node(tag = 0)

index = 0

print("myNumbers:", len(myNumbers))

def addNode(height, parent):
    global index
    assert myNumbers[index] == height

    while myNumbers[index] >= height:
        if myNumbers[index] == height:
            current = tree.create_node(tag=height, parent=parent)
            print("Created node:", index, height)
            index += 1
        if index >= len(myNumbers):
            print("Returning node:", index)
            return
        if myNumbers[index] > height:
            addNode(height + 1, current)
        if index >= len(myNumbers):
            print("Returning node:", index)
            return
    
    assert myNumbers[index] < height

addNode(0, root)

tree.to_graphviz(filename="myTree.dot", shape="point", graph="graph")
