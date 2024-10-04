

-- Stored Procedure which checks if the boat is currently on a charter and if it is not it inserts the dates into the CHARTER table
DROP PROCEDURE IF EXISTS `Add_Charter`;

DELIMITER $$

CREATE PROCEDURE Add_Charter (
	IN IN_BOAT_ID INT, 
	IN IN_StartDate DATE, 
	IN IN_EndDate DATE,
	IN IN_CUST_ID INT,
	OUT OUT_RESULT INT,
    OUT MESSAGE VARCHAR(100)
	)
BEGIN
	DECLARE OutputResponse VARCHAR(20) DEFAULT 'available';
	DECLARE temp_start_date DATE;
    DECLARE temp_end_date DATE;
    DECLARE done INT DEFAULT FALSE;
    
    DECLARE charter_temp CURSOR FOR
		SELECT CHARTER_START_DATE, CHARTER_END_DATE
        FROM CHARTER
        WHERE BOAT_ID = IN_BOAT_ID;
        
-- Declare the handler for when there are no more rows to fetch
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
        
	OPEN charter_temp;
    
    start_loop : LOOP
		FETCH charter_temp INTO temp_start_date, temp_end_date;
        IF done THEN
			LEAVE start_loop;
		END IF;
    
		IF IN_EndDate >= temp_start_date AND IN_StartDate <= temp_end_date THEN
			SET OutputResponse = 'unavailable';
			SET OUT_RESULT = -1;
            SET MESSAGE = 'unavailable';
			LEAVE start_loop;
		END IF;
    END LOOP;
    
    CLOSE charter_temp;
    
	IF OutputResponse = 'available' 
	THEN
		INSERT INTO CHARTER (BOAT_ID, CUST_ID, CREW_ID, ITINERARY_ID, WEATHER_ID, CHARTER_START_DATE, CHARTER_END_DATE, CHARTER_RETURN_DATE)
		VALUES (IN_BOAT_ID, IN_CUST_ID, NULL, NULL, NULL, IN_StartDate, IN_EndDate, NULL);
		SET MESSAGE = 'Your charter has been booked!';
        
		SET OUT_RESULT = (SELECT CHARTER_ID FROM CHARTER WHERE BOAT_ID = IN_BOAT_ID AND CHARTER_START_DATE = IN_StartDate);
		
	END IF;
END$$

/*
Test Code for Add_Charter

Make the 2nd date after current date

    CALL Add_Charter(3, '2024-09-30', '2024-10-05', 3, @id, @output);
    SELECT CONCAT('Charter Id: ', @id);
    SELECT @output;
    
Make the 2nd date the current date    
    
    CALL Add_Charter(4, '2024-09-30', '2024-10-2', 6, @id, @output);
    SELECT CONCAT('Charter Id: ', @id);
    SELECT @output;
    
Make the 2nd date before the current date

	CALL Add_Charter(1, '2024-09-30', '2024-10-1', 5, @id, @output);
    SELECT CONCAT('Charter Id: ', @id);
    SELECT @output;

*/	


-- Stored Procedure for returning boat and charging the customer
DROP PROCEDURE IF EXISTS `Return_Charter`;

DELIMITER $$

CREATE PROCEDURE Return_Charter (
	IN IN_CHARTER_ID INT,
	OUT OUT_RESULT VARCHAR(1000)
	)
