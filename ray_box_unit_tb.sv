`timescale 1ns/1ps

module ray_box_unit_tb;

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
    vec3_t bmin;
    vec3_t bmax;
  } aabb_t;

  // ------------------------------------------------------------
  // DUT signals
  // ------------------------------------------------------------
  logic                   clk;
  logic                   rst;
  logic                   req_valid;
  logic                   req_ready;
  ray_t                   req_ray;
  aabb_t                  req_box;
  logic                   resp_valid;
  logic                   resp_ready;
  logic                   resp_hit;
  logic signed [FP_W-1:0] resp_t_enter;
  logic signed [FP_W-1:0] resp_t_exit;

  ray_box_unit #(
    .FP_W   (FP_W),
    .FP_FRAC(FP_FRAC)
  ) dut (
    .clk         (clk),
    .rst         (rst),
    .req_valid   (req_valid),
    .req_ready   (req_ready),
    .req_ray     (req_ray),
    .req_box     (req_box),
    .resp_valid  (resp_valid),
    .resp_ready  (resp_ready),
    .resp_hit    (resp_hit),
    .resp_t_enter(resp_t_enter),
    .resp_t_exit (resp_t_exit)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  function automatic logic signed [FP_W-1:0] to_fp(real r);
    begin
      to_fp = $rtoi(r * (1 << FP_FRAC));
    end
  endfunction

  function automatic real to_real(logic signed [FP_W-1:0] x);
    begin
      to_real = x / real'(1 << FP_FRAC);
    end
  endfunction

  initial begin
    rst        = 1'b1;
    req_valid  = 1'b0;
    resp_ready = 1'b1;   // always ready

    $dumpfile("ray_box.vcd");
    $dumpvars(0, ray_box_unit_tb);

    $display("[0] BOX TB start");
    repeat (3) @(posedge clk);
    rst = 1'b0;
    $display("[%0t] Deassert reset", $time);
  end

  task automatic send_and_check(
    input  string name,
    input  bit    expect_hit
  );
    int i;
    begin
      @(posedge clk);
      req_valid <= 1'b1;
      $display("[%0t] %s: assert req_valid", $time, name);

      @(posedge clk);
      req_valid <= 1'b0;

      for (i = 0; i < 20 && !resp_valid; i++) begin
        @(posedge clk);
      end

      if (!resp_valid) begin
        $display("[%0t] %s: ERROR timeout waiting for resp_valid", $time, name);
        $stop;
      end

      $display("[%0t] %s RESP: hit=%0d, t_enter=%f, t_exit=%f",
               $time, name, resp_hit,
               to_real(resp_t_enter), to_real(resp_t_exit));

      if (resp_hit !== expect_hit) begin
        $display("%s: ERROR expected hit=%0d", name, expect_hit);
        $stop;
      end

      @(posedge clk);
    end
  endtask


  initial begin
    @(negedge rst);
    @(posedge clk);

    // ===========================
    // TEST 1: HIT case
    // ===========================
    $display("[%0t] TEST 1: HIT case", $time);

    // Ray: origin (0,0,-5), dir (0,0,1), t in [0,100]
    req_ray.origin.x = to_fp(0.0);
    req_ray.origin.y = to_fp(0.0);
    req_ray.origin.z = to_fp(-5.0);

    req_ray.dir.x    = to_fp(0.0);
    req_ray.dir.y    = to_fp(0.0);
    req_ray.dir.z    = to_fp(1.0);

    req_ray.inv_dir.x = '0;
    req_ray.inv_dir.y = '0;
    req_ray.inv_dir.z = to_fp(1.0 / 1.0);

    req_ray.t_min = to_fp(0.0);
    req_ray.t_max = to_fp(100.0);

    // Box: bmin (-1,-1,0), bmax (1,1,2)
    req_box.bmin.x = to_fp(-1.0);
    req_box.bmin.y = to_fp(-1.0);
    req_box.bmin.z = to_fp(0.0);
    req_box.bmax.x = to_fp( 1.0);
    req_box.bmax.y = to_fp( 1.0);
    req_box.bmax.z = to_fp( 2.0);

    send_and_check("TEST 1", 1'b1);

    // ===========================
    // TEST 2: MISS case (backwards ray)
    // ===========================
    $display("[%0t] TEST 2: MISS case", $time);

    req_ray.origin.x = to_fp(0.0);
    req_ray.origin.y = to_fp(0.0);
    req_ray.origin.z = to_fp(-5.0);

    req_ray.dir.x    = to_fp(0.0);
    req_ray.dir.y    = to_fp(0.0);
    req_ray.dir.z    = to_fp(-1.0);

    req_ray.inv_dir.x = '0;
    req_ray.inv_dir.y = '0;
    req_ray.inv_dir.z = to_fp(1.0 / -1.0);

    req_ray.t_min = to_fp(0.0);
    req_ray.t_max = to_fp(100.0);

    // Box unchanged
    send_and_check("TEST 2", 1'b0);

    $display("ray_box_unit_tb: ALL TESTS PASSED");
    $finish;
  end

endmodule
