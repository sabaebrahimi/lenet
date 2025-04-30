`timescale 1ns/1ns

module MAC #(
    parameter data_width = 8,
    parameter weight_width = 16,
    parameter acc_width = 32
)(
    input clk,
    input control,
    input reset,
    input [acc_width - 1:0] acc_in,
    input [data_width - 1:0] data_in,
    input [weight_width - 1:0] weight_in,
    output reg [acc_width - 1:0] acc_out,
    output reg [data_width - 1:0] data_out,
    output reg [weight_width - 1:0] weight_out
);
    reg [data_width + weight_width - 1:0] result;
    reg [acc_width - 1:0] acc_reg;
    always @(posedge clk) begin
        if (reset) begin
            acc_out <= 0;
            weight_out <= 0;
            data_out <= 0;
        end
        else begin
            acc_out <= acc_reg;
            weight_out <= weight_in;
            if (!control) begin
                data_out <= data_in;
            end
        end
    end

    always @* begin
        if (control) begin
            result = data_in * weight_in;
            acc_reg = acc_in + result;
        end
    end
endmodule

module MMU #(
    parameter depth = 5,          // 5 for 5x5 matrix
    parameter data_width = 8,     // 8-bit data
    parameter weight_width = 16,  // 16-bit weight
    parameter acc_width = 32,     // 32-bit accumulator
    parameter size = 5            // 5 for 5x5 output
)(
    input clk,
    input reset,
    input [(data_width*depth)-1:0] data_arr,    // 5*8 = 40 bits
    input [(weight_width*depth*depth)-1:0] wt_arr,    // 5*16 = 80 bits
    input print_debug,
    output reg [31:0] acc_out,     // 5*32 = 160 bits
    output reg comp_finish
);
    // Wires for data outputs, weight outputs, and accumulators for 5x5 MAC units
    wire [data_width-1:0] data_out00, data_out01, data_out02, data_out03, data_out04,
                         data_out10, data_out11, data_out12, data_out13, data_out14,
                         data_out20, data_out21, data_out22, data_out23, data_out24,
                         data_out30, data_out31, data_out32, data_out33, data_out34,
                         data_out40, data_out41, data_out42, data_out43, data_out44;
    
    wire [weight_width-1:0] wt_out00, wt_out01, wt_out02, wt_out03, wt_out04,
                           wt_out10, wt_out11, wt_out12, wt_out13, wt_out14,
                           wt_out20, wt_out21, wt_out22, wt_out23, wt_out24,
                           wt_out30, wt_out31, wt_out32, wt_out33, wt_out34,
                           wt_out40, wt_out41, wt_out42, wt_out43, wt_out44;
    
    wire [acc_width-1:0] acc_out00, acc_out01, acc_out02, acc_out03, acc_out04,
                         acc_out10, acc_out11, acc_out12, acc_out13, acc_out14,
                         acc_out20, acc_out21, acc_out22, acc_out23, acc_out24,
                         acc_out30, acc_out31, acc_out32, acc_out33, acc_out34,
                         acc_out40, acc_out41, acc_out42, acc_out43, acc_out44;
    reg [7:0] i = 0;
    reg [31:0] acc_out_reg;
    reg control = 0;
    // MAC unit instantiations for 5x5 matrix
    // First column (m00, m10, m20, m30, m40)
    MAC m00 (
        clk, control, reset, {acc_width{1'b0}}, 
        data_arr[data_width-1:0], 
        wt_arr[weight_width-1:0], 
        acc_out00, data_out00, wt_out00
    );
    
    MAC m10 (
        clk, control, reset, {acc_width{1'b0}}, 
        data_out00, 
        wt_arr[(6*weight_width)-1:(5*weight_width)], 
        acc_out10, data_out10, wt_out10
    );
    
    MAC m20 (
        clk, control, reset, {acc_width{1'b0}}, 
        data_out10, 
        wt_arr[(11*weight_width)-1:(10*weight_width)], 
        acc_out20, data_out20, wt_out20
    );
    
    MAC m30 (
        clk, control, reset, {acc_width{1'b0}}, 
        data_out20, 
        wt_arr[(16*weight_width)-1:(15*weight_width)], 
        acc_out30, data_out30, wt_out30
    );
    
    MAC m40 (
        clk, control, reset, {acc_width{1'b0}}, 
        data_out30, 
        wt_arr[(21*weight_width)-1:(20*weight_width)], 
        acc_out40, data_out40, wt_out40
    );


    // Second column (m01, m11, m21, m31, m41)
    MAC m01 (
        clk, control, reset, acc_out00, 
        data_arr[(2*data_width)-1:data_width], 
        wt_arr[(2*weight_width)-1:weight_width], 
        acc_out01, data_out01, wt_out01
    );
    MAC m11 (
        clk, control, reset, acc_out10, 
        data_out01, 
        wt_arr[(7*weight_width)-1:(6*weight_width)], 
        acc_out11, data_out11, wt_out11
    );
    MAC m21 (
        clk, control, reset, acc_out20, 
        data_out11, 
        wt_arr[(12*weight_width)-1:(11*weight_width)], 
        acc_out21, data_out21, wt_out21
    );
    MAC m31 (
        clk, control, reset, acc_out30, 
        data_out21, 
        wt_arr[(17*weight_width)-1:(16*weight_width)], 
        acc_out31, data_out31, wt_out31
    );
    MAC m41 (
        clk, control, reset, acc_out40, 
        data_out31, 
        wt_arr[(22*weight_width)-1:(21*weight_width)], 
        acc_out41, data_out41, wt_out41
    );


    // Third column (m02, m12, m22, m32, m42)
    MAC m02 (
        clk, control, reset, acc_out01, 
        data_arr[(3*data_width)-1:(2*data_width)], 
        wt_arr[(3*weight_width)-1:(2*weight_width)], 
        acc_out02, data_out02, wt_out02
    );
    MAC m12 (
        clk, control, reset, acc_out11, 
        data_out02, 
        wt_arr[(8*weight_width)-1:(7*weight_width)], 
        acc_out12, data_out12, wt_out12
    );     
    MAC m22 (
        clk, control, reset, acc_out21, 
        data_out12, 
        wt_arr[(13*weight_width)-1:(12*weight_width)], 
        acc_out22, data_out22, wt_out22
    );
    MAC m32 (
        clk, control, reset, acc_out31, 
        data_out22, 
        wt_arr[(18*weight_width)-1:(17*weight_width)], 
        acc_out32, data_out32, wt_out32
    );    
    MAC m42 (
        clk, control, reset, acc_out41, 
        data_out32, 
        wt_arr[(23*weight_width)-1:(22*weight_width)], 
        acc_out42, data_out42, wt_out42
    );


    // Fourth column (m03, m13, m23, m33, m43)
    MAC m03 (
        clk, control, reset, acc_out02, 
        data_arr[(4*data_width)-1:(3*data_width)], 
        wt_arr[(4*weight_width)-1:(3*weight_width)], 
        acc_out03, data_out03, wt_out03
    );
    MAC m13 (
        clk, control, reset, acc_out12, 
        data_out03, 
        wt_arr[(9*weight_width)-1:(8*weight_width)], 
        acc_out13, data_out13, wt_out13
    );
    MAC m23 (
        clk, control, reset, acc_out22, 
        data_out13, 
        wt_arr[(14*weight_width)-1:(13*weight_width)], 
        acc_out23, data_out23, wt_out23
    ); 
    MAC m33 (
        clk, control, reset, acc_out32, 
        data_out23, 
        wt_arr[(19*weight_width)-1:(18*weight_width)], 
        acc_out33, data_out33, wt_out33
    );
    MAC m43 (
        clk, control, reset, acc_out42, 
        data_out33, 
        wt_arr[(24*weight_width)-1:(23*weight_width)], 
        acc_out43, data_out43, wt_out43
    );

    // Fifth column (m04, m14, m24, m34, m44)
    MAC m04 (
        clk, control, reset, acc_out03, 
        data_arr[(5*data_width)-1:(4*data_width)], 
        wt_arr[(5*weight_width)-1:(4*weight_width)], 
        acc_out04, data_out04, wt_out04
    );
    MAC m14 (
        clk, control, reset, acc_out13, 
        data_out04, 
        wt_arr[(10*weight_width)-1:(9*weight_width)], 
        acc_out14, data_out14, wt_out14
    );    
    MAC m24 (
        clk, control, reset, acc_out23, 
        data_out14, 
        wt_arr[(15*weight_width)-1:(14*weight_width)], 
        acc_out24, data_out24, wt_out24
    );
    MAC m34 (
        clk, control, reset, acc_out33, 
        data_out24, 
        wt_arr[(20*weight_width)-1:(19*weight_width)], 
        acc_out34, data_out34, wt_out34
    );
    MAC m44 (
        clk, control, reset, acc_out43, 
        data_out34, 
        wt_arr[(25*weight_width)-1:(24*weight_width)], 
        acc_out44, data_out44, wt_out44
    );

    // Output assignment: Collect outputs from the last column
    always @(posedge clk) begin
        if (reset) begin
            acc_out <= {(acc_width*size){1'b0}};
            i = 0;
            comp_finish <= 0;
            control <= 0;
        end
        else begin
            i = i + 1;
            $display("i: %d, data in: %h, %h", i, data_arr, data_arr[data_width-1:0]);
            if (print_debug) begin
                $display("i: %d, din00: %d, din01: %d, din02: %d, din03: %d, din04: %d", i, data_arr[data_width-1:0],
                data_arr[(2*data_width)-1:(1*data_width)], data_arr[(3*data_width)-1:(2*data_width)], data_arr[(4*data_width)-1:(3*data_width)]
                , data_arr[(5*data_width)-1:(4*data_width)]);
                $display("dout00: %d, dout01: %d, dout02: %d, dout03: %d, dout04: %d, \n dout10: %d, dout11: %d, dout12: %d, dout13: %d, dout14: %d,\n dout20: %d, dout21: %d, dout22: %d, dout23: %d, dout24: %d, \n dout30: %d, dout31: %d, dout32: %d, dout33: %d, dout34: %d, \n dout40: %d, dout41: %d, dout42: %d, dout43: %d, dout44: %d", 
                    data_out00, data_out01, data_out02, data_out03, data_out04,
                         data_out10, data_out11, data_out12, data_out13, data_out14,
                         data_out20, data_out21, data_out22, data_out23, data_out24,
                         data_out30, data_out31, data_out32, data_out33, data_out34,
                         data_out40, data_out41, data_out42, data_out43, data_out44);
                         
                $display();
                         
               $display("acc00: %d, acc01: %d, acc02: %d, acc03: %d, acc04: %d,\n acc10: %d, acc11: %d, acc12: %d, acc13: %d, acc14: %d, \nacc20: %d, acc21: %d, acc22: %d, acc23: %d, acc24: %d, \nacc30: %d, acc31: %d, acc32: %d, acc33: %d, acc34: %d, \nacc40: %d, acc41: %d, acc42: %d, acc43: %d, acc44: %d",
               acc_out00, acc_out01, acc_out02, acc_out03, acc_out04,
                         acc_out10, acc_out11, acc_out12, acc_out13, acc_out14,
                         acc_out20, acc_out21, acc_out22, acc_out23, acc_out24,
                         acc_out30, acc_out31, acc_out32, acc_out33, acc_out34,
                         acc_out40, acc_out41, acc_out42, acc_out43, acc_out44);
                         
               $display("wt00: %d, wt01: %d, wt02: %d, wt03: %d, wt04: %d,\n wt10: %d, wt11: %d, wt12: %d, wt13: %d, wt14: %d, \nwt20: %d, wt21: %d, wt22: %d, wt23: %d, wt24: %d, \nwt30: %d, wt31: %d, wt32: %d, wt33: %d, wt34: %d, \nwt40: %d, wt41: %d, wt42: %d, wt43: %d, wt44: %d",
               wt_out00, wt_out01, wt_out02, wt_out03, wt_out04,
                         wt_out10, wt_out11, wt_out12, wt_out13, wt_out14,
                         wt_out20, wt_out21, wt_out22, wt_out23, wt_out24,
                         wt_out30, wt_out31, wt_out32, wt_out33, wt_out34,
                         wt_out40, wt_out41, wt_out42, wt_out43, wt_out44);   
            end
            if (i < 4) begin
                control <= 0;
            end else begin
                control <= 1;
            end
//            if (i == 7) begin
//                $display("acc00: %d", acc_out00);
//                acc_out_reg <= acc_out04;
//            end
//            else if (i == 8) begin
//                $display("acc11: %d", acc_out11);
//                acc_out_reg <= acc_out_reg + acc_out14;
//            end
//            else if (i == 9) begin
//                $display("acc22: %d", acc_out22);
//                acc_out_reg <= acc_out_reg + acc_out24;
//            end
//            else if (i == 10) begin
//                $display("acc33: %d", acc_out33);
//                acc_out_reg <= acc_out_reg + acc_out34;
//            end
            if (i == 11) begin
                $display("acc44: %d", acc_out44);
                acc_out_reg <= acc_out44 + acc_out34 + acc_out24 + acc_out14 + acc_out04;
		        acc_out <= acc_out44 + acc_out34 + acc_out24 + acc_out14 + acc_out04;
		        comp_finish <= 1;
//		        i = 0;
            end
            
           
        end
    end
endmodule
`timescale 1ns / 1ps

