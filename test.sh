#!/bin/sh
make clean
make && ./find_markers -f example.bmp || cat errors.txt