BEGIN
	DECLARE x_CUST_ID INT;
	DECLARE x_StartDate DATE;
	DECLARE x_EndDate Date;
	DECLARE x_BoatCost DECIMAL;
	DECLARE x_ReturnedAlready DATE;
	DECLARE x_ReturnDate DATE;
	DECLARE x_DaysUsed INT;
	DECLARE x_DaysPastDueDate INT;
	DECLARE x_Charge DECIMAL;
    
	-- This catches for if the wrong charter id was inputted
	DECLARE EXIT HANDLER FOR NOT FOUND
	SET OUT_RESULT = 'No data found for the given charter ID';

	SET x_ReturnDate = CURDATE();
    SET x_ReturnedAlready = NULL;
	
	SELECT A.CUST_ID, A.CHARTER_START_DATE, A.CHARTER_END_DATE, B.BOAT_RENTAL_COST, A.CHARTER_RETURN_DATE
	INTO x_Cust_ID, x_StartDate, x_EndDate, x_BoatCost, x_ReturnedAlready
	FROM CHARTER A
	JOIN BOAT B ON A.BOAT_ID = B.BOAT_ID
	WHERE A.CHARTER_ID = IN_CHARTER_ID;
						

	SET x_DaysUsed = DATEDIFF(x_EndDate, x_StartDate) + 1;

    IF x_ReturnedAlready != NULL
	THEN
		SET OUT_RESULT = 'The boat was not returned';
        
	ELSEIF x_ReturnedAlready IS NULL
	THEN

		IF x_ReturnDate > x_EndDate
		THEN
			SET x_DaysPastDueDate = TRUNCATE(x_ReturnDate - x_EndDate,0);
			SET x_Charge = (x_DaysUsed * x_BoatCost) + (x_DaysPastDueDate * 100);
			SET OUT_RESULT = CONCAT('Your boat has been returned and you have been charged $', CONVERT(x_DaysUsed * x_BoatCost, CHAR), '. There is also a late fee of $', CONVERT(x_DaysPastDueDate * 100, CHAR), '. For a total charge of: $', CONVERT(x_Charge,  CHAR));
		ELSEIF x_ReturnDate < x_EndDate
		THEN
			SET x_DaysPastDueDate = TRUNCATE(x_EndDate - x_ReturnDate,0) + 1;
			SET x_Charge = (x_DaysUsed * x_BoatCost) - (x_DaysPastDueDate * 25);
			SET OUT_RESULT = CONCAT('Your boat has been returned early! The Default cost was: $', CONVERT(x_DaysUsed * x_BoatCost, CHAR), ', but you have received a discount of $', CONVERT(x_DaysPastDueDate * 25, CHAR), '. For a total charge of: $', CONVERT(x_Charge,  CHAR));
		ELSE
			SET x_Charge = (x_DaysUsed * x_BoatCost);
			SET OUT_RESULT = CONCAT('Your boat was returned on time! You have been charged $', CONVERT(x_Charge, CHAR));
		END IF;
		
		UPDATE CUSTOMER
		SET CUST_BALANCE = CUST_BALANCE + x_Charge
		WHERE CUST_ID = x_CUST_ID;
		
		UPDATE CHARTER
		SET CHARTER_RETURN_DATE = x_ReturnDate
		WHERE CHARTER_ID = IN_CHARTER_ID;
	END IF;	
	
END $$



/*
Test Code for Return_Charter

Shows Early Return
    
    CALL RETURN_CHARTER(9 , @output);
    SELECT @output;
    
Shows On Time Return    
    
    CALL RETURN_CHARTER(10 , @output);
    SELECT @output;
    
Shows Late Return    
    
    CALL RETURN_CHARTER(11 , @output);
    SELECT @output;
    


*/


-- Stored procedure to add a new customer into the database. It also returns the CUST_ID
DROP PROCEDURE IF EXISTS `Add_Customer`;

DELIMITER $$

CREATE PROCEDURE Add_Customer (
	IN IN_CUST_FNAME VARCHAR(20),
	IN IN_CUST_LNAME VARCHAR(20),
	IN IN_CUST_EMAIL VARCHAR(50),
    OUT OUT_RESULT VARCHAR(100)
	)
BEGIN
DECLARE x_CUST_EMAIL VARCHAR(100) DEFAULT 'Currently Available';
DECLARE	x_CUST_ID INT;

SET OUT_RESULT = '';

	SELECT CUST_EMAIL
	INTO x_CUST_EMAIL
	FROM CUSTOMER
	WHERE CUST_EMAIL = IN_CUST_EMAIL;
	
        
	IF x_CUST_EMAIL = IN_CUST_EMAIL
	THEN
		SET OUT_RESULT = 'This email is currently being used. ';
	ELSE
		INSERT INTO CUSTOMER (CUST_FNAME, CUST_LNAME, CUST_EMAIL, CUST_BALANCE) VALUES (IN_CUST_FNAME, IN_CUST_LNAME, IN_CUST_EMAIL, 0.00);
	END IF;
		
		SELECT CUST_ID
		INTO x_CUST_ID
		FROM CUSTOMER
		WHERE CUST_EMAIL = IN_CUST_EMAIL;
		
	SET OUT_RESULT = CONCAT(OUT_RESULT, 'Your Customer ID is: ', CONVERT(x_CUST_ID, CHAR));
		
END$$




/*
Test Code for Add_Customer

This should be return the Customer ID

    CALL Add_Customer('Jonathan', 'Locke', 'John.Locke@gmail.com', @output);
    SELECT @output;
    
This should go through   
   
    CALL Add_Customer('Boone', 'Rutherford', 'Boone.Rutherford@gmail.com', @output);
	SELECT @output;
    
/    

*/