// sample testbench for a 4X4 Systolic Array

module test_TPU;

	// Inputs
	reg clk;
	reg reset;
	reg control;
	reg [39:0] data_arr;  // Changed from 32 to 40 bits (5*8)
	reg [79:0] wt_arr;    // Changed from 32 to 80 bits (5*16)

	// Outputs
	wire [31:0] acc_out; // Changed from 128 to 160 bits (5*32)
	wire comp_finish;

	// Instantiate the Unit Under Test (UUT)
	MMU uut (
		.clk(clk), 
		.reset(reset),
//		.control(control), 
		.data_arr(data_arr), 
		.wt_arr(wt_arr), 
		.acc_out(acc_out),
		.comp_finish(comp_finish)
	);

	initial begin
		// Initialize Inputs
		clk = 0;
		reset = 1;  // Initialize reset
		control = 0;
		data_arr = 0;
		wt_arr = 0;
		
		// ??????? ???? ?????
		$monitor("Time=%0t, reset=%b, acc_out=%h", $time, reset, acc_out);
		
		// Wait 100 ns for global reset to finish
		#1000;
		reset = 0;  // Release reset after delay
       end

		// Add stimulus here
		always
		#250 clk=!clk;
		
		initial begin
		@(posedge clk);
		control=1;
		wt_arr=80'h 00010001000100010001;
		
		
		@(posedge clk);

		control=0;
		
		data_arr=40'h 0000000001;
		
		@(posedge clk);
		data_arr=40'h 0000000101;
		
		@(posedge clk);
		data_arr=40'h 0000010101;
		
		@(posedge clk);
		data_arr=40'h 0001010101;
		
		@(posedge clk);
		data_arr=40'h 0101010101;
		
		@(posedge clk);
		data_arr=40'h 0101010100;
		
		@(posedge clk);
		data_arr=40'h 0101010000;
		
        @(posedge clk);
		data_arr=40'h 0101000000;

        @(posedge clk);
		data_arr=40'h 0100000000;

        @(posedge clk);
		data_arr=40'h 0000000000;

		// ????? ???? ????? ???? ???? ????? ???? ?????? ????? ?????
		repeat(15) @(posedge clk);
		
		// ????? ????????? ?????
		$display("Final acc_out = %h", acc_out);
		$display("Individual outputs:");
		$display("Output0 = %h", acc_out[31:0]);
		
		// ????? ?????????
		#1000 $finish;
		end
						
endmodule