verilator -Wno-PINCONNECTEMPTY -Wno-UNSIGNED --cc ./tboom_rename_unit_tb.sv ../../rtl/rmt/tboom_rename_unit.sv ../../rtl/rmt/tboom_freelist.sv ../../rtl/rmt/tboom_freelist_buffer.sv ../../rtl/rmt/tboom_rename_map_table.sv ../../rtl/rmt/tboom_rename_map_table_buffer.sv ../../rtl/rmt/tboom_delay_buffer.sv --exe ./sim_main_rename_unit.cpp --trace --timing --build
./obj_dir/Vtboom_rename_unit_tb
