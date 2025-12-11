`include "ti_top.sv"

module ti_tb();

    localparam N                = 6;
    localparam DEPTH_SIZE       = 5;
    localparam ACTUAL_DEPTH     = 2**N;
    localparam ADDR             = 8;
    localparam ROOT_ADDR        = 8; 
    localparam NODE_SIZE        = 8;
    localparam RAY_SIZE         = 8;
    localparam DIST_SIZE        = 8; 
    localparam SHORT_STACK_SIZE = 5;
    localparam INTERNAL_POS     = 0;
    localparam TRIANGLE_POS     = 1;

    logic                   clk = 0;
    logic                   rst;

    logic [RAY_SIZE-1:0]    ray_data;
    logic                   ray_valid;
    logic                   busy; // output

    logic [NODE_SIZE-1:0]   node_data;
    logic                   node_data_valid;
    logic [ROOT_ADDR-1:0]   root_node; // output
    logic [ADDR-1:0]        cur_node; // output

    logic                   H_valid;
    logic [$clog2(N)-1:0]   H_size;
    logic [N*ADDR-1:0]      H_nodes;
    logic [DIST_SIZE*6-1:0] H_dists;
    logic                   intersect_children; // output
    logic                   intersect_leaf; // output

    ti_top #(
        .N(N),
        .DEPTH_SIZE(DEPTH_SIZE),
        .ACTUAL_DEPTH(ACTUAL_DEPTH),
        .ADDR(ADDR),
        .ROOT_ADDR(ROOT_ADDR),
        .NODE_SIZE(NODE_SIZE),
        .RAY_SIZE(RAY_SIZE),
        .DIST_SIZE(DIST_SIZE),
        .SHORT_STACK_SIZE(SHORT_STACK_SIZE),
        .INTERNAL_POS(INTERNAL_POS),
        .TRIANGLE_POS(TRIANGLE_POS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .ray_data(ray_data),
        .ray_valid(ray_valid),
        .busy(busy),
        .node_data(node_data),
        .node_data_valid(node_data_valid),
        .root_node(root_node),
        .cur_node(cur_node),
        .H_valid(H_valid),
        .H_size(H_size),
        .H_nodes(H_nodes),
        .H_dists(H_dists),
        .intersect_children(intersect_children),
        .intersect_leaf(intersect_leaf)
    );

    always #1 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, ti_tb);

        #1;
        rst = 1;

        #2;
        rst = 0;

        // ray buffer communication
        #2 begin
            ray_data        <= 8'hFF;
            ray_valid       <= 1;
        end
        #2 begin
            ray_data  <= 8'h00;
            ray_valid <= 0;
        end
        // cache communication
        #2 begin
            node_data       <= 8'hA1; // node A, is internal node
            node_data_valid <= 1;
        end
        #2 begin
            node_data       <= 8'b0000_0000;
            node_data_valid <= 0;
        end
        // intersection unit communication
        #2 begin
            H_valid         <= 1;
            H_size          <= 1;
            H_nodes         <= {8'hE1, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
            H_dists         <= {8'd04, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00};
        end
        #2 begin // process_nodes_1
            H_valid         <= 0;
            H_size          <= 0;
            H_nodes         <= 0;
            H_dists         <= 0;
        end
        #2; // process_nodes_2


        #2; // check_nodes
        // cache communication
        #2 begin
            node_data       <= 8'hE1; // node E, is internal node
            node_data_valid <= 1;
        end
        #2 begin
            node_data       <= 8'b0000_0000;
            node_data_valid <= 0;
        end
        // intersection unit communication
        #2 begin
            H_valid         <= 1;
            H_size          <= 3;
            H_nodes         <= {8'h11, 8'h21, 8'h31, 8'h00, 8'h00, 8'h00};
            H_dists         <= {8'd02, 8'd09, 8'd03, 8'd00, 8'd00, 8'd00};
        end
        #2 begin // process_nodes_1
            H_valid         <= 0;
            H_size          <= 0;
            H_nodes         <= 0;
            H_dists         <= 0;
        end
        #2; // process_nodes_2

        #2; // check_nodes
        // cache communication
        #2 begin
            node_data       <= 8'h21; // node 2, is internal node
            node_data_valid <= 1;
        end
        #2 begin
            node_data       <= 8'b0000_0000;
            node_data_valid <= 0;
        end
        // intersection unit communication
        #2 begin
            H_valid         <= 1;
            H_size          <= 0;
            H_nodes         <= {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
            H_dists         <= {8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00};
        end
        #2 begin // process_nodes_1
            H_valid         <= 0;
            H_size          <= 0;
            H_nodes         <= 0;
            H_dists         <= 0;
        end
        #2; // process_nodes_2

        #2; // check_nodes
        // cache communication
        #2 begin
            node_data       <= 8'h31; // node 3, is internal node
            node_data_valid <= 1;
        end
        #2 begin
            node_data       <= 8'b0000_0000;
            node_data_valid <= 0;
        end
        // intersection unit communication
        #2 begin
            H_valid         <= 1;
            H_size          <= 0;
            H_nodes         <= {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
            H_dists         <= {8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00};
        end
        #2 begin // process_nodes_1
            H_valid         <= 0;
            H_size          <= 0;
            H_nodes         <= 0;
            H_dists         <= 0;
        end
        #2; // process_nodes_2

        #2; // check_nodes
        // cache communication
        #2 begin
            node_data       <= 8'h11; // node 1, is internal node
            node_data_valid <= 1;
        end
        #2 begin
            node_data       <= 8'b0000_0000;
            node_data_valid <= 0;
        end
        // intersection unit communication
        #2 begin
            H_valid         <= 1;
            H_size          <= 0;
            H_nodes         <= {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
            H_dists         <= {8'd00, 8'd00, 8'd00, 8'd00, 8'd00, 8'd00};
        end
        #2 begin // process_nodes_1
            H_valid         <= 0;
            H_size          <= 0;
            H_nodes         <= 0;
            H_dists         <= 0;
        end
        #2; // process_nodes_2

        #10 $finish;
    end

endmodule