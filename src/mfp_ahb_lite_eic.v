/* Simple external interrupt controller for MIPSfpga+ system 
 * managed using AHB-Lite bus
 * Copyright(c) 2017 Stanislav Zhelnio
 * https://github.com/zhelnio/ahb_lite_eic
 */  

module mfp_ahb_lite_eic
(
    //ABB-Lite side
    input                              HCLK,
    input                              HRESETn,
    input      [ 31 : 0 ]              HADDR,
    input      [  2 : 0 ]              HBURST,
    input                              HMASTLOCK,  // ignored
    input      [  3 : 0 ]              HPROT,      // ignored
    input                              HSEL,
    input      [  2 : 0 ]              HSIZE,
    input      [  1 : 0 ]              HTRANS,
    input      [ 31 : 0 ]              HWDATA,
    input                              HWRITE,
    output reg [ 31 : 0 ]              HRDATA,
    output                             HREADY,
    output                             HRESP,
    input                              SI_Endian,  // ignored

    //Interrupt side
    input      [ `EIC_CHANNELS-1 : 0 ] signal,
    output     [ 17 : 1 ]              EIC_Offset,
    output     [  3 : 0 ]              EIC_ShadowSet,
    output     [  7 : 0 ]              EIC_Interrupt,
    output     [  5 : 0 ]              EIC_Vector,
    output                             EIC_Present
);

    wire [ `EIC_ADDR_WIDTH - 1 : 0 ] read_addr;
    wire [                  31 : 0 ] read_data;
    wire [ `EIC_ADDR_WIDTH - 1 : 0 ] write_addr;
    reg  [                  31 : 0 ] write_data;
    wire                             write_enable;

    wire NeedAction = HTRANS != HTRANS_IDLE && HSEL;

    //STOPPED HERE! (continue tomorrow)


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

    


/*
    parameter   S_INIT      = 0,
                S_IDLE      = 1,
                S_READ      = 2,
                S_WRITE     = 3;
    
    reg  [ 1:0 ]    State, Next;

    assign      HRESP  = 1'b0;
    assign      HREADY = (State ==  S_IDLE);

    always @ (posedge HCLK) begin
        if (~HRESETn)
            State <= S_INIT;
        else
            State <= Next;
    end

    reg  [ 2:0 ]    ADDR_old;
    wire [ 2:0 ]    ADDR = HADDR [ 4:2 ];
    wire [ 7:0 ]    ReadData;

    parameter       HTRANS_IDLE       = 2'b0;
    wire            NeedAction = HTRANS != HTRANS_IDLE && HSEL;

    always @ (*) begin
        //State change decision
        case(State)
            default     :   Next = S_IDLE;
            S_IDLE      :   Next = ~NeedAction  ? S_IDLE : (
                                    HWRITE      ? S_WRITE : S_READ );
        endcase
    end

    always @ (posedge HCLK) begin
        case(State)
            S_INIT      :   ;
            S_IDLE      :   if(HSEL) ADDR_old <= ADDR;
            S_READ      :   HRDATA <= { 24'b0, ReadData};
            S_WRITE     :   ;
        endcase
    end

    wire [ 7:0 ]    WriteData   = HWDATA [ 7:0 ];
    wire [ 2:0 ]    ActionAddr;
    wire            WriteAction;
    wire            ReadAction;
    reg  [ 10:0 ]   conf;

    assign { ReadAction, WriteAction, ActionAddr } = conf;

    always @ (*) begin
        //io
        case(State)
            default     :   conf = { 2'b00, 8'b0     };
            S_READ      :   conf = { 2'b10, ADDR     };
            S_WRITE     :   conf = { 2'b01, ADDR_old };
        endcase
    end
*/

endmodule

