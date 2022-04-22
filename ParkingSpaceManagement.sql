-- Entire Code

set serveroutput on;

--drop table NYC_Parking_Lot;
-- Create table if exists
begin
    execute immediate (
        'create table NYC_Parking_Lot(
            parking_space_id number primary key,
            parking_space_status varchar(20) default ''A'',
            parked_car_color varchar(50),
            parked_car_reg_number varchar(50) constraint nyc_car_uk unique,
            check_in_dt timestamp,
            check_out_dt timestamp)');
    dbms_output.put_line('Table created');

exception
    when others then
      if sqlcode = -955 then
        dbms_output.put_line('Table already exists');
      else
         raise;
      end if;
end; 
/

-- Insert values for parking space ID

declare
v_cnt number;
begin
    select count(*) into v_cnt from NYC_Parking_Lot;
    if v_cnt = 0 then
        for i in 1..15 loop
            insert into NYC_Parking_Lot(parking_space_id) values(i);
        end loop;
        commit;
        dbms_output.put_line('Values inserted');
    else 
        dbms_output.put_line('Cannot insert values, clear table and insert again. (Count Exceeded 15');
    end if;
end;
/
-- create store procedure to display empty parking lots

create or replace procedure get_empty_parking_space_number
is
    v_checkCount number;
    v_parkingId nyc_parking_lot.parking_space_id%TYPE;
    v_parking_space_status nyc_parking_lot.parking_space_status%TYPE;

    cursor c_checkLot is select parking_space_id, parking_space_status from NYC_Parking_Lot;
begin
    v_checkCount := 0;
    dbms_output.put_line('Available slots IDs are: ');
    open c_checkLot;
        loop
            fetch c_checkLot into v_parkingId, v_parking_space_status;
            exit when c_checkLot%notfound; 
            if v_parking_space_status = 'A' then
                dbms_output.put_line(v_parkingId);
                v_checkCount := 1;
            end if;
        end loop;
    close c_checkLot;
    if v_checkCount = 0 then
        dbms_output.put_line('Sorry, no parking slots available for you!');
    end if;
end;
/

--exec get_empty_parking_space_number();

-- create stored procedure to check-in to parking lot

create or replace procedure Checkin_Parking_Space(in_parked_car_color in nyc_parking_lot.parked_car_color%TYPE,
                                                  in_parked_car_reg_number in nyc_parking_lot.parked_car_reg_number%TYPE,
                                                  in_check_in_dt in char,
                                                  in_parking_space_id in out varchar)
is
v_lotIDError number;
v_orig_parking_status nyc_parking_lot.parking_space_status%TYPE;
v_parkingID number;
v_carExists number;
v_check_in_dt char(50);

e_carExists exception;
e_reg_number exception;
e_orig_parking_status exception;
e_lotIDError exception;
begin
    if length(in_parked_car_reg_number) is null then raise e_reg_number; end if;
    select count(*) into v_carExists from nyc_parking_lot where parked_car_reg_number = in_parked_car_reg_number;
    if v_carExists > 0 then
        raise e_carExists;
    end if;
    
    if length(to_char(in_parking_space_id)) is null then 
        select min(parking_space_id) into v_parkingID from nyc_parking_lot where parking_space_status = 'A';
    else
        v_parkingID := in_parking_space_id;
    end if;
    
    select count(*) into v_lotIDError from nyc_parking_lot where parking_space_id = v_parkingID;
    if v_lotIDError = 0 then
        raise e_lotIDError;
    end if;
    
    select parking_space_status into v_orig_parking_status from nyc_parking_lot where parking_space_id = v_parkingID;
    if v_orig_parking_status != 'A' then
        raise e_orig_parking_status;
    end if;
    
    if length(in_check_in_dt) is null then
        v_check_in_dt := to_char(systimestamp, 'DD-Mon-YYYY HH12:MI:SS');
    else
        v_check_in_dt := in_check_in_dt;
    end if;
    
    update nyc_parking_lot set parked_car_color = upper(in_parked_car_color), 
                               parked_car_reg_number = upper(in_parked_car_reg_number),
                               check_in_dt = to_timestamp(v_check_in_dt, 'DD-Mon-YYYY HH24:MI:SS.FF'),
                               check_out_dt = null,
                               parking_space_status = 'O'
                            where parking_space_id = v_parkingID;
    commit;
    in_parking_space_id := v_parkingID;                           
    
