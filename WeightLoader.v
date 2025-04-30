module matrix_transpose(
    input wire clk,
    input wire reset,
    input wire [399:0] matrix_in, // 5x5 matrix with 16-bit elements (5*5*16 = 400 bits)
    output reg [399:0] matrix_out  // transposed 5x5 matrix
);

    // Internal signals to store the input matrix in a more manageable form
    reg [15:0] matrix [0:4][0:4];  // 5x5 matrix, each element is 16 bits
    reg [15:0] transposed [0:4][0:4];  // Transposed matrix

    integer i, j;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset the output matrix
            matrix_out <= 400'b0;
            
            // Reset internal matrices
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    matrix[i][j] <= 16'b0;
                    transposed[i][j] <= 16'b0;
                end
            end
        end
        else begin
            // Convert the 1D input to 2D matrix representation
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    // Calculate the position in the input array
                    // Each element is 16 bits, and we start from the MSB
                    matrix[i][j] <= matrix_in[399-(i*5+j)*16 -: 16];
                end
            end
            
            // Transpose the matrix
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    transposed[i][j] <= matrix[j][i];
                end
            end
            
            // Convert the transposed 2D matrix back to 1D output
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    // Calculate the position in the output array
                    matrix_out[399-(i*5+j)*16 -: 16] <= transposed[i][j];
                end
            end
        end
    end

endmodule