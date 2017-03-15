
`timescale 1ns / 100ps

`define EIC_DIRECT_CHANNELS 20
`define EIC_SENSE_CHANNELS  20

`include "mfp_eic_core.vh"

module test_eic;

    `include "ahb_lite.vh"

    reg  [ `EIC_CHANNELS    -1 : 0 ] signal;
    wire [                  17 : 1 ] EIC_Offset;
    wire [                   3 : 0 ] EIC_ShadowSet;
    wire [                   7 : 0 ] EIC_Interrupt;
    wire [                   5 : 0 ] EIC_Vector;
    wire                             EIC_Present;
    reg  [ `EIC_ADDR_WIDTH - 1 : 0 ] read_addr;
    wire [                  31 : 0 ] read_data;
    reg  [ `EIC_ADDR_WIDTH - 1 : 0 ] write_addr;
    reg  [                  31 : 0 ] write_data;
    reg                              write_enable;

    task eicRead;
        input [ `EIC_ADDR_WIDTH - 1 : 0 ] _read_addr;

        begin
            read_addr = _read_addr;
            @(posedge HCLK);

            $display("%t READEN ADDR=%h DATA=%h",
                     $time, _read_addr, read_data);
        end
    endtask

    task eicWrite;
        input [ `EIC_ADDR_WIDTH - 1 : 0 ] _write_addr;
        input [                  31 : 0 ] _write_data;

        begin
            write_addr   = _write_addr;
            write_data   = _write_data;
            write_enable = 1'b1;

            @(posedge HCLK);

            write_enable = 1'b0;

            $display("%t WRITEN ADDR=%h DATA=%h",
                     $time, _write_addr, _write_data);
        end
    endtask

    task delay;
        begin
            @(posedge HCLK);
            @(posedge HCLK);
            @(posedge HCLK);
        end
    endtask

    mfp_eic_core eic
    (
        .CLK            ( HCLK          ),
        .RESETn         ( HRESETn       ),
        .signal         ( signal        ),
        .read_addr      ( read_addr     ),
        .read_data      ( read_data     ),
        .write_addr     ( write_addr    ),
        .write_data     ( write_data    ),
        .write_enable   ( write_enable  ),
        .EIC_Offset     ( EIC_Offset    ),
        .EIC_ShadowSet  ( EIC_ShadowSet ),
        .EIC_Interrupt  ( EIC_Interrupt ),
        .EIC_Vector     ( EIC_Vector    ),
        .EIC_Present    ( EIC_Present   )
    );

    parameter Tclk = 20;
    always #(Tclk/2) HCLK = ~HCLK;

    initial begin
        begin

            /*
            `define EIC_REG_EICR        +
            `define EIC_REG_EIMSK_0     +
            `define EIC_REG_EIMSK_1     +
            `define EIC_REG_EIFR_0      +
            `define EIC_REG_EIFR_1      
            `define EIC_REG_EIFRS_0     +
            `define EIC_REG_EIFRS_1     
            `define EIC_REG_EIFRC_0     
            `define EIC_REG_EIFRC_1     +
            `define EIC_REG_EISMSK_0    +
            `define EIC_REG_EISMSK_1    
            `define EIC_REG_EIIPR_0     +
            `define EIC_REG_EIIPR_1     +
            */

            signal  = 16'b0;

            HRESETn = 0;
            @(posedge HCLK);
            @(posedge HCLK);
            HRESETn = 1;

            @(posedge HCLK);
            @(posedge HCLK);

            eicWrite(`EIC_REG_EICR, 32'h01);     //enable eic 
            eicWrite(`EIC_REG_EISMSK_0, 32'h05); //any logical change for irq 1, 2 (pins 0, 1)

            eicWrite(`EIC_REG_EIMSK_0, 32'h03); //enable irq 1, 2 (pins 0, 1)
            eicWrite(`EIC_REG_EIMSK_1, 32'h01); //enable irq 33 (pin 32)

            eicRead(`EIC_REG_EIMSK_0);
            eicRead(`EIC_REG_EIMSK_1);

            @(posedge HCLK);    signal[0]   = 1'b1;
            @(posedge HCLK);    signal[1]   = 1'b1;
            delay();

            @(posedge HCLK);    signal[32]  = 1'b1;
            @(posedge HCLK);    signal[32]  = 1'b0;
            delay();

            eicRead(`EIC_REG_EIFR_1);

            eicWrite(`EIC_REG_EIFRC_1, 32'h01); //clear irq 33 (pin 32)

            eicRead(`EIC_REG_EIFR_0);
            delay();

            eicWrite(`EIC_REG_EIFR_0, 32'h01); //set EIFR word0
            eicRead(`EIC_REG_EIFR_0);
            delay();

            eicWrite(`EIC_REG_EIFRS_0, 32'h04); //set EIFR bit3
            eicRead(`EIC_REG_EIFR_0);
            delay();
        end
        $stop;
        $finish;
    end
endmodule




/*
module test_uart_transmit;

    `include "ahb_lite.vh"
    `include "uart.vh"
    `include "uart_defines.v"

    assign UART_SRX = UART_STX;

    ahb_lite_uart16550 uart
    (
        .HCLK       (   HCLK        ),
        .HRESETn    (   HRESETn     ),
        .HADDR      (   HADDR       ),
        .HBURST     (   HBURST      ),
        .HSEL       (   HSEL        ),
        .HSIZE      (   HSIZE       ),
        .HTRANS     (   HTRANS      ),
        .HWDATA     (   HWDATA      ),
        .HWRITE     (   HWRITE      ),
        .HRDATA     (   HRDATA      ),
        .HREADY     (   HREADY      ),
        .HRESP      (   HRESP       ),

        .UART_SRX   (   UART_SRX    ),  // UART serial input signal
        .UART_STX   (   UART_STX    ),  // UART serial output signal
        .UART_RTS   (   UART_RTS    ),  // UART MODEM Request To Send
        .UART_CTS   (   UART_CTS    ),  // UART MODEM Clear To Send
        .UART_DTR   (   UART_DTR    ),  // UART MODEM Data Terminal Ready
        .UART_DSR   (   UART_DSR    ),  // UART MODEM Data Set Ready
        .UART_RI    (   UART_RI     ),  // UART MODEM Ring Indicator
        .UART_DCD   (   UART_DCD    ),  // UART MODEM Data Carrier Detect

        //UART internal
        .UART_BAUD  (   UART_BAUD   ),  // UART baudrate output
        .UART_INT   (   UART_INT    )   // UART interrupt
    );

    parameter Tclk = 20;
    always #(Tclk/2) HCLK = ~HCLK;

    initial begin
        begin

            HRESETn = 0;
            @(posedge HCLK);
            @(posedge HCLK);
            HRESETn = 1;

            @(posedge HCLK);
            //uart init & transmit 1 byte 0xF1

            // 1 working
            // ahbPhaseFst((`UART_REG_LC   << 2),   1, St_x);

            ahbPhaseFst((`UART_REG_LC   << 2),   1, St_x);
            ahbPhase   ((`UART_REG_MC   << 2),   1, 8'b11);     //8n1
            ahbPhase   ((`UART_REG_LC   << 2),   1, 8'b11);     //DTR + RTS
            
            // ahbPhase   ((`UART_REG_IE   << 2),   1, 8'b11);     //8n1
            // ahbPhase   ((`UART_REG_FC   << 2),   1, 8'b0);      //no interrupt
            // ahbPhase   ((`UART_REG_MC   << 2),   1, 8'b0);      //no fifo
            // ahbPhase   ((`UART_REG_LC   << 2),   0, 8'b11);     //DTR + RTS
            

            ahbPhase    ((`UART_REG_DL1  << 2),  1, 8'b11 | (1 << 7));
            ahbPhase    ((`UART_REG_DL2  << 2),  1, 8'd2);
            ahbPhase    ((`UART_REG_LC   << 2),   1, 8'b0);
            ahbPhase    ((`UART_REG_TR   << 2),   1, 8'b11);
            ahbPhase    ((`UART_REG_LS   << 2),   0, 8'h22);
            ahbPhase    ((`UART_REG_LS   << 2),   0, St_x);
            
            //waiting for transmit finish
            repeat(400)
                ahbPhase((`UART_REG_LS  << 2), 0, St_x);
            
            //reading input
            ahbPhase    ((`UART_REG_RB   << 2), 0, St_x);
            ahbPhase    ((`UART_REG_RB   << 2), 0, St_x);

            ahbPhaseLst ((`UART_REG_RB   << 2), 0, St_x);

            @(posedge HCLK);
            @(posedge HCLK);
        end
        $stop;
        $finish;
    end

endmodule
*/