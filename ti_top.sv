// `include "node_intersect.sv"

module ti_top(
    input  logic                 clk,
    input  logic                 rst,
    input  logic [RAY_SIZE-1:0]  ray_data,             // from ray buffer
    input  logic                 ray_valid,            // from ray buffer
    input  logic [NODE_SIZE-1:0] node_data,            // from cache
    input  logic                 node_data_valid,      // from cache
    input  logic                 children_intersected, // from intersection unit
    input  logic [] H_size,
    input  logic [N*ADDR-1:0]    H,
    output logic [ROOT_ADDR-1:0] root_node,            // to cache, BVH tree global address
    output logic [ADDR-1:0]      cur_node,             // to cache, bvh node address
    output logic                 intersect_children,   // to intersection unit
    output logic                 intersect_leaf,       // to intersection unit
    output logic                 hit_valid,            // to hit shader
    output logic [ADDR-1:0]      hit_node,             // to hit shader
    output logic [DIST_SIZE-1:0] hit_dist              // to hit shader
);

    // parameters
    localparam N                = 6;    // BVH tree width (max children per node)
    localparam DEPTH_SIZE       = 5;    // BVH tree level size for binary
    localparam ACTUAL_DEPTH     = 2**N; // actual BVH tree levels
    localparam ADDR             = 32;   // pointer addresses
    localparam ROOT_ADDR        = 64;   // embree bvh address
    localparam NODE_SIZE        = 512;  // TODO
    localparam RAY_SIZE         = 512;  // TODO
    localparam DIST_SIZE        = 32;   // TODO
    localparam SHORT_STACK_SIZE = 5;
    localparam NODE_TYPE_POS    = 376; // 48th byte LSB

    // internal signals
    logic [$clog2(N):0]    restart_trail [0:ACTUAL_DEPTH-1]; // use packed for subtask in iverilog, has 32x 3-bit counters
    logic [$clog2(N):0]    k;
    logic [N*ADDR-1:0]     H; // use valid mask too?
    logic [N*ADDR-1:0]     S; // use valid mask too?
    logic [N*ADDR-1:0]     Q; // use valid mask too?
    logic [DEPTH_SIZE-1:0] level;
    logic [ADDR-1:0]       short_stack [0:SHORT_STACK_SIZE-1];
    logic                  exit;
    logic                  is_internal_node;

    // fsm to control multicycle process
    typedef enum logic [1:0] {IDLE, CHECK_NODE, SORT_NODES, POP} state_e;
    state_e state;

    // set internal node flag
    assign is_internal_node = node_data[NODE_TYPE_POS];


    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin
            // node_intersect n(
            //     .ray(),
            //     .node(),
            //     .distance(),
            //     .hit()
            // );
        end
    endgenerate


    task leaf_intersect(
        input  logic [RAY_SIZE-1:0]  ray,
        input  logic [ADDR-1:0]      leaf,
        output logic [DIST_SIZE-1:0] distance,
        output logic                 hit
    );
        //
    endtask


    task pop(
        input  logic [0:ACTUAL_DEPTH-1][$clog2(N):0] trail,
        input  logic [DEPTH_SIZE-1:0]                level,
        output logic                                 true
    );

    endtask


    task automatic sort();
        // inputs
        // outputs
    endtask


    always_ff @(posedge clk) begin
        if (rst) begin
            // fsm init
            state <= IDLE;

            // variable inits
            level <= 0;
            for (int i=0; i<ACTUAL_DEPTH; i=i+1) begin
                restart_trail[i] <= 0;
            end
            for (int i=0; i<SHORT_STACK_SIZE; i=i+1) begin
                short_stack[i] <= 0;
            end

            cur_node <= 0;
            intersect_children <= 0;
            intersect_leaf <= 0;
        end
        else begin
            case(state)
                // assume node and ray are fetched simultaneously
                IDLE: begin
                    if (ray_valid) begin
                        state <= CHECK_NODE;
                    end
                    else begin
                        state <= IDLE;
                    end

                    intersect_children <= 0;
                    intersect_leaf     <= 0;
                    level              <= 0;
                    cur_node           <= 0;
                    for (int i=0; i<ACTUAL_DEPTH; i=i+1) begin
                        restart_trail[i] <= 0;
                    end
                    for (int i=0; i<SHORT_STACK_SIZE; i=i+1) begin
                        short_stack[i] <= 0;
                    end
                end

                CHECK_NODE: begin
                    if (is_internal_node) begin
                        k <= restart_trail[level];
                        intersect_children <= 1;
                        state <= SORT_NODES;
                    end
                    else begin
                        // eventually separately handle/indicate top and bottom leaf nodes
                        intersect_leaf <= 1;
                        state <= POP;
                    end
                end

                SORT_NODES: begin
                    if (children_intersected) begin
                        if (k == N) begin
                            //
                        end
                        else begin
                            //
                        end
                    end
                    else begin
                        state <= POP;
                    end
                end
            endcase
        end
    end

endmodule