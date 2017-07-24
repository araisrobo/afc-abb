MODULE afcTest
   
    VAR iodev commLog;
    VAR socketdev ags_socket;
    CONST string IPAddress:="10.1.1.20";  ! pi13
    CONST num PortNum:=6000;
    VAR num Call_NB_temp:=0;
    VAR string str_buf;
    VAR dnum ags_stat;  ! 32-bit AGS status signals
      
    PROC main()
        server_recovery; ! init socket communication

        ! Reset ROBOT_STAT before starting motion program
        SocketSend ags_socket\Str:="A021280"; ! set_dout(128,0) ROBOT_RUN
        SocketSend ags_socket\Str:="A021300"; ! set_dout(130,0) WORK_EXCHANGE_REQ
        SocketSend ags_socket\Str:="A021310"; ! set_dout(131,0) PROG_CHANGE_ACK(0)
        
        SocketSend ags_socket\Str:="A020321"; ! set_dout(32,x)
        ! SocketSend ags_socket\Str:="A020331"; ! set_dout(33,x)
        
        ! force AFC off: M103 P0 ...
        !                           CMD012345678901234567890123456
        !                              PQQQQQQRSSSSSSJJJJJJKKKKKLL
        SocketSend ags_socket\Str:="A03000060000000000000000000001"; ! M103 P0 Q230 R0 S0 J0 K0 L-1
        ! SocketSend ags_socket\Str:="A03100095000000000000000000001"; ! M103 P1 Q950 R0 S0 J0 K0 L1
        
    ENDPROC
 
    PROC server_recovery()
        VAR num retry_no:=0;
        VAR socketstatus state;
        state:=SocketGetStatus(ags_socket);
        IF state<>SOCKET_CONNECTED THEN
            TPWrite "PC(Master) close, try to reconnect...";
            IF state<>SOCKET_CREATED THEN
                SocketCreate ags_socket;
                SocketConnect ags_socket,IPAddress,PortNum\Time:=2;
                TPWrite "PC(Master) connected...";
                WaitTime 0.3;
            ENDIF
        ENDIF
        
        TPWrite "PC(Master) connected...";
        WaitTime 0.1;

    ERROR
        IF ERRNO=ERR_SOCK_TIMEOUT THEN
            IF retry_no<5 THEN
                WaitTime 1;
                retry_no:=retry_no+1;
                RETRY;
            ELSE
                TPWrite "PC(Master) close, try to reconnect...retry_no:5 so con't connect";
                RAISE ;
            ENDIF
        ELSEIF ERRNO=ERR_SOCK_CLOSED THEN
            ResetRetryCount;
            RETURN ;
        ELSEIF errno=ERR_REFUNKPRC THEN
            IF Call_NB_temp>4 THEN
                TPWrite "Error in Call NB Can no selce proc name or PC sent str errow ";
            ENDIF
            TPWrite "Rum_NB error. need proc name or pc str";
            waittime 5;
            Call_NB_temp:=Call_NB_temp+1;
        ENDIF
        RETURN ;
    ENDPROC

    FUNC dnum get_din(num n)
        VAR dnum dinp;
        VAR bool ok;
        SocketSend ags_socket \Str:="A04 "+NumToStr(n, 0); ! get_din(port[n]), each port is with 32-bits of data
        SocketReceive ags_socket \Str:=str_buf \ReadNoOfBytes:=8;
        str_buf := HexToDec(str_buf);
        ok := StrToVal(str_buf, dinp);
        IF ok THEN
            RETURN dinp;
        ELSE
            TPWrite "SocketComm ERROR: Cannot convert " + str_buf + " to VAR";
            RETURN 0xFFFFFFFF;
        ENDIF
    ENDFUNC
    
    FUNC string get_text(num n)
        VAR num len;
        VAR bool ok;
        
        Write commLog, "get_text: begin...";
         ! 0 <= n < 10, there is a SPACE right after "A05"
        SocketSend ags_socket \Str:="A05 "+NumToStr(n, 0); ! get_text(id)
        SocketReceive ags_socket \Str:=str_buf \ReadNoOfBytes:=2;  ! get text length
        ok := StrToVal(str_buf, len);
        IF ok THEN
            Write commLog, "get_text: str_buf:" + str_buf + " len:" \Num:=len;
            SocketReceive ags_socket \Str:=str_buf \ReadNoOfBytes:=len;  ! get text
            RETURN str_buf;
        ELSE
            TPWrite "SocketComm ERROR: Cannot convert " + str_buf + " to Num";
            RETURN "ERROR get_text()";
        ENDIF
    ENDFUNC
    
ENDMODULE