exception 
    when e_carExists then dbms_output.put_line('Car number already exists, please check!'); 
        in_parking_space_id := 200;
    when e_reg_number then dbms_output.put_line('Please do not leave car registration number blank!'); 
        in_parking_space_id := 200;
    when no_data_found then dbms_output.put_line('Please do not have null data input'); 
        in_parking_space_id := 200;
    when e_lotIDError then dbms_output.put_line('Either invalid ID entered, or no spots available for you at the moment'); 
        in_parking_space_id := 200;
    when e_orig_parking_status then dbms_output.put_line('Selected parking space ID is already occupied, please check status again and try checking in with different ID'); 
        in_parking_space_id := 200;
    when others then raise; in_parking_space_id := 200;
    rollback;
end;
/

-- create check-out stored procedure
create or replace procedure Check_Out_Parking_Lot (in_parked_car_reg_number nyc_parking_lot.parked_car_reg_number%TYPE, in_check_out_dt char)
is
v_nosuchcar number;
v_check_out_dt char(50);
v_carAlreadychecked number;

e_carAlreadychecked exception;
e_carnumbernull exception;
e_nosuchcar exception;
begin
    if length(to_char(in_parked_car_reg_number)) is null then
        raise e_carnumbernull;
    end if;
    
    select count(*) into v_nosuchcar from nyc_parking_lot where parked_car_reg_number = in_parked_car_reg_number;
    if v_nosuchcar = 0 then
        raise e_nosuchcar;
    end if;
    
    select count(*) into v_carAlreadychecked from nyc_parking_lot where parked_car_reg_number = in_parked_car_reg_number and parking_space_status = 'A';
    if v_carAlreadychecked != 0 then
        raise e_carAlreadychecked;
    end if;
    
    if length(in_check_out_dt) is null then
        v_check_out_dt := to_char(systimestamp, 'DD-Mon-YYYY HH24:MI:SS.FF');
    else
        v_check_out_dt := in_check_out_dt;
    end if;
    
    update nyc_parking_lot set check_out_dt = to_timestamp(v_check_out_dt, 'DD-Mon-YYYY HH24:MI:SS.FF'),
                               parking_space_status = 'A'
                            where parked_car_reg_number = in_parked_car_reg_number; 
    commit;
    dbms_output.put_line('Your car has been checked out, thanks for using our parking lot!');
    
exception
    when e_carAlreadychecked then dbms_output.put_line('Sorry you have already checked your car out');
    when e_carnumbernull then dbms_output.put_line('Please do not leave car reg number null, it is a req field!');
    when e_nosuchcar then dbms_output.put_line('Sorry, no such car exists in our lot!');
    when others then dbms_output.put_line('Contact sys admin!');
    rollback;
end;
/

-- check available spots

exec get_empty_parking_space_number();

--test cases
---- 1) Insert given data

--A) Checkin_Parking_Space: RED, UBX987, 1-JAN-2022, 14
declare
x varchar(20);
begin
    x := 14;
    Checkin_Parking_Space('RED', 'UBX987', '1-JAN-2022', x);
    if x = 200 then
        dbms_output.put_line('Sorry, try again!');
    else
        dbms_output.put_line('Checked into parking space number '|| x);
    end if;
end;
/

