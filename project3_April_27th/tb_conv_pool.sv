//////////////////////////////////////////////////////////////////////
`timescale 1ps/1ps
module tb;
//////////////////////////parmaeters////////////////////////////////////
localparam	CLK_PERIOD=*insert your clk period*;
parameter	RUN_TIME=*insert your runtime here (clk*cycles required fr your o/p)*;
//////////////////////////////tb_interface/////////////////////////////
logic	[127:0]	image [65635:0];
logic	[7:0]	results_mem_0 [65635:0];
logic	[7:0]	results_mem_1 [65635:0];
logic	[7:0]	results_mem_2 [65635:0];
logic	[7:0]	golden_results_0 [65635:0];
logic	[7:0]	golden_results_1 [65635:0];
logic	[7:0]	golden_results_2 [65635:0];
logic	signed [71:0]	filter_0;
logic	signed [71:0]	filter_1;
logic	signed [71:0]	filter_2;
int i,j;

///////////////////////////DUT interface////////////////////////////////////////////////////
logic	[127:0]	dut_image;
logic	[(8*9)-1:0]	dut_kernel_0, dut_kernel_1, dut_kernel_2;
logic	[15:0]	dut_im_address;
logic	[15:0]	dut_res_address_0, dut_res_address_1, dut_res_address_2;
logic	[7:0]	dut_results_0, dut_results_1, dut_results_2;
logic   [1:0]   dut_shift;
logic 	dut_give_im, clk_tb, rst;
logic   dut_take_results_0, dut_take_results_1, dut_take_results_2;
//////////////////////////////////Instance of DUT///////////////////////////////////////
conv_pool dut(	.clk(clk_tb),
				.rst(rst),
				.image_4x4(dut_image),
				.conv_kernel_0(dut_kernel_0),
				.conv_kernel_1(dut_kernel_1),
				.conv_kernel_2(dut_kernel_2),
				.shift(dut_shift),
				.input_re(dut_give_im),
				.input_addr(dut_im_address),
				.output_we_0(dut_take_results_0),
				.output_addr_0(dut_res_address_0),
				.output_we_1(dut_take_results_1),
				.output_addr_1(dut_res_address_1),
				.output_we_2(dut_take_results_2),
				.output_addr_2(dut_res_address_2),
				.y_0(dut_results_0),
				.y_1(dut_results_1),
				.y_2(dut_results_2)
				);
///////////////////////////clk and rst////////////////////////////////////////////////////
always 
	begin 
		#(CLK_PERIOD/2) clk_tb=~clk_tb; 
	end
task reset_dut();
  #(CLK_PERIOD/2) rst=0;
  @(posedge clk_tb);
     #(CLK_PERIOD/3)  rst=1;	
endtask
/////////////////////////initalize image,filters////////////////////////////////////
task initialize_image();
		integer fp1,p;
		fp1=$fopen("./image.txt","r");
		for(i=0;i<65636;i++)
			  p=$fscanf(fp1,"%h\n",image[i]);
		$fclose(fp1);        	       
endtask
task initialize_filter();
		integer fp1,p;
		fp1=$fopen("./filter_0.txt","r");
			  p=$fscanf(fp1,"%b\n",filter_0);
		$fclose(fp1);        
		fp1=$fopen("./filter_1.txt","r");
			  p=$fscanf(fp1,"%b\n",filter_1);
		$fclose(fp1);        
		fp1=$fopen("./filter_2.txt","r");
			  p=$fscanf(fp1,"%b\n",filter_2);
		$fclose(fp1);        
endtask
task initialize_gloden_results();
		integer fp1,p;
  		fp1=$fopen("./golden_results_0.txt","r");
		for(i=0;i<65636;i++)
			p=$fscanf(fp1,"%h\n",golden_results_0[i]);
		$fclose(fp1);  
  		fp1=$fopen("./golden_results_1.txt","r");
		for(i=0;i<65636;i++)
			p=$fscanf(fp1,"%h\n",golden_results_1[i]);
		$fclose(fp1);  
  		fp1=$fopen("./golden_results_2.txt","r");
		for(i=0;i<65636;i++)
			p=$fscanf(fp1,"%h\n",golden_results_2[i]);
		$fclose(fp1);  
endtask

////////////////////////////////filter and shift/////////////////////////////////////////////////////////////////
assign dut_kernel_0 = {filter_0};
assign dut_kernel_1 = {filter_1};
assign dut_kernel_2 = {filter_2};
assign dut_filter=2'b00;
////////////////////////////memory_read_models///////////////////////////////////////////////////////////
always @(posedge clk_tb)
begin
	if	(dut_give_im==1) dut_image<=image[dut_im_address];
	else dut_image<=0;
end

////////////////////////////memory_write_models///////////////////////////////////////////////////////////
//initial results_mem=0;
always @(posedge clk_tb)
begin
	
	if	(dut_take_results_0==1) results_mem_0[dut_res_address_0]<=dut_results_0;
	if	(dut_take_results_1==1) results_mem_1[dut_res_address_1]<=dut_results_1;
	if	(dut_take_results_2==1) results_mem_2[dut_res_address_2]<=dut_results_2;
end
//////////////////////////////////DUT verifier////////////////////////////////////////////////////////////////////
task verify_dut();
	bit error_check;
	int i;
	error_check=0;
	for(i=0;i<65636;i++)
		begin
			
			if((results_mem_0[i])!==(golden_results_0[i]))
			begin
				error_check=1;
				$display("FAILED...!!! Check results of kernel 0, block %d,result:%d,golden:%d\n",i,results_mem_0[i],golden_results_0[i]);
				$display("result:%h,golden:%h\n",results_mem_0[i],golden_results_0[i]);
				break;
			end
		end
	if(error_check==0)$display("PASS Kernel 0..!!\n");

	error_check=0;
	for(i=0;i<65636;i++)
		begin
			
			if((results_mem_1[i])!==(golden_results_1[i]))
			begin
				error_check=1;
				$display("FAILED...!!! Check results of kernel 1, block %d,result:%d,golden:%d\n",i,results_mem_1[i],golden_results_1[i]);
				$display("result:%h,golden:%h\n",results_mem_1[i],golden_results_1[i]);
				break;
			end
		end
	if(error_check==0)$display("PASS Kernel 1..!!\n");

	error_check=0;
	for(i=0;i<65636;i++)
		begin
			
			if((results_mem_2[i])!==(golden_results_2[i]))
			begin
				error_check=1;
				$display("FAILED...!!! Check results of kernel 2, block %d,result:%d,golden:%d\n",i,results_mem_2[i],golden_results_2[i]);
				$display("result:%h,golden:%h\n",results_mem_2[i],golden_results_2[i]);
				break;
			end
		end
	if(error_check==0)$display("PASS Kernel 2..!!\n");

endtask
//////////////////////////////////////////////////////////////////////////////////////////////////////
initial 
	begin
		
      	clk_tb=0;
		initialize_filter();
		initialize_gloden_results();
		initialize_image();
		reset_dut();
      		#(RUN_TIME);
		verify_dut();
		$finish();
	end	
// To generate vcd required for Primtetime Power Analysis
	

endmodule	
