/* Simple external interrupt controller for MIPSfpga+ system 
 * managed using AHB-Lite bus
 * Copyright(c) 2017 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_eic
 *
 */  



module eic
#(
    parameter   EIC_DIRECT_CHANNELS = 32,   /* 0-32 */
                EIC_SENSE_CHANNELS  = 32,   /* 0-32 */
                EIC_TOTAL_CHANNELS  = EIC_DIRECT_CHANNELS + EIC_SENSE_CHANNELS
)
(
    input       CLK,
    input       RESETn,

    input      [ (EIC_TOTAL_CHANNELS - 1) : 0  ]  signal,  //signal inputs

    //EIC processor interface
    output     [ 7 : 0 ] EIC_Interrupt,
    output     [ 5 : 0 ] EIC_Vector,

    //debug only
    input      [ (EIC_TOTAL_CHANNELS - 1) : 0  ]  mask
);
    reg [ 31 : 0  ] status; //eic config register

    //interrupt input logic
    //reg [ (EIC_TOTAL_CHANNELS - 1) : 0  ] mask;
    //reg [ (EIC_TOTAL_CHANNELS - 1) : 0  ] requestWR;
    //reg [ (EIC_TOTAL_CHANNELS - 1) : 0  ] requestIn;
    wire [ (EIC_TOTAL_CHANNELS - 1) : 0  ] request;

    //debug only
    wire [ (EIC_TOTAL_CHANNELS - 1) : 0  ] requestWR = 32'b0;
    wire [ (EIC_TOTAL_CHANNELS - 1) : 0  ] requestIn = 32'b0;


    //interrupt priority decode (request -> irqNumber)
    wire [ 62 : 0 ] irqRequest = { { 63 - EIC_TOTAL_CHANNELS { 1'b0 } }, request };
    wire [  5 : 0 ] irqNumber;
    assign EIC_Interrupt = { 2'b00, irqNumber };
    assign EIC_Vector    = irqNumber;

    priority_encoder63to6 encoder( .in(irqRequest), .out(irqNumber));

    //interrupt input logic (signal -> request)
    generate 
        genvar i;
        for (i = 0; i < EIC_TOTAL_CHANNELS; i = i + 1)
        begin : irq
            interrupt_channel channel (
                .CLK        ( CLK           ),
                .RESETn     ( RESETn        ),
                .signalMask ( mask[i]       ),
                .signalIn   ( signal[i]     ),
                .requestWR  ( requestWR[i]  ),
                .requestIn  ( requestIn[i]  ),
                .requestOut ( request[i]    )
            );
        end
    endgenerate 



endmodule

module priority_encoder63to6
(
    input      [ 62 : 0 ] in,
    output     [  5 : 0 ] out
);
    wire [7:0] detect;
    wire [2:0] preoutL [7:0];
    wire [2:0] preoutM;
    wire detected;

    //2nd order entries
    priority_encoder8to3 e10(in [  7:0  ], detect[0], preoutL[0] );
    priority_encoder8to3 e11(in [ 15:8  ], detect[1], preoutL[1] );
    priority_encoder8to3 e12(in [ 23:16 ], detect[2], preoutL[2] );
    priority_encoder8to3 e13(in [ 31:24 ], detect[3], preoutL[3] );
    priority_encoder8to3 e14(in [ 39:32 ], detect[4], preoutL[4] );
    priority_encoder8to3 e15(in [ 47:40 ], detect[5], preoutL[5] );
    priority_encoder8to3 e16(in [ 55:48 ], detect[6], preoutL[6] );
    priority_encoder8to3 e17( { 1'b0, in [ 62:56 ] }, detect[7], preoutL[7] );

    //1st order entry
    priority_encoder8to3 e00(detect, detected, preoutM);

    assign out = detected ? ({ preoutM, preoutL[preoutM] } + 1) : 5'b0;
endmodule

module priority_encoder8to3
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
