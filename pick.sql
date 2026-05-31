.mode csv
.headers on

CREATE TABLE IF NOT EXISTS toothpastes (
    id INTEGER,
    brand_string TEXT,
	tube_mass_g INTEGER,
	rating INTEGER
);

INSERT INTO toothpastes (id, brand_string, tube_mass_g,rating) VALUES (0,'RANDOM TOOTHPASTE 1', 100, 100);
INSERT INTO toothpastes (id, brand_string, tube_mass_g,rating) VALUES (1,'RANDOM TOOTHPASTE 2', 100, 100);
INSERT INTO toothpastes (id, brand_string, tube_mass_g,rating) VALUES (2,'RANDOM TOOTHPASTE 3', 100, 100);
INSERT INTO toothpastes (id, brand_string, tube_mass_g,rating) VALUES (3,'RANDOM TOOTHPASTE 4', 100, 100);
INSERT INTO toothpastes (id, brand_string, tube_mass_g,rating) VALUES (4,'Nothing', 0, 0);

.output toothpastes.csv
SELECT * FROM toothpastes;

CREATE TABLE IF NOT EXISTS picks (
	 username TEXT, 
	 pick_type TEXT, 
	 new_pick_flag INTEGER,
	 new_toothbrush_flag INTEGER,
	 new_dentist_visit INTEGER,
	 toothpaste_brand TEXT,
	 tube_mass_g INTEGER,
	 toothpaste_rating INTEGER,
	 toothpaste_index INTEGER,
	 total_toothpastes INTEGER, 
	 toothpaste_type TEXT,
	 dental_formula TEXT,
	 day_of_the_week TEXT,
	 day_counter INTEGER,
	 total_picks INTEGER,
	 last_pick_time INTEGER,
	 wasted_tubes_report TEXT,
	 toothpastes_file_path TEXT,
	 meme_payload TEXT
);

.import --csv --skip 1 picks.csv picks


SELECT * FROM toothpastes WHERE id=mod((SELECT CAST(unixepoch('now') / 86400 AS INTEGER)), (SELECT COUNT(*) FROM toothpastes)) LIMIT 1;
SELECT * FROM toothpastes ORDER BY rating DESC LIMIT 1;
SELECT * FROM toothpastes ORDER BY tube_mass_g DESC LIMIT 1;
SELECT * FROM toothpastes ORDER BY rating ASC LIMIT 1;
SELECT * FROM toothpastes ORDER BY tube_mass_g ASC LIMIT 1;
SELECT * FROM toothpastes ORDER BY RANDOM() LIMIT 1; 
SELECT * FROM toothpastes WHERE id = ? LIMIT 1;
SELECT * FROM toothpastes WHERE brand_string = ? LIMIT 1;