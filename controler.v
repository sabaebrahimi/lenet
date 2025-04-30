module convolution_top #(
    parameter MATRIX_SIZE = 32,        // Size of input matrix (32x32)
    parameter WINDOW_SIZE = 5,         // Size of sliding window/kernel (5x5)
    parameter DATA_WIDTH = 8,          // Width of input data elements
    parameter WEIGHT_WIDTH = 16,       // Width of weight elements
    parameter ACC_WIDTH = 32,          // Width of accumulator
    parameter OUTPUT_SIZE = MATRIX_SIZE - WINDOW_SIZE + 1  // Size of output matrix (28x28)
)(
    input wire clk,
    input wire reset,
    input wire start,                  // Signal to start processing
    input wire [8191:0] input_matrix,  // 32x32 input matrix (32*32*8 = 8192 bits)
    input wire [399:0] weights,        // 5x5 weight matrix (5*5*16 = 400 bits)
    output reg [OUTPUT_SIZE*OUTPUT_SIZE*ACC_WIDTH-1:0] result_matrix, // 28x28 output matrix
    output reg processing_done         // Signal indicating processing is complete
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam LOAD_WEIGHTS = 2'b01;
    localparam PROCESS_WINDOWS = 2'b10;
    localparam DONE = 2'b11;
    
    reg [1:0] current_state, next_state;
    
    // Control signals
    reg weight_load_done;
    reg generate_sliding;
    reg mmu_control;
    reg mmu_computing;
    reg [7:0] compute_counter;
    reg [9:0] window_counter;  // Counts processed windows (max 28*28 = 784)
    
    
   
    
    // MMU result ready detection
    reg [3:0] mmu_cycle_counter;
    
    // Transposed weights
    wire [399:0] transposed_weights;
    
    // Window signals
    wire [199:0] window_out;
    wire [4:0] window_row, window_col;
    wire window_valid;
    wire comp_mmu_finish;
    reg mmu_reset;
    
    reg print_debug;
    
    // MMU signals
    wire [31:0] mmu_result;
    reg [39:0] data_arr;  // 5x8 = 40 bits for data input to MMU
    
    // Instantiate Matrix Transpose module for weights
    matrix_transpose weight_transpose (
        .clk(clk),
        .reset(reset),
        .matrix_in(weights),
        .matrix_out(transposed_weights)
    );
    
    // Instantiate Sliding Window Generator
    sliding_window_generator window_gen (
        .clk(clk),
        .reset(reset),
        .matrix_in(input_matrix),
        .generate_sliding(generate_sliding),
        .window_out(window_out),
        .window_row(window_row),
        .window_col(window_col),
        .window_valid(window_valid)
    );
    
    // Instantiate MMU (Systolic Array)
    MMU systolic_array (
        .clk(clk),
//        .control(mmu_control),
        .reset(mmu_reset),
        .data_arr(data_arr),
        .wt_arr(transposed_weights[399:0]),  // Use first row of weights (5*16 = 80 bits)
        .print_debug(print_debug),
        .acc_out(mmu_result),
        .comp_finish(comp_mmu_finish)
    );
    
    // State machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = LOAD_WEIGHTS;
                else
                    next_state = IDLE;
            end
            
            LOAD_WEIGHTS: begin
                if (weight_load_done)
                    next_state = PROCESS_WINDOWS;
                else
                    next_state = LOAD_WEIGHTS;
            end
            
            PROCESS_WINDOWS: begin
                if (window_counter >= OUTPUT_SIZE * OUTPUT_SIZE)
                    next_state = DONE;
                else
                    next_state = PROCESS_WINDOWS;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Control logic and datapath
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset control signals
            weight_load_done <= 0;
            generate_sliding <= 0;
            mmu_control <= 0;
            mmu_computing <= 0;
            compute_counter <= 0;
            window_counter <= 0;
            mmu_cycle_counter <= 0;
            processing_done <= 0;
            data_arr <= 0;
            result_matrix <= 0;
            mmu_reset <= 1;
            print_debug <= 1;
        end
        else begin
            case (current_state)
                IDLE: begin
                    weight_load_done <= 0;
                    generate_sliding <= 0;
                    mmu_control <= 0;
                    mmu_computing <= 0;
                    compute_counter <= 0;
                    window_counter <= 0;
                    mmu_cycle_counter <= 0;
                    processing_done <= 0;
                    mmu_reset <= 0;
                end
                
                LOAD_WEIGHTS: begin
                    // One clock cycle to load weights into the systolic array
                    mmu_control <= 1;
                    weight_load_done <= 1;
                end
                
                PROCESS_WINDOWS: begin
                    // After weights are loaded, turn off weight loading
                    mmu_control <= 0;
                    
                    // Generate first sliding window if not already computing
                    if (!mmu_computing && compute_counter == 0) begin
                        generate_sliding <= 1;
                        mmu_reset <= 1;
                        compute_counter <= compute_counter + 1;
                    end
                    else begin
                        generate_sliding <= 0;
                    end
                    
                    // When a valid window is available, start computation
                    if (window_valid && !mmu_computing) begin
                        mmu_computing <= 1;
                        mmu_cycle_counter <= 0;
                    end
                    
                    // Feed data to MMU for 5 cycles (one row at a time)
                    if (mmu_computing) begin
                        $display("In MMU computing.MMU cycle counter = %d", mmu_cycle_counter);
                        
                        mmu_cycle_counter <= mmu_cycle_counter + 1;
                        
                        // Extract the appropriate row from the window based on the cycle counter
                        if (mmu_cycle_counter < 5) begin
                            data_arr <= window_out[199 - mmu_cycle_counter*40 -: 40];
//                        end else if (mmu_cycle_counter == 5) begin
//                            data_arr <= data_arr << 8;
                        end else begin
                              data_arr <= window_out[199 - 4*40 -: 40];
//                            data_arr <= 0;  // Zero padding after data is fed
                        end
                        
                        // After 11 cycles (5 to input + 6 to compute through systolic array), result is ready
                        if (comp_mmu_finish) begin
                            print_debug <=0;
                            $display("mmu result = %h, window_counter: %d, result index: %d", 
                                result_matrix[(window_counter*ACC_WIDTH) +: ACC_WIDTH], window_counter,
                                (window_counter*ACC_WIDTH));
                            // Store result in the output matrix at the appropriate position
                            result_matrix[(window_counter*ACC_WIDTH) +: ACC_WIDTH] <= mmu_result;
                            $display("Added = %h", mmu_result);
                            
                            // Increment window counter
                            window_counter <= window_counter + 1;
                            
                            // Reset for next computation
                            mmu_computing <= 0;
                            
                            // Generate next sliding window
                            generate_sliding <= 1;
                            
                            mmu_reset <= 1;
                        end else begin
                            mmu_reset <= 0;
                        end
                    end
                end
                
                DONE: begin
                    processing_done <= 1;
                end
            endcase
        end
    end

endmodule