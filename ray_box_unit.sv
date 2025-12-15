module ray_box_unit #(
    parameter int FP_W    = 32,
    parameter int FP_FRAC = 16
) (
    clk,
    rst,
    req_valid,
    req_ready,
    req_ray,
    req_box,
    resp_valid,
    resp_ready,
    resp_hit,
    resp_t_enter,
    resp_t_exit
);

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

    // ---------------------------------------------------------
    // PORTS
    // ---------------------------------------------------------
    input  logic                   clk;
    input  logic                   rst;

    input  logic                   req_valid;
    output logic                   req_ready;
    input  ray_t                   req_ray;
    input  aabb_t                  req_box;

    output logic                   resp_valid;
    input  logic                   resp_ready;
    output logic                   resp_hit;
    output logic signed [FP_W-1:0] resp_t_enter;
    output logic signed [FP_W-1:0] resp_t_exit;

    function automatic logic signed [FP_W-1:0]
      fp_mul (input logic signed [FP_W-1:0] a,
              input logic signed [FP_W-1:0] b);
        logic signed [(2*FP_W)-1:0] prod;
        begin
            prod   = a * b;
            fp_mul = prod >>> FP_FRAC;
        end
    endfunction

    assign req_ready = (!resp_valid) || (resp_valid && resp_ready);

    logic signed [FP_W-1:0] t1x, t2x, t1y, t2y, t1z, t2z;
    logic signed [FP_W-1:0] tmin_x, tmax_x;
    logic signed [FP_W-1:0] tmin_y, tmax_y;
    logic signed [FP_W-1:0] tmin_z, tmax_z;
    logic signed [FP_W-1:0] w_t_enter, w_t_exit;
    logic                   w_hit;

    always @(*) begin

        t1x = '0; t2x = '0;
        t1y = '0; t2y = '0;
        t1z = '0; t2z = '0;

        if (req_ray.inv_dir.x == '0) begin
            tmin_x = req_ray.t_min;
            tmax_x = req_ray.t_max;
        end else begin
            t1x = fp_mul(req_box.bmin.x - req_ray.origin.x, req_ray.inv_dir.x);
            t2x = fp_mul(req_box.bmax.x - req_ray.origin.x, req_ray.inv_dir.x);
            tmin_x = (t1x < t2x) ? t1x : t2x;
            tmax_x = (t1x > t2x) ? t1x : t2x;
        end

        if (req_ray.inv_dir.y == '0) begin
            tmin_y = req_ray.t_min;
            tmax_y = req_ray.t_max;
        end else begin
            t1y = fp_mul(req_box.bmin.y - req_ray.origin.y, req_ray.inv_dir.y);
            t2y = fp_mul(req_box.bmax.y - req_ray.origin.y, req_ray.inv_dir.y);
            tmin_y = (t1y < t2y) ? t1y : t2y;
            tmax_y = (t1y > t2y) ? t1y : t2y;
        end

        if (req_ray.inv_dir.z == '0) begin
            tmin_z = req_ray.t_min;
            tmax_z = req_ray.t_max;
        end else begin
            t1z = fp_mul(req_box.bmin.z - req_ray.origin.z, req_ray.inv_dir.z);
            t2z = fp_mul(req_box.bmax.z - req_ray.origin.z, req_ray.inv_dir.z);
            tmin_z = (t1z < t2z) ? t1z : t2z;
            tmax_z = (t1z > t2z) ? t1z : t2z;
        end

        w_t_enter = tmin_x;
        if (tmin_y > w_t_enter) w_t_enter = tmin_y;
        if (tmin_z > w_t_enter) w_t_enter = tmin_z;

        w_t_exit = tmax_x;
        if (tmax_y < w_t_exit) w_t_exit = tmax_y;
        if (tmax_z < w_t_exit) w_t_exit = tmax_z;

        // Final hit test
        if (   (w_t_exit >= w_t_enter)
            && (w_t_exit >= req_ray.t_min)
            && (w_t_enter <= req_ray.t_max)) begin
            w_hit = 1'b1;
        end else begin
            w_hit = 1'b0;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            resp_valid   <= 1'b0;
            resp_hit     <= 1'b0;
            resp_t_enter <= '0;
            resp_t_exit  <= '0;
        end else begin
            if (req_valid && req_ready) begin
                resp_valid   <= 1'b1;
                resp_hit     <= w_hit;
                resp_t_enter <= w_t_enter;
                resp_t_exit  <= w_t_exit;
            end else if (resp_valid && resp_ready) begin
                resp_valid <= 1'b0;
            end
        end
    end

endmodule
