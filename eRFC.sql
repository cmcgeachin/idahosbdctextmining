-- creates table and sets erfc_id as primary key
CREATE TABLE erfc_data (
	business_status text NOT NULL,
	erfc_date date NOT NULL,
	erfc_notes text NOT NULL,
	erfc_id bigint CONSTRAINT erfc_key PRIMARY KEY,
	search_erfc_text tsvector
);

COPY erfc_data (business_status, erfc_date, erfc_notes, erfc_id)
FROM '/Users/christophermcgeachin/Desktop/idaho_sbdc_session_analysis/erfcchatbot.csv'
WITH (FORMAT CSV, DELIMITER ';', HEADER);

-- Had to change csv encoding to UTF-8 to clear import error. Import successful 444 records added.

ALTER TABLE erfc_data ADD COLUMN specific_assistance text;

-- Using regexp to extract specific assistance from erfcs
-- test
SELECT 
	(regexp_match(erfc_notes, 'assistance:\s(.+)(?:signature:)'))[1]
	erfc_notes
FROM erfc_data;

-- update

UPDATE erfc_data
SET specific_assistance = 
	(regexp_match(erfc_notes, 'assistance:\s(.+)(?:signature:)'))[1]
RETURNING erfc_id, specific_assistance;

-- regexp to extract assitance requested
-- test
SELECT 
	regexp_match(erfc_notes, 'requested:\s(.+)(?:rfcdisclaimer:)')
	erfc_notes
FROM erfc_data;

-- update
UPDATE erfc_data
SET assistance_requested = 
	regexp_match(erfc_notes, 'requested:\s(.+)(?:rfcdisclaimer:)'):: text
RETURNING erfc_id, specific_assistance;

-- Updating and converting specific_assistance to lexemes
UPDATE erfc_data
SET search_erfc_text = to_tsvector('english', specific_assistance);

-- Using lexemes to find customers that specified tax in specific_assistance
SELECT 
	erfc_id,
	specific_assistance,
	assistance_requested,
	search_erfc_text,
	business_status,
	erfc_date
FROM erfc_data
WHERE specific_assistance IS NOT NULL 
	AND char_length(specific_assistance)>5 
	AND search_erfc_text @@ to_tsquery('english', 'tax')
ORDER BY erfc_date;

-- Testing columns for export
SELECT 
	erfc_id,
	specific_assistance,
	assistance_requested,
	search_erfc_text,
	business_status,
	erfc_date
FROM erfc_data
WHERE specific_assistance IS NOT NULL 
	AND char_length(specific_assistance)>5 
ORDER BY erfc_date;

-- Export
COPY (
	SELECT
	erfc_id,
	specific_assistance,
	assistance_requested,
	search_erfc_text,
	business_status,
	erfc_date
FROM erfc_data
WHERE specific_assistance IS NOT NULL 
	AND char_length(specific_assistance)>5 
ORDER BY erfc_date
	)
TO '/Users/christophermcgeachin/Desktop/chatbotdataformatted.csv'
WITH (FORMAT CSV, HEADER);
