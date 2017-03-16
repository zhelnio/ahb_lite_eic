
vlib work

set p0 -vlog01compat
set p1 +define+SIMULATION

set i0 +incdir+../../src/testbench
set i1 +incdir+../../src/

set s0 ../../src/testbench/*.v
set s1 ../../src/*.v

vlog $p0 $p1  $i0 $i1  $s0 $s1

vsim work.test_eicAhb
add wave -radix hex sim:/test_eicAhb/eic/*
run -all
wave zoom full
