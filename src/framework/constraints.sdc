create_clock -name "clock27" -period 37.037 [get_ports {clock27}]
create_clock -name {spiCk}  -period 41.666 -waveform { 20.8 41.666 } [get_ports {spiCk}]

derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

set_clock_groups -asynchronous -group [get_clocks {spiCk}] -group [get_clocks {Clock|altpll_component|auto_generated|pll1|clk[0]}]

#set_false_path -to [get_ports {audio*}]
#set_false_path -to [get_ports {sync*}]
#set_false_path -to [get_ports {rgb*}]
#set_false_path -to [get_ports {ram*}]
#set_false_path -to [get_ports {led*}]
