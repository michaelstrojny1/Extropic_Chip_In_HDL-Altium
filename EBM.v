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
        for (i = 0; i < number_size; i = i + 1) 
        begin:
            FA inst(
                a[i],
                b[i],
                carry[i],
                sum[i],
                carry[i+1]
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
        for (i = 0; i < number_size; i = i + 1) 
        begin:
            FS inst(a[i],b[i],carry[i],sum[i],carry[i+1]);
        end
    endgenerate
    assign cout = carry[number_size];

endmodule

// 16 bit adder

module Add16(
    input  logic [16:0] v1,
    input  logic [16:0] v2,
    output logic [16:0] v3,
    output logic cout);

    RippleAdd #(16) ra (
    v1, v2, 1'b0, v3, cout
    );
endmodule

// signed multiply

module Multiplier #(parameter int number_size = 16)(
    input  logic signed [number_size-1:0] m1,
    input  logic signed [number_size-1:0] m2,
    output logic signed [number_size-1:0] m3    // our number is <1 in magnitude so the number_size-1 size works
);
    logic signed [(2*number_size)-1:0] full_p;
    assign full_p = m1 * m2;   // future replace with raw multiplier
    assign m3 = full_p[number_size-1:0];
endmodule

module GT #(parameter int number_size = 16)(
    input  logic signed [number_size-1:0] m1,
    input  logic signed [number_size-1:0] m2,
    output logic out
);
wire temp, temp2;
RippleSubtract #(number_size) rs (m1, m2, 1'b0, , temp);


assign out = ~temp;
endmodule

// n bit weight and bias boltzmann

module Boltzmann #(
    parameter int number_size = 16,
    parameter int CLOCK_FREQ = 50_000_000
)(
    input logic clk,
    input real noise,
    input on;
    input logic train,  // future
    input logic sample,  // future
    input logic[3:0] neighbours,
    input logic signed [number_size-1:0] weight1,
    input logic signed [number_size-1:0] weight2,
    input logic signed [number_size-1:0] weight3,
    input logic signed [number_size-1:0] weight4,
    input logic signed [number_size-1:0] bias,
    output logic node
);
    wire signed [number_size-1:0] term1, term2, term3, term4, sum12, sum34, probability;

    // sum of weights*neighbours
    Multiplier #(number_size) mult1(weight1,{{(number_size-1){1'b0}}, neighbours[0]}, .m3(term1));
    Multiplier #(number_size) mult1(weight2,{{(number_size-1){1'b0}}, neighbours[1]}, .m3(term1));
    Multiplier #(number_size) mult1(weight3,{{(number_size-1){1'b0}}, neighbours[2]}, .m3(term1));
    Multiplier #(number_size) mult1(weight4,{{(number_size-1){1'b0}}, neighbours[3]}, .m3(term1));
    Add16(term1, term2, sum12);
    Add16(term3, term4, sum34);
    assign probability = sum12 + sum34 + bias;

    Sigmoid(probability, prob);

    node = prob > noise;

    always_ff @(posedge clk or negedge on) 
    begin
        if (!on)
            node <= 1'b0;    // initiallized when off / node reset back to 0
        else if (on)
            node <= node;
        else
            node <= (probability >= 0);
    end

endmodule
