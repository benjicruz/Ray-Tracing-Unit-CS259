// `include "node_intersect.sv"

module ti_top #(
    parameter N                = 6,    // BVH tree width (max children per node)
    parameter DEPTH_SIZE       = 5,    // BVH tree level size for binary
    parameter ACTUAL_DEPTH     = 2**N, // actual BVH tree levels
    parameter ADDR             = 32,   // pointer addresses
    parameter ROOT_ADDR        = 64,   // embree bvh address
    parameter NODE_SIZE        = 512,  // TODO
    parameter RAY_SIZE         = 512,  // TODO
    parameter DIST_SIZE        = 32,   // TODO
    parameter SHORT_STACK_SIZE = 5,
    parameter INTERNAL_POS     = 376,  // somewhere in 48th byte, currently bit0
    parameter TRIANGLE_POS     = 440   // somewhere in between 56-63rd byte, currently bit0 of 56th byte
)
(
    // global signals
    input  logic                 clk,
    input  logic                 rst,

    // ray buffer: feeds ray when ti unit is not busy
    input  logic [RAY_SIZE-1:0]  ray_data,
    input  logic                 ray_valid,
    output logic                 busy,

    // cache
    input  logic [NODE_SIZE-1:0] node_data,
    input  logic                 node_data_valid,
    output logic [ROOT_ADDR-1:0] root_node,
    output logic [ADDR-1:0]      cur_node,

    // intersection unit
    input  logic                   H_valid,
    input  logic [$clog2(N)-1:0]   H_size,
    input  logic [N*ADDR-1:0]      H_nodes,
    input  logic [DIST_SIZE*6-1:0] H_dists,
    output logic                   intersect_children,
    output logic                   intersect_leaf,

    // hit shader
    output logic                 hit_valid,
    output logic [ADDR-1:0]      hit_node,
    output logic [DIST_SIZE-1:0] hit_dist
);

    // internal signals
    logic [$clog2(N):0]        restart_trail [0:ACTUAL_DEPTH-1]; // use packed for subtask in iverilog, has 32x 3-bit counters
    logic [$clog2(N):0]        k;
    logic [6*ADDR-1:0]         S; // hardcoded for N=6
    logic [N*ADDR-1:0]         Q; // use valid mask too?
    logic [DEPTH_SIZE-1:0]     level;
    logic [ADDR-1:0]           short_stack [0:SHORT_STACK_SIZE-1];
    logic                      exit;
    logic                      is_internal_node;
    logic                      is_triangle_leaf;
    logic [5:0][DIST_SIZE-1:0] sorted_data;
    logic [$clog2(N)-1:0]      S_size;

    // fsm to control multicycle process
    typedef enum logic [2:0] {IDLE, CHECK_NODE, SORT_NODES, PROCESS_NODES, POP} state_e;
    state_e state;

    // set node type flags
    assign is_internal_node = node_data[INTERNAL_POS]; // position may vary based on embree version
    assign is_triangle_leaf = node_data[TRIANGLE_POS]; // position may vary based on embree version


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


    // hardcoded for N=6
    task automatic sort_nodes(
        input  logic [DIST_SIZE*6-1:0] orig_H_dists,
        input  logic [ADDR*6-1:0]      orig_H_nodes,
        output logic [ADDR*6-1:0]      sorted_H_nodes
    );
        logic [DIST_SIZE*6-1:0] sorted_H_dists;
        logic [DIST_SIZE-1:0]   tmp_dist;
        logic [ADDR-1:0]        tmp_H;

        sorted_H_dists = orig_H_dists;
        sorted_H_nodes = orig_H_nodes;

        // Stage 1 (even): (0,1),(2,3),(4,5)
        if (sorted_H_dists[0*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[1*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[0*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[0*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[1*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[1*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[0*ADDR +: ADDR];
            sorted_H_nodes[0*ADDR +: ADDR] = sorted_H_nodes[1*ADDR +: ADDR];
            sorted_H_nodes[1*ADDR +: ADDR] = tmp_H;
        end
        if (sorted_H_dists[2*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[3*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[2*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[2*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[3*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[3*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[2*ADDR +: ADDR];
            sorted_H_nodes[2*ADDR +: ADDR] = sorted_H_nodes[3*ADDR +: ADDR];
            sorted_H_nodes[3*ADDR +: ADDR] = tmp_H;
        end
        if (sorted_H_dists[4*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[5*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[4*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[4*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[5*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[5*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[4*ADDR +: ADDR];
            sorted_H_nodes[4*ADDR +: ADDR] = sorted_H_nodes[5*ADDR +: ADDR];
            sorted_H_nodes[5*ADDR +: ADDR] = tmp_H;
        end

        // Stage 2 (odd): (1,2),(3,4)
        if (sorted_H_dists[1*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[2*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[1*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[1*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[2*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[2*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[1*ADDR +: ADDR];
            sorted_H_nodes[1*ADDR +: ADDR] = sorted_H_nodes[2*ADDR +: ADDR];
            sorted_H_nodes[2*ADDR +: ADDR] = tmp_H;
        end
        if (sorted_H_dists[3*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[4*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[3*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[3*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[4*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[4*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[3*ADDR +: ADDR];
            sorted_H_nodes[3*ADDR +: ADDR] = sorted_H_nodes[4*ADDR +: ADDR];
            sorted_H_nodes[4*ADDR +: ADDR] = tmp_H;
        end

        // Stage 3 (even): (0,1),(2,3),(4,5)
        if (sorted_H_dists[0*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[1*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[0*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[0*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[1*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[1*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[0*ADDR +: ADDR];
            sorted_H_nodes[0*ADDR +: ADDR] = sorted_H_nodes[1*ADDR +: ADDR];
            sorted_H_nodes[1*ADDR +: ADDR] = tmp_H;
        end
        if (sorted_H_dists[2*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[3*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[2*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[2*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[3*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[3*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[2*ADDR +: ADDR];
            sorted_H_nodes[2*ADDR +: ADDR] = sorted_H_nodes[3*ADDR +: ADDR];
            sorted_H_nodes[3*ADDR +: ADDR] = tmp_H;
        end
        if (sorted_H_dists[4*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[5*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[4*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[4*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[5*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[5*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[4*ADDR +: ADDR];
            sorted_H_nodes[4*ADDR +: ADDR] = sorted_H_nodes[5*ADDR +: ADDR];
            sorted_H_nodes[5*ADDR +: ADDR] = tmp_H;
        end

        // Stage 4 (odd): (1,2),(3,4)
        if (sorted_H_dists[1*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[2*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[1*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[1*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[2*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[2*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[1*ADDR +: ADDR];
            sorted_H_nodes[1*ADDR +: ADDR] = sorted_H_nodes[2*ADDR +: ADDR];
            sorted_H_nodes[2*ADDR +: ADDR] = tmp_H;
        end
        if (sorted_H_dists[3*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[4*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[3*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[3*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[4*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[4*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[3*ADDR +: ADDR];
            sorted_H_nodes[3*ADDR +: ADDR] = sorted_H_nodes[4*ADDR +: ADDR];
            sorted_H_nodes[4*ADDR +: ADDR] = tmp_H;
        end

        // Stage 5 (even): (0,1),(2,3),(4,5)
        if (sorted_H_dists[0*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[1*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[0*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[0*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[1*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[1*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[0*ADDR +: ADDR];
            sorted_H_nodes[0*ADDR +: ADDR] = sorted_H_nodes[1*ADDR +: ADDR];
            sorted_H_nodes[1*ADDR +: ADDR] = tmp_H;
        end
        if (sorted_H_dists[2*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[3*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[2*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[2*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[3*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[3*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[2*ADDR +: ADDR];
            sorted_H_nodes[2*ADDR +: ADDR] = sorted_H_nodes[3*ADDR +: ADDR];
            sorted_H_nodes[3*ADDR +: ADDR] = tmp_H;
        end
        if (sorted_H_dists[4*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[5*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[4*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[4*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[5*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[5*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[4*ADDR +: ADDR];
            sorted_H_nodes[4*ADDR +: ADDR] = sorted_H_nodes[5*ADDR +: ADDR];
            sorted_H_nodes[5*ADDR +: ADDR] = tmp_H;
        end

        // Stage 6 (odd): (1,2),(3,4)
        if (sorted_H_dists[1*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[2*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[1*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[1*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[2*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[2*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[1*ADDR +: ADDR];
            sorted_H_nodes[1*ADDR +: ADDR] = sorted_H_nodes[2*ADDR +: ADDR];
            sorted_H_nodes[2*ADDR +: ADDR] = tmp_H;
        end
        if (sorted_H_dists[3*DIST_SIZE +: DIST_SIZE] < sorted_H_dists[4*DIST_SIZE +: DIST_SIZE]) begin
            tmp_dist = sorted_H_dists[3*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[3*DIST_SIZE +: DIST_SIZE] = sorted_H_dists[4*DIST_SIZE +: DIST_SIZE];
            sorted_H_dists[4*DIST_SIZE +: DIST_SIZE] = tmp_dist;

            tmp_H = sorted_H_nodes[3*ADDR +: ADDR];
            sorted_H_nodes[3*ADDR +: ADDR] = sorted_H_nodes[4*ADDR +: ADDR];
            sorted_H_nodes[4*ADDR +: ADDR] = tmp_H;
        end
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

            busy               <= 0;
            cur_node           <= 0;
            intersect_children <= 0;
            intersect_leaf     <= 0;
        end
        else begin
            case(state)
                // assume node and ray are fetched simultaneously
                IDLE: begin
                    if (ray_valid) begin
                        state <= CHECK_NODE;
                        busy  <= 1;
                    end
                    else begin
                        state <= IDLE;
                        busy  <= 0;
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
                        intersect_leaf <= 1;
                        state <= POP;
                    end
                end

                SORT_NODES: begin
                    if (H_valid) begin
                        if (H_size != 0) begin
                            sort_nodes(H_dists, H_nodes, S);
                            S_size <= H_size;
                            state <= PROCESS_NODES;
                        end
                        else begin
                            state <= POP;
                        end
                    end
                    else begin
                        state <= SORT_NODES;
                    end
                end

                PROCESS_NODES: begin
                    if (k == N) begin
                        S <= S << ADDR*(H_size-1); // remove all but last node in S
                        S_size <= 1;
                    end
                    else begin
                        S <= S << ADDR*k; // remove first k nodes in S
                        S_size <= S_size - k;
                    end
                end
            endcase
        end
    end

endmodule