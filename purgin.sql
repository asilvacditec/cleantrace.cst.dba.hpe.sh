

BEGIN
  DBMS_AUDIT_MGMT.INIT_CLEANUP(
    AUDIT_TRAIL_TYPE         => DBMS_AUDIT_MGMT.AUDIT_TRAIL_ALL,
    DEFAULT_CLEANUP_INTERVAL => 1 /* HOURS */);
END;
/


BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    JOB_NAME        => 'AUDIT_LAST_ARCHIVE_TIME',
    JOB_TYPE        => 'PLSQL_BLOCK',
    JOB_ACTION      => 'BEGIN 
                          DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(DBMS_AUDIT_MGMT.AUDIT_TRAIL_AUD_STD, SYSTIMESTAMP-1/24);
                          DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(DBMS_AUDIT_MGMT.AUDIT_TRAIL_FGA_STD, SYSTIMESTAMP-1/24);
                        END;',
    START_DATE      => SYSTIMESTAMP,
    REPEAT_INTERVAL => 'FREQ=MINUTELY; BYHOUR=0; BYMINUTE=0; BYSECOND=0;',
    END_DATE        => NULL,
    ENABLED         => TRUE,
    COMMENTS        => 'AUTOMATICALLY SET AUDIT LAST ARCHIVE TIME.');
END;
/


BEGIN
  DBMS_AUDIT_MGMT.CREATE_PURGE_JOB(
    AUDIT_TRAIL_TYPE           => DBMS_AUDIT_MGMT.AUDIT_TRAIL_ALL,
    AUDIT_TRAIL_PURGE_INTERVAL => 1 /* HOURS */,  
    AUDIT_TRAIL_PURGE_NAME     => 'PURGE_ALL_AUDIT_TRAILS',
    USE_LAST_ARCH_TIMESTAMP    => TRUE);
END;
/

