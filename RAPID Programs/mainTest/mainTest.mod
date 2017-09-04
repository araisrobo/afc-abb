MODULE mainTest
    VAR intnum sig1int; ! TODO: test EVENT_STOP
    
    VAR iodev commLog;
    VAR socketdev ags_socket;
    ! CONST string IPAddress:="10.1.2.2";  ! pi16
    CONST string IPAddress:="10.1.1.180";  ! interlaken
    CONST num PortNum:=6000;
    VAR num Call_NB_temp:=0;
    VAR num run_cycle:=0;
    VAR string str_buf;
    VAR dnum ags_stat;  ! 32-bit AGS status signals
    
    VAR string model;
    VAR string utilsFile;
    VAR string process;
    VAR string filePath;
    VAR string fileName;
    VAR string proc_loadFiles;
    VAR string proc_unloadFiles;
    VAR string proc_gotoBegin;
    VAR string proc_grind;
    VAR string proc_finish;
    
    PROC main()
        server_recovery;
        Open "HOME:" \File:= "socketComm.log", commLog \Write;
        Write commLog, "PC(Master) connected...";

        model:="ac20";
        utilsFile:="a_utils";
        process:="utils";

        filePath:="HOME/Program/" + model;
        fileName:=utilsFile + ".mod";

        proc_loadFiles:= process + ":loadFiles";
        proc_unloadFiles:= process + ":unloadFiles";
        proc_gotoBegin:= process + ":gotoBegin";
        proc_grind:= process + ":grind";
        proc_finish:= process + ":finish";
        
        Load \Dynamic, filePath\File:=fileName;
        %proc_loadFiles%;
        %proc_gotoBegin%;
        %proc_grind%;
        %proc_finish%;
        %proc_unloadFiles%;
        UnLoad filePath\File:=fileName;
    ENDPROC
    
    TRAP stop_routine
        TPWrite ("EVENT_STOP");
    ENDTRAP
 
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
