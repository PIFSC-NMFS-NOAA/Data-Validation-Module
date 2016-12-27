CREATE OR REPLACE PACKAGE DVM_PKG IS

    TYPE DATA_STREAM_TYP IS TABLE OF DVM_QC_CRITERIA_V%ROWTYPE INDEX BY PLS_INTEGER;
    ALL_CRITERIA DATA_STREAM_TYP;
    v_PK_ID NUMBER;

    v_PTA_ERROR DVM_PTA_ERRORS%ROWTYPE;
    v_data_stream DVM_DATA_STREAMS%ROWTYPE;
    
    
    --Main package procedure that validates a given data stream (p_data_stream_code) record (uniquely identified by p_PK_ID)
    PROCEDURE VALIDATE_PARENT_RECORD (p_data_stream_code IN DVM_DATA_STREAMS.DATA_STREAM_CODE%TYPE, p_PK_ID IN NUMBER);
    
    --package procedure that retrieves a parent error record and returns p_proc_return_code with a code that indicates the result of the operation
    PROCEDURE RETRIEVE_PARENT_ERROR_REC (p_proc_return_code OUT PLS_INTEGER);
    
    --package procedure to retrieve all of the QC criteria based on whether or not the parent record has been validated before:
    PROCEDURE RETRIEVE_QC_CRITERIA (p_first_validation IN BOOLEAN, p_proc_return_code OUT PLS_INTEGER);

    --define all of the error type association records to associate the parent record with all error types that are currently active:
    PROCEDURE DEFINE_ALL_ERROR_TYPE_ASSOC (p_proc_return_code OUT PLS_INTEGER);
    
    --define all of the error type association records to associate the parent record with all error types that are currently active:
    PROCEDURE DEFINE_PARENT_ERROR_REC (p_proc_return_code OUT PLS_INTEGER);

    --associate the new parent error record with the parent record:
    PROCEDURE ASSOC_PARENT_ERROR_REC (p_proc_return_code OUT PLS_INTEGER);

    --evaluate the QC criteria stored in ALL_CRITERIA for the given parent record:
    PROCEDURE EVAL_QC_CRITERIA (p_proc_return_code OUT PLS_INTEGER);

    --validate a specific QC criteria in ALL_CRITERIA in the elements from p_begin_pos to p_end_pos
    PROCEDURE PROCESS_QC_CRITERIA (p_begin_pos IN PLS_INTEGER, p_end_pos IN PLS_INTEGER, p_proc_return_code OUT PLS_INTEGER)


END DVM_PKG;
/



--Main package procedure that validates the parent record and all child records based on the validation rules defined in the database:
CREATE OR REPLACE PACKAGE BODY DVM_PKG IS
    PROCEDURE VALIDATE_PARENT_RECORD (p_data_stream_code IN DVM_DATA_STREAMS.DATA_STREAM_CODE%TYPE, p_PK_ID IN NUMBER) IS
    
        v_temp_SQL CLOB;
        
        v_proc_return_code PLS_INTEGER;
        
        v_continue BOOLEAN;
        
        v_first_validation BOOLEAN;

--        TYPE QC_criteria  IS REF CURSOR;
--        v_qc_cursor    QC_criteria;

--        v_PTA_ERROR_ID DVM_PTA_ERRORS.PTA_ERROR_ID%TYPE;
--        v_PTA_ERROR_CREATE_DATE DVM_PTA_ERRORS.CREATE_DATE%TYPE;

--        ALL_CRITERIA DATA_STREAM_TYP;


    
    BEGIN

        DBMS_OUTPUT.PUT_LINE('Running VALIDATE_PARENT_RECORD('||p_data_stream_code||', '||p_PK_ID||')');


        --initialize the v_continue variable:
        v_continue := true;

        --set the package variables to the parameter values:
        v_PK_ID := p_PK_ID;

        --retrieve the data stream information from the database:
        SELECT * INTO v_data_stream FROM DVM_DATA_STREAMS WHERE DATA_STREAM_CODE = p_data_stream_code;
        
        DBMS_OUTPUT.PUT_LINE('The data stream code "'||p_data_stream_code||'" was found in the database');

        --check if the parent record and PTA error record exist:
        RETRIEVE_PARENT_ERROR_REC (v_proc_return_code);
        
        
