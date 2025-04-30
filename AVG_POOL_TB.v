//==================================================
// Module: AVG_POOL_tb (Testbench)
// Description: Testbench for the AVG_POOL module.
//              Stores results and displays them as a flat vector.
//==================================================
`timescale 1ns / 1ps

module AVG_POOL_tb;

    // Parameters (must match DUT)
    parameter WIDTH   = 28;
    parameter HEIGHT  = 28;
    parameter CHANNEL = 6;
    parameter BIT_WIDTH = 16;

    // Calculate output dimensions for testbench logic if needed
    localparam OUT_WIDTH = WIDTH / 2;
    localparam OUT_HEIGHT = HEIGHT / 2;
    localparam OUT_PLANE_SIZE = OUT_HEIGHT * OUT_WIDTH; // Size of one output channel plane
    localparam TOTAL_OUTPUTS = OUT_PLANE_SIZE * CHANNEL;
    localparam LAST_ADDR_CH0 = OUT_PLANE_SIZE - 1;

    // Inputs to DUT
    reg [BIT_WIDTH * WIDTH * HEIGHT * CHANNEL - 1 : 0] indata;
    reg clk;
    reg enable;

    // Outputs from DUT
    wire [BIT_WIDTH-1:0] result_out; // Renamed output
    wire [15:0] adrressout;
    wire avgpoolingdone;
    wire avgpoolFIN;

    // Storage for results vector (flattened matrix)
    reg [BIT_WIDTH-1:0] results_vector [0:TOTAL_OUTPUTS-1];

    // Internal signal for counting outputs and loop variables
    integer output_count;
    integer c, i, j; // Loop counters

    // Instantiate the Device Under Test (DUT)
    AVG_POOL #(
        .WIDTH(WIDTH),
        .HEIGHT(HEIGHT),
        .CHANNEL(CHANNEL),
        .BIT_WIDTH(BIT_WIDTH)
    ) dut (
        .indata(indata),
        .clk(clk),
        .enable(enable),
        .result_out(result_out), // Connect to renamed output
        .adrressout(adrressout),
        .avgpoolingdone(avgpoolingdone),
        .avgpoolFIN(avgpoolFIN)
    );

    // Clock generation (e.g., 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    // Task to set pixel data in the flattened indata vector
    task set_pixel;
        input integer ch, y, x;
        input [BIT_WIDTH-1:0] value;
        integer index;
        begin
            // Basic bounds check
            if (ch >= 0 && ch < CHANNEL && y >= 0 && y < HEIGHT && x >= 0 && x < WIDTH) begin
                 index = (ch * HEIGHT * WIDTH + y * WIDTH + x) * BIT_WIDTH;
                 indata[index +: BIT_WIDTH] = value;
            end else begin
                 $display("Error @ %t: set_pixel index out of bounds (ch=%d, y=%d, x=%d)", $time, ch, y, x);
            end
        end
    endtask

    // Test sequence
    initial begin
        // Initialize inputs and results vector
        indata = 0; // Set all data to zero initially
        enable = 0;
        output_count = 0; // Initialize counter
        // Initialize results vector (optional, ensures clean start)
        for (i = 0; i < TOTAL_OUTPUTS; i = i + 1) begin
            results_vector[i] = {BIT_WIDTH{1'bx}}; // Initialize to 'x'
        end


        // Populate indata with a predictable pattern
        $display("Info @ %t: Populating input data...", $time);
        for (c = 0; c < CHANNEL; c = c + 1) begin
            for (i = 0; i < HEIGHT; i = i + 1) begin
                for (j = 0; j < WIDTH; j = j + 1) begin
                    // Simple pattern: value = channel*1000 + row*10 + col
                    set_pixel(c, i, j, (c * 1000 + i * 10 + j) % 65536);
                end
            end
        end

        // Override specific 2x2 windows for easier verification
        // Channel 0, Top-Left (Output Addr 0)
        set_pixel(0, 0, 0, 16'h0010); // 16
        set_pixel(0, 0, 1, 16'h0020); // 32
        set_pixel(0, 1, 0, 16'h0030); // 48
        set_pixel(0, 1, 1, 16'h0040); // 64
        // Expected average @ Addr 0: (16+32+48+64)/4 = 160/4 = 40 = 16'h0028

        // Channel 0, Bottom-Right (Output Addr OUT_WIDTH*OUT_HEIGHT - 1)
        set_pixel(0, HEIGHT-2, WIDTH-2, 16'h0050); // 80
        set_pixel(0, HEIGHT-2, WIDTH-1, 16'h0060); // 96
        set_pixel(0, HEIGHT-1, WIDTH-2, 16'h0070); // 112
        set_pixel(0, HEIGHT-1, WIDTH-1, 16'h0080); // 128
        // Expected average @ Addr LAST_ADDR_CH0: (80+96+112+128)/4 = 416/4 = 104 = 16'h0068

        // Wait for the next clock edge AFTER data is populated
        @(posedge clk);
        // REMOVED DELAY: #20; // Wait for data to settle if needed

        // Start the pooling operation IMMEDIATELY
        $display("Info @ %t: Asserting enable.", $time);
        enable = 1;
        @(posedge clk); // Ensure enable pulse is seen by DUT for one full cycle
        enable = 0;
        $display("Info @ %t: Deasserting enable.", $time);

        // Wait for the operation to complete by checking avgpoolFIN
        // avgpoolFIN is asserted *with* the last valid result
        $display("Info @ %t: Waiting for avgpoolFIN...", $time);
        wait(avgpoolFIN == 1'b1);
        $display("Info @ %t: avgpoolFIN asserted.", $time);

        // Wait one more clock cycle to ensure the final signals are stable and captured by monitor
        @(posedge clk);
        $display("Info @ %t: Final state check. Last Address: %h (%0d), Last Result: %h (%0d)",
                 $time, adrressout, adrressout, result_out, result_out);

        // Optional: Check if the correct number of outputs were received
         @(posedge clk); // Move slightly past the FIN signal
         if (output_count == TOTAL_OUTPUTS) begin
             $display("Success @ %t: Received expected number of outputs (%0d).", $time, output_count);
         end else begin
             $display("Warning @ %t: Received %0d outputs, expected %0d.", $time, output_count, TOTAL_OUTPUTS);
         end

        // Display the results vector
        $display("\n--- Final Results Vector ---");
        for (i = 0; i < TOTAL_OUTPUTS; i = i + 1) begin
             // Display index and value for each element in the vector
             $display("  Vector[%4d]: %h", i, results_vector[i]);
        end
        $display("--------------------------\n");


        // Wait a bit more before finishing
        #50;

        $display("Info @ %t: Simulation finished.", $time);
        $finish;
    end

    // Monitor signals for debugging
    initial begin
        // Monitor relevant DUT signals and internal avgpool inputs
        // CORRECTED: Use result_out and hierarchical paths to internal DUT signals
        $monitor("Time: %t, En: %b, Addr: %h(%0d), Res: %h(%0d), Done: %b, FIN: %b, Pool Inputs=[%h,%h,%h,%h]",
                 $time, enable,             // Input enable signal from TB
                 adrressout, adrressout,   // Output address from DUT
                 result_out, result_out,   // Output result from DUT
                 avgpoolingdone,           // Output done signal from DUT
                 avgpoolFIN,               // Output final signal from DUT
                 dut.pool_in1,             // Input 1 to avgpool instance inside DUT
                 dut.pool_in2,             // Input 2 to avgpool instance inside DUT
                 dut.pool_in3,             // Input 3 to avgpool instance inside DUT
                 dut.pool_in4);            // Input 4 to avgpool instance inside DUT
    end

    // Counter for valid outputs and store results in vector
    always @(posedge clk) begin
        // No local indices needed for vector storage

        if (avgpoolingdone) begin
            output_count <= output_count + 1;

            // Store the result directly into the vector using the flattened address
            if (adrressout < TOTAL_OUTPUTS) begin // Basic bounds check
                 results_vector[adrressout] <= result_out; // Use non-blocking assignment
            end else begin
                 // Should not happen if DUT logic is correct
                 $error("Error @ %t: Address out of bounds for results_vector! Addr=%h (%0d), AVG_POOL Index=%0d",
                        $time, adrressout, adrressout, TOTAL_OUTPUTS-1);
            end

            // Existing verification checks...
            if (adrressout == 0 && result_out != 16'h0028) begin
                 $error("Verification Error @ %t: First result mismatch! Addr=0, Result=%h, Expected=16'h0028", $time, result_out);
            end
             // Check the specific address for the last element of Channel 0
             if (adrressout == LAST_ADDR_CH0 && result_out != 16'h0068) begin
                 $error("Verification Error @ %t: Last result Ch0 mismatch! Addr=%h, Result=%h, Expected=16'h0068", $time, adrressout, result_out);
             end
        end
        // Reset count on new enable pulse if needed (ensure it happens *before* first done)
        // This logic might need adjustment depending on when enable can be re-asserted.
        // If enable is only asserted once, this reset part is less critical.
        // if (enable && !dut.processing && !avgpoolingdone) begin
        //      output_count <= 0;
        // end
    end

    // Initialize counter at start of simulation
    initial begin
        output_count = 0;
    end

endmodule
