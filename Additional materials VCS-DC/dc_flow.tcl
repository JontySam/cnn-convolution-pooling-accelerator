###################################################################
# This variable needs to be modified before running this script:
set DESIGN_NAME fulladd4

###################################################################
# Setup
puts "Hostnme : [info hostname]"

################################
# Directory housekeeping
foreach dir "outputs reports" {
  if {![file isdirectory $dir]} {
    file mkdir $dir
  }
}

redirect -file /dev/null {set start_time [clock seconds]}

################################
# setup tool cache so it doesn't clutter up working dir
if {![file exists ./synopsys_cache]} {file mkdir ./synopsys_cache}
set_app_var cache_write ./synopsys_cache
set_app_var cache_read ./synopsys_cache
set_app_var cache_file_chmod_octal 666
set_app_var cache_dir_chmod_octal 777

################################
# STEP: Analyze and elaborate the design, read the design constraints
set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0 }]
puts [format "##### Analyzing the Design. Runtime: %.2f mins #####" $elapsed_time]

if {[file exists ./inputs/rtl/${DESIGN_NAME}.v]} {
  analyze {./inputs/rtl/} -autoread -recursive -verbose -rebuild -format verilog -top $DESIGN_NAME
} else {
  puts "==>FATAL: ${DESIGN_NAME}.v rtl source file does not exist in ./inputs/rtl area. Exiting..."
}

elaborate ${DESIGN_NAME} -architecture verilog -library WORK -update
current_design ${DESIGN_NAME}

if {![eval {link}]} {
  puts "==>FATAL: Design Link Failed... Exiting..."
} else {
  link > ./reports/${DESIGN_NAME}.syn.link.rpt
}

###############################
# prevent assign statements
set_app_var verilogout_no_tri true
set_fix_multiple_port_nets -all
set_app_var uniquify_keep_original_design true

###############################
# Read IO, Loading and timing constraints
if {[file exists ./inputs/constraints/${DESIGN_NAME}.constraints.tcl]} {
  puts "==>INFORMATION: Sourcing the design constraints file"
  source -echo -verbose ./inputs/constraints/${DESIGN_NAME}.constraints.tcl
} else {
  puts "==>FATAL: Design Constraints file does not exists... Exiting..."
}

##############################
# Set the Clock network as Dont Touch Network
set_dont_touch_network [get_clocks]

###############################
# Set wire load model and operating condition
#set_wire_load_model -name 8000 -library [get_libs]
#set_operating_conditions -analysis_type bc_wc -max tt1p05v125c
set_operating_conditions -analysis_type bc_wc -max tt0p8v25c

###############################
# path group setup
group_path -name inputs -from [all_inputs]
group_path -name output -to [all_outputs]
group_path -name comb -from [all_inputs] -to [all_outputs]
group_path -name reg2reg -from [all_registers -clock_pins] -to [all_registers -data_pins]

###############################
# STEP: Compile
set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Running Compile. Runtime: %.2f mins #####" $elapsed_time]
compile -exact_map -boundary_optimization

##############################
# STEP: Incremental Compile
set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Running Incremental Compile. Runtime: %.2f mins #####" $elapsed_time]
compile -incremental_mapping

##############################
# STEP: Outputs and Reports
set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Running Outputs and Reports. Runtime: %.2f mins #####" $elapsed_time]

##############################
# change names
define_name_rules standard_names \
	-allowed "A-Za-z0-9_\[\]" \
	-equal_ports_nets \
	-remove_internal_net_bus \
	-target_bus_naming_style "%s\[%d\]" \
	-add_dummy_nets \
	-flatten_multi_dimension_busses

define_name_rules reg_names \
	-type cell \
	-map {{{"\]", "x"}, {"\[", "x"}}}

change_names -hierarchy -verbose -rules reg_names > ./logs/change_names_reg.log
change_names -hierarchy -verbose -rules standard_names > ./logs/change_names_standard.log

##############################
# Outputs
write_file -format verilog -hierarchy -output ./outputs/${DESIGN_NAME}.vg
write_file -format ddc -hierarchy -output ./outputs/${DESIGN_NAME}.ddc
# Setting variables to not write out load/resistance in sdc
set write_sdc_output_lumped_net_capacitance false
set write_sdc_output_net_resistance false
write_sdc -nosplit ./outputs/${DESIGN_NAME}.sdc

##############################
# Reports
report_area					> ./reports/${DESIGN_NAME}.area.rpt
redirect -append -file ./reports/${DESIGN_NAME}.area.rpt {printenv LOGNAME}
report_reference -hierarchy -nosplit		> ./reports/${DESIGN_NAME}.ref.rpt
report_qor					> ./reports/${DESIGN_NAME}.qor.rpt
report_power -hierarchy -verbose -nosplit	> ./reports/${DESIGN_NAME}.power.rpt
redirect -append -file ./reports/${DESIGN_NAME}.power.rpt {printenv LOGNAME}
report_constraint -all_violators -nosplit	> ./reports/${DESIGN_NAME}.constraint.rpt
check_design					> ./reports/${DESIGN_NAME}.check_design.rpt
check_timing					> ./reports/${DESIGN_NAME}.check_timing.rpt

foreach_in_collection group [get_path_groups] {
  set group_name [get_object_name $group]
  if { [sizeof_collection [get_timing_paths -group $group_name]] } {
    redirect -file ./reports/${DESIGN_NAME}.timing.${group_name}.rpt {
      report_timing \
		-nosplit \
		-capacitance \
		-transition_time \
		-significant_digits 2 \
		-input_pins -nets -max_paths 1 \
		-group $group_name
    }
    redirect -append -file ./reports/${DESIGN_NAME}.timing.${group_name}.rpt {printenv LOGNAME}
  }
}

set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Done. Runtime: %.2f mins, Memory Used: %.1f GB #####" $elapsed_time [expr [mem] / 1000000.0]]
