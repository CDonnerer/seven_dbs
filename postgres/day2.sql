INSERT INTO events (title, starts, ends, venue_id)
VALUES 
    ('Moby', '2018-02-06 21:00', '2018-02-06 23:00', (
        SELECT venue_id
        FROM venues
        WHERE name = 'Crystal Ballroom'
    ) 
);

INSERT INTO events (title, starts, ends, venue_id)
VALUES 
    ('Wedding', '2018-02-06 21:00', '2018-02-06 23:00', (
        SELECT venue_id
        FROM venues
        WHERE name = 'Crystal Ballroom'
    )),
    ('Valentine''s day', '2018-02-14 00:00', '2018-02-14 23:59', NULL)
;

SELECT count(title)
FROM events
WHERE title LIKE '%Day%';

SELECT min(starts), max(ends)
FROM events
INNER JOIN venues
ON events.venue_id = venues.venue_id
WHERE venues.name = 'Crystal Ballroom';  

SELECT venue_id, count(*)
FROM events
GROUP BY venue_id
HAVING count(*) >= 2 
AND venue_id IS NOT NULL;

SELECT venue_id
FROM events
GROUP BY venue_id;

SELECT title, count(*)
OVER (PARTITION BY venue_id)
FROM events;

BEGIN TRANSACTION;
    DELETE FROM events;
ROLLBACK;
SELECT * FROM events;

CREATE OR REPLACE FUNCTION add_event(
    title text,
    starts timestamp,
    ends timestamp,
    venue text,
    postal varchar(9),
    country char(2)
)
RETURNS boolean AS $$
DECLARE
    did_insert boolean := false;
    found_count integer;
    the_venue_id integer;
BEGIN
    SELECT venue_id INTO the_venue_id
    FROM venues v
    WHERE v.postal_code = postal
    AND v.country_code = country
    AND v.name ILIKE venue
    LIMIT 1;
    IF the_venue_id IS NULL THEN
        INSERT INTO venues (name, postal_code, country_code)
        VALUES (venue, postal, country)
        RETURNING venue_id INTO the_venue_id;
        did_insert := true;
    END IF;

    RAISE NOTICE 'Venue found %', the_venue_id;

    INSERT INTO events (title, starts, ends, venue_id)
    VALUES (title, starts, ends, the_venue_id);

    RETURN did_insert;
END;
$$ LANGUAGE plpgsql;

SELECT add_event(
    'House Party', '2018-05-03 23:00', '2018-05-04 02:00', 
    'Run''s House', '97206', 'us'
);

CREATE TABLE logs (
    event_id integer,
    old_title varchar(255),
    old_starts timestamp,
    old_ends timestamp,
    logged_at timestamp DEFAULT current_timestamp
);

CREATE OR REPLACE FUNCTION log_event() 
RETURNS trigger AS $$
DECLARE
BEGIN
    INSERT INTO logs (event_id, old_title, old_starts, old_ends)
    VALUES (OLD.event_id, OLD.title, OLD.starts, OLD.ends);
    RAISE NOTICE 'Someone just changed event #%', OLD.event_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_events
AFTER UPDATE ON events
FOR EACH ROW EXECUTE PROCEDURE log_event();

UPDATE events
SET ends='2018-05-04 01:00:00'
WHERE title='House Party';

CREATE VIEW holidays AS
SELECT 
    event_id AS holiday_id,
    title AS name,
    starts AS date
FROM events
WHERE title LIKE '%Day%'
AND venue_id IS NULL;

SELECT
    name,
    to_char(date, 'Month DD, YYYY') AS date
FROM holidays;

ALTER TABLE events
ADD colors text ARRAY;

CREATE OR REPLACE VIEW holidays AS (
    SELECT
        event_id AS holiday_id,
        title AS name,
        starts AS date,
        colors
    FROM
        events
    WHERE
        title LIKE '%Day%' AND venue_id IS NULL
);

EXPLAIN VERBOSE
    SELECT *
    FROM holidays;

CREATE RULE update_holidays AS ON UPDATE TO holidays DO INSTEAD (
    UPDATE events
    SET
        title = NEW.name,
        starts = NEW.date,
        colors = NEW.colors
    WHERE
        title = OLD.name
);

UPDATE holidays
SET colors = '{"red", "green"}'
WHERE name = 'April Fools Day';

SELECT
    extract(year from starts) AS year,
    extract(month from starts) AS month,
    count(*)
FROM events
GROUP BY year, month
ORDER BY year, month;

CREATE TEMPORARY TABLE month_count(
    month int
);

INSERT INTO month_count
VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12);

CREATE EXTENSION tablefunc;

SELECT * FROM crosstab(
    'SELECT
        extract(year from starts) AS year,
        extract(month from starts) AS month,
        count(*)
    FROM events
    GROUP BY year, month
    ORDER BY year, month',
    'SELECT * FROM month_count'
) AS (
    year int,
    jan int, feb int, mar int, apr int, may int, jun int,
    jul int, aug int, sep int, oct int, nov int, dec int
) ORDER BY year;
