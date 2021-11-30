onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/DUT/reset_n
add wave -noupdate /tb/DUT/clk
add wave -noupdate /tb/DUT/encryption
add wave -noupdate /tb/DUT/key_valid
add wave -noupdate -radix hexadecimal /tb/DUT/key_word_in
add wave -noupdate /tb/DUT/data_valid
add wave -noupdate -radix hexadecimal /tb/DUT/data_word_in
add wave -noupdate -radix hexadecimal /tb/DUT/data_word_out
add wave -noupdate /tb/DUT/data_ready
add wave -noupdate -color Cyan -radix hexadecimal -radixshowbase 0 /tb/data_bkp
add wave -noupdate -divider {Internal Signals}
add wave -noupdate -color Cyan /tb/DUT/st
add wave -noupdate -color Cyan -radix unsigned /tb/DUT/st_cnt
add wave -noupdate -color Orange -radix unsigned /tb/DUT/key_cnt
add wave -noupdate -color {Medium Orchid} -radix hexadecimal -radixshowbase 0 /tb/DUT/data_word(0)
add wave -noupdate -color {Medium Orchid} -radix hexadecimal -radixshowbase 0 /tb/DUT/data_word(1)
add wave -position end  sim:/tb/DUT/key_data_o
add wave -position end  sim:/tb/DUT/BRAM_KEY/RAM
add wave -position end  sim:/tb/DUT/CM1
add wave -position end  sim:/tb/DUT/N1
add wave -position end  sim:/tb/DUT/N2
add wave -position end  sim:/tb/DUT/R
add wave -position 21  sim:/tb/DUT/BRAM_0/addr
add wave -position end  sim:/tb/DUT/st_round
add wave -position end  sim:/tb/DUT/key_addr
add wave -position end  sim:/tb/DUT/s0_addr
add wave -position end  sim:/tb/DUT/s0_data_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1448170 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {1575 us}
