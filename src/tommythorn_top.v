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

`ifdef SIMULATE
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
`endif

module tommythorn_top (
  input [7:0]  io_in,
  output [7:0] io_out
);

   // Alas we don't have space for 512 FFs, so we just exercize the
   // quarter-round

   reg [3:0] abcd[31:0];
   wire [31:0] a_out;
   wire [31:0] b_out;
   wire [31:0] c_out;
   wire [31:0] d_out;

   wire [31:0] a = {abcd[31],abcd[30],abcd[29],abcd[28],abcd[27],abcd[26],abcd[25],abcd[24]};
   wire [31:0] b = {abcd[23],abcd[22],abcd[21],abcd[20],abcd[19],abcd[18],abcd[17],abcd[16]};
   wire [31:0] c = {abcd[15],abcd[14],abcd[13],abcd[12],abcd[11],abcd[10],abcd[9],abcd[8]};
   wire [31:0] d = {abcd[7],abcd[6],abcd[5],abcd[4],abcd[3],abcd[2],abcd[1],abcd[0]};

   chacha20_qr qr(a, b, c, d, a_out, b_out, c_out, d_out);

   wire [4:0]  data_in = io_in[4:0];
   wire        sel_we  = io_in[6];
   wire        data_we = io_in[7];

   // Reading out 8-bit at a time from 128, thus 16
   reg [5:0]   sel;
   assign io_out[3:0] = {a_out,b_out,c_out,d_out} >> (sel * 4);

   always @(*) begin
      if (sel_we)
        sel <= data_in;

      if (data_we) begin
         abcd[sel] <= data_in;
         $display("top: write abcd[%d] = %x, getting %x", sel, data_in, {a,b,c,d});
      end
   end
endmodule
 
`ifdef SIMULATE
module tommythorn_top_tb;
   reg [127:0]  abcd = 128'h 2f5ee82ec5941bfac7e80863910aee32;
   reg [127:0]  abcd_out;

   reg          sel_we = 0;
   reg          data_we = 0;
   reg [4:0]    data;

   wire [7:0]   io_out;

   tommythorn_top tt({data_we, sel_we, 1'b 0, data}, io_out);

   reg [6:0]    i;

   initial begin
      $display("Testing %x", abcd);
      $display("  top %x", abcd[127:124]);

      sel_we = 0;
      data_we = 0;

      for (i = 0; i < 32; i = i + 1) begin
         data = i;
         #10 sel_we = 1;
         #10 sel_we = 0;

         data = abcd[3:0];
         #10 data_we = 1;
         #10 data_we = 0;
         abcd = abcd >> 4;
      end

      #10 data_we = 0;
      for (i = 0; i < 32; i = i + 1) begin
         data = i;
         #10 sel_we = 1;
         #10 sel_we = 0;
         $display("%d: %x", i, io_out[3:0]);
      end
   end
endmodule
`endif
