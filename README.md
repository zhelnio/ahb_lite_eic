# alb_lite_iec
External Interrupt Controller for MIPSfpga+ system

## Main features
- very simple;
- up to 64 interrupts with independent interrupt vectors;
- the count of interrupts can be customized;
- two types of interrupt channels: direct channel and sense channel. The second type can be tuned to take only the low signal value, any logical change of input signal, the falling edge of input signal, or the rising edge of input signal.
- up to 32 sense channel interrupts;
- full supports of microAptiv™ external interrupt controller operation options: 'Explicit Vector Number' and 'Explicit Vector Offset' - the interrupt handler offset can be directly transmitted to the CPU. For details see the chapter 5.3.1.3 in 'MIPS32® microAptiv™ UP Processor Core Family Software User’s Manual, Revision 01.02';
- merged to MIPSfpga+ github project: https://github.com/MIPSfpga/mipsfpga-plus
- EIC usage example was included (MIPSfpga+/programs/07_iec);
- there is a standalone github project for controller debug: https://github.com/zhelnio/ahb_lite_eic
- to enable EIC uncomment option 'MFP_USE_IRQ_EIC' in mfp_ahb_lite_matrix_config.vh to set other setting use mfp_eic_core.vh
- to enable 'Explicit Vector Offset' option uncomment  'EIC_USE_EXPLICIT_VECTOR_OFFSET' in mfp_eic_core.vh and set 'assign eic_offset = 1'b1;' in m14k_cpz_eicoffset_stub.v