--B) Checkin_Parking_Space: WHITE, ZZX954, 1-JAN-2022, NULL
declare
x varchar(20);
begin
    x := null;
    Checkin_Parking_Space('WHITE', 'ZZX954', '1-JAN-2022', x);
    if x = 200 then
        dbms_output.put_line('Sorry, try again!');
    else
        dbms_output.put_line('Checked into parking space number '|| x);
    end if;
end;
/

--C) Checkin_Parking_Space: YELLOW, UEX982, 1-JAN-2022, NULL
declare
x varchar(20);
begin
    x := null;
    Checkin_Parking_Space('YELLOW', 'UEX982', '1-JAN-2022', x);
    if x = 200 then
        dbms_output.put_line('Sorry, try again!');
    else
        dbms_output.put_line('Checked into parking space number '|| x);
    end if;
end;
/

--D) Checkin_Parking_Space: BLUE, AAX983, 2-JAN-2022, NULL
declare
x varchar(20);
begin
    x := null;
    Checkin_Parking_Space('BLUE', 'AAX983', '2-JAN-2022', x);
    if x = 200 then
        dbms_output.put_line('Sorry, try again!');
    else
        dbms_output.put_line('Checked into parking space number '|| x);
    end if;
end;
/

--E) Checkin_Parking_Space: RED, BBX987, 3-JAN-2022, NULL
declare
x varchar(20);
begin
    x := null;
    Checkin_Parking_Space('RED', 'BBX987', '3-JAN-2022', x);
    if x = 200 then
        dbms_output.put_line('Sorry, try again!');
    else
        dbms_output.put_line('Checked into parking space number '|| x);
    end if;
end;
/

--F) Checkin_Parking_Space: RED, CCX585, 4-JAN-2022, 14 (Should throw error as already occupied)
declare
x varchar(20);
begin
    x := 14;
    Checkin_Parking_Space('RED', 'CCX585', '4-JAN-2022', x);
    if x = 200 then
        dbms_output.put_line('Sorry, try again!');
    else
        dbms_output.put_line('Checked into parking space number '|| x);
    end if;
end;
/

--G) Checkin_Parking_Space: WHITE, CCX585, 4-JAN-2022, 13
declare
x varchar(20);
begin
    x := 13;
    Checkin_Parking_Space('WHITE', 'CCX585', '4-JAN-2022', x);
    if x = 200 then
        dbms_output.put_line('Sorry, try again!');
    else
        dbms_output.put_line('Checked into parking space number '|| x);
    end if;
end;
/

--H) Checkin_Parking_Space: YELLOW, CCX585, 4-JAN-2022, 15
declare
x varchar(20);
begin
    x := 15;
    Checkin_Parking_Space('YELLOW', 'CCX585', '4-JAN-2022', x);
    if x = 200 then
        dbms_output.put_line('Sorry, try again!');
    else
        dbms_output.put_line('Checked into parking space number '|| x);
    end if;
end;
/

--I) Checkin_Parking_Space: BLUE, CCX585, 4-JAN-2022, 11
declare
x varchar(20);
begin
    x := 11;
    Checkin_Parking_Space('BLUE', 'CCX585', '4-JAN-2022', x);
    if x = 200 then
        dbms_output.put_line('Sorry, try again!');
    else
        dbms_output.put_line('Checked into parking space number '|| x);
    end if;
end;
/

--J) Checkin_Parking_Space: WHITE, CCX585, 4-JAN-2022, 12
declare
x varchar(20);
begin
    x := 12;
    Checkin_Parking_Space('WHITE', 'CCX585', '4-JAN-2022', x);
    if x = 200 then
        dbms_output.put_line('Sorry, try again!');
    else
        dbms_output.put_line('Checked into parking space number '|| x);
    end if;
end;
/

-- check available spots

exec get_empty_parking_space_number();


-- Test cases for check out

select * from nyc_parking_lot where parked_car_color = 'WHITE';

exec Check_Out_Parking_Lot('ZZX954', '');
exec Check_Out_Parking_Lot('CCX585', '');

select * from nyc_parking_lot where parked_car_color = 'WHITE';