/*****        --should also check if the parent record exists at all--      *****/
        


        --check the return code from RETRIEVE_QC_CRITERIA():
        IF (v_proc_return_code = 1) THEN
            --the parent record's PTA error record exists:
            DBMS_OUTPUT.PUT_LINE('The parent record for the data stream code "'||p_data_stream_code||'" and PK: "'||v_PK_ID||'" was found in the database');
            
            --the parent error record already exists, use the data validation criteria was active when the record was first validated:
            v_first_validation := false;
            
        ELSIF (v_proc_return_code = 0) THEN
            --the parent record's PTA error record does not exist:
            DBMS_OUTPUT.PUT_LINE('The parent record for the data stream code "'||p_data_stream_code||'" and PK: "'||v_PK_ID||'" was NOT found in the database');
            
            --the parent error record does not already exist, use the data validation criteria that is currently active:
            v_first_validation := true;
             
            --insert the new parent error record:
            DEFINE_PARENT_ERROR_REC (v_proc_return_code);

            IF (v_proc_return_code = 1) THEN
                --the parent error record was loaded successfully, proceed with the validation process:
            

                DBMS_OUTPUT.PUT_LINE('The parent error record was loaded successfully for the data stream code "'||p_data_stream_code||'" and PK: "'||v_PK_ID||'"');


                ASSOC_PARENT_ERROR_REC (v_proc_return_code);
                
                IF (v_proc_return_code = 1) THEN
                
                    --the parent error record was updated successfully:
                    DBMS_OUTPUT.PUT_LINE('The new parent error record was associated successfully with the parent record for the data stream code "'||p_data_stream_code||'" and PK: "'||v_PK_ID||'"');



                    --insert the error type association records:
                    DEFINE_ALL_ERROR_TYPE_ASSOC (v_proc_return_code);
                    
                    IF (v_proc_return_code = 1) THEN
                        --the association records were loaded successfully:
                        DBMS_OUTPUT.PUT_LINE('The error type association records were loaded successfully for the data stream code "'||p_data_stream_code||'" and PK: "'||v_PK_ID||'"');
                        
                    
                    
                    ELSE
        
                        --the association records were not loaded successfully:
                        DBMS_OUTPUT.PUT_LINE('The error type association records could not be loaded successfully for the data stream code "'||p_data_stream_code||'" and PK: "'||v_PK_ID||'"');
        
                        --do not continue processing the record:
                        v_continue := false;
                    
                    
                    END IF;
                    
                ELSE
                    --the parent error record was not updated successfully:
                    DBMS_OUTPUT.PUT_LINE('The new parent error record could not be associated successfully with the parent record for the data stream code "'||p_data_stream_code||'" and PK: "'||v_PK_ID||'"');
    
                    --do not continue processing the record:
                    v_continue := false;

                
                
                END IF;

            ELSE
                --the parent error record was not loaded successfully:
                DBMS_OUTPUT.PUT_LINE('The parent error record could not be loaded successfully for the data stream code "'||p_data_stream_code||'" and PK: "'||v_PK_ID||'"');

                --do not continue processing the record:
                v_continue := false;
            

            
            END IF;

        ELSE
        
        
            --there was an error:
            DBMS_OUTPUT.PUT_LINE('There was a database error when querying for the data stream code "'||p_data_stream_code||'"');


            --there was a database error, do not continue processing:
            v_continue := false;

        
        END IF;
        
        
        --check if the processing should continue:
        IF v_continue THEN
        
            --retrieve the QC criteria:
            RETRIEVE_QC_CRITERIA (v_first_validation, v_proc_return_code);
            
            --handle error codes:
            IF (v_proc_return_code = 1) THEN
                --the QC criteria records were loaded successfully:







                --evaluate the QC criteria:
                EVAL_QC_CRITERIA (v_proc_return_code);
                







                
                


            ELSE
                --the QC criteria records were not loaded successfully:
                DBMS_OUTPUT.PUT_LINE('The QC validation criteria records were not loaded successfully');

                --do not continue processing the record:
                v_continue := false;


            
            END IF;
            
            
            
            
        
        END IF;
        
        
    
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                --no DVM_PTA_ERRORS record exists for the given parent record:
                DBMS_OUTPUT.PUT_LINE('The data stream code "'||p_data_stream_code||'" was not found in the database');
                
            WHEN OTHERS THEN
             DBMS_OUTPUT.PUT_LINE('The error code is ' || SQLCODE || '- ' || SQLERRM);
    
    END VALIDATE_PARENT_RECORD;


    PROCEDURE RETRIEVE_PARENT_ERROR_REC (p_proc_return_code OUT PLS_INTEGER) IS
  
        v_temp_SQL CLOB;
    
    BEGIN

        DBMS_OUTPUT.PUT_LINE('Running RETRIEVE_PARENT_ERROR_REC()');
    
    
    --query the parent table to check if the PTA_ERROR_ID already exists, if so then re-use that PTA_ERROR_ID otherwise query for all of the active data validation criteria:
        v_temp_SQL := 'SELECT DVM_PTA_ERRORS.* FROM '||v_data_stream.DATA_STREAM_PAR_TABLE||' INNER JOIN DVM_PTA_ERRORS ON ('||v_data_stream.DATA_STREAM_PAR_TABLE||'.PTA_ERROR_ID = DVM_PTA_ERRORS.PTA_ERROR_ID) WHERE '||v_data_stream.DATA_STREAM_PK_FIELD||' = :pkid';
        
        EXECUTE IMMEDIATE v_temp_SQL INTO v_PTA_ERROR USING v_PK_ID;
        
        --set the return code to indicate the parent table record was found:
        p_proc_return_code := 1;
        
    EXCEPTION
    
        WHEN NO_DATA_FOUND THEN
            --no DVM_PTA_ERRORS record exists for the given parent record:
            DBMS_OUTPUT.PUT_LINE('The parent error record for the data stream code "'||v_data_stream.DATA_STREAM_CODE||'" and PK: "'||v_PK_ID||'" was not found in the database');

            --set the return code to indicate the parent table record was not found:
            p_proc_return_code := 0;
    
        WHEN OTHERS THEN
            
            --output database error code and message:
            DBMS_OUTPUT.PUT_LINE('The error code is ' || SQLCODE || '- ' || SQLERRM);
            
            --set the return code to indicate there was an unexpected exception during runtime:
            p_proc_return_code := -1;
    
    END RETRIEVE_PARENT_ERROR_REC;


    --procedure to retrieve all parent error records
    PROCEDURE RETRIEVE_QC_CRITERIA (p_first_validation IN BOOLEAN, p_proc_return_code OUT PLS_INTEGER) IS
  
        v_temp_SQL CLOB;
    
    BEGIN

        DBMS_OUTPUT.PUT_LINE('Running RETRIEVE_QC_CRITERIA()');
    
    
        --check if this is the first time this parent record has been validated:
        IF p_first_validation THEN
            v_temp_SQL := 'SELECT
                   DVM_QC_CRITERIA_V.*
                  FROM DVM_QC_CRITERIA_V
                  WHERE ERR_TYPE_ACTIVE_YN = ''Y''
                  AND QC_OBJ_ACTIVE_YN = ''Y''
                  AND DATA_STREAM_CODE = :DATA_STREAM_CODE
                  ORDER BY QC_SORT_ORDER, ERROR_TYPE_ID';
                  
            EXECUTE IMMEDIATE v_temp_SQL BULK COLLECT INTO ALL_CRITERIA USING v_data_stream.data_stream_code;
        ELSE
        
    
            --return the whole result set so it can be used to process the QC criteria:
            v_temp_SQL := 'SELECT DVM_QC_CRITERIA_V.*
                    FROM DVM_QC_CRITERIA_V
                   INNER JOIN DVM_PTA_ERR_TYP_ASSOC
                   ON DVM_QC_CRITERIA_V.ERROR_TYPE_ID = DVM_PTA_ERR_TYP_ASSOC.ERROR_TYPE_ID
                   WHERE
                   DVM_PTA_ERR_TYP_ASSOC.PTA_ERROR_ID = :ptaeid               
                   AND DATA_STREAM_CODE = :DATA_STREAM_CODE
                   ORDER BY QC_SORT_ORDER, DVM_QC_CRITERIA_V.ERROR_TYPE_ID';            
                
            EXECUTE IMMEDIATE v_temp_SQL BULK COLLECT INTO ALL_CRITERIA USING v_PTA_ERROR.PTA_ERROR_ID, v_data_stream.data_stream_code;
        END IF;        
        
        --the query was successful:
        p_proc_return_code := 1;
        
        
    EXCEPTION
        WHEN OTHERS THEN

            --output database error code and message:
            DBMS_OUTPUT.PUT_LINE('The error code is ' || SQLCODE || '- ' || SQLERRM);
           
            --set the return code to indicate there was an unexpected exception during runtime:
            p_proc_return_code := -1;
    END RETRIEVE_QC_CRITERIA;


    --define all of the error type association records to associate the parent record with all error types that are currently active:
    PROCEDURE DEFINE_ALL_ERROR_TYPE_ASSOC (p_proc_return_code OUT PLS_INTEGER) IS
        v_temp_SQL CLOB;
    
    BEGIN
    
        v_temp_SQL := 'INSERT INTO DVM_PTA_ERR_TYP_ASSOC (PTA_ERROR_ID, ERROR_TYPE_ID, CREATE_DATE) SELECT
               :PTA_ERROR_ID, DVM_QC_CRITERIA_V.ERROR_TYPE_ID, SYSDATE
              FROM DVM_QC_CRITERIA_V
              WHERE ERR_TYPE_ACTIVE_YN = ''Y''
              AND QC_OBJ_ACTIVE_YN = ''Y''
              AND DATA_STREAM_CODE = :DATA_STREAM_CODE';
              
        EXECUTE IMMEDIATE v_temp_SQL USING v_PTA_ERROR.PTA_ERROR_ID, v_data_stream.data_stream_code;
        
        --association records were loaded successfully:
        p_proc_return_code := 1;
        
        
    EXCEPTION
        WHEN OTHERS THEN

            --output database error code and message:
            DBMS_OUTPUT.PUT_LINE('The error code is ' || SQLCODE || '- ' || SQLERRM);

            --association records were not loaded successfully:
            p_proc_return_code := -1;
    
    END DEFINE_ALL_ERROR_TYPE_ASSOC;
    
    
    --define all of the error type association records to associate the parent record with all error types that are currently active:
    PROCEDURE DEFINE_PARENT_ERROR_REC (p_proc_return_code OUT PLS_INTEGER) IS
        v_temp_SQL CLOB;
    
    BEGIN
    
        INSERT INTO DVM_PTA_ERRORS (CREATE_DATE, LAST_EVAL_DATE) VALUES (SYSDATE, SYSDATE) RETURNING PTA_ERROR_ID, CREATE_DATE INTO v_PTA_ERROR.PTA_ERROR_ID, v_PTA_ERROR.CREATE_DATE;

        --parent error record was loaded successfully:
        p_proc_return_code := 1;
        
        
    EXCEPTION
        WHEN OTHERS THEN

            --output database error code and message:
            DBMS_OUTPUT.PUT_LINE('The error code is ' || SQLCODE || '- ' || SQLERRM);

            --parent error record was not loaded successfully:
            p_proc_return_code := -1;
    
    END DEFINE_PARENT_ERROR_REC;
    
    
    --associate the new parent error record with the parent record:
    PROCEDURE ASSOC_PARENT_ERROR_REC (p_proc_return_code OUT PLS_INTEGER) IS
        v_temp_SQL CLOB;
    
    
    BEGIN
    
        DBMS_OUTPUT.PUT_LINE('running ASSOC_PARENT_ERROR_REC ()');
    
        --update the parent record to associate it with the new parent error record:
        v_temp_SQL := 'UPDATE '||v_data_stream.DATA_STREAM_PAR_TABLE||' SET PTA_ERROR_ID = :pta_errid WHERE '||v_data_stream.DATA_STREAM_PK_FIELD||' = :pkid';
        
        DBMS_OUTPUT.PUT_LINE('v_temp_SQL is: '||v_temp_SQL);
        
        
        EXECUTE IMMEDIATE v_temp_SQL USING v_PTA_ERROR.PTA_ERROR_ID, v_PK_ID;
        
        --set the return code to indicate the parent table record was found:
        p_proc_return_code := 1;


    
    EXCEPTION
        WHEN OTHERS THEN

            --output database error code and message:
            DBMS_OUTPUT.PUT_LINE('The error code is ' || SQLCODE || '- ' || SQLERRM);

            --The parent record was not associated with the parent error record successfully:
            p_proc_return_code := -1;
        
    
    END ASSOC_PARENT_ERROR_REC;
    

    --evaluate the QC criteria stored in ALL_CRITERIA for the given parent record:
    PROCEDURE EVAL_QC_CRITERIA (p_proc_return_code OUT PLS_INTEGER) IS 
        
        v_curr_QC_begin_pos PLS_INTEGER;
        
        v_continue BOOLEAN;
        
        v_current_QC_OBJ_ID NUMBER;
        
    
    BEGIN
       
    
        DBMS_OUTPUT.PUT_LINE('running EVAL_QC_CRITERIA ()');

        --initialize the tracking variable for the processing loop:
        v_current_QC_OBJ_ID := NULL;

        --initialize the v_continue variable:
        v_continue := true;


        --loop through the QC criteria to execute each query and process each QC object separately:
        FOR indx IN 1 .. ALL_CRITERIA.COUNT
        LOOP
            IF (v_current_QC_OBJ_ID IS NULL) THEN
                --the QC object ID is NULL, this is the first record in the loop:

                --set the QC object's begin position to 1 since this is the first value to be processed:
                v_curr_QC_begin_pos := 1;
                
                --initialize the v_current_QC_OBJ_ID variable:
                v_current_QC_OBJ_ID := ALL_CRITERIA(indx).QC_OBJ_ID;
            
            ELSIF (v_current_QC_OBJ_ID <> ALL_CRITERIA(indx).QC_OBJ_ID) THEN
                --this is not the same QC object as the previous error type:
                
                
                --process the previous object:
                PROCESS_QC_CRITERIA (v_curr_QC_begin_pos, (indx - 1), v_proc_return_code);
                
                IF (v_proc_return_code = -1) THEN
                
                    --there was an error processing the current QC criteria:
                    
                    DBMS_OUTPUT.PUT_LINE('There was an error when processing the current QC criteria object: '||ALL_CRITERIA.OBJECT_NAME);
                    
                    --set the continue variable to false:
                    v_continue = false;
                    
                    --exit the loop, no additional processing is necessary since there was an error processing the validation criteria:
                    EXIT;
                END IF;
                
                
                
                --initialize the current object:
                
                v_curr_QC_begin_pos := indx;
                
                
                --set the QC_OBJ_ID variable value to the current row's corresponding value:
                v_current_QC_OBJ_ID := ALL_CRITERIA(indx).QC_OBJ_ID;
                
                
            
            END IF;
            




        END LOOP;
        
        
        --process the last QC criteria:
        IF (v_continue) THEN
            
            PROCESS_QC_CRITERIA (v_curr_QC_begin_pos, ALL_CRITERIA.COUNT, v_proc_return_code);
            
            IF (v_proc_return_code = -1) THEN
            
                --there was an error processing the current QC criteria:
                DBMS_OUTPUT.PUT_LINE('There was an error when processing the current QC criteria object: '||ALL_CRITERIA.OBJECT_NAME);
                
                --set the continue variable to false:
                v_continue = false;
                
                --exit the loop, no additional processing is necessary since there was an error processing the validation criteria:
                EXIT;
            END IF;


        
        END IF;
    


    
    EXCEPTION
        WHEN OTHERS THEN
            --output database error code and message:
            DBMS_OUTPUT.PUT_LINE('The error code is ' || SQLCODE || '- ' || SQLERRM);

            --QC criteria was not processed successfully:
            p_proc_return_code := -1;

        
    
    END EVAL_QC_CRITERIA;


    --validate a specific QC criteria in ALL_CRITERIA in the elements from p_begin_pos to p_end_pos
    PROCEDURE PROCESS_QC_CRITERIA (p_begin_pos IN PLS_INTEGER, p_end_pos IN PLS_INTEGER, p_proc_return_code OUT PLS_INTEGER) IS
    
        v_temp_SQL CLOB;
    
    BEGIN
    
        --construct the QC query to be executed:
        v_temp_SQL := 'SELECT * FROM '||ALL_CRITERIA(p_begin_pos).OBJECT_NAME||' WHERE '||ALL_CRITERIA(p_begin_pos).DATA_STREAM_PK_FIELD||' = :pkid';

        EXECUTE IMMEDIATE v_temp_SQL INTO
        
        USING v_PK_ID;
        
        

    
    
    EXCEPTION
        WHEN OTHERS THEN
        
            --output database error code and message:
            DBMS_OUTPUT.PUT_LINE('The error code is ' || SQLCODE || '- ' || SQLERRM);

            --QC criteria was not processed successfully:
            p_proc_return_code := -1;
    
    
    END PROCESS_QC_CRITERIA;

    




END DVM_PKG;
/