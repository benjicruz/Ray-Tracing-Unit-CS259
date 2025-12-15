module ray_triangle_unit #(
    parameter int FP_W    = 32,
    parameter int FP_FRAC = 16
) (
    clk,
    rst,
    req_valid,
    req_ready,
    req_ray,
    req_tri,
    resp_valid,
    resp_ready,
    resp_hit,
    resp_t_hit
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
        vec3_t v0;
        vec3_t v1;
        vec3_t v2;
    } triangle_t;

    input  logic                   clk;
    input  logic                   rst;

    input  logic                   req_valid;
    output logic                   req_ready;

    input  ray_t                   req_ray;
    input  triangle_t              req_tri;

    output logic                   resp_valid;
    input  logic                   resp_ready;
    output logic                   resp_hit;
    output logic signed [FP_W-1:0] resp_t_hit;


    localparam logic signed [FP_W-1:0] EPS    = (1 <<< (FP_FRAC - 8));
    localparam logic signed [FP_W-1:0] ONE_FP = (1 <<< FP_FRAC);

    function automatic logic signed [FP_W-1:0]
      fp_mul (input logic signed [FP_W-1:0] a,
              input logic signed [FP_W-1:0] b);
        logic signed [(2*FP_W)-1:0] prod;
        begin
            prod  = a * b;
            fp_mul = prod >>> FP_FRAC;
        end
    endfunction

    function automatic logic signed [FP_W-1:0]
      fp_inv (input logic signed [FP_W-1:0] x);
        logic signed [63:0] num;
        begin
            if (x == '0) begin
                fp_inv = '0;
            end else begin
                num    = 64'sd1 <<< (2*FP_FRAC);
                fp_inv = num / x;
            end
        end
    endfunction

    function automatic vec3_t vec_sub(input vec3_t a, input vec3_t b);
        vec3_t r;
        begin
            r.x = a.x - b.x;
            r.y = a.y - b.y;
            r.z = a.z - b.z;
            return r;
        end
    endfunction

    function automatic vec3_t vec_cross(input vec3_t a, input vec3_t b);
        vec3_t r;
        begin
            r.x = fp_mul(a.y, b.z) - fp_mul(a.z, b.y);
            r.y = fp_mul(a.z, b.x) - fp_mul(a.x, b.z);
            r.z = fp_mul(a.x, b.y) - fp_mul(a.y, b.x);
            return r;
        end
    endfunction

    function automatic logic signed [FP_W-1:0]
      vec_dot(input vec3_t a, input vec3_t b);
        logic signed [FP_W-1:0] axbx, ayby, azbz;
        begin
            axbx = fp_mul(a.x, b.x);
            ayby = fp_mul(a.y, b.y);
            azbz = fp_mul(a.z, b.z);
            vec_dot = axbx + ayby + azbz;
        end
    endfunction

    function automatic logic signed [FP_W-1:0]
      fp_abs (input logic signed [FP_W-1:0] x);
        begin
            if (x[FP_W-1] == 1'b1)
                fp_abs = -x;
            else
                fp_abs = x;
        end
    endfunction

    assign req_ready = (!resp_valid) || (resp_valid && resp_ready);

    vec3_t e1, e2, pvec, tvec, qvec;
    logic signed [FP_W-1:0] det, inv_det;
    logic signed [FP_W-1:0] u, v, t;
    logic                   w_hit;

    always @(*) begin

        e1 = '0; e2 = '0; pvec = '0; tvec = '0; qvec = '0;
        det = '0; inv_det = '0; u = '0; v = '0; t = '0;
        w_hit = 1'b0;

        e1 = vec_sub(req_tri.v1, req_tri.v0);
        e2 = vec_sub(req_tri.v2, req_tri.v0);

        pvec = vec_cross(req_ray.dir, e2);

        det = vec_dot(e1, pvec);

        if (fp_abs(det) > EPS) begin
            inv_det = fp_inv(det);

            tvec = vec_sub(req_ray.origin, req_tri.v0);

            u = fp_mul(vec_dot(tvec, pvec), inv_det);

            if (!(u < '0 || u > ONE_FP)) begin
                qvec = vec_cross(tvec, e1);

                v = fp_mul(vec_dot(req_ray.dir, qvec), inv_det);

                if (!(v < '0 || (u + v) > ONE_FP)) begin
                    t = fp_mul(vec_dot(e2, qvec), inv_det);
                    if (t >= req_ray.t_min && t <= req_ray.t_max)
                        w_hit = 1'b1;
                end
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            resp_valid <= 1'b0;
            resp_hit   <= 1'b0;
            resp_t_hit <= '0;
        end else begin
            if (req_valid && req_ready) begin
                $display("[DBG TRI @%0t] det=%0d abs(det)=%0d EPS=%0d u=%0d v=%0d t=%0d tmin=%0d tmax=%0d w_hit=%0d",
                         $time,
                         det,
                         fp_abs(det),
                         EPS,
                         u,
                         v,
                         t,
                         req_ray.t_min,
                         req_ray.t_max,
                         w_hit);

                resp_valid <= 1'b1;
                resp_hit   <= w_hit;
                resp_t_hit <= t;
            end else if (resp_valid && resp_ready) begin
                resp_valid <= 1'b0;
            end
        end
    end

endmodule
