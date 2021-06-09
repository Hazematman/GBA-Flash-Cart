#!/bin/bash

ghdl -a --std=08 gba_bus.vhdl
ghdl -a --std=08 gba_bus_testbench.vhdl
ghdl -e --std=08 gba_bus_testbench
