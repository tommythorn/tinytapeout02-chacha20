`default_nettype none

// See https://en.wikipedia.org/wiki/Salsa20
module chacha20_qr(
  input wire [31:0] a,
  input wire [31:0] b,
  input wire [31:0] c,
  input wire [31:0] d,

  output wire [31:0] a2,
  output wire [31:0] b2,
  output wire [31:0] c2,
  output wire [31:0] d2
);
   // a += b; d ^= a; d <<<= 16;
   wire [31:0] a1 = a + b;
   wire [31:0] d1_ = a1 ^ d;
   wire [31:0] d1 = {d1_[15:0],d1_[31:16]};

   // c += d; b ^= c; b <<<= 12;
   wire [31:0] c1 = c + d1;
   wire [31:0] b1_ = b ^ c1;
   wire [31:0] b1 = {b1_[19:0],b1_[31:20]};

   // a += b; d ^= a; d <<<= 8;
   assign a2 = a1 + b1;
   wire [31:0] d2_ = a2 ^ d1;
   assign d2 = {d2_[23:0],d2_[31:24]};

   // c += d; b ^= c; b <<<= 7;
   assign c2 = c1 + d2;
   wire [31:0] b2_ = b1 ^ c2;
   assign b2 = {b2_[24:0],b2_[31:25]};
endmodule


module tommythorn_top #( parameter MAX_COUNT = 1000 ) (
  input [7:0]  io_in,
  output [7:0] io_out
);

   // Alas we don't have space for 512 FFs, so we just exercize the
   // quarter-round

   reg [31:0]  a;
   reg [31:0]  b;
   reg [31:0]  c;
   reg [31:0]  d;
   wire [31:0] a_out;
   wire [31:0] b_out;
   wire [31:0] c_out;
   wire [31:0] d_out;

   chacha20_qr qr(a, b, c, d, a_out, b_out, c_out, d_out);

   wire        clk = io_in[0];
   wire        we = io_in[1];

   // Reading out 8-bit at a time from 128, thus 16
   reg [3:0]   sel;
   assign io_out = {a_out,b_out,c_out,d_out} << (sel * 8);

   always @(posedge clk) begin
      sel <= io_in[7:4];

      if (we)
        {a,b,c,d} <= {{a,b,c,d} << 4, io_in[7:4]};
   end
endmodule

module chacha20_qr_tb;
   reg [31:0]  a;
   reg [31:0]  b;
   reg [31:0]  c;
   reg [31:0]  d;
   wire [31:0] a_out;
   wire [31:0] b_out;
   wire [31:0] c_out;
   wire [31:0] d_out;

   chacha20_qr qr(a, b, c, d, a_out, b_out, c_out, d_out);

   // QR(2f5ee82e,c5941bfa,c7e80863,910aee32) -> (5c4d6ba1,255035b7,0910c712,570e58b6)

   initial begin
      a = 32'h 2f5ee82e;
      b = 32'h c5941bfa;
      c = 32'h c7e80863;
      d = 32'h 910aee32;

      if (a_out != 32'h 5c4d6ba1 ||
          b_out != 32'h 255035b7 ||
          b_out != 32'h 0910c712 ||
          b_out != 32'h 570e58b6)
        $display("expected 5c4d6ba1 255035b7 0910c712 570e58b6 but got %x %x %x %x",
                 a_out, b_out, c_out, d_out);
      else
        $display("good");
   end
endmodule
