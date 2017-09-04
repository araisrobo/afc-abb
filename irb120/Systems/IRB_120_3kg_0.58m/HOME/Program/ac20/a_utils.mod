MODULE utils

    ! for simulation:
    PERS wobjdata Workobject_1 := [FALSE,TRUE,"",[[398.934,36.477,307.64],[1,0,0,0]],[[0,0,0],[1,0,0,0]]];
    
    ! for real machine:
    ! PERS wobjdata Workobject_1 := [FALSE,TRUE,"",[[591.659,-166.943,423.004],[0.5,-0.5,-0.5,0.5]],[[0,0,0],[1,0,0,0]]];
    
    ! common variables:
    PERS tooldata AGS01Tool := [TRUE,[[154.8,0,62],[4.32963728535968E-17,-0.707106781186547,-4.32963728535968E-17,-0.707106781186548]],[3,[0,0,0.01],[1,0,0,0],0,0,0]];
!    PERS tooldata TCORNER := [TRUE,[[154.8,0,42],[0,-0.707106781,0,-0.707106781]],[3,[0,0,0.00001],[1,0,0,0],0,0,0]];
!    PERS tooldata AGS01TCP := [TRUE,[[154.8,0,42],[0,-0.707106781,0,-0.707106781]],[3,[0,0,0.00001],[1,0,0,0],0,0,0]];
!    PERS tooldata FaceTCP := [TRUE,[[154.8,0,42],[0,-0.707106781,0,-0.707106781]],[3,[0,0,0.00001],[1,0,0,0],0,0,0]];
    
    VAR speeddata vLinear := [110,90,5000,50];
    VAR speeddata vLinear1 := [110,90,5000,50];
    VAR speeddata vLinear2 := [110,90,5000,50];
    VAR speeddata vAngular := [5,72,5000,50];
    VAR speeddata vAngular1 := [5,72,5000,50];
    VAR speeddata vTraverse := [110,400,5000,50]; ! for internal use, same as vLinear
    VAR speeddata vTraverse1 := [150,400,5000,50]; ! for begin and end

! [[5.87495484961249, -209.948929822206, 55.199974607377],[0, 0.88684753706352, 0.462062166817809, 0],[-1, 0, -2, 0],[9E9,9E9,9E9,9E9,9E9,9E9]]
! [[28.7649944287146, -157.602285441643, 55.199974607377],[0, 0.88684753706352, 0.462062166817809, 0],[-1, 1, -2, 0],[9E9,9E9,9E9,9E9,9E9,9E9]]
    CONST robtarget B_Begin:=[[5.87495484961249, -209.948929822206, 55.199974607377],[0, 0.88684753706352, 0.462062166817809, 0],[-1, 0, -2, 0],[9E9,9E9,9E9,9E9,9E9,9E9]];
    CONST robtarget B_End:=[[28.7649944287146, -157.602285441643, 55.199974607377],[0, 0.88684753706352, 0.462062166817809, 0],[-1, 1, -2, 0],[9E9,9E9,9E9,9E9,9E9,9E9]];
       
    VAR intnum job_count; 

    PROC initParams()
        ! TODO: set wobj, tcp, ... here ...
        job_count := 0;
    ENDPROC

    PROC loadFiles()
        initParams;
        Load \Dynamic, filePath\File:="a_ac20.mod";
        Load \Dynamic, filePath\File:="a_TargetDef.mod";
    ENDPROC

    PROC unloadFiles()
        UnLoad filePath\File:="a_ac20.mod";
        UnLoad filePath\File:="a_TargetDef.mod";
    ENDPROC

    PROC gotoBegin()
        ConfJ \On;
        MoveJ B_Begin, v500, fine, AGS01Tool \wobj:=Workobject_1 ;
        ConfJ \Off;
    ENDPROC

    PROC grind()
        %"ac20:surface"%;
    ENDPROC
    
    PROC finish()
!        finishReal;     ! for Real Robot
        finishSim;    ! for Simulation
    ENDPROC

    PROC finishSim()
        ConfJ \On;
        MoveJ B_End,v500,z5,AGS01Tool\WObj:=Workobject_1;
        MoveJ B_Begin, v500, fine, AGS01Tool \wobj:=Workobject_1 ;
        job_count := job_count + 1;
        Write commLog, "JOB: "\Num:=job_count;
        ConfJ \Off;
    ENDPROC

    PROC finishReal()
        ConfJ\On;
        
        ! do motion; move robot to start point
        MoveJ B_End,v500,z5,AGS01Tool\WObj:=Workobject_1;
        
        ! request for WorkExchange
        SocketSend ags_socket\Str:="A021301"; ! set_dout(130,1) WORK_EXCHANGE_REQ
        
        MoveJ B_Begin, v500, fine, AGS01Tool \wobj:=Workobject_1 ;

        
        !                           CMD012345678901234567890123456
        !                              PQQQQQQRSSSSSSJJJJJJKKKKKLL
        SocketSend ags_socket\Str:="A03000060000000000000000000001"; ! M103 P0 Q230 R0 S0 J0 K0 L-1
        
        ! wait until AGS_STAT.WORK_EXCHANGE_ACK bit is set to 1
        ags_stat := get_din(4); ! get 32-bit of AGS_STAT signals
        ! Write commLog, "wait for WORK_EXCHANGE_ACK, ags_stat: " \Dnum:=ags_stat;
        WHILE (BitAndDnum(ags_stat, 0x00000005) <> 0x00000005) DO
            ags_stat := get_din(4); ! get 32-bit of AGS_STAT signals
        ENDWHILE
        
        job_count := job_count + 1;
        TPWrite "JOB: "\Num:=job_count;
        ! reset WORK_EXCHANGE_REQ
        SocketSend ags_socket\Str:="A021300"; ! set_dout(130,0) WORK_EXCHANGE_REQ
        
        ConfL\Off;
        ConfJ\Off;
    ENDPROC

ENDMODULE
