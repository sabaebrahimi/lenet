`timescale 1ns/1ps

module convolution_top_tb;

    // Parameters
    parameter MATRIX_SIZE = 32;
    parameter WINDOW_SIZE = 5;
    parameter DATA_WIDTH = 8;
    parameter WEIGHT_WIDTH = 16;
    parameter ACC_WIDTH = 32;
    parameter OUTPUT_SIZE = MATRIX_SIZE - WINDOW_SIZE + 1;  // 28
    parameter CLK_PERIOD = 10;  // 10ns
    
    // Signals
    reg clk;
    reg reset;
    reg start;
    reg [8191:0] input_matrix;  // 32x32 matrix of 8-bit values
    reg [399:0] weights;        // 5x5 matrix of 16-bit values
    wire [OUTPUT_SIZE*OUTPUT_SIZE*ACC_WIDTH-1:0] result_matrix; // 28x28 matrix of 32-bit values
    wire processing_done;
    integer i, j, k, l;
    // Instantiate the Unit Under Test (UUT)
    convolution_top #(
        .MATRIX_SIZE(MATRIX_SIZE),
        .WINDOW_SIZE(WINDOW_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .input_matrix(input_matrix),
        .weights(weights),
        .result_matrix(result_matrix),
        .processing_done(processing_done)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    
//    task calculate_expected_results;
//        integer row, col, kr, kc;
//        integer sum;
//        integer result_idx;
//    begin
//        $display("Calculating expected convolution results...");
        
//        // Convert 1D arrays to 2D for easier computation
//        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
//            for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
//                img_2d[i][j] = test_img[i*MATRIX_SIZE + j];
//            end
//        end
        
//        for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
//            for (j = 0; j < WINDOW_SIZE; j = j + 1) begin
//                weights_2d[i][j] = test_weights[i*WINDOW_SIZE + j];
//            end
//        end
        
//        // Display kernel for debugging
//        $display("Convolution kernel:");
//        for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
//            for (j = 0; j < WINDOW_SIZE; j = j + 1) begin
//                $write("%d ", weights_2d[i][j]);
//            end
//            $display("");
//        end
        
//        // Calculate expected convolution results
//        result_idx = 0;
//        for (row = 0; row <= MATRIX_SIZE - WINDOW_SIZE; row = row + 1) begin
//            for (col = 0; col <= MATRIX_SIZE - WINDOW_SIZE; col = col + 1) begin
//                sum = 0;
//                for (kr = 0; kr < WINDOW_SIZE; kr = kr + 1) begin
//                    for (kc = 0; kc < WINDOW_SIZE; kc = kc + 1) begin
//                        sum = sum + img_2d[row+kr][col+kc] * weights_2d[kr][kc];
//                    end
//                end
//                expected_results[result_idx] = sum;
//                result_idx = result_idx + 1;
//            end
//        end
        
//        $display("Expected results calculated for %0d output points", result_idx);
        
//    end
//    endtask
    
    
    // Temporary storage for visualizing inputs and outputs
    reg [DATA_WIDTH-1:0] input_2d [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    reg [WEIGHT_WIDTH-1:0] weight_2d [0:WINDOW_SIZE-1][0:WINDOW_SIZE-1];
    reg [ACC_WIDTH-1:0] result_2d [0:OUTPUT_SIZE-1][0:OUTPUT_SIZE-1];
//    integer i, j;
    
    // Test stimulus
    initial begin
        // Initialize signals
        reset = 1;
        start = 0;
        input_matrix = 0;
        weights = 0;
        
        // Apply reset for a few clock cycles
        #(CLK_PERIOD*3);
        reset = 0;
        #(CLK_PERIOD);
        
        // Initialize input matrix with simple pattern
        // Create a pattern where each element is (row + col) % 256
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
            for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                input_2d[i][j] = (i + j) % 256;
                input_matrix[8191 - (i*MATRIX_SIZE + j)*DATA_WIDTH -: DATA_WIDTH] = input_2d[i][j];
            end
        end
        
        // Initialize weights to all 1's for simple verification
//        weight_2d = {{1, 8, 0, 0, 4}, {2, 5, 2, 9, 1}, {6, 4, 4, 0, 2}, {3, 8, 7, 3, 1}, {0, 1, 0, 2, 9}};
//        weight_2d[0][0]=1; weight_2d[0][1]=8; weight_2d[0][2]=0; weight_2d[0][3]=0; weight_2d[0][4]=4;
//        weight_2d[1][0]=2; weight_2d[1][1]=5; weight_2d[1][2]=2; weight_2d[1][3]=9; weight_2d[1][4]=1;
//        weight_2d[2][0]=6; weight_2d[2][1]=4; weight_2d[2][2]=4; weight_2d[2][3]=0; weight_2d[2][4]=2;
//        weight_2d[3][0]=3; weight_2d[3][1]=8; weight_2d[3][2]=7; weight_2d[3][3]=3; weight_2d[3][4]=1;
//        weight_2d[4][0]=0; weight_2d[4][1]=1; weight_2d[4][2]=0; weight_2d[4][3]=2; weight_2d[4][4]=9;
        for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
            for (j = 0; j < WINDOW_SIZE; j = j + 1) begin
                weight_2d[i][j] = 1;
                weights[399 - (i*WINDOW_SIZE + j)*WEIGHT_WIDTH -: WEIGHT_WIDTH] = weight_2d[i][j];
            end
        end
        
        // Display input and weights (just a small section for visibility)
        $display("Input Matrix (first 5x5 section):");
        for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
            $write("Row %0d: ", i);
            for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                $write("%3d ", input_2d[i][j]);
            end
            $write("\n");
        end
        
        $display("\nWeights Matrix:");
        for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
            $write("Row %0d: ", i);
            for (j = 0; j < WINDOW_SIZE; j = j + 1) begin
                $write("%3d ", weight_2d[i][j]);
            end
            $write("\n");
        end
        
        // Start processing
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        
        // Wait for processing to complete
        wait(processing_done);
        #(CLK_PERIOD*2);
        
        // Extract and display results (first 5x5 section)
        for (i = 0; i < OUTPUT_SIZE; i = i + 1) begin
            for (j = 0; j < OUTPUT_SIZE; j = j + 1) begin
                result_2d[i][j] = result_matrix[(i*OUTPUT_SIZE + j)*ACC_WIDTH +: ACC_WIDTH];
            end
        end
        
        $display("\nResult Matrix (first 5x5 section):");
        for (i = 0; i < OUTPUT_SIZE; i = i + 1) begin
            $write("Row %0d: ", i);
            for (j = 0; j < OUTPUT_SIZE; j = j + 1) begin
                $write("%5d ", result_2d[i][j]);
            end
            $write("\n");
        end
        
        // End simulation
        #(CLK_PERIOD*10);
        $display("\nSimulation completed successfully");
        $finish;
    end
    
    // Monitor for status changes
    initial begin
        $monitor("Time=%0t, State: Reset=%b, Start=%b, Done=%b", 
                 $time, reset, start, processing_done);
    end

endmodule