module sliding_window_generator(
    input wire clk,
    input wire reset,
    input wire [8191:0] matrix_in,    // 32x32 matrix with 8-bit elements (32*32*8 = 8192 bits)
    input wire generate_sliding,      // Signal to generate the next sliding window
    output reg [199:0] window_out,    // 5x5 sliding window with 8-bit elements (5*5*8 = 200 bits)
    output reg [4:0] window_row,      // Current window's top-left row position (0-27)
    output reg [4:0] window_col,      // Current window's top-left column position (0-27)
    output reg window_valid           // Indicates if the current window is valid
);

    // Parameters
    parameter MATRIX_SIZE = 32;       // Size of input matrix (32x32)
    parameter WINDOW_SIZE = 5;        // Size of sliding window (5x5)
    parameter MAX_WINDOW_POS = MATRIX_SIZE - WINDOW_SIZE; // Maximum window position (27)
    
    // Internal storage for the matrix
    reg [7:0] matrix [0:MATRIX_SIZE-1][0:MATRIX_SIZE-1];
    
    // Window position tracking
    reg [4:0] next_row, next_col;
    
    // Temporary window storage for output generation
    reg [7:0] current_window [0:WINDOW_SIZE-1][0:WINDOW_SIZE-1];
    
    integer i, j;
    
    // Load the matrix from the input port
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset the matrix
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                    matrix[i][j] <= 8'b0;
                end
            end
        end
        else begin
            // Load matrix data from the flattened input
            for (i = 0; i < MATRIX_SIZE; i = i + 1) begin
                for (j = 0; j < MATRIX_SIZE; j = j + 1) begin
                    // Calculate position in the input vector (MSB to LSB)
                    // Each element is 8 bits, position = (row*MATRIX_SIZE + col) * 8 bits from the MSB
                    matrix[i][j] <= matrix_in[8191 - (i*MATRIX_SIZE + j)*8 -: 8];
                end
            end
        end
    end
    
    // Update window position and generate window
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset window position and output
            window_row <= 0;
            window_col <= 0;
            next_row <= 0;
            next_col <= 0;
            window_valid <= 0;
            window_out <= 0;
            
            for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
                for (j = 0; j < WINDOW_SIZE; j = j + 1) begin
                    current_window[i][j] <= 8'b0;
                end
            end
        end
        else if (generate_sliding) begin
            // Update current position to next_position
            window_row <= next_row;
            window_col <= next_col;
            
            // Extract the window from the matrix
            for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
                for (j = 0; j < WINDOW_SIZE; j = j + 1) begin
                    current_window[i][j] <= matrix[next_row + i][next_col + j];
                end
            end
            
            // Calculate next position
            if (next_col < MAX_WINDOW_POS) begin
                // Move to the next column
                next_col <= next_col + 1;
                next_row <= next_row;
            end 
            else if (next_row < MAX_WINDOW_POS) begin
                // Move to the next row, reset column
                next_col <= 0;
                next_row <= next_row + 1;
            end
            else begin
                // We've reached the end, reset to the beginning
                next_col <= 0;
                next_row <= 0;
            end
            
            // Window is valid when generate_sliding is asserted
            window_valid <= 1;
        end
        else begin
            // When not generating, maintain the current state
            window_valid <= 0;
        end
    end
    
    // Flatten the window to output port
    always @(*) begin
        // Convert the 2D window to 1D output

        for (i = 0; i < WINDOW_SIZE; i = i + 1) begin
            for (j = 0; j < WINDOW_SIZE; j = j + 1) begin
                window_out[199 - (i*WINDOW_SIZE + j)*8 -: 8] = current_window[i][j];
            end
        end
    end

endmodule

