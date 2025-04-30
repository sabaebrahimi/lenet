
`timescale 1ns / 1ps

module sliding_window_generator_tb;

    // Parameters
    parameter CLK_PERIOD = 10;        // 10ns clock period (100MHz)
    parameter MATRIX_SIZE = 32;       // Size of input matrix (32x32)
    parameter WINDOW_SIZE = 5;        // Size of sliding window (5x5)
    
    // Signals
    reg clk;
    reg reset;
    reg [8191:0] matrix_in;
    reg generate_sliding;
    wire [199:0] window_out;
    wire [4:0] window_row;
    wire [4:0] window_col;
    wire window_valid;
    
    // Instantiate the Unit Under Test (UUT)
    sliding_window_generator uut (
        .clk(clk),
        .reset(reset),
        .matrix_in(matrix_in),
        .generate_sliding(generate_sliding),
        .window_out(window_out),
        .window_row(window_row),
        .window_col(window_col),
        .window_valid(window_valid)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Helper variables
    reg [7:0] test_matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    reg [7:0] window_2d [0:WINDOW_SIZE-1][0:WINDOW_SIZE-1];
    integer i, j, window_count;
    
    // Test stimulus
    initial begin
        // Initialize signals
        reset = 1;
        generate_sliding = 0;
        matrix_in = 0;
        window_count = 0;
        
        // Create test matrix with position-based values
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
            for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                // Use a simple pattern: value = row*10 + col
                // This makes it easy to verify the window positions
                test_matrix[i][j] = (i * 10 + j) % 256;
            end
        end
        
        // Display the first few rows and columns of the test matrix
        $display("Test Matrix (showing first 8x8 section):");
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
            $write("Row %0d: ", i);
            for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                $write("%3d ", test_matrix[i][j]);
            end
            $write("\n");
        end
        
        // Convert test matrix to input format
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
            for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                matrix_in[8191 - (i*MATRIX_SIZE + j)*8 -: 8] = test_matrix[i][j];
            end
        end
        
        // Apply reset for 2 clock cycles
        #(CLK_PERIOD*2);
        reset = 0;
        
        // Wait one cycle for matrix to be loaded
        #(CLK_PERIOD);
        
        // Generate several sliding windows
        repeat (20) begin
            generate_sliding = 1;
            #(CLK_PERIOD);
            generate_sliding = 0;
            
            // Check if window is valid
            if (window_valid) begin
                // Convert output window to 2D for display
                for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
                    for (j = 0; j < WINDOW_SIZE; j = j + 1) begin
                        window_2d[i][j] = window_out[199 - (i*WINDOW_SIZE + j)*8 -: 8];
                    end
                end
                
                // Display window information
                $display("\nWindow #%0d at position [%0d, %0d]:", 
                         window_count, window_row, window_col);
                
                for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
                    $write("  ");
                    for (j = 0; j < WINDOW_SIZE; j = j + 1) begin
                        $write("%3d ", window_2d[i][j]);
                    end
                    $write("\n");
                end
                
                window_count = window_count + 1;
            end
            
            // Wait a few cycles between window generations
            #(CLK_PERIOD*3);
        end
        
        // End simulation
        #(CLK_PERIOD*5);
        $display("\nSimulation completed. Generated %0d windows.", window_count);
        $finish;
    end

endmodule
