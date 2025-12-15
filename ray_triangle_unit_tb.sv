`timescale 1ns/1ps

module ray_triangle_unit_tb;

  localparam int FP_W    = 32;
  localparam int FP_FRAC = 16;

  typedef struct packed {
    logic signed [FP_W-1:0] x;
    logic signed [FP_W-1:0] y;
    logic signed [FP_W-1:0] z;
  } vec3_t;

  typedef struct packed {
    vec3_t origin;
    vec3_t dir;
    vec3_t inv_dir;
    logic signed [FP_W-1:0] t_min;
    logic signed [FP_W-1:0] t_max;
  } ray_t;

  typedef struct packed {
    vec3_t v0;
    vec3_t v1;
    vec3_t v2;
  } triangle_t;

  // -------------------------------
  // DUT signals
  // -------------------------------
  logic                   clk;
  logic                   rst;
  logic                   req_valid;
  logic                   req_ready;
  ray_t                   req_ray;
  triangle_t              req_tri;
  logic                   resp_valid;
  logic                   resp_ready;
  logic                   resp_hit;
  logic signed [FP_W-1:0] resp_t_hit;

  ray_triangle_unit #(
    .FP_W   (FP_W),
    .FP_FRAC(FP_FRAC)
  ) dut (
    .clk       (clk),
    .rst       (rst),
    .req_valid (req_valid),
    .req_ready (req_ready),
    .req_ray   (req_ray),
    .req_tri   (req_tri),
    .resp_valid(resp_valid),
    .resp_ready(resp_ready),
    .resp_hit  (resp_hit),
    .resp_t_hit(resp_t_hit)
  );

  initial clk = 0;
  always #5 clk = ~clk;


  initial begin
    $dumpfile("ray_triangle_tb.vcd");
    $dumpvars(0, ray_triangle_unit_tb);
  end

  function automatic logic signed [FP_W-1:0] to_fp(real r);
    begin
      to_fp = $rtoi(r * (1 << FP_FRAC));
    end
  endfunction

  function automatic real to_real(logic signed [FP_W-1:0] x);
    begin
      to_real = $itor(x) / (1.0 * (1 << FP_FRAC));
    end
  endfunction

  initial begin
    rst        = 1;
    req_valid  = 0;
    resp_ready = 0;
    req_ray    = '0;
    req_tri    = '0;

    $display("[%0t] TRI TB start", $time);

    repeat (3) @(posedge clk);
    rst = 0;
    $display("[%0t] Deassert reset", $time);
    @(posedge clk);

    // =========================================================
    // TEST 1: simple HIT
    // Triangle in z=0 plane:
    //   v0 = (0,0,0), v1 = (1,0,0), v2 = (0,1,0)
    // Ray:
    //   origin = (0.25, 0.25, -1), dir = (0,0,1)
    // Expect: hit = 1, t ≈ 1
    // =========================================================
    $display("[%0t] TEST 1: HIT case", $time);

    req_tri.v0.x = to_fp(0.0);  req_tri.v0.y = to_fp(0.0);  req_tri.v0.z = to_fp(0.0);
    req_tri.v1.x = to_fp(1.0);  req_tri.v1.y = to_fp(0.0);  req_tri.v1.z = to_fp(0.0);
    req_tri.v2.x = to_fp(0.0);  req_tri.v2.y = to_fp(1.0);  req_tri.v2.z = to_fp(0.0);

    req_ray.origin.x = to_fp(0.25);
    req_ray.origin.y = to_fp(0.25);
    req_ray.origin.z = to_fp(-1.0);

    req_ray.dir.x    = to_fp(0.0);
    req_ray.dir.y    = to_fp(0.0);
    req_ray.dir.z    = to_fp(1.0);

    req_ray.inv_dir.x = '0;
    req_ray.inv_dir.y = '0;
    req_ray.inv_dir.z = to_fp(1.0);

    req_ray.t_min = to_fp(0.0);
    req_ray.t_max = to_fp(100.0);

    @(posedge clk);
    resp_ready = 1;
    req_valid  = 1;
    $display("[%0t] Asserting req_valid for TEST 1", $time);

    @(posedge clk);
    $display("[%0t] After 1 cycle T1: req_ready=%0d", $time, req_ready);
    req_valid = 0;

    wait (resp_valid == 1);
    $display("[%0t] TEST 1 RESP: hit=%0d, t_hit=%f",
             $time, resp_hit, to_real(resp_t_hit));

    if (resp_hit !== 1'b1) begin
      $display("ERROR: TEST 1 expected hit=1");
      $stop;
    end

    @(posedge clk);
    resp_ready = 0;
    @(posedge clk);

    // =========================================================
    // TEST 2: MISS
    // Same triangle, ray passes outside:
    //   origin = (1.5, 1.5, -1), dir = (0,0,1)
    // Expect: hit = 0
    // =========================================================
    $display("[%0t] TEST 2: MISS case", $time);

    req_tri.v0.x = to_fp(0.0);  req_tri.v0.y = to_fp(0.0);  req_tri.v0.z = to_fp(0.0);
    req_tri.v1.x = to_fp(1.0);  req_tri.v1.y = to_fp(0.0);  req_tri.v1.z = to_fp(0.0);
    req_tri.v2.x = to_fp(0.0);  req_tri.v2.y = to_fp(1.0);  req_tri.v2.z = to_fp(0.0);

    req_ray.origin.x = to_fp(1.5);
    req_ray.origin.y = to_fp(1.5);
    req_ray.origin.z = to_fp(-1.0);

    req_ray.dir.x    = to_fp(0.0);
    req_ray.dir.y    = to_fp(0.0);
    req_ray.dir.z    = to_fp(1.0);

    req_ray.inv_dir.x = '0;
    req_ray.inv_dir.y = '0;
    req_ray.inv_dir.z = to_fp(1.0);

    req_ray.t_min = to_fp(0.0);
    req_ray.t_max = to_fp(100.0);

    @(posedge clk);
    resp_ready = 1;
    req_valid  = 1;
    $display("[%0t] Asserting req_valid for TEST 2", $time);

    @(posedge clk);
    $display("[%0t] After 1 cycle T2: req_ready=%0d", $time, req_ready);
    req_valid = 0;

    wait (resp_valid == 1);
    $display("[%0t] TEST 2 RESP: hit=%0d, t_hit=%f",
             $time, resp_hit, to_real(resp_t_hit));

    if (resp_hit !== 1'b0) begin
      $display("ERROR: TEST 2 expected hit=0");
      $stop;
    end

    $display("[%0t] ALL TRIANGLE TESTS PASSED", $time);
    #20;
    $finish;
  end

endmodule
