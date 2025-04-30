//==================================================
// Module: avgpool (Average of 4 inputs)
// Description: Calculates the average of four 16-bit inputs.
//              Registers the output, introducing 1 clock cycle latency.
//==================================================
`timescale 1ns / 1ps

module avgpool(
    input  [15:0] in1,      // Input 1
    input  [15:0] in2,      // Input 2
    input  [15:0] in3,      // Input 3
    input  [15:0] in4,      // Input 4
    input         clk,      // Clock
    input         enable,   // Enable signal for calculation
    output reg [15:0] op    // Registered average output ((in1+in2+in3+in4)/4)
);

    // Internal wire for the sum. Width is 16 (inputs) + 2 (for sum of 4) = 18 bits.
    wire [17:0] sum_internal;

    // Combinational calculation of the sum
    assign sum_internal = {2'b0, in1} + {2'b0, in2} + {2'b0, in3} + {2'b0, in4};

    // Register the output on clock edge if enabled
    always @ (posedge clk) begin
        if (enable) begin
            // Divide by 4 by taking upper bits (equivalent to >> 2)
            // Truncates result (floor division)
            op <= sum_internal[17:2];
            // Optional: Display inputs and output *inside* avgpool when calculation happens
            // $display("avgpool @ %t: Enabled. Inputs=[%h,%h,%h,%h], Sum=%h, Output next cycle=%h",
            //          $time, in1, in2, in3, in4, sum_internal, sum_internal[17:2]);
        end else begin
            op <= 16'b0; // Reset output when not enabled
        end
    end

    // Initial block for simulation value initialization
    initial begin
        op = 16'b0;
    end

endmodule

//==================================================
// Module: AVG_POOL (Average Pooling Layer)
// Description: Performs 2x2 average pooling with stride 2 over an input feature map.
//              Handles timing latency from the 'avgpool' submodule.
//==================================================
module AVG_POOL #(
    parameter integer WIDTH   = 28, // Width of input feature map (must be >= 2 and even)
    parameter integer HEIGHT  = 28, // Height of input feature map (must be >= 2 and even)
    parameter integer CHANNEL = 6,  // Number of channels in input feature map
    parameter integer BIT_WIDTH = 16 // Bit width of data
)
(
    input [BIT_WIDTH * WIDTH * HEIGHT * CHANNEL - 1 : 0] indata, // Flattened input data
    input clk,                                                    // Clock
    input enable,                                                 // Enable signal to start pooling
    output reg [BIT_WIDTH-1:0] result_out,                        // Pooled result output (valid with avgpoolingdone)
    output reg [15:0] adrressout,                                 // Output address corresponding to result_out
    output reg avgpoolingdone,                                    // High when result_out and adrressout are valid
    output reg avgpoolFIN                                         // High with the *last* valid result_out/adrressout
);

    // Ensure parameters are valid for 2x2 pooling
    initial begin
        if (WIDTH < 2 || WIDTH % 2 != 0) begin
            $error("AVG_POOL Error: WIDTH must be >= 2 and even.");
            $finish;
        end
        if (HEIGHT < 2 || HEIGHT % 2 != 0) begin
            $error("AVG_POOL Error: HEIGHT must be >= 2 and even.");
            $finish;
        end
        if (CHANNEL < 1) begin
            $error("AVG_POOL Error: CHANNEL must be >= 1.");
            $finish;
        end
    end

    // Calculate output dimensions
    localparam OUT_WIDTH = WIDTH / 2;
    localparam OUT_HEIGHT = HEIGHT / 2;
    localparam OUT_PLANE_SIZE = OUT_HEIGHT * OUT_WIDTH; // Size of one output channel plane

    // Map flattened input data to a 3D array structure (combinational)
    wire [BIT_WIDTH-1:0] dataArray[0 : CHANNEL - 1][0 : HEIGHT-1][0 : WIDTH - 1];
    genvar i, j, k;
    generate
        for(i = 0; i < CHANNEL; i = i + 1) begin: channel_loop
            for(j = 0; j < HEIGHT; j = j + 1) begin: height_loop
                for(k = 0; k < WIDTH; k = k + 1) begin: width_loop
                    // Calculate the index in the flattened 'indata' vector
                    localparam base_index = (i * HEIGHT * WIDTH + j * WIDTH + k) * BIT_WIDTH;
                    assign dataArray[i][j][k] = indata[base_index +: BIT_WIDTH];
                end
            end
        end
    endgenerate

    // Address counters for iterating through the output map
    reg [$clog2(CHANNEL)-1:0] C_adr; // Channel address
    reg [$clog2(OUT_HEIGHT)-1:0] Y_adr; // Output Y address (maps to 2*Y_adr in input)
    reg [$clog2(OUT_WIDTH)-1:0] X_adr; // Output X address (maps to 2*X_adr in input)

    // Wires for connecting to the avgpool instance inputs
    // These are internal to AVG_POOL but need to be monitored from TB
    wire [BIT_WIDTH-1:0] pool_in1;
    wire [BIT_WIDTH-1:0] pool_in2;
    wire [BIT_WIDTH-1:0] pool_in3;
    wire [BIT_WIDTH-1:0] pool_in4;

    // Wire for the result from the avgpool instance (1 cycle latency)
    wire [BIT_WIDTH-1:0] pool_result_wire;

    // Internal registers to pipeline control/output signals by 1 cycle
    reg [15:0] adrressout_reg;      // Registered version of output address
    reg avgpoolingdone_reg;         // Registered version of 'done' flag
    reg avgpoolFIN_reg;             // Registered version of 'final' flag
    reg enable_reg;                 // Registered enable for avgpool instance
    reg processing;                 // Flag indicates pooling is in progress

    // Combinational assignments for the avgpool inputs based on current addresses
    // These inputs are selected combinationally based on C_adr, Y_adr, X_adr
    // The avgpool module will process these inputs and produce a result NEXT cycle.
    assign pool_in1 = (processing || enable_reg) ? dataArray[C_adr][2*Y_adr]  [2*X_adr]   : {BIT_WIDTH{1'b0}};
    assign pool_in2 = (processing || enable_reg) ? dataArray[C_adr][2*Y_adr]  [2*X_adr+1] : {BIT_WIDTH{1'b0}};
    assign pool_in3 = (processing || enable_reg) ? dataArray[C_adr][2*Y_adr+1][2*X_adr]   : {BIT_WIDTH{1'b0}};
    assign pool_in4 = (processing || enable_reg) ? dataArray[C_adr][2*Y_adr+1][2*X_adr+1] : {BIT_WIDTH{1'b0}};

    // Instantiate the avgpool sub-module
    avgpool #(
        // Assuming avgpool is generic enough not to need parameters,
        // or parameters would be passed here if it did.
    ) Pooling_Inst (
        .in1(pool_in1),
        .in2(pool_in2),
        .in3(pool_in3),
        .in4(pool_in4),
        .clk(clk),
        .enable(enable_reg), // Controlled by registered enable
        .op(pool_result_wire) // Output has 1 cycle latency
    );

    // Control logic: Address generation and management of registered signals
    always @(posedge clk) begin
        if (enable && !processing) begin // Start condition: enable is high, not already processing
            processing <= 1'b1;
            enable_reg <= 1'b1;         // Enable the avgpool instance for the first calculation
            C_adr <= 0;
            X_adr <= 0;
            Y_adr <= 0;
            // Reset registered outputs for the first cycle (no valid output yet)
            avgpoolingdone_reg <= 1'b0;
            avgpoolFIN_reg     <= 1'b0;
            adrressout_reg     <= 16'b0; // Or calculate first address if needed immediately
                                         // Current: First valid adrressout appears with first result
        end else if (processing) begin
            enable_reg <= 1'b1; // Keep avgpool enabled while processing

            // Calculate the output address corresponding to the inputs processed LAST cycle.
            // This address will be output NEXT cycle alongside pool_result_wire.
            adrressout_reg <= C_adr * OUT_PLANE_SIZE + Y_adr * OUT_WIDTH + X_adr;
            avgpoolingdone_reg <= 1'b1; // Signal valid output for next cycle

            // Check if this is the last calculation being initiated
            if (C_adr == CHANNEL - 1 && Y_adr == OUT_HEIGHT - 1 && X_adr == OUT_WIDTH - 1) begin
                avgpoolFIN_reg <= 1'b1; // Signal final output for next cycle
                processing <= 1'b0;     // Stop processing after this cycle
                enable_reg <= 1'b0;     // Disable avgpool for the cycle *after* the last result
                // Reset counters for potential next run (optional)
                // C_adr <= 0; // Keep last address until next enable
                // X_adr <= 0;
                // Y_adr <= 0;
            end else begin
                // Not the last calculation, update addresses for the next cycle
                avgpoolFIN_reg <= 1'b0;
                if (X_adr == OUT_WIDTH - 1) begin
                    X_adr <= 0;
                    if (Y_adr == OUT_HEIGHT - 1) begin
                        Y_adr <= 0;
                        C_adr <= C_adr + 1;
                    end else begin
                        Y_adr <= Y_adr + 1;
                    end
                end else begin
                    X_adr <= X_adr + 1;
                end
            end

            // Optional Debug Display inside AVG_POOL: Shows state *before* address update,
            // relating to inputs being sent to avgpool for processing *next* cycle.
            // $display("AVG_POOL @ %t: Processing Addr (C=%d, Y=%d, X=%d). Inputs for next cycle=[%h, %h, %h, %h]. Result next cycle = %h",
            //          $time, C_adr, Y_adr, X_adr, pool_in1, pool_in2, pool_in3, pool_in4, pool_result_wire);

        end else begin // Not enabled and not processing
            enable_reg <= 1'b0;         // Keep avgpool disabled
            // Reset registered flags only if not finishing the last operation
            if (!avgpoolFIN_reg) begin
                avgpoolingdone_reg <= 1'b0;
                adrressout_reg     <= 16'b0; // Reset address output
            end
             // Keep avgpoolFIN_reg high for one cycle after processing stops
             avgpoolFIN_reg <= 1'b0; // De-assert FIN after it's been output
        end
    end

    // Output assignment: Assign registered signals to module outputs
    // These outputs change one cycle *after* the control logic determines their value.
    always @(posedge clk) begin
       // Assign registered values directly to outputs
       result_out     <= pool_result_wire;   // Result from avgpool (already registered)
       adrressout     <= adrressout_reg;     // Delayed address
       avgpoolingdone <= avgpoolingdone_reg; // Delayed done signal
       avgpoolFIN     <= avgpoolFIN_reg;     // Delayed final signal
    end

    // Initial block for simulation value initialization
    initial begin
        C_adr = 0;
        X_adr = 0;
        Y_adr = 0;
        processing = 1'b0;
        enable_reg = 1'b0;
        adrressout_reg = 16'b0;
        avgpoolingdone_reg = 1'b0;
        avgpoolFIN_reg = 1'b0;
        // Initialize outputs
        result_out = {BIT_WIDTH{1'b0}};
        adrressout = 16'b0;
        avgpoolingdone = 1'b0;
        avgpoolFIN = 1'b0;
    end

endmodule
