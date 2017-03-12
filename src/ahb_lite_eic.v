/* Simple external interrupt controller for MIPSfpga+ system 
 * managed using AHB-Lite bus
 * Copyright(c) 2017 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_eic
 *
 */  



module eic
#(
    parameter   EIC_DIRECT_CHANNELS = 31,
                EIC_SENSE_CHANNELS  = 32,
                EIC_TOTAL_CHANNELS  = EIC_DIRECT_CHANNELS + EIC_SENSE_CHANNELS
)
(
    input       CLK,
    input       RESETn,

    //signal inputs
    input      [ (EIC_TOTAL_CHANNELS - 1) : 0  ]  signal,  

    //EIC processor interface
    output     [ 17 : 1 ] EIC_Offset,
    output     [  3 : 0 ] EIC_ShadowSet,
    output     [  7 : 0 ] EIC_Interrupt,
    output     [  5 : 0 ] EIC_Vector,

    //debug only
    input      [ (EIC_TOTAL_CHANNELS - 1) : 0  ]  mask
);
    reg [ 31 : 0  ] status; //eic config register

    //interrupt input logic
    //reg [ (EIC_TOTAL_CHANNELS - 1) : 0  ] mask;
    //reg [ (EIC_TOTAL_CHANNELS - 1) : 0  ] requestWR;
    //reg [ (EIC_TOTAL_CHANNELS - 1) : 0  ] requestIn;
    

    //debug only
    wire [   (EIC_TOTAL_CHANNELS - 1) : 0  ] requestWR = 32'b0;
    wire [   (EIC_TOTAL_CHANNELS - 1) : 0  ] requestIn = 32'b0;
    wire [ 2*(EIC_TOTAL_CHANNELS - 1) : 0  ] senceMask = 32'hFFFFFFFF; //low level

    //interrupt input logic (signal -> request)
    wire [ (EIC_TOTAL_CHANNELS - 1) : 0  ] request;
    wire [ (EIC_SENSE_CHANNELS - 1) : 0  ] sensed;
    generate 
        genvar i;

        for (i = 0; i < EIC_SENSE_CHANNELS; i = i + 1)
        begin : sirq
            interrupt_sence sense 
            (
                .CLK        ( CLK           ),
                .RESETn     ( RESETn        ),
                .senceMask  ( senceMask [ (1+i*2):(i*2) ] ),
                .signalIn   ( signal    [i] ),
                .signalOut  ( sensed    [i] )
            );

            interrupt_channel channel 
            (
                .CLK        ( CLK           ),
                .RESETn     ( RESETn        ),
                .signalMask ( mask      [i] ),
                .signalIn   ( sensed    [i] ),
                .requestWR  ( requestWR [i] ),
                .requestIn  ( requestIn [i] ),
                .requestOut ( request   [i] )
            );
        end

        for (i = EIC_SENSE_CHANNELS; i < EIC_TOTAL_CHANNELS; i = i + 1)
        begin : irq
            interrupt_channel channel 
            (
                .CLK        ( CLK           ),
                .RESETn     ( RESETn        ),
                .signalMask ( mask      [i] ),
                .signalIn   ( signal    [i] ),
                .requestWR  ( requestWR [i] ),
                .requestIn  ( requestIn [i] ),
                .requestOut ( request   [i] )
            );
        end
    endgenerate 

    //interrupt priority decode (request -> irqNumber)
    wire      [ 63 : 0 ] irqRequest = { 1'b0, { 63 - EIC_TOTAL_CHANNELS { 1'b0 } }, request };
    wire                 irqDetected;

    wire      [  5 : 0 ] irqNumberL;
    wire      [  7 : 0 ] irqNumber  = { 2'b0, irqNumberL };

    priority_encoder64 priority_encoder //use priority_encoder255 for more interrupt inputs
    ( 
        .in     ( irqRequest  ), 
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


module priority_encoder255
(
    input      [ 255 : 0 ] in,
    output reg             detect,
    output reg [   7 : 0 ] out
);
    wire [3:0] detectL;
    wire [5:0] preoutL [3:0];
    wire [1:0] preoutM;

    //1st order entries
    priority_encoder64 e10( in[  63:0   ], detectL[0], preoutL[0] );
    priority_encoder64 e11( in[ 127:64  ], detectL[1], preoutL[1] );
    priority_encoder64 e12( in[ 191:128 ], detectL[2], preoutL[2] );
    priority_encoder64 e13( in[ 255:192 ], detectL[3], preoutL[3] );

    always @ (*)
        casez(detectL)
            default : {detect, out} = 9'b0;
            4'b0001 : {detect, out} = { 3'b100, preoutL[0] };
            4'b001? : {detect, out} = { 3'b101, preoutL[1] };
            4'b01?? : {detect, out} = { 3'b110, preoutL[2] };
            4'b1??? : {detect, out} = { 3'b111, preoutL[3] };
        endcase
endmodule

module priority_encoder64
(
    input      [ 63 : 0 ] in,
    output                detect,
    output     [  5 : 0 ] out
);
    wire [7:0] detectL;
    wire [2:0] preoutL [7:0];
    wire [2:0] preoutM;

    //3rd order entries
    priority_encoder8 e30( in[  7:0  ], detectL[0], preoutL[0] );
    priority_encoder8 e31( in[ 15:8  ], detectL[1], preoutL[1] );
    priority_encoder8 e32( in[ 23:16 ], detectL[2], preoutL[2] );
    priority_encoder8 e33( in[ 31:24 ], detectL[3], preoutL[3] );
    priority_encoder8 e34( in[ 39:32 ], detectL[4], preoutL[4] );
    priority_encoder8 e35( in[ 47:40 ], detectL[5], preoutL[5] );
    priority_encoder8 e36( in[ 55:48 ], detectL[6], preoutL[6] );
    priority_encoder8 e37( in[ 63:56 ], detectL[7], preoutL[7] );

    //2nd order entry
    priority_encoder8 e20(detectL, detect, preoutM);

    assign out = detect ? { preoutM, preoutL[preoutM] } : 6'b0;
endmodule

module priority_encoder8
(
    input       [ 7 : 0 ] in,
    output reg            detect,
    output reg  [ 2 : 0 ] out
);
    always @ (*)
        casez(in)
            default     : {detect, out} = 4'b0000;
            8'b00000001 : {detect, out} = 4'b1000;
            8'b0000001? : {detect, out} = 4'b1001;
            8'b000001?? : {detect, out} = 4'b1010;
            8'b00001??? : {detect, out} = 4'b1011;
            8'b0001???? : {detect, out} = 4'b1100;
            8'b001????? : {detect, out} = 4'b1101;
            8'b01?????? : {detect, out} = 4'b1110;
            8'b1??????? : {detect, out} = 4'b1111;
        endcase
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
