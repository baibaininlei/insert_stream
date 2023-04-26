`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/04/25 16:53:08
// Design Name: 
// Module Name: axi_stream_insert_header
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module axi_stream_insert_header #(
	parameter DATA_WD = 32,
	parameter DATA_BYTE_WD = DATA_WD/8,
	parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)//计算byte_insert_cnt的位宽
) 
(
	input 							clk				,
	input 							rst_n			,
	// AXI Stream input original data	
	input 							valid_in		,
	input [DATA_WD-1 : 0] 			data_in			,
	input [DATA_BYTE_WD-1 : 0] 		keep_in			,
	input 							last_in			,
	output 							ready_in		,

	// The header to be inserted to AXI Stream input
	input 							valid_insert	,
	input [DATA_WD-1 : 0] 			data_insert		,
	input [DATA_BYTE_WD-1 : 0] 		keep_insert		,
	input [BYTE_CNT_WD-1 : 0] 		byte_insert_cnt	,
	output 							ready_insert	,
	// AXI Stream output with header inserted	
	output 							valid_out		,
	output [DATA_WD-1 : 0] 			data_out		,
	output [DATA_BYTE_WD-1 : 0] 	keep_out		,
	output 							last_out		,
	input 							ready_out		
);
//内部信号
	
	reg [DATA_WD-1 : 0] 		data_in_r			;//寄存器暂存data_in有效数据
	
	reg [DATA_WD-1 : 0] 		data_insert_r		;//寄存器暂存data_insert有效数据
	reg [DATA_BYTE_WD-1 : 0]    keep_in_r			;
	reg [DATA_WD-1 : 0] 		data_out_r			;
	reg [DATA_WD-1 : 0] 		data_out_rr			;
	reg							last_in_r			;
	reg 						last_in_rr			;
	wire						last_in_flag		;
	reg 						insert_flag			;
	
	wire 						last_out_flag		;
	reg [DATA_BYTE_WD-1 : 0] 	keep_out_r			;
	reg 						insert_flag_r		;
	reg 						insert_flag_rr		;
	reg [1:0]					last_out_r			;
	reg [DATA_WD-1 : 0] 		header_insert_data	;
	
	wire 						handshake_data_in	;
	wire						handshake_insert	;
	wire 						handshake_data_out	;
	
	assign handshake_data_in = ready_in & valid_in; 
	assign handshake_insert  = ready_insert & valid_insert;
	assign handshake_data_out= ready_out & valid_out;
	
	
	//ready_in
	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			last_in_r  <= 0;
			last_in_rr <= 0;
		end
		else
			last_in_r 	<= last_in;
			last_in_rr 	<= last_in_r;
	end
	
	assign last_in_flag	 = ~last_in_r & last_in_rr;//上升沿 	
	assign ready_in		 = last_in_flag ? 0:1;
	assign ready_insert  = insert_flag ? 0 : 1;
	
	//data_in传输
	always @(posedge clk or negedge rst_n) begin
		if(!rst_n)
			data_in_r <= 0;
		else if(handshake_data_in)
			data_in_r <= data_in;
		else 
			data_in_r <= data_in_r;
	end
	
	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)
			data_in_rr <= 0;
		else 
			data_in_rr <= data_in_r;
	end
	

	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)
			keep_in_r <= 0;
		else if(valid_in && ready_in)
			keep_in_r <= keep_in;
	end

	
	//处理data_insert无效字节
	always@(posedge clk )begin
		if(handshake_insert)begin
			if(keep_insert==4'b1111)begin
				data_insert_r  <= data_insert;
				insert_flag    <= 1;
			end
			else if( keep_insert==4'b0111)begin
				data_insert_r <= {8'b0, data_insert[23:0]};
				insert_flag   <= 1;
			end
			else if(keep_insert==4'b0011)begin
				data_insert_r <= {16'b00, data_insert[15:0]};
				insert_flag   <= 1;
			end
			else if(keep_insert==4'b0001)begin
				data_insert_r <= {24'b000, data_insert[7:0]};
				insert_flag   <= 1;
			end
		end
		else begin
			data_insert_r <= data_insert_r;
			insert_flag <= 0;
		end
				
	end
	

	
	//合并，将两路输入合并成一路输出
	//即data_insert插入到data_in中
	
	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			header_insert_data <= 0;
		end
		else if(insert_flag)begin
			if(keep_insert==4'b1111)
				header_insert_data <=  data_insert_r;
			else if(keep_insert==4'b0111)
				header_insert_data<={data_insert_r[23:0],data_in_r[7:0]};
			else if(keep_insert==4'b0011)
				header_insert_data<={data_insert_r[15:0],data_in_r[15:0]};
			else if(keep_insert==4'b0001)
				header_insert_data<={data_insert_r[7:0],data_in_r[23:0]};
			else 
				header_insert_data<=header_insert_data;
			end
		else begin
			if(keep_insert==4'b1111)
				header_insert_data <=  data_in_rr;
			else if(keep_insert==4'b0111)
				header_insert_data<={data_in_rr[23:0],data_in_r[7:0]};
			else if(keep_insert==4'b0011)
				header_insert_data<={data_in_rr[15:0],data_in_r[15:0]};
			else if(keep_insert==4'b0001)
				header_insert_data<={data_in_rr[7:0],data_in_r[23:0]};
			else 
				header_insert_data<=header_insert_data;
			end
		end
		
	end
	


	assign data_out = handshake_data_out ? header_insert_data : data_in_rr;
	
	//ready_in
	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			last_in_r  <= 0;
			last_in_rr <= 0;
		end
		else
			last_in_r 	<= last_in;
			last_in_rr 	<= last_in_r;
	end
	
	assign last_in_flag	 = ~last_in_r & last_in_rr;//上升沿 	
	assign ready_in		 = last_in_flag ? 0:1;
	assign ready_insert  = insert_flag ? 0 : 1;
	
	//valid_out

	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			insert_flag_r  <= 0;
			insert_flag_rr <= 0;
		end
		else
			insert_flag_r  <= insert_flag;
			insert_flag_rr <= insert_flag_r;
	end
	
	assign valid_out = (insert_flag_r & ~insert_flag_rr) ? 0 : 1;
	
	//keep_out

	always@(posedge clk or negedge rst_n)
	begin
		if(!rst_n)
			keep_out_r<=0;
		else if(valid_out)
			keep_out_r <= 4'b1111;
		else if(last_out_flag)
		begin
			case(keep_insert)
				4'b1111: keep_out_r <= keep_in_r;
				4'b0111: keep_out_r <= keep_in_r<<1;
				4'b0011: keep_out_r <= keep_in_r<<2;
				4'b0001: keep_out_r <= keep_in_r<<3;
				default: keep_out_r <= 0;
			endcase
		end
		else
			keep_out_r<=0;
	end
	assign keep_out = keep_out_r;
	
	//last_out
	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)
			last_out_r <= 0;
		else 
			last_out_r <= {last_out_r[0],last_in_flag};
	end
	assign last_out_flag = ~last_out_r[0]&last_out_r[1];
	assign last_out = last_out_flag;

endmodule

	



