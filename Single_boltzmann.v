`timescale 1ns/1ps

// Sigmoid is analog. See altium files for CMOS implementation of Sigmoid
// Used to transform the influence of incoming weights and the boltzmann machine node bias into a node flip probability

module Sigmoid(input real in, output real out);
    analog begin
        out <+ 1.0 / (1.0 + exp(-in));
    end
endmodule

// random number generator 

module Comparator_RNG(input real gaussian_source, output real out);
    analog begin
        if (gaussian_source > 0)
            out <+ 1.0;
        else
            out <+ 0.0;
    end
endmodule

// Helpers (built from absolute scratch for fun + practice for ECE final)

module HA(
    input  logic a,
    input  logic b,
    output logic s,
    output logic c
);
    assign s = a ^ b;
    assign c = a & b;
endmodule

// a - b
module HS(
    input  logic a,
    input  logic b,
    output logic s,
    output logic c
);
    assign s = a ^ b;
    assign c = ~a & b;
endmodule

module FA(
    input logic a,
    input logic b,
    input logic cin,
    output logic sum,
    output logic cout);
    wire s1, c1, c2;
    HA ha0(a, b, s1, c1);
    HA ha1(s1, cin, sum, c2);
    assign cout = c1 | c2;
endmodule

// a - b
module FS(
    input logic a,
    input logic b,
    input logic cin,
    output logic dif,
    output logic cout);
    wire s1, c1, c2;
    HA ha0(a, b, s1, c1);
    HA ha1(s1, cin, dif, c2);
    assign cout = c1 | c2;
endmodule

// build n bit ripple adder with loops

module RippleAdd #(parameter int number_size = 16)(
    input logic [number_size-1:0] a,
    input logic [number_size-1:0] b,
    input logic cin,
    output logic [number_size-1:0] sum,
    output logic cout);

    logic [number_size:0] carry;
    assign carry[0] = cin;

    genvar i;

    generate
        for (i = 0; i < number_size; i = i + 1) begin : gen_add
            FA inst (
                .a(a[i]),
                .b(b[i]),
                .cin(carry[i]),
                .sum(sum[i]),
                .cout(carry[i+1])
            );
        end
    endgenerate
    assign cout = carry[number_size];
endmodule

module RippleSubtract #(parameter int number_size = 16)(
    input logic [number_size-1:0] a,
    input logic [number_size-1:0] b,
    input logic cin,
    output logic [number_size-1:0] sum,
    output logic cout);

    logic [number_size:0] carry;
    assign carry[0] = cin;

    genvar i;

    generate
        for (i = 0; i < number_size; i = i + 1) begin : gen_sub
            FS inst(
                .a(a[i]),
                .b(b[i]),
                .cin(carry[i]),
                .dif(sum[i]),
                .cout(carry[i+1])
            );
        end
    endgenerate
    assign cout = carry[number_size];

endmodule

// 16 bit adder

module Add16(
    input  logic signed [15:0] v1,
    input  logic signed [15:0] v2,
    output logic signed [15:0] v3,
    output logic cout);

    RippleAdd #(16) ra (
        .a(v1),
        .b(v2),
        .cin(1'b0),
        .sum(v3),
        .cout(cout)
    );
endmodule

// signed multiply

module Multiplier #(parameter int number_size = 16)(
    input  logic signed [number_size-1:0] m1,
    input  logic signed [number_size-1:0] m2,
    output logic signed [number_size-1:0] m3    // our number is <1 in magnitude so the number_size-1 size works
);
    logic signed [(2*number_size)-1:0] full_p;
    assign full_p = m1 * m2;  
    assign m3 = full_p[number_size-1:0];
endmodule

module GT #(parameter int number_size = 16)(
    input  logic signed [number_size-1:0] m1,
    input  logic signed [number_size-1:0] m2,
    output logic out
);
wire temp;
wire signed [number_size-1:0] diff;
RippleSubtract #(number_size) rs (
    .a(m1),
    .b(m2),
    .cin(1'b0),
    .sum(diff),
    .cout(temp)
);


assign out = ~temp;
endmodule

// n bit weight and bias boltzmann

module Boltzmann #(
    parameter int number_size = 16,
    parameter int CLOCK_FREQ = 50_000_000
)(
    input  logic clk,
    input  real noise,
    input  logic on,
    input  logic train,  // future
    input  logic sample, // future
    input  logic [3:0] neighbours,
    input  logic signed [number_size-1:0] weight1,
    input  logic signed [number_size-1:0] weight2,
    input  logic signed [number_size-1:0] weight3,
    input  logic signed [number_size-1:0] weight4,
    input  logic signed [number_size-1:0] bias,
    output logic node
);
    // fixed-point terms (signed)
    wire signed [number_size-1:0] term1, term2, term3, term4;
    wire signed [number_size-1:0] sum12, sum34, probability;
    real probability_real;
    real prob_real;
    wire node_decision;

    Multiplier #(number_size) mult1 (
        .m1(weight1),
        .m2({{(number_size-1){1'b0}}, neighbours[0]}),
        .m3(term1)
    );
    Multiplier #(number_size) mult2 (
        .m1(weight2),
        .m2({{(number_size-1){1'b0}}, neighbours[1]}),
        .m3(term2)
    );
    Multiplier #(number_size) mult3 (
        .m1(weight3),
        .m2({{(number_size-1){1'b0}}, neighbours[2]}),
        .m3(term3)
    );
    Multiplier #(number_size) mult4 (
        .m1(weight4),
        .m2({{(number_size-1){1'b0}}, neighbours[3]}),
        .m3(term4)
    );

    wire add_cout_unused1, add_cout_unused2;
    Add16 addA (
        .v1(term1),
        .v2(term2),
        .v3(sum12),
        .cout(add_cout_unused1)
    );
    Add16 addB (
        .v1(term3),
        .v2(term4),
        .v3(sum34),
        .cout(add_cout_unused2)
    );

    assign probability = sum12 + sum34 + bias;

    assign probability_real = $itor(probability);

    Sigmoid(probability_real, prob_real);

    assign node_decision = (prob_real > noise);

    always_ff @(posedge clk or negedge on) begin
        if (!on)
            node <= 1'b0;
        else
            node <= node_decision;
    end

endmodule
