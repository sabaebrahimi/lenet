`timescale 1ns / 1ps

module matrix_transpose_tb;

    // Parameters
    parameter CLK_PERIOD = 10; // 10ns clock period (100MHz)
    
    // Signals
    reg clk;
    reg reset;
    reg [399:0] matrix_in;
    wire [399:0] matrix_out;
    
    // Instantiate the Unit Under Test (UUT)
    matrix_transpose uut (
        .clk(clk),
        .reset(reset),
        .matrix_in(matrix_in),
        .matrix_out(matrix_out)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Helper variables for displaying matrix data
    reg [15:0] input_2d [0:4][0:4];
    reg [15:0] output_2d [0:4][0:4];
    integer i, j;
    
    // Test stimulus
    initial begin
        // Initialize inputs
        reset = 1;
        matrix_in = 0;
        
        // Apply reset for 2 clock cycles
        #(CLK_PERIOD*2);
        reset = 0;
        
        // Create a simple test matrix with sequential values (1-25)
        for (i = 0; i < 5; i = i + 1) begin
            for (j = 0; j < 5; j = j + 1) begin
                input_2d[i][j] = (i*5) + j + 1; // Values 1 to 25
            end
        end
        
        // Display input matrix
        $display("Input Matrix:");
        for (i = 0; i < 5; i = i + 1) begin
            $display("%d %d %d %d %d", 
                    input_2d[i][0], input_2d[i][1], input_2d[i][2], 
                    input_2d[i][3], input_2d[i][4]);
        end
        
        // Convert to flattened representation and apply to input
        for (i = 0; i < 5; i = i + 1) begin
            for (j = 0; j < 5; j = j + 1) begin
                matrix_in[399-(i*5+j)*16 -: 16] = input_2d[i][j];
            end
        end
        
        // Wait for a few clock cycles for processing
        #(CLK_PERIOD*3);
        
        // Convert output to 2D representation for display
        for (i = 0; i < 5; i = i + 1) begin
            for (j = 0; j < 5; j = j + 1) begin
                output_2d[i][j] = matrix_out[399-(i*5+j)*16 -: 16];
            end
        end
        
        // Display output matrix
        $display("\nOutput Matrix (Transposed):");
        for (i = 0; i < 5; i = i + 1) begin
            $display("%d %d %d %d %d", 
                    output_2d[i][0], output_2d[i][1], output_2d[i][2], 
                    output_2d[i][3], output_2d[i][4]);
        end
        
        // End simulation
        #(CLK_PERIOD*5);
        $display("\nSimulation completed");
        $finish;
    end

endmodule