/* Simple external interrupt controller for MIPSfpga+ system 
 * managed using AHB-Lite bus
 * Copyright(c) 2017 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_eic
 */  

//reg addrs
`define EIC_REG_EICR        0   // external interrupt control register
`define EIC_REG_EIMSK_0     1   // external interrupt mask register (31 - 0 )
`define EIC_REG_EIMSK_1     2   // external interrupt mask register (63 - 32)
`define EIC_REG_EIFR_0      3   // external interrupt flag register (31 - 0 )
`define EIC_REG_EIFR_1      4   // external interrupt flag register (63 - 32)
`define EIC_REG_EIFRS_0     5   // external interrupt flag register, bit set (31 - 0 )
`define EIC_REG_EIFRS_1     6   // external interrupt flag register, bit set (63 - 32)
`define EIC_REG_EIFRC_0     7   // external interrupt flag register, bit clear (31 - 0 )
`define EIC_REG_EIFRC_1     8   // external interrupt flag register, bit clear (63 - 32)
`define EIC_REG_EISMSK_0    9   // external interrupt sense mask register (31 - 0 )
`define EIC_REG_EISMSK_1    10  // external interrupt sense mask register (63 - 32)
`define EIC_REG_EIIPR_0     11  // external interrupt input pin register (31 - 0 )
`define EIC_REG_EIIPR_1     12  // external interrupt input pin register (63 - 32)

`define EIC_ADDR_WIDTH      4   // register addr width
`define EIC_TOTAL_WIDTH     64  // max total aligned reg width

module eic
#(
    parameter   EIC_DIRECT_CHANNELS = 31,   /* 0-31 */
                EIC_SENSE_CHANNELS  = 32,   /* 0-32 */
                EIC_TOTAL_CHANNELS  = EIC_DIRECT_CHANNELS + EIC_SENSE_CHANNELS
)
(
    input       CLK,
    input       RESETn,

    //signal inputs (should be synchronized!)
    input      [ (EIC_TOTAL_CHANNELS - 1) : 0  ]  signal,

    //register access
    input      [    (`EIC_ADDR_WIDTH - 1) : 0  ]  read_addr,
    output     [                      31  : 0  ]  read_data,
    input      [    (`EIC_ADDR_WIDTH - 1) : 0  ]  write_addr,
    output     [                      31  : 0  ]  write_data,
    input                                         write_enable,

    //EIC processor interface
    output     [ 17 : 1 ] EIC_Offset,
    output     [  3 : 0 ] EIC_ShadowSet,
    output     [  7 : 0 ] EIC_Interrupt,
    output     [  5 : 0 ] EIC_Vector,
);
    //registers interface part
    wire       [                         31 : 0  ]  EICR;
    wire       [ (  `EIC_TOTAL_WIDTH   - 1) : 0  ]  EIMSK;
    wire       [ (  `EIC_TOTAL_WIDTH   - 1) : 0  ]  EIFR;
    wire       [ (  `EIC_TOTAL_WIDTH   - 1) : 0  ]  EISMSK;
    wire       [ (  `EIC_TOTAL_WIDTH   - 1) : 0  ]  EIIPR;

    //register involved part
    wire       wr_shift;
    wire       EIMSK_WR;
    wire       EISMSK_WR;

    aligned_reg64 #(.USED(  EIC_TOTAL_CHANNELS)) EIMSK_inv  (CLK, RESETn, EIMSK,  write_data, wr_shift, EIMSK_WR );
    aligned_reg64 #(.USED(2*EIC_SENSE_CHANNELS)) EISMSK_inv (CLK, RESETn, EISMSK, write_data, wr_shift, EISMSK_WR);

    //register align and combination
    wire   [ (  EIC_TOTAL_CHANNELS - 1) : 0 ]  EIFR_used;
    assign EIFR   = { 1'b0, { `EIC_TOTAL_WIDTH - EIC_TOTAL_CHANNELS - 1 { 1'b0 } }, EIFR_used };
    assign EIIPR  = { { `EIC_TOTAL_WIDTH - EIC_TOTAL_CHANNELS { 1'b0 } }, signal };

    //register read operations
    always @ (*)
        case(read_addr)
             default          :  read_data = 32'b0;
            `EIC_REG_EICR     :  read_data = EICR;
            `EIC_REG_EIMSK_0  :  read_data = EIMSK  [ 31:0  ];
            `EIC_REG_EIMSK_1  :  read_data = EIMSK  [ 63:32 ];
            `EIC_REG_EIFR_0   :  read_data = EIFR   [ 31:0  ];
            `EIC_REG_EIFR_1   :  read_data = EIFR   [ 63:32 ];
            `EIC_REG_EIFRS_0  :  read_data = EIFR   [ 31:0  ];
            `EIC_REG_EIFRS_1  :  read_data = EIFR   [ 63:32 ];
            `EIC_REG_EIFRC_0  :  read_data = 32'b0;
            `EIC_REG_EIFRC_1  :  read_data = 32'b0;
            `EIC_REG_EISMSK_0 :  read_data = EISMSK [ 31:0  ];
            `EIC_REG_EISMSK_1 :  read_data = EISMSK [ 63:32 ];
            `EIC_REG_EIIPR_0  :  read_data = EIIPR  [ 31:0  ];
            `EIC_REG_EIIPR_1  :  read_data = EIIPR  [ 31:0  ];
        endcase

    //mask register write operations
    wire [2:0] mask_cmd;
    assign { wr_shift, EIMSK_WR, EISMSK_WR } = mask_cmd;
    always @ (*)
        case(read_addr)
             default          :  mask_cmd = 3'b000;
            `EIC_REG_EIMSK_0  :  mask_cmd = 3'b010;
            `EIC_REG_EIMSK_1  :  mask_cmd = 3'b110;
            `EIC_REG_EISMSK_0 :  mask_cmd = 3'b001;
            `EIC_REG_EISMSK_1 :  mask_cmd = 3'b101;
        endcase


    wire       [ (  `EIC_TOTAL_WIDTH - 1) : 0 ]  EIFR_wr_data;
    wire       [ (  `EIC_TOTAL_WIDTH - 1) : 0 ]  EIFR_wr_enable;

    // todo: change fixed width values
    always @ (*) begin
        case(write_addr)
            default          :  EIFR_wr_enable = { `EIC_TOTAL_WIDTH { 1'b0 } };
            `EIC_REG_EIFR_0  :  EIFR_wr_enable = { `EIC_TOTAL_WIDTH { 1'b0 } } | (~32'b0);
            `EIC_REG_EIFR_1  :  EIFR_wr_enable = { `EIC_TOTAL_WIDTH { 1'b0 } } | (~32'b0 << 16);
            `EIC_REG_EIFRS_0 :  EIFR_wr_enable = { 32'b0, write_data };
            `EIC_REG_EIFRS_1 :  EIFR_wr_enable = { write_data, 32'b0 };
            `EIC_REG_EIFRC_0 :  EIFR_wr_enable = { 32'b0, write_data };
            `EIC_REG_EIFRC_1 :  EIFR_wr_enable = { write_data, 32'b0 };
        endcase

        case(write_addr)
            default          :  EIFR_wr_data = { `EIC_TOTAL_WIDTH { 1'b0 } };
            `EIC_REG_EIFR_0  :  EIFR_wr_data = { `EIC_TOTAL_WIDTH { 1'b0 } } | (~32'b0);
            `EIC_REG_EIFR_1  :  EIFR_wr_data = { `EIC_TOTAL_WIDTH { 1'b0 } } | (~32'b0 << 16);
            `EIC_REG_EIFRS_0 :  EIFR_wr_data = { `EIC_TOTAL_WIDTH { 1'b1 } };
            `EIC_REG_EIFRS_1 :  EIFR_wr_data = { `EIC_TOTAL_WIDTH { 1'b1 } };
            `EIC_REG_EIFRC_0 :  EIFR_wr_data = { `EIC_TOTAL_WIDTH { 1'b0 } };
            `EIC_REG_EIFRC_1 :  EIFR_wr_data = { `EIC_TOTAL_WIDTH { 1'b0 } };
        endcase
    end

    //interrupt input logic (signal -> request)
    wire [ (EIC_SENSE_CHANNELS - 1) : 0  ] sensed;
    generate 
        genvar i;

        for (i = 0; i < EIC_SENSE_CHANNELS; i = i + 1)
        begin : sirq
            interrupt_sence sense 
            (
                .CLK        ( CLK                ),
                .RESETn     ( RESETn             ),
                .senceMask  ( EISMSK_inv [ (1+i*2):(i*2) ] ),
                .signalIn   ( signal         [i] ),
                .signalOut  ( sensed         [i] )
            );

            interrupt_channel channel 
            (
                .CLK        ( CLK                ),
                .RESETn     ( RESETn             ),
                .signalMask ( EIMSK_inv      [i] ),
                .signalIn   ( sensed         [i] ),
                .requestWR  ( EIFR_wr_enable [i] ),
                .requestIn  ( EIFR_wr_data   [i] ),
                .requestOut ( EIFR_used      [i] )
            );
        end

        for (i = EIC_SENSE_CHANNELS; i < EIC_TOTAL_CHANNELS; i = i + 1)
        begin : irq
            interrupt_channel channel 
            (
                .CLK        ( CLK                ),
                .RESETn     ( RESETn             ),
                .signalMask ( EIMSK_inv      [i] ),
                .signalIn   ( signal         [i] ),
                .requestWR  ( EIFR_wr_enable [i] ),
                .requestIn  ( EIFR_wr_data   [i] ),
                .requestOut ( EIFR_used      [i] )
            );
        end
    endgenerate 

    //interrupt priority decode (EIFR -> irqNumber)
    wire                 irqDetected;
    wire      [  5 : 0 ] irqNumberL;
    wire      [  7 : 0 ] irqNumber  = { 2'b0, irqNumberL };

    priority_encoder64 priority_encoder //use priority_encoder255 for more interrupt inputs
    ( 
        .in     ( EIFR        ), 
        .detect ( irqDetected ),
        .out    ( irqNumberL  )
    );

    //interrupt priority decode (irqNumber -> handler_params)
    handler_params_decoder handler_params_decoder
    (
        .irqNumber      ( irqNumber     ),
        .irqDetected    ( irqDetected   ),
        .EIC_Offset     ( EIC_Offset    ),
        .EIC_ShadowSet  ( EIC_ShadowSet ),
        .EIC_Interrupt  ( EIC_Interrupt ),
        .EIC_Vector     ( EIC_Vector    )
    );

endmodule

module aligned_reg64
#(
    parameter   USED  = 8
)
(
    input                 CLK,
    input                 RESETn,
    output reg [ 63 : 0 ] rd_data,
    input      [ 31 : 0 ] wr_data,
    input                 wr_shift,
    input                 wr
);
    reg [(USED - 1) : 0] data;

    assign rd_data  = { {(64 - USED){1'b0}}, data };

    assign wr_data0 = (USED > 32) ? { data    [ (USED-1)    : 32 ], wr_data    }
                                  :   wr_data [ (USED-1)    : 0  ];

    assign wr_data1 = (USED > 32) ? { wr_data [ (USED-32-1) : 0  ], data[31:0] }
                                  :   data;

    always @ (posedge CLK)
        if(~RESETn)
            data <= { USED {1'b0}};
        else
            casez({wr, wr_shift})
                2'b0? : ;
                2'b10 : data <= wr_data0;
                2'b11 : data <= wr_data1;
            endcase
endmodule

module handler_params_decoder
(
    input      [  7 : 0 ] irqNumber,
    input                 irqDetected,
    
    output     [ 17 : 1 ] EIC_Offset,
    output     [  3 : 0 ] EIC_ShadowSet,
    output     [  7 : 0 ] EIC_Interrupt,
    output     [  5 : 0 ] EIC_Vector
);
    // A value of 0 indicates that no interrupt requests are pending
    assign EIC_Offset    = 17'b0;
    assign EIC_ShadowSet = 4'b0;
    assign EIC_Interrupt = irqDetected ? irqNumber + 1  : 8'b0;
    assign EIC_Vector    = EIC_Interrupt[5:0];

endmodule





module interrupt_channel
(
    input       CLK,
    input       RESETn,
    input       signalMask, // Interrupt mask (0 - disabled, 1 - enabled)
    input       signalIn,   // Interrupt intput signal
    input       requestWR,  // forced interrupt flag change
    input       requestIn,  // forced interrupt flag value
    output reg  requestOut  // interrupt flag
);
    wire request =  requestWR   ? requestIn : 
                    (signalMask & signalIn | requestOut);

    always @ (posedge CLK)
        if(~RESETn)
            requestOut <= 1'b0;
        else
            requestOut <= request;

endmodule

//Interrupt sense control
module interrupt_sence
(
    input       CLK,
    input       RESETn,
    input [1:0] senceMask,
    input       signalIn,
    output reg  signalOut
);
    // senceMask:
    parameter   MASK_LOW  = 2'b00, // The low level of signalIn generates an interrupt request
                MASK_ANY  = 2'b01, // Any logical change on signalIn generates an interrupt request
                MASK_FALL = 2'b10, // The falling edge of signalIn generates an interrupt request
                MASK_RIZE = 2'b11; // The rising edge of signalIn generates an interrupt request

    parameter   S_RESET   = 0,
                S_INIT0   = 1,
                S_INIT1   = 2,
                S_WORK    = 3;

    reg [ 1 : 0 ]   State, Next;
    reg [ 1 : 0 ]   signal;

    always @ (posedge CLK)
        if(~RESETn)
            State <= S_INIT0;
        else
            State <= Next;

    always @ (posedge CLK)
        case(State)
            S_RESET : signal <= 2'b0;
            default : signal <= { signal[0], signalIn };
        endcase

    always @ (*) begin

        case (State)
            S_RESET : Next = S_INIT0;
            S_INIT0 : Next = S_INIT1;
            default : Next = S_WORK;
        endcase

        case( { State, senceMask } )
            { S_WORK, MASK_LOW  } : signalOut = ~signal[1] & ~signal[0]; 
            { S_WORK, MASK_ANY  } : signalOut =  signal[1] ^  signal[0];
            { S_WORK, MASK_FALL } : signalOut =  signal[1] & ~signal[0]; 
            { S_WORK, MASK_RIZE } : signalOut = ~signal[1] &  signal[0]; 
            default               : signalOut = 1'b0;
        endcase
    end

endmodule
