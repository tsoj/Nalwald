#!/bin/bash

dot -Tpng myTree.dot -o myTree.png
twopi -Tpng myTree.dot -o myTreeRadial.png